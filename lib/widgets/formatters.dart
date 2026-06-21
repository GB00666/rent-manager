import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

  /// Formats e.g. 5500.0 -> "5,500" (no decimals, Indian grouping)
  static String rupeeAmount(num value) {
    return _inr.format(value.round());
  }

  /// Formats with the rupee symbol prefix: "₹5,500"
  static String rupee(num value) => '₹${rupeeAmount(value)}';

  static String monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  static String dayOrdinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  static String dateTime(DateTime dt) {
    return DateFormat("d MMM, h:mm a").format(dt);
  }
}
