import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../rest/rtdb_rest.dart';
import '../utils/platform_support.dart';
import 'current_user.dart';

class PresenceInfo {
  final String uid;
  final String name;
  final bool online;
  PresenceInfo({required this.uid, required this.name, required this.online});
}

class PresenceService {
  // Getter, not an eagerly-initialized field — see AuthService's _auth.
  FirebaseDatabase get _db => FirebaseDatabase.instance;
  DatabaseReference? _myRef;
  String? _myRestPath;

  Future<void> goOnline(String caseId) async {
    if (isLinuxDesktop) {
      final path = 'presence/$caseId/${CurrentUser.uid}';
      _myRestPath = path;
      // No REST equivalent of onDisconnect() — a plain HTTP write can't
      // register a server-side cleanup hook the way a persistent connection
      // can, so on an ungraceful exit this entry stays "online" until
      // someone else's client overwrites it. Acceptable on a desktop
      // fallback that's normally closed cleanly (goOffline runs on dispose).
      await RtdbRest.put(path, {
        'name': CurrentUser.displayName,
        'online': true,
        'lastSeen': RtdbRest.serverTimestamp,
      });
      return;
    }
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
    if (isLinuxDesktop) {
      final path = _myRestPath;
      if (path == null) return;
      await RtdbRest.patch(path, {
        'online': false,
        'lastSeen': RtdbRest.serverTimestamp,
      });
      return;
    }
    final ref = _myRef;
    if (ref == null) return;
    await ref.update({'online': false, 'lastSeen': ServerValue.timestamp});
  }

  Stream<List<PresenceInfo>> watch(String caseId) {
    if (isLinuxDesktop) {
      return RtdbRest.watch('presence/$caseId').map((data) {
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
