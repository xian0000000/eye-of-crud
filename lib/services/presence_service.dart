import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceInfo {
  final String uid;
  final String name;
  final bool online;
  PresenceInfo({required this.uid, required this.name, required this.online});
}

class PresenceService {
  final _db = FirebaseDatabase.instance;
  DatabaseReference? _myRef;

  Future<void> goOnline(String caseId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = _db.ref('presence/$caseId/${user.uid}');
    _myRef = ref;
    await ref.onDisconnect().update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
    await ref.set({
      'name': user.email ?? 'Detektif',
      'online': true,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Future<void> goOffline() async {
    final ref = _myRef;
    if (ref == null) return;
    await ref.update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Stream<List<PresenceInfo>> watch(String caseId) {
    return _db.ref('presence/$caseId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <PresenceInfo>[];
      return data.entries.map((e) {
        final m = Map<dynamic, dynamic>.from(e.value as Map);
        return PresenceInfo(
          uid: e.key.toString(),
          name: m['name'] as String? ?? '?',
          online: m['online'] as bool? ?? false,
        );
      }).toList();
    });
  }
}
