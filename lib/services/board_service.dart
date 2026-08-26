import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/board_item.dart';
import '../models/connection.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _items(String caseId) =>
      _db.collection('cases').doc(caseId).collection('boardItems');

  CollectionReference<Map<String, dynamic>> _connections(String caseId) =>
      _db.collection('cases').doc(caseId).collection('connections');

  Stream<List<BoardItem>> items(String caseId) {
    return _items(caseId)
        .snapshots()
        .map((snap) => snap.docs.map(BoardItem.fromDoc).toList());
  }

  Stream<List<BoardConnection>> connections(String caseId) {
    return _connections(caseId)
        .snapshots()
        .map((snap) => snap.docs.map(BoardConnection.fromDoc).toList());
  }

  Future<void> addNote(String caseId,
      {required double x, required double y, required int color}) {
    return _items(caseId).add({
      'type': 'note',
      'x': x,
      'y': y,
      'width': 180.0,
      'height': 180.0,
      'rotation': 0.0,
      'text': '',
      'imageBase64': null,
      'color': color,
      'zIndex': 0,
      'createdBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPhoto(String caseId,
      {required double x,
      required double y,
      required String base64,
      required double width,
      required double height}) {
    return _items(caseId).add({
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
      'createdBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePosition(String caseId, String itemId, double x, double y) {
    return _items(caseId).doc(itemId).update({
      'x': x,
      'y': y,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateText(String caseId, String itemId, String text) {
    return _items(caseId).doc(itemId).update({
      'text': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateColor(String caseId, String itemId, int color) {
    return _items(caseId).doc(itemId).update({'color': color});
  }

  Future<void> deleteItem(String caseId, String itemId) async {
    await _items(caseId).doc(itemId).delete();
    final linked = await _connections(caseId)
        .where('fromItemId', isEqualTo: itemId)
        .get();
    final linked2 = await _connections(caseId)
        .where('toItemId', isEqualTo: itemId)
        .get();
    final batch = _db.batch();
    for (final d in [...linked.docs, ...linked2.docs]) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Future<void> addConnection(String caseId, String fromId, String toId) {
    return _connections(caseId).add({
      'fromItemId': fromId,
      'toItemId': toId,
      'color': 0xFFE53935,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteConnection(String caseId, String connId) {
    return _connections(caseId).doc(connId).delete();
  }
}
