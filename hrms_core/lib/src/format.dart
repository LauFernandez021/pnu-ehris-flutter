const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// yyyy-MM-dd, the format the API expects.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String dayLabel(double d) => d == d.roundToDouble() ? '${d.toInt()}' : '$d';

String daysText(double d) => '${dayLabel(d)} ${d == 1 ? 'day' : 'days'}';

/// Monday to Friday, both ends included. Matches the server's count.
int workingDays(DateTime start, DateTime end) {
  var count = 0;
  for (
    var d = DateTime(start.year, start.month, start.day);
    !d.isAfter(end);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
  }
  return count;
}

/// 24-hour "HH:mm" string the API expects.
String hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// "14:30" -> "2:30 PM"
String timeLabel(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${parts[1]} $suffix';
}

String attendanceStatusLabel(String status) => switch (status) {
  'present' => 'Present',
  'late' => 'Late',
  'absent' => 'Absent',
  'on_leave' => 'On leave',
  'not_started' => 'Not started',
  'day_off' => 'Day off',
  _ => status,
};
