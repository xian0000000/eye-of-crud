import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/chat_message.dart';

class ChatService {
  final _db = FirebaseDatabase.instance;

  DatabaseReference _chatRef(String caseId) => _db.ref('chats/$caseId');

  Stream<List<ChatMessage>> messages(String caseId) {
    return _chatRef(caseId).orderByChild('ts').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <ChatMessage>[];
      final list = data.entries
          .map((e) => ChatMessage.fromMap(
              e.key.toString(), Map<dynamic, dynamic>.from(e.value as Map)))
          .toList();
      list.sort((a, b) => a.ts.compareTo(b.ts));
      return list;
    });
  }

  Future<void> send(String caseId, {required String text}) {
    final user = FirebaseAuth.instance.currentUser!;
    return _chatRef(caseId).push().set({
      'senderUid': user.uid,
      'senderName': user.email ?? 'Detektif',
      'text': text.trim(),
      'ts': ServerValue.timestamp,
    });
  }
}
