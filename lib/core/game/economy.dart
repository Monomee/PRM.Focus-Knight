const int kHeroMaxHp = 100;
const int kPenaltyHp = 25;
const int kDistractionTax = 15;
const int kTaxIntervalSeconds = 30;
const int kMaxPauseSeconds = 300;

double durationMultiplier(int focusMinutes) {
  if (focusMinutes >= 50) return 1.5;
  if (focusMinutes >= 25) return 1.2;
  return 1.0;
}

/// Coin/Log earned by one completed focus session.
({int coins, int logs}) sessionReward({required int focusMinutes, int barracksLevel = 0}) => (
      coins: (focusMinutes * durationMultiplier(focusMinutes) * (1 + 0.1 * barracksLevel)).round(),
      logs: (focusMinutes * 0.5).floor(),
    );
