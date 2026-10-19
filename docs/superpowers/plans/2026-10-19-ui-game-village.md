# FocusKnight – UI mới, Rank, Làng & Kinh tế · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thay game canvas vẽ tay bằng UI sprite Tiny Swords (không Canvas), làm dashboard phẳng 4 tab, thêm Rank/Nhân vật/Huy hiệu, Làng, kinh tế Coin/Log tạm giữ theo trận và hình phạt app blacklist.

**Architecture:** Luật game là hàm thuần trong `lib/core/game/` (dễ test). `PlayerState` (ChangeNotifier) giữ ví + lựa chọn + building, persist bằng SharedPreferences. `FocusSessionController` giữ trận (quỹ tạm giữ, HP, pause, nghỉ dài) và chỉ quyết toán khi xong trọn trận. `DistractionGuard` là state machine thuần, `main.dart` gọi `tick()` mỗi 2s. UI chỉ đọc state; animation sprite bằng widget `SpriteAnim` (ClipRect + Align + Image.asset).

**Tech Stack:** Flutter 3.47 / Dart 3.13, shared_preferences, flutter_overlay_window 0.5 (`shareData`/`overlayListener`), flutter_foreground_task, usage_stats. Không thêm package.

**Spec:** `docs/superpowers/specs/2026-10-19-ui-game-village-design.md`

## Global Constraints

- Không thêm dependency vào `pubspec.yaml`; font Pixelify Sans thêm như asset (`ui/fonts/PixelifySans.ttf`).
- Không dùng `CustomPainter`/`Canvas` cho đồ hoạ game.
- Mọi ảnh pixel: `filterQuality: FilterQuality.none`.
- Portrait-only, đích Android (thiết bị `R3CN90V2K3X`).
- Dashboard: nền `#0F131C`, card `#151A26`, viền 1.5px `#232A3B`, accent `#FFB300`, không gradient/glow/BoxShadow.
- Coin lưu ở key `fk_gold` (giữ dữ liệu cũ).
- Rank: Starter 0h · Gold 10h · Diamond 30h · Ruby 70h · Amethyst 150h; mở lần lượt Pawn · Lancer · Archer · Monk · Warrior.
- Thua/bỏ cuộc: mất toàn bộ Coin/Log **và** giờ của cả trận; chỉ ghi số lần xao nhãng.
- Phạt chỉ khi mở app blacklist: hết ân hạn → −25 HP (max 100) + overlay; mỗi 30s ở lại → −15 Coin quỹ tạm giữ (≥0); HP 0 → thua.
- Pause: 1 lần/phiên, tối đa 300s, tự chạy tiếp.
- Text UI bằng tiếng Việt.
- `flutter test` toàn bộ phải pass sau mỗi task; `flutter analyze` không có error.

## Review Focus

1. Nhập "Tùy…" phút = rỗng/0/chữ/999 → clamp 1–180 (tập trung) và 1–60 (nghỉ), không crash. → test ở Task 6.
2. `applyBlacklistPenalty()`/`applyDistractionTax()` gọi tiếp sau khi đã thua hoặc khi không focus → bỏ qua, không quyết toán hai lần. → test ở Task 4.
3. Xây building khi thiếu Coin/Log, nhân vật chưa mở, hoặc đã max cấp → trả `false`, ví không đổi. → test ở Task 3.
4. Vé giữ chuỗi: không cấp trước khi xây Kho lương, không cấp 2 lần trong cùng tuần, không bù ngày trước ngày xây. → test ở Task 3 & 9.
5. Bấm pause khi đang nghỉ hoặc lần thứ hai trong cùng phiên → bỏ qua; app ra nền khi đang pause vẫn bị guard phạt. → test ở Task 4 & 10.

---

### Task 1: Assets, font, `SpriteAnim` & `PixelIcon`

**Files:**
- Modify: `pubspec.yaml` (thêm `assets:` từng thư mục con của `ui/` – Flutter không đệ quy – và `fonts:` family `PixelifySans`)
- Create: `ui/fonts/PixelifySans.ttf` (tải từ `https://github.com/google/fonts/raw/main/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf`)
- Create: `lib/core/game/sprites.dart`
- Create: `lib/core/widgets/sprite_anim.dart`
- Test: `test/sprite_anim_test.dart`

**Interfaces:**
- Produces:
  - `class SpriteSheet { const SpriteSheet(this.asset, this.frames); final String asset; final int frames; }`
  - `class CharacterSprites { final SpriteSheet idle, run, attack; }`
  - `const Map<GameCharacter, CharacterSprites> characterSprites` – **Task 1 tạm khai báo `enum GameCharacter { pawn, lancer, archer, monk, warrior }` trong `lib/core/game/progression.dart`** (Task 2 bổ sung phần còn lại).
  - `const List<CharacterSprites> enemySprites` (torch, tnt, barrel), `const SpriteSheet deadSprite = SpriteSheet('ui/characters/Dead.png', 7)`
  - `SpriteAnim({required SpriteSheet sheet, required double size, bool flipX = false, bool playing = true, int fps = 10, bool loop = true, VoidCallback? onComplete})`
  - `PixelIcon(String name, {double size = 24})` → `Image.asset('ui/icons/$name.png')`
  - `const String kPixelFont = 'PixelifySans'`

Số frame (= width/height của sheet), dùng nguyên trong `sprites.dart`:

| Nhân vật | idle | run | attack |
|---|---|---|---|
| pawn | `Pawn_Idle Axe.png` 8 | `Pawn_Run Axe.png` 6 | `Pawn_Interact Axe.png` 6 |
| lancer | `Lancer_Idle.png` 12 | `Lancer_Run.png` 6 | `Lancer_Right_Attack.png` 3 |
| archer | `Archer_Idle.png` 6 | `Archer_Run.png` 4 | `Archer_Shoot.png` 8 |
| monk | `Idle.png` 6 | `Run.png` 4 | `Heal.png` 11 |
| warrior | `Warrior_Idle.png` 8 | `Warrior_Run.png` 6 | `Warrior_Attack1.png` 4 |
| torch / tnt (enemy) | 7 | 7 | 7 |
| barrel (enemy) | 6 | 6 | 6 |

