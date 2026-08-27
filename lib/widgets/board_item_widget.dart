import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/board_item.dart';
import 'board_action_bar.dart';

/// A card on the board. By default it shows nothing but the photo/note
/// itself — no handles, no buttons — so the board stays clean. Tapping it
/// (unless [locked]) selects it, which shows a colored outline here and
/// opens the fixed on-screen [BoardActionBar] elsewhere. Moving/resizing
/// only happens after picking "Geser"/"Ukuran" from that bar — while
/// [activeAction] is set, dragging anywhere on this card performs it.
class BoardItemWidget extends StatelessWidget {
  final BoardItem item;
  final bool isSelected;
  final bool isPendingFrom;
  final bool locked;
  final ItemAction activeAction;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<Offset> onResizeUpdate;
  final VoidCallback onResizeEnd;
  final ValueChanged<String> onTextChanged;

  const BoardItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isPendingFrom,
    required this.locked,
    required this.activeAction,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onTextChanged,
  });

  Color? get _borderColor {
    if (isPendingFrom) return Colors.redAccent;
    if (activeAction == ItemAction.move) return Colors.orangeAccent;
    if (activeAction == ItemAction.resize) return Colors.purpleAccent;
    if (isSelected) return Colors.blueAccent;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor;
    final editingText = isSelected && activeAction == ItemAction.editText;
    final content = item.type == BoardItemType.photo
        ? _PhotoCard(item: item, borderColor: borderColor)
        : _NoteCard(
            item: item,
            borderColor: borderColor,
            editing: editingText,
            onTextChanged: onTextChanged,
          );

    final dragging =
        isSelected &&
        !locked &&
        (activeAction == ItemAction.move || activeAction == ItemAction.resize);

    return Positioned(
      left: item.x,
      top: item.y,
      child: SizedBox(
        width: item.width,
        height: item.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Not while actively typing — the TextField itself owns
              // taps then; ending the tap here would fight it for focus.
              onTap: locked || editingText ? null : onTap,
              // Only active once "Geser"/"Ukuran" is picked from the
              // bottom bar — otherwise a plain tap reaches the note's
              // TextField / photo untouched, no gesture competition.
              onPanUpdate: !dragging
                  ? null
                  : (details) => activeAction == ItemAction.move
                        ? onDragUpdate(details.delta)
                        : onResizeUpdate(details.delta),
              onPanEnd: !dragging
                  ? null
                  : (_) => activeAction == ItemAction.move
                        ? onDragEnd()
                        : onResizeEnd(),
              child: content,
            ),
            const Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(child: _PushPin()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushPin extends StatelessWidget {
  const _PushPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFE0E0E0), Color(0xFF616161)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatefulWidget {
  final BoardItem item;
  final Color? borderColor;
  const _PhotoCard({required this.item, required this.borderColor});

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<_PhotoCard> {
  Uint8List? _bytes;
  String? _decodedFrom;

  @override
  Widget build(BuildContext context) {
    // Cache the decoded bytes across rebuilds: base64Decode allocates a new
    // Uint8List every call, and Image.memory's cache identity is based on
    // that list's identity — decoding fresh on every REST poll (~1/sec)
    // made the photo flicker as it was treated as a brand-new image each
    // time. Re-decode only when the photo itself actually changed (e.g.
    // after "Ganti Foto").
    if (_decodedFrom != widget.item.imageBase64) {
      _decodedFrom = widget.item.imageBase64;
      try {
        _bytes = base64Decode(widget.item.imageBase64 ?? '');
      } catch (_) {
        _bytes = null;
      }
    }

    final bytes = _bytes;
    final image = bytes == null
        ? const ColoredBox(color: Colors.grey, child: Icon(Icons.broken_image))
        : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
        ],
        border: Border.all(
          color: widget.borderColor ?? Colors.white,
          width: widget.borderColor != null ? 4 : 6,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRect(child: image),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final BoardItem item;
  final Color? borderColor;
  final bool editing;
  final ValueChanged<String> onTextChanged;
  const _NoteCard({
    required this.item,
    required this.borderColor,
    required this.editing,
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
    // locally never gets clobbered by the server echo of our own edits.
    if (!_focusNode.hasFocus && widget.item.text != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: widget.item.text,
        selection: TextSelection.collapsed(offset: widget.item.text.length),
        composing: TextRange.empty,
      );
    }
    // Entering "Teks" mode from the bottom bar should pop the keyboard up
    // immediately, not require a second tap on the field.
    if (widget.editing && !oldWidget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    if (!widget.editing && oldWidget.editing) {
      _focusNode.unfocus();
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
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!, width: 4)
            : null,
      ),
      padding: const EdgeInsets.all(10),
      // Not editable until "Teks" is picked from the bottom bar — a plain
      // tap just selects the note (see the outer GestureDetector) instead
      // of immediately popping the keyboard up.
      child: AbsorbPointer(
        absorbing: !widget.editing,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          expands: true,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: widget.item.fontSize,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
          onChanged: widget.onTextChanged,
        ),
      ),
    );
  }
}
