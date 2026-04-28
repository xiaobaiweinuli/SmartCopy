import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class GlobalRulesScreen extends StatefulWidget {
  const GlobalRulesScreen({super.key});

  @override
  State<GlobalRulesScreen> createState() => _GlobalRulesScreenState();
}

class _GlobalRulesScreenState extends State<GlobalRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _folderCtrl = TextEditingController();
  final _fileCtrl = TextEditingController();
  final _importCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _folderCtrl.dispose();
    _fileCtrl.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final settings = provider.settings;
    final colors = AppColors.of(context);

    return Column(
      children: [
        // ─── 顶部标题栏 ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            border:
                Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.block_rounded,
                        size: 17, color: AppTheme.error),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('全局黑名单',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      Text(
                          '作用于所有复制操作，可与文件夹配置叠加',
                          style: TextStyle(
                              fontSize: 12, color: colors.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  // 统计徽章
                  _StatBadge(
                    icon: Icons.folder_off_rounded,
                    label: '${settings.globalBlacklistFolders.length} 个文件夹',
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  _StatBadge(
                    icon: Icons.file_present_outlined,
                    label: '${settings.globalBlacklistFiles.length} 个文件',
                    color: AppTheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                labelColor: AppTheme.primary,
                unselectedLabelColor: colors.textMuted,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '排除文件夹'),
                  Tab(text: '排除文件'),
                  Tab(text: '从 .gitignore 导入'),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        // ── 内容区 ──────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // 文件夹黑名单
              _RuleTab(
                items: settings.globalBlacklistFolders,
                color: AppTheme.warning,
                icon: Icons.folder_off_rounded,
                inputCtrl: _folderCtrl,
                inputHint: '如：node_modules、.git、dist、build',
                emptyTitle: '暂无全局文件夹排除规则',
                emptySubtitle: '添加规则后将在所有复制操作中排除对应文件夹',
                onAdd: (v) => provider.addGlobalFolder(v),
                onDelete: (v) => provider.removeGlobalFolder(v),
                presets: const [
                  'node_modules', '.git', '.svn', '__pycache__',
                  '.idea', '.vscode', 'dist', 'build', '.gradle',
                  '.dart_tool', '.next', 'vendor', 'Pods',
                ],
              ),

              // 文件黑名单
              _RuleTab(
                items: settings.globalBlacklistFiles,
                color: AppTheme.error,
                icon: Icons.file_present_outlined,
                inputCtrl: _fileCtrl,
                inputHint: '如：*.log、*.tmp、Thumbs.db、.DS_Store',
                emptyTitle: '暂无全局文件排除规则',
                emptySubtitle: '添加规则后将在所有复制操作中排除对应文件',
                onAdd: (v) => provider.addGlobalFile(v),
                onDelete: (v) => provider.removeGlobalFile(v),
                presets: const [
                  '*.log', '*.tmp', '*.temp', 'Thumbs.db',
                  '.DS_Store', '*.pyc', '*.class', '*.o',
                  '*.a', '*.so', '*.dll', '*.exe',
                ],
              ),

              // .gitignore 导入
              _GitignoreImportTab(
                controller: _importCtrl,
                onImport: (content) async {
                  await provider.importFromGitignore(content);
                  _importCtrl.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 规则 Tab ───────────────────────────────────────────────
class _RuleTab extends StatelessWidget {
  final List<String> items;
  final Color color;
  final IconData icon;
  final TextEditingController inputCtrl;
  final String inputHint;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;
  final List<String> presets;

  const _RuleTab({
    required this.items,
    required this.color,
    required this.icon,
    required this.inputCtrl,
    required this.inputHint,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onAdd,
    required this.onDelete,
    required this.presets,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 输入框
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SmartTextField(
                        controller: inputCtrl,
                        hint: inputHint,
                        prefixIcon: icon,
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) {
                            onAdd(v.trim());
                            inputCtrl.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SmartButton(
                      label: '添加规则',
                      icon: Icons.add,
                      color: color,
                      onTap: () {
                        final v = inputCtrl.text.trim();
                        if (v.isNotEmpty) {
                          onAdd(v);
                          inputCtrl.clear();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('快速添加',
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((p) {
                    final isAdded = items.contains(p);
                    return GestureDetector(
                      onTap: isAdded ? null : () => onAdd(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdded
                              ? color.withValues(alpha: 0.12)
                              : colors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAdded
                                ? color.withValues(alpha: 0.35)
                                : colors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdded)
                              Icon(Icons.check, size: 10, color: color),
                            if (isAdded) const SizedBox(width: 3),
                            Text(
                              p,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isAdded ? color : colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 已添加规则
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: EmptyState(
                icon: icon,
                title: emptyTitle,
                subtitle: emptySubtitle,
              ),
            )
          else ...[
            SectionHeader(
              title: '已配置规则',
              action: Text('共 ${items.length} 条',
                  style: TextStyle(
                      fontSize: 11, color: colors.textMuted)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => TagChip(
                        label: item,
                        color: color,
                        prefixIcon: icon,
                        onDelete: () => onDelete(item),
                      )
                          .animate()
                          .fadeIn(duration: 200.ms)
                          .scale(begin: const Offset(0.9, 0.9)))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── .gitignore 导入 Tab ───────────────────────────────────
class _GitignoreImportTab extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onImport;

  const _GitignoreImportTab({
    required this.controller,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF05133).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.merge_type_rounded,
                        size: 16, color: Color(0xFFF05133)),
                  ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('粘贴 .gitignore 内容',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary)),
                          Text('将自动解析并导入到全局规则',
                              style: TextStyle(
                                  fontSize: 12, color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: colors.textSecondary,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          '# 粘贴你的 .gitignore 内容\nnode_modules/\n.git/\n*.log\n...',
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                          fontFamily: 'monospace'),
                      contentPadding: const EdgeInsets.all(14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SmartButton(
                    label: '解析并导入',
                    icon: Icons.upload_rounded,
                    onTap: () {
                      final content = controller.text.trim();
                      if (content.isNotEmpty) onImport(content);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 格式说明
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支持的格式',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary)),
                const SizedBox(height: 10),
                ...[
                  ('node_modules/', '以 / 结尾 → 识别为文件夹规则'),
                  ('*.log', '通配符 → 识别为文件规则'),
                  ('# 注释', '以 # 开头 → 自动忽略'),
                  ('空行', '空行 → 自动忽略'),
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.bg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(item.$1,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: AppTheme.primary)),
                          ),
                          const SizedBox(width: 10),
                          Text(item.$2,
                              style: TextStyle(
                                  fontSize: 11, color: colors.textMuted)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 统计徽章 ────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
