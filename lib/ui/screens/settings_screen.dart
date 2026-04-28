import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/models/app_settings.dart';
import '../../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SettingsHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HotkeySection(),
                SizedBox(height: 20),
                _AppearanceSection(),
                SizedBox(height: 20),
                _SystemSection(),
                SizedBox(height: 20),
                _BehaviorSection(),
                SizedBox(height: 20),
                _AboutSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.settings_rounded,
                size: 17, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设置',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              Text('自定义快捷键、托盘行为与系统集成',
                  style: TextStyle(fontSize: 12, color: colors.textMuted)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── 快捷键 ──────────────────────────────────────────────────
class _HotkeySection extends StatelessWidget {
  const _HotkeySection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '全局快捷键',
          subtitle: '在任意窗口下均可触发，不与原生 Ctrl+C/V 冲突',
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              _HotkeyRow(
                label: '标记复制源（Smart Copy）',
                subtitle: '捕获剪贴板中的文件作为复制源',
                hotkey: settings.smartCopyHotkey,
                icon: Icons.copy_rounded,
                onChanged: (hk) =>
                    provider.updateHotkeys(copyHotkey: hk),
              ),
              Divider(height: 1, color: colors.border),
              _HotkeyRow(
                label: '触发智能粘贴（Smart Paste）',
                subtitle: '唤起主窗口以选择目标目录粘贴',
                hotkey: settings.smartPasteHotkey,
                icon: Icons.paste_rounded,
                onChanged: (hk) =>
                    provider.updateHotkeys(pasteHotkey: hk),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }
}

class _HotkeyRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final HotkeyDef hotkey;
  final IconData icon;
  final ValueChanged<HotkeyDef> onChanged;

  const _HotkeyRow({
    required this.label,
    required this.subtitle,
    required this.hotkey,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary)),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: colors.textMuted)),
              ],
            ),
          ),
          _HotkeyBadge(
            hotkey: hotkey,
            onEdit: () =>
                _showHotkeyEditor(context, hotkey, label, onChanged),
          ),
        ],
      ),
    );
  }

  void _showHotkeyEditor(BuildContext context, HotkeyDef current,
      String label, ValueChanged<HotkeyDef> onChanged) {
    showDialog(
      context: context,
      builder: (_) => _HotkeyEditorDialog(
        title: label,
        current: current,
        onSave: onChanged,
      ),
    );
  }
}

class _HotkeyBadge extends StatefulWidget {
  final HotkeyDef hotkey;
  final VoidCallback onEdit;

  const _HotkeyBadge({required this.hotkey, required this.onEdit});

  @override
  State<_HotkeyBadge> createState() => _HotkeyBadgeState();
}

class _HotkeyBadgeState extends State<_HotkeyBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.primary.withValues(alpha: 0.12)
                : colors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _hovered
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.hotkey.display,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _hovered ? AppTheme.primary : colors.textSecondary,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_rounded,
                  size: 12,
                  color: _hovered ? AppTheme.primary : colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 热键编辑对话框 ──────────────────────────────────────────
class _HotkeyEditorDialog extends StatefulWidget {
  final String title;
  final HotkeyDef current;
  final ValueChanged<HotkeyDef> onSave;

  const _HotkeyEditorDialog({
    required this.title,
    required this.current,
    required this.onSave,
  });

  @override
  State<_HotkeyEditorDialog> createState() => _HotkeyEditorDialogState();
}

class _HotkeyEditorDialogState extends State<_HotkeyEditorDialog> {
  late bool _ctrl;
  late bool _shift;
  late bool _alt;
  late String _key;

  static const _keys = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = widget.current.ctrl;
    _shift = widget.current.shift;
    _alt = widget.current.alt;
    _key = widget.current.key.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final previewDef = HotkeyDef(
        key: _key, ctrl: _ctrl, shift: _shift, alt: _alt);

