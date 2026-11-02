# Báo cáo nâng cấp Analytics — 2026-11-02

## A. Audit codebase

Flutter dùng ChangeNotifier/ListenableBuilder và SharedPreferences, không có
database migration hay thư viện biểu đồ. Dashboard dùng palette Flat dark theme.
Analytics mới tái sử dụng các thành phần này, không thêm dependency.

Các file/luồng đã kiểm tra:

- `lib/main.dart`: lifecycle, monitoring, DistractionGuard và khởi tạo controller.
- `lib/features/home/analytics_screen.dart`, `home_screen.dart`: route analytics.
- `lib/features/dashboard/services/analytics_service.dart`,
  `focus_history_service.dart` và ba card biểu đồ cũ.
- `lib/features/focus_session/focus_session_controller.dart`, `settlement.dart`:
  deadline, intervals, pause/resume, thắng/thua, retry và idempotent settlement.
- `lib/features/telemetry/screen_time_tracker.dart`: tracked packages, permission,
  Usage Events, foreground reducer và phân bổ thời gian sử dụng ứng dụng.
- `lib/core/services/persistent_preferences.dart`, `distraction_guard.dart`,
  `foreground_task_service.dart`, `overlay_service.dart`: persistence và blocker.
- `lib/core/game/player_state.dart`: ví, công trình và streak shield.
- `lib/core/widgets/flat_theme.dart`, `features/settings/settings_screen.dart`,
  `features/battle/battle_screen.dart`, `features/shell/app_shell.dart`.
- `android/app/src/main/kotlin/com/example/test_dart/MainActivity.kt`,
  `pubspec.yaml`, API package usage_stats đã cài và các regression tests liên quan.

| Chất lượng | Dữ liệu | Cách sử dụng |
|---|---|---|
| Available | Giây focus/ngày, số phiên hoàn thành đã settlement, tổng giờ | Giữ lịch sử trên lịch |
| Available | Tracked apps, Usage Access, Usage Events Android còn được OS giữ | Usage và lượt mở app được chọn |
| Derivable | Active intervals của timer đang chạy | Phân bổ ngày/giờ và loại thời gian pause |
| Missing trước nâng cấp | Goal history, từng phiên, outcome, first interruption | Thu thập cho phiên tương lai |
| Unreliable | Legacy interruption count: trước đây đếm foreground app bất kỳ và defeat | Không dùng để suy ra velocity/endurance |
| Unreliable | All-time hourly totals không có weekday/target/outcome | Không dùng làm điểm Golden Hours |

Vấn đề cũ: target ngày cố định 75 phút; Golden Hours lấy khung có nhiều phút nhất
làm 100%; phiên thua mất dấu thời gian thực tế do logic thưởng chỉ ghi sau khi
thắng cả trận; không có timestamp để suy ra survival.

## B. Triển khai và công thức

Đã triển khai và kiểm chứng tự động cả năm dashboard, đúng thứ tự:

| Dashboard | Biểu đồ và logic | Nguồn |
|---|---|---|
| Discipline Calendar | Lịch 7 cột từ T2; không hoạt động, <50%, 50–99%, ≥100% goal. Không goal dùng ngưỡng 30/60 phút. Viền chọn xanh, chấm đạt goal; chuyển tháng, chi tiết ngày | Legacy totals + journal, trừ phần journal đã settlement bằng ID |
| Golden Hours | Heatmap 7 slot × 7 weekday trong 30 ngày; từng ô cần ≥3 phiên. Score phiên = 0.5 × completed + 0.5 × min(active seconds / target seconds, 1); score ô là trung bình theo giây thực sự thuộc ô | Terminal session journal và active intervals |
| Focus Endurance | Kaplan–Meier S(t)=product(1−events/atRisk); cần ≥5 phiên có monitoring. Event = lượt mở app được chọn đầu tiên; hoàn thành theo kế hoạch right-censored; pause chủ động censor tại pause; hủy/thua sớm censor tại kết thúc nếu chưa có event | Timestamped session journal + Usage Events |
| Distraction Velocity | Line chart đủ miền 7 ngày, gap khi không có mẫu số. Rate = confirmed visits / active hours trong phiên có monitoring. KPI tuần là tỷ số tổng, không phải trung bình các tỷ số ngày | Terminal sessions với monitoring hợp lệ |
| Distraction Correlation | Scatter từng ngày; X=giờ dùng các app đang được chọn, Y=min(actual focus/goal,1)×100. Selector 7/30 ngày; Pearson r và OLS trendline chỉ khi ≥7 cặp hợp lệ và cả X/Y có phương sai | Usage Events Android + goal history + actual focus |

