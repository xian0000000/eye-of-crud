import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../services/auth_service.dart';
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
  final _authService = AuthService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Created once — see the matching comment in case_board_screen.dart.
  late final Stream<List<ChatMessage>> _messagesStream;
  late final Stream<List<PresenceInfo>> _presenceStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.messages(widget.caseId);
    _presenceStream = _presenceService.watch(widget.caseId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await _chatService.send(widget.caseId, text: text);
    } catch (e) {
      // Was previously a fire-and-forget call: a permission/network error
      // failed silently, which just looked like "chat doesn't work" with
      // no clue why. Surface it instead.
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal kirim pesan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser!.uid;
    return Column(
      children: [
        _PresenceBar(stream: _presenceStream),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messagesStream,
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
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
                            Text(
                              m.senderName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(m.text),
                          Text(
                            m.ts == 0
                                ? ''
                                : DateFormat('HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(m.ts),
                                  ),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black54,
                            ),
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
