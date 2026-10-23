import 'package:flutter/material.dart';

import 'utils/font_utility.dart';

class PosTheme {
  PosTheme._();

  /// A short, soft edge. Surfaces stay flat instead of sitting on a slab.
  static List<BoxShadow> lift({Color tint = const Color(0xFF1B1433)}) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.05),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  /// Contact shadow used while a surface is pressed in.
  static List<BoxShadow> pressed({Color tint = const Color(0xFF1B1433)}) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static ThemeData light() {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A00E0),
      surface: const Color(0xFFFCFAFF),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide.none,
    );
    final text = ThemeData(useMaterial3: true).textTheme.apply(
      fontFamily: FontUtility.body.fontFamily,
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFFF3F0FA),
      textTheme: text.copyWith(
        headlineMedium: FontUtility.heading,
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: FontUtility.body,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 8,
        scrolledUnderElevation: 8,
        shadowColor: const Color(0x331B1433),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: FontUtility.heading.copyWith(
          fontSize: 22,
          color: colors.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline,
        errorBorder: outline,
        focusedErrorBorder: outline,
        disabledBorder: outline,
        hintStyle: FontUtility.body.copyWith(color: colors.onSurfaceVariant),
        labelStyle: FontUtility.body.copyWith(color: colors.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: text.bodyMedium,
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x331B1433),
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colors.onPrimary,
          backgroundColor: colors.primary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 6,
          shadowColor: const Color(0x553C00B5),
          textStyle: FontUtility.button.copyWith(fontSize: 16),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          side: BorderSide.none,
          elevation: 6,
          shadowColor: const Color(0x331B1433),
          textStyle: FontUtility.button.copyWith(
            fontSize: 16,
            color: colors.onSurface,
          ),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        headingTextStyle: text.labelLarge?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: text.bodyMedium,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 80,
        headingRowHeight: 52,
        horizontalMargin: 20,
        columnSpacing: 24,
        dividerThickness: 0.5,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PosTheme.lift(),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            colors.surfaceContainerLowest,
          ),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 0.5,
      ),
    );
  }
}
