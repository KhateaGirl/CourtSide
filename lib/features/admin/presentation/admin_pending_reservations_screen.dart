import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';

class AdminPendingReservationsScreen extends StatefulWidget {
  const AdminPendingReservationsScreen({super.key});

  @override
  State<AdminPendingReservationsScreen> createState() =>
      _AdminPendingReservationsScreenState();
}

class _AdminPendingReservationsScreenState
    extends State<AdminPendingReservationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final res = await client
        .from('reservations')
        .select('*, users(name,email), courts(name)')
        .eq('status', 'PENDING')
        .order('date')
        .order('start_time');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _setStatus(String id, String status) async {
    final client = Supabase.instance.client;
    await client.functions.invoke(
      'approve_reservation',
      body: {'reservation_id': id, 'status': status},
    );
    setState(() => _future = _load());
  }

  Future<void> _editReservation(Map<String, dynamic> r) async {
    final client = Supabase.instance.client;
    final dateCtrl = TextEditingController(text: r['date']?.toString() ?? '');
    final startCtrl = TextEditingController(text: r['start_time']?.toString().substring(0, 5) ?? '');
    final endCtrl = TextEditingController(text: r['end_time']?.toString().substring(0, 5) ?? '');
    final eventCtrl = TextEditingController(text: r['event_type']?.toString() ?? '');
    final playersCtrl = TextEditingController(text: r['players_count']?.toString() ?? '');
    DateTime pickedDate = DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit reservation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      setDialogState(() {
                        pickedDate = d;
                        dateCtrl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Text('Date: ${dateCtrl.text.isEmpty ? "Tap to pick" : dateCtrl.text}'),
                ),
                TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start time (HH:mm)')),
                TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End time (HH:mm)')),
                TextField(controller: eventCtrl, decoration: const InputDecoration(labelText: 'Event type')),
                TextField(controller: playersCtrl, decoration: const InputDecoration(labelText: 'Number of players'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await client.from('reservations').update({
                  'date': pickedDate.toIso8601String().substring(0, 10),
                  'start_time': startCtrl.text.trim(),
                  'end_time': endCtrl.text.trim(),
                  'event_type': eventCtrl.text.trim(),
                  'players_count': int.tryParse(playersCtrl.text.trim()) ?? 1,
                }).eq('id', r['id']);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _future = _load());
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending reservations')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              final user = r['users'];
              final court = r['courts'];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  title: Text(
                    '${court['name']} • ${r['date']} ${r['start_time']} - ${r['end_time']}',
                    style: AppTypography.titleMedium,
                  ),
                  subtitle: Text(
                    '${user['name']} (${user['email']}) • ${r['event_type']}',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: AppColors.blue600,
                        onPressed: () => _editReservation(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        color: AppColors.approved,
                        onPressed: () => _setStatus(r['id'], 'APPROVED'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: AppColors.rejected,
                        onPressed: () => _setStatus(r['id'], 'REJECTED'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

