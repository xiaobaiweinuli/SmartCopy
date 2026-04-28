import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/models/copy_task.dart';
import '../../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/duplicate_file_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Header(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CopyPanel(),
                SizedBox(height: 24),
                _ActiveTaskPanel(),
                _TaskHistoryPanel(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('智能复制',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text('过滤黑名单，精准复制你需要的文件',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    )),
              ],
            ),
          ),
          // 快捷键提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _KbdKey(
                    label: provider.settings.smartCopyHotkey.display
                        .split(' + ')
                        .join(' ')),
                Text(' 标记源',
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted)),
                const SizedBox(width: 10),
                _KbdKey(
                    label: provider.settings.smartPasteHotkey.display
                        .split(' + ')
                        .join(' ')),
                Text(' 粘贴',
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _KbdKey extends StatelessWidget {
  final String label;

  const _KbdKey({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary)),
    );
  }
}

class _CopyPanel extends StatefulWidget {
  const _CopyPanel();

  @override
  State<_CopyPanel> createState() => _CopyPanelState();
}

class _CopyPanelState extends State<_CopyPanel> {
  String? _destPath;
  bool _pasting = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hasSource = provider.hasCopySource;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.copy_all_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('复制操作',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  Text('手动指定源与目标目录',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 复制源
          _PathSelector(
            label: '复制源',
            hint: hasSource
                ? provider.copySource!
                : '点击选择文件或文件夹，或使用 Ctrl+Shift+C',
            icon: Icons.folder_open_rounded,
            iconColor: AppTheme.primary,
            isSet: hasSource,
            onSelect: () async {
              final appProvider = context.read<AppProvider>();
              final result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '选择复制源目录',
              );
              if (result != null && mounted) {
                appProvider.setCopySource(result);
              }
            },
            onSelectFile: () async {
              final appProvider = context.read<AppProvider>();
              final result = await FilePicker.platform.pickFiles(
                dialogTitle: '选择复制源文件',
                allowMultiple: false,
              );
              if (result != null && result.files.isNotEmpty && mounted) {
                final path = result.files.first.path;
                if (path != null) {
                  appProvider.setCopySource(path);
                }
              }
            },
            onClear: provider.clearCopySource,
          ),

          const SizedBox(height: 12),
          Divider(color: AppTheme.border),
          const SizedBox(height: 12),

          // 目标目录
          _PathSelector(
            label: '目标目录',
            hint: _destPath ?? '点击选择粘贴目标目录',
            icon: Icons.drive_file_move_outlined,
            iconColor: AppTheme.secondary,
            isSet: _destPath != null,
            onSelect: () async {
              final result = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '选择目标目录',
              );
              if (result != null && mounted) {
                setState(() => _destPath = result);
              }
            },
            onClear: () => setState(() => _destPath = null),
          ),

          const SizedBox(height: 20),

          // 应用规则预览
          if (hasSource) _RulePreview(sourcePath: provider.copySource!),

          const SizedBox(height: 16),

