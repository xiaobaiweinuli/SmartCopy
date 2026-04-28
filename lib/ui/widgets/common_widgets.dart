import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

// ─── GlassCard ─────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool hoverable;
  final Color? borderColor;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.hoverable = false,
    this.borderColor,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget card = Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? colors.border,
          width: 1,
        ),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null || hoverable) {
      card = _HoverCard(
        onTap: onTap,
        radius: radius,
        child: card,
      );
    }

    return card;
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  const _HoverCard({
    required this.child,
    this.onTap,
    required this.radius,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? colors.cardHover : colors.card,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: _hovered ? AppTheme.primary.withValues(alpha: 0.4) : colors.border,
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── SmartButton ───────────────────────────────────────────────
class SmartButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final Color? color;
  final bool outlined;
  final bool small;
  final Widget? trailing;

  const SmartButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.color,
    this.outlined = false,
    this.small = false,
    this.trailing,
  });

  @override
  State<SmartButton> createState() => _SmartButtonState();
}

class _SmartButtonState extends State<SmartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? AppTheme.primary;
    final h = widget.small ? 36.0 : 42.0;
    final px = widget.small ? 14.0 : 18.0;
    final fontSize = widget.small ? 12.0 : 13.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: h,
          padding: EdgeInsets.symmetric(horizontal: px),
          decoration: BoxDecoration(
            color: widget.outlined
                ? Colors.transparent
                : (widget.onTap == null
                    ? AppTheme.border
                    : bgColor),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.outlined ? bgColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.outlined ? bgColor : Colors.white,
                  ),
                )
              else if (widget.icon != null)
                Icon(widget.icon,
                    size: widget.small ? 15 : 16,
                    color: widget.outlined ? bgColor : Colors.white),
              if ((widget.icon != null || widget.loading) &&
                  widget.label.isNotEmpty)
                const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: widget.outlined ? bgColor : Colors.white,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 6),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TagChip ───────────────────────────────────────────────────
class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onDelete;
  final IconData? prefixIcon;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.onDelete,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: EdgeInsets.only(
        left: prefixIcon != null ? 6 : 10,
        right: onDelete != null ? 4 : 10,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
              letterSpacing: 0.2,
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 2),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 11, color: c),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── SectionHeader ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                    letterSpacing: 0.5,
                  )),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    )),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─── StatusBadge ───────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.dot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SmartTextField ────────────────────────────────────────────
class SmartTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;

  const SmartTextField({
    super.key,
    required this.hint,
    this.controller,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      validator: validator,
      inputFormatters: inputFormatters,
      style: TextStyle(fontSize: 13, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 16, color: colors.textMuted)
            : null,
        suffix: suffix,
      ),
    );
  }
}

// ─── InfoRow ───────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                )),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor ?? colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AnimatedSnackBar ──────────────────────────────────────────
class AppSnackBar {
  static void show(
    dynamic messengerOrContext,
    String message, {
    bool isError = false,
  }) {
    final ScaffoldMessengerState messenger;
    if (messengerOrContext is BuildContext) {
      messenger = ScaffoldMessenger.of(messengerOrContext);
    } else if (messengerOrContext is ScaffoldMessengerState) {
      messenger = messengerOrContext;
    } else {
      return; // 无效参数
    }
    
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── EmptyState ────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppTheme.primary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              )),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
    );
  }
}
