class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final int ts;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.ts,
  });

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: id,
      senderUid: map['senderUid'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '?',
      text: map['text'] as String? ?? '',
      ts: (map['ts'] as num?)?.toInt() ?? 0,
    );
  }
}
