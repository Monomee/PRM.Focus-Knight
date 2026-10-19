import 'dart:async';
import 'package:flutter/material.dart';

/// 15-second mindful pause before abandoning a focus session.
class MindfulInterruptionDialog extends StatefulWidget {
  final ValueChanged<String> onConfirmAbandon;
  final VoidCallback onResumeFocus;

  const MindfulInterruptionDialog({
    super.key,
    required this.onConfirmAbandon,
    required this.onResumeFocus,
  });

  @override
  State<MindfulInterruptionDialog> createState() => _MindfulInterruptionDialogState();
}

class _MindfulInterruptionDialogState extends State<MindfulInterruptionDialog> {
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
