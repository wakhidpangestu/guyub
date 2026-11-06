import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../tokens.dart';
import '../widgets/event_widgets.dart';
import 'attendance_series.dart';

/// Colors of the enclosing [Tile].
class TileScope extends InheritedWidget {
  const TileScope({super.key, required this.colors, required super.child});

  final ToneColors colors;

  static ToneColors of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TileScope>()!.colors;

  @override
  bool updateShouldNotify(TileScope oldWidget) => oldWidget.colors != colors;
}

/// A dashboard card surface: neutral or filled with one of the chart colors.
class Tile extends StatelessWidget {
  const Tile({super.key, required this.child, this.tone = TileTone.plain, this.onTap});

  final Widget child;
  final TileTone tone;

  /// Makes the whole card a link.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = GuyubTokens.of(context);
    final colors = tokens.tone(tone);
    final radius = BorderRadius.circular(tokens.radius * 1.5);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: tone == TileTone.plain ? colors.start : null,
          gradient: tone == TileTone.plain
              ? null
              : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.start, colors.end]),
          border: tone == TileTone.plain ? Border.all(color: tokens.border) : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: colors.ink.withValues(alpha: 0.05),
          splashColor: colors.ink.withValues(alpha: 0.1),
          highlightColor: colors.ink.withValues(alpha: 0.06),
          child: Padding(
            padding: EdgeInsets.all(tokens.sp(4)),
            child: TileScope(
              colors: colors,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: colors.ink),
                child: IconTheme.merge(data: IconThemeData(color: colors.ink, size: 20), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small title row of a card, with an icon or an action on the right.
class TileHeader extends StatelessWidget {
  const TileHeader(this.title, {super.key, this.icon, this.trailing});

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = TileScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.mutedInk),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: colors.mutedInk)],
      ],
    );
  }
}

/// The greeting card: who you are, what this area is for, the main action.
class HeroTile extends StatelessWidget {
  const HeroTile({
    super.key,
    required this.title,
    required this.intro,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String intro;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tile(
      tone: TileTone.primary,
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(color: colors.ink),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    intro,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.mutedInk),
                  ),
                ),
              ),
              if (actionLabel != null)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.arrow_forward, size: 18),
                  label: Text(actionLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.start,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One number on a colored card.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    this.tone = TileTone.plain,
    this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final TileTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    return Tile(
      tone: tone,
      onTap: onTap,
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TileHeader(label, icon: icon),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: tokens.numeric(theme.textTheme.displaySmall).copyWith(color: colors.ink, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 2),
              Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
            ],
          );
        },
      ),
    );
  }
}

/// A feature that is not built yet. The handbook requires planned features to
/// be labelled, so this card stays neutral and says so.
class PlannedTile extends StatelessWidget {
  const PlannedTile({super.key, required this.title, required this.description, required this.icon, required this.milestone});

  final String title;
  final String description;
  final IconData icon;
  final String milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tokens.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TonePill('Planned · $milestone', background: tokens.muted, foreground: tokens.foreground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(color: tokens.cardForeground)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(description, overflow: TextOverflow.fade, style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground)),
          ),
        ],
      ),
    );
  }
}

/// A small rounded label.
class TonePill extends StatelessWidget {
  const TonePill(this.label, {super.key, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class EventStatusPill extends StatelessWidget {
  const EventStatusPill(this.status, {super.key});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final t = GuyubTokens.of(context);
    final (background, foreground) = switch (status) {
      EventStatus.draft => (t.muted, t.foreground),
      EventStatus.active => (t.accent, t.accentText),
      EventStatus.completed => (t.secondary, t.secondaryForeground),
    };
    return TonePill(status.label, background: background, foreground: foreground);
  }
}

/// A round avatar with initials, colored from the name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = GuyubTokens.of(context);
    const tones = [TileTone.violet, TileTone.cyan, TileTone.green, TileTone.orchid, TileTone.pink];
    final tone = tokens.tone(tones[name.runes.fold<int>(0, (sum, rune) => sum + rune) % tones.length]);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.start, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A column of fixed-height rows that shows as many as the card has room for.
/// Cards have a fixed height, so a long list cannot push the layout around.
class FitList extends StatelessWidget {
  const FitList({super.key, required this.rowHeight, required this.count, required this.builder});

  final double rowHeight;
  final int count;
  final Widget Function(BuildContext context, int index) builder;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(rowHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = math.min(count, (constraints.maxHeight / height).floor());
        return Column(
          children: [
            for (var i = 0; i < fits; i++) SizedBox(height: height, child: builder(context, i)),
          ],
        );
      },
    );
  }
}

