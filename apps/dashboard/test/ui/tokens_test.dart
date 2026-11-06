import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/ui/theme.dart';
import 'package:guyub_dashboard/ui/tokens.dart';

/// Reads one `selector { ... }` block of the design system's tokens.css.
Map<String, String> cssBlock(String css, String selector) {
  final body = RegExp('${RegExp.escape(selector)} \\{(.*?)\\}', dotAll: true).firstMatch(css)!.group(1)!;
  return {
    for (final match in RegExp(r'--([\w-]+):\s*([^;]+);').allMatches(body)) match.group(1)!: match.group(2)!.trim(),
  };
}

Color parseHsl(String value) {
  final m = RegExp(r'hsl\(([\d.]+)[, ]+([\d.]+)%[, ]+([\d.]+)%\)').firstMatch(value)!;
  return hsl(double.parse(m.group(1)!), double.parse(m.group(2)!), double.parse(m.group(3)!));
}

void main() {
  final css = File('../../design-system/guyub/tokens.css').readAsStringSync();

  for (final (name, selector, tokens) in [
    ('light', ':root', GuyubTokens.light),
    ('dark', '.dark', GuyubTokens.dark),
  ]) {
    group('$name tokens', () {
      final block = cssBlock(css, selector);

      test('every color matches tokens.css', () {
        for (final MapEntry(:key, :value) in tokens.cssColors.entries) {
          expect(value, parseHsl(block[key]!), reason: '--$key');
        }
      });

      test('every color in tokens.css is mirrored', () {
        final colors = block.entries.where((e) => e.value.startsWith('hsl')).map((e) => e.key).toSet();
        expect(tokens.cssColors.keys.toSet(), colors);
      });

      test('non-color tokens match', () {
        double number(String key) => double.parse(RegExp(r'-?[\d.]+').firstMatch(block[key]!)!.group(0)!);
        expect(tokens.radius, number('radius') * 16);
        expect(tokens.spacing, closeTo(number('spacing') * 16, 0.001));
        expect(tokens.letterSpacingEm, number('letter-spacing'));
        expect(tokens.shadowBlur, number('shadow-blur'));
        expect(tokens.shadowSpread, number('shadow-spread'));
        expect(tokens.shadowOpacity, number('shadow-opacity'));
        expect(tokens.shadowOffset, Offset(number('shadow-offset-x'), number('shadow-offset-y')));
        expect(block['font-sans'], startsWith(tokens.fontSans));
      });

      // Text on the colorful cards must stay readable on the whole gradient.
      for (final tone in TileTone.values) {
        test('${tone.name} tile text is readable', () {
          final colors = tokens.tone(tone);
          final muted = Color.alphaBlend(colors.mutedInk, colors.start);
          final mutedEnd = Color.alphaBlend(colors.mutedInk, colors.end);
          expect(contrastRatio(colors.ink, colors.start), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(colors.ink, colors.end), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(muted, colors.start), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(mutedEnd, colors.end), greaterThanOrEqualTo(4.5));
        });
      }

      test('body text pairs are readable', () {
        final pairs = {
          'foreground on background': (tokens.foreground, tokens.background),
          'muted on card': (tokens.mutedForeground, tokens.card),
          'muted on background': (tokens.mutedForeground, tokens.background),
          'draft and planned pills': (tokens.foreground, tokens.muted),
          'primary button': (tokens.primaryForeground, tokens.primary),
          'accent': (tokens.accentText, tokens.accent),
          'secondary': (tokens.secondaryForeground, tokens.secondary),
          'sidebar selection': (tokens.sidebarAccentText, tokens.sidebarAccent),
        };
        pairs.forEach((name, pair) {
          expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5), reason: name);
        });
      });

      test('the error text shade is readable where the token red is not', () {
        final scheme = (name == 'light' ? GuyubTheme.light() : GuyubTheme.dark()).colorScheme;
        final surface = Color.alphaBlend(scheme.errorContainer, tokens.card);
        expect(contrastRatio(scheme.onErrorContainer, surface), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('the theme exposes the tokens and the brand fonts', () {
    final light = GuyubTheme.light();
    expect(light.extension<GuyubTokens>(), same(GuyubTokens.light));
    expect(light.colorScheme.primary, GuyubTokens.light.primary);
    expect(light.scaffoldBackgroundColor, GuyubTokens.light.background);
    expect(light.textTheme.bodyMedium!.fontFamily, 'Plus Jakarta Sans');
    expect(GuyubTheme.dark().textTheme.bodyMedium!.fontFamily, 'Public Sans');
  });
}
