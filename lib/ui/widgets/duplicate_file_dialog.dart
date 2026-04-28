import 'package:flutter/material.dart';
import '../../core/models/copy_task.dart';
import '../theme/app_theme.dart';

class DuplicateFileDialog extends StatefulWidget {
  final List<DuplicateFile> duplicates;
  final VoidCallback onCancel;
  final Function(ConflictResolution) onConfirm;

  const DuplicateFileDialog({
    super.key,
    required this.duplicates,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<DuplicateFileDialog> createState() => _DuplicateFileDialogState();
}

class _DuplicateFileDialogState extends State<DuplicateFileDialog> {
  ConflictResolution _selectedResolution = ConflictResolution.keepNewer;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发现 ${widget.duplicates.length} 个重复文件',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '请选择如何处理这些文件',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 文件列表
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.duplicates.length,
                  itemBuilder: (context, index) {
                    final duplicate = widget.duplicates[index];
                    return _DuplicateFileItem(
                      duplicate: duplicate,
                      formatBytes: _formatBytes,
                      formatDate: _formatDate,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 冲突解决选项
            Text(
              '选择处理方式',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _ResolutionOption(
              title: '保留较新的',
              description: '如果源文件比目标文件新，则覆盖',
              value: ConflictResolution.keepNewer,
              groupValue: _selectedResolution,
              onChanged: (value) {
                setState(() {
                  _selectedResolution = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            _ResolutionOption(
              title: '跳过重复',
              description: '保留目标文件，不覆盖',
              value: ConflictResolution.skip,
              groupValue: _selectedResolution,
              onChanged: (value) {
                setState(() {
                  _selectedResolution = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            _ResolutionOption(
              title: '覆盖所有',
              description: '用源文件覆盖所有目标文件',
              value: ConflictResolution.overwrite,
              groupValue: _selectedResolution,
              onChanged: (value) {
                setState(() {
                  _selectedResolution = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => widget.onConfirm(_selectedResolution),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '继续复制',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

class _DuplicateFileItem extends StatelessWidget {
  final DuplicateFile duplicate;
  final String Function(int) formatBytes;
  final String Function(DateTime) formatDate;

  const _DuplicateFileItem({
    required this.duplicate,
    required this.formatBytes,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件名
          Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  duplicate.displayPath,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 文件信息对比
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '源文件',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatBytes(duplicate.source.size)} • ${formatDate(duplicate.source.modified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目标文件',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatBytes(duplicate.dest.size)} • ${formatDate(duplicate.dest.modified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionOption extends StatelessWidget {
  final String title;
  final String description;
  final ConflictResolution value;
  final ConflictResolution groupValue;
  final ValueChanged<ConflictResolution?> onChanged;

  const _ResolutionOption({
    required this.title,
    required this.description,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : colors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // 自定义单选按钮指示器，避免使用 Radio 组件的弃用属性
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : colors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
