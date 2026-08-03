import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ╔══════════════════════════════════════════════════════════╗
/// ║          APP THEME  ─  PREMIUM DARK GAMING               ║
/// ║  Palette: Midnight Navy + Electric Violet + Neon Cyan    ║
/// ╚══════════════════════════════════════════════════════════╝
abstract final class AppTheme {
  // ── Seed colours ────────────────────────────────────────────
  static const Color seed          = Color(0xFF7C3AED); // electric violet
  static const Color neonCyan      = Color(0xFF22D3EE); // highlight / secondary
  static const Color amberGold     = Color(0xFFF59E0B); // tertiary / XP
  static const Color roseRed       = Color(0xFFEF4444); // danger / minesweeper
  static const Color emeraldGreen  = Color(0xFF10B981); // success / win

  // ── Public API ───────────────────────────────────────────────
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  // ── Builder ──────────────────────────────────────────────────
  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme : _lightScheme;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      // ── Text ────────────────────────────────────────────────
      textTheme: _textTheme(base.textTheme, scheme.onSurface),

      // ── AppBar ──────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),

      // ── Card ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        margin: EdgeInsets.zero,
        color: isDark
            ? const Color(0xFF141B2D)
            : scheme.surfaceContainerLow,
        shadowColor: isDark
            ? scheme.primary.withValues(alpha: 0.25)
            : Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide(
                  color: scheme.primary.withValues(alpha: 0.18),
                  width: 1,
                )
              : BorderSide.none,
        ),
      ),

      // ── Navigation bar (bottom) ──────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF0D1326).withValues(alpha: 0.9)
            : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom sheet ────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? const Color(0xFF141B2D)
            : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // ── Filled button ────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Text button ──────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Icon button ──────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
        ),
      ),

      // ── Dialog ──────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? const Color(0xFF141B2D)
            : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),

      // ── List tile ────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: scheme.primary,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ── Switch ───────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor:
            WidgetStateProperty.all(scheme.outlineVariant),
      ),

      // ── Chip ────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        selectedColor: scheme.primaryContainer,
        backgroundColor: isDark
            ? const Color(0xFF141B2D)
            : scheme.surfaceContainerLow,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Light colour scheme ──────────────────────────────────────
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary:              Color(0xFF6D28D9),
    onPrimary:            Colors.white,
    primaryContainer:     Color(0xFFEDE9FE),
    onPrimaryContainer:   Color(0xFF2E1065),
    secondary:            Color(0xFF0891B2),
    onSecondary:          Colors.white,
    secondaryContainer:   Color(0xFFCFF1FA),
    onSecondaryContainer: Color(0xFF0C3040),
    tertiary:             Color(0xFFD97706),
    onTertiary:           Colors.white,
    tertiaryContainer:    Color(0xFFFEF3C7),
    onTertiaryContainer:  Color(0xFF3B1C00),
    error:                Color(0xFFDC2626),
    onError:              Colors.white,
    errorContainer:       Color(0xFFFEE2E2),
    onErrorContainer:     Color(0xFF7F1D1D),
    surface:              Color(0xFFF7F7FC),
    onSurface:            Color(0xFF181620),
    onSurfaceVariant:     Color(0xFF5F6472),
    outline:              Color(0xFF7180A0),
    outlineVariant:       Color(0xFFD8DCE7),
    surfaceContainerLowest:  Colors.white,
    surfaceContainerLow:     Color(0xFFFFFFFF),
    surfaceContainer:        Color(0xFFF3F4F8),
    surfaceContainerHigh:    Color(0xFFE7E9F0),
    surfaceContainerHighest: Color(0xFFD8DCE7),
    inverseSurface:       Color(0xFF181620),
    onInverseSurface:     Color(0xFFF7F7FC),
    inversePrimary:       Color(0xFFC4B5FD),
    shadow:               Color(0xFF000000),
    scrim:                Color(0xFF000000),
  );

  // ── Dark colour scheme ───────────────────────────────────────
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary:              Color(0xFFA78BFA), // soft violet
    onPrimary:            Color(0xFF1E0A3C),
    primaryContainer:     Color(0xFF3B1F6E),
    onPrimaryContainer:   Color(0xFFEDE9FE),
    secondary:            Color(0xFF22D3EE), // neon cyan
    onSecondary:          Color(0xFF002B38),
    secondaryContainer:   Color(0xFF004C5E),
    onSecondaryContainer: Color(0xFFB2F5FF),
    tertiary:             Color(0xFFFBBF24), // gold
    onTertiary:           Color(0xFF2D1900),
    tertiaryContainer:    Color(0xFF4A2E00),
    onTertiaryContainer:  Color(0xFFFDE68A),
    error:                Color(0xFFFCA5A5),
    onError:              Color(0xFF7F1D1D),
    errorContainer:       Color(0xFF991B1B),
    onErrorContainer:     Color(0xFFFFE4E1),
    surface:              Color(0xFF080C18), // deep midnight
    onSurface:            Color(0xFFE8E6FF),
    onSurfaceVariant:     Color(0xFF9B9EC8),
    outline:              Color(0xFF5C6080),
    outlineVariant:       Color(0xFF252847),
    surfaceContainerLowest:  Color(0xFF04060F),
    surfaceContainerLow:     Color(0xFF0D1326),
    surfaceContainer:        Color(0xFF141B2D),
    surfaceContainerHigh:    Color(0xFF1C2438),
    surfaceContainerHighest: Color(0xFF252D44),
    inverseSurface:       Color(0xFFE8E6FF),
    onInverseSurface:     Color(0xFF0F0A1E),
    inversePrimary:       Color(0xFF6D28D9),
    shadow:               Color(0xFF000000),
    scrim:                Color(0xFF000000),
  );

  // ── Type scale ───────────────────────────────────────────────
  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontSize: 57,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            color: onSurface,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: onSurface,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: onSurface,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: onSurface,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: onSurface,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: onSurface,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.5,
            color: onSurface,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.45,
            color: onSurface,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.4,
            color: onSurface,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: onSurface,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: onSurface,
          ),
        )
        .apply(displayColor: onSurface, bodyColor: onSurface);
  }
}

/// Gradient text widget — dùng cho tiêu đề nổi bật.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
    this.textAlign,
  });

  final String text;
  final Gradient gradient;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

/// Glass-morphism container.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: br,
          color: backgroundColor ??
              (isDark
                  ? const Color(0xFF141B2D).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.7)),
          border: Border.all(
            color: borderColor ??
                (isDark
                    ? const Color(0xFFA78BFA).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.6)),
            width: 1,
          ),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Neon glow decoration helper.
BoxDecoration neonGlowDecoration({
  required Color color,
  double radius = 20,
  double blurRadius = 20,
  double spreadRadius = 0,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: 0.4),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ],
  );
}

/// Premium gradient definitions.
abstract final class AppGradients {
  static const violetCyan = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldAmber = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emeraldTeal = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const nightSky = LinearGradient(
    colors: [Color(0xFF080C18), Color(0xFF0D1326), Color(0xFF141B2D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const roseGold = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Style helper dùng chung cho nút bấm.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

/// Khoảng cách / padding chuẩn hoá 8dp grid.
abstract final class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Thang radius.
abstract final class AppRadius {
  static const Radius sm  = Radius.circular(8);
  static const Radius md  = Radius.circular(12);
  static const Radius lg  = Radius.circular(16);
  static const Radius xl  = Radius.circular(20);
  static const Radius xxl = Radius.circular(28);
}