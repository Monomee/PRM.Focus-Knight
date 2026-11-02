import 'dart:math' as math;

typedef PlotPoint = ({double x, double y});
typedef SurvivalObservation = ({double minutes, bool event});
const slotEdges = [0, 5, 8, 11, 14, 17, 21, 24];
const slotLabels = [
  '00:00–05:00',
  '05:00–08:00',
  '08:00–11:00',
  '11:00–14:00',
  '14:00–17:00',
  '17:00–21:00',
  '21:00–24:00',
];
const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime nextDay(DateTime d, [int n = 1]) =>
    DateTime(d.year, d.month, d.day + n);

class DailyFocus {
  DailyFocus({
    this.seconds = 0,
    this.goalSeconds,
    this.completed = 0,
    this.incomplete = 0,
  });
  double seconds;
  int? goalSeconds;
  int completed;
  int incomplete;
  bool get achieved =>
      goalSeconds != null && goalSeconds! > 0 && seconds >= goalSeconds!;
  double? get progress => goalSeconds == null || goalSeconds! <= 0
      ? null
      : (seconds / goalSeconds!).clamp(0, 1);
  int get heatLevel => seconds <= 0
      ? 0
      : seconds < (goalSeconds ?? 3600) * 0.5
      ? 1
      : seconds < (goalSeconds ?? 3600)
      ? 2
      : 3;
}

({int current, int longest}) goalStreaks(
  Map<String, DailyFocus> days,
  DateTime now,
) {
  final achieved = days.entries
      .where((e) => e.value.achieved && e.key.compareTo(dateKey(now)) <= 0)
      .map((e) => e.key)
      .toSet();
  var current = 0, longest = 0, run = 0;
  DateTime? previous;
  for (final key in achieved.toList()..sort()) {
    final date = DateTime.parse(key);
    run = previous != null && dateKey(nextDay(previous)) == key ? run + 1 : 1;
    longest = math.max(longest, run);
    previous = date;
  }
  var cursor = dayOf(now);
  if ((days[dateKey(cursor)]?.goalSeconds ?? 0) <= 0) {
    return (current: 0, longest: longest);
  }
  if (!achieved.contains(dateKey(cursor))) cursor = nextDay(cursor, -1);
  while (achieved.contains(dateKey(cursor))) {
    current++;
    cursor = nextDay(cursor, -1);
  }
  return (current: current, longest: longest);
}

List<({DateTime date, int slot, double seconds})> splitInterval(
  DateTime start,
  DateTime end,
) {
  final slices = <({DateTime date, int slot, double seconds})>[];
  var cursor = start.toLocal();
  while (cursor.isBefore(end)) {
    final slot = slotEdges.indexWhere((h) => h > cursor.hour) - 1;
    // Elapsed-hour steps also handle repeated/skipped hours at DST transitions.
    final boundary = cursor.add(
      Duration(
        microseconds:
            Duration.microsecondsPerHour -
            cursor.minute * Duration.microsecondsPerMinute -
            cursor.second * Duration.microsecondsPerSecond -
            cursor.millisecond * 1000 -
            cursor.microsecond,
      ),
    );
    final stop = boundary.isBefore(end) ? boundary : end;
    slices.add((
      date: dayOf(cursor),
      slot: slot,
      seconds: stop.difference(cursor).inMicroseconds / 1e6,
    ));
    cursor = stop;
  }
  return slices;
}

double? distractionRate(int events, double seconds) =>
    seconds > 0 ? events * 3600 / seconds : null;

class SurvivalEstimate {
  SurvivalEstimate(this.points, this.median, this.count);
  final List<PlotPoint> points;
  final double? median;
  final int count;
  static SurvivalEstimate calculate(List<SurvivalObservation> input) {
    final rows =
        input.where((o) => o.minutes.isFinite && o.minutes >= 0).toList()
          ..sort((a, b) => a.minutes.compareTo(b.minutes));
    final points = <PlotPoint>[(x: 0, y: 1)];
    var risk = rows.length, survival = 1.0;
    double? median;
    var i = 0;
    while (i < rows.length) {
      final t = rows[i].minutes;
      var events = 0, total = 0;
      while (i < rows.length && rows[i].minutes == t) {
        if (rows[i].event) events++;
        total++;
        i++;
      }
      survival *= 1 - events / risk;
      points.add((x: t, y: survival));
      if (survival <= 0.5) median ??= t;
      risk -= total;
    }
    return SurvivalEstimate(points, median, rows.length);
  }
}

({double r, double slope, double intercept})? correlation(
  List<PlotPoint> points, {
  int minimum = 7,
}) {
  if (minimum < 3 ||
      points.length < minimum ||
      points.any((p) => !p.x.isFinite || !p.y.isFinite)) {
    return null;
  }
  final mx = points.fold<double>(0, (s, p) => s + p.x) / points.length;
  final my = points.fold<double>(0, (s, p) => s + p.y) / points.length;
  var xx = 0.0, yy = 0.0, xy = 0.0;
  for (final p in points) {
    xx += (p.x - mx) * (p.x - mx);
    yy += (p.y - my) * (p.y - my);
    xy += (p.x - mx) * (p.y - my);
  }
  if (xx <= 1e-12 || yy <= 1e-12) return null;
  final slope = xy / xx;
  return (
    r: (xy / math.sqrt(xx * yy)).clamp(-1, 1),
    slope: slope,
    intercept: my - slope * mx,
  );
}
