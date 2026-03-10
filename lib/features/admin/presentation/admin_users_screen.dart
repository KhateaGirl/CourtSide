import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  RealtimeChannel? _channel;

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_channel == null) {
      _channel = Supabase.instance.client
          .channel('admin:users')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (_) => ref.invalidate(adminUsersListProvider),
          )
          .subscribe();
    }

    final usersAsync = ref.watch(adminUsersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: usersAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No users yet',
              subtitle: 'Registered users will appear here.',
            );
          }
          return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isNarrow(context) ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
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
                title: Text(
                  u['name'],
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${u['email']} (${u['role']})',
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
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
              final confirmed = await ConfirmDialog.show(
                ctx,
                title: 'Save user changes?',
                message: 'Name and contact will be updated.',
                confirmLabel: 'Yes, save',
                cancelLabel: 'Cancel',
                icon: Icons.person_outline_rounded,
              );
              if (!confirmed || !ctx.mounted) return;
              await Supabase.instance.client.from('users').update({
                'name': nameCtrl.text.trim(),
                'contact_number': contactCtrl.text.trim(),
              }).eq('id', user['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(adminUsersListProvider);
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
}
