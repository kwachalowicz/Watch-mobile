import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dwa koncentryczne ringi - kroki (zewnętrzny) i nawyki (wewnętrzny).
/// Replikuje ten sam układ co na zegarku w app.js.
class RingsPainter extends CustomPainter {
  final double stepsProgress; // 0.0 - 1.0
  final double habitsProgress; // 0.0 - 1.0
  final double strokeWidth;

  RingsPainter({
    required this.stepsProgress,
    required this.habitsProgress,
    this.strokeWidth = 12,
  });

  static const _stepsColor = Color(0xFF1E88E5); // niebieski - kroki
  static const _stepsTrack = Color(0xFF1E88E5); // pasek pod (przyciemniony)
  static const _habitsColor = Color(0xFF43A047); // zielony - nawyki
  static const _habitsTrack = Color(0xFF43A047);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2 - strokeWidth / 2;
    final innerRadius = outerRadius - strokeWidth - 4;

    _drawRing(
      canvas,
      center,
      outerRadius,
      _stepsColor,
      _stepsTrack,
      stepsProgress,
    );
    _drawRing(
      canvas,
      center,
      innerRadius,
      _habitsColor,
      _habitsTrack,
      habitsProgress,
    );
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    Color trackColor,
    double progress,
  ) {
    final track = Paint()
      ..color = trackColor.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Track (pełny okrąg, przyciemniony).
    canvas.drawCircle(center, radius, track);

    // Foreground - łuk od góry (-90°), zgodnie z ruchem wskazówek.
    final sweep = (progress.clamp(0, 1)) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(RingsPainter old) =>
      old.stepsProgress != stepsProgress ||
      old.habitsProgress != habitsProgress;
}
