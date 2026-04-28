import 'dart:io';

/// 通过系统内置 reg.exe 管理右键菜单 Shell Verb
/// 使用 HKCU（无需管理员权限）
class RegistryService {
  // 右键 Shell Verb 的注册表键路径
  static const _dirShellKey =
      r'HKCU\Software\Classes\Directory\shell\SmartCopy';
  static const _dirBgShellKey =
      r'HKCU\Software\Classes\Directory\Background\shell\SmartPasteHere';
  static const _fileShellKey =
      r'HKCU\Software\Classes\*\shell\SmartCopy';

  // 开机启动注册表路径
  static const _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _runValueName = 'SmartCopy';

  /// 注册右键菜单（文件夹 + 背景 + 文件）
  Future<bool> registerShellVerbs(String exePath) async {
    try {
      final escaped = exePath.replaceAll('/', '\\');

      final ops = [
        // ── 文件夹右键 → Smart Copy ──────────────────────────────
        _reg(['add', _dirShellKey, '/ve', '/d', 'Smart Copy (&S)', '/f']),
        _reg(['add', _dirShellKey, '/v', 'Icon', '/t', 'REG_SZ',
            '/d', '"$escaped",0', '/f']),
        _reg(['add', '$_dirShellKey\\command', '/ve', '/d',
            '"$escaped" --action=copy --src="%1"', '/f']),

        // ── 文件夹背景右键 → Smart Paste Here ───────────────────
        _reg(['add', _dirBgShellKey, '/ve', '/d', 'Smart Paste Here (&P)', '/f']),
        _reg(['add', _dirBgShellKey, '/v', 'Icon', '/t', 'REG_SZ',
            '/d', '"$escaped",0', '/f']),
        _reg(['add', '$_dirBgShellKey\\command', '/ve', '/d',
            '"$escaped" --action=paste --dest="%V"', '/f']),

        // ── 文件右键 → Smart Copy ────────────────────────────────
        _reg(['add', _fileShellKey, '/ve', '/d', 'Smart Copy (&S)', '/f']),
        _reg(['add', _fileShellKey, '/v', 'Icon', '/t', 'REG_SZ',
            '/d', '"$escaped",0', '/f']),
        _reg(['add', '$_fileShellKey\\command', '/ve', '/d',
            '"$escaped" --action=copy --src="%1"', '/f']),
      ];

      for (final op in ops) {
        final result = await op;
        if (result.exitCode != 0) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 注销右键菜单
  Future<bool> unregisterShellVerbs() async {
    try {
      await Future.wait([
        _reg(['delete', _dirShellKey, '/f']),
        _reg(['delete', _dirBgShellKey, '/f']),
        _reg(['delete', _fileShellKey, '/f']),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 检查右键菜单是否已注册
  Future<bool> isShellVerbRegistered() async {
    try {
      final result = await _reg(['query', _dirShellKey]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 设置/取消开机自启
  Future<bool> setAutoStart(bool enabled, String exePath) async {
    try {
      if (enabled) {
        final escaped = exePath.replaceAll('/', '\\');
        final result = await _reg([
          'add', _runKey,
          '/v', _runValueName,
          '/t', 'REG_SZ',
          '/d', '"$escaped" --minimized',
          '/f',
        ]);
        return result.exitCode == 0;
      } else {
        final result = await _reg([
          'delete', _runKey,
          '/v', _runValueName,
          '/f',
        ]);
        // 值不存在时也返回 true
        return result.exitCode == 0 || result.exitCode == 1;
      }
    } catch (_) {
      return false;
    }
  }

  /// 检查是否已设置开机自启
  Future<bool> isAutoStartEnabled() async {
    try {
      final result =
          await _reg(['query', _runKey, '/v', _runValueName]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 获取当前可执行文件路径
  static String get currentExePath => Platform.resolvedExecutable;

  // ─── 内部 ──────────────────────────────────────────────────

  Future<ProcessResult> _reg(List<String> args) =>
      Process.run('reg', args, runInShell: false);
}
