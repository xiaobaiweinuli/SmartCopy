import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:charset/charset.dart';
import 'logger_service.dart';
import '../models/copy_task.dart';
import '../models/app_settings.dart';
import '../models/folder_profile.dart';
import '../utils/glob_matcher.dart';

typedef TaskUpdateCallback = void Function(CopyTask task);

/// 尝试多种编码解码字节
String _decodeBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';

  try {
    return gbk.decode(bytes);
  } catch (_) {}

  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {}

  try {
    return const SystemEncoding().decode(bytes);
  } catch (_) {}

  return '';
}

/// 简单的节流包装器，避免 UI 频繁更新
class _ThrottledUpdater {
  final TaskUpdateCallback? onUpdate;
  final Duration minInterval;
  DateTime? _lastUpdate;
  CopyTask? _pendingTask;

  _ThrottledUpdater(this.onUpdate) : minInterval = const Duration(milliseconds: 200);

  void update(CopyTask task) {
    if (onUpdate == null) return;

    final now = DateTime.now();
    if (_lastUpdate == null || now.difference(_lastUpdate!) >= minInterval) {
      _lastUpdate = now;
      _pendingTask = null;
      onUpdate!(task);
    } else {
      _pendingTask = task;
    }
  }

  void flush() {
    if (_pendingTask != null && onUpdate != null) {
      onUpdate!(_pendingTask!);
      _pendingTask = null;
    }
  }
}

/// Robocopy 包装器，处理文件夹/文件的过滤复制
class CopyEngine {
  Process? _currentProcess;
  CopyTask? _currentTask;
  final _uuid = const Uuid();
  final LoggerService _logger = LoggerService();
  bool _loggerInitialized = false;
  Map<String, FileInfo>? _fileInfoMap;
  int _totalBytesFromScan = 0;

  Future<void> _initLogger() async {
    if (!_loggerInitialized) {
      await _logger.init();
      _loggerInitialized = true;
    }
  }

  bool get isRunning => _currentTask != null &&
      _currentTask!.status == CopyStatus.running;

  /// 预扫描源目录，获取文件列表和检测重复
  Future<ScanResult> scanSourceAndDetectDuplicates({
    required String sourcePath,
    required String destPath,
    List<String>? blacklistFolders,
    List<String>? blacklistFiles,
  }) async {
    await _initLogger();
    _logger.log('开始预扫描目录: $sourcePath', prefix: 'CopyEngine');

    final sourceEntity = FileSystemEntity.typeSync(sourcePath);
    final isDir = sourceEntity == FileSystemEntityType.directory;

    final List<FileInfo> allFiles = [];
    final List<DuplicateFile> duplicates = [];
    int totalBytes = 0;

    // 构建黑名单匹配函数
    bool isFolderBlacklisted(String folderName) {
      if (blacklistFolders == null) return false;
      return GlobMatcher.anyMatch(blacklistFolders, folderName);
    }

    bool isFileBlacklisted(String fileName) {
      if (blacklistFiles == null) return false;
      return GlobMatcher.anyMatch(blacklistFiles, fileName);
    }

    if (isDir) {
      // 处理目录
      final sourceDir = Directory(sourcePath);
      await for (final entity in sourceDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          // 获取相对路径
          final relativePath = p.relative(entity.path, from: sourcePath);

          // 检查文件夹黑名单
          final parts = p.split(relativePath);
          bool skip = false;
          for (int i = 0; i < parts.length - 1; i++) {
            if (isFolderBlacklisted(parts[i])) {
              skip = true;
              break;
            }
          }
          if (skip) continue;

          // 检查文件黑名单
          if (isFileBlacklisted(p.basename(entity.path))) continue;

          // 获取文件信息
          final stat = await entity.stat();
          final fileInfo = FileInfo(
            path: entity.path,
            relativePath: relativePath,
            size: stat.size,
            modified: stat.modified,
          );

          allFiles.add(fileInfo);
          totalBytes += stat.size;

          // 检查目标文件是否存在
          final srcName = p.basename(sourcePath);
          final finalDestDir = p.join(destPath, srcName);
          final destFilePath = p.join(finalDestDir, relativePath);
          final destFile = File(destFilePath);

          if (await destFile.exists()) {
            final destStat = await destFile.stat();
            final destFileInfo = FileInfo(
              path: destFilePath,
              relativePath: relativePath,
              size: destStat.size,
              modified: destStat.modified,
            );

            duplicates.add(DuplicateFile(
              source: fileInfo,
              dest: destFileInfo,
            ));
          }
        }
      }
    } else {
      // 处理单个文件
      final file = File(sourcePath);
      if (isFileBlacklisted(p.basename(sourcePath))) {
        return ScanResult(
          allFiles: [],
          duplicates: [],
          totalBytes: 0,
          totalFiles: 0,
        );
      }

      final stat = await file.stat();
      final fileInfo = FileInfo(
        path: sourcePath,
        relativePath: p.basename(sourcePath),
        size: stat.size,
        modified: stat.modified,
      );

      allFiles.add(fileInfo);
      totalBytes += stat.size;

      // 检查目标文件是否存在
      final destFilePath = p.join(destPath, p.basename(sourcePath));
      final destFile = File(destFilePath);

      if (await destFile.exists()) {
        final destStat = await destFile.stat();
        final destFileInfo = FileInfo(
          path: destFilePath,
          relativePath: p.basename(sourcePath),
          size: destStat.size,
          modified: destStat.modified,
        );

        duplicates.add(DuplicateFile(
          source: fileInfo,
          dest: destFileInfo,
        ));
      }
    }

