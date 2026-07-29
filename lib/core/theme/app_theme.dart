import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design tokens chuẩn hoá cho toàn app — tránh "lè lọe" màu sắc.
///
/// Mọi màn (Home, Sudoku, 2048, Thành tích, Cài đặt) đều dùng:
///   - Cùng một palette primary/secondary/tertiary
///   - Cùng một thang radius (8 / 12 / 16 / 20 / 28)
///   - Cùng một thang spacing (4 / 8 / 12 / 16 / 20 / 24 / 32)
///   - Cùng thang typography (display / title / body / label)
abstract final class AppTheme {
  // ── Seed ──────────────────────────────────────────────────────────────
  static const seed = Color(0xFF087CC1);
  static const navy = Color(0xFF071A33);

  // ── Palette mở rộng (dùng cho điểm nhấn và dark/light song song) ──────
  // Mọi màu bổ sung đều là biến thể toàn sáng / toàn tối của seed,
  // đảm bảo cùng tông — không pha màu lạ.
  static const accentSky = Color(0xFF26B9F3);
  static const accentAmber = Color(0xFFFFB52E);
  static const accentCoral = Color(0xFFFF5A4F);

  // ── Public API ────────────────────────────────────────────────────────
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  // ── Helpers ───────────────────────────────────────────────────────────
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = dark ? _darkScheme : _lightScheme;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      // ── Text ────────────────────────────────────────────────────────
      textTheme: _textTheme(base.textTheme, scheme.onSurface),

      // ── Card ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Navigation bar (bottom) ─────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Bottom sheet ────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // ── Filled button (CTA chính) ───────────────────────────────────
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
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────
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

      // ── Icon button ─────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
        ),
      ),

      // ── Dialog ──────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),

      // ── List tile ───────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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

      // ── Switch ──────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(scheme.outlineVariant),
      ),
    );
  }

  // ── Color schemes (cùng tông giữa light/dark) ──────────────────────────
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF087CC1),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD8ECFF),
    onPrimaryContainer: Color(0xFF002B45),
    secondary: Color(0xFF2E7D6B),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCDEFE6),
    onSecondaryContainer: Color(0xFF002A22),
    tertiary: Color(0xFFB45309),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE3C2),
    onTertiaryContainer: Color(0xFF2A1700),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF6FAFE),
    onSurface: Color(0xFF0A1A2C),
    onSurfaceVariant: Color(0xFF43536B),
    outline: Color(0xFF6F84A0),
    outlineVariant: Color(0xFFCDD9E6),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFEEF5FB),
    surfaceContainer: Color(0xFFE3EEF8),
    surfaceContainerHigh: Color(0xFFD7E5F2),
    surfaceContainerHighest: Color(0xFFC7D9EA),
    inverseSurface: Color(0xFF122236),
    onInverseSurface: Color(0xFFEDF4FB),
    inversePrimary: Color(0xFF8FCEFF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF66B6F0),
    onPrimary: Color(0xFF002237),
    primaryContainer: Color(0xFF134871),
    onPrimaryContainer: Color(0xFFD7ECFF),
    secondary: Color(0xFF7BD3BC),
    onSecondary: Color(0xFF003830),
    secondaryContainer: Color(0xFF1F4E45),
    onSecondaryContainer: Color(0xFFCDEFE6),
    tertiary: Color(0xFFFFB877),
    onTertiary: Color(0xFF3A2300),
    tertiaryContainer: Color(0xFF6B3D0E),
    onTertiaryContainer: Color(0xFFFFE3C2),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF071A33),
    onSurface: Color(0xFFE4EEF8),
    onSurfaceVariant: Color(0xFFA7BACD),
    outline: Color(0xFF6E85A0),
    outlineVariant: Color(0xFF2A4059),
    surfaceContainerLowest: Color(0xFF03101F),
    surfaceContainerLow: Color(0xFF0C2238),
    surfaceContainer: Color(0xFF142E48),
    surfaceContainerHigh: Color(0xFF1C3B58),
    surfaceContainerHighest: Color(0xFF264867),
    inverseSurface: Color(0xFFE4EEF8),
    onInverseSurface: Color(0xFF0A1A2C),
    inversePrimary: Color(0xFF087CC1),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ── Type scale thống nhất ─────────────────────────────────────────────
  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: onSurface,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: onSurface,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: onSurface,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: onSurface,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
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
            height: 1.45,
            color: onSurface,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.4,
            color: onSurface,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.35,
            color: onSurface,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: onSurface,
          ),
        )
        .apply(displayColor: onSurface, bodyColor: onSurface);
  }
}

/// Style helper dùng chung cho nút bấm Sudoku / 2048.
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
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Thang radius.
abstract final class AppRadius {
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(16);
  static const Radius xl = Radius.circular(20);
  static const Radius xxl = Radius.circular(28);
}