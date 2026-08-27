import 'package:firebase_database/firebase_database.dart';

import '../models/board_item.dart';
import '../models/connection.dart';
import '../rest/rtdb_rest.dart';
import '../utils/platform_support.dart';
import 'current_user.dart';

class BoardService {
  // Getter, not an eagerly-initialized field — see AuthService's _auth.
  FirebaseDatabase get _db => FirebaseDatabase.instance;

  DatabaseReference _itemsRef(String caseId) => _db.ref('boardItems/$caseId');

  DatabaseReference _connectionsRef(String caseId) =>
      _db.ref('connections/$caseId');

  Stream<List<BoardItem>> items(String caseId) {
    if (isLinuxDesktop) {
      return RtdbRest.watch('boardItems/$caseId').map(_toItems);
    }
    return _itemsRef(
      caseId,
    ).onValue.map((event) => _toItems(event.snapshot.value));
  }

  List<BoardItem> _toItems(dynamic data) {
    if (data == null || data is! Map) return const [];
    return data.entries
        .map(
          (e) => BoardItem.fromMap(
            e.key.toString(),
            Map<dynamic, dynamic>.from(e.value as Map),
          ),
        )
        .toList();
  }

  Stream<List<BoardConnection>> connections(String caseId) {
    if (isLinuxDesktop) {
      return RtdbRest.watch('connections/$caseId').map(_toConnections);
    }
    return _connectionsRef(
      caseId,
    ).onValue.map((event) => _toConnections(event.snapshot.value));
  }

  List<BoardConnection> _toConnections(dynamic data) {
    if (data == null || data is! Map) return const [];
    return data.entries
        .map(
          (e) => BoardConnection.fromMap(
            e.key.toString(),
            Map<dynamic, dynamic>.from(e.value as Map),
          ),
        )
        .toList();
  }

  Future<void> addNote(
    String caseId, {
    required double x,
    required double y,
    required int color,
  }) {
    final fields = {
      'type': 'note',
      'x': x,
      'y': y,
      'width': 180.0,
      'height': 180.0,
      'rotation': 0.0,
      'text': '',
      'fontSize': 20.0,
      'imageBase64': null,
      'color': color,
      'zIndex': 0,
      'createdBy': CurrentUser.uid,
    };
    if (isLinuxDesktop) {
      return RtdbRest.push('boardItems/$caseId', {
        ...fields,
        'updatedAt': RtdbRest.serverTimestamp,
      });
    }
    return _itemsRef(
      caseId,
    ).push().set({...fields, 'updatedAt': ServerValue.timestamp});
  }

  Future<void> addPhoto(
    String caseId, {
    required double x,
    required double y,
    required String base64,
    required double width,
    required double height,
  }) {
    final fields = {
      'type': 'photo',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': 0.0,
      'text': '',
      'imageBase64': base64,
      'color': 0xFFFFFFFF,
      'zIndex': 0,
      'createdBy': CurrentUser.uid,
    };
    if (isLinuxDesktop) {
      return RtdbRest.push('boardItems/$caseId', {
        ...fields,
        'updatedAt': RtdbRest.serverTimestamp,
      });
    }
    return _itemsRef(
      caseId,
    ).push().set({...fields, 'updatedAt': ServerValue.timestamp});
  }

  Future<void> updatePosition(
    String caseId,
    String itemId,
    double x,
    double y,
  ) {
    if (isLinuxDesktop) {
      return RtdbRest.patch('boardItems/$caseId/$itemId', {
        'x': x,
        'y': y,
        'updatedAt': RtdbRest.serverTimestamp,
      });
    }
    return _itemsRef(caseId).child(itemId).update({
      'x': x,
      'y': y,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> updateSize(
    String caseId,
    String itemId,
    double width,
    double height,
  ) {
    if (isLinuxDesktop) {
      return RtdbRest.patch('boardItems/$caseId/$itemId', {
        'width': width,
        'height': height,
        'updatedAt': RtdbRest.serverTimestamp,
      });
    }
    return _itemsRef(caseId).child(itemId).update({
      'width': width,
      'height': height,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> updateText(String caseId, String itemId, String text) {
    if (isLinuxDesktop) {
      return RtdbRest.patch('boardItems/$caseId/$itemId', {
        'text': text,
        'updatedAt': RtdbRest.serverTimestamp,
      });
    }
    return _itemsRef(
      caseId,
    ).child(itemId).update({'text': text, 'updatedAt': ServerValue.timestamp});
  }

  Future<void> updateColor(String caseId, String itemId, int color) {
    if (isLinuxDesktop) {
      return RtdbRest.patch('boardItems/$caseId/$itemId', {'color': color});
    }
    return _itemsRef(caseId).child(itemId).update({'color': color});
  }

  Future<void> updateFontSize(String caseId, String itemId, double fontSize) {
    if (isLinuxDesktop) {
      return RtdbRest.patch('boardItems/$caseId/$itemId', {
        'fontSize': fontSize,
      });
    }
    return _itemsRef(caseId).child(itemId).update({'fontSize': fontSize});
  }

  Future<void> updatePhoto(String caseId, String itemId, String base64) {
    if (isLinuxDesktop) {
      return RtdbRest.patch('boardItems/$caseId/$itemId', {
        'imageBase64': base64,
        'updatedAt': RtdbRest.serverTimestamp,
      });
    }
    return _itemsRef(caseId).child(itemId).update({
      'imageBase64': base64,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> deleteItem(String caseId, String itemId) async {
    if (isLinuxDesktop) {
      final conns = await RtdbRest.get('connections/$caseId');
      final updates = <String, dynamic>{'boardItems/$caseId/$itemId': null};
      if (conns is Map) {
        for (final e in conns.entries) {
          final m = e.value as Map;
          if (m['fromItemId'] == itemId || m['toItemId'] == itemId) {
            updates['connections/$caseId/${e.key}'] = null;
          }
        }
      }
      // A PATCH at the root with full paths as keys is RTDB's atomic
      // multi-location update — the item and any connections touching it
      // disappear together, not one write then the other.
      return RtdbRest.patch('', updates);
    }
    final snap = await _connectionsRef(caseId).get();
    final updates = <String, dynamic>{'boardItems/$caseId/$itemId': null};
    if (snap.value is Map) {
      for (final entry in (snap.value as Map).entries) {
        final m = entry.value as Map;
        if (m['fromItemId'] == itemId || m['toItemId'] == itemId) {
          updates['connections/$caseId/${entry.key}'] = null;
        }
      }
    }
    return _db.ref().update(updates);
  }

  Future<void> addConnection(String caseId, String fromId, String toId) {
    final fields = {
      'fromItemId': fromId,
      'toItemId': toId,
      'color': 0xFFE53935,
      'createdBy': CurrentUser.uid,
    };
    if (isLinuxDesktop) {
      return RtdbRest.push('connections/$caseId', {
        ...fields,
        'createdAt': RtdbRest.serverTimestamp,
      });
    }
    return _connectionsRef(
      caseId,
    ).push().set({...fields, 'createdAt': ServerValue.timestamp});
  }

  Future<void> deleteConnection(String caseId, String connId) {
    if (isLinuxDesktop) {
      return RtdbRest.delete('connections/$caseId/$connId');
    }
    return _connectionsRef(caseId).child(connId).remove();
  }
}
