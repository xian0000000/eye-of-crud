import 'package:flutter/material.dart';

import '../models/board_item.dart';

/// Which interaction the selected item's card currently responds to.
/// `none` means a plain tap just selects it — nothing else happens until
/// one of these is picked from the bar. `move`/`resize` snap back to
/// `none` after one drag; `editText` stays active (so you can keep typing)
/// until the item is deselected or another action is picked.
enum ItemAction { none, move, resize, editText }

/// Fixed, screen-anchored toolbar shown at the bottom while an item is
/// selected. Deliberately NOT drawn inside the pannable/zoomable board —
/// controls drawn in board space shrink along with zoom-out and become
/// tiny/unreadable; this stays a constant, comfortable size on screen no
/// matter how far the board is zoomed.
class BoardActionBar extends StatelessWidget {
  final BoardItemType itemType;
  final ItemAction activeAction;
  final ValueChanged<ItemAction> onActionSelected;
  final VoidCallback onConnect;
  final VoidCallback? onReplacePhoto;
  final ValueChanged<double>? onFontSizeDelta;
  final VoidCallback? onChangeColor;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const BoardActionBar({
    super.key,
    required this.itemType,
    required this.activeAction,
    required this.onActionSelected,
    required this.onConnect,
    required this.onReplacePhoto,
    required this.onFontSizeDelta,
    required this.onChangeColor,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ).copyWith(bottom: 12),
        child: Material(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(18),
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            // Wraps to a second row instead of scrolling off-screen — a
            // horizontal scroll with no visible hint meant Hapus/Tutup
            // were just gone as far as anyone could tell.
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (itemType == BoardItemType.note)
                  _ActionButton(
                    icon: Icons.edit,
                    label: 'Teks',
                    active: activeAction == ItemAction.editText,
                    onTap: () => onActionSelected(
                      activeAction == ItemAction.editText
                          ? ItemAction.none
                          : ItemAction.editText,
                    ),
                  ),
                if (itemType == BoardItemType.note) ...[
                  _ActionButton(
                    icon: Icons.text_decrease,
                    label: 'A-',
                    onTap: () => onFontSizeDelta!(-2),
                  ),
                  _ActionButton(
                    icon: Icons.text_increase,
                    label: 'A+',
                    onTap: () => onFontSizeDelta!(2),
                  ),
                  _ActionButton(
                    icon: Icons.palette,
                    label: 'Warna',
                    onTap: onChangeColor!,
                  ),
                ],
                _ActionButton(
                  icon: Icons.open_with,
                  label: 'Geser',
                  active: activeAction == ItemAction.move,
                  onTap: () => onActionSelected(
                    activeAction == ItemAction.move
                        ? ItemAction.none
                        : ItemAction.move,
                  ),
                ),
                _ActionButton(
                  icon: Icons.open_in_full,
                  label: 'Ukuran',
                  active: activeAction == ItemAction.resize,
                  onTap: () => onActionSelected(
                    activeAction == ItemAction.resize
                        ? ItemAction.none
                        : ItemAction.resize,
                  ),
                ),
                _ActionButton(
                  icon: Icons.link,
                  label: 'Hubung',
                  onTap: onConnect,
                ),
                if (itemType == BoardItemType.photo)
                  _ActionButton(
                    icon: Icons.image,
                    label: 'Ganti',
                    onTap: onReplacePhoto!,
                  ),
                _ActionButton(
                  icon: Icons.delete,
                  label: 'Hapus',
                  color: Colors.redAccent,
                  onTap: onDelete,
                ),
                _ActionButton(
                  icon: Icons.close,
                  label: 'Tutup',
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
