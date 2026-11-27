/// Shared period boundaries. Weeks start on Sunday (local time).
DateTime startOfDay(DateTime now) => DateTime(now.year, now.month, now.day);

DateTime startOfWeek(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday % 7));

DateTime endOfWeek(DateTime now) => startOfWeek(
  now,
).add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

DateTime startOfMonth(DateTime now) => DateTime(now.year, now.month, 1);

/// Start of the period containing [now]. Accepts budget periods
/// ('daily' | 'weekly' | 'monthly') and UI periods ('today' | 'this week' | 'month').
/// Unknown values fall back to the start of today.
DateTime periodStart(String period, DateTime now) {
  switch (period.toLowerCase()) {
    case 'weekly':
    case 'this week':
      return startOfWeek(now);
    case 'monthly':
    case 'month':
      return startOfMonth(now);
    default:
      return startOfDay(now);
  }
}
