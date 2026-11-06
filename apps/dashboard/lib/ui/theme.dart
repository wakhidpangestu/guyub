import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material theme built from the Guyub design tokens.
/// See design-system/guyub/MASTER.md.
abstract final class GuyubTheme {
  static ThemeData light() => _build(GuyubTokens.light);

  static ThemeData dark() => _build(GuyubTokens.dark);

  static ThemeData _build(GuyubTokens t) {
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.primary,
      onPrimary: t.primaryForeground,
      primaryContainer: t.accent,
      onPrimaryContainer: t.accentText,
      secondary: t.chart2,
      onSecondary: t.foreground,
      secondaryContainer: t.secondary,
      onSecondaryContainer: t.secondaryForeground,
      tertiary: t.chart3,
      onTertiary: t.foreground,
      error: t.destructive,
      onError: t.destructiveForeground,
      errorContainer: t.destructive.withValues(alpha: 0.12),
      // The token red is 3.8:1 on white, too low for sentences. Error text
      // uses a darker (or, in dark mode, lighter) shade of the same hue.
      onErrorContainer: t.brightness == Brightness.light ? hsl(0, 74, 36) : hsl(0, 90, 80),
      surface: t.card,
      onSurface: t.foreground,
      surfaceContainerLowest: t.background,
      surfaceContainerLow: t.card,
      surfaceContainer: t.muted,
      surfaceContainerHigh: t.muted,
      surfaceContainerHighest: t.muted,
      onSurfaceVariant: t.mutedForeground,
      outline: t.mutedForeground,
      outlineVariant: t.border,
      inverseSurface: t.foreground,
      onInverseSurface: t.background,
      inversePrimary: t.ring,
      shadow: t.shadowColor,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
    final radius = BorderRadius.circular(t.radius);
    final controlRadius = BorderRadius.circular(t.radius * 0.75);
    final textTheme = _textTheme(t);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: controlRadius, borderSide: BorderSide(color: color, width: width));

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: t.fontSans,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [t],
      scaffoldBackgroundColor: t.background,
      dividerColor: t.border,
      focusColor: t.ring.withValues(alpha: 0.16),
      hoverColor: t.foreground.withValues(alpha: 0.05),
      // Every page repeats the sidebar, so a route transition would animate
      // it. Pages switch at once and the sidebar appears to stay in place.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: const _InstantPageTransitions()},
      ),
      dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: t.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: t.border)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.secondary,
        labelStyle: textTheme.labelMedium?.copyWith(color: t.secondaryForeground),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: t.foreground,
          side: BorderSide(color: t.input),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: t.accentForeground,
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.card,
        border: inputBorder(t.input),
        enabledBorder: inputBorder(t.input),
        focusedBorder: inputBorder(t.ring, 2),
        errorBorder: inputBorder(t.destructive),
        focusedErrorBorder: inputBorder(t.destructive, 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.popover,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.popover,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: controlRadius, side: BorderSide(color: t.border)),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: t.sidebar, surfaceTintColor: Colors.transparent),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.primary, linearTrackColor: t.muted),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: t.foreground, borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.labelMedium?.copyWith(color: t.background),
      ),
    );
  }

  static TextTheme _textTheme(GuyubTokens t) {
    final base = ThemeData(brightness: t.brightness, useMaterial3: true, fontFamily: t.fontSans)
        .textTheme
        .apply(bodyColor: t.foreground, displayColor: t.foreground);
    // `--letter-spacing` is in em; Flutter wants logical pixels per style.
    // Plus Jakarta Sans has a narrow space, and the negative tracking closes it
    // further: small text read as one word without this.
    final wordSpacingEm = t.fontSans == GuyubTokens.fontPlusJakarta ? 0.12 : 0.0;
    TextStyle? tracked(TextStyle? style, [FontWeight? weight]) => style?.copyWith(
          letterSpacing: t.letterSpacingEm * (style.fontSize ?? 14),
          wordSpacing: wordSpacingEm * (style.fontSize ?? 14),
          fontWeight: weight ?? style.fontWeight,
        );
    return base.copyWith(
      displayLarge: tracked(base.displayLarge, FontWeight.w600),
      displayMedium: tracked(base.displayMedium, FontWeight.w600),
      displaySmall: tracked(base.displaySmall, FontWeight.w600),
      headlineLarge: tracked(base.headlineLarge, FontWeight.w600),
      headlineMedium: tracked(base.headlineMedium, FontWeight.w600),
      headlineSmall: tracked(base.headlineSmall, FontWeight.w600),
      titleLarge: tracked(base.titleLarge, FontWeight.w600),
      titleMedium: tracked(base.titleMedium, FontWeight.w600),
      titleSmall: tracked(base.titleSmall, FontWeight.w600),
      bodyLarge: tracked(base.bodyLarge),
      bodyMedium: tracked(base.bodyMedium),
      bodySmall: tracked(base.bodySmall),
      labelLarge: tracked(base.labelLarge, FontWeight.w600),
      labelMedium: tracked(base.labelMedium),
      labelSmall: tracked(base.labelSmall),
    );
  }
}

class _InstantPageTransitions extends PageTransitionsBuilder {
  const _InstantPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
