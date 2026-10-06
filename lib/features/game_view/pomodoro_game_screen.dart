import 'dart:async';
import 'package:flutter/material.dart';
import '../focus_session/focus_session_controller.dart';
import '../upgrade_shop/camp_upgrade_sheet.dart';
import 'combat_engine.dart';
import 'models/skin_cosmetics.dart';
import 'pixel_stage_canvas.dart';
import '../dashboard/services/focus_history_service.dart';

/// In-Game Pomodoro Combat Screen.
/// Contains Procedural Pixel Canvas, Huge Countdown directly under canvas,
/// TabBar for Battle/Camp Upgrades and Skins/Companions, and 15s Mindful Interruption Log.
class PomodoroGameScreen extends StatefulWidget {
  final CombatEngine combatEngine;
  final FocusSessionController sessionController;
  final String? initialTaskName;

  const PomodoroGameScreen({
    super.key,
    required this.combatEngine,
    required this.sessionController,
    this.initialTaskName,
  });

  @override
  State<PomodoroGameScreen> createState() => _PomodoroGameScreenState();
}

class _PomodoroGameScreenState extends State<PomodoroGameScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _taskTextController;
  late final CosmeticsManager _cosmeticsManager;

  int _selectedSessionsCount = 3; // Default 3 sessions
  int _selectedDurationSeconds = 25 * 60; // Default 25m Pomodoro
  int _selectedRestSeconds = 5 * 60; // Default 5m Rest

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _taskTextController = TextEditingController(
      text: widget.initialTaskName ?? widget.sessionController.taskName,
    );
    _cosmeticsManager = CosmeticsManager();

    widget.sessionController.addListener(_onSessionStateChanged);
    // Explicitly enforce idle combat state unless actively focusing
    if (!widget.sessionController.isFocusing) {
      widget.combatEngine.pauseCombat();
    }
  }

  void _onSessionStateChanged() {
    if (widget.sessionController.isFocusing) {
      widget.combatEngine.resumeCombat();
    } else {
      widget.combatEngine.pauseCombat();
    }
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionStateChanged);
    _tabController.dispose();
    _taskTextController.dispose();
    _cosmeticsManager.dispose();
    super.dispose();
  }

  void _handleBackAttempt() {
    if (widget.sessionController.isFocusing) {
      _showMindfulInterruptionDialog();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 15-Second Mindful Interruption Dialog with breathing countdown and restless reason selection
  void _showMindfulInterruptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MindfulInterruptionDialog(
        onConfirmAbandon: (reason) {
          widget.sessionController.forceAbandonSession(reason: reason);
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
        onResumeFocus: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackAttempt();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F111A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161A26),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF94A3B8)),
            onPressed: _handleBackAttempt,
          ),
          title: Row(
            children: [
              const Icon(Icons.shield, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.sessionController.isFocusing
                      ? 'QUEST: ${widget.sessionController.taskName.toUpperCase()}'
                      : 'POMODORO BATTLEFIELD',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 14),
                  const SizedBox(width: 4),
                  ListenableBuilder(
                    listenable: widget.combatEngine,
                    builder: (context, _) {
                      return Text(
                        '${widget.combatEngine.gold} G',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD54F),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top Section: Procedural Pixel Stage Canvas (flex 44)
              Expanded(
                flex: 44,
                child: ListenableBuilder(
                  listenable: Listenable.merge([_cosmeticsManager, widget.sessionController]),
                  builder: (context, _) {
                    return PixelStageCanvas(
                      engine: widget.combatEngine,
                      skin: _cosmeticsManager.currentSkin,
                      campCosmetic: _cosmeticsManager.currentCampItem,
                      countdownText: widget.sessionController.formattedTime,
                      timerColor: widget.sessionController.isResting
                          ? const Color(0xFF10B981)
                          : (widget.sessionController.isFocusing
                              ? const Color(0xFFFFB300)
                              : const Color(0xFF94A3B8)),
                    );
                  },
                ),
              ),

              // Divider
              Container(height: 1.5, color: const Color(0xFF262C3D)),

              // Middle Section: Tab Views (flex 56)
              Expanded(
                flex: 56,
                child: Container(
                  color: const Color(0xFF121520),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBattleAndCampTab(),
                      _buildSkinsAndCosmeticsTab(),
                    ],
                  ),
                ),
              ),

              // Bottom Section: 2 Tabs at the VERY BOTTOM, compact and not oversized
              Container(
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF161A26),
                  border: Border(
                    top: BorderSide(color: Color(0xFF262C3D), width: 1.5),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFFFB300),
                  indicatorWeight: 2.5,
                  labelColor: const Color(0xFFFFB300),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.sports_martial_arts, size: 18),
                      text: 'Trận Đấu & Trại',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    Tab(
                      icon: Icon(Icons.palette, size: 18),
                      text: 'Ngoại Trang (Skins)',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: BATTLE & CAMP WORKSHOP
  // ---------------------------------------------------------------------------
  Widget _buildBattleAndCampTab() {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.sessionController, widget.combatEngine]),
      builder: (context, _) {
        final controller = widget.sessionController;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Focus Banner (when focusing)
              if (controller.isFocusing) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2333),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flash_on, size: 16, color: Color(0xFFFFB300)),
                              const SizedBox(width: 6),
                              Text(
                                'PHIÊN ${controller.currentSession}/${controller.totalSessions} • ĐANG TẬP TRUNG',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Color(0xFFFFB300),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _showMindfulInterruptionDialog,
                            icon: const Icon(Icons.pause_circle_outline, size: 14, color: Color(0xFFEF4444)),
                            label: const Text(
                              'Dừng phiên',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: controller.progressRatio,
                          backgroundColor: const Color(0xFF0F172A),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Active Rest Break Banner & Camp Upgrades (when resting)
              if (controller.isResting) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.coffee, size: 16, color: Color(0xFF34D399)),
                              const SizedBox(width: 6),
                              Text(
                                'NGHỈ GIẢI LAO (${controller.currentSession}/${controller.totalSessions})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => controller.finishRestBreak(),
                            child: const Text('Bỏ qua nghỉ', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: controller.progressRatio,
                          backgroundColor: const Color(0xFF0F172A),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                CampUpgradeSheet(
                  engine: widget.combatEngine,
                  onFinishRest: () => controller.finishRestBreak(),
                ),
                const SizedBox(height: 14),
              ],

              // If in Setup, show full multi-session config & Start button
              if (controller.isSetup) ...[
                const Text(
                  'NHẬN DIỆN MỤC TIÊU (TASK TAG)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _taskTextController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Code API, Đọc sách, Luyện thuật toán',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E2333),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFFB300)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 1. NUMBER OF SESSIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SỐ PHIÊN TẬP TRUNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      '$_selectedSessionsCount Phiên',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...[1, 2, 3, 4].map((count) {
                      final isSelected = _selectedSessionsCount == count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: () => setState(() => _selectedSessionsCount = count),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                                    : const Color(0xFF1E2333),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF334155),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$count Phiên',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color(0xFFFFB300) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. FOCUS DURATION PER SESSION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'THỜI LƯỢNG MỖI PHIÊN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      _selectedDurationSeconds >= 60
                          ? '${_selectedDurationSeconds ~/ 60} Phút'
                          : '$_selectedDurationSeconds Giây',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildDurationChip('1m (Test)', 60, Icons.flash_on),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildDurationChip('15 Phút', 15 * 60, Icons.timer),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildDurationChip('25 Phút', 25 * 60, Icons.timer),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildDurationChip('50 Phút', 50 * 60, Icons.timer),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. REST DURATION BETWEEN SESSIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'THỜI GIAN NGHỈ GIỮA CÁC PHIÊN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      _selectedRestSeconds >= 60
                          ? '${_selectedRestSeconds ~/ 60} Phút'
                          : '$_selectedRestSeconds Giây',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildRestChip('30s (Test)', 30),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildRestChip('5 Phút', 5 * 60),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildRestChip('10 Phút', 10 * 60),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildRestChip('15 Phút', 15 * 60),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // START BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      controller.startFocusSession(
                        task: _taskTextController.text,
                        durationSeconds: _selectedDurationSeconds,
                        totalSessions: _selectedSessionsCount,
                        restDurationSeconds: _selectedRestSeconds,
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 22),
                    label: Text(
                      'BẮT ĐẦU CA TẬP TRUNG ($_selectedSessionsCount PHIÊN • ${_selectedDurationSeconds ~/ 60}P/${_selectedRestSeconds >= 60 ? "${_selectedRestSeconds ~/ 60}P" : "${_selectedRestSeconds}s"})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Live Combat Stats
              const Text(
                'THÔNG SỐ TRẬN ĐẤU THỜI GIAN THỰC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'HIỆP SĨ (HERO)',
                      'HP ${widget.combatEngine.currentHp}/${widget.combatEngine.maxHp}',
                      'ATK ${widget.combatEngine.atk} • ${widget.combatEngine.critRate.toInt()}% CRIT',
                      const Color(0xFF60A5FA),
                      Icons.shield,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      widget.combatEngine.monsterName.toUpperCase(),
                      'HP ${widget.combatEngine.monsterCurrentHp}',
                      'ATK ${widget.combatEngine.monsterAtk} • STAGE ${widget.combatEngine.currentStage}',
                      const Color(0xFFF87171),
                      Icons.sports_kabaddi,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2333),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF60A5FA)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hiệp sĩ chỉ tấn công khi ca tập trung bắt đầu. Xưởng nâng cấp sẽ mở khóa trong thời gian nghỉ ngơi giữa các phiên!',
                        style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: SKINS & COMPANIONS (Procedural Palette Swap)
  // ---------------------------------------------------------------------------
  Widget _buildSkinsAndCosmeticsTab() {
    final history = FocusHistoryService.instance;
    final totalHours = history.totalFocusHoursAllTime;

    return ListenableBuilder(
      listenable: _cosmeticsManager,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Skins Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NGOẠI TRANG HIỆP SĨ (HERO SKINS)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  Text(
                    'Đã tích lũy: ${totalHours}h',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFFFB300), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...CosmeticsManager.allSkins.map((skin) {
                final isUnlocked = skin.isUnlocked(totalHours);
                final isEquipped = _cosmeticsManager.activeSkinId == skin.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEquipped
                        ? const Color(0xFFFFB300).withValues(alpha: 0.12)
                        : const Color(0xFF1E2333),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isEquipped ? const Color(0xFFFFB300) : const Color(0xFF334155),
                      width: isEquipped ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Palette preview icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: skin.armorLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: skin.armorDark, width: 2),
                        ),
                        child: Icon(Icons.shield, color: skin.visorColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skin.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isUnlocked ? skin.description : 'Yêu cầu: ${skin.unlockHours} giờ tập trung',
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnlocked ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isEquipped)
                        const Chip(
                          label: Text('ĐANG DÙNG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          backgroundColor: Color(0xFFFFB300),
                          labelPadding: EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        )
                      else if (isUnlocked)
                        ElevatedButton(
                          onPressed: () => _cosmeticsManager.equipSkin(skin.id, totalHours),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF334155),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Mặc', style: TextStyle(fontSize: 11)),
                        )
                      else
                        const Icon(Icons.lock, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Camp Pets Section
              const Text(
                'THÚ CƯNG ĐỒNG HÀNH (CAMP PETS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 10),
              ...CosmeticsManager.allCampItems.map((camp) {
                final isUnlocked = camp.isUnlocked(totalHours);
                final isEquipped = _cosmeticsManager.activeCampId == camp.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEquipped
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFF1E2333),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isEquipped ? const Color(0xFF10B981) : const Color(0xFF334155),
                      width: isEquipped ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: camp.id == 'none' ? const Color(0xFF334155) : camp.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          camp.id == 'none' ? Icons.block : Icons.pets,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              camp.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isUnlocked ? camp.description : 'Yêu cầu: ${camp.unlockHours} giờ tập trung',
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnlocked ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isEquipped)
                        const Chip(
                          label: Text('ĐANG DÙNG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          backgroundColor: Color(0xFF10B981),
                          labelPadding: EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        )
                      else if (isUnlocked)
                        ElevatedButton(
                          onPressed: () => _cosmeticsManager.equipCampItem(camp.id, totalHours),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF334155),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Chọn', style: TextStyle(fontSize: 11)),
                        )
                      else
                        const Icon(Icons.lock, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String hpText, String statsText, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(hpText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(statsText, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String label, int seconds, IconData icon) {
    final isSelected = _selectedDurationSeconds == seconds;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDurationSeconds = seconds;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFB300).withValues(alpha: 0.15)
              : const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFFFFB300) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestChip(String label, int seconds) {
    final isSelected = _selectedRestSeconds == seconds;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRestSeconds = seconds;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.15)
              : const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal for 15-second breathing countdown and restless reason selection
class _MindfulInterruptionDialog extends StatefulWidget {
  final ValueChanged<String> onConfirmAbandon;
  final VoidCallback onResumeFocus;

  const _MindfulInterruptionDialog({
    required this.onConfirmAbandon,
    required this.onResumeFocus,
  });

  @override
  State<_MindfulInterruptionDialog> createState() => _MindfulInterruptionDialogState();
}

class _MindfulInterruptionDialogState extends State<_MindfulInterruptionDialog> {
  int _countdown = 15;
  Timer? _timer;
  String _selectedReason = 'Mệt mỏi / Cạn năng lượng';

  static const List<String> reasons = [
    'Mệt mỏi / Cạn năng lượng',
    'Thèm lướt MXH / Tin nhắn',
    'Có việc đột xuất',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        setState(() {
          _countdown = 0;
        });
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _countdown > 0;

    return Dialog(
      backgroundColor: const Color(0xFF1A1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breathing animated circle
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                border: Border.all(
                  color: isLocked ? const Color(0xFF60A5FA) : const Color(0xFF10B981),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Text(
                  isLocked ? '$_countdown' : '✓',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: isLocked ? const Color(0xFF60A5FA) : const Color(0xFF10B981),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              isLocked ? 'HÍT THỞ SÂU ĐỂ TĨNH TÂM' : 'BẠN ĐÃ TĨNH TÂM LẠI CHƯA?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLocked
                ? 'Hít vào 4 giây... Thở ra 4 giây. Cơn bồn chồn chỉ kéo dài chốc lát.'
                : 'Nếu thật sự cần dừng, hãy chọn lý do bên dưới để hoàn tất.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),

            const SizedBox(height: 16),

            // 3 Restless reason chips
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lý do muốn bỏ cuộc:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
              ),
            ),
            const SizedBox(height: 6),
            ...reasons.map((r) {
              final isSelected = _selectedReason == r;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedReason = r;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD97706).withValues(alpha: 0.2)
                          : const Color(0xFF121520),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 14,
                          color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onResumeFocus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Tiếp tục tập trung', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLocked ? null : () => widget.onConfirmAbandon(_selectedReason),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(
                        color: isLocked ? const Color(0xFF475569) : const Color(0xFFEF4444),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isLocked ? 'Chờ ${_countdown}s' : 'Xác nhận thoát',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? const Color(0xFF64748B) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
