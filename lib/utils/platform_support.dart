import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// firebase_core (and every plugin built on top of it — firebase_auth,
/// firebase_database) has no native implementation on Linux desktop at
/// all, so on that platform the app talks to Firebase's plain REST APIs
/// instead (see lib/rest/).
bool get isLinuxDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
