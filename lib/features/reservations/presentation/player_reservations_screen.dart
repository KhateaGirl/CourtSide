import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_design_system.dart';
import '../../auth/domain/auth_providers.dart';
import '../../courts/domain/courts_providers.dart';
import '../domain/reservations_providers.dart';
import '../../courts/data/court_model.dart';
import '../data/reservation_model.dart';

class PlayerReservationsScreen extends ConsumerStatefulWidget {
  const PlayerReservationsScreen({super.key});

  @override
  ConsumerState<PlayerReservationsScreen> createState() =>
      _PlayerReservationsScreenState();
}

class _PlayerReservationsScreenState
    extends ConsumerState<PlayerReservationsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Court? _selectedCourt;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _eventCtrl = TextEditingController();
  final _playersCtrl = TextEditingController(text: '10');
  bool _booking = false;
  String? _error;
  RealtimeChannel? _reservationsChannel;

  static const double _wideLayoutBreakpoint = 600;

  @override
  void dispose() {
    if (_reservationsChannel != null) {
      Supabase.instance.client.removeChannel(_reservationsChannel!);
    }
    super.dispose();
  }

  Widget _buildFormSection(WidgetRef ref) {
    final courtsAsync = ref.watch(courtsListProvider);
    return ListView(
      shrinkWrap: true,
      padding: AppSpacing.paddingMd,
      children: [
        courtsAsync.when(
          data: (courts) {
            _selectedCourt ??= courts.isNotEmpty ? courts.first : null;
            return DropdownButtonFormField<Court>(
              value: _selectedCourt,
              items: courts
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.name} (${c.sportType})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCourt = v),
              decoration: const InputDecoration(labelText: 'Select court'),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, st) => Text('Error: $e'),
        ),
        AppSpacing.gapMdV,
        _buildCalendar(),
        AppSpacing.gapMdV,
        _buildAvailabilitySection(ref),
        AppSpacing.gapMdV,
        _buildTimePickers(context),
        AppSpacing.gapSmV,
        TextField(
          controller: _eventCtrl,
          decoration: const InputDecoration(labelText: 'Event type'),
        ),
        TextField(
          controller: _playersCtrl,
          decoration:
              const InputDecoration(labelText: 'Number of players'),
          keyboardType: TextInputType.number,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _error!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        AppSpacing.gapSmV,
        ElevatedButton.icon(
          onPressed: _booking ? null : _createReservation,
          icon: _booking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Create reservation'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(myReservationsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final useWideLayout = width >= _wideLayoutBreakpoint;

    if (_reservationsChannel == null) {
      final repo = ref.read(reservationsRepositoryProvider);
      _reservationsChannel = repo.subscribeToMyReservationsChanges(() {
        ref.invalidate(myReservationsProvider);
      });
    }

    final profileAsync = ref.watch(currentUserProfileProvider);
    final isAdmin = profileAsync.valueOrNull?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reservations'),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.dashboard, size: 20),
              label: const Text('Admin'),
            ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: useWideLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 280),
                      child: _buildFormSection(ref),
                    ),
                  ),
                ),
                Expanded(
                  child: reservationsAsync.when(
                    data: (res) => _buildReservationsSection(res),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildFormSection(ref),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: reservationsAsync.when(
                    data: (res) => _buildReservationsSection(res),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
    );
  }

  bool _slotOverlaps(String slotStart, String slotEnd, List<({String start, String end})> occupied) {
    for (final range in occupied) {
      if (slotStart.compareTo(range.end) < 0 && slotEnd.compareTo(range.start) > 0) return true;
    }
    return false;
  }

  Widget _buildAvailabilitySection(WidgetRef ref) {
    final court = _selectedCourt;
    if (court == null) return const SizedBox.shrink();
    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupiedAsync = ref.watch(occupiedSlotsProvider((courtId: court.id, date: dateKey)));
    return occupiedAsync.when(
      data: (occupied) {
        const hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Availability for ${DateFormat.MMMd().format(_selectedDay)}',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.blue800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: hours.map((h) {
                    final slotStart = '${h.toString().padLeft(2, '0')}:00';
                    final slotEnd = h < 23 ? '${(h + 1).toString().padLeft(2, '0')}:00' : '23:00';
                    final isBooked = _slotOverlaps(slotStart, slotEnd, occupied);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isBooked ? AppColors.rejected.withOpacity(0.15) : AppColors.approved.withOpacity(0.15),
                        borderRadius: AppRadius.radiusXs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBooked ? Icons.block : Icons.check_circle,
                            size: 14,
                            color: isBooked ? AppColors.rejected : AppColors.approved,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('$slotStart', style: AppTypography.labelSmall),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))))),
      error: (e, _) => Card(child: Padding(padding: AppSpacing.paddingMd, child: Text('Could not load availability: $e', style: AppTypography.bodySmall))),
    );
  }

  Widget _buildCalendar() {
    return Card(
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        selectedDayPredicate: (day) =>
            day.year == _selectedDay.year &&
            day.month == _selectedDay.month &&
            day.day == _selectedDay.day,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  Widget _buildTimePickers(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final t =
                  await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (t != null) setState(() => _startTime = t);
            },
            child: Text(
              _startTime == null ? 'Start time' : _startTime!.format(context),
            ),
          ),
        ),
        AppSpacing.gapSmH,
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now().replacing(
                  hour: (TimeOfDay.now().hour + 1) % 24,
                ),
              );
              if (t != null) setState(() => _endTime = t);
            },
            child: Text(
              _endTime == null ? 'End time' : _endTime!.format(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsSection(List<Reservation> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Your reservations',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.blue800,
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty ? _buildEmptyReservations() : _buildReservationsList(list),
        ),
      ],
    );
  }

  Widget _buildEmptyReservations() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No reservations yet',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.neutral700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Select a court, date & time above,\nthen tap "Create reservation"',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationsList(List<Reservation> list) {
    final dateFmt = DateFormat.yMMMd();
    return ListView.builder(
      padding: AppSpacing.paddingMd,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            title: Text(
              '${dateFmt.format(r.date)} ${r.startTime} - ${r.endTime}',
              style: AppTypography.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.eventType} • Players: ${r.playersCount}',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusColor(r.status).withOpacity(0.15),
                    borderRadius: AppRadius.radiusXs,
                  ),
                  child: Text(
                    r.status,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.statusColor(r.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.status == 'PENDING')
                  IconButton(
                    icon: const Icon(Icons.edit),
                    color: AppColors.blue600,
                    onPressed: () => _editReservationDialog(r),
                  ),
                if (r.status == 'PENDING')
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    color: AppColors.orange600,
                    onPressed: () => _cancelReservation(r),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createReservation() async {
    final court = _selectedCourt;
    if (court == null ||
        _startTime == null ||
        _endTime == null ||
        _eventCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    setState(() {
      _booking = true;
      _error = null;
    });

    final repo = ref.read(reservationsRepositoryProvider);
    final start = _startTime!;
    final end = _endTime!;
    final startStr = _formatTime(start);
    final endStr = _formatTime(end);
    final players = int.tryParse(_playersCtrl.text.trim()) ?? 1;

    try {
      await repo.createReservation(
        courtId: court.id,
        date: _selectedDay,
        startTime: startStr,
        endTime: endStr,
        eventType: _eventCtrl.text.trim(),
        playersCount: players,
      );
      ref.invalidate(myReservationsProvider);
      ref.invalidate(occupiedSlotsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation submitted. It is pending approval.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already') ||
          msg.contains('booked') ||
          msg.contains('overlap') ||
          msg.contains('409')) {
        setState(() => _error = 'This time slot is already booked. Choose another.');
      } else {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _booking = false);
      }
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _cancelReservation(Reservation r) async {
    final repo = ref.read(reservationsRepositoryProvider);
    await repo.cancelReservation(r.id);
    ref.invalidate(myReservationsProvider);
  }

  Future<void> _editReservationDialog(Reservation r) async {
    final eventCtrl = TextEditingController(text: r.eventType);
    final playersCtrl = TextEditingController(text: r.playersCount.toString());
    DateTime selectedDate = r.date;
    TimeOfDay start = TimeOfDay(
      hour: int.parse(r.startTime.split(':')[0]),
      minute: int.parse(r.startTime.split(':')[1]),
    );
    TimeOfDay end = TimeOfDay(
      hour: int.parse(r.endTime.split(':')[0]),
      minute: int.parse(r.endTime.split(':')[1]),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit reservation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    selectedDate = d;
                  }
                },
                child: Text(DateFormat.yMMMd().format(selectedDate)),
              ),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: start,
                  );
                  if (t != null) start = t;
                },
                child: Text('Start: ${start.format(context)}'),
              ),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: end,
                  );
                  if (t != null) end = t;
                },
                child: Text('End: ${end.format(context)}'),
              ),
              TextField(
                controller: eventCtrl,
                decoration: const InputDecoration(labelText: 'Event type'),
              ),
              TextField(
                controller: playersCtrl,
                decoration:
                    const InputDecoration(labelText: 'Players count'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(reservationsRepositoryProvider);
              await repo.updateReservation(
                id: r.id,
                date: selectedDate,
                startTime: _formatTime(start),
                endTime: _formatTime(end),
                eventType: eventCtrl.text.trim(),
                playersCount:
                    int.tryParse(playersCtrl.text.trim()) ?? r.playersCount,
              );
              if (context.mounted) Navigator.pop(context);
              ref.invalidate(myReservationsProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

