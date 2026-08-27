import 'package:flutter/material.dart';

enum BoardItemType { photo, note }

class BoardItem {
  final String id;
  final BoardItemType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final String text;
  final double fontSize;
  final String? imageBase64;
  final int color;
  final int zIndex;
  final String createdBy;

  BoardItem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.text,
    required this.fontSize,
    required this.imageBase64,
    required this.color,
    required this.zIndex,
    required this.createdBy,
  });

  Offset get center => Offset(x + width / 2, y + height / 2);

  factory BoardItem.fromMap(String id, Map<dynamic, dynamic> data) {
    return BoardItem(
      id: id,
      type: (data['type'] as String? ?? 'note') == 'photo'
          ? BoardItemType.photo
          : BoardItemType.note,
      x: (data['x'] as num? ?? 0).toDouble(),
      y: (data['y'] as num? ?? 0).toDouble(),
      width: (data['width'] as num? ?? 160).toDouble(),
      height: (data['height'] as num? ?? 160).toDouble(),
      rotation: (data['rotation'] as num? ?? 0).toDouble(),
      text: data['text'] as String? ?? '',
      fontSize: (data['fontSize'] as num? ?? 20).toDouble(),
      imageBase64: data['imageBase64'] as String?,
      color: (data['color'] as num? ?? 0xFFFFF59D).toInt(),
      zIndex: (data['zIndex'] as num? ?? 0).toInt(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}
