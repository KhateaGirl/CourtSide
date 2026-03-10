import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/courts_providers.dart';

class CourtsListScreen extends ConsumerStatefulWidget {
  const CourtsListScreen({super.key});

  @override
  ConsumerState<CourtsListScreen> createState() => _CourtsListScreenState();
}

class _CourtsListScreenState extends ConsumerState<CourtsListScreen> {
  RealtimeChannel? _courtsChannel;

  @override
  void dispose() {
    if (_courtsChannel != null) {
      Supabase.instance.client.removeChannel(_courtsChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_courtsChannel == null) {
      final repo = ref.read(courtsRepositoryProvider);
      _courtsChannel = repo.subscribeToCourtsChanges(() {
        ref.invalidate(courtsListProvider);
      });
    }

    final courtsAsync = ref.watch(courtsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Courts')),
      body: courtsAsync.when(
        data: (courts) {
          if (courts.isEmpty) {
            return const EmptyState(
              icon: Icons.sports_basketball,
              title: 'No courts yet',
              subtitle: 'Courts will appear here once added by admin.',
            );
          }
          return ListView.builder(
          padding: AppSpacing.paddingMd,
          itemCount: courts.length,
          itemBuilder: (context, index) {
            final c = courts[index];
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
