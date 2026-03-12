/// Shared reservation/slot helpers. Avoid duplicate logic across UI and services.
/// Booking overlap rule per spec: start_time < existing_end_time AND end_time > existing_start_time.

/// Returns true if [slotStart, slotEnd) overlaps any range in [occupied].
bool slotOverlaps(
  String slotStart,
  String slotEnd,
  List<({String start, String end})> occupied,
) {
  for (final range in occupied) {
    if (slotStart.compareTo(range.end) < 0 &&
        slotEnd.compareTo(range.start) > 0) {
      return true;
    }
  }
  return false;
}

/// Format time as "HH:mm" for display and RPC (e.g. "09:00").
String formatTimeAsHHmm(int hour, [int minute = 0]) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