Calendar phân biệt ngày hoạt động với ngày đạt goal. Goal là opt-in, hiệu lực từ
ngày mai; thay đổi/tắt goal không viết lại lịch sử. Streak của dashboard chỉ tính
ngày đạt goal, không dùng game shield. Hôm nay có goal nhưng chưa đạt được giữ
streak từ hôm qua; hôm nay không có goal thì current streak bằng 0. Monthly rate
= ngày đạt / ngày có goal đã kết thúc, thêm hôm nay nếu đã đạt; loại ngày tương lai.

Median survival chỉ xuất hiện khi S≤0.5; nếu chưa đạt, hiển thị “Chưa xác định”.
Uninterrupted rate = phiên hoàn thành không event/không pause / toàn bộ phiên
kết thúc có monitoring trong 30 ngày; UI hiển thị mẫu số. Các censor do pause hoặc
hủy có thể mang tính chọn lọc, vì vậy đây là ước lượng mô tả, không đề xuất độ dài
Pomodoro tối ưu. Event và censor cùng thời điểm được giữ cùng risk set trước khi
cập nhật survival.

Previous-week velocity change = (current / previous − 1)×100; undefined khi
previous không tồn tại hoặc bằng 0. Không đồng nhất ngày thiếu dữ liệu với 0.

Correlation loại hôm nay, ngày không goal, dữ liệu invalid và lịch sử OS rỗng.
Yêu cầu có event trước ngày để khởi tạo trạng thái usage; ngày đầu retention không
đủ ngữ cảnh được loại. Minimum pairs có thể cấu hình qua AnalyticsService.
Pearson r = covariance / sqrt(varianceX×varianceY); trendline dùng least squares.
Không diễn giải tương quan thành quan hệ nhân quả.

## Data foundation và tính tương thích

- Journal riêng `fk_analytics_v1_session_*`: UTC start/end, target, active intervals,
  pause/resume, lifecycle, interruptions, monitoring coverage, outcome và reason.
- Lifecycle đơn thuần không phải interruption. Kết thúc phiên đối chiếu raw Usage
  Events để bắt lượt mở ngắn, loại duplicate resumes, pause và ứng dụng không chọn.
  Thiếu permission hoặc query lỗi làm session không đủ coverage cho distraction.
- Ghi tuần tự, lỗi hiện trong UI, giữ bản ghi lỗi trong RAM và có nút retry.
- Không xóa/đổi legacy keys. Settlement thêm metadata tùy chọn `analyticsIds` và
  `analyticsCredits`, parser đọc được snapshot cũ; không có DB migration.
- Focus thực tế = legacy settled seconds + journal seconds − journal seconds đã
  settlement. Trừ theo ngày gốc trong credit ledger rồi phân bổ journal theo
  timezone hiện tại, tránh đếm đôi hoặc bỏ sót khi đổi timezone.
- Thời gian của phiên hủy/thua vẫn là focus thực tế trong analytics; quy tắc thưởng,
  tổng giờ được thưởng, timer, HP/tax, blocker và game streak giữ nguyên.
- Không có mock data production. Fixtures chỉ nằm trong tests.
- Android usage chỉ query một khoảng 7/30 ngày cộng một ngày seed; terminal tracking
  chỉ query khoảng của phiên. Cache parsed session snapshots; chart calculations
  chạy trong service, không trong build. Mỗi card giữ widget riêng và chỉ dựng lại
  khi snapshot dữ liệu của card thay đổi.
- UI có loading/error/retry, empty/insufficient states, touch details, tooltip,
  semantic labels và vùng lịch/heatmap cuộn ngang khi cần.

## C. Files changed

Created:

- `docs/analytics-upgrade.md`
- `lib/features/dashboard/services/analytics_calculations.dart`
- `lib/features/dashboard/services/analytics_journal.dart`
- `lib/features/dashboard/widgets/analytics_chart.dart`
- `lib/features/dashboard/widgets/discipline_calendar_card.dart`
- `lib/features/dashboard/widgets/focus_endurance_card.dart`
- `test/analytics_calculations_test.dart`
- `test/analytics_journal_test.dart`
- `test/analytics_widgets_test.dart`

Modified:

