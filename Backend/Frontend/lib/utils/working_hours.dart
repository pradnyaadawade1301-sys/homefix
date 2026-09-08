/// Technician weekly working hours — parsing + display helpers.
///
/// Backend shape (JSONB column `working_hours`): an object keyed by lowercase
/// 3-letter weekday, each value either `{"open":"HH:MM","close":"HH:MM"}` or
/// `null` (not working that day). Times are 24-hour wall-clock in app-local /
/// IST. This is display-only — it never blocks booking.
library;

/// One day's open window. Times kept as raw "HH:MM" strings; use
/// [openLabel] / [closeLabel] for a friendly "9:00 AM".
class DayHours {
  final String open; // "HH:MM"
  final String close; // "HH:MM"

  const DayHours({required this.open, required this.close});

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
        open: (json['open'] as String?) ?? '09:00',
        close: (json['close'] as String?) ?? '18:00',
      );

  Map<String, dynamic> toJson() => {'open': open, 'close': close};

  int get openMinutes => _toMinutes(open);
  int get closeMinutes => _toMinutes(close);

  String get openLabel => formatHhmm(open);
  String get closeLabel => formatHhmm(close);
}

/// Ordered weekday keys, Monday first (matches the editor + most Indian
/// business-hours mental models).
const List<String> kWeekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const Map<String, String> kWeekdayLabels = {
  'mon': 'Monday',
  'tue': 'Tuesday',
  'wed': 'Wednesday',
  'thu': 'Thursday',
  'fri': 'Friday',
  'sat': 'Saturday',
  'sun': 'Sunday',
};

const Map<String, String> kWeekdayShort = {
  'mon': 'Mon',
  'tue': 'Tue',
  'wed': 'Wed',
  'thu': 'Thu',
  'fri': 'Fri',
  'sat': 'Sat',
  'sun': 'Sun',
};

/// DateTime.weekday is 1=Mon..7=Sun — maps straight onto [kWeekdayKeys].
String weekdayKeyFor(DateTime dt) => kWeekdayKeys[dt.weekday - 1];

int _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

/// "09:00" -> "9:00 AM", "18:30" -> "6:30 PM".
String formatHhmm(String hhmm) {
  final mins = _toMinutes(hhmm);
  final h24 = mins ~/ 60;
  final m = mins % 60;
  final period = h24 >= 12 ? 'PM' : 'AM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// Parses the backend `working_hours` object into a 7-entry map. Every key in
/// [kWeekdayKeys] is present; value is null when that day is off.
Map<String, DayHours?> parseWorkingHours(dynamic raw) {
  final out = <String, DayHours?>{for (final k in kWeekdayKeys) k: null};
  if (raw is Map) {
    for (final k in kWeekdayKeys) {
      final v = raw[k];
      if (v is Map) {
        out[k] = DayHours.fromJson(Map<String, dynamic>.from(v));
      }
    }
  }
  return out;
}

Map<String, dynamic> workingHoursToJson(Map<String, DayHours?> hours) => {
      for (final k in kWeekdayKeys) k: hours[k]?.toJson(),
    };

/// True if [hours] has at least one working day configured.
bool hasAnyWorkingDay(Map<String, DayHours?> hours) =>
    hours.values.any((d) => d != null);

/// Whether the technician is within their working window right now.
bool isOpenNow(Map<String, DayHours?> hours, [DateTime? now]) {
  final t = now ?? DateTime.now();
  final today = hours[weekdayKeyFor(t)];
  if (today == null) return false;
  final mins = t.hour * 60 + t.minute;
  return mins >= today.openMinutes && mins < today.closeMinutes;
}

/// A short label for when the technician next opens, e.g. "Opens Mon 9:00 AM"
/// or "Opens at 9:00 AM" (later today). Returns null if no working days at all.
String? nextOpenLabel(Map<String, DayHours?> hours, [DateTime? now]) {
  if (!hasAnyWorkingDay(hours)) return null;
  final t = now ?? DateTime.now();
  final nowMins = t.hour * 60 + t.minute;

  for (var offset = 0; offset < 8; offset++) {
    final day = t.add(Duration(days: offset));
    final win = hours[weekdayKeyFor(day)];
    if (win == null) continue;
    if (offset == 0 && nowMins >= win.openMinutes) continue; // already past today's open
    if (offset == 0) return 'Opens at ${win.openLabel}';
    if (offset == 1) return 'Opens tomorrow ${win.openLabel}';
    return 'Opens ${kWeekdayShort[weekdayKeyFor(day)]} ${win.openLabel}';
  }
  return null;
}

/// One-line summary for a card, e.g. "Mon–Sat · 9:00 AM–6:00 PM" when every
/// working day shares the same window, otherwise "Varies by day".
String workingHoursSummary(Map<String, DayHours?> hours) {
  final working = kWeekdayKeys.where((k) => hours[k] != null).toList();
  if (working.isEmpty) return 'Hours not set';

  final first = hours[working.first]!;
  final sameWindow = working.every((k) =>
      hours[k]!.open == first.open && hours[k]!.close == first.close);
  if (!sameWindow) return 'Varies by day';

  // Collapse contiguous runs of weekdays into "Mon–Sat" style ranges.
  final buf = <String>[];
  var runStart = working.first;
  var prevIdx = kWeekdayKeys.indexOf(working.first);
  for (var i = 1; i <= working.length; i++) {
    final curIdx = i < working.length ? kWeekdayKeys.indexOf(working[i]) : -99;
    if (curIdx == prevIdx + 1) {
      prevIdx = curIdx;
      continue;
    }
    final runEnd = kWeekdayKeys[prevIdx];
    buf.add(runStart == runEnd
        ? kWeekdayShort[runStart]!
        : '${kWeekdayShort[runStart]}–${kWeekdayShort[runEnd]}');
    if (i < working.length) {
      runStart = working[i];
      prevIdx = curIdx;
    }
  }
  return '${buf.join(', ')} · ${first.openLabel}–${first.closeLabel}';
}
