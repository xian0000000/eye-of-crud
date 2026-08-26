import 'package:flutter/material.dart';

import '../models/board_item.dart';
import '../models/connection.dart';

class StringPainter extends CustomPainter {
  final List<BoardItem> items;
  final List<BoardConnection> connections;
  final String? pendingFromId;
  final Offset? pendingPointer;

  StringPainter({
    required this.items,
    required this.connections,
    this.pendingFromId,
    this.pendingPointer,
  });

  BoardItem? _findItem(String id) {
    for (final it in items) {
      if (it.id == id) return it;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final conn in connections) {
      final from = _findItem(conn.fromItemId);
      final to = _findItem(conn.toItemId);
      if (from == null || to == null) continue;
      paint.color = Color(conn.color);
      canvas.drawLine(from.center, to.center, paint);
    }

    if (pendingFromId != null && pendingPointer != null) {
      final from = _findItem(pendingFromId!);
      if (from != null) {
        paint.color = Colors.red.withValues(alpha: 0.6);
        canvas.drawLine(from.center, pendingPointer!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StringPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.connections != connections ||
        oldDelegate.pendingFromId != pendingFromId ||
        oldDelegate.pendingPointer != pendingPointer;
  }
}
