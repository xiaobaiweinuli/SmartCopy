import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/app_dir.dart';

/// 简单的日志服务，将日志写入文件
class LoggerService {
  static LoggerService? _instance;
  File? _logFile;
  bool _initialized = false;
  static Future _writeFuture = Future.value();
  
  factory LoggerService() {
    _instance ??= LoggerService._internal();
    return _instance!;
  }
  
  LoggerService._internal();
  
  /// 初始化日志文件
  Future<void> init() async {
    if (_initialized) return;
    
    final logDir = AppDir.logsDirectory;
    
    // 日志文件名用日期
    final now = DateTime.now();
    final logFileName = 'smartcopy_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.txt';
    final logFilePath = p.join(logDir.path, logFileName);
    
    _logFile = File(logFilePath);
    
    // 写入一条初始标记
    await _logFile!.writeAsString(
      '=== SmartCopy Log Started at ${DateTime.now().toIso8601String()} ===\n',
      mode: FileMode.writeOnlyAppend,
    );
    
    _initialized = true;
  }
  
  /// 写入日志
  Future<void> log(String message, {String? prefix}) async {
    if (_logFile == null) return;
    
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final logLine = prefix != null 
        ? '[$timestamp] [$prefix] $message\n' 
        : '[$timestamp] $message\n';
    
    try {
      _writeFuture = _writeFuture.then(
        (_) => _logFile!.writeAsString(logLine, mode: FileMode.writeOnlyAppend),
      );
    } catch (e) {
      // 忽略日志文件错误
    }
  }
  
  /// 获取日志文件路径
  String? get logPath => _logFile?.path;
}
