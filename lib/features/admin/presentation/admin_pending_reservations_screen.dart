import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/admin_providers.dart';

class AdminPendingReservationsScreen extends ConsumerStatefulWidget {
  const AdminPendingReservationsScreen({super.key});

  @override
  ConsumerState<AdminPendingReservationsScreen> createState() =>
      _AdminPendingReservationsScreenState();
}

class _AdminPendingReservationsScreenState
    extends ConsumerState<AdminPendingReservationsScreen> {
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
          .channel('admin:pending_reservations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) => ref.invalidate(adminPendingReservationsProvider),
          )
          .subscribe();
    }

    final pendingAsync = ref.watch(adminPendingReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending reservations')),
      body: pendingAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.pending_actions_rounded,
              title: 'No pending reservations',
              subtitle: 'All caught up. New requests will show here.',
            );
          }
          return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isNarrow(context) ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final r = list[index];
            final user = r['users'];
            final court = r['courts'];
            final category = r['categories'] as Map<String, dynamic>?;
            final categoryName = category?['name']?.toString();
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                title: Text(
                  '${court?['name'] ?? 'Court'} • ${r['date']} ${r['start_time']} - ${r['end_time']}',
                  style: AppTypography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${user['name']} (${user['email']}) • ${categoryName ?? r['event_type']}',
                  style: AppTypography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check),
                      color: AppColors.approved,
                      tooltip: 'Approve',
                      onPressed: () => _confirmSetStatus(r, 'APPROVED'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: AppColors.rejected,
                      tooltip: 'Reject',
                      onPressed: () => _confirmSetStatus(r, 'REJECTED'),
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

  Future<void> _confirmSetStatus(Map<String, dynamic> r, String status) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: status == 'APPROVED' ? 'Approve this reservation?' : 'Reject this reservation?',
      message: status == 'APPROVED'
          ? 'The user will be notified and the slot will be confirmed.'
          : 'The user will be notified. Only the user who made the reservation can edit it.',
      confirmLabel: status == 'APPROVED' ? 'Yes, approve' : 'Yes, reject',
      cancelLabel: 'Cancel',
      isDanger: status == 'REJECTED',
      icon: status == 'APPROVED' ? Icons.check_circle_outline : Icons.cancel_outlined,
    );
    if (!confirmed || !mounted) return;
    await _setStatus(r['id'], r['user_id'], status);
  }

  Future<void> _setStatus(String id, dynamic userId, String status) async {
    final client = Supabase.instance.client;
    try {
      final res = await client
          .from('reservations')
          .update({'status': status})
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (res == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservation not found')),
          );
        }
        return;
      }
      final uid = userId?.toString() ?? '';
      if (uid.isNotEmpty) {
        final title = status == 'APPROVED' ? 'Reservation approved' : 'Reservation rejected';
        final message = status == 'APPROVED'
            ? 'Your reservation has been approved.'
            : 'Your reservation has been rejected.';
        await client.from('notifications').insert({
          'user_id': uid,
          'title': title,
          'message': message,
        });
      }
      ref.invalidate(adminPendingReservationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reservation $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

}