/// List row for an event: title, status, date, and how full it is.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, this.onTap, this.showStatus = true});

  static const height = 72.0;

  final GuyubEvent event;
  final VoidCallback? onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    final capacity = event.capacity;
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius * 0.75),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(child: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
                if (showStatus) ...[const SizedBox(width: 8), EventStatusPill(event.status)],
              ],
            ),
            const SizedBox(height: 2),
            Text(formatEventDate(context, event.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: capacity == null ? (event.registeredCount > 0 ? 1 : 0) : (event.registeredCount / capacity).clamp(0, 1),
                      color: capacity == null ? tokens.chart2 : tokens.chart1,
                      backgroundColor: tokens.muted,
                      semanticsLabel: 'Registrations',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  capacity == null ? '${event.registeredCount}' : '${event.registeredCount}/$capacity',
                  style: tokens.numeric(theme.textTheme.labelSmall).copyWith(color: tokens.mutedForeground),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Seats at a glance: checked in, registered, free. Drawn in the tile's ink.
class SeatsBar extends StatelessWidget {
  const SeatsBar({super.key, required this.checkedIn, required this.registered, this.capacity});

  final int checkedIn;
  final int registered;
  final int? capacity;

  @override
  Widget build(BuildContext context) {
    final colors = TileScope.of(context);
    final waiting = math.max(0, registered - checkedIn);
    final free = capacity == null ? 0 : math.max(0, capacity! - registered);
    final segments = [
      (checkedIn, colors.ink),
      (waiting, colors.ink.withValues(alpha: 0.45)),
      (free, colors.soft),
    ].where((segment) => segment.$1 > 0).toList();
    return Semantics(
      label: '$checkedIn checked in, $registered registered${capacity == null ? '' : ', $free spots left'}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 10,
          child: segments.isEmpty
              ? ColoredBox(color: colors.soft, child: const SizedBox.expand())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, segment) in segments.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(flex: segment.$1, child: ColoredBox(color: segment.$2)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// A semicircle gauge drawn in the tile's ink.
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.value, required this.label});

  /// From 0 to 1.
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = TileScope.of(context);
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    return Semantics(
      label: label,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _GaugePainter(value.clamp(0, 1), colors.soft, colors.ink)),
          Align(
            alignment: Alignment.bottomCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${(value * 100).round()}%',
                style: tokens.numeric(theme.textTheme.headlineSmall).copyWith(color: colors.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.track, this.fill);

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final radius = math.max(0.0, math.min(size.width / 2, size.height) - stroke / 2);
    final centre = Offset(size.width / 2, size.height - 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, paint..color = track);
    if (value > 0) canvas.drawArc(rect, math.pi, math.pi * value, false, paint..color = fill);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value || old.fill != fill || old.track != track;
}

/// Cumulative registrations (solid, filled) against check-ins (dashed). The two
/// differ in form as well as color, so they stay apart without relying on hue.
class AttendanceChart extends StatefulWidget {
  const AttendanceChart({super.key, required this.series});

  final AttendanceSeries series;

  @override
  State<AttendanceChart> createState() => _AttendanceChartState();
}

class _AttendanceChartState extends State<AttendanceChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    final l10n = MaterialLocalizations.of(context);
    final series = widget.series;
    final last = series.days.length - 1;
    final index = (_hover ?? last).clamp(0, last);
    final number = tokens.numeric(theme.textTheme.titleLarge);
    final small = tokens.numeric(theme.textTheme.labelSmall).copyWith(color: tokens.mutedForeground);

    Widget legend(String label, int value, Color color, {bool dashed = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(size: const Size(16, 3), painter: _LegendMark(color, dashed)),
                const SizedBox(width: 6),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground)),
              ],
            ),
            Text('$value', style: number),
          ],
        );

    return Semantics(
      label: 'Chart: ${series.registered[last]} registered and ${series.checkedIn[last]} checked in, '
          'from ${l10n.formatShortMonthDay(series.days.first)} to ${l10n.formatShortMonthDay(series.days[last])}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                legend('Registered', series.registered[index], tokens.chart1),
                legend('Checked in', series.checkedIn[index], tokens.chart5, dashed: true),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => MouseRegion(
                  onHover: (event) => setState(() {
                    final x = (event.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    _hover = (x * last).round();
                  }),
                  onExit: (_) => setState(() => _hover = null),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _AttendancePainter(
                      series: series,
                      hover: _hover,
                      registered: tokens.chart1,
                      checkedIn: tokens.chart5,
                      grid: tokens.border,
                      card: tokens.card,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.formatShortMonthDay(series.days.first), style: small),
                if (_hover != null) Text(l10n.formatShortMonthDay(series.days[index]), style: small.copyWith(color: tokens.foreground)),
                Text('Today', style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendMark extends CustomPainter {
  const _LegendMark(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dashed) {
      canvas.drawLine(Offset(0, y), Offset(5, y), paint);
      canvas.drawLine(Offset(10, y), Offset(size.width, y), paint);
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LegendMark old) => old.color != color || old.dashed != dashed;
}

class _AttendancePainter extends CustomPainter {
  const _AttendancePainter({
    required this.series,
    required this.hover,
    required this.registered,
    required this.checkedIn,
    required this.grid,
    required this.card,
  });

  final AttendanceSeries series;
  final int? hover;
  final Color registered;
  final Color checkedIn;
  final Color grid;
  final Color card;

  @override
  void paint(Canvas canvas, Size size) {
    final count = series.days.length;
    if (count == 0 || size.isEmpty) return;
    final top = series.registered.fold<int>(1, math.max).toDouble();
    const pad = 6.0;
    double x(int i) => count == 1 ? size.width / 2 : i / (count - 1) * size.width;
    double y(num v) => size.height - pad - (v / top) * (size.height - 2 * pad);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final fraction in const [0.25, 0.5, 0.75]) {
      final lineY = size.height * fraction;
      for (double dashX = 0; dashX < size.width; dashX += 6) {
        canvas.drawLine(Offset(dashX, lineY), Offset(dashX + 2, lineY), gridPaint);
      }
    }

    Path smooth(List<int> values) {
      final path = Path()..moveTo(x(0), y(values[0]));
      for (var i = 1; i < count; i++) {
        final mid = (x(i - 1) + x(i)) / 2;
        path.cubicTo(mid, y(values[i - 1]), mid, y(values[i]), x(i), y(values[i]));
      }
      return path;
    }

    final line = smooth(series.registered);
    final fill = Path.from(line)
      ..lineTo(x(count - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [registered.withValues(alpha: 0.28), registered.withValues(alpha: 0.02)],
        ).createShader(Offset.zero & size),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(line, stroke..color = registered);

    stroke.color = checkedIn;
    for (final PathMetric metric in smooth(series.checkedIn).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), stroke);
      }
    }

    final index = hover ?? count - 1;
    if (hover != null) canvas.drawLine(Offset(x(index), 0), Offset(x(index), size.height), gridPaint);
    final dot = Paint();
    void marker(num value, Color color) {
      final at = Offset(x(index), y(value));
      canvas.drawCircle(at, 6, dot..color = card);
      canvas.drawCircle(at, 4, dot..color = color);
    }

    marker(series.checkedIn[index], checkedIn);
    marker(series.registered[index], registered);
  }

  @override
  bool shouldRepaint(_AttendancePainter old) =>
      old.series != series || old.hover != hover || old.registered != registered || old.card != card;
}
