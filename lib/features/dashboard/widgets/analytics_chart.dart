import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/flat_theme.dart';
import '../services/analytics_calculations.dart';

class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.color,
    required this.children,
    this.info,
    this.onInfo,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final String? info;
  final VoidCallback? onInfo;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: Flat.cardBox(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Flat.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (info != null || onInfo != null)
              IconButton(
                tooltip: 'Thông tin $title',
                onPressed:
                    onInfo ?? () => showAnalyticsDetail(context, title, info!),
                icon: const Icon(
                  Icons.info_outline,
                  size: 19,
                  color: Flat.muted,
                ),
              ),
          ],
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: const TextStyle(color: Flat.muted, fontSize: 12),
          ),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(top: 10), child: child),
        const SizedBox(height: 4),
      ],
    ),
  );
}

class AnalyticsKpi extends StatelessWidget {
  const AnalyticsKpi({
    super.key,
    required this.value,
    required this.label,
    this.color = Flat.text,
    this.unit,
  });
  final String value, label;
  final String? unit;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (unit != null)
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 12, color: color),
              ),
          ],
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Flat.muted, fontSize: 12)),
    ],
  );
}

class AnalyticsEmpty extends StatelessWidget {
  const AnalyticsEmpty({
    super.key,
    this.message = 'Hoàn thành thêm phiên để xem xu hướng.',
  });
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.insights_outlined, size: 20, color: Flat.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Flat.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

void showAnalyticsDetail(
  BuildContext context,
  String title,
  String detail, {
  List<Widget> actions = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Flat.card,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Flat.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: const TextStyle(color: Flat.text, height: 1.5),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Null observations break the line; native touch targets expose every real point.
class AnalyticsChart extends StatelessWidget {
  const AnalyticsChart({
    super.key,
    required this.points,
    required this.color,
    required this.xLabel,
    required this.yLabel,
    required this.details,
    this.scatter = false,
    this.steps = false,
    this.maxY,
    this.maxX,
    this.minX = 0,
    this.trend,
    this.xTicks,
  });
  final List<PlotPoint?> points;
  final Color color;
  final String xLabel, yLabel;
  final List<String> details;
  final bool scatter, steps;
  final double? maxY, maxX;
  final double minX;
  final ({double slope, double intercept})? trend;
  final List<String>? xTicks;
  @override
  Widget build(BuildContext context) {
    final valid = points.nonNulls.toList();
    final xmax =
        maxX ??
        math.max(minX + 1, valid.fold<double>(0, (m, p) => math.max(m, p.x)));
    final ymax =
        maxY ??
        math.max(1.0, valid.fold<double>(0, (m, p) => math.max(m, p.y)) * 1.1);
    String tick(double n) =>
        n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    var axisWidth = 0.0;
    for (final value in [ymax, ymax / 2, 0.0]) {
      final painter = TextPainter(
        text: TextSpan(
          text: tick(value),
          style: DefaultTextStyle.of(context).style
              .merge(const TextStyle(fontSize: 10)),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      axisWidth = math.max(axisWidth, painter.width + 8);
      painter.dispose();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(yLabel, style: const TextStyle(fontSize: 11, color: Flat.muted)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: axisWidth,
              height: 144,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final y in [ymax, ymax / 2, 0.0])
                    Text(
                      tick(y),
                      style: const TextStyle(fontSize: 10, color: Flat.muted),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, box) => Semantics(
                      label:
                          '$yLabel theo $xLabel. ${valid.length} điểm dữ liệu.',
                      child: SizedBox(
                        height: 144,
                        width: box.maxWidth,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _PlotPainter(
                                  points,
                                  color,
                                  minX,
                                  xmax,
                                  ymax,
                                  scatter,
                                  steps,
                                  trend,
                                ),
                              ),
                            ),
                            for (var i = 0; i < points.length; i++)
                              if (points[i] != null)
                                Positioned(
                                  left:
                                      (8 +
                                              (points[i]!.x - minX) /
                                                  (xmax - minX) *
                                                  (box.maxWidth - 16) -
                                              22)
                                          .clamp(
                                            0.0,
                                            math.max(0, box.maxWidth - 44),
                                          ),
                                  top: (136 - points[i]!.y / ymax * 128 - 22)
                                      .clamp(0.0, 100.0),
                                  child: Semantics(
                                    label: details[i],
                                    button: true,
                                    child: Tooltip(
                                      message: details[i],
                                      child: InkWell(
                                        onTap: () => showAnalyticsDetail(
                                          context,
                                          'Chi tiết',
                                          details[i],
                                        ),
                                        child: const SizedBox(
                                          width: 44,
                                          height: 44,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (xTicks != null)
                    Row(
                      children: [
                        for (final label in xTicks!)
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Flat.muted,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tick(minX),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Flat.muted,
                          ),
                        ),
                        Text(
                          tick(xmax),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Flat.muted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            xLabel,
            style: const TextStyle(fontSize: 11, color: Flat.muted),
          ),
        ),
      ],
    );
  }
}

class _PlotPainter extends CustomPainter {
  _PlotPainter(
    this.points,
    this.color,
    this.xmin,
    this.xmax,
    this.ymax,
    this.scatter,
    this.steps,
    this.trend,
  );
  final List<PlotPoint?> points;
  final Color color;
  final double xmin, xmax, ymax;
  final bool scatter, steps;
  final ({double slope, double intercept})? trend;
  @override
  void paint(Canvas canvas, Size size) {
    Offset at(PlotPoint p) => Offset(
      8 + (p.x - xmin) / (xmax - xmin) * (size.width - 16),
      size.height - 8 - p.y / ymax * (size.height - 16),
    );
    final grid = Paint()
      ..color = Flat.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = 8 + i * (size.height - 16) / 2;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    final ink = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    Offset? previous;
    for (final p in points) {
      if (p == null) {
        previous = null;
        continue;
      }
      final current = at(p);
      if (!scatter && previous != null) {
        if (steps) {
          final corner = Offset(current.dx, previous.dy);
          canvas.drawLine(previous, corner, ink);
          canvas.drawLine(corner, current, ink);
        } else {
          canvas.drawLine(previous, current, ink);
        }
      }
      canvas.drawCircle(current, scatter ? 4 : 3, Paint()..color = color);
      previous = current;
    }
    if (trend != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(8, 8, size.width - 8, size.height - 8));
      canvas.drawLine(
        at((x: xmin, y: trend!.slope * xmin + trend!.intercept)),
        at((x: xmax, y: trend!.slope * xmax + trend!.intercept)),
        Paint()
          ..color = Flat.text.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) =>
      old.points != points ||
      old.color != color ||
      old.xmin != xmin ||
      old.xmax != xmax ||
      old.ymax != ymax ||
      old.scatter != scatter ||
      old.steps != steps ||
      old.trend != trend;
}
