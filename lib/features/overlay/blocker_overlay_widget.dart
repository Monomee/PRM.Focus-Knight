import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Full-screen overlay blocker displayed when user leaves active focus session
/// or exceeds daily distraction limits.
/// Uses 100% opaque backdrop and centered card to eliminate any misaligned edges.
class BlockerOverlayWidget extends StatelessWidget {
  final String reason;

  const BlockerOverlayWidget({
    super.key,
    this.reason = 'Focus session in progress! Return to keep your knight fighting.',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF090B10), // 100% solid opaque dark void backdrop
      child: SafeArea(
        child: SizedBox.expand(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Warning Icon with pulsating ring
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        border: Border.all(color: const Color(0xFFEF4444), width: 2),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: Color(0xFFEF4444),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Warning Title
                    const Text(
                      'DISTRACTION BLOCKED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Color(0xFFEF4444),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Subtitle / Reason
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // "Return to Focus" Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Launch FocusKnight back to foreground and close overlay
                          FlutterForegroundTask.launchApp('/');
                          await FlutterOverlayWindow.closeOverlay();
                        },
                        icon: const Icon(Icons.arrow_back, size: 20),
                        label: const Text(
                          'RETURN TO FOCUS',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Secondary dismiss button
                    TextButton(
                      onPressed: () async {
                        await FlutterOverlayWindow.closeOverlay();
                      },
                      child: const Text(
                        'Dismiss Overlay',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
