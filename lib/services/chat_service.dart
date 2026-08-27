import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/chat_message.dart';
import '../rest/rtdb_rest.dart';
import '../utils/platform_support.dart';
import 'current_user.dart';

class ChatService {
  // Getter, not an eagerly-initialized field — see AuthService's _auth.
  FirebaseDatabase get _db => FirebaseDatabase.instance;

  DatabaseReference _chatRef(String caseId) => _db.ref('chats/$caseId');

  Stream<List<ChatMessage>> messages(String caseId) {
    if (isLinuxDesktop) {
      return RtdbRest.watch('chats/$caseId').map((data) {
        if (data == null || data is! Map) return <ChatMessage>[];
        final list = data.entries
            .map(
              (e) => ChatMessage.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ),
            )
            .toList();
        list.sort((a, b) => a.ts.compareTo(b.ts));
        return list;
      });
    }
    return _chatRef(caseId).orderByChild('ts').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <ChatMessage>[];
      final list = data.entries
          .map(
            (e) => ChatMessage.fromMap(
              e.key.toString(),
              Map<dynamic, dynamic>.from(e.value as Map),
            ),
          )
          .toList();
      list.sort((a, b) => a.ts.compareTo(b.ts));
      return list;
    });
  }

  Future<void> send(String caseId, {required String text}) {
    if (isLinuxDesktop) {
      return RtdbRest.push('chats/$caseId', {
        'senderUid': CurrentUser.uid,
        'senderName': CurrentUser.displayName,
        'text': text.trim(),
        'ts': RtdbRest.serverTimestamp,
      });
    }
    final user = FirebaseAuth.instance.currentUser!;
    return _chatRef(caseId).push().set({
      'senderUid': user.uid,
      'senderName': user.email ?? 'Detektif',
      'text': text.trim(),
      'ts': ServerValue.timestamp,
    });
  }
}