    _logger.log('扫描完成: ${allFiles.length} 个文件, $totalBytes 字节, ${duplicates.length} 个重复', prefix: 'CopyEngine');

    return ScanResult(
      allFiles: allFiles,
      duplicates: duplicates,
      totalBytes: totalBytes,
      totalFiles: allFiles.length,
    );
  }

  /// 根据冲突解决策略构建 robocopy 参数
  List<String> _buildArgsWithResolution({
    required String source,
    required String dest,
    required List<String> blacklistFolders,
    required List<String> blacklistFiles,
    required int threads,
    ConflictResolution resolution = ConflictResolution.keepNewer,
    bool listOnly = false,
  }) {
    final args = <String>[
      source,
      dest,
      '/E',         // 包含子目录（含空目录）
      '/COPY:DAT',  // 复制数据、属性、时间戳
      '/R:2',       // 失败重试 2 次
      '/W:1',       // 重试间隔 1 秒
    ];

    // 根据冲突解决策略添加参数
    switch (resolution) {
      case ConflictResolution.skip:
        args.addAll(['/XC', '/XN', '/XO']); // 跳过已更改、较新、较旧的文件
        break;
      case ConflictResolution.overwrite:
        args.add('/IS'); // 包含相同文件（强制覆盖）
        break;
      case ConflictResolution.keepNewer:
        args.add('/XO'); // 只复制较旧的（即保留较新的）
        break;
    }

    if (blacklistFolders.isNotEmpty) {
      args.add('/XD');
      args.addAll(blacklistFolders);
    }

    if (blacklistFiles.isNotEmpty) {
      args.add('/XF');
      args.addAll(blacklistFiles);
    }

    if (listOnly) args.add('/L');

    return args;
  }

  // ─── 主入口 ──────────────────────────────────────────────────

  /// 执行过滤复制
  Future<CopyTask> execute({
    required String sourcePath,
    required String destPath,
    required AppSettings settings,
    FolderProfile? profile,
    ScanResult? scanResult,
    ConflictResolution resolution = ConflictResolution.keepNewer,
    TaskUpdateCallback? onUpdate,
  }) async {
    await _initLogger();
    _logger.log('开始复制任务', prefix: 'CopyEngine');
    _logger.log('源目录: $sourcePath', prefix: 'CopyEngine');
    _logger.log('目标目录: $destPath', prefix: 'CopyEngine');
    _logger.log('冲突策略: $resolution', prefix: 'CopyEngine');

    final sourceEntity = FileSystemEntity.typeSync(sourcePath);
    final isDir = sourceEntity == FileSystemEntityType.directory;

    // 合并过滤规则
    final blacklistFolders = _mergeRules(
      settings.mergeGlobalRules ? settings.globalBlacklistFolders : [],
      profile?.blacklistFolders ?? [],
    );
    final blacklistFiles = _mergeRules(
      settings.mergeGlobalRules ? settings.globalBlacklistFiles : [],
      profile?.blacklistFiles ?? [],
    );

    // 特殊处理：如果源目录本身在文件夹黑名单中，临时从黑名单移除它
    List<String> effectiveBlacklistFolders = List.from(blacklistFolders);
    if (isDir) {
      final sourceDirName = p.basename(sourcePath);
      if (effectiveBlacklistFolders.remove(sourceDirName)) {
        _logger.log('源目录本身在黑名单中，临时移除: $sourceDirName', prefix: 'CopyEngine');
      }
    }

    // 构建文件信息映射（用于进度计算）
    if (scanResult != null) {
      _fileInfoMap = {
        for (final file in scanResult.allFiles) file.relativePath.toLowerCase(): file
      };
      _totalBytesFromScan = scanResult.totalBytes;
    } else {
      _fileInfoMap = null;
      _totalBytesFromScan = 0;
    }

    final task = CopyTask(
      id: _uuid.v4(),
      sourcePath: sourcePath,
      destPath: destPath,
      isDirectory: isDir,
      status: CopyStatus.running,
      totalFiles: scanResult?.totalFiles ?? 0,
      bytesTotal: scanResult?.totalBytes ?? 0,
      appliedRules: [...blacklistFolders, ...blacklistFiles],
    );
    _currentTask = task;
    onUpdate?.call(task);

    try {
      if (isDir) {
        await _copyDirectory(
          task: task,
          blacklistFolders: effectiveBlacklistFolders,
          blacklistFiles: blacklistFiles,
          threads: settings.robocopyThreads,
          resolution: resolution,
          onUpdate: onUpdate,
        );
      } else {
        await _copySingleFile(
          task: task,
          blacklistFiles: blacklistFiles,
          onUpdate: onUpdate,
        );
      }
    } catch (e, stackTrace) {
      task.status = CopyStatus.failed;
      task.errorMessage = '复制失败，请查看日志';
      _logger.log('复制异常: $e\n$stackTrace', prefix: 'Error');
      task.finishedAt = DateTime.now();
      onUpdate?.call(task);
    }

    _currentTask = null;
    _fileInfoMap = null;
    return task;
  }

  /// 取消当前任务
  void cancel() {
    _logger.log('用户请求取消任务', prefix: 'CopyEngine');

    // 先更新任务状态
    if (_currentTask != null && _currentTask!.status == CopyStatus.running) {
      _currentTask!.status = CopyStatus.cancelled;
      _currentTask!.finishedAt = DateTime.now();
    }

    // 然后再结束进程
    if (_currentProcess != null) {
      try {
        _currentProcess!.kill(ProcessSignal.sigterm);
        _logger.log('进程已终止', prefix: 'CopyEngine');
      } catch (e) {
        _logger.log('终止进程失败: $e', prefix: 'Error');
      }
    }
  }

  // ─── 文件夹复制（Robocopy） ──────────────────────────────────

  Future<void> _copyDirectory({
    required CopyTask task,
    required List<String> blacklistFolders,
    required List<String> blacklistFiles,
    required int threads,
    ConflictResolution resolution = ConflictResolution.keepNewer,
    TaskUpdateCallback? onUpdate,
  }) async {
    _logger.log('开始 Robocopy 复制目录', prefix: 'CopyEngine');

    final updater = _ThrottledUpdater(onUpdate);
    int bytesCopied = 0;
    final startTime = DateTime.now();

    // 确保目标目录名与源一致
    final srcName = p.basename(task.sourcePath);
    final finalDest = p.join(task.destPath, srcName);
    _logger.log('最终目标目录: $finalDest', prefix: 'CopyEngine');

    final args = _buildArgsWithResolution(
      source: task.sourcePath,
      dest: finalDest,
      blacklistFolders: blacklistFolders,
      blacklistFiles: blacklistFiles,
      threads: threads,
      resolution: resolution,
      listOnly: false,
    );

    // 记录完整的 Robocopy 命令用于调试
    final commandLog = 'robocopy ${args.join(' ')}';
    _logger.log('执行命令: $commandLog', prefix: 'CopyEngine');

    _currentProcess = await Process.start('robocopy', args, runInShell: false);
    _logger.log('进程已启动，PID: ${_currentProcess?.pid}', prefix: 'CopyEngine');

    int lineCount = 0;
    final List<int> stdoutBytes = [];
    final List<int> stderrBytes = [];

    // 同时监听 stdout 和 stderr
    final stdoutFuture = _currentProcess!.stdout.listen((data) {
      stdoutBytes.addAll(data);

      // 实时解析输出更新进度
      final output = _decodeBytes(data);
      for (final line in output.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (_isFileCopyLine(trimmed)) {
          lineCount++;
          task.copiedFiles = lineCount;
          final fileName = _extractFileName(trimmed);
          task.currentFile = fileName;

          // 如果有预扫描的文件信息，累加字节数
          if (_fileInfoMap != null) {
            final lowerFileName = fileName.toLowerCase();
            final fileInfo = _fileInfoMap![lowerFileName];
            if (fileInfo != null) {
              bytesCopied += fileInfo.size;
              task.bytesCopied = bytesCopied;
            }

            // 计算速度和剩余时间
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            if (elapsed > 0) {
              task.speedBytesPerSecond = bytesCopied / elapsed;
              if (_totalBytesFromScan > bytesCopied && task.speedBytesPerSecond! > 0) {
                final remainingBytes = _totalBytesFromScan - bytesCopied;
                task.estimatedRemaining = Duration(seconds: (remainingBytes / task.speedBytesPerSecond!).round());
              }
            }
          }

          updater.update(task);
        } else if (_isSkipLine(trimmed)) {
          task.skippedFiles++;
          updater.update(task);
        } else if (_isErrorLine(trimmed)) {
          task.failedFiles++;
          updater.update(task);
        }
      }
    }).asFuture();

    final stderrFuture = _currentProcess!.stderr.listen((data) {
      stderrBytes.addAll(data);
    }).asFuture();

    // 等待进程结束和所有流收集完成
    final exitCode = await _currentProcess!.exitCode;
    await Future.wait([stdoutFuture, stderrFuture]);
    _logger.log('进程已退出，退出码: $exitCode', prefix: 'CopyEngine');
    _currentProcess = null;

    task.finishedAt = DateTime.now();
    // Robocopy: exitCode 0-7 视为成功
    if (task.status == CopyStatus.cancelled) {
      _logger.log('任务已取消', prefix: 'CopyEngine');
    } else if (exitCode <= 7) {
      task.status = CopyStatus.success;
      _logger.log('复制成功！复制了 $lineCount 个文件', prefix: 'Success');
      if (task.totalFiles == 0) task.totalFiles = task.copiedFiles;
    } else {
      task.status = CopyStatus.failed;
      task.errorMessage = '复制失败，请查看日志';
      _logger.log('复制失败: 退出码 $exitCode', prefix: 'Error');
      if (_decodeBytes(stderrBytes).isNotEmpty) {
        _logger.log('错误输出:\n${_decodeBytes(stderrBytes)}', prefix: 'Error');
      }
      if (_decodeBytes(stdoutBytes).isNotEmpty) {
        _logger.log('完整输出:\n${_decodeBytes(stdoutBytes)}', prefix: 'Debug');
      }
    }

    updater.flush();
    updater.update(task);
  }

  // ─── 单文件复制 ──────────────────────────────────────────────

  Future<void> _copySingleFile({
    required CopyTask task,
    required List<String> blacklistFiles,
    TaskUpdateCallback? onUpdate,
  }) async {
    final srcFile = File(task.sourcePath);
    final fileName = p.basename(task.sourcePath);

    // 检查黑名单
    if (GlobMatcher.anyMatch(blacklistFiles, fileName)) {
      task.status = CopyStatus.success;
      task.totalFiles = 1;
      task.skippedFiles = 1;
      task.finishedAt = DateTime.now();
      onUpdate?.call(task);
      return;
    }

    try {
      await Directory(task.destPath).create(recursive: true);
      final destFile = File(p.join(task.destPath, fileName));

      task.totalFiles = 1;
      task.currentFile = fileName;

      // 如果有预扫描信息，设置总大小
      if (_totalBytesFromScan > 0) {
        task.bytesTotal = _totalBytesFromScan;
      }

      onUpdate?.call(task);

      // 复制文件
      await srcFile.copy(destFile.path);

      task.status = CopyStatus.success;
      task.copiedFiles = 1;
      task.bytesCopied = task.bytesTotal;
      task.finishedAt = DateTime.now();
      onUpdate?.call(task);
    } catch (e, stackTrace) {
      task.status = CopyStatus.failed;
      task.errorMessage = '复制失败，请查看日志';
      _logger.log('文件复制失败: $e\n$stackTrace', prefix: 'Error');
      task.finishedAt = DateTime.now();
      onUpdate?.call(task);
    }
  }

  // ─── 输出行解析 ──────────────────────────────────────────────

  bool _isFileCopyLine(String line) {
    if (line.isEmpty) return false;
    return line.contains('New File') ||
        line.contains('新建文件') ||
        line.contains('Newer') ||
        line.contains('更新') ||
        line.contains('Same') ||
        line.contains('相同');
  }

  bool _isSkipLine(String line) =>
      line.contains('Skipped') ||
      line.contains('跳过');

  bool _isErrorLine(String line) =>
      line.contains('ERROR') || line.contains('错误');

  String _extractFileName(String line) {
    final parts = line.split(RegExp(r'\s{2,}|\t'));
    // 找最后一个非空部分
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i].trim();
      if (part.isNotEmpty && !part.contains('%') && !part.contains('File')) {
        return part;
      }
    }
    return parts.isNotEmpty ? parts.last.trim() : line;
  }

  // ─── 工具方法 ─────────────────────────────────────────────────

  List<String> _mergeRules(List<String> global, List<String> local) {
    final set = <String>{...global, ...local};
    return set.toList();
  }

  /// 根据源路径查找最匹配的 Profile
  static FolderProfile? findBestProfile(
      List<FolderProfile> profiles, String sourcePath) {
    final normSrc = sourcePath.replaceAll('\\', '/').toLowerCase();
    FolderProfile? best;
    int bestDepth = -1;

    for (final profile in profiles) {
      if (!profile.enabled) continue;
      final normPath =
          profile.folderPath.replaceAll('\\', '/').toLowerCase();
      if (normSrc.startsWith(normPath)) {
        final depth = normPath.split('/').length;
        if (depth > bestDepth) {
          bestDepth = depth;
          best = profile;
        }
      }
    }
    return best;
  }
}
