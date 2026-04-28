/// .gitignore 风格的 glob 规则匹配器
///
/// 支持：
///   node_modules      → 精确匹配目录名或文件名
///   *.log             → 任意 .log 文件
///   **\/test          → 任意深度下名为 test 的文件夹
///   src\/dist         → 特定路径
class GlobMatcher {
  /// 判断 [name]（单个文件名或目录名）是否匹配 [pattern]
  static bool matchesName(String pattern, String name) {
    // 去掉路径分隔符，仅比较名称
    final cleanPattern = pattern.replaceAll('/', '').replaceAll('\\', '');
    if (!cleanPattern.contains('*') && !cleanPattern.contains('?')) {
      return name.toLowerCase() == cleanPattern.toLowerCase();
    }
    return _match(cleanPattern.toLowerCase(), name.toLowerCase());
  }

  /// 判断 [relativePath]（相对路径，使用 /）是否匹配 [pattern]
  static bool matchesPath(String pattern, String relativePath) {
    final normPath = relativePath.replaceAll('\\', '/');
    final normPattern = pattern.replaceAll('\\', '/');

    // 无通配符 → 精确匹配末尾路径段
    if (!normPattern.contains('*') && !normPattern.contains('?')) {
      final segments = normPath.split('/');
      return segments.any((s) => s.toLowerCase() == normPattern.toLowerCase());
    }

    // ** 展开为多段匹配
    if (normPattern.contains('**')) {
      final regexStr = _globToRegex(normPattern);
      return RegExp(regexStr, caseSensitive: false).hasMatch(normPath);
    }

    return _match(normPattern.toLowerCase(), normPath.toLowerCase());
  }

  /// 批量检查：给定 name/relativePath，判断是否被任意规则命中
  static bool anyMatch(List<String> patterns, String name,
      {String? relativePath}) {
    for (final p in patterns) {
      if (matchesName(p, name)) return true;
      if (relativePath != null && matchesPath(p, relativePath)) return true;
    }
    return false;
  }

  // ──────────────────────────────────────────────
  // 内部实现
  // ──────────────────────────────────────────────

  static bool _match(String pattern, String text) {
    // 经典递归 glob 匹配（* 不跨路径分隔符）
    if (pattern.isEmpty) return text.isEmpty;
    if (pattern == '*') return !text.contains('/');
    if (pattern[0] == '*') {
      // 尝试匹配 0 个或多个字符（不含 /）
      for (var i = 0; i <= text.length; i++) {
        if (i > 0 && text[i - 1] == '/') break;
        if (_match(pattern.substring(1), text.substring(i))) return true;
      }
      return false;
    }
    if (pattern[0] == '?' && text.isNotEmpty && text[0] != '/') {
      return _match(pattern.substring(1), text.substring(1));
    }
    if (text.isNotEmpty && pattern[0] == text[0]) {
      return _match(pattern.substring(1), text.substring(1));
    }
    return false;
  }

  static String _globToRegex(String pattern) {
    final buf = StringBuffer('^');
    var i = 0;
    while (i < pattern.length) {
      final c = pattern[i];
      if (c == '*' && i + 1 < pattern.length && pattern[i + 1] == '*') {
        buf.write('.*');
        i += 2;
        if (i < pattern.length && pattern[i] == '/') i++;
      } else if (c == '*') {
        buf.write('[^/]*');
        i++;
      } else if (c == '?') {
        buf.write('[^/]');
        i++;
      } else if (RegExp(r'[.+^${}()|[\]\\]').hasMatch(c)) {
        buf.write('\\$c');
        i++;
      } else {
        buf.write(c);
        i++;
      }
    }
    buf.write('\$');
    return buf.toString();
  }
}
