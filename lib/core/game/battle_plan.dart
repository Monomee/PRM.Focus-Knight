import 'economy.dart';

/// What the user picks in the setup sheet before a battle.
class BattlePlan {
  BattlePlan({
    required this.task,
    required this.focusMinutes,
    required this.restMinutes,
    required this.sessions,
    required this.longBreakEvery,
  });

  String task;
  int focusMinutes;
  int restMinutes;
  int sessions;

  /// 0 = no long breaks.
  int longBreakEvery;

  static BattlePlan get defaults =>
      BattlePlan(task: '', focusMinutes: 25, restMinutes: 5, sessions: 1, longBreakEvery: 0);

  Map<String, dynamic> toJson() => {
        'task': task,
        'focus': focusMinutes,
        'rest': restMinutes,
        'sessions': sessions,
        'longEvery': longBreakEvery,
      };

  factory BattlePlan.fromJson(Map<String, dynamic> j) => BattlePlan(
        task: j['task'] as String? ?? '',
        focusMinutes: j['focus'] as int? ?? 25,
        restMinutes: j['rest'] as int? ?? 5,
        sessions: j['sessions'] as int? ?? 1,
        longBreakEvery: j['longEvery'] as int? ?? 0,
      );
}

int clampFocusMinutes(String input) => (int.tryParse(input.trim()) ?? 25).clamp(1, 180);

int clampRestMinutes(String input) => (int.tryParse(input.trim()) ?? 5).clamp(1, 60);

List<({bool focus, bool longRest, int minutes})> planTimeline(BattlePlan p, {int longRestMinutes = 15}) => [
      for (var i = 1; i <= p.sessions; i++) ...[
        (focus: true, longRest: false, minutes: p.focusMinutes),
        if (i < p.sessions)
          p.longBreakEvery > 0 && i % p.longBreakEvery == 0
              ? (focus: false, longRest: true, minutes: longRestMinutes)
              : (focus: false, longRest: false, minutes: p.restMinutes),
      ],
    ];

DateTime planEndTime(BattlePlan p, DateTime start, {int longRestMinutes = 15}) => start.add(Duration(
    minutes: planTimeline(p, longRestMinutes: longRestMinutes).fold(0, (sum, s) => sum + s.minutes)));

int planCoins(BattlePlan p, int barracksLevel) =>
    p.sessions * sessionReward(focusMinutes: p.focusMinutes, barracksLevel: barracksLevel).coins;
