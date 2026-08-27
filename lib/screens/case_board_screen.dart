import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/board_item.dart';
import '../models/case_model.dart';
import '../models/connection.dart';
import '../services/board_service.dart';
import '../services/presence_service.dart';
import '../utils/image_utils.dart';
import '../widgets/board_action_bar.dart';
import '../widgets/board_item_widget.dart';
import '../widgets/chat_panel.dart';
import '../widgets/corkboard_background.dart';
import '../widgets/string_painter.dart';

// A real corkboard/bulletin board is a landscape rectangle, not a square.
const double boardWidth = 6000;
const double boardHeight = 3400;

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
  final Map<String, Size> _resizeSizes = {};
  final Map<String, double> _fontSizeOverrides = {};
  final Map<String, int> _colorOverrides = {};
  final Map<String, Timer> _textDebounce = {};
  Timer? _fontSizeDebounce;
  // The selected note's live font size / color, tracked locally so the
  // A+/A- and Warna buttons (which live outside the item's own stream
  // data) know what to start from.
  double _selectedFontSize = 20;
  Color _selectedColor = const Color(0xFFFFF59D);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // Locking disables selection entirely, so tapping around the board
  // (e.g. while just browsing) can't select or change anything — but
  // panning/zooming still works.
  bool _locked = false;
  // Preview goes further: fits the whole board on screen and freezes it
  // completely — no selecting, no panning, no zooming. Toggled from the
  // "Lihat semua papan" button.
  bool _previewMode = false;
  bool get _interactionLocked => _locked || _previewMode;
  String? _selectedItemId;
  BoardItemType? _selectedItemType;
  ItemAction _activeAction = ItemAction.none;
  String? _pendingFromId;

  final _transformController = TransformationController();
  final _viewerKey = GlobalKey();

  // Created once and reused for the screen's whole lifetime — NOT inside
  // build()/_buildBoard(). Each of these opens a real REST poll/connection
  // on the Linux fallback; recreating them on every setState (e.g. every
  // drag frame) piled up connections fast enough to exhaust file
  // descriptors and crash the app.
  late final Stream<List<BoardItem>> _itemsStream;
  late final Stream<List<BoardConnection>> _connectionsStream;

  @override
  void initState() {
    super.initState();
    _itemsStream = _boardService.items(widget.caseModel.id);
    _connectionsStream = _boardService.connections(widget.caseModel.id);
    _presenceService.goOnline(widget.caseModel.id).catchError((_) {
      // Presence is a nice-to-have; a permission/network hiccup here
      // shouldn't surface as an unhandled exception.
    });
  }

  @override
  void dispose() {
    _presenceService.goOffline();
    for (final t in _textDebounce.values) {
      t.cancel();
    }
    _fontSizeDebounce?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  static const double _minItemSize = 60;
  static const double _maxItemSize = 900;
  static const double _minFontSize = 12;
  static const double _maxFontSize = 96;
  // Low enough that "Lihat semua papan" can always zoom the full
  // boardWidth x boardHeight canvas down to fit even a narrow phone
  // viewport (~350-400px wide) — 0.2 was too high a floor and left the
  // board cropped on the sides.
  static const double _minZoom = 0.05;
  static const double _maxZoom = 2.5;

  /// Zooms/pans the board so the whole rectangular canvas fits in the
  /// current viewport at once — an overview, since panning around at 1:1
  /// to find where everything is gets old fast.
  void _fitBoardToScreen() {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final viewport = box.size;
    final scale = min(
      viewport.width / boardWidth,
      viewport.height / boardHeight,
    ).clamp(_minZoom, _maxZoom);
    final dx = (viewport.width - boardWidth * scale) / 2;
    final dy = (viewport.height - boardHeight * scale) / 2;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  // Where the view was before entering preview, so leaving it goes back
  // to that instead of staying zoomed out to the whole board.
  Matrix4? _prePreviewTransform;

  /// "Lihat semua papan": fits the whole board on screen and freezes it
  /// completely (no select/edit, no pan/zoom) until pressed again — which
  /// restores the view exactly where it was before.
  void _togglePreview() {
    setState(() {
      _previewMode = !_previewMode;
      if (_previewMode) {
        _prePreviewTransform = _transformController.value.clone();
        _selectedItemId = null;
        _selectedItemType = null;
        _activeAction = ItemAction.none;
        _pendingFromId = null;
      }
    });
    if (_previewMode) {
      _fitBoardToScreen();
    } else if (_prePreviewTransform != null) {
      _transformController.value = _prePreviewTransform!;
      _prePreviewTransform = null;
    }
  }

  /// Called after sending a position/size update: keeps the optimistic
  /// local value in place for a bit longer than the write's round-trip
  /// before letting the (by-then fresh) server data take back over.
  /// Without this, clearing the local override right away shows the item
  /// snap back to its stale server position for the gap until the write
  /// confirms and echoes back, then jump forward again — the REST
  /// fallback has no local-write-echo like the native SDK does, which is
  /// what hid this on Android/web.
  void _releaseLiveEditAfterPoll(
    bool Function() stillCurrent,
    VoidCallback release,
  ) {
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted && stillCurrent()) release();
    });
  }

  BoardItem _withLiveEdits(BoardItem item) {
    final pos = _dragPositions[item.id];
    final size = _resizeSizes[item.id];
    final fontSize = _fontSizeOverrides[item.id];
    final color = _colorOverrides[item.id];
    if (pos == null && size == null && fontSize == null && color == null) {
      return item;
    }
    return BoardItem(
      id: item.id,
      type: item.type,
      x: pos?.dx ?? item.x,
      y: pos?.dy ?? item.y,
      width: size?.width ?? item.width,
      height: size?.height ?? item.height,
      rotation: item.rotation,
      text: item.text,
      fontSize: fontSize ?? item.fontSize,
      imageBase64: item.imageBase64,
      color: color ?? item.color,
      zIndex: item.zIndex,
      createdBy: item.createdBy,
    );
  }

  /// Full HSV/hex color picker — any color, not just a fixed preset list.
  Future<Color?> _pickColor(Color initial) {
    var picked = initial;
    return showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Warna'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initial,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, picked),
            child: const Text('Pilih'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNote() async {
    final color = await _pickColor(const Color(0xFFFFF59D));
    if (color == null) return;
    _boardService.addNote(
      widget.caseModel.id,
      x: boardWidth / 2 - 90,
      y: boardHeight / 2 - 90,
      color: color.toARGB32(),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto kegedean buat disimpan. Coba foto lain atau kompres dulu.',
          ),
        ),
      );
      return;
    }
    _boardService.addPhoto(
      widget.caseModel.id,
      x: boardWidth / 2 - 100,
      y: boardHeight / 2 - 100,
      base64: encoded.base64,
      width: 200,
      height: 200,
    );
  }

  void _onItemTap(BoardItem item, List<BoardConnection> connections) {
    if (_interactionLocked) return;
    if (_pendingFromId != null) {
      // Currently in "pick a target to link to" mode (started from the
      // bottom bar's Hubung button) — this tap completes or cancels it,
      // regardless of selection state.
      if (_pendingFromId == item.id) {
        setState(() => _pendingFromId = null);
        return;
      }
      final existing = connections.where(
        (c) =>
            (c.fromItemId == _pendingFromId && c.toItemId == item.id) ||
            (c.toItemId == _pendingFromId && c.fromItemId == item.id),
      );
      if (existing.isNotEmpty) {
        _boardService.deleteConnection(widget.caseModel.id, existing.first.id);
      } else {
        _boardService.addConnection(
          widget.caseModel.id,
          _pendingFromId!,
          item.id,
        );
      }
      setState(() => _pendingFromId = null);
      return;
    }
    // Plain tap: toggle this item's selection — shows/hides the fixed
    // bottom BoardActionBar. Tapping empty board space deselects too (see
    // the background GestureDetector below).
    setState(() {
      if (_selectedItemId == item.id) {
        _selectedItemId = null;
        _selectedItemType = null;
      } else {
        _selectedItemId = item.id;
        _selectedItemType = item.type;
        _selectedFontSize = _fontSizeOverrides[item.id] ?? item.fontSize;
        _selectedColor = Color(_colorOverrides[item.id] ?? item.color);
      }
      _activeAction = ItemAction.none;
    });
  }

  void _changeSelectedFontSize(double delta) {
    final id = _selectedItemId;
    if (id == null) return;
    final next = (_selectedFontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() {
      _selectedFontSize = next;
      _fontSizeOverrides[id] = next;
    });
    _fontSizeDebounce?.cancel();
    _fontSizeDebounce = Timer(const Duration(milliseconds: 400), () {
      _boardService.updateFontSize(widget.caseModel.id, id, next);
      _releaseLiveEditAfterPoll(
        () => _fontSizeOverrides[id] == next,
        () => setState(() => _fontSizeOverrides.remove(id)),
      );
    });
  }

  Future<void> _changeSelectedColor() async {
    final id = _selectedItemId;
    if (id == null) return;
    final picked = await _pickColor(_selectedColor);
    if (picked == null) return;
    final argb = picked.toARGB32();
    setState(() {
      _selectedColor = picked;
      _colorOverrides[id] = argb;
    });
    await _boardService.updateColor(widget.caseModel.id, id, argb);
    _releaseLiveEditAfterPoll(
      () => _colorOverrides[id] == argb,
      () => setState(() => _colorOverrides.remove(id)),
    );
  }

  void _startConnectingSelected() {
    final id = _selectedItemId;
    if (id == null) return;
    setState(() {
      _pendingFromId = id;
      _selectedItemId = null;
      _selectedItemType = null;
      _activeAction = ItemAction.none;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tap item lain buat menyambungkan, atau tap area kosong buat batal.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _deselectAll() {
    if (_selectedItemId == null && _pendingFromId == null) return;
    setState(() {
      _selectedItemId = null;
      _selectedItemType = null;
      _activeAction = ItemAction.none;
      _pendingFromId = null;
    });
  }

  Future<void> _deleteSelected() async {
    final id = _selectedItemId;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus item ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _boardService.deleteItem(widget.caseModel.id, id);
      if (mounted) {
        setState(() {
          _selectedItemId = null;
          _selectedItemType = null;
        });
      }
    }
  }

  Future<void> _replaceSelectedPhoto() async {
    final id = _selectedItemId;
    if (id == null) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto kegedean buat disimpan. Coba foto lain atau kompres dulu.',
          ),
        ),
      );
      return;
    }
    await _boardService.updatePhoto(widget.caseModel.id, id, encoded.base64);
    if (mounted) {
      setState(() {
        _selectedItemId = null;
        _selectedItemType = null;
      });
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
      stream: _itemsStream,
      builder: (context, itemsSnap) {
        final items = itemsSnap.data ?? const <BoardItem>[];
        return StreamBuilder<List<BoardConnection>>(
          stream: _connectionsStream,
          builder: (context, connSnap) {
            final connections = connSnap.data ?? const <BoardConnection>[];
            final displayItems = items.map(_withLiveEdits).toList();
            return InteractiveViewer(
              key: _viewerKey,
              transformationController: _transformController,
              constrained: false,
              panEnabled: !_previewMode,
              scaleEnabled: !_previewMode,
              minScale: _minZoom,
              maxScale: _maxZoom,
              // No extra pannable margin around the board — otherwise you
              // can drag/zoom past its edges into blank space with no
              // corkboard texture under it.
              boundaryMargin: EdgeInsets.zero,
              child: SizedBox(
                width: boardWidth,
                height: boardHeight,
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _deselectAll,
                      child: CorkboardBackground(
                        width: boardWidth,
                        height: boardHeight,
                      ),
                    ),
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
                        isSelected: _selectedItemId == item.id,
                        isPendingFrom: _pendingFromId == item.id,
                        locked: _interactionLocked,
                        activeAction: _selectedItemId == item.id
                            ? _activeAction
                            : ItemAction.none,
                        onTap: () => _onItemTap(item, connections),
                        onDragUpdate: (delta) {
                          final current =
                              _dragPositions[item.id] ?? Offset(item.x, item.y);
                          setState(
                            () => _dragPositions[item.id] = current + delta,
                          );
                        },
                        onDragEnd: () {
                          final pos = _dragPositions[item.id];
                          if (pos == null) return;
                          _boardService.updatePosition(
                            widget.caseModel.id,
                            item.id,
                            pos.dx,
                            pos.dy,
                          );
                          setState(() => _activeAction = ItemAction.none);
                          _releaseLiveEditAfterPoll(
                            () => _dragPositions[item.id] == pos,
                            () =>
                                setState(() => _dragPositions.remove(item.id)),
                          );
                        },
                        onResizeUpdate: (delta) {
                          final current =
                              _resizeSizes[item.id] ??
                              Size(item.width, item.height);
                          // Width and height follow the drag independently
                          // — pull sideways for a wide note, down for a
                          // tall one, diagonally for both.
                          final next = Size(
                            (current.width + delta.dx).clamp(
                              _minItemSize,
                              _maxItemSize,
                            ),
                            (current.height + delta.dy).clamp(
                              _minItemSize,
                              _maxItemSize,
                            ),
                          );
                          setState(() => _resizeSizes[item.id] = next);
                        },
                        onResizeEnd: () {
                          final size = _resizeSizes[item.id];
                          if (size == null) return;
                          _boardService.updateSize(
                            widget.caseModel.id,
                            item.id,
                            size.width,
                            size.height,
                          );
                          setState(() => _activeAction = ItemAction.none);
                          _releaseLiveEditAfterPoll(
                            () => _resizeSizes[item.id] == size,
                            () => setState(() => _resizeSizes.remove(item.id)),
                          );
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
    final selectedType = _selectedItemType;
    // Backdrop behind the InteractiveViewer's viewport, in case it's ever
    // bigger than the (zoomed-out) board — no stray white showing at the
    // edges even then.
    final board = ColoredBox(
      color: const Color(0xFF3E2A18),
      child: Stack(
        children: [
          _buildBoard(),
          Positioned(
            top: 8,
            left: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text('Kode undangan: ${widget.caseModel.inviteCode}'),
              ),
            ),
          ),
          // Fixed to the screen, not the zoomable board — stays a
          // constant, comfortable size and position no matter how far
          // the board is zoomed out.
          if (selectedType != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: BoardActionBar(
                  itemType: selectedType,
                  activeAction: _activeAction,
                  onActionSelected: (action) =>
                      setState(() => _activeAction = action),
                  onConnect: _startConnectingSelected,
                  onReplacePhoto: selectedType == BoardItemType.photo
                      ? _replaceSelectedPhoto
                      : null,
                  onFontSizeDelta: selectedType == BoardItemType.note
                      ? _changeSelectedFontSize
                      : null,
                  onChangeColor: selectedType == BoardItemType.note
                      ? _changeSelectedColor
                      : null,
                  onDelete: _deleteSelected,
                  onClose: _deselectAll,
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.caseModel.name),
        actions: [
          IconButton(
            icon: Icon(_previewMode ? Icons.fullscreen_exit : Icons.fit_screen),
            tooltip: _previewMode ? 'Keluar preview' : 'Lihat semua papan',
            isSelected: _previewMode,
            onPressed: _togglePreview,
          ),
          IconButton(
            icon: Icon(_locked ? Icons.lock : Icons.lock_open),
            tooltip: _locked ? 'Buka kunci' : 'Kunci papan',
            isSelected: _locked,
            onPressed: () => setState(() {
              _locked = !_locked;
              _selectedItemId = null;
              _selectedItemType = null;
              _activeAction = ItemAction.none;
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
      // Hidden while an item is selected (they'd sit on top of the bottom
      // BoardActionBar's rightmost buttons) or while locked/previewing —
      // both are view-only modes, so adding new items shouldn't be
      // possible until they're turned off.
      floatingActionButton: selectedType != null || _interactionLocked
          ? null
          : Column(
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
