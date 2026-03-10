import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/admin_providers.dart';

/// Lists reservations with status ADMIN (admin-created). Admin can edit these.
class AdminAdminReservationsScreen extends ConsumerStatefulWidget {
  const AdminAdminReservationsScreen({super.key});

  @override
  ConsumerState<AdminAdminReservationsScreen> createState() =>
      _AdminAdminReservationsScreenState();
}

class _AdminAdminReservationsScreenState
    extends ConsumerState<AdminAdminReservationsScreen> {
  RealtimeChannel? _channel;

  // Same booking window as player UI: 6:00–22:00, 1-hour blocks.
  static const List<int> _bookingHours = [
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
  ];

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
          .channel('admin:admin_reservations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) => ref.invalidate(adminAdminReservationsProvider),
          )
          .subscribe();
    }

    final async = ref.watch(adminAdminReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin reservations')),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.admin_panel_settings_rounded,
              title: 'No admin reservations',
              subtitle: 'Reservations you create as admin appear here. You can edit them.',
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
              final user = r['users'];
              final court = r['courts'];
              final category = r['categories'] as Map<String, dynamic>?;
              final categoryName = category?['name']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  title: Text(
                    '${court?['name'] ?? 'Court'} • ${r['date']} ${r['start_time']} - ${r['end_time']}',
                    style: AppTypography.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${user['name']} (${user['email']}) • ${categoryName ?? r['event_type']}',
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    color: AppColors.blue600,
                    tooltip: 'Edit',
                    onPressed: () => _editReservation(r),
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

  bool _slotOverlaps(
      String slotStart,
      String slotEnd,
      List<({String start, String end})> occupied,
      ) {
    Duration parseTime(String s) {
      final parts = s.split(':');
      return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
    }

    final start = parseTime(slotStart);
    final end = parseTime(slotEnd);

    for (final o in occupied) {
      final oStart = parseTime(o.start);
      final oEnd = parseTime(o.end);

      if (start < oEnd && end > oStart) return true;
    }
    return false;
  }

  List<int> _availableEndsFor(
    List<({String start, String end})> occupied,
    int startHour,
  ) {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    final ends = <int>[];
    for (var h = startHour + 1; h <= 23; h++) {
      final endStr = '${h.toString().padLeft(2, '0')}:00';
      if (!_slotOverlaps(startStr, endStr, occupied)) ends.add(h);
    }
    return ends;
  }

  Future<void> _editReservation(Map<String, dynamic> r) async {
    final client = Supabase.instance.client;

    // Normalize time from DB to "HH:mm" (handles "09:00", "09:00:00", "9:00:00").
    String toHhMm(dynamic v) {
      final s = (v?.toString() ?? '').trim();
      if (s.isEmpty) return '';
      final parts = s.split(':');
      if (parts.isEmpty) return '';
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    final dateCtrl = TextEditingController(text: r['date']?.toString() ?? '');
    final startCtrl = TextEditingController(text: toHhMm(r['start_time']));
    final endCtrl = TextEditingController(text: toHhMm(r['end_time']));
    final eventCtrl = TextEditingController(text: r['event_type']?.toString() ?? '');
    final playersCtrl = TextEditingController(text: r['players_count']?.toString() ?? '');
    DateTime pickedDate =
        DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now();

    // For building available dropdown options we use occupied slots from RPC,
    // excluding the current reservation's own slot so it remains selectable.
    List<({String start, String end})> occupied = [];
    bool slotsLoading = true;
    bool initialSlotsLoadScheduled = false;

    Future<void> loadOccupied(DateTime day, void Function(void Function()) setState) async {
      setState(() => slotsLoading = true);
      final dateStr = day.toIso8601String().substring(0, 10);
      try {
        final res = await client.rpc(
          'get_occupied_slots',
          params: {
            'p_court_id': r['court_id'] as String,
            'p_date': dateStr,
          },
        );
        final list = (res as List?) ?? [];
        final mapped = list.map<({String start, String end})>((e) {
          final m = e as Map<String, dynamic>;
          final s = m['start_time'] as String? ?? '';
          final eStr = m['end_time'] as String? ?? '';
          return (start: toHhMm(s), end: toHhMm(eStr));
        }).toList();

        final currentStart = toHhMm(r['start_time']);
        final currentEnd = toHhMm(r['end_time']);

        setState(() {
          occupied = mapped
              .where(
                (o) => !(o.start == currentStart && o.end == currentEnd),
              )
              .toList();
          slotsLoading = false;
        });
      } catch (_) {
        setState(() {
          occupied = [];
          slotsLoading = false;
        });
      }
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load available slots once when dialog opens.
          if (!initialSlotsLoadScheduled) {
            initialSlotsLoadScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadOccupied(pickedDate, setDialogState);
            });
          }

          return AlertDialog(
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
                      await loadOccupied(pickedDate, setDialogState);
                    }
                  },
                  child: Text('Date: ${dateCtrl.text.isEmpty ? "Tap to pick" : dateCtrl.text}'),
                ),
                Builder(
                  builder: (context) {
                    if (slotsLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final availableStarts = <int>[];
                    for (final h in _bookingHours) {
                      final s = '${h.toString().padLeft(2, '0')}:00';
                      final e = h < 23
                          ? '${(h + 1).toString().padLeft(2, '0')}:00'
                          : '23:00';
                      if (!_slotOverlaps(s, e, occupied)) {
                        availableStarts.add(h);
                      }
                    }

                    int? selectedStartHour;
                    final startHhMm = toHhMm(startCtrl.text);
                    if (startHhMm.length >= 5) {
                      final h = int.tryParse(startHhMm.substring(0, 2));
                      if (h != null && availableStarts.contains(h)) {
                        selectedStartHour = h;
                      }
                    }

                    int? selectedEndHour;
                    final endHhMm = toHhMm(endCtrl.text);
                    if (endHhMm.length >= 5) {
                      final h = int.tryParse(endHhMm.substring(0, 2));
                      selectedEndHour = h;
                    }

                    final availableEnds = selectedStartHour == null
                        ? <int>[]
                        : _availableEndsFor(occupied, selectedStartHour);

                    if (availableStarts.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                          'No available time slots for this date. Pick another date.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.rejected),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          value: selectedStartHour,
                          decoration: const InputDecoration(
                            labelText: 'Start time',
                            hintText: 'Choose available start',
                          ),
                          items: availableStarts
                              .map(
                                (h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(
                                      '${h.toString().padLeft(2, '0')}:00'),
                                ),
                              )
                              .toList(),
                          onChanged: (h) {
                            if (h == null) return;
                            setDialogState(() {
                              final s =
                                  '${h.toString().padLeft(2, '0')}:00';
                              startCtrl.text = s;
                              final ends = _availableEndsFor(occupied, h);
                              if (ends.isNotEmpty) {
                                final firstEnd =
                                    '${ends.first.toString().padLeft(2, '0')}:00';
                                endCtrl.text = firstEnd;
                              } else {
                                endCtrl.text = '';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<int>(
                          value: selectedStartHour != null &&
                                  availableEnds.contains(selectedEndHour)
                              ? selectedEndHour
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'End time',
                            hintText: 'Choose available end',
                          ),
                          items: availableEnds
                              .map(
                                (h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(
                                      '${h.toString().padLeft(2, '0')}:00'),
                                ),
                              )
                              .toList(),
                          onChanged: selectedStartHour == null
                              ? null
                              : (h) {
                                  if (h == null) return;
                                  setDialogState(() {
                                    final e =
                                        '${h.toString().padLeft(2, '0')}:00';
                                    endCtrl.text = e;
                                  });
                                },
                        ),
                      ],
                    );
                  },
                ),
                TextField(controller: eventCtrl, decoration: const InputDecoration(labelText: 'Event type')),
                TextField(controller: playersCtrl, decoration: const InputDecoration(labelText: 'Number of players'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final confirmed = await ConfirmDialog.show(
                  ctx,
                  title: 'Save changes?',
                  message: 'Reservation details will be updated. Only free time slots on this date are allowed.',
                  confirmLabel: 'Yes, save',
                  cancelLabel: 'Cancel',
                  icon: Icons.save_outlined,
                );
                if (!confirmed || !ctx.mounted) return;

                final dateStr = pickedDate.toIso8601String().substring(0, 10);
                final startStr = startCtrl.text.trim();
                final endStr = endCtrl.text.trim();

                if (startStr.compareTo(endStr) >= 0) {
                  await showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Invalid time'),
                      content: const Text('End time must be after start time.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                try {
                  // Normalize time for RPC: HH:mm -> HH:mm:00 so PostgREST/PostgreSQL accept it.
                  String normTime(String t) {
                    final s = t.trim();
                    if (s.length == 5 && s[2] == ':') return '$s:00';
                    return s;
                  }
                  final overlapRes = await client.rpc(
                    'check_reservation_overlap',
                    params: {
                      'p_court_id': r['court_id'].toString(),
                      'p_date': dateStr,
                      'p_start': normTime(startStr),
                      'p_end': normTime(endStr),
                      'p_exclude_reservation_id': r['id'].toString(),
                    },
                  );
                  if (overlapRes == null) {
                    await showDialog(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Error'),
                        content: const Text('Could not check availability. Please try again.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  if (overlapRes != true) {
                    await showDialog(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Time not available'),
                        content: const Text('This time slot is already booked. Choose another.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  await client.from('reservations').update({
                    'date': dateStr,
                    'start_time': startStr,
                    'end_time': endStr,
                    'event_type': eventCtrl.text.trim(),
                    'players_count': int.tryParse(playersCtrl.text.trim()) ?? 1,
                  }).eq('id', r['id']);

                  // Direct insert into notifications table (no RPC) so user sees it and can Get it / Cancel.
                  String? notifError;
                  final userId = r['user_id']?.toString();
                  final reservationId = r['id']?.toString();
                  if (userId != null &&
                      userId.isNotEmpty &&
                      reservationId != null &&
                      reservationId.isNotEmpty) {
                    try {
                      await client.from('notifications').insert({
                        'user_id': userId,
                        'title': 'Reservation rescheduled by admin',
                        'message':
                            'An admin rescheduled your reservation. Open Notifications and tap Get it to agree or Cancel to decline.',
                        'type': 'RESERVATION_ADMIN_EDIT',
                        'reservation_id': reservationId,
                      });
                    } catch (notifE) {
                      notifError = notifE.toString();
                    }
                  }

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    await showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Success'),
                        content: Text(
                          notifError != null
                              ? 'Reservation updated. Notification could not be sent: $notifError'
                              : 'Reservation updated. User was notified.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  ref.invalidate(adminAdminReservationsProvider);
                } catch (e) {
                  if (ctx.mounted) {
                    await showDialog(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Error'),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
    },
  ),
    );
  }
}
