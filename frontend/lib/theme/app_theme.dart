import "package:flutter/material.dart";

class AppTheme {
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color primary = Color(0xFF10B981);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color danger = Color(0xFFEF4444);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.normal,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
        onSurface: textPrimary,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onError: textPrimary,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDCFCE7),
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFDCFCE7),
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(10),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      listTileTheme: const ListTileThemeData(minTileHeight: 52),
    );
  }
}