- [ ] **Step 1: Write failing tests** `test/sprite_anim_test.dart`:
  - `characterSprites has an entry for every GameCharacter` → `expect(characterSprites.keys.toSet(), GameCharacter.values.toSet())`.
  - `SpriteAnim shows frame 0 then advances` → pump `SpriteAnim(sheet: SpriteSheet('ui/characters/player/warrior/Warrior_Idle.png', 8), size: 96)`; find the `Align` inside; `expect(align.alignment, const Alignment(-1, 0))`; `tester.pump(Duration(milliseconds: 100))`; expect `Alignment(-1 + 2/7, 0)`.
  - `SpriteAnim non-loop calls onComplete once` → frames 4, `loop: false`, pump 500ms, counter == 1.
- [ ] **Step 2:** `flutter test test/sprite_anim_test.dart` → FAIL (file không tồn tại).
- [ ] **Step 3: Implement.** `SpriteAnim`: `SizedBox(size×size)` → `ClipRect` → `OverflowBox(maxWidth: size*frames, maxHeight: size, alignment: Alignment(frames==1 ? 0 : -1 + 2*i/(frames-1), 0))` → `Image.asset(fit: BoxFit.fill, filterQuality: none)`; frame index từ `AnimationController(duration: frames/fps giây)` với `StepTween(0, frames-1)` (hoặc `(value*frames).floor().clamp`), lật bằng `Transform.flip(flipX:)`. Khai báo pubspec assets: `ui/buildings/enemy_building/`, `ui/buildings/player_building/`, `ui/characters/`, `ui/characters/enemy/{barrel,tnt,torch}/`, `ui/characters/player/{archer,lancer,monk,pawn,warrior}/`, `ui/icons/`, `ui/ranks/{archer,lancer,monk,pawn,warrior}/`, `ui/ribbons/`, `ui/scenes/`.
- [ ] **Step 4:** `flutter test` → PASS toàn bộ.
- [ ] **Step 5: Commit** `feat: add sprite assets, pixel font and SpriteAnim widget`

---

### Task 2: Luật game thuần – progression, economy, village

**Files:**
- Modify: `lib/core/game/progression.dart`
- Create: `lib/core/game/economy.dart`, `lib/core/game/village.dart`
- Test: `test/game_rules_test.dart`

**Interfaces:**
- Produces (`progression.dart`):
  - `enum Rank { starter, gold, diamond, ruby, amethyst }` với `int get thresholdHours` (0,10,30,70,150) và `String get label` ('Starter','Gold','Diamond','Ruby','Amethyst')
  - `Rank rankForSeconds(int totalFocusSeconds)`
  - `Rank? nextRank(Rank r)`
  - `GameCharacter.unlockRank` → `Rank.values[index]`; `String get label` ('Pawn','Lancer','Archer','Monk','Warrior')
  - `bool isCharacterUnlocked(GameCharacter c, Rank current)` = `c.index <= current.index`
  - `bool isBadgeUnlocked(GameCharacter c, Rank badge, Rank current)` = unlocked(c) && `badge.index <= current.index`
  - `String badgeAsset(GameCharacter c, Rank r)` = `'ui/ranks/${c.name}/${c.name}_${r.name}.png'`
- Produces (`economy.dart`):
  - `double durationMultiplier(int focusMinutes)` – <25 → 1.0; 25–49 → 1.2; ≥50 → 1.5
  - `({int coins, int logs}) sessionReward({required int focusMinutes, int barracksLevel = 0})` – coins = `(m × mult × (1 + 0.1×barracksLevel)).round()`, logs = `(m × 0.5).floor()`
  - `const int kHeroMaxHp = 100, kPenaltyHp = 25, kDistractionTax = 15, kTaxIntervalSeconds = 30, kMaxPauseSeconds = 300`
- Produces (`village.dart`):
  - `enum Building { tower, granary, barracks, archery, monastery, castle, house2, house3 }` với các field: `asset`, `label`, `maxLevel`, `GameCharacter? requiredCharacter`, `baseCoins`, `baseLogs`, `bool functional`, `String effect`

| Building | asset | label | max | yêu cầu | base coin/log | functional | effect |
|---|---|---|---|---|---|---|---|
| tower | Tower.png | Tháp canh | 2 | – | 200/40 | ✓ | Ân hạn 10s→12s→15s |
| granary | House1.png | Kho lương | 1 | – | 150/30 | ✓ | 1 vé giữ chuỗi mỗi tuần |
| barracks | Barracks.png | Doanh trại | 2 | – | 300/60 | ✓ | +10% Coin mỗi cấp |
| archery | Archery.png | Trường bắn | 3 | archer | 150/30 | – | Nhà của Archer |
| monastery | Monastery.png | Tu viện | 3 | monk | 250/50 | – | Nhà của Monk |
| castle | Castle.png | Lâu đài | 3 | warrior | 400/80 | – | Nhà của Warrior |
| house2 | House2.png | Nhà dân | 3 | – | 100/20 | – | Trang trí |
| house3 | House3.png | Nhà dân lớn | 3 | – | 100/20 | – | Trang trí |

  - `({int coins, int logs}) buildCost(Building b, int currentLevel)` = base × 1.5^currentLevel, `.round()`
  - `int graceSecondsFor(int towerLevel)` → `[10, 12, 15][towerLevel]`

