import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'screens/cases_list_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'utils/platform_support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // firebase_core has no native implementation on Linux desktop at all, so
  // it's skipped there — services fall back to plain REST calls instead of
  // the native SDK on that platform (see lib/rest/).
  if (!isLinuxDesktop) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(
    DevicePreview(enabled: true, builder: (context) => const EyeOfCrudApp()),
  );
}

class EyeOfCrudApp extends StatelessWidget {
  const EyeOfCrudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye of Crud',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Created once — see the matching comment in case_board_screen.dart.
  late final Stream<AppUser?> _authStateChanges =
      AuthService().authStateChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const CasesListScreen();
      },
    );
  }
}
