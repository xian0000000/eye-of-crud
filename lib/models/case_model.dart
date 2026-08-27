class CaseModel {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final List<String> members;
  final DateTime? createdAt;

  CaseModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  /// [data] is the RTDB node for this case — `members` is a `{uid: true}`
  /// map there (not a list), since RTDB has no array-contains query; a map
  /// gives O(1) membership checks in both security rules and client code.
  factory CaseModel.fromMap(String id, Map<dynamic, dynamic> data) {
    final membersMap = data['members'];
    final createdAtMillis = data['createdAt'];
    return CaseModel(
      id: id,
      name: data['name'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      members: membersMap is Map
          ? membersMap.keys.map((k) => k.toString()).toList()
          : const [],
      createdAt: createdAtMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMillis)
          : null,
    );
  }
}