- [ ] **Step 1: Write failing tests** `test/game_rules_test.dart`:
  - `rankForSeconds`: `0 → starter`, `10*3600-1 → starter`, `10*3600 → gold`, `30*3600 → diamond`, `70*3600 → ruby`, `150*3600 → amethyst`, `999*3600 → amethyst`.
  - `nextRank(Rank.amethyst) == null`, `nextRank(Rank.gold) == Rank.diamond`.
  - unlocks at diamond: pawn/lancer/archer true, monk/warrior false.
  - badges at diamond: `(archer, diamond)` true, `(archer, ruby)` false, `(monk, starter)` false; at ruby `(monk, ruby)` true, `(monk, starter)` true.
  - `badgeAsset(GameCharacter.archer, Rank.diamond) == 'ui/ranks/archer/archer_diamond.png'`.
  - `sessionReward(focusMinutes: 15)` → (15, 7); `(25)` → (30, 12); `(50)` → (75, 25); `(25, barracksLevel: 2)` → (36, 12).
  - `buildCost(Building.tower, 0)` → (200, 40); `buildCost(Building.tower, 1)` → (300, 60).
  - `graceSecondsFor(0..2)` → 10, 12, 15.
- [ ] **Step 2:** `flutter test test/game_rules_test.dart` → FAIL.
- [ ] **Step 3: Implement** theo bảng trên.
- [ ] **Step 4:** `flutter test` → PASS.
- [ ] **Step 5: Commit** `feat: add rank, economy and village rules`

---

### Task 3: `PlayerState` – ví, lựa chọn, building, vé giữ chuỗi

**Files:**
- Create: `lib/core/game/player_state.dart`
- Test: `test/player_state_test.dart`

**Interfaces:**
- Consumes: Task 2 (`Rank`, `GameCharacter`, `Building`, `buildCost`, `isCharacterUnlocked`, `isBadgeUnlocked`).
- Produces: `class PlayerState extends ChangeNotifier`
  - getters: `int coins`, `int logs`, `GameCharacter selectedCharacter` (mặc định pawn), `GameCharacter badgeCharacter` + `Rank badgeRank` (mặc định pawn/starter), `int streakTickets`, `DateTime? granaryBuiltAt`
  - `Future<void> load()`
  - `int levelOf(Building b)`
  - `Future<void> deposit({required int coins, required int logs})`
  - `Future<bool> build(Building b, Rank current)` – false nếu max cấp / nhân vật yêu cầu chưa mở / thiếu tiền; xây Kho lương lần đầu set `granaryBuiltAt = now` và gọi `grantWeeklyTicket`
  - `Future<void> selectCharacter(GameCharacter c, Rank current)` – bỏ qua nếu chưa mở
  - `Future<void> selectBadge(GameCharacter c, Rank badge, Rank current)` – bỏ qua nếu chưa mở
  - `Future<void> grantWeeklyTicket(DateTime now)` – chỉ khi đã có Kho lương; nếu thứ Hai của tuần `now` khác tuần đã cấp gần nhất → `streakTickets = 1` (giữ tối đa 1)
  - `bool consumeTicket()` – giảm 1 nếu >0, persist, trả true
  - Constructor `PlayerState({DateTime Function()? clock})` để test.
- Keys: `fk_gold`, `fk_logs`, `fk_character` (name), `fk_badge` (`'<char>_<rank>'`), `fk_buildings` (StringList `'tower:1'`), `fk_streak_tickets`, `fk_granary_built` (`yyyy-MM-dd`), `fk_ticket_week` (`yyyy-MM-dd` của thứ Hai).

- [ ] **Step 1: Write failing tests** (mỗi test `SharedPreferences.setMockInitialValues`):
  - `load keeps legacy fk_gold` → mock `{'fk_gold': 120}` → `coins == 120`, `logs == 0`, `selectedCharacter == pawn`.
  - `deposit then reload persists` → deposit(30, 12) → `PlayerState()..load()` mới → coins 30, logs 12.
  - `build succeeds and spends` → coins 500 logs 100 → `build(tower, starter)` true → coins 300, logs 60, `levelOf(tower) == 1`.
  - `build fails without funds` → coins 100 → false, coins vẫn 100, level 0.
  - `build fails for locked character house` → coins 9999, logs 9999 → `build(archery, Rank.gold)` false; `build(archery, Rank.diamond)` true.
  - `build fails at max level` → granary lần 2 → false, ví không đổi.
  - `ticket only after granary, once per week` → clock = Thứ Tư 2026-10-21: `grantWeeklyTicket` khi chưa có granary → 0; build granary → 1; consumeTicket → 0; grant cùng tuần → 0; clock = 2026-10-26 (thứ Hai) grant → 1; grant lại → 1 (không thành 2).
  - `selectCharacter ignores locked` → `selectCharacter(monk, Rank.gold)` → vẫn pawn.
- [ ] **Step 2:** `flutter test test/player_state_test.dart` → FAIL.
- [ ] **Step 3: Implement** `PlayerState` như Interfaces.
- [ ] **Step 4:** `flutter test` → PASS.
- [ ] **Step 5: Commit** `feat: add PlayerState with wallet, selections, buildings and streak tickets`

---

### Task 4: `FocusSessionController` – trận, quỹ tạm giữ, HP, pause, nghỉ dài

**Files:**
- Modify: `lib/features/focus_session/focus_session_controller.dart`
- Test: `test/battle_controller_test.dart`; giữ `test/multi_session_and_app_limit_test.dart` pass

