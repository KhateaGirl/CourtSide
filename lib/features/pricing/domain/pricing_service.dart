import 'package:supabase_flutter/supabase_flutter.dart';

/// Dynamic pricing per spec: day rate 06:00–18:00, night rate 18:00–24:00.
/// Delegates to backend RPC for calculation.
class PricingService {
  final SupabaseClient _client;

  PricingService(this._client);

  /// Returns total price for the given date/time range. Backend applies day/night segments.
  Future<double> getBookingPrice({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final res = await _client.rpc(
      'calculate_booking_price',
      params: {
        'p_date': dateStr,
        'p_start': _normalizeTime(startTime),
        'p_end': _normalizeTime(endTime),
      },
    );
    return (res is num) ? res.toDouble() : 0.0;
  }

  static String _normalizeTime(String t) {
    final s = t.trim();
    if (s.length == 5 && s[2] == ':') return '$s:00';
    return s;
  }
}