- `lib/core/widgets/flat_theme.dart`: hai màu analytics dùng chung.
- `lib/features/dashboard/services/analytics_service.dart`
- `lib/features/dashboard/services/focus_history_service.dart`
- `lib/features/dashboard/widgets/golden_hours_card.dart`
- `lib/features/dashboard/widgets/distraction_velocity_card.dart`
- `lib/features/dashboard/widgets/correlation_chart_card.dart`
- `lib/features/focus_session/focus_session_controller.dart`
- `lib/features/focus_session/settlement.dart`
- `lib/features/home/analytics_screen.dart`
- `lib/main.dart`
- `test/analytics_metrics_test.dart`
- `test/project_review_regression_test.dart`
- `test/settlement_test.dart`
- `test/storage_failure_test.dart`
- `test/tracked_apps_test.dart`

Deleted: không có. Các thay đổi có sẵn của người dùng về font, assets, pubspec,
sprite_anim và tài liệu UI không thuộc thay đổi Analytics. Đã chạy `dart format .`,
sau đó khôi phục các chỉnh sửa chỉ-format ở file ngoài phạm vi để giữ diff gọn.

## D. Kết quả kiểm thử

- `flutter pub get`: exit 0, không thêm hoặc nâng dependency.
- `dart format .`: exit 0; sau đó format lại các file trong phạm vi.
- `flutter analyze`: exit 0, **No issues found** (`analytics-analyze.log`).
- `flutter test --reporter expanded`: exit 0, **204 tests passed**, toàn bộ suite
  gồm unit và widget (`analytics-tests.log`).
- Riêng bốn file analytics tests: 28 cases; widget checks gồm route/order, empty,
  insufficient, calendar 28/29/30/31 ngày, năm nhuận, chuyển tháng/chọn ngày,
  tooltip và touch details; 320/412 px với text scale 200%, không RenderFlex overflow.
- Unit checks gồm golden overlap/weight/sample threshold, goal/streak, legacy merge,
  pause/cancellation, first event, censor/ties/median, velocity zero denominator,
  Pearson invalid/zero variance, DST elapsed offsets, midnight và đổi timezone.
- Storage failure/retry và đổi correlation range trong lúc query đang chờ có
  regression tests. Hai findings từ review độc lập đã sửa và review lại.
- `flutter build apk --debug`: **native Flutter exit 0**. APK:
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Build còn cảnh báo package `usage_stats` dùng Kotlin Gradle Plugin; Flutter báo
  tương thích Built-in Kotlin cho phiên bản tương lai. Không chặn debug build.
  PowerShell ban đầu quy stderr warning thành exit 1; đã chạy lại và kiểm tra
  trực tiếp `$LASTEXITCODE` của Flutter bằng 0 trước khi xác nhận build.
- `git diff --check`: exit 0.

## E. Giới hạn và trạng thái xác minh

Implemented and verified: cả năm dashboard, công thức, tracking tích hợp,
backward-compatible persistence, automated suite và Android debug compilation.

Implemented but not verified on device: OEM Usage Events completeness, permission
revocation/background process behavior trên điện thoại thật, TalkBack thủ công,
timezone/DST hệ thống thực, và UI runtime. Có thiết bị Android kết nối nhưng không
cài đè/chạy ứng dụng lên dữ liệu người dùng trong nhiệm vụ này. Chưa build release.

Historical data limitation: không backfill first interruption, goal, outcome hoặc
weekday efficiency từ các aggregate cũ. Các metrics đó chờ dữ liệu phiên mới.
Không tái tạo timezone gốc cho legacy dates thiếu timestamp. Usage Events có thể
bị OS giới hạn retention; không đảm bảo đủ 30 ngày, không tự điền lịch sử còn thiếu.

Partially observable: chỉ đo interruptions qua app được chọn mà Android ghi nhận;
không thể đo suy nghĩ mất tập trung hoặc gián đoạn ngoài đời. Pause/cancellation
censoring có thể gây selection bias. Không gọi đây là phép đo mọi gián đoạn.

Storage limitation: SharedPreferences vốn nạp snapshot vào RAM. Calendar/streak
toàn thời gian cần aggregate lịch sử journal; chưa có indexed database hoặc
benchmark nhiều năm dữ liệu. Phiên bị kill trước terminal timestamp bị loại khỏi
session analytics; không tự gán thời gian kết thúc. Bản ghi retry trong RAM sẽ mất
nếu storage đang lỗi và process bị kill trước khi lưu lại, nhưng dữ liệu cũ không
bị xóa hay thay thế bởi dữ liệu giả.

Not implemented intentionally: lịch sử giả, suy đoán optimal Pomodoro, suy luận
nhân quả, thay database hoặc nâng cấp package ngoài phạm vi.

Tham chiếu phương pháp: [NIST Kaplan–Meier](https://itl.nist.gov/div898/handbook/apr/section2/apr215.htm),
[NIST correlation](https://www.itl.nist.gov/div898/software/dataplot/refman2/ch2/correlat.pdf).
