import 'package:flutter/material.dart';
import '../../../data/models/theme_model.dart';

/// Miniature board drawn with a theme's real colours: background, board
/// panel, grid dots, bent arrows with their heads, and one arrow in the
/// accent colour (the colour an escaping arrow takes).
class ThemePreview extends StatelessWidget {
  final ThemeModel theme;
  final BorderRadius borderRadius;

  const ThemePreview({
    super.key,
    required this.theme,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomPaint(
          painter: _ThemePreviewPainter(theme),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ThemePreviewPainter extends CustomPainter {
  final ThemeModel theme;
  const _ThemePreviewPainter(this.theme);

  static const int _cols = 6;
  static const int _rows = 4;

  // (row, col) cells, tail → head, like ArrowModel.points.
  static const List<(String, List<(int, int)>)> _arrows = [
    ('a001', [(3, 0), (3, 2), (1, 2), (1, 3)]),
    ('a002', [(0, 0), (0, 1), (2, 1)]),
    ('a004', [(3, 5), (0, 5)]),
  ];
  static const List<(int, int)> _accentArrow = [(2, 3), (3, 3), (3, 4)];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.width / _cols).clamp(0.0, size.height / _rows);
    final origin = Offset(
      (size.width - cell * _cols) / 2,
      (size.height - cell * _rows) / 2,
    );
    Offset centre((int, int) p) =>
        origin + Offset((p.$2 + 0.5) * cell, (p.$1 + 0.5) * cell);

    final board = theme.boardColor;
    if (board != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (origin & Size(cell * _cols, cell * _rows)).deflate(cell * 0.12),
          Radius.circular(cell * 0.4),
        ),
        Paint()..color = board,
      );
    }

    final dotPaint = Paint()..color = theme.gridDotColor;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        canvas.drawCircle(centre((r, c)), cell * 0.06, dotPaint);
      }
    }

    final stroke = cell * 0.2;
    void drawArrow(List<(int, int)> points, Color body, Color head) {
      final pts = points.map(centre).toList();
      final last = pts.last;
      final prev = pts[pts.length - 2];
      final dir = (last - prev) / (last - prev).distance;
      final tip = last + dir * (cell * 0.35);
      final headSize = cell * 0.42;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final lineEnd = tip - dir * (headSize * 0.7);
      path.lineTo(lineEnd.dx, lineEnd.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = body
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final normal = Offset(-dir.dy, dir.dx);
      final base = tip - dir * headSize;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(
            base.dx + normal.dx * headSize * 0.52,
            base.dy + normal.dy * headSize * 0.52,
          )
          ..lineTo(
            base.dx - normal.dx * headSize * 0.52,
            base.dy - normal.dy * headSize * 0.52,
          )
          ..close(),
        Paint()..color = head,
      );
    }

    for (final (id, points) in _arrows) {
      final body = theme.arrowColorFor(id);
      drawArrow(points, body, theme.headColorFor(body));
    }
    drawArrow(
      _accentArrow,
      theme.accentColor,
      theme.headColorFor(theme.accentColor),
    );
  }

  @override
  bool shouldRepaint(_ThemePreviewPainter old) => old.theme.id != theme.id;
}