          // 执行按钮
          Row(
            children: [
              Expanded(
                child: SmartButton(
                  label: provider.scanning
                      ? '正在扫描...'
                      : (_pasting ? '复制中...' : '开始智能复制'),
                  icon: Icons.play_arrow_rounded,
                  loading: _pasting || provider.scanning,
                  onTap: (!hasSource || _destPath == null || _pasting || provider.scanning)
                      ? null
                      : _executeCopy,
                ),
              ),
              const SizedBox(width: 10),
              SmartButton(
                label: '清除',
                outlined: true,
                icon: Icons.clear_rounded,
                onTap: () {
                  provider.clearCopySource();
                  setState(() => _destPath = null);
                },
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }

  Future<void> _executeCopy() async {
    if (_destPath == null) return;

    final provider = context.read<AppProvider>();
    if (provider.copySource == null) return;

    setState(() => _pasting = true);

    try {
      // 1. 扫描源目录
      final scanResult = await provider.scanSource(
        provider.copySource!,
        _destPath!,
      );

      if (scanResult == null) {
        return;
      }

      // 2. 检查是否有重复文件
      if (scanResult.duplicates.isNotEmpty && mounted) {
        // 显示重复文件对话框
        final resolution = await showDialog<ConflictResolution>(
          context: context,
          builder: (context) => DuplicateFileDialog(
            duplicates: scanResult.duplicates,
            onCancel: () => Navigator.pop(context),
            onConfirm: (resolution) => Navigator.pop(context, resolution),
          ),
        );

        if (resolution == null) {
          // 用户取消了
          return;
        }

        // 3. 执行复制（带用户选择的策略）
        await provider.executePaste(
          _destPath!,
          scanResult: scanResult,
          resolution: resolution,
        );
      } else {
        // 没有重复文件，直接复制
        await provider.executePaste(
          _destPath!,
          scanResult: scanResult,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pasting = false);
      }
    }
  }
}

class _PathSelector extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final bool isSet;
  final VoidCallback onSelect;
  final VoidCallback? onSelectFile;
  final VoidCallback? onClear;

  const _PathSelector({
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.isSet,
    required this.onSelect,
    this.onSelectFile,
    this.onClear,
  });

  @override
  State<_PathSelector> createState() => _PathSelectorState();
}

class _PathSelectorState extends State<_PathSelector> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bgColor = widget.isSet
        ? widget.iconColor.withValues(alpha: 0.06)
        : _hovered
            ? colors.card
            : colors.bg;
    final borderColor = widget.isSet
        ? widget.iconColor.withValues(alpha: 0.3)
        : _hovered
            ? colors.textSecondary.withValues(alpha: 0.3)
            : colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted)),
            if (widget.isSet) ...[
              const Spacer(),
              GestureDetector(
                onTap: widget.onClear,
                child: Text('清除',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.error.withValues(alpha: 0.8))),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onSelectFile != null && !widget.isSet
                ? null
                : widget.onSelect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: widget.isSet ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.icon,
                      size: 16,
                      color: widget.isSet ? widget.iconColor : colors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isSet ? colors.textSecondary : colors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onSelectFile != null && !widget.isSet) ...[
                    Container(
                      width: 1,
                      height: 16,
                      color: colors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    _HoverText(
                      label: '文件',
                      onTap: widget.onSelectFile!,
                    ),
                    const SizedBox(width: 4),
                    Text('/',
                        style:
                            TextStyle(fontSize: 11, color: colors.textMuted)),
                    const SizedBox(width: 4),
                    _HoverText(
                      label: '目录',
                      onTap: widget.onSelect,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverText extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _HoverText({
    required this.label,
    required this.onTap,
  });

  @override
  State<_HoverText> createState() => _HoverTextState();
}

class _HoverTextState extends State<_HoverText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(widget.label,
            style: TextStyle(
              fontSize: 11,
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 1)
                  : AppTheme.primary,
              fontWeight: _hovered ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    );
  }
}

class _RulePreview extends StatelessWidget {
  final String sourcePath;

  const _RulePreview({required this.sourcePath});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = AppColors.of(context);
    final settings = provider.settings;
    final profile = provider.profiles.isNotEmpty
        ? _findProfile(provider.profiles, sourcePath)
        : null;

