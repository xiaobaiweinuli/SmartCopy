import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../theme/app_theme.dart';

class SideNav extends StatelessWidget {
  const SideNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final screen = provider.currentScreen;
    final colors = AppColors.of(context);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border, width: 1)),
      ),
      child: Column(
        children: [
          // ── Logo ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.content_copy_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SmartCopy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        )),
                    Text('智能过滤复制',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textMuted,
                        )),
                  ],
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideX(begin: -0.2, duration: 350.ms),

          const SizedBox(height: 16),

          // ── 复制源状态卡片 ────────────────────────────────────
          _CopySourceIndicator(),

          const SizedBox(height: 8),

          // ── 导航条目 ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                const _NavSection(label: '操作'),
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  active: screen == AppScreen.home,
                  onTap: () => provider.navigate(AppScreen.home),
                  delay: 50,
                ),
                const SizedBox(height: 16),
                const _NavSection(label: '规则'),
                _NavItem(
                  icon: Icons.folder_special_rounded,
                  label: '文件夹配置',
                  badge: provider.profiles.isNotEmpty
                      ? '${provider.profiles.length}'
                      : null,
                  active: screen == AppScreen.profiles,
                  onTap: () => provider.navigate(AppScreen.profiles),
                  delay: 100,
                ),
                _NavItem(
                  icon: Icons.block_rounded,
                  label: '全局黑名单',
                  badge: () {
                    final n = provider.settings.globalBlacklistFolders.length +
                        provider.settings.globalBlacklistFiles.length;
                    return n > 0 ? '$n' : null;
                  }(),
                  active: screen == AppScreen.globalRules,
                  onTap: () => provider.navigate(AppScreen.globalRules),
                  delay: 150,
                ),
                const SizedBox(height: 16),
                const _NavSection(label: '系统'),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  active: screen == AppScreen.settings,
                  onTap: () => provider.navigate(AppScreen.settings),
                  delay: 200,
                ),
              ],
            ),
          ),

          // ── 底部版本 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('v1.0.0  ·  Windows',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 复制源指示卡 ─────────────────────────────────────────────
class _CopySourceIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final colors = AppColors.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: provider.hasCopySource
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.snippet_folder_rounded,
                          size: 14, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('已标记源',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              )),
                          Text(
                            _shortPath(provider.copySource ?? ''),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: provider.clearCopySource,
                      child: Icon(Icons.close,
                          size: 14, color: colors.textMuted),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.95, 0.95)),
            )
          : const SizedBox.shrink(),
    );
  }

  String _shortPath(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : path;
  }
}

// ─── 导航章节标签 ─────────────────────────────────────────────
class _NavSection extends StatelessWidget {
  final String label;

  const _NavSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─── 导航条目 ────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;
  final int delay;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
    this.delay = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.active;
    final colors = AppColors.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.12)
                : _hovered
                    ? colors.border.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: isActive ? AppTheme.primary : colors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? AppTheme.primary
                        : colors.textSecondary,
                  ),
                ),
              ),
              if (widget.badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withValues(alpha: 0.2)
                        : colors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppTheme.primary
                          : colors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ).animate().fadeIn(
          delay: Duration(milliseconds: widget.delay), duration: 300.ms),
    );
  }
}
