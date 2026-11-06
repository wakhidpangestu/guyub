import 'package:flutter/material.dart';

/// `hsl(h, s%, l%)` from design-system/guyub/tokens.css.
Color hsl(double h, double s, double l) => HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

/// WCAG contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final high = la > lb ? la : lb;
  final low = la > lb ? lb : la;
  return (high + 0.05) / (low + 0.05);
}

/// The colorful card fills. [plain] is the neutral card surface.
enum TileTone { plain, primary, violet, cyan, green, orchid, pink }

/// Resolved colors of a tile: a gradient and the text that reads on all of it.
@immutable
class ToneColors {
  const ToneColors({required this.start, required this.end, required this.ink, required this.mutedInk, required this.soft});

  final Color start;
  final Color end;
  final Color ink;

  /// Secondary text. Still meets 4.5:1 on the whole gradient.
  final Color mutedInk;

  /// Translucent fill for tracks and chips on top of the tile.
  final Color soft;
}

/// Guyub's design tokens, one instance per theme. Values mirror
/// design-system/guyub/tokens.css; test/ui/tokens_test.dart keeps them equal.
@immutable
class GuyubTokens extends ThemeExtension<GuyubTokens> {
  const GuyubTokens({
    required this.brightness,
    required this.card,
    required this.ring,
    required this.input,
    required this.muted,
    required this.accent,
    required this.border,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.popover,
    required this.primary,
    required this.sidebar,
    required this.secondary,
    required this.background,
    required this.foreground,
    required this.destructive,
    required this.shadowColor,
    required this.sidebarRing,
    required this.sidebarAccent,
    required this.sidebarBorder,
    required this.cardForeground,
    required this.sidebarPrimary,
    required this.mutedForeground,
    required this.accentForeground,
    required this.popoverForeground,
    required this.primaryForeground,
    required this.sidebarForeground,
    required this.secondaryForeground,
    required this.destructiveForeground,
    required this.sidebarAccentForeground,
    required this.sidebarPrimaryForeground,
    required this.radius,
    required this.spacing,
    required this.letterSpacingEm,
    required this.shadowBlur,
    required this.shadowSpread,
    required this.shadowOpacity,
    required this.shadowOffset,
    required this.fontSans,
    required this.fontMono,
  });

  final Brightness brightness;
  final Color card;
  final Color ring;
  final Color input;
  final Color muted;
  final Color accent;
  final Color border;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;
  final Color popover;
  final Color primary;
  final Color sidebar;
  final Color secondary;
  final Color background;
  final Color foreground;
  final Color destructive;
  final Color shadowColor;
  final Color sidebarRing;
  final Color sidebarAccent;
  final Color sidebarBorder;
  final Color cardForeground;
  final Color sidebarPrimary;
  final Color mutedForeground;
  final Color accentForeground;
  final Color popoverForeground;
  final Color primaryForeground;
  final Color sidebarForeground;
  final Color secondaryForeground;
  final Color destructiveForeground;
  final Color sidebarAccentForeground;
  final Color sidebarPrimaryForeground;

  /// `--radius` in logical pixels (1rem = 16).
  final double radius;

  /// `--spacing` in logical pixels.
  final double spacing;
  final double letterSpacingEm;
  final double shadowBlur;
  final double shadowSpread;
  final double shadowOpacity;
  final Offset shadowOffset;
  final String fontSans;
  final String fontMono;

  static const fontPlusJakarta = 'Plus Jakarta Sans';
  static const fontPublicSans = 'Public Sans';
  static const fontJetBrains = 'JetBrains Mono';

