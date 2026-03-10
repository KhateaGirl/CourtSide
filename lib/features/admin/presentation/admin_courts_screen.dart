import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';

class AdminCourtsScreen extends StatefulWidget {
  const AdminCourtsScreen({super.key});

  @override
  State<AdminCourtsScreen> createState() => _AdminCourtsScreenState();
}

class _AdminCourtsScreenState extends State<AdminCourtsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res =
        await Supabase.instance.client.from('courts').select().order('name');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _showEditDialog({Map<String, dynamic>? court}) async {
    final nameCtrl = TextEditingController(text: court?['name'] ?? '');
    final sportCtrl = TextEditingController(text: court?['sport_type'] ?? '');
    final descCtrl =
        TextEditingController(text: court?['description'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(court == null ? 'Create court' : 'Edit court'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: sportCtrl,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final client = Supabase.instance.client;
              if (court == null) {
                await client.from('courts').insert({
                  'name': nameCtrl.text.trim(),
                  'sport_type': sportCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
              } else {
                await client
                    .from('courts')
                    .update({
                      'name': nameCtrl.text.trim(),
                      'sport_type': sportCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                    })
                    .eq('id', court['id']);
              }
              if (context.mounted) Navigator.pop(context);
              setState(() => _future = _load());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCourt(String id) async {
    await Supabase.instance.client.from('courts').delete().eq('id', id);
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
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
              final c = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.blue100,
                    child: Text(
                      (c['sport_type'] as String? ?? '?').isNotEmpty
                          ? (c['sport_type'] as String)[0]
                          : '?',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.blue700,
                      ),
                    ),
                  ),
                  title: Text(c['name'], style: AppTypography.titleMedium),
                  subtitle: Text(
                    c['sport_type'],
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.orange700,
                    ),
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: AppColors.blue600,
                        onPressed: () => _showEditDialog(court: c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: AppColors.rejected,
                        onPressed: () => _deleteCourt(c['id']),
                      ),
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

