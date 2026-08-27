import 'package:firebase_auth/firebase_auth.dart';

import '../rest/rest_session.dart';
import '../utils/platform_support.dart';

/// The signed-in user's uid/display name, whichever backend (native SDK or
/// REST fallback) is currently active. Every service that stamps
/// `createdBy`/`senderUid` fields goes through this instead of touching
/// FirebaseAuth or RestSession directly.
class CurrentUser {
  static String get uid => isLinuxDesktop
      ? RestSession.instance.uid!
      : FirebaseAuth.instance.currentUser!.uid;

  static String get displayName => isLinuxDesktop
      ? (RestSession.instance.email ?? 'Detektif')
      : (FirebaseAuth.instance.currentUser?.email ?? 'Detektif');
}
