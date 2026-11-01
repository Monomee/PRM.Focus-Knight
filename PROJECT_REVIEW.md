# Review dự án FocusKnight

Ngày review ban đầu: 2026-10-28.

Cập nhật gần nhất: 2026-10-31.

Tài liệu này tổng hợp 13 vấn đề đã báo cáo trong phiên review và trạng thái xử lý hiện tại. Sau phúc tra nhánh `camtu`, các lỗi còn lại ở mục 1, 5, 7 và 8 đã được sửa bổ sung. Đợt cải thiện tiếp theo đã xử lý mục 9, 10 và 13; mục 12 đã có cấu hình ký riêng, chờ chủ dự án cung cấp khóa. Phần nghiệm thu thiết bị thật ở mục 11 do chủ dự án thực hiện.

## Phạm vi và kết quả kiểm tra

FocusKnight là ứng dụng Pomodoro kết hợp game pixel: hoàn thành trận để nhận tài nguyên, nâng làng và mở nhân vật. Đánh giá kỹ thuật dựa trên mô hình hiện tại: dữ liệu lưu trên một điện thoại Android, không có máy chủ.

Đã đọc mã Dart trong `lib/`, các test, phần Android tùy chỉnh, công cụ tạo icon và tài liệu; rà soát thêm cấu hình các nền tảng còn lại.

Kết quả tại thời điểm review ban đầu:

- `flutter analyze --no-pub`: không phát hiện lỗi.
- `flutter test --no-pub`: 99 test đạt.

Kết quả sau đợt sửa bổ sung ngày 2026-10-31:

- `flutter analyze --no-pub`: không phát hiện lỗi.
- `flutter test --no-pub`: 132 test đạt.
- `flutter build apk --debug --no-pub`: đạt, cài và chạy trên Samsung SM-G781N, Android 13 qua USB.
- `git diff --check`: đạt.

Kết quả đợt cải thiện mục 9–13 cùng ngày:

- `flutter analyze --no-pub`: không phát hiện lỗi.
- `flutter test --no-pub`: **146 test đạt** (thêm 15 test hồi quy, bỏ 1 placeholder).
- `flutter build apk --debug --no-pub`: đạt; APK cuối đã cài cập nhật qua `adb install -r` lên Samsung SM-G781N, Android 13, giữ dữ liệu ứng dụng.
- Khởi động qua ADB trả `Status: ok`; Activity ở trạng thái resumed, tiến trình còn chạy; không thấy `FATAL EXCEPTION`, `Unhandled Exception` hoặc `E/flutter` trong 300 dòng log gần nhất của tiến trình. Đây là smoke test, không thay nghiệm thu mục 11.
- Đã tái hiện lỗi callback trễ và ghi lịch sử sai ngày trước khi sửa; bổ sung test giờ nghỉ, pause tự hết, phần lẻ giây, qua nửa đêm và retry sau khi lịch sử đã ghi bền vững.
- Review độc lập phát hiện thêm thao tác skip/bỏ cuộc đến trễ; đã tái hiện bằng test và sửa để không kéo dài phiên hoặc làm mất thưởng của trận đã hoàn thành.
- Gradle `:app:preReleaseBuild --offline`: dừng đúng dự kiến khi thiếu khóa release, chỉ rõ cần `android/key.properties`.
- Kiểm tra quy tắc Git: `android/key.properties`, `*.jks`, `*.keystore` trong `android/` đều bị ignore.
- `git diff --check`: đạt. Chi tiết: [review-improvements](docs/reviews/2026-10-31-review-improvements.md).

Đã kiểm tra thêm trên thiết bị thật cho khóa màn hình, overlay khi thắng trận, cảnh báo vượt hạn khi YouTube mở liên tục và nạp hạn mức cài đặt. Chưa kiểm tra mọi tình huống trên mọi phiên bản Android/OEM. Báo cáo phúc tra trước khi sửa được giữ tại [camtu-verification](docs/reviews/2026-10-31-camtu-verification.md).

Điểm tốt: luật game tách khỏi giao diện, tái sử dụng component hợp lý và có test cho nhiều luồng chính. Ưu tiên cải thiện độ tin cậy của dữ liệu, chống xao nhãng và thống kê.

## Đã khắc phục

### 1. Lỗi lưu dữ liệu bị bỏ qua nhưng vẫn đánh dấu đã trả thưởng

Trạng thái: **Đã sửa**.

