import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/blacklist_constants.dart';
import '../../core/services/overlay_service.dart';
import '../../core/widgets/flat_theme.dart';
import '../battle/battle_launcher.dart';
import '../telemetry/screen_time_tracker.dart';

/// Permissions, screen-time limits and battle preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.screenTimeTracker, required this.overlayService});
  final ScreenTimeTracker screenTimeTracker;
  final OverlayService overlayService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _limitTextController =
      TextEditingController(text: '${widget.screenTimeTracker.dailyLimitMinutes}');
  int _longRestMinutes = 15;

  @override
  void initState() {
    super.initState();
    widget.screenTimeTracker.addListener(_onTrackerChanged);
    widget.overlayService.addListener(_onTrackerChanged);
    widget.screenTimeTracker.refreshUsageStats();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _longRestMinutes = p.getInt(kLongRestMinutesKey) ?? 15);
    });
  }

  void _onTrackerChanged() {
    final currentVal = int.tryParse(_limitTextController.text.trim());
    if (currentVal != widget.screenTimeTracker.dailyLimitMinutes) {
      _limitTextController.text = '${widget.screenTimeTracker.dailyLimitMinutes}';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.screenTimeTracker.removeListener(_onTrackerChanged);
    widget.overlayService.removeListener(_onTrackerChanged);
    _limitTextController.dispose();
    super.dispose();
  }

  Future<void> _setLongRest(int minutes) async {
    final m = minutes.clamp(5, 60);
    setState(() => _longRestMinutes = m);
    final p = await SharedPreferences.getInstance();
    await p.setInt(kLongRestMinutesKey, m);
  }

  void _saveDailyLimit() {
    final minutes = int.tryParse(_limitTextController.text.trim());
    if (minutes != null && minutes > 0) {
      widget.screenTimeTracker.setDailyLimitMinutes(minutes);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu hạn mức MXH: $minutes phút/ngày'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2333),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số phút hợp lệ (> 0)'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF7F1D1D),
        ),
      );
    }
  }

  void _showSetAppLimitDialog(String pkg, String appName) {
    final currentLimit = widget.screenTimeTracker.getAppLimit(pkg);
    final textController = TextEditingController(text: '$currentLimit');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFFFFB300), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hạn mức: $appName',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập số phút cho phép sử dụng mỗi ngày (không giới hạn):',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: 'phút/ngày',
                suffixStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF121520),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final mins = int.tryParse(textController.text.trim());
              if (mins != null && mins > 0) {
                widget.screenTimeTracker.setAppLimit(pkg, mins);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật hạn mức cho $appName: $mins phút/ngày'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF1E2333),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Cài đặt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: Flat.cardBox(),
          child: Row(children: [
            const Expanded(child: Text('Nghỉ dài (phút)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            IconButton(onPressed: () => _setLongRest(_longRestMinutes - 5), icon: const Icon(Icons.remove)),
            Text('$_longRestMinutes', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            IconButton(onPressed: () => _setLongRest(_longRestMinutes + 5), icon: const Icon(Icons.add)),
          ]),
        ),
        const SizedBox(height: 12),
        _buildTelemetryCard(),
      ],
    );
  }

  Widget _buildTelemetryCard() {
    final tracker = widget.screenTimeTracker;
    final hasPerm = tracker.hasPermission;
    final totalDistraction = tracker.totalDistractionToday;
    final isExceeded = tracker.isLimitExceeded;
    final progress = tracker.limitProgress;

    final Color progressColor = isExceeded
        ? const Color(0xFFEF4444)
        : (progress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262C3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_android, size: 16, color: Color(0xFF60A5FA)),
                  SizedBox(width: 6),
                  Text(
                    'SCREEN-TIME & BLOCKER OVERLAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => tracker.refreshUsageStats(),
                child: const Icon(Icons.refresh, size: 16, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!hasPerm) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF78350F).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cần cấp quyền Truy cập Sử dụng để theo dõi MXH.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFCD34D)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => tracker.requestPermission(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Cấp quyền', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Daily Limit Section Header & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hourglass_top, size: 14, color: Color(0xFFFFB300)),
                    SizedBox(width: 5),
                    Text(
                      'HẠN MỨC MXH TRONG NGÀY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isExceeded
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : (progress >= 0.8
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                            : const Color(0xFF10B981).withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExceeded
                          ? const Color(0xFFEF4444)
                          : (progress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    ),
                  ),
                  child: Text(
                    isExceeded
                        ? '⚠️ ĐÃ QUÁ HẠN'
                        : 'Còn: ${tracker.formatDuration(tracker.remainingTime)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isExceeded
                          ? const Color(0xFFEF4444)
                          : (progress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Plain Text Input Field for Daily Limit
            TextField(
              controller: _limitTextController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveDailyLimit(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Nhập số phút (ví dụ: 45, 60)',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF121622),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFFFB300)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('phút', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ElevatedButton(
                        onPressed: _saveDailyLimit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Lưu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Quick preset chips
            Row(
              children: [
                const Text('Gợi ý:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                const SizedBox(width: 6),
                ...[15, 30, 60, 120].map((mins) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        _limitTextController.text = '$mins';
                        tracker.setDailyLimitMinutes(mins);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tracker.dailyLimitMinutes == mins
                              ? const Color(0xFFFFB300).withValues(alpha: 0.2)
                              : const Color(0xFF1E2333),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: tracker.dailyLimitMinutes == mins
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tracker.dailyLimitMinutes == mins
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 10),

            // Usage Progress Indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 6),

            // Usage vs Limit Caption
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đã dùng: ${tracker.formatDuration(totalDistraction)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  'Hạn mức: ${tracker.dailyLimitMinutes} phút',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),

            const Divider(color: Color(0xFF262C3D), height: 16),

            // Blacklisted apps breakdown with individual limits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'ỨNG DỤNG THEO DÕI',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                Text(
                  'ĐÃ DÙNG / HẠN MỨC',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            ...BlacklistConstants.defaultBlacklist.map((pkg) {
              final appName = BlacklistConstants.appNames[pkg] ?? pkg;
              final dur = tracker.appDistractions[pkg] ?? Duration.zero;
              final limit = tracker.getAppLimit(pkg);
              final isAppExceeded = tracker.isAppLimitExceeded(pkg);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('• $appName', style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                        if (isAppExceeded) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '⚠️ Quá hạn',
                            style: TextStyle(fontSize: 9, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${tracker.formatDuration(dur)} / ${limit}m',
                          style: TextStyle(
                            fontSize: 11,
                            color: isAppExceeded
                                ? const Color(0xFFEF4444)
                                : (dur.inSeconds > 0 ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8)),
                            fontWeight: dur.inSeconds > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showSetAppLimitDialog(pkg, appName),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2333),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Color(0xFFFFB300)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            const Text(
              '💡 Khi dùng quá hạn mức, hệ thống sẽ gửi thông báo đẩy (popup) nhắc nhở nghỉ ngơi.',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),

            // Overlay Permission and Setting Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.overlayService.hasPermission
                        ? widget.overlayService.openSettings()
                        : widget.overlayService.requestPermission(),
                    icon: Icon(
                      widget.overlayService.hasPermission ? Icons.settings : Icons.security,
                      size: 14,
                    ),
                    label: Text(
                      widget.overlayService.hasPermission ? 'Quản lý Overlay' : 'Cấp quyền Overlay',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.overlayService.hasPermission
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFFB300),
                      side: BorderSide(
                        color: widget.overlayService.hasPermission
                            ? const Color(0xFF10B981)
                            : const Color(0xFFFFB300),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => tracker.openSettings(),
                    icon: const Icon(Icons.tune, size: 14),
                    label: const Text('Cài đặt Sử dụng', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
