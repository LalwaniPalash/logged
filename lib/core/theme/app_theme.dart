import 'package:flutter/material.dart';

/// Semantic colors that don't map cleanly onto a Material [ColorScheme] role —
/// the streak "flame" and the positive/PR "success" green. Exposed as a theme
/// extension so widgets read them via `Theme.of(context).extension<AppColors>()`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.streak,
    required this.onStreak,
    required this.streakContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color streak;
  final Color onStreak;
  final Color streakContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  static const light = AppColors(
    streak: Color(0xFFC9821F), // warm amber-gold
    onStreak: Color(0xFFFFFFFF),
    streakContainer: Color(0xFFF6E4C4),
    success: Color(0xFF5E7047), // sage green
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCE6CB),
    onSuccessContainer: Color(0xFF2C381C),
  );

  static const dark = AppColors(
    streak: Color(0xFFE7B24B),
    onStreak: Color(0xFF3A2A08),
    streakContainer: Color(0xFF463714),
    success: Color(0xFF9DB37E),
    onSuccess: Color(0xFF29331A),
    successContainer: Color(0xFF39442A),
    onSuccessContainer: Color(0xFFDCE6CB),
  );

  @override
  AppColors copyWith({
    Color? streak,
    Color? onStreak,
    Color? streakContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
  }) => AppColors(
    streak: streak ?? this.streak,
    onStreak: onStreak ?? this.onStreak,
    streakContainer: streakContainer ?? this.streakContainer,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      streak: Color.lerp(streak, other.streak, t)!,
      onStreak: Color.lerp(onStreak, other.onStreak, t)!,
      streakContainer: Color.lerp(streakContainer, other.streakContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}

/// The "warm earth" design system: terracotta primary, sage accents, and warm
/// cream/charcoal neutrals — deliberately avoiding the cold indigo/violet defaults.
class AppTheme {
  const AppTheme._();

  // Terracotta / clay
  static const _clay = Color(0xFFB05C3B);
  static const _clayLight = Color(0xFFE08A63);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _clay,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF4D9C9),
    onPrimaryContainer: Color(0xFF3A1B0C),
    secondary: Color(0xFF6E7B5B), // muted sage
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDFE6CD),
    onSecondaryContainer: Color(0xFF2A331B),
    tertiary: Color(0xFF8A6748), // warm mocha
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF3DEC9),
    onTertiaryContainer: Color(0xFF32200F),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFBF5EC), // warm cream canvas
    onSurface: Color(0xFF241C16),
    onSurfaceVariant: Color(0xFF6A5D51),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFCF7EF),
    surfaceContainer: Color(0xFFF6EFE3),
    surfaceContainerHigh: Color(0xFFF0E7D9),
    surfaceContainerHighest: Color(0xFFEADFCF),
    outline: Color(0xFFB6A695),
    outlineVariant: Color(0xFFE0D3C1),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF352C24),
    onInverseSurface: Color(0xFFF9EFE2),
    inversePrimary: _clayLight,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _clayLight,
    onPrimary: Color(0xFF44200D),
    primaryContainer: Color(0xFF5E3016),
    onPrimaryContainer: Color(0xFFF4D9C9),
    secondary: Color(0xFFB7C598),
    onSecondary: Color(0xFF29331A),
    secondaryContainer: Color(0xFF3E482D),
    onSecondaryContainer: Color(0xFFDFE6CD),
    tertiary: Color(0xFFDDB794),
    onTertiary: Color(0xFF4B3120),
    tertiaryContainer: Color(0xFF654935),
    onTertiaryContainer: Color(0xFFF3DEC9),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF17120E), // warm charcoal, not pure black
    onSurface: Color(0xFFEDE2D6),
    onSurfaceVariant: Color(0xFFC5B4A3),
    surfaceContainerLowest: Color(0xFF120D0A),
    surfaceContainerLow: Color(0xFF1F1913),
    surfaceContainer: Color(0xFF241D17),
    surfaceContainerHigh: Color(0xFF2F2721),
    surfaceContainerHighest: Color(0xFF3A312A),
    outline: Color(0xFF8A7A6B),
    outlineVariant: Color(0xFF493F36),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEDE2D6),
    onInverseSurface: Color(0xFF352C24),
    inversePrimary: _clay,
  );

  static ThemeData light() => _build(_lightScheme, AppColors.light);
  static ThemeData dark() => _build(_darkScheme, AppColors.dark);

  static ThemeData _build(ColorScheme scheme, AppColors appColors) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _typography(base.textTheme, scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [appColors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainer,
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        extendedTextStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.all(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  static TextTheme _typography(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.labelLarge?.copyWith(letterSpacing: 0.1),
          labelSmall: base.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
