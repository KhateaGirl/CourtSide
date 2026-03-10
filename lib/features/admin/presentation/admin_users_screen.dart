import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res =
        await Supabase.instance.client.from('users').select().order('name');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['name']?.toString() ?? '');
    final contactCtrl = TextEditingController(text: user['contact_number']?.toString() ?? '');
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact number'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.from('users').update({
                'name': nameCtrl.text.trim(),
                'contact_number': contactCtrl.text.trim(),
              }).eq('id', user['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _future = _load());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewHistory(Map<String, dynamic> user) async {
    final res = await Supabase.instance.client
        .from('reservations')
        .select()
        .eq('user_id', user['id']);
    final list = (res as List).cast<Map<String, dynamic>>();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('History for ${user['name']}'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              return ListTile(
                title: Text(
                  '${r['date']} ${r['start_time']} - ${r['end_time']}',
                ),
                subtitle: Text('Status: ${r['status']}'),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final u = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.orange100,
                    child: Text(
                      (u['name'] as String? ?? '?').isNotEmpty
                          ? (u['name'] as String)[0]
                          : '?',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.orange800,
                      ),
                    ),
                  ),
                  title: Text(u['name'], style: AppTypography.titleMedium),
                  subtitle: Text(
                    '${u['email']} (${u['role']})',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      TextButton(onPressed: () => _editUser(u), child: const Text('Edit')),
                      TextButton(onPressed: () => _viewHistory(u), child: const Text('History')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

