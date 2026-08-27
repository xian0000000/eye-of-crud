import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';

/// Holds the signed-in session for the REST fallback path (Linux desktop).
/// In-memory only — same as the pattern in 9drive-xinac / widget_baterai,
/// this is a dev/desktop fallback, not something that needs to survive a
/// restart (the login screen already only takes the 2 hardcoded accounts).
class RestSession {
  RestSession._();
  static final instance = RestSession._();

  String? uid;
  String? email;
  String? idToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  final changes = StreamController<void>.broadcast();

  bool get isSignedIn => idToken != null;

  void set({
    required String uid,
    required String email,
    required String idToken,
    required String refreshToken,
    required int expiresInSeconds,
  }) {
    this.uid = uid;
    this.email = email;
    this.idToken = idToken;
    _refreshToken = refreshToken;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
    changes.add(null);
  }

  void clear() {
    uid = null;
    email = null;
    idToken = null;
    _refreshToken = null;
    _expiresAt = null;
    changes.add(null);
  }

  /// Refreshes the ID token if it's expired or close to it. Every Rest*
  /// client calls this before making a request.
  Future<String> ensureFreshIdToken() async {
    if (idToken == null) {
      throw StateError('Belum login.');
    }
    final expiresSoon =
        _expiresAt == null ||
        DateTime.now().isAfter(
          _expiresAt!.subtract(const Duration(minutes: 2)),
        );
    if (!expiresSoon) return idToken!;

    final response = await http.post(
      Uri.parse(
        'https://securetoken.googleapis.com/v1/token?key=${DefaultFirebaseOptions.web.apiKey}',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken},
    );
    if (response.statusCode != 200) {
      clear();
      throw StateError('Sesi habis, login ulang.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    idToken = data['id_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _expiresAt = DateTime.now().add(
      Duration(seconds: int.parse(data['expires_in'] as String)),
    );
    return idToken!;
  }
}
