import 'package:intl/intl.dart';

class DateFormatter {
  static String formatFull(DateTime date) {
    // Formato limpio y compacto en español: "29 ago 2026, 02:27 PM"
    return DateFormat("d 'de' MMMM, yyyy • h:mm a", 'es').format(date);
  }

  static String formatShort(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(date.year, date.month, date.day);

    if (recordDate == today) {
      return 'Hoy, ${DateFormat('h:mm a', 'es').format(date)}';
    } else if (recordDate == today.subtract(const Duration(days: 1))) {
      return 'Ayer, ${DateFormat('h:mm a', 'es').format(date)}';
    } else {
      return DateFormat("d MMM, h:mm a", 'es').format(date);
    }
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy', 'es').format(date);
  }
}
