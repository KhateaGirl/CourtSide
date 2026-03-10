import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<Map<String, dynamic>> _loadStats() async {
    final client = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final totalTodayData = await client
        .from('reservations')
        .select('id')
        .eq('date', today);
    final totalToday = (totalTodayData as List).length;

    final pendingTodayData = await client
        .from('reservations')
        .select('id')
        .eq('status', 'PENDING');
    final pendingToday = (pendingTodayData as List).length;

    final analytics = await client
        .from('analytics_daily')
        .select()
        .eq('date', today)
        .maybeSingle();

    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
    final busiestDaysData = await client
        .from('analytics_daily')
        .select('date,total_bookings')
        .gte('date', weekAgo)
        .order('total_bookings', ascending: false)
        .limit(5);
    final busiestDays = busiestDaysData as List;

    return {
      'totalToday': totalToday,
      'pending': pendingToday,
      'busiestHour': analytics?['busiest_hour'],
      'mostSport': analytics?['most_booked_sport'],
      'busiestDays': busiestDays,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Admin Dashboard')),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _metricCard(
                            'Reservations today',
                            (stats?['totalToday'] ?? 0).toString(),
                          ),
                          _metricCard(
                            'Pending',
                            (stats?['pending'] ?? 0).toString(),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _metricCard(
                            'Busiest hour',
                            stats?['busiestHour']?.toString() ?? '-',
                          ),
                          _metricCard(
                            'Top sport',
                            stats?['mostSport']?.toString() ?? '-',
                          ),
                        ],
                      ),
                      if (stats?['busiestDays'] != null && (stats!['busiestDays'] as List).isNotEmpty) ...[
                        AppSpacing.gapSmV,
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Busiest days (last 7)', style: AppTypography.labelLarge),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: (stats['busiestDays'] as List).map<Widget>((e) {
                              final m = e as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.sm),
                                child: Chip(
                                  label: Text('${m['date']} (${m['total_bookings']})'),
                                  backgroundColor: AppColors.blue50,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      AppSpacing.gapMdV,
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          ElevatedButton(
                            onPressed: () => context.push('/admin/pending'),
                            child: const Text('Pending reservations'),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/admin/users'),
                            child: const Text('User management'),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/admin/courts'),
                            child: const Text('Court management'),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/admin/schedule'),
                            child: const Text('Court schedule'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _metricCard(String title, String value) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(AppSpacing.xs),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            children: [
              Text(title, style: AppTypography.labelLarge),
              AppSpacing.gapSmV,
              Text(
                value,
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.blue700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