**Interfaces:**
- Consumes: `PlayerState` (Task 3), `sessionReward`, hằng số Task 2, `FocusHistoryService.recordCompletedSession(int)` / `recordInterruption()`.
- Produces:
  - Constructor `FocusSessionController({PlayerState? player, FocusHistoryService? history})` (mặc định `PlayerState()` / `FocusHistoryService.instance`)
  - `startFocusSession({required String task, required int durationSeconds, int totalSessions = 1, int restDurationSeconds = 300, int longBreakEvery = 0, int longRestSeconds = 900})` – reset `heroHp = kHeroMaxHp`, quỹ, `lastResult = null`
  - getters: `int heroHp`, `int pendingCoins`, `int pendingLogs`, `int pendingFocusSeconds`, `bool isPaused`, `bool canPause`, `int pauseRemainingSeconds`, `bool isLongRest`, `double houseHpRatio` (= remaining/total khi focus, 0 khi khác), `BattleResult? lastResult`, `({int coins, int logs})? lastSessionReward`
  - `class BattleResult { final bool won; final int coins, logs, focusSeconds, sessions; }`
  - `bool pause()` / `void resumeFromPause()`
  - `void applyBlacklistPenalty()` – chỉ khi đang trận (focus/rest) và chưa thua; HP −25; ≤0 → thua
  - `void applyDistractionTax()` – chỉ khi đang trận; `pendingCoins = max(0, pendingCoins − 15)`
  - `void forceAbandonSession({String? reason})` – thua (ghi 1 interruption)
  - `cancelSession()` giữ nguyên ngữ nghĩa cũ (về setup, không thưởng, không ghi)
- Hành vi:
  - `_onFocusCompleted`: **không** gọi `recordCompletedSession` nữa; cộng `sessionReward(focusMinutes: totalFocusSeconds ~/ 60, barracksLevel: player.levelOf(Building.barracks))` vào quỹ, lưu `lastSessionReward`, cộng giây vào `pendingFocusSeconds` và một danh sách giây từng phiên.
  - Phiên cuối xong → quyết toán: `history.recordCompletedSession(s)` cho từng phiên, `player.deposit(pending)`, `lastResult = BattleResult(won: true, …)`, phase → setup.
  - Nghỉ: nếu `longBreakEvery > 0 && currentSession % longBreakEvery == 0` → dùng `longRestSeconds`, `isLongRest = true`.
  - Thua (HP 0 hoặc abandon): `lastResult = BattleResult(won: false, coins: 0, logs: 0, focusSeconds: 0, …)`, xoá quỹ, `recordInterruption()`, phase → setup; gọi lại penalty/tax sau đó không làm gì.
  - Pause: chỉ trong focus, 1 lần/phiên (reset khi sang phiên mới); khi pause, countdown đứng, `pauseRemainingSeconds` đếm từ 300 về 0 rồi tự `resumeFromPause()`; notification hiện `'Tạm dừng mm:ss'`.

- [ ] **Step 1: Write failing tests** `test/battle_controller_test.dart` (thời gian thật như test hiện có, `durationSeconds: 1`, `SharedPreferences.setMockInitialValues({})`, `FocusHistoryService()` mới cho mỗi test):
  - Controller thêm `@visibleForTesting void debugCompleteFocus()` = gọi `_onFocusCompleted()` ngay (tránh chờ 25 phút).
  - `real timers still run a full battle` → `durationSeconds: 1, restDurationSeconds: 1, totalSessions: 2`; chờ 3.5s → `lastResult!.won` true, `lastResult!.sessions == 2`, `history.totalFocusSecondsAllTime == 2`.
  - `completed battle deposits reward once` → `durationSeconds: 1500, totalSessions: 1`, `debugCompleteFocus()` → `player.coins == 30`, `player.logs == 12`, `history.totalFocusSecondsAllTime == 1500`, `lastResult!.coins == 30`.
  - `hours and coins withheld until battle ends` → 1500s × 2 phiên, `debugCompleteFocus()` một lần → `pendingCoins == 30`, `player.coins == 0`, `history.totalFocusSecondsAllTime == 0`.
  - `defeat forfeits everything` → 1500s × 2, `debugCompleteFocus()`, rồi `applyBlacklistPenalty()` ×4 → `lastResult!.won == false`, `player.coins == 0`, `history.totalFocusSecondsAllTime == 0`, `isSetup`; gọi `applyBlacklistPenalty()` + `applyDistractionTax()` lần nữa → không throw, `lastResult` không đổi.
  - `tax never below zero` → `debugCompleteFocus()` (quỹ 30) → tax ×3 → `pendingCoins == 0`.
  - `penalty ignored when not in battle` → controller mới (setup) → `applyBlacklistPenalty()` → `heroHp == 100`, `lastResult == null`.
  - `pause once per session and freezes timer` → focus 5s → `pause()` true → chờ 1.2s → `remainingSeconds == 5` → `pause()` lần 2 false sau `resumeFromPause()`; khi đang rest `pause()` false.
  - `long rest after N sessions` → `totalSessions: 3, longBreakEvery: 2, restDurationSeconds: 1, longRestSeconds: 7`, `debugCompleteFocus()` → `isLongRest == false`; `finishRestBreak()`; `debugCompleteFocus()` → `isLongRest == true`, `remainingSeconds == 7`.
- [ ] **Step 2:** `flutter test test/battle_controller_test.dart` → FAIL.
- [ ] **Step 3: Implement** theo Interfaces/Hành vi.
- [ ] **Step 4:** `flutter test` → PASS (kể cả `multi_session_and_app_limit_test.dart`, `focus_history_test.dart`).
- [ ] **Step 5: Commit** `feat: battle-level escrow, hero HP, pause and long breaks in session controller`

---

### Task 5: Màn trận mới (Focus + Camp + Tổng kết), xoá canvas & engine cũ

