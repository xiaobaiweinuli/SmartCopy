enum CopyStatus { idle, running, success, failed, cancelled }

enum ConflictResolution {
  skip,        // 跳过 (保持目标文件)
  overwrite,   // 覆盖 (用源文件替换)
  keepNewer,  // 保留较新的
}

/// 单个文件信息
class FileInfo {
  final String path;
  final String relativePath;
  final int size;
  final DateTime modified;

  FileInfo({
    required this.path,
    required this.relativePath,
    required this.size,
    required this.modified,
  });
}

/// 重复文件信息
class DuplicateFile {
  final FileInfo source;
  final FileInfo dest;
  ConflictResolution resolution;

  DuplicateFile({
    required this.source,
    required this.dest,
    this.resolution = ConflictResolution.skip,
  });

  String get displayPath => source.relativePath;
  bool get isSourceNewer => source.modified.isAfter(dest.modified);
  bool get isSameSize => source.size == dest.size;
  bool get isSameTime => source.modified == dest.modified;
}

/// 预扫描结果
class ScanResult {
  final List<FileInfo> allFiles;
  final List<DuplicateFile> duplicates;
  final int totalBytes;
  final int totalFiles;

  ScanResult({
    required this.allFiles,
    required this.duplicates,
    required this.totalBytes,
    required this.totalFiles,
  });
}

class CopyTask {
  final String id;
  final String sourcePath;
  final String destPath;
  final bool isDirectory;
  CopyStatus status;
  int totalFiles;
  int copiedFiles;
  int skippedFiles;
  int failedFiles;
  String? currentFile;
  String? errorMessage;
  final DateTime startedAt;
  DateTime? finishedAt;
  int bytesTotal;
  int bytesCopied;
  List<String> appliedRules;
  double? speedBytesPerSecond;
  Duration? estimatedRemaining;

  CopyTask({
    required this.id,
    required this.sourcePath,
    required this.destPath,
    required this.isDirectory,
    this.status = CopyStatus.idle,
    this.totalFiles = 0,
    this.copiedFiles = 0,
    this.skippedFiles = 0,
    this.failedFiles = 0,
    this.currentFile,
    this.errorMessage,
    DateTime? startedAt,
    this.finishedAt,
    this.bytesTotal = 0,
    this.bytesCopied = 0,
    List<String>? appliedRules,
    this.speedBytesPerSecond,
    this.estimatedRemaining,
  })  : startedAt = startedAt ?? DateTime.now(),
        appliedRules = appliedRules ?? [];

  double get progress {
    if (bytesTotal == 0 && totalFiles == 0) return 0.0;
    if (bytesTotal > 0) {
      return (bytesCopied / bytesTotal).clamp(0.0, 1.0);
    }
    return (copiedFiles / totalFiles).clamp(0.0, 1.0);
  }

  Duration? get elapsed {
    final end = finishedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  bool get isFinished =>
      status == CopyStatus.success ||
      status == CopyStatus.failed ||
      status == CopyStatus.cancelled;

  String get statusLabel {
    switch (status) {
      case CopyStatus.idle:
        return '等待中';
      case CopyStatus.running:
        return '复制中';
      case CopyStatus.success:
        return '已完成';
      case CopyStatus.failed:
        return '失败';
      case CopyStatus.cancelled:
        return '已取消';
    }
  }

  String get sourceNameShort {
    final parts = sourcePath.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : sourcePath;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'destPath': destPath,
        'isDirectory': isDirectory,
        'status': status.name,
        'totalFiles': totalFiles,
        'copiedFiles': copiedFiles,
        'skippedFiles': skippedFiles,
        'failedFiles': failedFiles,
        'errorMessage': errorMessage,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'bytesTotal': bytesTotal,
        'bytesCopied': bytesCopied,
        'appliedRules': appliedRules,
      };

  factory CopyTask.fromJson(Map<String, dynamic> json) => CopyTask(
        id: json['id'] as String,
        sourcePath: json['sourcePath'] as String,
        destPath: json['destPath'] as String,
        isDirectory: json['isDirectory'] as bool? ?? false,
        status: CopyStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => CopyStatus.success,
        ),
        totalFiles: json['totalFiles'] as int? ?? 0,
        copiedFiles: json['copiedFiles'] as int? ?? 0,
        skippedFiles: json['skippedFiles'] as int? ?? 0,
        failedFiles: json['failedFiles'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        startedAt: DateTime.tryParse(json['startedAt'] ?? '') ?? DateTime.now(),
        finishedAt: json['finishedAt'] != null
            ? DateTime.tryParse(json['finishedAt'] as String)
            : null,
        bytesTotal: json['bytesTotal'] as int? ?? 0,
        bytesCopied: json['bytesCopied'] as int? ?? 0,
        appliedRules: List<String>.from(json['appliedRules'] ?? []),
      );
}
