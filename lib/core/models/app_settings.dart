import 'dart:convert';

class HotkeyDef {
  final String key;           // e.g. "C"
  final bool ctrl;
  final bool shift;
  final bool alt;

  const HotkeyDef({
    required this.key,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
  });

  String get display {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    parts.add(key.toUpperCase());
    return parts.join(' + ');
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'ctrl': ctrl,
        'shift': shift,
        'alt': alt,
      };

  factory HotkeyDef.fromJson(Map<String, dynamic> json) => HotkeyDef(
        key: json['key'] as String,
        ctrl: json['ctrl'] as bool? ?? false,
        shift: json['shift'] as bool? ?? false,
        alt: json['alt'] as bool? ?? false,
      );

  static const smartCopyDefault =
      HotkeyDef(key: 'C', ctrl: true, shift: true);
  static const smartPasteDefault =
      HotkeyDef(key: 'V', ctrl: true, shift: true);
}

enum ThemeModeSetting {
  system, // 跟随系统
  light,  // 浅色
  dark,   // 深色
}

class AppSettings {
  // 快捷键
  HotkeyDef smartCopyHotkey;
  HotkeyDef smartPasteHotkey;

  // 全局黑名单
  List<String> globalBlacklistFolders;
  List<String> globalBlacklistFiles;

  // 行为
  bool autoStart;
  bool minimizeToTray;
  bool showNotifications;
  bool rightClickMenuEnabled;
  bool mergeGlobalRules; // 全局规则叠加到 Profile 规则
  int robocopyThreads;
  
  // 主题
  ThemeModeSetting themeMode;

  AppSettings({
    HotkeyDef? smartCopyHotkey,
    HotkeyDef? smartPasteHotkey,
    List<String>? globalBlacklistFolders,
    List<String>? globalBlacklistFiles,
    this.autoStart = false,
    this.minimizeToTray = true,
    this.showNotifications = true,
    this.rightClickMenuEnabled = false,
    this.mergeGlobalRules = true,
    this.robocopyThreads = 8,
    this.themeMode = ThemeModeSetting.system,
  })  : smartCopyHotkey = smartCopyHotkey ?? HotkeyDef.smartCopyDefault,
        smartPasteHotkey = smartPasteHotkey ?? HotkeyDef.smartPasteDefault,
        globalBlacklistFolders = globalBlacklistFolders ??
            [
              'node_modules',
              '.git',
              '.svn',
              '__pycache__',
              '.idea',
              '.vscode',
              'dist',
              'build',
              '.gradle',
              '.dart_tool',
            ],
        globalBlacklistFiles = globalBlacklistFiles ??
            [
              '*.log',
              '*.tmp',
              '*.temp',
              'Thumbs.db',
              '.DS_Store',
              '*.pyc',
            ];

  Map<String, dynamic> toJson() => {
        'smartCopyHotkey': smartCopyHotkey.toJson(),
        'smartPasteHotkey': smartPasteHotkey.toJson(),
        'globalBlacklistFolders': globalBlacklistFolders,
        'globalBlacklistFiles': globalBlacklistFiles,
        'autoStart': autoStart,
        'minimizeToTray': minimizeToTray,
        'showNotifications': showNotifications,
        'rightClickMenuEnabled': rightClickMenuEnabled,
        'mergeGlobalRules': mergeGlobalRules,
        'robocopyThreads': robocopyThreads,
        'themeMode': themeMode.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        smartCopyHotkey: json['smartCopyHotkey'] != null
            ? HotkeyDef.fromJson(
                json['smartCopyHotkey'] as Map<String, dynamic>)
            : null,
        smartPasteHotkey: json['smartPasteHotkey'] != null
            ? HotkeyDef.fromJson(
                json['smartPasteHotkey'] as Map<String, dynamic>)
            : null,
        globalBlacklistFolders:
            List<String>.from(json['globalBlacklistFolders'] ?? []),
        globalBlacklistFiles:
            List<String>.from(json['globalBlacklistFiles'] ?? []),
        autoStart: json['autoStart'] as bool? ?? false,
        minimizeToTray: json['minimizeToTray'] as bool? ?? true,
        showNotifications: json['showNotifications'] as bool? ?? true,
        rightClickMenuEnabled: json['rightClickMenuEnabled'] as bool? ?? false,
        mergeGlobalRules: json['mergeGlobalRules'] as bool? ?? true,
        robocopyThreads: json['robocopyThreads'] as int? ?? 8,
        themeMode: _parseThemeMode(json['themeMode'] as String?),
      );
      
  static ThemeModeSetting _parseThemeMode(String? name) {
    if (name == null) return ThemeModeSetting.system;
    try {
      return ThemeModeSetting.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return ThemeModeSetting.system;
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
