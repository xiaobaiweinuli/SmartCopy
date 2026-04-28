import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../core/models/app_settings.dart';
import '../core/models/copy_task.dart';
import '../core/models/folder_profile.dart';
import '../core/services/clipboard_service.dart';
import '../core/services/copy_engine.dart';
import '../core/services/logger_service.dart';
import '../core/services/registry_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/tray_service.dart';

enum AppScreen { home, profiles, globalRules, settings }

class AppProvider extends ChangeNotifier {
  final StorageService storageService;

  final CopyEngine _copyEngine = CopyEngine();
  final RegistryService _registryService = RegistryService();
  final TrayService _trayService = TrayService();
  final LoggerService _logger = LoggerService();
  final Uuid _uuid = const Uuid();

  AppScreen _currentScreen = AppScreen.home;
  List<FolderProfile> _profiles = [];
  AppSettings _settings = AppSettings();
  List<CopyTask> _taskHistory = [];
  CopyTask? _activeTask;
  String? _copySource;
  bool _loading = false;
  bool _scanning = false;
  String? _errorMessage;
  String? _successMessage;

  AppProvider({required this.storageService});

  AppScreen get currentScreen => _currentScreen;
  List<FolderProfile> get profiles => List.unmodifiable(_profiles);
  AppSettings get settings => _settings;
  List<CopyTask> get taskHistory => List.unmodifiable(_taskHistory);
  CopyTask? get activeTask => _activeTask;
  String? get copySource => _copySource;
  bool get loading => _loading;
  bool get scanning => _scanning;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get hasCopySource => _copySource != null;
  bool get isRunning => _copyEngine.isRunning;

  Future<void> init() async {
    await _logger.init();
    _setLoading(true);
    try {
      _profiles = await storageService.loadProfiles();
      _settings = await storageService.loadSettings();
      _taskHistory = await storageService.loadTaskHistory();
      await _registerHotkeys();
      await _trayService.init(onAction: _onTrayAction);
    } finally {
      _setLoading(false);
    }
    notifyListeners();
  }

