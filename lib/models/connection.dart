import 'package:cloud_firestore/cloud_firestore.dart';

class BoardConnection {
  final String id;
  final String fromItemId;
  final String toItemId;
  final int color;
  final String createdBy;

  BoardConnection({
    required this.id,
    required this.fromItemId,
    required this.toItemId,
    required this.color,
    required this.createdBy,
  });

  factory BoardConnection.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BoardConnection(
      id: doc.id,
      fromItemId: data['fromItemId'] as String? ?? '',
      toItemId: data['toItemId'] as String? ?? '',
      color: (data['color'] as num? ?? 0xFFE53935).toInt(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}