Vị trí chính: [player_state.dart](lib/core/game/player_state.dart), [focus_history_service.dart](lib/features/dashboard/services/focus_history_service.dart), [settlement.dart](lib/features/focus_session/settlement.dart), [focus_session_controller.dart](lib/features/focus_session/focus_session_controller.dart).

- Settlement hiện dùng hàng đợi tuần tự để các khoản trả thưởng không ghi đè hoặc chạy chồng lên nhau.
- Mỗi bước ghi lịch sử và ví có `settlementId` riêng. Ví và lịch sử lưu danh sách ID đã áp dụng để retry không cộng trùng nếu ứng dụng dừng giữa side effect và bước cập nhật journal.
- Tiến độ settlement chỉ được cập nhật sau khi bước tương ứng lưu thành công; bản ghi chờ được giữ lại khi có lỗi.
- Số dư trong bộ nhớ chỉ thay đổi sau khi trạng thái ví bền vững đã được ghi thành công.
- Có hỗ trợ đọc bản ghi pending theo định dạng cũ.
- Khoản thưởng mới được lưu vào journal trước khi xử lý khoản cũ đang lỗi. Retry dùng cùng ID, không tạo khoản thưởng thứ hai.
- Xây làng và nhận thưởng dùng chung hàng đợi ghi ví; số dư, cấp công trình và ngày xây Kho lương được lưu cùng snapshot, không hoàn lại tiền đã chi sau khi nạp lại.
- Getter thống kê đọc snapshot lịch sử đã ghi thành công, có fallback dữ liệu cũ; không phụ thuộc các khóa phụ chưa kịp đồng bộ khi tiến trình bị tắt.
- Khi ghi thất bại, cache bị đánh dấu chưa tin cậy cho đến khi đọc phục hồi thành công, kể cả khi lần đọc phục hồi đầu tiên cũng lỗi.
- Nếu lần ghi journal đầu tiên lỗi, controller giữ khoản thưởng, hiển thị nút thử lại ở kết quả/Trang chủ và ngăn bắt đầu trận mới làm mất khoản này.

### 2. Số phút hôm qua có thể bị cộng sang hôm nay

Trạng thái: **Đã sửa**.

Vị trí chính: [focus_history_service.dart](lib/features/dashboard/services/focus_history_service.dart).

- Mỗi phiên hoàn thành lấy ngày hiện tại tại thời điểm ghi và đọc số giây từ đúng khóa của ngày đó trước khi cộng.
- Cache `todayFocusSeconds` được cập nhật bằng dữ liệu của ngày vừa ghi, không tiếp tục dùng tổng của ngày trước khi ứng dụng chạy qua nửa đêm.
- Clock có thể được inject để kiểm thử hồi quy đổi ngày.

### 3. Thống kê trình bày dữ liệu mẫu như dữ liệu cá nhân

Trạng thái: **Đã sửa**.

Vị trí chính: [analytics_service.dart](lib/features/dashboard/services/analytics_service.dart), [correlation_chart_card.dart](lib/features/dashboard/widgets/correlation_chart_card.dart), [distraction_velocity_card.dart](lib/features/dashboard/widgets/distraction_velocity_card.dart), [golden_hours_card.dart](lib/features/dashboard/widgets/golden_hours_card.dart).

- Đã bỏ các baseline và xu hướng mẫu khỏi báo cáo thật.
- Dữ liệu MXH dùng `null` cho trạng thái chưa có dữ liệu; giá trị `0` được giữ đúng nghĩa là đã đo và không sử dụng.
- Không còn tự thay thời gian tập trung bằng 1,2 giờ hoặc số lần xao nhãng bằng 2.
- Không còn kết luận “40%/95%” viết cố định.
- Khi chưa đủ dữ liệu, các card hiển thị trạng thái thiếu dữ liệu thay vì tạo nhận xét cá nhân.

### 4. Khóa màn hình sau khi mở app bị chặn vẫn có thể bị phạt

Trạng thái: **Đã sửa; ca khóa màn hình đã đạt trên Samsung Android 13**.

Vị trí chính: [screen_time_tracker.dart](lib/features/telemetry/screen_time_tracker.dart), [main.dart](lib/main.dart).

