import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../domain/notifications_providers.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifsAsync.when(
        data: (list) => ListView.builder(
          padding: AppSpacing.paddingMd,
          itemCount: list.length,
          itemBuilder: (context, index) {
            final n = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                title: Text(n.title, style: AppTypography.titleMedium),
                subtitle: Text(n.message, style: AppTypography.bodySmall),
                trailing: n.isRead
                    ? Icon(Icons.done, color: AppColors.approved)
                    : TextButton(
                      onPressed: () => ref
                          .read(notificationsRepositoryProvider)
                          .markAsRead(n.id)
                          .then(
                            (_) =>
                                ref.invalidate(myNotificationsProvider),
                          ),
                      child: const Text('Mark read'),
                    ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

