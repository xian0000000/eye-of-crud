import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

import '../models/case_model.dart';
import '../rest/rtdb_rest.dart';
import '../utils/platform_support.dart';
import 'current_user.dart';

class CaseService {
  // Getter, not an eagerly-initialized field — see AuthService's _auth.
  FirebaseDatabase get _db => FirebaseDatabase.instance;

  DatabaseReference get _casesRef => _db.ref('cases');

  Stream<List<CaseModel>> myCases() {
    if (isLinuxDesktop) {
      return RtdbRest.watch('cases').map(_myCasesFrom);
    }
    return _casesRef.onValue.map((event) => _myCasesFrom(event.snapshot.value));
  }

  List<CaseModel> _myCasesFrom(dynamic data) {
    if (data == null || data is! Map) return const [];
    final mine =
        data.entries
            .map(
              (e) => CaseModel.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ),
            )
            .where((c) => c.members.contains(CurrentUser.uid))
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
    return mine;
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<CaseModel> createCase(String name) async {
    final code = _generateInviteCode();
    final resolvedName = name.trim().isEmpty ? 'Kasus Tanpa Nama' : name.trim();
    final fields = {
      'name': resolvedName,
      'inviteCode': code,
      'createdBy': CurrentUser.uid,
      'members': {CurrentUser.uid: true},
    };
    final String id;
    if (isLinuxDesktop) {
      id = await RtdbRest.pushAndReturnKey('cases', {
        ...fields,
        'createdAt': RtdbRest.serverTimestamp,
      });
    } else {
      final ref = _casesRef.push();
      await ref.set({...fields, 'createdAt': ServerValue.timestamp});
      id = ref.key!;
    }
    // Server timestamp resolves moments later than this — close enough for
    // a case you just created yourself and are about to open.
    return CaseModel(
      id: id,
      name: resolvedName,
      inviteCode: code,
      createdBy: CurrentUser.uid,
      members: [CurrentUser.uid],
      createdAt: DateTime.now(),
    );
  }

  Future<String?> joinByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return 'Masukkan kode undangan.';

    if (isLinuxDesktop) {
      final data = await RtdbRest.get('cases');
      if (data is! Map) return 'Kode undangan tidak ditemukan.';
      MapEntry<dynamic, dynamic>? match;
      for (final e in data.entries) {
        if ((e.value as Map)['inviteCode'] == normalized) {
          match = e;
          break;
        }
      }
      if (match == null) return 'Kode undangan tidak ditemukan.';
      final caseId = match.key.toString();
      final members = Map<dynamic, dynamic>.from(
        (match.value as Map)['members'] as Map? ?? const {},
      );
      if (members.containsKey(CurrentUser.uid)) return null;
      await RtdbRest.patch('cases/$caseId/members', {CurrentUser.uid: true});
      return null;
    }

    final query = await _casesRef
        .orderByChild('inviteCode')
        .equalTo(normalized)
        .limitToFirst(1)
        .get();
    if (!query.exists) {
      return 'Kode undangan tidak ditemukan.';
    }
    final entry = (query.value as Map).entries.first;
    final caseId = entry.key.toString();
    final members = Map<dynamic, dynamic>.from(
      (entry.value as Map)['members'] as Map? ?? const {},
    );
    if (members.containsKey(CurrentUser.uid)) {
      return null;
    }
    await _casesRef.child(caseId).child('members').update({
      CurrentUser.uid: true,
    });
    return null;
  }
}
