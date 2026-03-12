import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_list_padding.dart';
import '../../reservation_change/domain/reservation_change_providers.dart';
import '../data/notification_model.dart';
import '../domain/notifications_providers.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AsyncValueView<List<AppNotification>>(
        value: notifsAsync,
        isEmpty: (list) => list.isEmpty,
        empty: () => const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications yet',
          subtitle: "You'll see reservation updates and reminders here.",
        ),
        data: (list) {
          final changeRequestNotifs = list
              .where((n) => n.type == 'reservation_change_request')
              .toList();
          final otherNotifs = list
              .where((n) => n.type != 'reservation_change_request')
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(changeRequestByIdProvider);
            },
            child: ScreenListPadding(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (changeRequestNotifs.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        'Change requests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ...changeRequestNotifs.map((n) => _buildNotificationCard(ref, context, n)),
                    if (otherNotifs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                  if (otherNotifs.isNotEmpty && changeRequestNotifs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ...otherNotifs.map((n) => _buildNotificationCard(ref, context, n)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    WidgetRef ref,
    BuildContext context,
    AppNotification n,
  ) {
    final changeRequestAsync = n.changeRequestId != null
        ? ref.watch(changeRequestByIdProvider(n.changeRequestId!))
        : null;
    final changeRequest = changeRequestAsync?.valueOrNull;
    final changeRequestLoading = n.type == 'reservation_change_request' && (changeRequestAsync?.isLoading ?? false);

    return NotificationCard(
                    notification: n,
                    changeRequest: changeRequest,
                    changeRequestLoading: changeRequestLoading,
                  onAccept: n.changeRequestId != null && n.reservationId != null
                      ? () async {
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid == null) return;
                          try {
                            await ref
                                .read(reservationChangeServiceProvider)
                                .acceptChangeRequest(
                                  changeRequestId: n.changeRequestId!,
                                  userId: uid,
                                  notificationId: n.id,
                                );
                            ref.invalidate(myNotificationsProvider);
                            ref.invalidate(myPendingChangeRequestsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Change accepted. Reservation updated.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  onReject: n.changeRequestId != null
                      ? () async {
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid == null) return;
                          try {
                            await ref
                                .read(reservationChangeServiceProvider)
                                .rejectChangeRequest(
                                  changeRequestId: n.changeRequestId!,
                                  userId: uid,
                                  notificationId: n.id,
                                );
                            ref.invalidate(myNotificationsProvider);
                            ref.invalidate(myPendingChangeRequestsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Change declined. Your reservation stays as is.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  onCancel: () async {
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
                  onGetIt: () async {
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
                  onMarkRead: () => ref
                      .read(notificationsRepositoryProvider)
                      .markAsRead(n.id)
                      .then((_) => ref.invalidate(myNotificationsProvider)),
                );
  }
}
