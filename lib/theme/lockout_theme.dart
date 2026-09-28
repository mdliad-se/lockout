import 'package:flutter/material.dart';

import 'lockout_semantics.dart';

/// Builds the app's `ThemeData` from a colour scheme.
///
/// There is deliberately no static colour accessor here. The token class this
/// replaces exposed colours without a `BuildContext`, which is what made a
/// dynamic (Material You) scheme impossible to support: the platform scheme
/// only exists below the widget that resolves it. Everything a widget needs
/// arrives through `Theme.of(context)`; the constants below are the only
/// things safe to read statically, because none of them are colours.
class LockoutTheme {
  LockoutTheme._();

  // Shape scale.
  static const double radiusButton = 14;
  static const double radiusCard = 18;
  static const double radiusDialog = 24;
  static const double radiusSheet = 28;
  static const double radiusField = 14;
  static const double radiusPill = 999;

  // 8dp spacing grid.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const double screenPadding = 20;
  static const double cardPadding = 16;
  static const double sectionGap = 24;

  static const double navBarHeight = 80;
  static const double minTouchTarget = 48;
  static const double controlHeight = 52;

  static const String fontSans = 'Inter';
  static const String fontMono = 'JetBrainsMono';

  /// The Material type scale, stated rather than derived.
  ///
  /// Sizes come from the design brief. They are written out instead of scaled
  /// from one base size so that changing `titleMedium` cannot silently move
  /// `bodySmall` with it.
  static TextTheme textThemeFor(ColorScheme colors) {
    TextStyle sans(
      double size,
      FontWeight weight, {
      Color? color,
      double? height,
    }) {
      return TextStyle(
        fontFamily: fontSans,
        fontSize: size,
        fontWeight: weight,
        color: color ?? colors.onSurface,
        height: height,
      );
    }

    return TextTheme(
      displayLarge: sans(45, FontWeight.w700, height: 1.05),
      displayMedium: sans(40, FontWeight.w700, height: 1.05),
      displaySmall: sans(36, FontWeight.w700, height: 1.08),
      headlineLarge: sans(32, FontWeight.w700, height: 1.15),
      headlineMedium: sans(28, FontWeight.w700, height: 1.15),
      headlineSmall: sans(24, FontWeight.w600, height: 1.2),
      titleLarge: sans(22, FontWeight.w600, height: 1.25),
      titleMedium: sans(18, FontWeight.w600, height: 1.3),
      titleSmall: sans(16, FontWeight.w600, height: 1.3),
      bodyLarge: sans(16, FontWeight.w400, height: 1.45),
      bodyMedium: sans(14, FontWeight.w400, height: 1.45),
      bodySmall: sans(13, FontWeight.w400,
          color: colors.onSurfaceVariant, height: 1.4),
      labelLarge: sans(14, FontWeight.w600, height: 1.2),
      labelMedium: sans(12, FontWeight.w500,
          color: colors.onSurfaceVariant, height: 1.2),
      labelSmall: sans(11, FontWeight.w500,
          color: colors.onSurfaceVariant, height: 1.2),
    );
  }

  /// Style for anything that must align in a column — set/rep/weight tables,
  /// the rest timer, log rows.
  ///
  /// Mono, so a digit does not change width between 1 and 8 and a column of
  /// numbers does not shimmer as it counts down.
  static TextStyle numeric(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontMono,
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      letterSpacing: 0.2,
    );
  }

  static RoundedRectangleBorder _rounded(double radius, {BorderSide? side}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side ?? BorderSide.none,
    );
  }

  static ThemeData build({
    required ColorScheme colors,
    required LockoutSemantics semantics,
  }) {
    final text = textThemeFor(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[semantics],

      // Every component theme below sets `surfaceTintColor: transparent`.
      // M3's default tint overlays `primary` onto an elevated surface, which
      // on these dark schemes turns a raised card faintly green — the one
      // colour reserved for "complete". Tone is carried by the
      // surfaceContainer ladder instead.
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      cardTheme: CardThemeData(
        color: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: _rounded(
          radiusCard,
          side: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: _rounded(radiusDialog),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surfaceContainerLow,
        elevation: 6,
        showDragHandle: true,
        dragHandleColor: colors.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: spaceLg),
          textStyle: text.labelLarge,
          shape: _rounded(radiusButton),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: spaceLg),
          textStyle: text.labelLarge,
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outline),
          shape: _rounded(radiusButton),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, minTouchTarget),
          textStyle: text.labelLarge,
          shape: _rounded(radiusButton),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          foregroundColor: colors.onSurfaceVariant,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceMd,
        ),
        labelStyle: text.labelMedium,
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        suffixStyle: text.labelMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: navBarHeight,
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            color: selected ? colors.primary : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color:
                selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          );
        }),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.secondaryContainer,
          selectedForegroundColor: colors.onSecondaryContainer,
          foregroundColor: colors.onSurfaceVariant,
          side: BorderSide(color: colors.outlineVariant),
          textStyle: text.labelLarge,
          minimumSize: const Size(0, minTouchTarget),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        selectedColor: colors.secondaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        labelStyle: text.labelMedium!,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceSm,
          vertical: spaceXs,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        linearMinHeight: 8,
        circularTrackColor: colors.surfaceContainerHighest,
      ),

      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: spaceLg,
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        iconColor: colors.onSurfaceVariant,
        shape: _rounded(radiusButton),
        contentPadding: const EdgeInsets.symmetric(horizontal: spaceMd),
        minTileHeight: minTouchTarget,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: colors.onInverseSurface),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: _rounded(radiusButton),
        insetPadding: const EdgeInsets.all(spaceMd),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: 4,
        shape: _rounded(radiusDialog),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: _rounded(radiusButton),
        textStyle: text.bodyMedium,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(radiusButton),
        ),
        textStyle: text.labelMedium?.copyWith(color: colors.onInverseSurface),
      ),
    );
  }
}