**Files:**
- Create: `lib/features/battle/battle_screen.dart` (Scaffold full-screen, chọn view theo phase)
- Create: `lib/features/battle/focus_view.dart`, `lib/features/battle/camp_view.dart`, `lib/features/battle/result_view.dart`
- Create: `lib/core/widgets/ribbon.dart` – `Ribbon({required RibbonColor color, required Widget child})`, `enum RibbonColor { yellow, blue, red }`, vẽ bằng `Image.asset(centerSlice: Rect.fromLTWH(64, 0, 64, 64))` phía sau `child`
- Delete: `lib/features/game_view/pixel_stage_canvas.dart`, `combat_engine.dart`, `models/skin_cosmetics.dart`, `pomodoro_game_screen.dart` (chuyển `_MindfulInterruptionDialog` sang `lib/features/battle/mindful_interruption_dialog.dart`), `lib/features/upgrade_shop/camp_upgrade_sheet.dart`
- Modify: `lib/main.dart`, `lib/features/dashboard/dashboard_screen.dart` (bỏ `CombatEngine`, điều hướng tới `BattleScreen`; tạo `PlayerState` ở `_FocusKnightHomePageState`, `load()` trong initState, truyền vào controller)
- Test: `test/battle_screen_test.dart`

**Interfaces:**
- Consumes: `SpriteAnim`, `characterSprites`, `enemySprites`, `deadSprite`, `PixelIcon`, `kPixelFont` (Task 1); controller getters Task 4; `PlayerState.selectedCharacter`.
- Produces: `BattleScreen({required FocusSessionController controller, required PlayerState player, VoidCallback? onOpenVillage})`

UI (theo mockup v2 màn C, v1 màn 4; spec 6.3/6.4):
- Focus: nền `ui/scenes/battle_field.webp` `BoxFit.cover`; HUD trên: `Ribbon(yellow)` chứa `formattedTime` font pixel; dưới là `'Phiên $current/$total · $taskName'`. Nhân vật (attack loop) bên trái + thanh HP `heroHp/100`; `Goblin_House.png` bên phải + thanh `houseHpRatio`; quái ngẫu nhiên từ `enemySprites` chạy (run, flipX) từ nhà tới nhân vật rồi attack, lặp mỗi ~4s – thuần hình ảnh (state cục bộ widget, `AnimatedPositioned`). Góc trên-trái: icon nhà đã phá (`Goblin_House_Destroyed.png`) / còn lại. Khi `heroHp` giảm: `ColorFiltered` trắng 60ms → đỏ 150ms + lệch `Offset(-4,0)`. Khi `isPaused`: lớp tối + `'Tạm dừng mm:ss'`.
- Ghost controls: trái dưới `PixelIcon('music_note')` (chưa có nhạc → chỉ toggle icon, **không** thêm audio) + `PixelIcon('play')` (pause/resume, ẩn khi `!canPause && !isPaused`); phải dưới `PixelIcon('cancel')` dùng `GestureDetector.onLongPressStart` + `Timer` 2s, kèm vòng tiến độ; thả trước 2s thì huỷ. Opacity 1 → 0.2 sau 3s không chạm (`AnimatedOpacity`), chạm bất kỳ đâu bật lại 1.
- Back hệ thống khi focus → `MindfulInterruptionDialog` (giữ nguyên hành vi cũ, gọi `forceAbandonSession`).
- Hết phiên: nhân vật đổi sang `run` 0.8s rồi chuyển Camp.
- Camp: nửa trên `ui/scenes/camp_fire.webp` (căn vào lửa trại) + nhân vật idle + `Ribbon(blue)` `'Nghỉ mm:ss'` (nghỉ dài: `'Nghỉ dài mm:ss'`); nửa dưới sheet gỗ (`#1B1712`, viền `#6B4F2A`, font pixel): `+coin +log` của `lastSessionReward`, dòng `'Quỹ trận: X coin · Y log — nhận khi xong trận'`, nút `'Vào làng'` (gọi `onOpenVillage`, nếu null thì ẩn). Nút ghim đáy `'⚔ XUNG TRẬN NGAY'` → `finishRestBreak()`.
- Result (`lastResult != null` và phase setup, ngay sau trận): thắng → nhà goblin đã phá, `'+coins +logs · X phút'`, nút `'Về trang chủ'`; thua → `deadSprite` (không loop), `'Thất bại – mất toàn bộ phần thưởng và giờ của trận'`, nút `'Về trang chủ'`.

- [ ] **Step 1: Write failing widget tests** `test/battle_screen_test.dart` (controller thật, `startFocusSession(durationSeconds: 1500)`; dọn bằng `cancelSession()` cuối test):
  - `focus view has no TabBar/AppBar and shows timer` → `find.byType(TabBar)` none, `find.byType(AppBar)` none, `find.text('25:00')` one.
  - `give up requires 2s long press` → long-press giữ 1s rồi thả → `controller.isFocusing` true; giữ 2.1s → `controller.isSetup` true và `lastResult!.won == false`.
  - `camp shows session reward and skip button` → `debugCompleteFocus()` với `totalSessions: 2`, pump → `find.text('+30')` và `find.textContaining('XUNG TRẬN NGAY')`; tap → `controller.isFocusing`.
  - `defeat shows result screen` → `applyBlacklistPenalty()` ×4, pump → `find.textContaining('Thất bại')`.
- [ ] **Step 2:** `flutter test test/battle_screen_test.dart` → FAIL.
- [ ] **Step 3: Implement** các file trên; xoá file cũ; sửa `main.dart`/`dashboard_screen.dart` để build được (nút bắt đầu cũ tạm gọi `startFocusSession` mặc định rồi push `BattleScreen` – Task 6 thay bằng sheet).
- [ ] **Step 4:** `flutter test` → PASS; `flutter analyze` → không error.
- [ ] **Step 5: Kiểm tra trên máy:** `flutter run -d R3CN90V2K3X`, bắt đầu phiên 1 phút (đặt tạm), xem sprite chạy mượt, camp hiện, long-press bỏ cuộc hoạt động.
- [ ] **Step 6: Commit** `feat: sprite-based battle screen with goblin house timer, camp and result views`

---

### Task 6: Bottom sheet "Thiết lập trận"

**Files:**
- Create: `lib/features/battle/battle_setup_sheet.dart`
- Create: `lib/core/game/battle_plan.dart`
- Test: `test/battle_plan_test.dart`, thêm case vào `test/battle_screen_test.dart` nếu cần