- Detector foreground hiện dựng trạng thái từ cả sự kiện resume, pause, màn hình interactive/non-interactive và keyguard shown/hidden.
- Khi ứng dụng bị pause, app khác được resume, màn hình tắt hoặc khóa máy, package cũ được xóa đúng cách.
- Guard nhận `null` khi không còn app blacklist thực sự hoạt động nên dừng thời gian ân hạn và không tiếp tục phạt.
- Polling được tuần tự hóa; cửa sổ overlap và dedupe sự kiện tránh bỏ event UsageStats trả về trễ hoặc áp dụng lặp.

### 5. Cảnh báo hạn mức có thể bỏ lỡ lúc người dùng vượt hạn

Trạng thái: **Đã sửa; ca vượt hạn khi dùng liên tục đã đạt trên Samsung Android 13**.

Vị trí chính: [screen_time_tracker.dart](lib/features/telemetry/screen_time_tracker.dart), [main.dart](lib/main.dart).

- Trạng thái package foreground được giữ giữa các lần polling thay vì chỉ tìm sự kiện mở trong một cửa sổ ngắn.
- Package chỉ bị xóa khi có sự kiện rời app, app khác được mở, tắt màn hình hoặc khóa máy.
- Cảnh báo hạn mức vì vậy vẫn có thể kích hoạt khi người dùng mở app dưới hạn rồi tiếp tục dùng đến lúc vượt hạn.
- Main ngăn các lượt kiểm tra async chạy chồng nhau.
- Thời gian trong ngày được dựng từ UsageEvents, gồm cả khoảng app vẫn đang mở; dừng cộng khi pause, khóa máy hoặc tắt màn hình. Không còn chờ aggregate cập nhật sau khi rời app.
- Query lấy dữ liệu trước đầu ngày để nhận biết phiên qua nửa đêm, nhưng chỉ cộng thời gian thuộc ngày hiện tại; polling có overlap và dedupe.
- Bộ đếm tự bắt đầu khi quyền usage được cấp sau khởi động.
- Ca USB: YouTube ban đầu 4m51s, hạn mức 6 phút; mở liên tục 90 giây, không có cảnh báo ở 45 giây, có thông báo vượt hạn ở 90 giây mà không mở lại app.

### 6. Overlay chưa được đóng khi thắng trận trong app bị chặn

Trạng thái: **Đã sửa**.

Vị trí chính: [main.dart](lib/main.dart), [overlay_service.dart](lib/core/services/overlay_service.dart), [blocker_overlay_widget.dart](lib/features/overlay/blocker_overlay_widget.dart).

- Main theo dõi chuyển trạng thái từ đang trong trận sang kết thúc trận.
- Khi thắng hoặc kết thúc không phải thất bại, guard được reset và overlay đóng ngay dù app blacklist vẫn ở foreground.
- Khi thất bại, trạng thái thất bại vẫn được gửi cho overlay để giữ hành vi hiển thị trong năm giây.

### 7. Khung giờ vàng có thể hiển thị sai khung giờ cao nhất

Trạng thái: **Đã sửa**.

Vị trí chính: [analytics_service.dart](lib/features/dashboard/services/analytics_service.dart), [golden_hours_card.dart](lib/features/dashboard/widgets/golden_hours_card.dart).

- Khung `00h–05h` được tách riêng, không còn bị gộp vào nhãn `21h–24h`.
- `peakTimeSlot` được lấy trực tiếp từ khung có tổng thời gian cao nhất nên các khung `11h–14h` và `21h–24h` không còn rơi về mặc định buổi sáng.
- Khi không có dữ liệu, ứng dụng không tự chọn một khung giờ mặc định hoặc tạo lời khuyên.
- Chọn khung từ tổng phút gốc trước khi làm tròn tỷ lệ, nên 599 phút không thắng khung 600 phút.

### 8. Ô nhập hạn mức bị ghi đè trong lúc đang sửa

Trạng thái: **Đã sửa**.

Vị trí chính: [settings_screen.dart](lib/features/settings/settings_screen.dart).

- Ô nhập theo dõi focus, trạng thái draft đã thay đổi và giá trị cấu hình đồng bộ gần nhất.
- Notification định kỳ từ tracker hoặc overlay không ghi đè khi người dùng đang focus hoặc có draft chưa lưu.
- Nội dung chỉ được đồng bộ khi hạn mức cấu hình thực sự thay đổi và field đang sạch, không có focus.
- Listener, controller và `FocusNode` được giải phóng đầy đủ.
- Baseline đồng bộ được khởi tạo trước khi đăng ký listener; lần nạp đầu hiển thị đúng cấu hình 240 thay vì giữ mặc định 60.