    final folders = {
      ...settings.globalBlacklistFolders,
      ...?profile?.blacklistFolders,
    };
    final files = {
      ...settings.globalBlacklistFiles,
      ...?profile?.blacklistFiles,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 13, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('将应用的过滤规则',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
              const Spacer(),
              if (profile != null)
                TagChip(
                  label: '+ ${profile.name}',
                  color: AppTheme.secondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...folders.take(6).map((f) => TagChip(
                    label: f,
                    color: AppTheme.warning,
                    prefixIcon: Icons.folder_off_outlined,
                  )),
              ...files.take(6).map((f) => TagChip(
                    label: f,
                    color: AppTheme.error,
                    prefixIcon: Icons.file_present_outlined,
                  )),
              if (folders.length + files.length > 12)
                TagChip(
                  label: '+${folders.length + files.length - 12} 条',
                  color: colors.textMuted,
                ),
            ],
          ),
        ],
      ),
    );
  }

  dynamic _findProfile(List profiles, String sourcePath) {
    final normSrc = sourcePath.replaceAll('\\', '/').toLowerCase();
    dynamic best;
    int bestDepth = -1;
    for (final profile in profiles) {
      if (!profile.enabled) continue;
      final normPath = profile.folderPath.replaceAll('\\', '/').toLowerCase();
      if (normSrc.startsWith(normPath)) {
        final depth = normPath.split('/').length;
        if (depth > bestDepth) {
          bestDepth = depth;
          best = profile;
        }
      }
    }
    return best;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds < 60) return '${duration.inSeconds} 秒';
  if (duration.inMinutes < 60) return '${duration.inMinutes} 分钟';
  return '${duration.inHours} 小时';
}

class _ActiveTaskPanel extends StatelessWidget {
  const _ActiveTaskPanel();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final task = context.watch<AppProvider>().activeTask;
    if (task == null) return const SizedBox.shrink();

    final progress = task.progress;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary,
                  value: progress > 0 ? progress : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.sourceNameShort,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    if (task.currentFile != null)
                      Text(task.currentFile!,
                          style: TextStyle(
                              fontSize: 11, color: colors.textMuted),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              SmartButton(
                label: '取消',
                small: true,
                outlined: true,
                color: AppTheme.error,
                icon: Icons.stop_rounded,
                onTap: context.read<AppProvider>().cancelCurrentTask,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatPill(label: '已复制', value: '${task.copiedFiles}',
                  color: AppTheme.success),
              const SizedBox(width: 8),
              _StatPill(label: '跳过', value: '${task.skippedFiles}',
                  color: AppTheme.warning),
              if (task.failedFiles > 0) ...[
                const SizedBox(width: 8),
                _StatPill(label: '失败', value: '${task.failedFiles}',
                    color: AppTheme.error),
              ],
              const Spacer(),
              if (task.bytesTotal > 0)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% • ${_formatBytes(task.bytesCopied)}/${_formatBytes(task.bytesTotal)}',
                  style: TextStyle(
                      fontSize: 11, color: colors.textMuted),
                ),
            ],
          ),
          // 显示速度和剩余时间（如果有）
          if (task.speedBytesPerSecond != null && task.bytesTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.speed_rounded, size: 14, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatBytes(task.speedBytesPerSecond!.round())}/秒',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                  if (task.estimatedRemaining != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.timer_rounded, size: 14, color: colors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '剩余约 ${_formatDuration(task.estimatedRemaining!)}',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05).then().shimmer(
      duration: 2.seconds,
      color: AppTheme.primary.withValues(alpha: 0.05),
      delay: 500.ms,
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _TaskHistoryPanel extends StatelessWidget {
  const _TaskHistoryPanel();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final history = provider.taskHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        SectionHeader(
          title: '最近记录',
          action: TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text('清空'),
            onPressed: provider.clearHistory,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...history.take(10).map((task) => _TaskHistoryItem(task: task)),
      ],
    );
  }
}

class _TaskHistoryItem extends StatelessWidget {
  final CopyTask task;

  const _TaskHistoryItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isSuccess = task.status == CopyStatus.success;
    final isFailed = task.status == CopyStatus.failed;
    final statusColor = isSuccess
        ? AppTheme.success
        : isFailed
            ? AppTheme.error
            : colors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(
              isSuccess
                  ? Icons.check_rounded
                  : isFailed
                      ? Icons.error_outline
                      : Icons.cancel_outlined,
              size: 15,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.sourceNameShort,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text(
                      _formatDest(task.destPath),
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${task.copiedFiles} 个文件',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
              Text(
                _formatTime(task.finishedAt ?? task.startedAt),
                style: TextStyle(fontSize: 10, color: colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDest(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.length > 2
        ? '.../${parts[parts.length - 2]}/${parts.last}'
        : path;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${dt.month}/${dt.day}';
  }
}
