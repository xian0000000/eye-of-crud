import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';

class ChatPanel extends StatefulWidget {
  final String caseId;
  const ChatPanel({super.key, required this.caseId});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _chatService = ChatService();
  final _presenceService = PresenceService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _chatService.send(widget.caseId, text: text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return Column(
      children: [
        _PresenceBar(stream: _presenceService.watch(widget.caseId)),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _chatService.messages(widget.caseId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <ChatMessage>[];
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final mine = m.senderUid == myUid;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!mine)
                            Text(m.senderName,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(m.text),
                          Text(
                            m.ts == 0
                                ? ''
                                : DateFormat('HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(m.ts)),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ketik pesan...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresenceBar extends StatelessWidget {
  final Stream<List<PresenceInfo>> stream;
  const _PresenceBar({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PresenceInfo>>(
      stream: stream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <PresenceInfo>[];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Wrap(
            spacing: 8,
            children: list.map((p) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: p.online ? Colors.green : Colors.grey,
                  radius: 6,
                ),
                label: Text(p.name, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
