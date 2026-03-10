import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../domain/courts_providers.dart';

class CourtsListScreen extends ConsumerWidget {
  const CourtsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(courtsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Courts')),
      body: courtsAsync.when(
        data: (courts) => ListView.builder(
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
                title: Text(c.name, style: AppTypography.titleMedium),
                subtitle: Text(
                  c.sportType,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.orange700,
                  ),
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