## Cải thiện bổ sung và nghiệm thu còn chờ

### 9. Đồng hồ cần dựa trên thời gian đã trôi qua

Trạng thái: **Đã sửa; kiểm thử tự động đạt, chờ nghiệm thu chạy nền thực tế ở mục 11**.

Vị trí: [focus_session_controller.dart](lib/features/focus_session/focus_session_controller.dart), [main.dart](lib/main.dart).

- Mỗi giai đoạn dùng mốc kết thúc; callback chỉ tính lại thời gian còn lại, làm tròn lên để không kết thúc sớm phần lẻ giây.
- Callback đến trễ bù các giai đoạn focus/nghỉ đã trôi qua, bao gồm nghỉ dài và thời gian focus sau khi pause tự hết 5 phút.
- Tiếp tục thủ công chỉ loại đúng thời gian đã tạm dừng; không mất phần lẻ giây.
- Đồng bộ lại khi ứng dụng trở về foreground và trước khi áp dụng guard chạy nền. Skip và bỏ cuộc cũng đồng bộ trước khi xử lý, tránh thao tác cũ tác động sai giai đoạn.
- Chỉ xử lý khi tiến trình còn sống; không khôi phục trận đang chơi sau khi tiến trình bị tắt.

### 10. Lịch sử phiên thiếu thời điểm thực tế

Trạng thái: **Đã sửa cho các phiên mới; dữ liệu cũ không có timestamp giữ fallback cũ**.

Vị trí: [focus_session_controller.dart](lib/features/focus_session/focus_session_controller.dart), [settlement.dart](lib/features/focus_session/settlement.dart), [focus_history_service.dart](lib/features/dashboard/services/focus_history_service.dart).

- Quỹ trận và journal giữ các khoảng bắt đầu/kết thúc tập trung của từng phiên, loại trừ thời gian pause. Journal lưu timestamp UTC, phân bổ thống kê theo giờ địa phương lúc xử lý.
- Khi thắng, số giây được chia theo ranh giới giờ/ngày thực tế. Mỗi phiên được đếm một lần vào ngày hoàn thành; ngày có giây tập trung được thêm vào lịch và streak.
- Retry/khôi phục trả thưởng hôm sau giữ nguyên timestamp, không dồn dữ liệu sang ngày retry, không cộng trùng lịch sử hoặc ví.
- Giữ tổng số giây chính xác khi chia các khoảng có phần lẻ giây. Kiểm tra khoảng bị đảo, chồng lấn hoặc không khớp thời lượng trước khi ghi.
- Journal cũ thiếu timestamp vẫn đọc được theo cách cũ. Không suy đoán hay sửa lại phân bố lịch sử đã ghi trước đợt này.

### 11. Kiểm thử thiết bị thật cho các luồng nền quan trọng

Trạng thái: **146 unit/widget test đạt; chủ dự án sẽ thực hiện phần nghiệm thu Android thật**.

Vị trí: thư mục [test](test), đặc biệt [analytics_metrics_test.dart](test/analytics_metrics_test.dart), [focus_history_test.dart](test/focus_history_test.dart), [settlement_test.dart](test/settlement_test.dart), [foreground_detection_test.dart](test/foreground_detection_test.dart) và [settings_screen_test.dart](test/settings_screen_test.dart).

- Đã thêm test hồi quy cho analytics không tạo dữ liệu mẫu, đổi ngày, lỗi và retry settlement, tính idempotent của trả thưởng, chuỗi sự kiện foreground/khóa màn hình và draft hạn mức.
- Bộ test hiện có 146 test đạt, gồm lỗi ghi/đọc phục hồi, retry sau side effect, ghi đồng thời, UsageEvents khi app còn mở, khóa màn hình, đổi ngày, cấp quyền sau khởi động và hồi quy timer/timestamp mới.
- Đã chạy các ca khóa máy, vượt hạn khi app mở lâu và kết thúc trận khi overlay hiển thị trên Samsung Android 13. Còn cần kiểm tra luồng cấp quyền lần đầu trên thiết bị mới và các OEM/phiên bản khác.
- Cần kiểm tra trên nhiều phiên bản Android/OEM vì thời điểm UsageStats phát sự kiện có thể khác nhau.
- Chủ dự án cần kiểm tra thêm: khóa màn hình và bật tiết kiệm pin trong phiên/nghỉ/pause; bật lại sau hạn kết thúc; cấp quyền lần đầu trên máy mới. Không xóa dữ liệu hoặc thu hồi quyền trên điện thoại hiện tại để giả lập máy mới.

