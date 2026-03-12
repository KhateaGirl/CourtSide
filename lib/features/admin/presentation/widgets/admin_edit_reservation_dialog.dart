import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../../core/utils/slot_utils.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../reservation_change/domain/reservation_change_providers.dart';

/// Shared dialog for admin to edit a reservation (time, etc.) by sending a change request to the player.
/// Use from Pending Reservations or Admin Reservations screen.
class AdminEditReservationDialog extends ConsumerStatefulWidget {
  const AdminEditReservationDialog({
    super.key,
    required this.reservation,
    this.onSuccess,
  });

  final Map<String, dynamic> reservation;
  final VoidCallback? onSuccess;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> reservation, {
    VoidCallback? onSuccess,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AdminEditReservationDialog(
        reservation: reservation,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<AdminEditReservationDialog> createState() =>
      _AdminEditReservationDialogState();
}

class _AdminEditReservationDialogState
    extends ConsumerState<AdminEditReservationDialog> {
  static const List<int> _bookingHours = [
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
  ];

  late final TextEditingController _dateCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  late final TextEditingController _eventCtrl;
  late final TextEditingController _playersCtrl;
  late final TextEditingController _messageCtrl;
  late DateTime _pickedDate;
  List<({String start, String end})> _occupied = [];
  bool _slotsLoading = true;
  bool _initialLoadScheduled = false;

  Map<String, dynamic> get r => widget.reservation;

  static String toHhMm(dynamic v) {
    final s = (v?.toString() ?? '').trim();
    if (s.isEmpty) return '';
    final parts = s.split(':');
    if (parts.isEmpty) return '';
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<int> _availableEndsFor(
      List<({String start, String end})> occupied, int startHour) {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    final ends = <int>[];
    for (var h = startHour + 1; h <= 23; h++) {
      final endStr = '${h.toString().padLeft(2, '0')}:00';
      if (!slotOverlaps(startStr, endStr, occupied)) ends.add(h);
    }
    return ends;
  }

  Future<void> _loadOccupied(DateTime day) async {
    setState(() => _slotsLoading = true);
    final client = Supabase.instance.client;
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
        _occupied = mapped
            .where((o) => !(o.start == currentStart && o.end == currentEnd))
            .toList();
        _slotsLoading = false;
      });
    } catch (_) {
      setState(() {
        _occupied = [];
        _slotsLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(text: r['date']?.toString() ?? '');
    _startCtrl = TextEditingController(text: toHhMm(r['start_time']));
    _endCtrl = TextEditingController(text: toHhMm(r['end_time']));
    _eventCtrl = TextEditingController(text: r['event_type']?.toString() ?? '');
    _playersCtrl =
        TextEditingController(text: r['players_count']?.toString() ?? '');
    _messageCtrl = TextEditingController();
    _pickedDate =
        DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _eventCtrl.dispose();
    _playersCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final ctx = context;
    final confirmed = await ConfirmDialog.show(
      ctx,
      title: 'Send change request?',
      message:
          'A change request will be sent to the player. They must accept or reject within 24 hours. The reservation will only update if they accept.',
      confirmLabel: 'Yes, send request',
      cancelLabel: 'Cancel',
      icon: Icons.schedule_send_outlined,
    );
    if (!confirmed || !mounted) return;

    final dateStr = _pickedDate.toIso8601String().substring(0, 10);
    final startStr = _startCtrl.text.trim();
    final endStr = _endCtrl.text.trim();

    try {
      final changeRepo =
          ref.read(reservationChangeRequestsRepositoryProvider);
      final pending =
          await changeRepo.getPendingByReservation(r['id'].toString());
      if (pending != null && mounted) {
        await showDialog(
          context: ctx,
          builder: (dCtx) => AlertDialog(
            title: const Text('Pending change request'),
            content: const Text(
              'This reservation already has a pending change request. The player must respond first.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx), child: const Text('OK')),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: ctx,
          builder: (dCtx) => AlertDialog(
            title: const Text('Error checking change requests'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    if (startStr.compareTo(endStr) >= 0) {
      await showDialog(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          title: const Text('Invalid time'),
          content: const Text('End time must be after start time.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final client = Supabase.instance.client;
    String normTime(String t) {
      final s = t.trim();
      if (s.length == 5 && s[2] == ':') return '$s:00';
      return s;
    }
    try {
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
        if (mounted) {
          await showDialog(
            context: ctx,
            builder: (dCtx) => AlertDialog(
              title: const Text('Error'),
              content: const Text(
                  'Could not check availability. Please try again.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('OK')),
              ],
            ),
          );
        }
        return;
      }
      if (overlapRes != true) {
        if (mounted) {
          await showDialog(
            context: ctx,
            builder: (dCtx) => AlertDialog(
              title: const Text('Time not available'),
              content: const Text(
                  'This time slot is already booked. Choose another.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('OK')),
              ],
            ),
          );
        }
        return;
      }

      final court = r['courts'] as Map<String, dynamic>?;
      final courtName = court?['name']?.toString() ?? 'Court';
      final playerId = (r['user_id']?.toString() ?? '').trim();
      final reservationId = (r['id']?.toString() ?? '').trim();
      if (playerId.isEmpty || reservationId.isEmpty) {
        if (mounted) {
          await showDialog(
            context: ctx,
            builder: (dCtx) => AlertDialog(
              title: const Text('Error'),
              content: const Text(
                'Reservation or player id is missing. Cannot create change request.',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('OK')),
              ],
            ),
          );
        }
        return;
      }
      final oldStart = toHhMm(r['start_time']);
      final oldEnd = toHhMm(r['end_time']);
      final message = _messageCtrl.text.trim().isEmpty
          ? null
          : _messageCtrl.text.trim();

      await ref.read(reservationChangeServiceProvider).createChangeRequest(
            reservationId: reservationId,
            playerId: playerId,
            courtName: courtName,
            oldStartTime: oldStart,
            oldEndTime: oldEnd,
            newStartTime: startStr,
            newEndTime: endStr,
            message: message,
          );

      if (mounted) {
        Navigator.pop(context);
        await showDialog(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Change request sent'),
            content: const Text(
              'The player will be notified and must accept or reject within 24 hours.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx), child: const Text('OK')),
            ],
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: ctx,
          builder: (dCtx) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoadScheduled) {
      _initialLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOccupied(_pickedDate);
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
                  context: context,
                  initialDate: _pickedDate,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) {
                  setState(() {
                    _pickedDate = d;
                    _dateCtrl.text =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  });
                  await _loadOccupied(_pickedDate);
                }
              },
              child: Text(
                  'Date: ${_dateCtrl.text.isEmpty ? "Tap to pick" : _dateCtrl.text}'),
            ),
            Builder(
              builder: (context) {
                if (_slotsLoading) {
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
                  if (!slotOverlaps(s, e, _occupied)) {
                    availableStarts.add(h);
                  }
                }
                int? selectedStartHour;
                final startHhMm = toHhMm(_startCtrl.text);
                if (startHhMm.length >= 5) {
                  final h = int.tryParse(startHhMm.substring(0, 2));
                  if (h != null && availableStarts.contains(h)) {
                    selectedStartHour = h;
                  }
                }
                int? selectedEndHour;
                final endHhMm = toHhMm(_endCtrl.text);
                if (endHhMm.length >= 5) {
                  final h = int.tryParse(endHhMm.substring(0, 2));
                  selectedEndHour = h;
                }
                final availableEnds = selectedStartHour == null
                    ? <int>[]
                    : _availableEndsFor(_occupied, selectedStartHour);

                if (availableStarts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'No available time slots for this date. Pick another date.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.rejected),
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
                        setState(() {
                          _startCtrl.text =
                              '${h.toString().padLeft(2, '0')}:00';
                          final ends = _availableEndsFor(_occupied, h);
                          if (ends.isNotEmpty) {
                            _endCtrl.text =
                                '${ends.first.toString().padLeft(2, '0')}:00';
                          } else {
                            _endCtrl.text = '';
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
                              setState(() {
                                _endCtrl.text =
                                    '${h.toString().padLeft(2, '0')}:00';
                              });
                            },
                    ),
                  ],
                );
              },
            ),
            TextField(
                controller: _eventCtrl,
                decoration: const InputDecoration(labelText: 'Event type')),
            TextField(
                controller: _playersCtrl,
                decoration: const InputDecoration(
                    labelText: 'Number of players'),
                keyboardType: TextInputType.number),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: 'Message to player (optional)',
                hintText: 'e.g. Moved to fit another booking',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
