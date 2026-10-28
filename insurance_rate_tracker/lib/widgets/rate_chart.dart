import 'dart:math';

import 'package:flutter/material.dart';

import '../format.dart';

class ChartPoint {
  const ChartPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

class ChartSeries {
  const ChartSeries({required this.name, required this.color, required this.mine, required this.points});
  final String name;
  final Color color;
  final bool mine;
  final List<ChartPoint> points;
}

/// Line chart of each carrier's price over time.
class RateChart extends StatelessWidget {
  const RateChart({super.key, required this.series, required this.formatY});
  final List<ChartSeries> series;
  final String Function(double) formatY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = series.fold<int>(0, (a, s) => a + s.points.length);
    if (total < 2) {
      return Text('Add at least two rates to see a trend.',
          style: TextStyle(color: scheme.onSurfaceVariant));
    }
    final labelStyle = (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11))
        .copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Rate history chart',
          child: AspectRatio(
            aspectRatio: 16 / 8,
            child: CustomPaint(
              painter: _ChartPainter(
                series: series,
                formatY: formatY,
                labelStyle: labelStyle,
                grid: scheme.outlineVariant,
                ring: scheme.surface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text(s.mine ? '${s.name} (yours)' : s.name, style: theme.textTheme.bodyMedium),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.formatY,
    required this.labelStyle,
    required this.grid,
    required this.ring,
  });

  final List<ChartSeries> series;
  final String Function(double) formatY;
  final TextStyle labelStyle;
  final Color grid;
  final Color ring;

  static const _day = 86400000.0;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 62.0, r = 10.0, t = 8.0, b = 22.0;
    final pts = series.expand((s) => s.points).toList();
    if (pts.isEmpty) return;

    var x0 = pts.map((p) => p.date.millisecondsSinceEpoch).reduce(min).toDouble();
    var x1 = pts.map((p) => p.date.millisecondsSinceEpoch).reduce(max).toDouble();
    if (x1 - x0 < _day * 20) {
      x0 -= _day * 15;
      x1 += _day * 15;
    }
    var y0 = pts.map((p) => p.value).reduce(min);
    var y1 = pts.map((p) => p.value).reduce(max);
    var pad = (y1 - y0) * 0.15;
    if (pad == 0) pad = y1 * 0.1;
    if (pad == 0) pad = 1;
    y0 = max(0.0, y0 - pad);
    y1 = y1 + pad;

    double sx(double v) => l + (v - x0) / (x1 - x0) * (size.width - l - r);
    double sy(double v) => t + (1 - (v - y0) / (y1 - y0)) * (size.height - t - b);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = y0 + (y1 - y0) * i / 3;
      final y = sy(v);
      canvas.drawLine(Offset(l, y), Offset(size.width - r, y), gridPaint);
      _label(canvas, formatY(v), l - 6, y, anchor: 1, vCenter: true);
    }
    for (var i = 0; i <= 3; i++) {
      final ms = x0 + (x1 - x0) * i / 3;
      final d = DateTime.fromMillisecondsSinceEpoch(ms.round());
      _label(canvas, fmtShortDate(d), sx(ms), size.height - b + 6, anchor: i == 0 ? -1 : (i == 3 ? 1 : 0));
    }

    // Draw the user's own carrier last so it sits on top.
    final ordered = [...series.where((s) => !s.mine), ...series.where((s) => s.mine)];
    for (final s in ordered) {
      final offs = s.points
          .map((p) => Offset(sx(p.date.millisecondsSinceEpoch.toDouble()), sy(p.value)))
          .toList();
      if (offs.length > 1) {
        final path = Path()..moveTo(offs.first.dx, offs.first.dy);
        for (final o in offs.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.mine ? 3.5 : 2
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = s.color,
        );
      }
      for (final o in offs) {
        canvas.drawCircle(o, s.mine ? 6.5 : 5.5, Paint()..color = ring);
        canvas.drawCircle(o, s.mine ? 4.5 : 3.5, Paint()..color = s.color);
      }
    }
  }

  /// anchor: -1 left edge at x, 0 centered, 1 right edge at x.
  void _label(Canvas canvas, String text, double x, double y, {int anchor = -1, bool vCenter = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final dx = anchor == 1 ? x - tp.width : (anchor == 0 ? x - tp.width / 2 : x);
    final dy = vCenter ? y - tp.height / 2 : y;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
