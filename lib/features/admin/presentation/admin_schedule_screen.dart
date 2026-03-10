import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/admin_providers.dart';

class AdminScheduleScreen extends ConsumerStatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  ConsumerState<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends ConsumerState<AdminScheduleScreen> {
  DateTime _filterDate = DateTime.now();
  String? _filterEventType;
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
          .channel('admin:schedule')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) => ref.invalidate(adminScheduleProvider),
          )
          .subscribe();
    }

    final dateKey = _filterDate.toIso8601String().substring(0, 10);
    final scheduleAsync = ref.watch(adminScheduleProvider((date: dateKey, eventType: _filterEventType)));

    return Scaffold(
      appBar: AppBar(title: const Text('Court schedule')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.isNarrow(context) ? AppSpacing.sm : AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Responsive.isNarrow(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${_filterDate.year}-${_filterDate.month.toString().padLeft(2, '0')}-${_filterDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String>(
                        value: _filterEventType,
                        decoration: const InputDecoration(
                          labelText: 'Event type',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ..._eventTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                        ],
                        onChanged: (v) {
                          setState(() => _filterEventType = v);
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            '${_filterDate.year}-${_filterDate.month.toString().padLeft(2, '0')}-${_filterDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterEventType,
                          decoration: const InputDecoration(
                            labelText: 'Event type',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All')),
                            ..._eventTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                          ],
                          onChanged: (v) {
                            setState(() => _filterEventType = v);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: scheduleAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.calendar_today_rounded,
                    title: 'No reservations for this date',
                    subtitle: 'Try another date or event type.',
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
                    final user = r['users'] as Map<String, dynamic>?;
                    final court = r['courts'] as Map<String, dynamic>?;
                    final category = r['categories'] as Map<String, dynamic>?;
                    final categoryName = category?['name']?.toString();
                    final status = r['status'] as String? ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Container(
                          width: 4,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: AppRadius.radiusXs,
                          ),
                        ),
                        title: Text(
                          '${court?['name'] ?? 'Court'} • ${r['start_time']} - ${r['end_time']}',
                          style: AppTypography.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${user?['name']} • ${categoryName ?? r['event_type']} • $status',
                          style: AppTypography.bodySmall,
                          maxLines: 2,
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
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _filterDate = d);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.pending;
      case 'APPROVED':
        return AppColors.approved;
      case 'CANCELLED':
      case 'REJECTED':
        return AppColors.cancelled;
      default:
        return AppColors.neutral600;
    }
  }

  static const List<String> _eventTypes = ['Basketball', 'Volleyball', 'Rent', 'Practice', 'Pickup', 'Other'];
}
