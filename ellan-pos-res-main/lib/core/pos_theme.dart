import 'package:flutter/material.dart';

import 'utils/font_utility.dart';

class PosTheme {
  PosTheme._();

  static ThemeData light() {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A00E0),
      surface: const Color(0xFFFCFAFF),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final text = ThemeData(useMaterial3: true).textTheme.apply(
      fontFamily: FontUtility.body.fontFamily,
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      textTheme: text.copyWith(
        headlineMedium: FontUtility.heading,
        bodyMedium: FontUtility.body,
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
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: outline.copyWith(
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
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
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
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
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 1,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: colors.outlineVariant),
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
          border: Border.all(color: colors.outlineVariant),
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