**Interfaces:**
- Consumes: `sessionReward`, `PlayerState.levelOf(Building.barracks)`, `controller.startFocusSession` (Task 4).
- Produces:
  - `class BattlePlan { String task; int focusMinutes; int restMinutes; int sessions; int longBreakEvery; }` + `toJson`/`fromJson` (`Map<String, dynamic>`), lưu lần chọn cuối ở key `fk_last_plan` (JSON string)
  - `int clampFocusMinutes(String input)` → không parse được → 25; <1 → 1; >180 → 180
  - `int clampRestMinutes(String input)` → không parse được → 5; <1 → 1; >60 → 60
  - `List<({bool focus, bool longRest, int minutes})> planTimeline(BattlePlan p, {int longRestMinutes = 15})` – không có nghỉ sau phiên cuối
  - `DateTime planEndTime(BattlePlan p, DateTime start, {int longRestMinutes = 15})`
  - `int planCoins(BattlePlan p, int barracksLevel)` = sessions × `sessionReward(...).coins`
  - `Future<BattlePlan?> showBattleSetupSheet(BuildContext, {required BattlePlan initial, required int barracksLevel})`
- UI (mockup v2 màn A): tên task; chip Tập trung 15/25/50/Tùy…; chip Nghỉ ngắn 3/5/10/Tùy…; stepper Số phiên 1–8; stepper Nghỉ dài sau 0(=tắt)–8 phiên; thanh lịch trình (vàng `#FFB300` / xanh lá `#10B981` / xanh dương `#3B82F6`, flex theo phút); `'xong lúc ~HH:mm'`; `'~X coin'`; nút `'XUẤT TRẬN'`. "Tùy…" mở dialog TextField số.
- Dashboard: nút Bắt đầu → sheet → nếu trả plan: lưu `fk_last_plan`, `startFocusSession(durationSeconds: m*60, restDurationSeconds: …, totalSessions, longBreakEvery, longRestSeconds: settings.longRestMinutes*60)` → push `BattleScreen`. Độ dài nghỉ dài: key `fk_long_rest_minutes`, mặc định 15 (Task 7 thêm chỗ chỉnh).

- [ ] **Step 1: Write failing tests** `test/battle_plan_test.dart`:
  - `clampFocusMinutes`: `''→25`, `'abc'→25`, `'0'→1`, `'999'→180`, `'40'→40`; `clampRestMinutes`: `''→5`, `'0'→1`, `'90'→60`.
  - `planTimeline` với 4 phiên × 25p, nghỉ 5p, longBreakEvery 4 → 7 đoạn: F25 R5 F25 R5 F25 R5 F25 (phiên 4 là cuối → không nghỉ). Với longBreakEvery 2, 3 phiên → F R(5) F L(15) F.
  - `planEndTime(4×25p, nghỉ 5p, start 10:00)` → 11:55.
  - `planCoins(3×25p, barracks 0)` → 90.
  - `BattlePlan` round-trip JSON.
- [ ] **Step 2:** `flutter test test/battle_plan_test.dart` → FAIL.
- [ ] **Step 3: Implement** `battle_plan.dart`, sheet, nối dashboard.
- [ ] **Step 4:** `flutter test` → PASS.
- [ ] **Step 5: Kiểm tra trên máy:** mở sheet, chọn Tùy… = 2 phút, 2 phiên, xem thanh lịch trình & giờ xong; xuất trận.
- [ ] **Step 6: Commit** `feat: battle setup bottom sheet with timeline preview`

---

### Task 7: Khung app 4 tab, Trang chủ phẳng, Cài đặt

**Files:**
- Create: `lib/features/shell/app_shell.dart` – `AppShell` (Scaffold + `IndexedStack` + `NavigationBar` phẳng 4 mục dùng `PixelIcon`: `sword` Trang chủ · `hammer` Làng · `shield` Bộ sưu tập · `setting` Cài đặt). Tab Làng/Bộ sưu tập tạm là `Center(Text('Sắp có'))` tới Task 8/9.
- Create: `lib/features/home/home_screen.dart`
- Create: `lib/features/settings/settings_screen.dart` – chuyển nguyên phần telemetry/hạn mức MXH/giới hạn app/quyền overlay & usage từ `dashboard_screen.dart`, thêm chỉnh "Nghỉ dài (phút)" (`fk_long_rest_minutes`, 5–60)
- Create: `lib/features/home/analytics_screen.dart` – trang con chứa `GoldenHoursCard`, `DistractionVelocityCard`, `CorrelationChartCard` và lịch chấm tháng cũ (chuyển `_buildMonthlyDotGridCalendar` sang đây)
- Delete: `lib/features/dashboard/dashboard_screen.dart` (sau khi đã chuyển hết phần trên)
- Modify: `lib/main.dart` (`home` → `AppShell`), áp màu theme ở Global Constraints
- Test: `test/home_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerState`, `rankForSeconds`, `nextRank`, `badgeAsset`, `FocusHistoryService` (today seconds, session count, interruptions, 7 ngày, `calculateStreak`), `showBattleSetupSheet` (Task 6), `BattleScreen` (Task 5).
- Produces: `AppShell({required FocusSessionController controller, required PlayerState player, required ScreenTimeTracker tracker, required OverlayService overlay})`; `AppShell` có `void openTab(int index)` qua `GlobalKey<AppShellState>` để Camp "Vào làng" chuyển tab Làng (pop BattleScreen trước). **Không** cho vào Làng khi đang focus.
- Trang chủ (mockup v1 màn 1, từ trên xuống): header avatar `badgeAsset(badgeCharacter, badgeRank)` 52px · tên rank · thanh tiến độ · `'Xh / Yh → <next>'` (Amethyst: `'Hạng cao nhất'`) · coin/log với `PixelIcon`; card Bắt đầu (SpriteAnim idle của `selectedCharacter`, tên task, nút `'BẮT ĐẦU'`); 3 ô Hôm nay (phút / phiên / xao nhãng – xao nhãng màu `#F87171`); card 7 ngày (cột theo phút, nhãn T2…CN) + `'🔥 N ngày liên tiếp'`; card dòng thu gọn `'Phân tích chi tiết ›'` → `AnalyticsScreen`.
- Nếu controller đang trong trận (focus/rest) khi mở app → nút Bắt đầu đổi thành `'Quay lại trận'` → push `BattleScreen`.

