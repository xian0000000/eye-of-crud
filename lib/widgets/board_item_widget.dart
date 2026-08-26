import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/board_item.dart';

class BoardItemWidget extends StatelessWidget {
  final BoardItem item;
  final bool connectMode;
  final bool isPendingFrom;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onTextChanged;

  const BoardItemWidget({
    super.key,
    required this.item,
    required this.connectMode,
    required this.isPendingFrom,
    required this.onTap,
    required this.onLongPress,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final content = item.type == BoardItemType.photo
        ? _PhotoCard(item: item, highlighted: isPendingFrom)
        : _NoteCard(
            item: item,
            highlighted: isPendingFrom,
            onTextChanged: onTextChanged,
          );

    return Positioned(
      left: item.x,
      top: item.y,
      child: GestureDetector(
        onTap: connectMode ? onTap : null,
        onLongPress: onLongPress,
        onPanUpdate: connectMode
            ? null
            : (details) => onDragUpdate(details.delta),
        onPanEnd: connectMode ? null : (_) => onDragEnd(),
        child: SizedBox(
          width: item.width,
          height: item.height,
          child: content,
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final BoardItem item;
  final bool highlighted;
  const _PhotoCard({required this.item, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    Widget image;
    try {
      image = Image.memory(
        base64Decode(item.imageBase64 ?? ''),
        fit: BoxFit.cover,
      );
    } catch (_) {
      image = const ColoredBox(
        color: Colors.grey,
        child: Icon(Icons.broken_image),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
        ],
        border: Border.all(
          color: highlighted ? Colors.red : Colors.white,
          width: highlighted ? 3 : 6,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRect(child: image),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final BoardItem item;
  final bool highlighted;
  final ValueChanged<String> onTextChanged;
  const _NoteCard({
    required this.item,
    required this.highlighted,
    required this.onTextChanged,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(_NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only pull in remote changes while the field isn't focused, so typing
    // locally never gets clobbered by the Firestore echo of our own edits.
    if (!_focusNode.hasFocus && widget.item.text != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: widget.item.text,
        selection: TextSelection.collapsed(offset: widget.item.text.length),
        composing: TextRange.empty,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(widget.item.color),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
        ],
        border: widget.highlighted ? Border.all(color: Colors.red, width: 3) : null,
      ),
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        decoration: const InputDecoration(border: InputBorder.none),
        onChanged: widget.onTextChanged,
      ),
    );
  }
}