  static final light = GuyubTokens(
    brightness: Brightness.light,
    card: hsl(0, 0, 100),
    ring: hsl(263, 70, 50),
    input: hsl(220, 13, 91),
    muted: hsl(220, 14, 96),
    accent: hsl(263, 80, 96),
    border: hsl(220, 13, 91),
    chart1: hsl(263, 70, 50),
    chart2: hsl(190, 90, 45),
    chart3: hsl(150, 60, 40),
    chart4: hsl(280, 65, 60),
    chart5: hsl(330, 80, 60),
    popover: hsl(0, 0, 100),
    primary: hsl(256, 45, 54),
    sidebar: hsl(0, 0, 100),
    secondary: hsl(263, 20, 94),
    background: hsl(210, 40, 98),
    foreground: hsl(224, 71, 4),
    destructive: hsl(0, 84, 60),
    shadowColor: hsl(263, 70, 50),
    sidebarRing: hsl(263, 70, 50),
    sidebarAccent: hsl(263, 20, 94),
    sidebarBorder: hsl(220, 13, 91),
    cardForeground: hsl(224, 71, 4),
    sidebarPrimary: hsl(263, 70, 50),
    mutedForeground: hsl(220, 9, 46),
    accentForeground: hsl(263, 70, 50),
    popoverForeground: hsl(224, 71, 4),
    primaryForeground: hsl(210, 40, 98),
    sidebarForeground: hsl(224, 71, 4),
    secondaryForeground: hsl(263, 70, 30),
    destructiveForeground: hsl(210, 40, 98),
    sidebarAccentForeground: hsl(263, 70, 50),
    sidebarPrimaryForeground: hsl(210, 40, 98),
    radius: 16,
    spacing: 4,
    letterSpacingEm: -0.02,
    shadowBlur: 30,
    shadowSpread: 0,
    shadowOpacity: 0.08,
    shadowOffset: const Offset(0, 8),
    fontSans: fontPlusJakarta,
    fontMono: fontJetBrains,
  );

  static final dark = GuyubTokens(
    brightness: Brightness.dark,
    card: hsl(260, 25, 4),
    ring: hsl(263, 85, 65),
    input: hsl(260, 20, 15),
    muted: hsl(260, 20, 12),
    accent: hsl(263, 60, 15),
    border: hsl(260, 20, 15),
    chart1: hsl(263, 85, 65),
    chart2: hsl(190, 80, 55),
    chart3: hsl(150, 70, 50),
    chart4: hsl(280, 80, 70),
    chart5: hsl(330, 90, 65),
    popover: hsl(260, 25, 5),
    primary: hsl(263, 85, 65),
    sidebar: hsl(260, 25, 3),
    secondary: hsl(263, 40, 15),
    background: hsl(260, 25, 2),
    foreground: hsl(210, 40, 98),
    destructive: hsl(0, 84, 60),
    shadowColor: hsl(0, 0, 0),
    sidebarRing: hsl(263, 85, 65),
    sidebarAccent: hsl(263, 40, 12),
    sidebarBorder: hsl(260, 20, 12),
    cardForeground: hsl(210, 40, 98),
    sidebarPrimary: hsl(263, 85, 65),
    mutedForeground: hsl(260, 10, 70),
    accentForeground: hsl(263, 85, 65),
    popoverForeground: hsl(210, 40, 98),
    primaryForeground: hsl(260, 25, 2),
    sidebarForeground: hsl(210, 40, 98),
    secondaryForeground: hsl(263, 85, 85),
    destructiveForeground: hsl(210, 40, 98),
    sidebarAccentForeground: hsl(263, 85, 65),
    sidebarPrimaryForeground: hsl(260, 25, 2),
    radius: 16,
    spacing: 5.04,
    letterSpacingEm: -0.015,
    shadowBlur: 30,
    shadowSpread: 12,
    shadowOpacity: 0.46,
    shadowOffset: const Offset(10, 20),
    fontSans: fontPublicSans,
    // tokens.css names Consolas, which cannot be bundled and which a Flutter
    // web canvas cannot read from the system. See MASTER.md.
    fontMono: fontJetBrains,
  );

  static GuyubTokens of(BuildContext context) => Theme.of(context).extension<GuyubTokens>()!;

  /// The Tailwind spacing scale: `sp(4)` is `p-4`.
  double sp(double steps) => spacing * steps;

  /// Every color by its CSS variable name, for the drift test.
  Map<String, Color> get cssColors => {
        'card': card,
        'ring': ring,
        'input': input,
        'muted': muted,
        'accent': accent,
        'border': border,
        'chart-1': chart1,
        'chart-2': chart2,
        'chart-3': chart3,
        'chart-4': chart4,
        'chart-5': chart5,
        'popover': popover,
        'primary': primary,
        'sidebar': sidebar,
        'secondary': secondary,
        'background': background,
        'foreground': foreground,
        'destructive': destructive,
        'shadow-color': shadowColor,
        'sidebar-ring': sidebarRing,
        'sidebar-accent': sidebarAccent,
        'sidebar-border': sidebarBorder,
        'card-foreground': cardForeground,
        'sidebar-primary': sidebarPrimary,
        'muted-foreground': mutedForeground,
        'accent-foreground': accentForeground,
        'popover-foreground': popoverForeground,
        'primary-foreground': primaryForeground,
        'sidebar-foreground': sidebarForeground,
        'secondary-foreground': secondaryForeground,
        'destructive-foreground': destructiveForeground,
        'sidebar-accent-foreground': sidebarAccentForeground,
        'sidebar-primary-foreground': sidebarPrimaryForeground,
      };