- [ ] **Step 1: Write failing widget tests** `test/home_screen_test.dart` (mock prefs `{'fk_total_focus_seconds_all_time': 34*3600, 'fk_gold': 1240, 'fk_logs': 86, 'fk_badge': 'archer_diamond'}`):
  - shows `'Diamond'`, `'34h / 70h → Ruby'`, `'1240'`, `'86'`.
  - avatar `Image` có asset `'ui/ranks/archer/archer_diamond.png'`.
  - không có `BoxShadow` nào trong cây widget (duyệt `Container.decoration`).
  - tap `'BẮT ĐẦU'` → bottom sheet có `'XUẤT TRẬN'`.
- [ ] **Step 2:** `flutter test test/home_screen_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** `flutter test` → PASS (cập nhật/xoá test cũ nào import `dashboard_screen.dart`, nếu có).
- [ ] **Step 5: Kiểm tra trên máy:** 4 tab, Cài đặt vẫn cấp quyền overlay/usage được.
- [ ] **Step 6: Commit** `feat: flat 4-tab shell, home dashboard, analytics and settings screens`

---

### Task 8: Bộ sưu tập (nhân vật + huy hiệu)

**Files:**
- Create: `lib/features/collection/collection_screen.dart`
- Modify: `lib/features/shell/app_shell.dart` (gắn tab)
- Test: `test/collection_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerState.selectCharacter/selectBadge`, `isCharacterUnlocked`, `isBadgeUnlocked`, `badgeAsset`, `characterSprites`, `rankForSeconds`.
- UI (mockup v1 màn 2): hàng 5 nhân vật – đã mở: `SpriteAnim` idle, viền vàng nếu đang chọn; chưa mở: idle đứng yên + `ColorFiltered` tối + tên rank cần đạt. Lưới 5×5 (hàng = nhân vật, cột = rank) – ô khoá tối, ô đang làm avatar viền `#FFB300`. Dòng cuối: `'Còn Xh để mở <Nhân vật> + huy hiệu <Rank>'` (Amethyst: ẩn).

- [ ] **Step 1: Write failing widget tests** (tổng giờ 34h = Diamond):
  - tap Monk → `player.selectedCharacter` vẫn pawn; tap Archer → archer.
  - tap ô `archer_diamond` → `badgeCharacter == archer && badgeRank == diamond`; tap ô `monk_starter` → không đổi.
  - hiện `'Còn 36h để mở Monk + huy hiệu Ruby'`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** `flutter test` → PASS.
- [ ] **Step 5: Commit** `feat: collection screen for characters and rank badges`

---

### Task 9: Làng + buff + vé giữ chuỗi

**Files:**
- Create: `lib/features/village/village_screen.dart`, `lib/features/village/building_sheet.dart`
- Modify: `lib/features/dashboard/services/focus_history_service.dart` (vé giữ chuỗi), `lib/features/shell/app_shell.dart` (gắn tab), `lib/main.dart` (khi khởi động: `player.grantWeeklyTicket(now)` rồi `history.tryShieldGap(...)`)
- Test: `test/streak_shield_test.dart`, `test/village_screen_test.dart`

**Interfaces:**
- Consumes: `Building`, `buildCost`, `PlayerState.build/levelOf/consumeTicket/granaryBuiltAt`, `rankForSeconds`.
- Produces (`FocusHistoryService`):
  - `List<String> get shieldedDates` (key `fk_shielded_dates`, load trong `loadData`)
  - `Future<bool> tryShieldGap({required DateTime now, required DateTime? protectFrom, required bool Function() consumeTicket})` – nếu hôm nay & hôm qua đều chưa có trong (completed ∪ shielded), hôm kia có, hôm qua ≥ `protectFrom` (theo ngày) và `consumeTicket()` true → thêm hôm qua vào shielded, persist, true. Ngược lại false và **không** gọi `consumeTicket`.
  - `calculateStreak` dùng `completed ∪ shielded`.
- Village UI (mockup v2 màn D): nền `camp_fire.webp` cover; 8 ô ở toạ độ phần trăm cố định (builder tự đặt, tránh đè lên nhau ở 360×780 dp); đã xây: sprite + nhãn `'<label> Lv<n>'`; chưa xây: khung nét đứt + `PixelIcon('hammer')` + label; khoá: thêm `'🔒 <Rank>'` (rank mở nhân vật yêu cầu). Header: coin/log. Chạm → `building_sheet` (font pixel, nền gỗ): sprite lớn, `effect`, cấp hiện tại/max, chi phí cấp tiếp với PixelIcon coin/log, nút `'Xây'`/`'Nâng cấp'`/`'Đã tối đa'`, disabled + lý do khi thiếu tiền / khoá.
- Buff đã nối: Doanh trại qua `sessionReward` (Task 4); Tháp canh qua `graceSecondsFor(player.levelOf(Building.tower))` (Task 10); Kho lương qua vé ở trên.

- [ ] **Step 1: Write failing tests** `test/streak_shield_test.dart` (now = 2026-10-21):
  - completed `[10-19]`, protectFrom 10-01, ticket available → `tryShieldGap` true, `calculateStreak(now)` == 2 (19 + 20 bù), counter consume == 1.
  - không vé (`consumeTicket` trả false) → false, streak 0.
  - protectFrom 10-21 (xây sau ngày trống) → false, `consumeTicket` không được gọi.
  - hôm qua đã completed → false, không gọi `consumeTicket`.
  - `village_screen_test.dart`: coins 0 → mở sheet Tháp canh → nút `'Xây'` disabled; coins 500/logs 100 → tap `'Xây'` → hiện `'Tháp canh Lv1'`; ở Rank.gold ô Trường bắn hiện `'🔒 Diamond'`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** `flutter test` → PASS (kể cả `focus_history_test.dart`).