### 12. Cấu hình ký bản release riêng

Trạng thái: **Đã cấu hình; chờ khóa riêng của chủ dự án để build/kiểm tra bản release chính thức**.

Vị trí: [build.gradle.kts](android/app/build.gradle.kts), [key.properties.example](android/key.properties.example), [README.md](README.md#ký-bản-phát-hành-android).

- Release dùng signing config riêng, đọc `storeFile`, `storePassword`, `keyAlias`, `keyPassword` từ file `android/key.properties` bị ignore.
- Thiếu giá trị cấu hình sẽ bị chặn ở `preReleaseBuild`; không rơi về khóa debug và không tạo release unsigned do thiếu khóa. Debug vẫn build được khi chưa có khóa release.
- Có file mẫu và hướng dẫn tạo/sao lưu khóa ngoài Git. Không tự tạo khóa production hoặc điền mật khẩu thay chủ dự án.
- Chưa có `android/key.properties` trên môi trường hiện tại, nên chưa kiểm tra chữ ký APK/AAB release bằng khóa thật.

## Đã tinh gọn

### 13. Bỏ dependency không dùng và test placeholder

Trạng thái: **Đã xử lý**.

- Bỏ `cupertino_icons` khỏi `pubspec.yaml` và lockfile vì mã ứng dụng không dùng.
- Xóa `test/widget_test.dart` chỉ kiểm tra `1 + 1 == 2`.
- Resolve dependency bằng cache offline; không nâng các package khác, không thêm dependency mới.

## Thứ tự ưu tiên hiện tại

Các phần sửa mã ở mục 1–10 và 13 đã được xử lý. Công việc còn lại:

1. Mở rộng kiểm thử các luồng UsageStats, khóa màn hình, cảnh báo hạn mức và overlay sang Android/OEM khác và cấp quyền lần đầu.
2. Nghiệm thu timer khi khóa màn hình/tiết kiệm pin, bao gồm pause tự hết và các giai đoạn đã hết hạn.
3. Chủ dự án cấu hình khóa release riêng, sao lưu khóa/mật khẩu và kiểm tra APK/AAB đã ký trước khi phân phối.

Chưa có lý do từ mã hiện tại để thay toàn bộ cách quản lý state hoặc thêm framework mới.

## Yêu cầu đã xác nhận và nội dung còn chờ

- Chủ dự án đã xác nhận: **Android tắt tiến trình hoặc người dùng vuốt đóng ứng dụng giữa trận = bỏ cuộc**. Không xem việc thiếu khôi phục trận là lỗi.
- Khôi phục khoản trả thưởng của một trận đã thắng là luồng khác với khôi phục trận đang chơi.
- Chủ dự án sẽ bổ sung yêu cầu hiện hành vì các tài liệu đang khác nhau. Chưa lấy `PROJECT_OVERVIEW.md` hoặc tài liệu khác làm chuẩn duy nhất để kết luận luật game đúng/sai.
- Đánh giá luật thưởng, mở khóa và đề xuất tính năng mới còn chờ yêu cầu hiện hành.

## Giới hạn kiểm tra và rủi ro

Chưa kiểm tra APK release, Android/OEM khác, pin/FPS, từng ảnh/font và từng dòng scaffold native của các nền tảng phụ.

Timer dùng mốc `DateTime`; chưa nghiệm thu tình huống người dùng chỉnh giờ hệ thống hoặc đổi múi giờ giữa trận/giữa các lần retry. Dữ liệu cũ không có timestamp không thể phân bổ lại chính xác. Các cảnh báo build hiện có về Kotlin plugin của `usage_stats` và SDK XML chưa được xử lý trong phạm vi này.

Các thay đổi đã vượt qua unit/widget test, static analysis và các ca USB nêu trên; không suy rộng một Samsung Android 13 thành mọi thiết bị. SharedPreferences không phải cơ sở dữ liệu giao dịch; cần mở rộng kiểm thử kill tiến trình tại các bước ghi thực tế. Nếu bộ nhớ không thể ghi ngay journal đầu tiên, phần thưởng được giữ trong tiến trình và UI yêu cầu thử lại trước khi đóng ứng dụng; không thể bảo đảm dữ liệu bền vững khi thiết bị hoàn toàn không ghi được.
