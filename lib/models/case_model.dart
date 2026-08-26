import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CaseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CaseModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      members: List<String>.from(data['members'] as List? ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
