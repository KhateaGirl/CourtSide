import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/reservations_repository.dart';
import '../data/reservation_model.dart';

final reservationsRepositoryProvider =
    Provider<ReservationsRepository>((ref) {
  return ReservationsRepository(Supabase.instance.client);
});

final myReservationsProvider =
    FutureProvider.autoDispose<List<Reservation>>((ref) async {
  final repo = ref.read(reservationsRepositoryProvider);
  return repo.getMyReservations();
});

/// Occupied time slots for a court/date (for availability). Key: 'courtId|yyyy-MM-dd'.
final occupiedSlotsProvider = FutureProvider.autoDispose
    .family<List<({String start, String end})>, ({String courtId, String date})>((ref, key) async {
  final repo = ref.read(reservationsRepositoryProvider);
  return repo.getOccupiedSlots(
    key.courtId,
    DateTime.parse(key.date),
  );
});

