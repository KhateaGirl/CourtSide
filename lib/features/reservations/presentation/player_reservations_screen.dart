import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/slot_utils.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../auth/domain/auth_providers.dart';
import '../../categories/domain/categories_providers.dart';
import '../../categories/data/category_model.dart';
import '../../courts/domain/courts_providers.dart';
import '../domain/reservations_providers.dart';
import '../../courts/data/court_model.dart';
import '../../reservation_change/data/reservation_change_request_model.dart';
import '../../reservation_change/domain/reservation_change_providers.dart';
import '../../reservation_change/presentation/widgets/reservation_change_modal.dart';
import '../data/reservation_model.dart';

class PlayerReservationsScreen extends ConsumerStatefulWidget {
  const PlayerReservationsScreen({super.key});

  @override
  ConsumerState<PlayerReservationsScreen> createState() =>
      _PlayerReservationsScreenState();
}

class _PlayerReservationsScreenState
    extends ConsumerState<PlayerReservationsScreen> {
  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
  static DateTime get _lastDay => DateTime(_today.year + 1, _today.month, _today.day);

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = _today;
    _selectedDay = _today;
  }
  Court? _singleCourt;
  Category? _selectedCategory;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _eventCtrl = TextEditingController();
  final _playersCtrl = TextEditingController(text: '10');
  bool _booking = false;
  String? _error;
  /// Status filter for reservations list: null or 'ALL' = all, else PENDING, APPROVED, REJECTED, CANCELLED
  String? _reservationStatusFilter;
  bool _calendarExpanded = true;

  static const double _wideLayoutBreakpoint = 600;

  Widget _buildFormSection(WidgetRef ref) {
    final courtsAsync = ref.watch(courtsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final padding = MediaQuery.sizeOf(context).width < 400 ? AppSpacing.paddingSm : AppSpacing.paddingMd;
    return ListView(
      shrinkWrap: true,
      padding: padding,
      children: [
        courtsAsync.when(
          data: (courts) {
            _singleCourt ??= courts.isNotEmpty ? courts.first : null;
            if (courts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'No venue configured. Add a court in Admin.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                ),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, st) => Text('Error loading venue: $e'),
        ),
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              if (_selectedCategory != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedCategory = null);
                });
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'No categories. Add categories in Admin.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                ),
              );
            }
            // Use the category *from the current list* (same instance as an item) so DropdownButton finds exactly one match.
            // After an admin update, _selectedCategory is a stale instance; matching by id gives us the list instance.
            Category effectiveValue;
            Category? match;
            if (_selectedCategory != null) {
              for (final c in categories) {
                if (c.id == _selectedCategory!.id) {
                  match = c;
                  break;
                }
              }
            }
            if (match != null) {
              effectiveValue = match;
            } else {
              effectiveValue = categories.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedCategory = categories.first);
              });
            }
            return DropdownButtonFormField<Category>(
              value: effectiveValue,
              isExpanded: true,
              items: categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedCategory = v;
                _startTime = null;
                _endTime = null;
                _error = null;
              }),
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: Responsive.isNarrow(context)
                    ? 'e.g. Basketball, Volleyball'
                    : 'Basketball, Volleyball, etc. — one slot per time for the court',
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, st) => Text('Error loading categories: $e'),
        ),
        AppSpacing.gapMdV,
        _buildCalendar(),
        AppSpacing.gapMdV,
        _buildAvailabilitySection(ref),
        AppSpacing.gapMdV,
        _buildTimePickers(context, ref),
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
          onPressed: _booking ? null : _confirmCreateReservation,
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

    // Realtime subscription lives in myReservationsProvider; list updates when admin approves/rejects.

    final profileAsync = ref.watch(currentUserProfileProvider);
    final role = profileAsync.valueOrNull?['role']?.toString().toLowerCase();
    final isAdmin = role == 'admin';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: GradientAppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('My Reservations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              if (isAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Admin', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
        ),  // FittedBox
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.dashboard, size: 20, color: Colors.white),
              label: const Text('Admin', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (mounted) context.go('/login');
            },
          ),
          const AppBarThemeToggle(),
        ],
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
        child: useWideLayout
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
                    data: (res) => _buildReservationsSection(res, ref),
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
                    data: (res) => _buildReservationsSection(res, ref),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
      ),
    );
  }


  Widget _buildAvailabilitySection(WidgetRef ref) {
    final court = _singleCourt;
    if (court == null) return const SizedBox.shrink();
    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupiedAsync = ref.watch(occupiedSlotsProvider((courtId: court.id, date: dateKey)));
    return occupiedAsync.when(
      data: (occupied) {
        const hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
        return GlassCard(
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
                    final isBooked = slotOverlaps(slotStart, slotEnd, occupied);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isBooked ? AppColors.rejected.withOpacity(0.2) : AppColors.approved.withOpacity(0.2),
                        borderRadius: AppRadius.radiusXs,
                        border: Border.all(
                          color: isBooked ? AppColors.rejected.withOpacity(0.5) : AppColors.approved.withOpacity(0.5),
                          width: 1,
                        ),
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
        );
      },
      loading: () => const GlassCard(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (e, _) => GlassCard(padding: AppSpacing.paddingMd, child: Text('Could not load availability: $e', style: AppTypography.bodySmall)),
    );
  }

  Widget _buildCalendar() {
    final first = _today;
    final last = _lastDay;
    DateTime clampDay(DateTime d) {
      if (d.isBefore(first)) return first;
      if (d.isAfter(last)) return last;
      return DateTime(d.year, d.month, d.day);
    }
    final focused = clampDay(_focusedDay);
    final selected = clampDay(_selectedDay);
    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: AppColors.blue600),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Select date',
                  style: AppTypography.titleSmall,
                ),
              ),
              IconButton(
                icon: Icon(
                  _calendarExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                tooltip: _calendarExpanded ? 'Hide calendar' : 'Show calendar',
                onPressed: () {
                  setState(() {
                    _calendarExpanded = !_calendarExpanded;
                  });
                },
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _calendarExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: TableCalendar(
              firstDay: first,
              lastDay: last,
              focusedDay: focused,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) =>
                  day.year == selected.year &&
                  day.month == selected.month &&
                  day.day == selected.day,
              enabledDayPredicate: (day) => !day.isBefore(first),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = DateTime(
                      selectedDay.year, selectedDay.month, selectedDay.day);
                  _focusedDay = DateTime(
                      focusedDay.year, focusedDay.month, focusedDay.day);
                  _startTime = null;
                  _endTime = null;
                  _error = null;
                });
              },
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Hours we allow for booking (whole-hour slots).
  static const List<int> _bookingHours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];

  Widget _buildTimePickers(BuildContext context, WidgetRef ref) {
    final court = _singleCourt;
    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final isPast = _selectedDay.isBefore(_today);
    if (court == null || isPast) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          court == null ? 'Venue not loaded' : 'Select a date from the calendar',
          style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
        ),
      );
    }

    final occupiedAsync = ref.watch(occupiedSlotsProvider((courtId: court.id, date: dateKey)));
    return occupiedAsync.when(
      data: (occupied) {
        final availableStarts = <int>[];
        for (final h in _bookingHours) {
          final start = '${h.toString().padLeft(2, '0')}:00';
          final end = h < 23 ? '${(h + 1).toString().padLeft(2, '0')}:00' : '23:00';
          if (!slotOverlaps(start, end, occupied)) availableStarts.add(h);
        }

        final startHour = _startTime?.hour;
        final availableEnds = <int>[];
        if (startHour != null) {
          final startStr = _formatTime(_startTime!);
          for (var h = startHour + 1; h <= 23; h++) {
            final endStr = '${h.toString().padLeft(2, '0')}:00';
            if (!slotOverlaps(startStr, endStr, occupied)) availableEnds.add(h);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (availableStarts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'No available slots for this date. Pick another day.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.rejected),
                ),
              )
            else ...[
              DropdownButtonFormField<int>(
                value: startHour != null && availableStarts.contains(startHour) ? startHour : null,
                decoration: const InputDecoration(
                  labelText: 'Start time',
                  hintText: 'Choose available start',
                ),
                items: availableStarts
                    .map((h) => DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ))
                    .toList(),
                onChanged: (h) {
                  if (h == null) return;
                  final ends = availableEndsFor(occupied, h);
                  setState(() {
                    _startTime = TimeOfDay(hour: h, minute: 0);
                    _endTime = ends.isNotEmpty ? TimeOfDay(hour: ends.first, minute: 0) : null;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                value: startHour != null && _endTime != null && availableEndsFor(occupied, startHour).contains(_endTime!.hour) ? _endTime!.hour : null,
                decoration: const InputDecoration(
                  labelText: 'End time',
                  hintText: 'Choose end time',
                ),
                items: startHour == null
                    ? <DropdownMenuItem<int>>[]
                    : availableEndsFor(occupied, startHour)
                        .map((h) => DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            ))
                        .toList(),
                onChanged: startHour == null ? null : (h) {
                  if (h == null) return;
                  setState(() {
                    _endTime = TimeOfDay(hour: h, minute: 0);
                    _error = null;
                  });
                },
              ),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('Could not load slots: $e', style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
      ),
    );
  }

  List<int> availableEndsFor(List<({String start, String end})> occupied, int startHour) {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    final ends = <int>[];
    for (var h = startHour + 1; h <= 23; h++) {
      final endStr = '${h.toString().padLeft(2, '0')}:00';
      if (!slotOverlaps(startStr, endStr, occupied)) ends.add(h);
    }
    return ends;
  }

  static const List<String> _statusFilterOptions = [
    'ALL',
    'PENDING',
    'APPROVED',
    'REJECTED',
    'CANCELLED',
    'ADMIN',
  ];

  Widget _buildReservationsSection(List<Reservation> list, WidgetRef ref) {
    final filtered = _reservationStatusFilter == null ||
            _reservationStatusFilter == 'ALL'
        ? list
        : list.where((r) => r.status == _reservationStatusFilter).toList();

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilterOptions.map((status) {
                      final isSelected = (_reservationStatusFilter == null && status == 'ALL') ||
                          _reservationStatusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: Text(
                            status == 'ALL' ? 'All' : status.toLowerCase(),
                            style: AppTypography.labelSmall,
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _reservationStatusFilter = status == 'ALL' ? null : status;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh list',
                onPressed: () {
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(occupiedSlotsProvider);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filtered.isEmpty
              ? (list.isEmpty
                  ? _buildEmptyReservations()
                  : _buildEmptyFilteredMessage())
              : _buildReservationsList(filtered, ref),
        ),
      ],
    );
  }

  Widget _buildEmptyReservations() {
    return const EmptyState(
      icon: Icons.event_available_rounded,
      title: 'No reservations yet',
      subtitle: 'Select a category, date & time above, then tap "Create reservation".',
    );
  }

  Widget _buildEmptyFilteredMessage() {
    return EmptyState(
      icon: Icons.filter_list_rounded,
      title: 'No reservations for this status',
      subtitle: 'Try another filter or create a new reservation.',
    );
  }

  Widget _buildReservationsList(List<Reservation> list, WidgetRef ref) {
    final dateFmt = DateFormat.yMMMd();
    final pendingAsync = ref.watch(myPendingChangeRequestsProvider);
    return pendingAsync.when(
      data: (pendingRequests) {
        return ListView.builder(
          padding: AppSpacing.paddingMd,
          itemCount: list.length,
          itemBuilder: (context, index) {
            final r = list[index];
            final matching = pendingRequests.where((req) => req.reservationId == r.id).toList();
            final request = matching.isNotEmpty ? matching.first : null;
            final hasChangeRequest = request != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasChangeRequest)
                  _ChangeRequestBanner(
                    reservation: r,
                    request: request,
                  ),
                GlassCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      '${dateFmt.format(r.date)} ${r.startTime} - ${r.endTime}',
                      style: AppTypography.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${r.eventType} • Players: ${r.playersCount}',
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    trailing: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (r.status == 'PENDING' || r.status == 'APPROVED')
                          IconButton(
                            icon: Icon(r.status == 'APPROVED' ? Icons.schedule : Icons.edit),
                            tooltip: r.status == 'APPROVED' ? 'Reschedule' : 'Edit',
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.cyan400 : AppColors.blue600,
                            onPressed: () => _editReservationDialog(r),
                          ),
                        if (r.status == 'PENDING')
                          IconButton(
                            icon: const Icon(Icons.cancel),
                            color: AppColors.orange600,
                            onPressed: () => _confirmCancelReservation(r),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => ListView.builder(
        padding: AppSpacing.paddingMd,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final r = list[index];
          final dateFmt = DateFormat.yMMMd();
          return GlassCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text('${dateFmt.format(r.date)} ${r.startTime} - ${r.endTime}', style: AppTypography.titleMedium),
              subtitle: Text('${r.eventType} • ${r.status}', style: AppTypography.bodySmall),
            ),
          );
        },
      ),
      error: (_, __) => ListView.builder(
        padding: AppSpacing.paddingMd,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final r = list[index];
          final dateFmt = DateFormat.yMMMd();
          return GlassCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text('${dateFmt.format(r.date)} ${r.startTime} - ${r.endTime}', style: AppTypography.titleMedium),
              subtitle: Text('${r.eventType} • ${r.status}', style: AppTypography.bodySmall),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createReservation() async {
    final court = _singleCourt;
    final category = _selectedCategory;
    if (court == null ||
        category == null ||
        _startTime == null ||
        _endTime == null ||
        _eventCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill category, date, time and event type.');
      return;
    }
    final startStr = _formatTime(_startTime!);
    final endStr = _formatTime(_endTime!);
    if (startStr.compareTo(endStr) >= 0) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupied = await ref.read(occupiedSlotsProvider((courtId: court.id, date: dateKey)).future);
    if (slotOverlaps(startStr, endStr, occupied)) {
      setState(() => _error = 'This slot was taken. Please choose another time.');
      return;
    }
    setState(() {
      _booking = true;
      _error = null;
    });

    final service = ref.read(reservationServiceProvider);
    final players = int.tryParse(_playersCtrl.text.trim()) ?? 1;

    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      final createAsAdmin = profile?['role']?.toString().trim().toLowerCase() == 'admin';
      await service.createReservation(
        courtId: court.id,
        categoryId: category.id,
        date: _selectedDay,
        startTime: startStr,
        endTime: endStr,
        eventType: _eventCtrl.text.trim(),
        playersCount: players,
        createAsAdmin: createAsAdmin,
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

  bool _validateSlotWithOccupied(List<({String start, String end})> occupied) {
    if (_startTime == null || _endTime == null) return false;
    final startStr = _formatTime(_startTime!);
    final endStr = _formatTime(_endTime!);
    if (startStr.compareTo(endStr) >= 0) return false;
    return !slotOverlaps(startStr, endStr, occupied);
  }

  Future<void> _confirmCreateReservation() async {
    final court = _singleCourt;
    final category = _selectedCategory;
    if (court == null || category == null || _startTime == null || _endTime == null || _eventCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill category, date, start time, end time and event type.');
      return;
    }
    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupied = await ref.read(occupiedSlotsProvider((courtId: court.id, date: dateKey)).future);
    if (!_validateSlotWithOccupied(occupied)) {
      setState(() => _error = 'This slot is no longer available. Please pick another time.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Submit reservation?',
      message: 'Your request will be sent for approval. You\'ll be notified when it\'s confirmed.',
      confirmLabel: 'Yes, submit',
      cancelLabel: 'Cancel',
      icon: Icons.event_available_rounded,
    );
    if (!confirmed || !mounted) return;
    await _createReservation();
  }

  Future<void> _confirmCancelReservation(Reservation r) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel this reservation?',
      message: 'This reservation will be cancelled. The slot may become available for others.',
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep it',
      isDanger: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed || !mounted) return;
    await _cancelReservation(r);
  }

  Future<void> _cancelReservation(Reservation r) async {
    final repo = ref.read(reservationsRepositoryProvider);
    await repo.cancelReservation(r.id);
    ref.invalidate(myReservationsProvider);
    ref.invalidate(occupiedSlotsProvider);
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

    final isReschedule = r.status == 'APPROVED';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isReschedule ? 'Reschedule reservation' : 'Edit reservation'),
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
              final confirmed = await ConfirmDialog.show(
                context,
                title: isReschedule ? 'Submit reschedule?' : 'Save changes?',
                message: isReschedule
                    ? 'Your reschedule will need admin approval again. Date, time and details will be updated.'
                    : 'Reservation date, time and details will be updated.',
                confirmLabel: isReschedule ? 'Yes, submit' : 'Yes, save',
                cancelLabel: 'Cancel',
                icon: Icons.save_outlined,
              );
              if (!confirmed || !context.mounted) return;
              final service = ref.read(reservationServiceProvider);
              try {
                await service.updateReservation(
                  id: r.id,
                  courtId: r.courtId,
                  date: selectedDate,
                  startTime: _formatTime(start),
                  endTime: _formatTime(end),
                  eventType: eventCtrl.text.trim(),
                  playersCount:
                      int.tryParse(playersCtrl.text.trim()) ?? r.playersCount,
                  currentStatus: r.status,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isReschedule
                          ? 'Reschedule submitted. Pending admin approval.'
                          : 'Reservation updated.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                ref.invalidate(myReservationsProvider);
                ref.invalidate(occupiedSlotsProvider);
              } catch (e) {
                if (context.mounted) {
                  final msg = e.toString().toLowerCase();
                  final isSlot = msg.contains('already') ||
                      msg.contains('booked') ||
                      msg.contains('overlap');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSlot
                          ? 'That time slot is already booked. Choose another.'
                          : e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ChangeRequestBanner extends ConsumerWidget {
  const _ChangeRequestBanner({
    required this.reservation,
    required this.request,
  });

  final Reservation reservation;
  final ReservationChangeRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = request.isExpired || request.expiresAt.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.blue600.withOpacity(0.12),
        borderRadius: AppRadius.radiusXs,
        border: Border.all(color: AppColors.blue600.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reservation Change Requested',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.blue800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Admin proposed a new schedule: ${request.newStartTime} – ${request.newEndTime}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: expired
                    ? null
                    : () => ReservationChangeModal.show(
                          context,
                          request: request,
                          reservationDate: reservation.date,
                          onAccept: () => _accept(ref, context),
                          onReject: () => _reject(ref, context),
                        ),
                child: const Text('View details'),
              ),
              if (!expired) ...[
                TextButton(
                  onPressed: () => _reject(ref, context),
                  child: const Text('Reject', style: TextStyle(color: AppColors.rejected)),
                ),
                ElevatedButton(
                  onPressed: () => _accept(ref, context),
                  child: const Text('Accept'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(WidgetRef ref, BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await ref.read(reservationChangeServiceProvider).acceptChangeRequest(
            changeRequestId: request.id,
            userId: uid,
            notificationId: null,
          );
      ref.invalidate(myReservationsProvider);
      ref.invalidate(myPendingChangeRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change accepted. Reservation updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _reject(WidgetRef ref, BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await ref.read(reservationChangeServiceProvider).rejectChangeRequest(
            changeRequestId: request.id,
            userId: uid,
            notificationId: null,
          );
      ref.invalidate(myReservationsProvider);
      ref.invalidate(myPendingChangeRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change rejected. Reservation unchanged.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

