import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../courts/data/court_model.dart';
import '../../courts/domain/courts_providers.dart';

class AdminCourtsScreen extends ConsumerStatefulWidget {
  const AdminCourtsScreen({super.key});

  @override
  ConsumerState<AdminCourtsScreen> createState() => _AdminCourtsScreenState();
}

class _AdminCourtsScreenState extends ConsumerState<AdminCourtsScreen> {
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
      final repo = ref.read(courtsRepositoryProvider);
      _channel = repo.subscribeToCourtsChanges(() {
        ref.invalidate(courtsListProvider);
      });
    }

    final courtsAsync = ref.watch(courtsListProvider);

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
      body: courtsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.sports_basketball,
              title: 'No courts yet',
              subtitle: 'Tap + to add your first court.',
            );
          }
          return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isNarrow(context) ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final c = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.blue100,
                  child: Text(
                    c.sportType.isNotEmpty ? c.sportType[0] : '?',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.blue700,
                    ),
                  ),
                ),
                title: Text(
                  c.name,
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  c.sportType,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.orange700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: AppColors.blue600,
                      onPressed: () => _showEditDialog(court: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: AppColors.rejected,
                      onPressed: () => _confirmDeleteCourt(c),
                    ),
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

  Future<void> _showEditDialog({Court? court}) async {
    final nameCtrl = TextEditingController(text: court?.name ?? '');
    final sportCtrl = TextEditingController(text: court?.sportType ?? '');
    final descCtrl = TextEditingController(text: court?.description ?? '');

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
              final confirmed = await ConfirmDialog.show(
                context,
                title: court == null ? 'Add this court?' : 'Save changes?',
                message: court == null
                    ? 'This court will be available for reservations.'
                    : 'Court details will be updated.',
                confirmLabel: 'Yes, save',
                cancelLabel: 'Cancel',
                icon: court == null ? Icons.add_circle_outline : Icons.save_outlined,
              );
              if (!confirmed || !context.mounted) return;
              final repo = ref.read(courtsRepositoryProvider);
              if (court == null) {
                await repo.createCourt(
                  nameCtrl.text.trim(),
                  sportCtrl.text.trim(),
                  descCtrl.text.trim(),
                );
              } else {
                await repo.updateCourt(
                  court.id,
                  nameCtrl.text.trim(),
                  sportCtrl.text.trim(),
                  descCtrl.text.trim(),
                );
              }
              if (context.mounted) Navigator.pop(context);
              ref.invalidate(courtsListProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCourt(Court court) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete this court?',
      message: '${court.name} will be removed. Reservations linked to it may be affected.',
      confirmLabel: 'Yes, delete',
      cancelLabel: 'Cancel',
      isDanger: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(courtsRepositoryProvider);
    await repo.deleteCourt(court.id);
    ref.invalidate(courtsListProvider);
  }
}
