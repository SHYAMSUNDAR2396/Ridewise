import 'package:flutter/material.dart';

const _palettes = [
  [Color(0xFF2563EB), Color(0xFF1E1B8F)],
  [Color(0xFFF59E0B), Color(0xFFB45309)],
  [Color(0xFF10B981), Color(0xFF065F46)],
  [Color(0xFFEC4899), Color(0xFF7C1D6F)],
  [Color(0xFF0EA5E9), Color(0xFF0F3D6B)],
  [Color(0xFF8B5CF6), Color(0xFF3B1D8F)],
];

// Route curve (SVG-style cubic segments in a 100x100 box) and its marker dot.
const _routes = [
  (
    m: Offset(-5, 78),
    c: [
      Offset(25, 78),
      Offset(25, 38),
      Offset(52, 38),
      Offset(80, 38),
      Offset(80, 22),
      Offset(105, 22),
    ],
    dot: Offset(52, 38),
  ),
  (
    m: Offset(-5, 30),
    c: [
      Offset(30, 30),
      Offset(30, 70),
      Offset(58, 70),
      Offset(85, 70),
      Offset(85, 55),
      Offset(105, 60),
    ],
    dot: Offset(58, 70),
  ),
  (
    m: Offset(-5, 60),
    c: [
      Offset(20, 60),
      Offset(30, 25),
      Offset(55, 30),
      Offset(85, 35),
      Offset(85, 75),
      Offset(105, 50),
    ],
    dot: Offset(55, 30),
  ),
];

int _hash(String seed) {
  var value = 0;
  for (final unit in seed.codeUnits) {
    value = (value * 31 + unit) & 0xFFFFFFFF;
  }
  return value;
}

/// Cover art: a diagonal gradient and a route line, picked deterministically from [seed].
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.seed,
    required this.size,
    this.radius,
  });

  final String seed;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final h = _hash(seed);
    final colors = _palettes[h % _palettes.length];
    final route = _routes[h % _routes.length];
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? size * 0.09),
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: CustomPaint(
              painter: _RoutePainter(route.m, route.c, route.dot),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.start, this.points, this.dot);
  final Offset start;
  final List<Offset> points;
  final Offset dot;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    Offset p(Offset o) => Offset(o.dx * k, o.dy * k);
    final path = Path()..moveTo(p(start).dx, p(start).dy);
    for (var i = 0; i < points.length; i += 3) {
      path.cubicTo(
        p(points[i]).dx,
        p(points[i]).dy,
        p(points[i + 1]).dx,
        p(points[i + 1]).dy,
        p(points[i + 2]).dx,
        p(points[i + 2]).dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * k
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x99FFFFFF),
    );
    canvas.drawCircle(p(dot), 4 * k, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => false;
}
