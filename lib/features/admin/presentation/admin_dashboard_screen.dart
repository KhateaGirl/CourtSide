import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../domain/admin_providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  RealtimeChannel? _reservationsChannel;
  RealtimeChannel? _analyticsChannel;

  @override
  void dispose() {
    final client = Supabase.instance.client;
    if (_reservationsChannel != null) client.removeChannel(_reservationsChannel!);
    if (_analyticsChannel != null) client.removeChannel(_analyticsChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reservationsChannel == null) {
      _reservationsChannel = Supabase.instance.client
          .channel('admin:reservations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) => ref.invalidate(adminStatsProvider),
          )
          .subscribe();
    }
    if (_analyticsChannel == null) {
      _analyticsChannel = Supabase.instance.client
          .channel('admin:analytics')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'analytics_daily',
            callback: (_) => ref.invalidate(adminStatsProvider),
          )
          .subscribe();
    }

    final statsAsync = ref.watch(adminStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Admin Dashboard',
        actions: [AppBarThemeToggle()],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                ),
        ),
        child: statsAsync.when(
          data: (stats) {
            final isNarrow = Responsive.isNarrow(context);
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? AppSpacing.sm : AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNarrow) ...[
                    _metricCard(context, 'Reservations today', (stats['totalToday'] ?? 0).toString()),
                    _metricCard(context, 'Pending', (stats['pending'] ?? 0).toString()),
                    _metricCard(context, 'Busiest hour', stats['busiestHour']?.toString() ?? '-'),
                    _metricCard(context, 'Top sport', stats['mostSport']?.toString() ?? '-'),
                  ] else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _metricCard(context, 'Reservations today', (stats['totalToday'] ?? 0).toString())),
                            Expanded(child: _metricCard(context, 'Pending', (stats['pending'] ?? 0).toString())),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _metricCard(context, 'Busiest hour', stats['busiestHour']?.toString() ?? '-')),
                            Expanded(child: _metricCard(context, 'Top sport', stats['mostSport']?.toString() ?? '-')),
                          ],
                        ),
                      ],
                    ),
                  if (stats['busiestDays'] != null && (stats['busiestDays'] as List).isNotEmpty) ...[
                    AppSpacing.gapSmV,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Busiest days (last 7)', style: AppTypography.labelLarge),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: (stats['busiestDays'] as List).length,
                        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final m = (stats['busiestDays'] as List)[i] as Map<String, dynamic>;
                          return Chip(
                            label: Text('${m['date']} (${m['total_bookings']})'),
                            backgroundColor: AppColors.blue50,
                          );
                        },
                      ),
                    ),
                  ],
                  AppSpacing.gapMdV,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push('/admin/pending'),
                        child: const Text('Pending'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/admin/users'),
                        child: const Text('Users'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/admin/categories'),
                        child: const Text('Categories'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/admin/reservations'),
                        child: const Text('Admin reservations'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/admin/schedule'),
                        child: const Text('Schedule'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _metricCard(BuildContext context, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = GlassCard(
      margin: const EdgeInsets.all(AppSpacing.xs),
      padding: AppSpacing.paddingMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTypography.labelLarge, textAlign: TextAlign.center),
          AppSpacing.gapSmV,
          Text(
            value,
            style: AppTypography.displaySmall.copyWith(
              color: isDark ? AppColors.cyan400 : AppColors.blue700,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return card;
  }
}
