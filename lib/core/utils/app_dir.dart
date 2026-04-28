import 'dart:io';
import 'package:path/path.dart' as p;

/// 获取程序所在的目录
class AppDir {
  static Directory? _appDir;

  /// 获取程序所在的目录（获取可执行文件所在的文件夹）
  static Directory get appDirectory {
    if (_appDir != null) return _appDir!;
    
    // 获取当前可执行文件的路径
    final exePath = Platform.resolvedExecutable;
    _appDir = Directory(p.dirname(exePath));
    return _appDir!;
  }

  /// 获取程序目录下的路径
  static String getPath(String subPath) {
    return p.join(appDirectory.path, subPath);
  }

  /// 获取数据目录（程序目录下的 data 文件夹）
  static Directory get dataDirectory {
    final dir = Directory(getPath('data'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 获取日志目录（程序目录下的 logs 文件夹）
  static Directory get logsDirectory {
    final dir = Directory(getPath('logs'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }
}
