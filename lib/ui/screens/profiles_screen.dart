import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/folder_profile.dart';
import '../../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  FolderProfile? _selected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profiles = provider.profiles;
    final colors = AppColors.of(context);

    return Row(
      children: [
        // 左侧列表
        SizedBox(
          width: 280,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colors.border)),
            ),
            child: Column(
              children: [
                _ProfileListHeader(
                  onAdd: () => _showAddDialog(context),
                ),
                Expanded(
                  child: profiles.isEmpty
                      ? EmptyState(
                          icon: Icons.folder_special_outlined,
                          title: '暂无文件夹配置',
                          subtitle: '添加文件夹以设置专属过滤规则',
                          action: SmartButton(
                            label: '添加配置',
                            icon: Icons.add,
                            onTap: () => _showAddDialog(context),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: profiles.length,
                          itemBuilder: (context, i) => _ProfileListTile(
                            profile: profiles[i],
                            isSelected:
                                _selected?.id == profiles[i].id,
                            onTap: () =>
                                setState(() => _selected = profiles[i]),
                            onDelete: () {
                              if (_selected?.id == profiles[i].id) {
                                setState(() => _selected = null);
                              }
                              provider.deleteProfile(profiles[i].id);
                            },
                          ).animate().fadeIn(
                              delay: Duration(milliseconds: i * 50),
                              duration: 250.ms),
                        ),
                ),
              ],
            ),
          ),
        ),

        // 右侧详情
        Expanded(
          child: _selected == null
              ? const Center(
                  child: EmptyState(
                    icon: Icons.touch_app_outlined,
                    title: '选择一个配置',
                    subtitle: '从左侧列表选择文件夹配置以编辑其过滤规则',
                  ),
                )
              : _ProfileEditor(
                  key: ValueKey(_selected!.id),
                  profile: _selected!,
                  onSave: (updated) {
                    provider.updateProfile(updated);
                    setState(() => _selected = updated);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final appProvider = context.read<AppProvider>();
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择要配置的文件夹',
    );
    if (result == null || !mounted) return;

    final name = _folderName(result);
    final profile = FolderProfile(
      id: const Uuid().v4(),
      name: name,
      folderPath: result,
    );
    await appProvider.addProfile(profile);
    setState(() =>
        _selected = appProvider.profiles.isEmpty ? null : appProvider.profiles.last);
  }

  String _folderName(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : path;
  }
}

// ─── 列表头 ──────────────────────────────────────────────────
class _ProfileListHeader extends StatelessWidget {
  final VoidCallback onAdd;

