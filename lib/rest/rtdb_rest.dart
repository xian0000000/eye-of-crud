import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import 'rest_session.dart';

/// Realtime Database's plain REST + SSE API — same database the native
/// `firebase_database` plugin talks to, just plain HTTP. Used on platforms
/// with no firebase_database implementation (Linux desktop).
class RtdbRest {
  static String get _databaseUrl => DefaultFirebaseOptions.web.databaseURL!;

  /// Placeholder value recognized by the RTDB REST API to mean "fill this
  /// with the server's write timestamp" — the REST equivalent of the native
  /// SDK's `ServerValue.timestamp`.
  static const serverTimestamp = {'.sv': 'timestamp'};

  /// One-shot read — for a lookup that doesn't need to stay live (e.g.
  /// scanning for an invite code, or finding connections to clean up on
  /// item delete). Returns the decoded JSON value, or null if the path is
  /// empty.
  static Future<dynamic> get(String path) async {
    final token = await RestSession.instance.ensureFreshIdToken();
    final response = await http.get(
      Uri.parse('$_databaseUrl/$path.json?auth=$token'),
    );
    _checkOk(response);
    if (response.body == 'null') return null;
    return jsonDecode(response.body);
  }

  static Future<void> put(String path, dynamic value) async {
    final token = await RestSession.instance.ensureFreshIdToken();
    final response = await http.put(
      Uri.parse('$_databaseUrl/$path.json?auth=$token'),
      body: jsonEncode(value),
    );
    _checkOk(response);
  }

  /// Partial update at [path] — merges [value]'s keys in without touching
  /// siblings. Also doubles as a multi-location atomic update when [path]
  /// is `''` and [value]'s keys are full paths themselves (RTDB's REST API
  /// treats a PATCH at the root with slash-delimited keys as one atomic
  /// multi-path write) — used to delete an item and its connections
  /// together.
  static Future<void> patch(String path, Map<String, dynamic> value) async {
    final token = await RestSession.instance.ensureFreshIdToken();
    final response = await http.patch(
      Uri.parse('$_databaseUrl/$path.json?auth=$token'),
      body: jsonEncode(value),
    );
    _checkOk(response);
  }

  static Future<void> delete(String path) async {
    final token = await RestSession.instance.ensureFreshIdToken();
    final response = await http.delete(
      Uri.parse('$_databaseUrl/$path.json?auth=$token'),
    );
    _checkOk(response);
  }

  /// Equivalent of the native SDK's `ref.push().set(value)`: lets the
  /// server mint a chronologically-ordered key and write [value] under it.
  static Future<void> push(String path, dynamic value) async {
    final token = await RestSession.instance.ensureFreshIdToken();
    final response = await http.post(
      Uri.parse('$_databaseUrl/$path.json?auth=$token'),
      body: jsonEncode(value),
    );
    _checkOk(response);
  }

