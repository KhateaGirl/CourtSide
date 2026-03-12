import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/reservation_list_card.dart';
import '../../../core/widgets/screen_list_padding.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_edit_reservation_dialog.dart';

/// Lists reservations with status ADMIN (admin-created). Admin can edit these.
class AdminAdminReservationsScreen extends ConsumerStatefulWidget {
  const AdminAdminReservationsScreen({super.key});

  @override
  ConsumerState<AdminAdminReservationsScreen> createState() =>
      _AdminAdminReservationsScreenState();
}

class _AdminAdminReservationsScreenState
    extends ConsumerState<AdminAdminReservationsScreen> {
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
          .channel('admin:admin_reservations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) => ref.invalidate(adminAdminReservationsProvider),
          )
          .subscribe();
    }

    final async = ref.watch(adminAdminReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin reservations')),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.admin_panel_settings_rounded,
              title: 'No admin reservations',
              subtitle: 'Reservations you create as admin appear here. You can edit them.',
            );
          }
          return ScreenListPadding(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final r = list[index];
                final user = r['users'];
                final court = r['courts'];
                final category = r['categories'] as Map<String, dynamic>?;
                final categoryName = category?['name']?.toString();
                return ReservationListCard(
                  title:
                      '${court?['name'] ?? 'Court'} • ${r['date']} ${r['start_time']} - ${r['end_time']}',
                  subtitle:
                      '${user['name']} (${user['email']}) • ${categoryName ?? r['event_type']}',
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    color: AppColors.blue600,
                    tooltip: 'Edit',
                    onPressed: () => AdminEditReservationDialog.show(
                      context,
                      ref,
                      r,
                      onSuccess: () =>
                          ref.invalidate(adminAdminReservationsProvider),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

}
