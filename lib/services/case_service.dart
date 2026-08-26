import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/case_model.dart';

class CaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _cases =>
      _db.collection('cases');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<List<CaseModel>> myCases() {
    return _cases
        .where('members', arrayContains: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CaseModel.fromDoc).toList());
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<CaseModel> createCase(String name) async {
    final code = _generateInviteCode();
    final doc = await _cases.add({
      'name': name.trim().isEmpty ? 'Kasus Tanpa Nama' : name.trim(),
      'inviteCode': code,
      'createdBy': _uid,
      'members': [_uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await doc.get();
    return CaseModel.fromDoc(snap);
  }

  Future<String?> joinByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return 'Masukkan kode undangan.';
    final query = await _cases
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return 'Kode undangan tidak ditemukan.';
    }
    final doc = query.docs.first;
    final members = List<String>.from(doc.data()['members'] as List? ?? []);
    if (members.contains(_uid)) {
      return null;
    }
    await doc.reference.update({
      'members': FieldValue.arrayUnion([_uid]),
    });
    return null;
  }
}
