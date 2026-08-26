import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/board_item.dart';
import '../models/case_model.dart';
import '../models/connection.dart';
import '../services/board_service.dart';
import '../services/presence_service.dart';
import '../utils/image_utils.dart';
import '../widgets/board_item_widget.dart';
import '../widgets/chat_panel.dart';
import '../widgets/string_painter.dart';

const List<Color> noteColors = [
  Color(0xFFFFF59D),
  Color(0xFFA5D6A7),
  Color(0xFF90CAF9),
  Color(0xFFF48FB1),
  Color(0xFFFFCC80),
];

const double boardSize = 4000;

class CaseBoardScreen extends StatefulWidget {
  final CaseModel caseModel;
  const CaseBoardScreen({super.key, required this.caseModel});

  @override
  State<CaseBoardScreen> createState() => _CaseBoardScreenState();
}

class _CaseBoardScreenState extends State<CaseBoardScreen> {
  final _boardService = BoardService();
  final _presenceService = PresenceService();
  final _picker = ImagePicker();
  final Map<String, Offset> _dragPositions = {};
  final Map<String, Timer> _textDebounce = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _connectMode = false;
  String? _pendingFromId;

  @override
  void initState() {
    super.initState();
    _presenceService.goOnline(widget.caseModel.id);
  }

  @override
  void dispose() {
    _presenceService.goOffline();
    for (final t in _textDebounce.values) {
      t.cancel();
    }
    super.dispose();
  }

  BoardItem _withDrag(BoardItem item) {
    final pos = _dragPositions[item.id];
    if (pos == null) return item;
    return BoardItem(
      id: item.id,
      type: item.type,
      x: pos.dx,
      y: pos.dy,
      width: item.width,
      height: item.height,
      rotation: item.rotation,
      text: item.text,
      imageBase64: item.imageBase64,
      color: item.color,
      zIndex: item.zIndex,
      createdBy: item.createdBy,
    );
  }

  Future<void> _addNote() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Warna Catatan'),
        content: Wrap(
          spacing: 10,
          children: noteColors
              .map((c) => GestureDetector(
                    onTap: () => Navigator.pop(context, c),
                    child: CircleAvatar(backgroundColor: c, radius: 18),
                  ))
              .toList(),
        ),
      ),
    );
    if (color == null) return;
    _boardService.addNote(widget.caseModel.id,
        x: boardSize / 2 - 90, y: boardSize / 2 - 90, color: color.toARGB32());
  }

  Future<void> _addPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final encoded = encodeImageBytes(bytes);
    if (encoded.tooLarge) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Foto kegedean buat disimpan. Coba foto lain atau kompres dulu.'),
      ));
      return;
    }
    _boardService.addPhoto(
      widget.caseModel.id,
      x: boardSize / 2 - 100,
      y: boardSize / 2 - 100,
      base64: encoded.base64,
      width: 200,
      height: 200,
    );
  }

  void _onItemTap(BoardItem item, List<BoardConnection> connections) {
    if (!_connectMode) return;
    if (_pendingFromId == null) {
      setState(() => _pendingFromId = item.id);
      return;
    }
    if (_pendingFromId == item.id) {
      setState(() => _pendingFromId = null);
      return;
    }
    final existing = connections.where((c) =>
        (c.fromItemId == _pendingFromId && c.toItemId == item.id) ||
        (c.toItemId == _pendingFromId && c.fromItemId == item.id));
    if (existing.isNotEmpty) {
      _boardService.deleteConnection(widget.caseModel.id, existing.first.id);
    } else {
      _boardService.addConnection(widget.caseModel.id, _pendingFromId!, item.id);
    }
    setState(() => _pendingFromId = null);
  }

  Future<void> _onItemLongPress(BoardItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus item ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) {
      _boardService.deleteItem(widget.caseModel.id, item.id);
    }
  }

  void _onTextChanged(BoardItem item, String text) {
    _textDebounce[item.id]?.cancel();
    _textDebounce[item.id] = Timer(const Duration(milliseconds: 400), () {
      _boardService.updateText(widget.caseModel.id, item.id, text);
    });
  }

  Widget _buildBoard() {
    return StreamBuilder<List<BoardItem>>(
      stream: _boardService.items(widget.caseModel.id),
      builder: (context, itemsSnap) {
        final items = itemsSnap.data ?? const <BoardItem>[];
        return StreamBuilder<List<BoardConnection>>(
          stream: _boardService.connections(widget.caseModel.id),
          builder: (context, connSnap) {
            final connections = connSnap.data ?? const <BoardConnection>[];
            final displayItems = items.map(_withDrag).toList();
            return InteractiveViewer(
              constrained: false,
              minScale: 0.2,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(200),
              child: SizedBox(
                width: boardSize,
                height: boardSize,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFEDE3D0)),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: StringPainter(
                          items: displayItems,
                          connections: connections,
                        ),
                      ),
                    ),
                    for (final item in displayItems)
                      BoardItemWidget(
                        key: ValueKey(item.id),
                        item: item,
                        connectMode: _connectMode,
                        isPendingFrom: _pendingFromId == item.id,
                        onTap: () => _onItemTap(item, connections),
                        onLongPress: () => _onItemLongPress(item),
                        onDragUpdate: (delta) {
                          final current =
                              _dragPositions[item.id] ?? Offset(item.x, item.y);
                          setState(() =>
                              _dragPositions[item.id] = current + delta);
                        },
                        onDragEnd: () {
                          final pos = _dragPositions[item.id];
                          if (pos != null) {
                            _boardService.updatePosition(
                                widget.caseModel.id, item.id, pos.dx, pos.dy);
                          }
                          setState(() => _dragPositions.remove(item.id));
                        },
                        onTextChanged: (text) => _onTextChanged(item, text),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    final board = Stack(
      children: [
        _buildBoard(),
        Positioned(
          top: 8,
          left: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text('Kode undangan: ${widget.caseModel.inviteCode}'),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.caseModel.name),
        actions: [
          IconButton(
            icon: Icon(_connectMode ? Icons.link_off : Icons.link),
            tooltip: 'Mode Hubungkan',
            isSelected: _connectMode,
            onPressed: () => setState(() {
              _connectMode = !_connectMode;
              _pendingFromId = null;
            }),
          ),
          if (!wide)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Chat',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Expanded(flex: 3, child: board),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 320,
                  child: ChatPanel(caseId: widget.caseModel.id),
                ),
              ],
            )
          : board,
      endDrawer: wide
          ? null
          : Drawer(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SafeArea(child: ChatPanel(caseId: widget.caseModel.id)),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'photo',
            onPressed: _addPhoto,
            tooltip: 'Tambah Foto',
            child: const Icon(Icons.add_a_photo),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'note',
            onPressed: _addNote,
            tooltip: 'Tambah Catatan',
            child: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }
}
