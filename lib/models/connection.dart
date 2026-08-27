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

  factory BoardConnection.fromMap(String id, Map<dynamic, dynamic> data) {
    return BoardConnection(
      id: id,
      fromItemId: data['fromItemId'] as String? ?? '',
      toItemId: data['toItemId'] as String? ?? '',
      color: (data['color'] as num? ?? 0xFFE53935).toInt(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}