  /// Same as [push], but returns the server-generated key — for callers
  /// (creating a case/board item/connection) that need to know the new
  /// id right away instead of waiting for the next poll/stream update.
  static Future<String> pushAndReturnKey(String path, dynamic value) async {
    final token = await RestSession.instance.ensureFreshIdToken();
    final response = await http.post(
      Uri.parse('$_databaseUrl/$path.json?auth=$token'),
      body: jsonEncode(value),
    );
    _checkOk(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['name'] as String;
  }

  /// Streams the live value at [path], merging incremental `patch` events
  /// into the last known snapshot the way the native SDK's listener would.
  ///
  /// The RTDB REST SSE connection isn't kept alive forever by the server
  /// (idle timeouts, network blips), so this reconnects automatically
  /// whenever the stream ends — otherwise chat/presence would silently
  /// freeze until the app restarts.
  static Stream<dynamic> watch(String path) {
    return Stream.multi((controller) async {
      var cancelled = false;
      var hasEmittedData = false;
      http.Client? activeClient;
      controller.onCancel = () {
        cancelled = true;
        activeClient?.close();
      };

      dynamic root;
      while (!cancelled) {
        final client = http.Client();
        activeClient = client;
        try {
          final token = await RestSession.instance.ensureFreshIdToken();
          final request = http.Request(
            'GET',
            Uri.parse('$_databaseUrl/$path.json?auth=$token'),
          );
          request.headers['Accept'] = 'text/event-stream';
          final response = await client.send(request);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            final body = await response.stream.bytesToString();
            throw StateError(
              'Realtime Database REST gagal (${response.statusCode}): $body',
            );
          }
          var buffer = '';
          await for (final chunk in response.stream.transform(utf8.decoder)) {
            buffer += chunk;
            while (buffer.contains('\n\n')) {
              final splitIndex = buffer.indexOf('\n\n');
              final rawEvent = buffer.substring(0, splitIndex);
              buffer = buffer.substring(splitIndex + 2);

              String? eventType;
              String? dataLine;
              for (final line in rawEvent.split('\n')) {
                if (line.startsWith('event:')) {
                  eventType = line.substring(6).trim();
                }
                if (line.startsWith('data:')) {
                  dataLine = line.substring(5).trim();
                }
              }
              if (eventType != 'put' && eventType != 'patch') continue;
              if (dataLine == null) continue;
              try {
                final decoded = jsonDecode(dataLine) as Map<String, dynamic>;
                root = _applyEvent(
                  root,
                  eventType!,
                  decoded['path'] as String,
                  decoded['data'],
                );
                hasEmittedData = true;
                controller.add(root);
              } catch (_) {
                // Keep-alive/malformed chunk — ignore and keep listening.
              }
            }
          }
        } catch (e) {
          if (!hasEmittedData) {
            // Never got any good data — a permission/config error here
            // needs to actually reach the UI, or the caller spins on a
            // loading indicator forever with no way to tell something's
            // wrong (this connection would otherwise just retry forever).
            controller.addError(e);
          }
          // Once we've had good data, swallow a dropped connection or
          // transient failure and just reconnect below, instead of
          // wiping the caller's last-known chat/presence/board state.
        } finally {
          client.close();
        }
        if (cancelled) break;
        await Future.delayed(const Duration(seconds: 2));
      }
    });
  }

  /// `put` fully replaces whatever is at [path] with [data]. `patch` is
  /// different: per Firebase's REST streaming docs, its `data` is itself a
  /// map of children to merge into whatever is already at [path] — every
  /// other key already there is left alone. Treating both the same way
  /// (as a full replace) is what made a plain field update — e.g. resizing
  /// a photo, which PATCHes only width/height — wipe out the rest of that
  /// item's fields (imageBase64, type, ...) on every collaborator's screen
  /// the moment the echo arrived, making the photo vanish or turn into a
  /// blank note.
  static dynamic _applyEvent(
    dynamic root,
    String eventType,
    String path,
    dynamic data,
  ) {
    final segments = path == '/'
        ? const <String>[]
        : path.substring(1).split('/');
    if (eventType == 'put') {
      return _setAtPath(root, segments, data);
    }
    final current = _getAtPath(root, segments);
    final merged = _shallowMerge(current, data as Map);
    return _setAtPath(root, segments, merged);
  }

  static dynamic _getAtPath(dynamic node, List<String> segments) {
    if (segments.isEmpty) return node;
    if (node is! Map) return null;
    return _getAtPath(node[segments.first], segments.sublist(1));
  }

  static dynamic _setAtPath(
    dynamic node,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) return value;
    final map = Map<String, dynamic>.from(node is Map ? node : const {});
    final key = segments.first;
    final childValue = _setAtPath(map[key], segments.sublist(1), value);
    if (childValue == null) {
      map.remove(key);
    } else {
      map[key] = childValue;
    }
    return map;
  }

  static Map<String, dynamic> _shallowMerge(dynamic current, Map data) {
    final merged = Map<String, dynamic>.from(
      current is Map ? current : const {},
    );
    data.forEach((k, v) {
      final key = k.toString();
      if (v == null) {
        merged.remove(key);
      } else {
        merged[key] = v;
      }
    });
    return merged;
  }

  static void _checkOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Realtime Database REST gagal (${response.statusCode}): ${response.body}',
      );
    }
  }
}
