import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wyraz twarzy pingwinka - zmienia się w zależności od progresu.
enum PenguinMood { sad, neutral, happy }

/// Replika pingwinka z app.js na Bangle.js 2.
/// Rysowany proceduralnie przez prostokąty/koła - dokładnie tak jak na zegarku
/// (przez g.fillRect), żeby UI apki było 1:1 z UI zegarka.
///
/// Bazowe proporcje są z mockupu 176×176; CustomPainter skaluje je do size.
class PenguinPainter extends CustomPainter {
  final PenguinMood mood;
  final bool blinking;

  PenguinPainter({required this.mood, this.blinking = false});

  // Kolory pingwinka - te same co w wersji Espruino.
  static const _body = Color(0xFF1A1A1A); // czarny korpus
  static const _belly = Color(0xFFF5F5F5); // biały brzuszek
  static const _beak = Color(0xFFFFA726); // pomarańczowy dziób
  static const _feet = Color(0xFFFFA726); // pomarańczowe stopki
  static const _eye = Color(0xFFFFFFFF); // białko oka
  static const _pupil = Color(0xFF000000); // źrenica

  @override
  void paint(Canvas canvas, Size size) {
    // Skala - bazowy projekt jest na 100×100 jednostek wewnętrznych.
    final s = size.shortestSide / 100;
    canvas.translate(
      (size.width - 100 * s) / 2,
      (size.height - 100 * s) / 2,
    );
    canvas.scale(s);

    final paint = Paint();

    // Korpus (jajowaty owal).
    paint.color = _body;
    canvas.drawOval(const Rect.fromLTWH(20, 18, 60, 72), paint);

    // Brzuszek (mniejszy biały owal nałożony na korpus).
    paint.color = _belly;
    canvas.drawOval(const Rect.fromLTWH(32, 35, 36, 50), paint);

    // Oczy - lekko oddalone, biały owal + czarna źrenica.
    if (!blinking) {
      paint.color = _eye;
      canvas.drawOval(const Rect.fromLTWH(34, 32, 10, 12), paint);
      canvas.drawOval(const Rect.fromLTWH(56, 32, 10, 12), paint);

      paint.color = _pupil;
      // Pozycja źrenicy zależy od nastroju.
      final pupilY = switch (mood) {
        PenguinMood.happy => 35.0,
        PenguinMood.neutral => 37.0,
        PenguinMood.sad => 39.0,
      };
      canvas.drawOval(Rect.fromLTWH(37, pupilY, 4, 5), paint);
      canvas.drawOval(Rect.fromLTWH(59, pupilY, 4, 5), paint);
    } else {
      // Mrugnięcie - kreska zamiast oczu.
      paint
        ..color = _pupil
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(34, 39), const Offset(44, 39), paint);
      canvas.drawLine(const Offset(56, 39), const Offset(66, 39), paint);
      paint.style = PaintingStyle.fill;
    }

    // Dziób - trójkąt pomarańczowy, kierunek zależy od nastroju.
    paint.color = _beak;
    final beakPath = Path();
    switch (mood) {
      case PenguinMood.happy:
        // Uśmiechnięty - dziób lekko podniesiony.
        beakPath
          ..moveTo(44, 48)
          ..lineTo(56, 48)
          ..lineTo(50, 56)
          ..close();
      case PenguinMood.neutral:
        beakPath
          ..moveTo(44, 49)
          ..lineTo(56, 49)
          ..lineTo(50, 55)
          ..close();
      case PenguinMood.sad:
        // Smutny - dziób opuszczony.
        beakPath
          ..moveTo(44, 50)
          ..lineTo(56, 50)
          ..lineTo(50, 58)
          ..close();
    }
    canvas.drawPath(beakPath, paint);

    // Stopki - dwa małe pomarańczowe owale na dole.
    paint.color = _feet;
    canvas.drawOval(const Rect.fromLTWH(30, 85, 14, 8), paint);
    canvas.drawOval(const Rect.fromLTWH(56, 85, 14, 8), paint);

    // Skrzydełka - małe owale po bokach.
    paint.color = _body;
    canvas.save();
    canvas.translate(22, 48);
    canvas.rotate(-0.3);
    canvas.drawOval(const Rect.fromLTWH(-4, -6, 8, 28), paint);
    canvas.restore();

    canvas.save();
    canvas.translate(78, 48);
    canvas.rotate(0.3);
    canvas.drawOval(const Rect.fromLTWH(-4, -6, 8, 28), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PenguinPainter old) =>
      old.mood != mood || old.blinking != blinking;
}

/// Widget z pingwinkiem + animacja mrugania co kilka sekund.
class AnimatedPenguin extends StatefulWidget {
  final PenguinMood mood;
  final double size;

  const AnimatedPenguin({
    super.key,
    required this.mood,
    this.size = 120,
  });

  @override
  State<AnimatedPenguin> createState() => _AnimatedPenguinState();
}

class _AnimatedPenguinState extends State<AnimatedPenguin> {
  bool _blinking = false;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    // Losowo co 2-6 sekund. Mrugnięcie trwa 120ms.
    final delayMs = 2000 + _rand.nextInt(4000);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _blinking = true);
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleNextBlink();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: PenguinPainter(mood: widget.mood, blinking: _blinking),
      ),
    );
  }
}