  const _ProfileListHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text('文件夹配置',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text('添加',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 列表项 ──────────────────────────────────────────────────
class _ProfileListTile extends StatefulWidget {
  final FolderProfile profile;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProfileListTile({
    required this.profile,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ProfileListTile> createState() => _ProfileListTileState();
}

class _ProfileListTileState extends State<_ProfileListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = widget.profile;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primary.withValues(alpha: 0.1)
                : _hovered
                    ? colors.cardHover
                    : colors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.enabled
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : colors.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  size: 17,
                  color: p.enabled ? AppTheme.primary : colors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    Text('${p.totalRules} 条规则',
                        style: TextStyle(
                            fontSize: 11, color: colors.textMuted)),
                  ],
                ),
              ),
              if (_hovered || widget.isSelected)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(Icons.delete_outline,
                      size: 16, color: AppTheme.error.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile 编辑器 ──────────────────────────────────────────
class _ProfileEditor extends StatefulWidget {
  final FolderProfile profile;
  final ValueChanged<FolderProfile> onSave;

  const _ProfileEditor({super.key, required this.profile, required this.onSave});

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _nameCtrl;
  late List<String> _folders;
  late List<String> _files;
  late bool _enabled;
  final _folderCtrl = TextEditingController();
  final _fileCtrl = TextEditingController();
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p.name);
    _folders = List.from(p.blacklistFolders);
    _files = List.from(p.blacklistFiles);
    _enabled = p.enabled;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _folderCtrl.dispose();
    _fileCtrl.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  void _save() {
    final updated = widget.profile.copyWith(
      name: _nameCtrl.text.trim().isEmpty
          ? widget.profile.name
          : _nameCtrl.text.trim(),
      blacklistFolders: _folders,
      blacklistFiles: _files,
      enabled: _enabled,
    );
    widget.onSave(updated);
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = widget.profile;
    return Column(
      children: [
        // 顶部工具栏
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameCtrl,
                  onChanged: (_) => _markDirty(),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              // 启用开关
              Row(
                children: [
                  Text(_enabled ? '启用' : '禁用',
                      style: TextStyle(
                          fontSize: 12, color: colors.textMuted)),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _enabled,
                      onChanged: (v) {
                        setState(() => _enabled = v);
                        _markDirty();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              if (_dirty)
                SmartButton(
                  label: '保存',
                  icon: Icons.save_rounded,
                  onTap: _save,
                  small: true,
                )
                    .animate()
                    .fadeIn(duration: 150.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
            ],
          ),
        ),

        // 内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 路径信息
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: InfoRow(
                    label: '监控路径',
                    value: p.folderPath,
                    valueColor: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // 文件夹黑名单
                SectionHeader(
                  title: '排除文件夹',
                  subtitle: '匹配此列表的文件夹将被跳过（支持 * 通配符）',
                  action: Text('${_folders.length} 条',
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted)),
                ),
                const SizedBox(height: 10),
                _RuleInput(
                  controller: _folderCtrl,
                  hint: '如：node_modules、.git、dist',
                  icon: Icons.folder_off_rounded,
                  iconColor: AppTheme.warning,
                  onAdd: () => _addFolder(_folderCtrl.text.trim()),
                ),
                const SizedBox(height: 8),
                _RuleList(
                  items: _folders,
                  color: AppTheme.warning,
                  icon: Icons.folder_off_outlined,
                  onDelete: (item) {
                    setState(() => _folders.remove(item));
                    _markDirty();
                  },
                ),

                const SizedBox(height: 20),

                // 文件黑名单
                SectionHeader(
                  title: '排除文件',
                  subtitle: '匹配此列表的文件将被跳过（支持 * 通配符，如 *.log）',
                  action: Text('${_files.length} 条',
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted)),
                ),
                const SizedBox(height: 10),
                _RuleInput(
                  controller: _fileCtrl,
                  hint: '如：*.log、*.tmp、Thumbs.db',
                  icon: Icons.file_present_outlined,
                  iconColor: AppTheme.error,
                  onAdd: () => _addFile(_fileCtrl.text.trim()),
                ),
                const SizedBox(height: 8),
                _RuleList(
                  items: _files,
                  color: AppTheme.error,
                  icon: Icons.file_present_outlined,
                  onDelete: (item) {
                    setState(() => _files.remove(item));
                    _markDirty();
                  },
                ),

                // 常用模板快捷添加
                const SizedBox(height: 20),
                _QuickTemplates(
                  onAddFolders: (list) {
                    setState(() {
                      for (final f in list) {
                        if (!_folders.contains(f)) _folders.add(f);
                      }
                    });
                    _markDirty();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addFolder(String v) {
    if (v.isEmpty || _folders.contains(v)) {
      _folderCtrl.clear();
      return;
    }
    setState(() => _folders.add(v));
    _folderCtrl.clear();
    _markDirty();
  }

  void _addFile(String v) {
    if (v.isEmpty || _files.contains(v)) {
      _fileCtrl.clear();
      return;
    }
    setState(() => _files.add(v));
    _fileCtrl.clear();
    _markDirty();
  }
}

// ─── 规则输入框 ──────────────────────────────────────────────
class _RuleInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onAdd;

  const _RuleInput({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SmartTextField(
            hint: hint,
            controller: controller,
            prefixIcon: icon,
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 8),
        SmartButton(
          label: '添加',
          icon: Icons.add,
          onTap: onAdd,
          color: iconColor,
          small: true,
        ),
      ],
    );
  }
}

// ─── 规则列表 ────────────────────────────────────────────────
class _RuleList extends StatelessWidget {
  final List<String> items;
  final Color color;
  final IconData icon;
  final ValueChanged<String> onDelete;

  const _RuleList({
    required this.items,
    required this.color,
    required this.icon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((item) => TagChip(
                label: item,
                color: color,
                prefixIcon: icon,
                onDelete: () => onDelete(item),
              ))
          .toList(),
    );
  }
}

// ─── 常用模板 ────────────────────────────────────────────────
class _QuickTemplates extends StatelessWidget {
  final ValueChanged<List<String>> onAddFolders;

  const _QuickTemplates({required this.onAddFolders});

  static const _templates = [
    _Template('Node.js', ['node_modules', 'dist', '.next', '.nuxt'],
        Icons.code_rounded, Color(0xFF68A063)),
    _Template('Python', ['__pycache__', '.venv', 'venv', '.pytest_cache'],
        Icons.code_rounded, Color(0xFF3572A5)),
    _Template('Android', ['.gradle', 'build', '.idea', 'captures'],
        Icons.android_rounded, Color(0xFF3DDC84)),
    _Template('Git', ['.git', '.svn', '.hg'], Icons.merge_type_rounded,
        Color(0xFFF05133)),
    _Template(
        'Flutter', ['.dart_tool', 'build', '.flutter-plugins'],
        Icons.flutter_dash_rounded, Color(0xFF54C5F8)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '快速模板', subtitle: '一键添加常用框架的过滤规则'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _templates
              .map((t) => _TemplateChip(
                    template: t,
                    onAdd: () => onAddFolders(t.folders),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _Template {
  final String name;
  final List<String> folders;
  final IconData icon;
  final Color color;

  const _Template(this.name, this.folders, this.icon, this.color);
}

class _TemplateChip extends StatefulWidget {
  final _Template template;
  final VoidCallback onAdd;

  const _TemplateChip({required this.template, required this.onAdd});

  @override
  State<_TemplateChip> createState() => _TemplateChipState();
}

class _TemplateChipState extends State<_TemplateChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onAdd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? t.color.withValues(alpha: 0.15)
                : t.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? t.color.withValues(alpha: 0.4)
                  : t.color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(t.icon, size: 13, color: t.color),
              const SizedBox(width: 6),
              Text(t.name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.color)),
              const SizedBox(width: 6),
              Icon(Icons.add, size: 12, color: t.color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