  void navigate(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  void setCopySource(String path) {
    _copySource = path;
    _trayService.setHasSource(true, sourceLabel: p.basename(path));
    _showSuccess('已标记复制源：${p.basename(path)}');
    notifyListeners();
  }

  void clearCopySource() {
    _copySource = null;
    _trayService.setHasSource(false);
    notifyListeners();
  }

  /// 从剪贴板捕获文件路径（异步 PowerShell 方案）
  Future<void> captureFromClipboard() async {
    if (!Platform.isWindows) return;
    _logger.log('尝试从剪贴板捕获文件', prefix: 'Clipboard');
    final files = await ClipboardService.getFiles();
    _logger.log('剪贴板文件列表：${files.isNotEmpty ? files.join(', ') : '空'}', prefix: 'Clipboard');
    if (files.isEmpty) {
      _showError('未检测到选中文件，请先在文件管理器中选中文件');
      return;
    }
    if (files.length == 1) {
      setCopySource(files.first);
    } else {
      final parent = File(files.first).parent.path;
      setCopySource(parent);
      _showSuccess('已标记 ${files.length} 个文件（源目录：${p.basename(parent)}）');
    }
  }

  /// 预扫描源目录，返回扫描结果
  Future<ScanResult?> scanSource(String sourcePath, String destPath) async {
    _scanning = true;
    notifyListeners();

    try {
      // 合并过滤规则
      final profile = CopyEngine.findBestProfile(_profiles, sourcePath);
      final blacklistFolders = _mergeRules(
        _settings.mergeGlobalRules ? _settings.globalBlacklistFolders : [],
        profile?.blacklistFolders ?? [],
      );
      final blacklistFiles = _mergeRules(
        _settings.mergeGlobalRules ? _settings.globalBlacklistFiles : [],
        profile?.blacklistFiles ?? [],
      );

      final result = await _copyEngine.scanSourceAndDetectDuplicates(
        sourcePath: sourcePath,
        destPath: destPath,
        blacklistFolders: blacklistFolders,
        blacklistFiles: blacklistFiles,
      );

      return result;
    } catch (e, stackTrace) {
      _logger.log('扫描失败: $e\n$stackTrace', prefix: 'Error');
      _showError('扫描失败，请查看日志');
      return null;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// 执行粘贴（带扫描结果）
  Future<void> executePaste(String destPath, {ScanResult? scanResult, ConflictResolution? resolution}) async {
    _logger.log('executePaste 被调用，目标路径：$destPath', prefix: 'AppProvider');
    if (_copySource == null) { _showError('请先设置复制源'); return; }
    _logger.log('复制源路径：$_copySource', prefix: 'AppProvider');
    await _runCopy(
      sourcePath: _copySource!,
      destPath: destPath,
      scanResult: scanResult,
      resolution: resolution,
    );
  }

  /// 执行复制（内部方法）
  Future<void> _runCopy({
    required String sourcePath,
    required String destPath,
    ScanResult? scanResult,
    ConflictResolution? resolution,
  }) async {
    _logger.log('开始 _runCopy，源：$sourcePath，目标：$destPath', prefix: 'AppProvider');
    if (_copyEngine.isRunning) { _showError('当前有任务正在执行'); return; }
    final profile = CopyEngine.findBestProfile(_profiles, sourcePath);
    _activeTask = CopyTask(
      id: _uuid.v4(),
      sourcePath: sourcePath,
      destPath: destPath,
      isDirectory: FileSystemEntity.isDirectorySync(sourcePath),
      totalFiles: scanResult?.totalFiles ?? 0,
      bytesTotal: scanResult?.totalBytes ?? 0,
    );
    notifyListeners();
    _logger.log('创建 CopyTask：源=${_activeTask!.sourcePath}，目标=${_activeTask!.destPath}', prefix: 'AppProvider');
    final task = await _copyEngine.execute(
      sourcePath: sourcePath,
      destPath: destPath,
      settings: _settings,
      profile: profile,
      scanResult: scanResult,
      resolution: resolution ?? ConflictResolution.keepNewer,
      onUpdate: (t) { _activeTask = t; notifyListeners(); },
    );
    _activeTask = null;
    _taskHistory.insert(0, task);
    if (_taskHistory.length > 50) _taskHistory.removeLast();
    await storageService.appendTask(task);
    if (task.status == CopyStatus.success) {
      clearCopySource();
      _showSuccess('✓ 复制完成：${task.copiedFiles} 个文件，跳过 ${task.skippedFiles} 个');
      _sendNotification(task);
    } else if (task.status == CopyStatus.failed) {
      _showError('复制失败：${task.errorMessage}');
    }
    notifyListeners();
  }

  void cancelCurrentTask() { _copyEngine.cancel(); notifyListeners(); }

  Future<void> addProfile(FolderProfile profile) async {
    final n = await storageService.addProfile(profile);
    _profiles.add(n); notifyListeners();
  }

  Future<void> updateProfile(FolderProfile profile) async {
    await storageService.updateProfile(profile);
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) _profiles[idx] = profile;
    _showSuccess('配置已保存');
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    await storageService.deleteProfile(id);
    _profiles.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> addGlobalFolder(String pattern) async {
    if (!_settings.globalBlacklistFolders.contains(pattern)) {
      _settings.globalBlacklistFolders.add(pattern);
      await storageService.saveSettings(_settings); notifyListeners();
    }
  }

  Future<void> removeGlobalFolder(String pattern) async {
    _settings.globalBlacklistFolders.remove(pattern);
    await storageService.saveSettings(_settings); notifyListeners();
  }

  Future<void> addGlobalFile(String pattern) async {
    if (!_settings.globalBlacklistFiles.contains(pattern)) {
      _settings.globalBlacklistFiles.add(pattern);
      await storageService.saveSettings(_settings); notifyListeners();
    }
  }

  Future<void> removeGlobalFile(String pattern) async {
    _settings.globalBlacklistFiles.remove(pattern);
    await storageService.saveSettings(_settings); notifyListeners();
  }

  Future<void> importFromGitignore(String content) async {
    int added = 0;
    for (var line in content.split('\n')) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final isFolder = line.endsWith('/');
      final pattern = line.replaceAll('/', '').trim();
      if (pattern.isEmpty) continue;
      if (isFolder) {
        if (!_settings.globalBlacklistFolders.contains(pattern)) {
          _settings.globalBlacklistFolders.add(pattern); added++;
        }
      } else {
        if (!_settings.globalBlacklistFiles.contains(pattern)) {
          _settings.globalBlacklistFiles.add(pattern); added++;
        }
      }
    }
    await storageService.saveSettings(_settings);
    _showSuccess('已从 .gitignore 导入 $added 条规则'); notifyListeners();
  }

  Future<void> updateSetting({
    bool? autoStart, bool? minimizeToTray, bool? showNotifications,
    bool? mergeGlobalRules, int? robocopyThreads,
  }) async {
    if (autoStart != null) {
      // 注意：autoStart 现在通过 toggleAutoStart 来处理，不在这里处理
    }
    if (minimizeToTray != null) _settings.minimizeToTray = minimizeToTray;
    if (showNotifications != null) _settings.showNotifications = showNotifications;
    if (mergeGlobalRules != null) _settings.mergeGlobalRules = mergeGlobalRules;
    if (robocopyThreads != null) _settings.robocopyThreads = robocopyThreads;
    await storageService.saveSettings(_settings); notifyListeners();
  }

  Future<bool> toggleAutoStart() async {
    if (_settings.autoStart) {
      final ok = await _registryService.setAutoStart(false, RegistryService.currentExePath);
      if (ok) {
        _settings.autoStart = false;
        await storageService.saveSettings(_settings);
        _showSuccess('已取消开机自动启动'); notifyListeners();
      }
      return ok;
    } else {
      final ok = await _registryService.setAutoStart(true, RegistryService.currentExePath);
      if (ok) {
        _settings.autoStart = true;
        await storageService.saveSettings(_settings);
        _showSuccess('已设置开机自动启动'); notifyListeners();
      } else {
        _showError('操作失败，请检查权限');
      }
      return ok;
    }
  }

  Future<void> updateThemeMode(ThemeModeSetting mode) async {
    _settings.themeMode = mode;
    await storageService.saveSettings(_settings);
    notifyListeners();
    // 显示提示
    switch (mode) {
      case ThemeModeSetting.light:
        _showSuccess('已切换到浅色主题');
        break;
      case ThemeModeSetting.dark:
        _showSuccess('已切换到深色主题');
        break;
      case ThemeModeSetting.system:
        _showSuccess('已设置为跟随系统主题');
        break;
    }
  }

  Future<bool> toggleRightClickMenu() async {
    if (_settings.rightClickMenuEnabled) {
      final ok = await _registryService.unregisterShellVerbs();
      if (ok) {
        _settings.rightClickMenuEnabled = false;
        await storageService.saveSettings(_settings);
        _showSuccess('已注销右键菜单'); notifyListeners();
      }
      return ok;
    } else {
      final ok = await _registryService.registerShellVerbs(RegistryService.currentExePath);
      if (ok) {
        _settings.rightClickMenuEnabled = true;
        await storageService.saveSettings(_settings);
        _showSuccess('右键菜单注册成功'); notifyListeners();
      } else {
        _showError('右键菜单注册失败，请检查权限');
      }
      return ok;
    }
  }

  Future<void> updateHotkeys({HotkeyDef? copyHotkey, HotkeyDef? pasteHotkey}) async {
    if (copyHotkey != null) _settings.smartCopyHotkey = copyHotkey;
    if (pasteHotkey != null) _settings.smartPasteHotkey = pasteHotkey;
    await storageService.saveSettings(_settings);
    await _registerHotkeys(); notifyListeners();
  }

  Future<void> clearHistory() async {
    _taskHistory.clear(); await storageService.clearTaskHistory(); notifyListeners();
  }

  Future<void> _registerHotkeys() async {
    await hotKeyManager.unregisterAll();

    final copyHk = _buildHotKey(_settings.smartCopyHotkey);
    if (copyHk != null) {
      await hotKeyManager.register(copyHk,
          keyDownHandler: (_) {
            // 使用 Future 异步运行，避免阻塞
            Future.microtask(captureFromClipboard);
          });
    }
    final pasteHk = _buildHotKey(_settings.smartPasteHotkey);
    if (pasteHk != null) {
      await hotKeyManager.register(pasteHk,
          keyDownHandler: (_) {
            _hotkeyPasteTriggered();
          });
    }
  }

  HotKey? _buildHotKey(HotkeyDef def) {
    try {
      final modifiers = <HotKeyModifier>[];
      if (def.ctrl) modifiers.add(HotKeyModifier.control);
      if (def.shift) modifiers.add(HotKeyModifier.shift);
      if (def.alt) modifiers.add(HotKeyModifier.alt);
      final key = _keyStringToLogical(def.key);
      if (key == null) return null;
      return HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
    } catch (_) { return null; }
  }

  LogicalKeyboardKey? _keyStringToLogical(String key) {
    final map = <String, LogicalKeyboardKey>{
      'A': LogicalKeyboardKey.keyA, 'B': LogicalKeyboardKey.keyB,
      'C': LogicalKeyboardKey.keyC, 'D': LogicalKeyboardKey.keyD,
      'E': LogicalKeyboardKey.keyE, 'F': LogicalKeyboardKey.keyF,
      'G': LogicalKeyboardKey.keyG, 'H': LogicalKeyboardKey.keyH,
      'I': LogicalKeyboardKey.keyI, 'J': LogicalKeyboardKey.keyJ,
      'K': LogicalKeyboardKey.keyK, 'L': LogicalKeyboardKey.keyL,
      'M': LogicalKeyboardKey.keyM, 'N': LogicalKeyboardKey.keyN,
      'O': LogicalKeyboardKey.keyO, 'P': LogicalKeyboardKey.keyP,
      'Q': LogicalKeyboardKey.keyQ, 'R': LogicalKeyboardKey.keyR,
      'S': LogicalKeyboardKey.keyS, 'T': LogicalKeyboardKey.keyT,
      'U': LogicalKeyboardKey.keyU, 'V': LogicalKeyboardKey.keyV,
      'W': LogicalKeyboardKey.keyW, 'X': LogicalKeyboardKey.keyX,
      'Y': LogicalKeyboardKey.keyY, 'Z': LogicalKeyboardKey.keyZ,
    };
    return map[key.toUpperCase()];
  }

  void _hotkeyPasteTriggered() async {
    _logger.log('热键粘贴触发', prefix: 'AppProvider');

    if (!hasCopySource) {
      _showError('请先通过右键或 Ctrl+Shift+C 标记复制源'); return;
    }

    // 尝试获取当前文件管理器窗口的路径
    final destPath = await ClipboardService.getCurrentWindowPath();
    _logger.log('获取到目标路径：$destPath', prefix: 'AppProvider');

    if (destPath != null) {
      // 如果获取到路径，直接粘贴（不打开窗口）
      // 对于热键粘贴，我们直接用默认策略，不扫描（避免用户等待）
      await executePaste(destPath);
    } else {
      // 否则回退到原来的行为，显示窗口让用户选择
      _showError('未能检测到文件管理器窗口，请手动选择');
      await windowManager.show();
      await windowManager.focus();
      navigate(AppScreen.home); notifyListeners();
    }
  }

  void _onTrayAction(String key) {
    switch (key) {
      case 'show': windowManager.show(); windowManager.focus(); break;
      case 'clearSource': clearCopySource(); break;
      case 'openDataDir':
        Process.run('explorer', [storageService.dataDirectory]);
        break;
      case 'exit':
        _trayService.dispose();
        hotKeyManager.unregisterAll();
        // 先关闭 PreventClose 再关闭窗口，否则 close() 被拦截
        windowManager.setPreventClose(false).then((_) => windowManager.close());
        break;
    }
  }

  void _sendNotification(CopyTask task) {
    if (!_settings.showNotifications) return;
    LocalNotification(
      title: 'SmartCopy - 复制完成',
      body: '${task.sourceNameShort} → 已复制 ${task.copiedFiles} 个文件，跳过 ${task.skippedFiles} 个',
    ).show();
  }

  void _setLoading(bool v) { _loading = v; notifyListeners(); }

  void _showError(String msg) {
    _errorMessage = msg; _successMessage = null; notifyListeners();
    Future.delayed(const Duration(seconds: 4), () {
      if (_errorMessage == msg) { _errorMessage = null; notifyListeners(); }
    });
  }

  void _showSuccess(String msg) {
    _successMessage = msg; _errorMessage = null; notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (_successMessage == msg) { _successMessage = null; notifyListeners(); }
    });
  }

  void clearMessages() {
    _errorMessage = null; _successMessage = null; notifyListeners();
  }

  void showSuccess(String message) {
    _showSuccess(message);
  }

  void showError(String message) {
    _showError(message);
  }

  List<String> _mergeRules(List<String> global, List<String> local) {
    final set = <String>{...global, ...local};
    return set.toList();
  }

  @override
  void dispose() {
    _trayService.dispose();
    hotKeyManager.unregisterAll();
    super.dispose();
  }
}
