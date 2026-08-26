import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import 'case_board_screen.dart';

class CasesListScreen extends StatefulWidget {
  const CasesListScreen({super.key});

  @override
  State<CasesListScreen> createState() => _CasesListScreenState();
}

class _CasesListScreenState extends State<CasesListScreen> {
  final _caseService = CaseService();
  final _authService = AuthService();
  final _joinController = TextEditingController();
  bool _joining = false;

  Future<void> _createCase() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kasus Baru'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nama kasus'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Buat')),
        ],
      ),
    );
    if (name == null) return;
    final created = await _caseService.createCase(name);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CaseBoardScreen(caseModel: created)),
    );
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    final error = await _caseService.joinByInviteCode(_joinController.text);
    if (!mounted) return;
    setState(() => _joining = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      _joinController.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Berhasil gabung kasus.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Kasus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _authService.signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Gabung dengan kode undangan',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _joining ? null : _join,
                  child: const Text('Gabung'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CaseModel>>(
              stream: _caseService.myCases(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cases = snapshot.data!;
                if (cases.isEmpty) {
                  return const Center(
                      child: Text('Belum ada kasus. Buat satu, yuk.'));
                }
                return ListView.builder(
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    final c = cases[index];
                    return ListTile(
                      leading: const Icon(Icons.folder_special),
                      title: Text(c.name),
                      subtitle: Text('Kode: ${c.inviteCode}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CaseBoardScreen(caseModel: c)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCase,
        icon: const Icon(Icons.add),
        label: const Text('Kasus Baru'),
      ),
    );
  }
}
