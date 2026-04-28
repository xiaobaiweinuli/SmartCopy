import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef IpcCommandHandler = void Function(Map<String, dynamic> command);

/// 单实例检测 + 进程间通信（临时文件方案）
class IpcService {
  static const _lockFile = 'smartcopy.pid';
  static const _cmdFile = 'smartcopy_cmd.json';
  static const _pollInterval = Duration(milliseconds: 400);

  String? _dir;
  Timer? _pollTimer;
  IpcCommandHandler? _handler;

  Future<String> get _dataDir async {
    if (_dir != null) return _dir!;
    final support = await getApplicationSupportDirectory();
    _dir = p.join(support.path, 'SmartCopy');
    await Directory(_dir!).create(recursive: true);
    return _dir!;
  }

  Future<String> get _lockPath async => p.join(await _dataDir, _lockFile);
  Future<String> get _cmdPath async => p.join(await _dataDir, _cmdFile);

  /// 尝试获取单实例锁。返回 true 表示本进程是第一个实例。
  Future<bool> tryAcquireLock() async {
    final lf = File(await _lockPath);

    if (await lf.exists()) {
      final pidStr = (await lf.readAsString()).trim();
      final existingPid = int.tryParse(pidStr);
      if (existingPid != null && _isProcessAlive(existingPid)) {
        return false; // 另一个实例正在运行
      }
    }

    await lf.writeAsString('$pid');
    return true;
  }

  /// 向正在运行的实例发送命令
  Future<void> sendCommand(Map<String, dynamic> command) async {
    final cf = File(await _cmdPath);
    // 若已有待处理命令，稍作等待
    for (var i = 0; i < 5; i++) {
      if (!await cf.exists()) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await cf.writeAsString(jsonEncode(command));
  }

  /// 开始轮询命令文件
  void startListening(IpcCommandHandler handler) {
    _handler = handler;
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      final cf = File(await _cmdPath);
      if (!await cf.exists()) return;
      try {
        final content = await cf.readAsString();
        await cf.delete();
        final cmd = jsonDecode(content);
        if (cmd is Map<String, dynamic>) {
          _handler?.call(cmd);
        }
      } catch (_) {
        // 忽略解析错误
      }
    });
  }

  /// 释放锁并停止轮询
  Future<void> releaseLock() async {
    _pollTimer?.cancel();
    final lf = File(await _lockPath);
    if (await lf.exists()) {
      try {
        await lf.delete();
      } catch (_) {}
    }
  }

  bool _isProcessAlive(int targetPid) {
    try {
      final result = Process.runSync(
        'tasklist',
        ['/fi', 'PID eq $targetPid', '/fo', 'csv', '/nh'],
        runInShell: true,
      );
      return result.stdout.toString().contains('"$targetPid"') ||
          result.stdout.toString().contains(',$targetPid,');
    } catch (_) {
      return false;
    }
  }
}