- [ ] **Step 5: Kiểm tra trên máy:** xây Tháp canh bằng coin thật (có thể tạm set coin qua debug), vào làng từ Camp.
- [ ] **Step 6: Commit** `feat: village with functional buildings and streak shield tickets`

---

### Task 10: `DistractionGuard`, nối hình phạt & overlay mới

**Files:**
- Create: `lib/core/services/distraction_guard.dart`
- Modify: `lib/main.dart` (`didChangeAppLifecycleState`), `lib/core/services/overlay_service.dart`, `lib/features/overlay/blocker_overlay_widget.dart`
- Test: `test/distraction_guard_test.dart`

**Interfaces:**
- Consumes: `kTaxIntervalSeconds`, `graceSecondsFor`, controller `applyBlacklistPenalty/applyDistractionTax/heroHp/pendingCoins/isFocusing/isResting/recordInterruptionEvent`.
- Produces:
  - `class DistractionGuard { DistractionGuard({required int Function() graceSeconds, required void Function(String pkg) onPenalty, required void Function() onTax, required void Function() onLeftBlacklisted}); void tick(String? blacklistedPkg, DateTime now); void reset(); }`
  - Trạng thái: `idle` → (pkg≠null) `grace(start)` → (now−start ≥ grace) gọi `onPenalty(pkg)`, sang `penalized(lastTax=now)` → mỗi `now−lastTax ≥ 30s` gọi `onTax()`. pkg==null ở bất kỳ trạng thái ≠ idle → `onLeftBlacklisted()`, về `idle` (lần mở lại tính ân hạn + phạt lại).
  - `OverlayService.showBlockerOverlay` thêm `Future<void> pushState({required String appName, required int heroHp, required int pendingCoins})` gọi `FlutterOverlayWindow.shareData({...})`.
  - `BlockerOverlayWidget` thành StatefulWidget nghe `FlutterOverlayWindow.overlayListener`: hiện `PixelIcon('shield')`, tên app, thanh HP `heroHp/100` (đỏ), `'Quỹ trận: X coin'`, `'−15 coin mỗi 30 giây'`, nút `'QUAY LẠI TRẬN'` (giữ `launchApp` + `closeOverlay`); bỏ nút "Dismiss". Font pixel, nền tối phẳng.
- `main.dart`: khi app ra nền và đang trong trận (focus hoặc rest – `isFocusing || isResting`): `controller.recordInterruptionEvent()` **chỉ khi** `isFocusing`; bỏ `startGracePeriod` khi chỉ rời app; timer 2s gọi `guard.tick(await tracker.getActiveBlacklistedPackage(), DateTime.now())`. `onPenalty` → `controller.applyBlacklistPenalty()`, `overlay.showBlockerOverlay(...)`, `pushState`. `onTax` → `applyDistractionTax()`, `pushState`. `onLeftBlacklisted` → `closeBlockerOverlay()`. Resume app → `guard.reset()`, đóng overlay. Ngoài trận giữ nguyên nhánh notification vượt hạn mức app. `OverlayService.startGracePeriod`/grace timer cũ: xoá nếu không còn dùng.

- [ ] **Step 1: Write failing tests** `test/distraction_guard_test.dart` (grace = 10, t0 = DateTime(2026,10,19,10)):
  - `no penalty during grace` → tick(pkg, t0), tick(pkg, t0+9s) → penalty 0.
  - `penalty after grace, once` → tick t0, t0+10s, t0+12s → penalty 1.
  - `tax every 30s while staying` → sau penalty ở t0+10s: tick t0+39s → tax 0; t0+40s → 1; t0+70s → 2.
  - `leaving resets, returning re-penalizes` → penalty ở t0+10s; tick(null, t0+15s) → left 1; tick(pkg, t0+20s), tick(pkg, t0+30s) → penalty 2.
  - `null while idle does nothing` → tick(null) ×3 → left 0.
  - `grace reads current tower level` → `graceSeconds` trả 15 → penalty ở t0+15s, không ở t0+14s.
- [ ] **Step 2:** FAIL. **Step 3:** Implement guard + nối main/overlay. **Step 4:** `flutter test` → PASS; `flutter analyze` sạch.
- [ ] **Step 5: Kiểm tra trên máy:** bắt đầu phiên, mở YouTube ~15s → overlay hiện HP 75, quỹ; ở thêm 30s → quỹ −15; quay lại app → overlay đóng; mở app không blacklist (vd. Tin nhắn) → không phạt, chỉ +1 xao nhãng.
- [ ] **Step 6: Commit** `feat: blacklist-only penalty guard with HP and escrow tax on overlay`

---

### Task 11: Dọn dẹp & tài liệu

**Files:**
- Modify: `PROJECT_OVERVIEW.md`, `README.md` (bỏ mô tả "100% vẽ bằng Canvas", skin, stat upgrade; mô tả rank/làng/kinh tế mới – ngắn gọn)
- Delete: `problem.md` chỉ khi chủ dự án đồng ý (hỏi trước; mặc định giữ)

- [ ] **Step 1:** `grep -rn "CombatEngine\|PixelStageCanvas\|CosmeticsManager\|camp_upgrade" lib test` → không còn kết quả.
- [ ] **Step 2:** `flutter test` → PASS; `flutter analyze` → 0 error.
- [ ] **Step 3:** Cập nhật tài liệu.
- [ ] **Step 4: Commit** `docs: update overview for sprite UI, ranks, village and economy`
