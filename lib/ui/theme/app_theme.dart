import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── 调色板 ───────────────────────────────────────────────────
  static const _primary = Color(0xFF6366F1);      // indigo-500
  static const _primaryLight = Color(0xFF818CF8);  // indigo-400
  static const _primaryDark = Color(0xFF4F46E5);   // indigo-600
  static const _secondary = Color(0xFF06B6D4);     // cyan-500
  static const _success = Color(0xFF10B981);       // emerald-500
  static const _warning = Color(0xFFF59E0B);       // amber-500
  static const _error = Color(0xFFEF4444);         // red-500

  // 深色背景层次
  static const _darkBg = Color(0xFF0F1117);
  static const _darkSurface = Color(0xFF1A1D27);
  static const _darkCard = Color(0xFF21242F);
  static const _darkCardHover = Color(0xFF272B38);
  static const _darkBorder = Color(0xFF2E3344);
  static const _darkDivider = Color(0xFF252839);
  static const _darkTextPrimary = Color(0xFFF1F5F9);
  static const _darkTextSecondary = Color(0xFF94A3B8);
  static const _darkTextMuted = Color(0xFF64748B);

  // 浅色背景层次
  static const _lightBg = Color(0xFFF8FAFC);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightCardHover = Color(0xFFF1F5F9);
  static const _lightBorder = Color(0xFFE2E8F0);
  static const _lightDivider = Color(0xFFE2E8F0);
  static const _lightTextPrimary = Color(0xFF0F172A);
  static const _lightTextSecondary = Color(0xFF475569);
  static const _lightTextMuted = Color(0xFF94A3B8);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          secondary: _secondary,
          surface: _darkSurface,
          error: _error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: _darkTextPrimary,
          onError: Colors.white,
          outline: _darkBorder,
          surfaceContainerHighest: _darkCard,
        ),
        scaffoldBackgroundColor: _darkBg,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .copyWith(
          displayLarge: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: _darkTextPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _darkTextPrimary,
            letterSpacing: -0.3,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 14,
            color: _darkTextPrimary,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13,
            color: _darkTextSecondary,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            color: _darkTextMuted,
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: _darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _darkBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: _darkDivider,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkBg,
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: _darkTextMuted,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _error),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryLight,
            side: const BorderSide(color: _darkBorder),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _primaryLight,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return _darkTextMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _primary;
            return _darkCard;
          }),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.transparent;
            }
            return _darkBorder;
          }),
        ),
        iconTheme: const IconThemeData(color: _darkTextSecondary, size: 18),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: _darkCardHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _darkBorder),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            color: _darkTextPrimary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(_darkBorder),
          radius: const Radius.circular(4),
          thickness: WidgetStateProperty.all(4),
        ),
        extensions: const [
          AppColors(
            bg: _darkBg,
            surface: _darkSurface,
            card: _darkCard,
            cardHover: _darkCardHover,
            border: _darkBorder,
            textPrimary: _darkTextPrimary,
            textSecondary: _darkTextSecondary,
            textMuted: _darkTextMuted,
          ),
        ],
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          secondary: _secondary,
          surface: _lightSurface,
          error: _error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: _lightTextPrimary,
          onError: Colors.white,
          outline: _lightBorder,
          surfaceContainerHighest: _lightCard,
        ),
        scaffoldBackgroundColor: _lightBg,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
            .copyWith(
          displayLarge: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: _lightTextPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _lightTextPrimary,
            letterSpacing: -0.3,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _lightTextPrimary,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _lightTextPrimary,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 14,
            color: _lightTextPrimary,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 13,
            color: _lightTextSecondary,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            color: _lightTextMuted,
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _lightTextPrimary,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: _lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _lightBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: _lightDivider,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _lightSurface,
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: _lightTextMuted,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _error),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _lightBorder),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return _lightTextMuted;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _primary;
            return _lightCard;
          }),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.transparent;
            }
            return _lightBorder;
          }),
        ),
        iconTheme: const IconThemeData(color: _lightTextSecondary, size: 18),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: _lightCardHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _lightBorder),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            color: _lightTextPrimary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(_lightBorder),
          radius: const Radius.circular(4),
          thickness: WidgetStateProperty.all(4),
        ),
        extensions: const [
          AppColors(
            bg: _lightBg,
            surface: _lightSurface,
            card: _lightCard,
            cardHover: _lightCardHover,
            border: _lightBorder,
            textPrimary: _lightTextPrimary,
            textSecondary: _lightTextSecondary,
            textMuted: _lightTextMuted,
          ),
        ],
      );

  // 快捷色彩访问
  static Color get primary => _primary;
  static Color get primaryLight => _primaryLight;
  static Color get primaryDark => _primaryDark;
  static Color get secondary => _secondary;
  static Color get success => _success;
  static Color get warning => _warning;
  static Color get error => _error;
  static Color get surface => _darkSurface;
  static Color get card => _darkCard;
  static Color get cardHover => _darkCardHover;
  static Color get border => _darkBorder;
  static Color get textPrimary => _darkTextPrimary;
  static Color get textSecondary => _darkTextSecondary;
  static Color get textMuted => _darkTextMuted;
  static Color get bg => _darkBg;

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [_primary, Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get cyanGradient => const LinearGradient(
        colors: [_secondary, Color(0xFF0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

// ThemeExtension 用于访问扩展颜色
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color cardHover;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.card,
    required this.cardHover,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? cardHover,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) =>
      AppColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        cardHover: cardHover ?? this.cardHover,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardHover: Color.lerp(cardHover, other.cardHover, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }

  // 便捷获取 AppColors
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;
}

// 为了兼容旧代码，我们保留 AppColors 常量，但让它们返回深色
class AppColorsConstants {
  static Color get primary => AppTheme.primary;
  static Color get primaryLight => AppTheme.primaryLight;
  static Color get primaryDark => AppTheme.primaryDark;
  static Color get secondary => AppTheme.secondary;
  static Color get success => AppTheme.success;
  static Color get warning => AppTheme.warning;
  static Color get error => AppTheme.error;
  static LinearGradient get primaryGradient => AppTheme.primaryGradient;
  static LinearGradient get cyanGradient => AppTheme.cyanGradient;
}
