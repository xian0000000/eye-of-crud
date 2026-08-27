import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../rest/rest_session.dart';
import '../utils/platform_support.dart';

class AuthService {
  // A getter, not an eagerly-initialized field: on Linux desktop
  // Firebase.initializeApp() is never called (see main.dart), and touching
  // FirebaseAuth.instance before that throws — this must stay unevaluated
  // until a non-Linux code path actually needs it.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<AppUser?> get authStateChanges {
    if (isLinuxDesktop) {
      // A plain broadcast stream only reaches listeners subscribed *after*
      // an event fires — unlike `authStateChanges()`, which always replays
      // the current user first. Stream.multi makes this behave the same
      // way, so AuthGate's StreamBuilder doesn't spin forever waiting for a
      // first event that already happened before it subscribed.
      return Stream.multi((controller) {
        controller.add(currentUser);
        final sub = RestSession.instance.changes.stream.listen(
          (_) => controller.add(currentUser),
          onError: controller.addError,
        );
        controller.onCancel = sub.cancel;
      });
    }
    return _auth.authStateChanges().map(
      (u) => u == null ? null : AppUser(uid: u.uid, email: u.email),
    );
  }

  AppUser? get currentUser {
    if (isLinuxDesktop) {
      final session = RestSession.instance;
      if (!session.isSignedIn) return null;
      return AppUser(uid: session.uid!, email: session.email);
    }
    final u = _auth.currentUser;
    return u == null ? null : AppUser(uid: u.uid, email: u.email);
  }

  Future<String?> signIn(String email, String password) {
    return isLinuxDesktop
        ? _signInRest(email, password)
        : _signInNative(email, password);
  }

  Future<String?> _signInNative(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email atau password salah.';
        case 'invalid-email':
          return 'Format email tidak valid.';
        case 'user-disabled':
          return 'Akun ini dinonaktifkan.';
        default:
          return 'Gagal login: ${e.message}';
      }
    }
  }

  Future<String?> _signInRest(String email, String password) async {
    final trimmedEmail = email.trim();
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${DefaultFirebaseOptions.web.apiKey}',
    );
    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': trimmedEmail,
          'password': password,
          'returnSecureToken': true,
        }),
      );
    } catch (_) {
      return 'Gagal login: tidak ada koneksi internet.';
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final message = body['error']?['message'] as String? ?? '';
      if (message.startsWith('INVALID_LOGIN_CREDENTIALS') ||
          message.startsWith('EMAIL_NOT_FOUND') ||
          message.startsWith('INVALID_PASSWORD')) {
        return 'Email atau password salah.';
      }
      if (message.startsWith('INVALID_EMAIL')) {
        return 'Format email tidak valid.';
      }
      if (message.startsWith('USER_DISABLED')) return 'Akun ini dinonaktifkan.';
      if (message.startsWith('TOO_MANY_ATTEMPTS_TRY_LATER')) {
        return 'Terlalu banyak percobaan, coba lagi nanti.';
      }
      return 'Gagal login: $message';
    }
    RestSession.instance.set(
      uid: body['localId'] as String,
      email: trimmedEmail,
      idToken: body['idToken'] as String,
      refreshToken: body['refreshToken'] as String,
      expiresInSeconds: int.parse(body['expiresIn'] as String),
    );
    return null;
  }

  Future<void> signOut() {
    if (isLinuxDesktop) {
      RestSession.instance.clear();
      return Future.value();
    }
    return _auth.signOut();
  }
}
