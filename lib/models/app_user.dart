/// Platform-independent stand-in for firebase_auth's `User`, so UI code
/// doesn't need to know whether the signed-in session came from the native
/// SDK or the REST fallback (Linux desktop).
class AppUser {
  final String uid;
  final String? email;

  AppUser({required this.uid, required this.email});
}