  BoxShadow get restShadow => BoxShadow(
        color: shadowColor.withValues(alpha: shadowOpacity),
        offset: shadowOffset,
        blurRadius: shadowBlur,
        spreadRadius: shadowSpread,
      );

  /// A card lifted by a drag.
  BoxShadow get liftedShadow => BoxShadow(
        color: shadowColor.withValues(alpha: brightness == Brightness.dark ? 0.7 : 0.28),
        offset: const Offset(0, 24),
        blurRadius: 48,
        spreadRadius: -8,
      );

  /// Text on [accent]. `--accent-foreground` reaches only 4.16:1 on the dark
  /// accent, so dark mode falls back to the lighter secondary foreground.
  Color get accentText => contrastRatio(accentForeground, accent) >= 4.5 ? accentForeground : secondaryForeground;

  /// Text on a selected sidebar entry, for the same reason as [accentText].
  Color get sidebarAccentText =>
      contrastRatio(sidebarAccentForeground, sidebarAccent) >= 4.5 ? sidebarAccentForeground : secondaryForeground;

  Color chart(int index) => [chart1, chart2, chart3, chart4, chart5][index % 5];

  /// Text style for numbers: mono with tabular figures, so digits do not jump.
  TextStyle numeric(TextStyle? base) => (base ?? const TextStyle()).copyWith(
        fontFamily: fontMono,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -0.5,
      );

  ToneColors tone(TileTone tone) {
    if (tone == TileTone.plain) {
      return ToneColors(start: card, end: card, ink: cardForeground, mutedInk: mutedForeground, soft: muted);
    }
    final Color start = switch (tone) {
      TileTone.primary => primary,
      TileTone.violet => chart1,
      TileTone.cyan => chart2,
      TileTone.green => chart3,
      TileTone.orchid => chart4,
      TileTone.pink => chart5,
      TileTone.plain => card,
    };
    final Color end = tone == TileTone.primary ? chart1 : _shift(start);
    final ink = _bestInk(start, end);
    return ToneColors(start: start, end: end, ink: ink, mutedInk: _mutedInk(ink, start, end), soft: ink.withValues(alpha: 0.16));
  }

  /// The softest version of [ink] that still reads at 4.5:1 on both ends.
  static Color _mutedInk(Color ink, Color start, Color end) {
    for (final alpha in const [0.84, 0.88, 0.92, 0.96]) {
      final muted = ink.withValues(alpha: alpha);
      if (contrastRatio(Color.alphaBlend(muted, start), start) >= 4.5 && contrastRatio(Color.alphaBlend(muted, end), end) >= 4.5) {
        return muted;
      }
    }
    return ink;
  }

  /// A gentle gradient partner: the same hue, slightly lighter.
  static Color _shift(Color color) {
    final value = HSLColor.fromColor(color);
    return value.withLightness((value.lightness + 0.05).clamp(0, 1)).toColor();
  }

  /// Near-black or near-white, whichever reads better on both gradient ends.
  Color _bestInk(Color start, Color end) {
    final darkInk = hsl(224, 71, 4);
    final lightInk = hsl(210, 40, 98);
    double worst(Color ink) {
      final a = contrastRatio(ink, start);
      final b = contrastRatio(ink, end);
      return a < b ? a : b;
    }

    return worst(lightInk) >= worst(darkInk) ? lightInk : darkInk;
  }

  @override
  GuyubTokens copyWith() => this;

  /// Theme changes switch tokens at the midpoint. Fonts and spacing cannot be
  /// blended usefully, and the switch is quick.
  @override
  GuyubTokens lerp(ThemeExtension<GuyubTokens>? other, double t) =>
      other is GuyubTokens && t >= 0.5 ? other : this;
}
