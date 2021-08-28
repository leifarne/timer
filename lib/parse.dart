import 'package:intl/intl.dart';
import 'package:string_scanner/string_scanner.dart';

final dateFormat = DateFormat('dd.MM');
final timeFormat = DateFormat.Hm();

class QuickEntryModel {
  DateTime? from;
  Duration? duration;
  String? message;

  QuickEntryModel({this.from, this.duration});
}

QuickEntryModel parseQuickType(String? s) {
  // Quick type overrides the other individual fields. If focus in Quick type field.
  // Collect string variables first. Then parse as DateTime and update model object.

  // if empty - use other fields, ie. no Model object == null
  // if 1 field & number => duration. Read From field
  // if 1 field & text (ie. not number) => message.
  // if 2 fields & both numbers => from and duration. Overwrite From and Duration fields
  // if 2 fields & number & text => duration and message. Read From field. Overwrite Duration.
  // if 3 fields & number, number, text => from, duration, message. Overwrite From, Duration.
  // else ERROR.
  QuickEntryModel quickEntry = QuickEntryModel();
  String? from;
  String? duration;
  String? message;

  if (s == null) {
    return quickEntry;
  }

  s = s.trim();
  var scanner = StringScanner(s);

  // TODO: Use precise #occurences, f.ex. {1,2}
  // Determine which fields are present in the string.
  RegExp rxfdm = RegExp(r'(\d+(?::\d+)*)\s(\d+(?:\.\d*)*)\s(.+)');
  RegExp rxfd = RegExp(r'(\d+(?::\d+)*)\s(\d+(?:\.\d*)*)');
  RegExp rxdm = RegExp(r'(\d+(?:\.\d*)*)\s(.+)');
  RegExp rxd = RegExp(r'(\d+(?:\.\d*)*)');
  RegExp rxm = RegExp(r'(.+)');

  bool fdm = scanner.matches(rxfdm);
  bool fd = scanner.matches(rxfd);
  bool dm = scanner.matches(rxdm);
  bool d = scanner.matches(rxd);
  bool m = scanner.matches(rxm);

  // Collect the strings from Quick Type.
  if (fdm) {
    scanner.expect(rxfdm);
    from = scanner.lastMatch?.group(1);
    duration = scanner.lastMatch?.group(2);
    message = scanner.lastMatch?.group(3);
  } else if (fd) {
    scanner.expect(rxfd);
    from = scanner.lastMatch?.group(1);
    duration = scanner.lastMatch?.group(2);
    message = null;
  } else if (dm) {
    scanner.expect(rxdm);
    from = null;
    duration = scanner.lastMatch?.group(1);
    message = scanner.lastMatch?.group(2);
  } else if (d) {
    scanner.expect(rxd);
    from = null;
    duration = scanner.lastMatch?.group(1);
    message = null;
  } else if (m) {
    scanner.expect(rxm);
    from = null;
    duration = null;
    message = scanner.lastMatch?.group(1);
  } else {
    from = null;
    duration = null;
    message = null;
  }

  // Parse and save to model. Defer to _onSave to collect other fields.
  // Use flags to make quick type override individual From and Duration fields.

  if (from != null) {
    quickEntry.from = parseTime(from);
  }
  if (duration != null) {
    quickEntry.duration = parseDuration(duration);
  }
  quickEntry.message = message;

  return quickEntry;
}

DateTime? parseDate(String? s) {
  if (s == null) return null;

  final now = DateTime.now();
  DateTime dt;
  try {
    dt = dateFormat.parse(s);
    dt = DateTime(now.year, dt.month, dt.day);
  } catch (FormatException) {
    dt = DateFormat('dd').parse(s);
    dt = DateTime(now.year, now.month, dt.day);
  }
  print('date = $dt');
  return dt;
}

bool isDate(String? s) {
  if (s == null) return false;

  // ignore: unused_local_variable
  DateTime dt;
  try {
    dt = dateFormat.parse(s);
  } catch (FormatException) {
    try {
      dt = DateFormat('dd').parse(s);
    } catch (FormatException) {
      return false;
    }
  }
  return true;
}

DateTime? parseTime(String? s) {
  if (s == null) return null;

  final now = DateTime.now();
  DateTime tm;
  try {
    tm = timeFormat.parse(s);
  } catch (FormatException) {
    try {
      tm = DateFormat('HH').parse(s);
    } catch (FormatException) {
      return null;
    }
  }
  tm = DateTime(now.year, now.month, now.day, tm.hour, tm.minute);
  print('time = $tm');
  return tm;
}

bool isTime(String? s) {
  if (s == null) return false;

  // ignore: unused_local_variable
  DateTime tm;
  try {
    tm = timeFormat.parse(s);
  } catch (FormatException) {
    try {
      tm = DateFormat('HH').parse(s);
    } catch (FormatException) {
      return false;
    }
  }
  return true;
}

Duration? parseDuration(String? s) {
  if (s == null || s.isEmpty) return null;

  try {
    double d = double.parse(s);
    final h = d.truncate();
    final m = (d.remainder(1) * 60).round();
    print('h = $h, m = $m');
    return Duration(hours: h, minutes: m);
  } catch (FormatException) {
    return null;
  }
}

bool isDuration(String? s) {
  if (s == null) return false;

  try {
    double.parse(s);
  } catch (FormatException) {
    return false;
  }
  return true;
}

/// Calculates week number from a date as per https://en.wikipedia.org/wiki/ISO_week_date#Calculation
int weekNumber(DateTime date) {
  int dayOfYear = int.parse(DateFormat("D").format(date));
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

String formatTime(DateTime? t) {
  return (t != null) ? timeFormat.format(t) : '';
}

String? formatDuration(Duration? duration) {
  if (duration == null) return null;
  double hours = duration.inMinutes / 60.0;
  return hours.toStringAsFixed(1);
}
