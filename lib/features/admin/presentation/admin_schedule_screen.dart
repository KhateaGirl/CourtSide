import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  DateTime _filterDate = DateTime.now();
  String? _filterEventType;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    var query = Supabase.instance.client
        .from('reservations')
        .select('*, users(name,email), courts(name,sport_type)')
        .eq('date', _filterDate.toIso8601String().substring(0, 10));
    if (_filterEventType != null && _filterEventType!.isNotEmpty) {
      query = query.eq('event_type', _filterEventType!);
    }
    final res = await query.order('start_time');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _filterDate = d;
        _future = _load();
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Court schedule')),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Row(
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
                AppSpacing.gapSmH,
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
                      setState(() {
                        _filterEventType = v;
                        _future = _load();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No reservations for this date',
                      style: AppTypography.bodyLarge.copyWith(color: AppColors.neutral500),
                    ),
                  );
                }
                return ListView.builder(
                  padding: AppSpacing.paddingMd,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final r = list[index];
                    final user = r['users'] as Map<String, dynamic>?;
                    final court = r['courts'] as Map<String, dynamic>?;
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
                          '${court?['name']} • ${r['start_time']} - ${r['end_time']}',
                          style: AppTypography.titleMedium,
                        ),
                        subtitle: Text(
                          '${user?['name']} • ${r['event_type']} • $status',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _eventTypes = ['Basketball', 'Volleyball', 'Rent', 'Practice', 'Pickup', 'Other'];
}
