import 'package:flutter/material.dart';

/// Christmas theme colors and decorations for the app.
/// 
/// When Christmas mode is enabled, these colors are used throughout
/// the app for a festive appearance.
class ChristmasColors {
  // Primary Christmas colors
  static const Color christmasRed = Color(0xFFB22222); // Deep red
  static const Color christmasGreen = Color(0xFF228B22); // Forest green
  static const Color christmasGold = Color(0xFFFFD700); // Gold
  static const Color snowWhite = Color(0xFFF8F8FF); // Ghost white
  static const Color hollyGreen = Color(0xFF006400); // Dark green
  static const Color candyCaneRed = Color(0xFFDC143C); // Crimson
  
  // Accent colors
  static const Color ornamentBlue = Color(0xFF4169E1); // Royal blue
  static const Color starGold = Color(0xFFDAA520); // Goldenrod
  static const Color icicleBlue = Color(0xFFB0E0E6); // Powder blue
  static const Color berryRed = Color(0xFF8B0000); // Dark red
  
  // Surface colors for light theme
  static const Color lightSurface = Color(0xFFFFFAFA); // Snow
  static const Color lightSurfaceContainer = Color(0xFFF5F5F5);
  static const Color lightBackground = Color(0xFFFFF8F0); // Warm white
  
  // Surface colors for dark theme  
  static const Color darkSurface = Color(0xFF1A1A2E); // Deep navy
  static const Color darkSurfaceContainer = Color(0xFF16213E);
  static const Color darkBackground = Color(0xFF0F0F1A); // Very dark blue
}

/// Extension for Christmas-specific theme properties
class ChristmasThemeExtension extends ThemeExtension<ChristmasThemeExtension> {
  final Color snowflakeColor;
  final Color ornamentPrimary;
  final Color ornamentSecondary;
  final Color garlandColor;
  final Color starColor;
  final Gradient? backgroundGradient;
  final bool showSnowflakes;

  const ChristmasThemeExtension({
    required this.snowflakeColor,
    required this.ornamentPrimary,
    required this.ornamentSecondary,
    required this.garlandColor,
    required this.starColor,
    this.backgroundGradient,
    this.showSnowflakes = true,
  });

  static ChristmasThemeExtension light = ChristmasThemeExtension(
    snowflakeColor: Colors.white.withOpacity(0.9),
    ornamentPrimary: ChristmasColors.christmasRed,
    ornamentSecondary: ChristmasColors.christmasGold,
    garlandColor: ChristmasColors.christmasGreen,
    starColor: ChristmasColors.starGold,
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ChristmasColors.lightBackground,
        ChristmasColors.lightSurface,
      ],
    ),
    showSnowflakes: true,
  );

  static ChristmasThemeExtension dark = ChristmasThemeExtension(
    snowflakeColor: Colors.white.withOpacity(0.7),
    ornamentPrimary: ChristmasColors.candyCaneRed,
    ornamentSecondary: ChristmasColors.starGold,
    garlandColor: ChristmasColors.hollyGreen,
    starColor: ChristmasColors.christmasGold,
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ChristmasColors.darkBackground,
        ChristmasColors.darkSurface,
      ],
    ),
    showSnowflakes: true,
  );

  @override
  ThemeExtension<ChristmasThemeExtension> copyWith({
    Color? snowflakeColor,
    Color? ornamentPrimary,
    Color? ornamentSecondary,
    Color? garlandColor,
    Color? starColor,
    Gradient? backgroundGradient,
    bool? showSnowflakes,
  }) {
    return ChristmasThemeExtension(
      snowflakeColor: snowflakeColor ?? this.snowflakeColor,
      ornamentPrimary: ornamentPrimary ?? this.ornamentPrimary,
      ornamentSecondary: ornamentSecondary ?? this.ornamentSecondary,
      garlandColor: garlandColor ?? this.garlandColor,
      starColor: starColor ?? this.starColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      showSnowflakes: showSnowflakes ?? this.showSnowflakes,
    );
  }

  @override
  ThemeExtension<ChristmasThemeExtension> lerp(
    covariant ThemeExtension<ChristmasThemeExtension>? other,
    double t,
  ) {
    if (other is! ChristmasThemeExtension) return this;
    return ChristmasThemeExtension(
      snowflakeColor: Color.lerp(snowflakeColor, other.snowflakeColor, t)!,
      ornamentPrimary: Color.lerp(ornamentPrimary, other.ornamentPrimary, t)!,
      ornamentSecondary: Color.lerp(ornamentSecondary, other.ornamentSecondary, t)!,
      garlandColor: Color.lerp(garlandColor, other.garlandColor, t)!,
      starColor: Color.lerp(starColor, other.starColor, t)!,
      backgroundGradient: t < 0.5 ? backgroundGradient : other.backgroundGradient,
      showSnowflakes: t < 0.5 ? showSnowflakes : other.showSnowflakes,
    );
  }
}

/// Creates a Christmas-themed ThemeData
ThemeData createChristmasLightTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'plusJakartaSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: ChristmasColors.christmasRed,
      brightness: Brightness.light,
      primary: ChristmasColors.christmasRed,
      secondary: ChristmasColors.christmasGreen,
      tertiary: ChristmasColors.christmasGold,
      surface: ChristmasColors.lightSurface,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: ChristmasColors.lightSurface,
    ),
    extensions: [ChristmasThemeExtension.light],
  );
}

ThemeData createChristmasDarkTheme({bool blackThemeEnabled = false}) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'plusJakartaSans',
    scaffoldBackgroundColor: blackThemeEnabled ? Colors.black : ChristmasColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ChristmasColors.christmasRed,
      brightness: Brightness.dark,
      primary: ChristmasColors.candyCaneRed,
      secondary: ChristmasColors.hollyGreen,
      tertiary: ChristmasColors.starGold,
      surface: blackThemeEnabled ? Colors.black : ChristmasColors.darkSurface,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: blackThemeEnabled ? Colors.black : ChristmasColors.darkSurface,
    ),
    extensions: [ChristmasThemeExtension.dark],
  );
}

