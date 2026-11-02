# Analytics UI + isolated demo — 2026-11-02

## UI

Giữ nguyên năm dashboard và thứ tự. Card dùng header gọn, KPI lớn, biểu đồ và
tối đa một câu hỗ trợ. Công thức, sample thresholds và giới hạn nằm trong sheet
mở bằng nút thông tin. Chạm ngày/điểm/ô mở sheet chi tiết.

- Calendar bỏ chiều rộng tối thiểu 336 px: 7 cột theo card, xanh tăng dần,
  viền chọn xanh dương, chấm đạt goal, ba KPI tiếng Việt và legend nhỏ.
- Golden Hours bỏ grid cố định 440 px: Table 7 weekday × 7 slot, nhãn giờ ngắn.
  Chữ lớn dùng marker thay số trong ô khi thiếu chiều rộng; số đầy đủ vẫn có
  trong semantics và sheet. Empty state không dựng 49 ô trống.
- Endurance giữ Kaplan–Meier, median unavailable là dấu gạch, cyan, curve gọn.
- Velocity giữ missing samples và miền 7 ngày. Mức thấp xanh, vừa amber, cao coral;
  thay đổi giảm xanh/tăng đỏ, có icon và từ chỉ hướng.
- Correlation giữ selector, scatter, r/trendline hợp lệ; phương pháp ở sheet.
- Chart trục Y đo chiều rộng bằng font/text scaler thực để tránh nhãn xuống dòng.
  Bỏ danh sách ExpansionTile dài dưới từng chart; giữ touch/semantic details.

## Demo architecture / isolation

`DemoAnalytics.create(now: ...)` tạo một snapshot trong RAM cho 30 ngày gần nhất.
Không dùng random; cùng reference clock tạo cùng events. Screen tạo đúng một lần
khi người dùng bật “Xem dữ liệu mẫu”; mặc định OFF và không persist toggle.
App bar luôn có badge DEMO khi bật, cùng nhãn “Dữ liệu mô phỏng”. Tắt trả ngay về
service thật đang có, không trộn dữ liệu. Ví dụ đầu tháng, lịch demo mở tháng chứa
phần lớn khoảng 30 ngày để người dùng nhìn được heatmap.

Fixtures gồm goal 120 phút, phiên 25–50 phút, active intervals, pause/censoring,
interruption timestamps và simulated app-usage intervals. Có ngày mạnh/yếu,
nghỉ, phiên hủy, ngày hiện tại chưa đạt goal, và phiên qua nửa đêm. Afternoon
thường hiệu quả nhất nhưng không luôn hoàn hảo. Không tạo dữ liệu sau clock.
Tổng usage theo ngày được cộng từ usage intervals, gồm các lượt mở trong phiên.

`AnalyticsService.fromSamples` không tạo FocusHistoryService hoặc đăng ký journal
listener. Bước `_aggregateSessions` được tách nguyên công thức từ loader hiện có
để real/demo dùng chung. Preview refresh/range selector chỉ tính dữ liệu RAM.
Không gọi SharedPreferences, Usage Access, tracker, blocker, player hoặc settlement.
Goal editor bị ẩn và có guard trong demo; retry không gọi journal với preview.

Không đổi schema, session journal, timer, reward/blocker hoặc dependency.

## Files changed trong lần UI/Demo này

Created:

- `lib/features/dashboard/services/demo_analytics.dart`
- `test/analytics_demo_test.dart`
- `test/analytics_demo_widgets_test.dart`
- `docs/analytics-ui-demo.md`

Modified:

- `lib/core/widgets/flat_theme.dart`
- `lib/features/dashboard/services/analytics_service.dart`
- `lib/features/home/analytics_screen.dart`
- `lib/features/dashboard/widgets/analytics_chart.dart`
- `lib/features/dashboard/widgets/discipline_calendar_card.dart`
- `lib/features/dashboard/widgets/golden_hours_card.dart`
- `lib/features/dashboard/widgets/focus_endurance_card.dart`
- `lib/features/dashboard/widgets/distraction_velocity_card.dart`
- `lib/features/dashboard/widgets/correlation_chart_card.dart`
- `test/analytics_widgets_test.dart`

Deleted: không có. Các thay đổi từ nhiệm vụ Analytics trước và assets/font của
người dùng vẫn được giữ, không phải thay đổi mới của lần này.

## Verification

- `flutter analyze`: exit 0, No issues found (`analytics-redesign-analyze.log`).
- `flutter test --reporter expanded`: exit 0, **210 tests passed**, bao gồm toàn bộ
  regression suite timer/blocker/rewards (`analytics-redesign-full-tests.log`).
- `flutter build apk --debug`: native exit 0 (`analytics-redesign-build.log`).
  Artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: exit 0.
- Demo tests: default real, on/off, goal editor disabled, exact preferences snapshot
  unchanged (including wallet/goals/tracked apps), zero UsageStats calls during
  preview/range/refresh, deterministic raw sessions, totals/goals/streak, Golden
  Hours, KM, interruptions/hour, app usage and correlation consistency.
- Boundary tests: current day before study begins, partially elapsed session,
  midnight allocation, no session or usage interval after reference clock.
- UI tests: populated 320/390 px at 200% text, empty 320/412 px at 200%, no horizontal
  scroll or overflow, seven columns visible, date and heatmap details, selector,
  demo label and route order. Existing leap-month calendar checks retained.
- Populated screenshot uses SDK Roboto/Material Icons and fixed clock 2026-11-30
  12:00: `build/analytics-preview/demo-dashboard.png`. Reviewed visually.
- Independent read-only review found no important isolation/correctness defect.

## Remaining limitations

UI mới chưa cài/chạy trên điện thoại thật; TalkBack chưa kiểm tra thủ công.
Chưa build release cho lần UI/Demo này. Debug build còn warning KGP của package
usage_stats hiện có; không chặn biên dịch.

Demo không bổ sung bất kỳ lịch sử thật nào. Khoảng correlation 30 ngày loại hôm
nay nên có tối đa 29 ngày demo đủ cặp: ngày sớm hơn fixture được giữ là missing.
Giá trị preview thay theo reference clock khi mở lại screen; tests/ảnh cố định clock.
Màn hình chữ lớn có thể cao hơn để giữ chữ đọc được; không ép nhỏ text để vừa grid.