    return Dialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编辑快捷键',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            Text(widget.title,
                style: TextStyle(fontSize: 12, color: colors.textMuted)),

            const SizedBox(height: 20),

            // 修饰键
            Text('修饰键',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                _ModKey(label: 'Ctrl', active: _ctrl,
                    onTap: () => setState(() => _ctrl = !_ctrl)),
                const SizedBox(width: 8),
                _ModKey(label: 'Shift', active: _shift,
                    onTap: () => setState(() => _shift = !_shift)),
                const SizedBox(width: 8),
                _ModKey(label: 'Alt', active: _alt,
                    onTap: () => setState(() => _alt = !_alt)),
              ],
            ),

            const SizedBox(height: 16),

            // 主键
            Text('主键',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _keys.map((k) {
                final isSelected = _key == k;
                return GestureDetector(
                  onTap: () => setState(() => _key = k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : colors.bg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : colors.border),
                    ),
                    child: Text(k,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : colors.textSecondary)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // 预览
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                previewDef.display,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: AppTheme.primary),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(HotkeyDef(
                          key: _key,
                          ctrl: _ctrl,
                          shift: _shift,
                          alt: _alt));
                      Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModKey extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModKey(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withValues(alpha: 0.15) : colors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? AppTheme.primary : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppTheme.primary : colors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── 外观设置 ───────────────────────────────────────────────
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '外观', subtitle: '主题与颜色'),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.palette_rounded,
                        size: 16, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('主题',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.textPrimary)),
                        Text(
                            _getThemeModeLabel(settings.themeMode),
                            style: TextStyle(
                                fontSize: 11, color: colors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ThemeOption(
                    label: '浅色',
                    icon: Icons.light_mode_rounded,
                    selected: settings.themeMode == ThemeModeSetting.light,
                    onTap: () => provider.updateThemeMode(ThemeModeSetting.light),
                  ),
                  const SizedBox(width: 8),
                  _ThemeOption(
                    label: '深色',
                    icon: Icons.dark_mode_rounded,
                    selected: settings.themeMode == ThemeModeSetting.dark,
                    onTap: () => provider.updateThemeMode(ThemeModeSetting.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeOption(
                    label: '跟随系统',
                    icon: Icons.settings_rounded,
                    selected: settings.themeMode == ThemeModeSetting.system,
                    onTap: () => provider.updateThemeMode(ThemeModeSetting.system),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05);
  }
  
  String _getThemeModeLabel(ThemeModeSetting mode) {
    switch (mode) {
      case ThemeModeSetting.light:
        return '浅色主题';
      case ThemeModeSetting.dark:
        return '深色主题';
      case ThemeModeSetting.system:
        return '跟随系统设置';
    }
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : colors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : colors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppTheme.primary
                    : colors.textMuted,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppTheme.primary
                      : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 系统集成设置 ─────────────────────────────────────────────
class _SystemSection extends StatelessWidget {
  const _SystemSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '系统集成', subtitle: '托盘、开机启动与右键菜单'),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // 开机启动开关（特殊：有状态反馈，与右键菜单一致）
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: settings.autoStart
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : colors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.launch_rounded,
                          size: 16,
                          color: settings.autoStart
                              ? AppTheme.primary
                              : colors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('开机自动启动',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary)),
                          Text(
                              settings.autoStart
                                  ? '已注册：系统启动时自动运行'
                                  : '注册到 HKCU\\Run（无需管理员权限）',
                              style: TextStyle(
                                  fontSize: 11, color: colors.textMuted)),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: settings.autoStart,
                        onChanged: (_) => provider.toggleAutoStart(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              _SettingToggle(
                icon: Icons.minimize_rounded,
                label: '关闭时最小化到托盘',
                subtitle: '关闭主窗口时保持后台运行',
                value: settings.minimizeToTray,
                onChanged: (v) => provider.updateSetting(minimizeToTray: v),
              ),
              Divider(height: 1, color: colors.border),
              _SettingToggle(
                icon: Icons.notifications_rounded,
                label: '完成通知',
                subtitle: '复制完成后显示系统通知',
                value: settings.showNotifications,
                onChanged: (v) =>
                    provider.updateSetting(showNotifications: v),
              ),
              Divider(height: 1, color: colors.border),
              // 右键菜单开关（特殊：有状态反馈）
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: settings.rightClickMenuEnabled
                            ? AppTheme.success.withValues(alpha: 0.12)
                            : colors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.menu_rounded,
                          size: 16,
                          color: settings.rightClickMenuEnabled
                              ? AppTheme.success
                              : colors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('右键菜单集成',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary)),
                          Text(
                              settings.rightClickMenuEnabled
                                  ? '已注册：右键文件夹可见 Smart Copy/Paste'
                                  : '注册到 HKCU（无需管理员权限）',
                              style: TextStyle(
                                  fontSize: 11, color: colors.textMuted)),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: settings.rightClickMenuEnabled,
                        onChanged: (_) => provider.toggleRightClickMenu(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

// ─── 行为设置 ─────────────────────────────────────────────────
class _BehaviorSection extends StatelessWidget {
  const _BehaviorSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '复制行为', subtitle: 'Robocopy 引擎参数'),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              _SettingToggle(
                icon: Icons.merge_type_rounded,
                label: '叠加全局规则',
                subtitle: '文件夹配置的规则将在全局规则基础上追加',
                value: settings.mergeGlobalRules,
                onChanged: (v) =>
                    provider.updateSetting(mergeGlobalRules: v),
              ),
              Divider(height: 1, color: colors.border),
              // 多线程滑块
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.speed_rounded,
                          size: 16, color: AppTheme.secondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Robocopy 并发线程',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textPrimary)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${settings.robocopyThreads} 线程',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.secondary),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              activeTrackColor: AppTheme.secondary,
                              thumbColor: AppTheme.secondary,
                              inactiveTrackColor: colors.border,
                              overlayColor:
                                  AppTheme.secondary.withValues(alpha: 0.15),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                            ),
                            child: Slider(
                              min: 1,
                              max: 16,
                              divisions: 15,
                              value: settings.robocopyThreads.toDouble(),
                              onChanged: (v) => provider.updateSetting(
                                  robocopyThreads: v.toInt()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05);
  }
}

// ─── 关于 ─────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.content_copy_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SmartCopy v1.0.0',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                Text(
                    '基于 Flutter + Robocopy 的智能过滤复制工具\n绿色免安装  ·  仅限 Windows',
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                        height: 1.6)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(
                  label: '绿色版', color: AppTheme.success, dot: true),
              const SizedBox(height: 4),
              StatusBadge(
                  label: 'Robocopy 引擎',
                  color: AppTheme.secondary,
                  dot: false),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ─── 通用开关行 ──────────────────────────────────────────────
class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : colors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: value ? AppTheme.primary : colors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
