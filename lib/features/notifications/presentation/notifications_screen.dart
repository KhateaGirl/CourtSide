import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              subtitle: 'You’ll see reservation updates and reminders here.',
            );
          }
          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];

              Widget trailing;
              final isAdminEdit =
                  n.type == 'RESERVATION_ADMIN_EDIT' && !n.isRead && n.reservationId != null;

              if (isAdminEdit) {
                trailing = Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .handleAdminEditDecision(
                              notificationId: n.id,
                              reservationId: n.reservationId!,
                              accept: false,
                            );
                        ref.invalidate(myNotificationsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reservation cancelled.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.rejected),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .handleAdminEditDecision(
                              notificationId: n.id,
                              reservationId: n.reservationId!,
                              accept: true,
                            );
                        ref.invalidate(myNotificationsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Got it. Reservation approved.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Get it'),
                    ),
                  ],
                );
              } else {
                trailing = n.isRead
                    ? Icon(Icons.done, color: AppColors.approved)
                    : TextButton(
                        onPressed: () => ref
                            .read(notificationsRepositoryProvider)
                            .markAsRead(n.id)
                            .then(
                              (_) => ref.invalidate(myNotificationsProvider),
                            ),
                        child: const Text('Mark read'),
                      );
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        n.title,
                        style: AppTypography.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        n.message,
                        style: AppTypography.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isAdminEdit) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Get it = agree to reschedule. Cancel = decline.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.neutral600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [trailing],
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
}

