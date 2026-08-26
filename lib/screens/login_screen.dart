import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await _authService.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.travel_explore, size: 56),
                const SizedBox(height: 12),
                Text('Eye of Crud',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Text('Papan investigasi untuk detektif terpercaya',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Masuk'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Akun cuma dibuat manual oleh admin lewat Firebase Console. '
                  'Gak ada pendaftaran publik.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
