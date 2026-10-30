# Review dự án FocusKnight

Ngày review ban đầu: 2026-10-28.

Cập nhật gần nhất: 2026-10-31.

Tài liệu này tổng hợp 13 vấn đề đã báo cáo trong phiên review và trạng thái xử lý hiện tại. Tám mục trong phần "Cần sửa" đã được khắc phục; các mục "Nên cải thiện" và "Có thể tinh gọn" vẫn là công việc còn lại.

## Phạm vi và kết quả kiểm tra

FocusKnight là ứng dụng Pomodoro kết hợp game pixel: hoàn thành trận để nhận tài nguyên, nâng làng và mở nhân vật. Đánh giá kỹ thuật dựa trên mô hình hiện tại: dữ liệu lưu trên một điện thoại Android, không có máy chủ.

Đã đọc toàn bộ 39 file Dart trong `lib/`, 22 file test, phần Android tùy chỉnh, công cụ tạo icon và tài liệu; rà soát thêm cấu hình các nền tảng còn lại.

Kết quả tại thời điểm review ban đầu:

- `flutter analyze --no-pub`: không phát hiện lỗi.
- `flutter test --no-pub`: 99 test đạt.

Kết quả sau khi khắc phục tám mục "Cần sửa":

- `flutter analyze --no-pub`: không phát hiện lỗi.
- `flutter test --no-pub`: 111 test đạt.
- `git diff --check`: đạt.

Các phát hiện dưới đây dựa trên việc đọc mã và đối chiếu test hiện có. Chưa tái hiện từng lỗi trên thiết bị thật.

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

Trạng thái: **Đã sửa ở mức mã nguồn và unit test; vẫn cần xác nhận trên thiết bị Android thật**.

Vị trí chính: [screen_time_tracker.dart](lib/features/telemetry/screen_time_tracker.dart), [main.dart](lib/main.dart).

- Detector foreground hiện dựng trạng thái từ cả sự kiện resume, pause, màn hình interactive/non-interactive và keyguard shown/hidden.
- Khi ứng dụng bị pause, app khác được resume, màn hình tắt hoặc khóa máy, package cũ được xóa đúng cách.
- Guard nhận `null` khi không còn app blacklist thực sự hoạt động nên dừng thời gian ân hạn và không tiếp tục phạt.
- Polling được tuần tự hóa; cửa sổ overlap và dedupe sự kiện tránh bỏ event UsageStats trả về trễ hoặc áp dụng lặp.

### 5. Cảnh báo hạn mức có thể bỏ lỡ lúc người dùng vượt hạn

Trạng thái: **Đã sửa ở mức mã nguồn và unit test; vẫn cần xác nhận trên thiết bị Android thật**.

Vị trí chính: [screen_time_tracker.dart](lib/features/telemetry/screen_time_tracker.dart), [main.dart](lib/main.dart).

- Trạng thái package foreground được giữ giữa các lần polling thay vì chỉ tìm sự kiện mở trong một cửa sổ ngắn.
- Package chỉ bị xóa khi có sự kiện rời app, app khác được mở, tắt màn hình hoặc khóa máy.
- Cảnh báo hạn mức vì vậy vẫn có thể kích hoạt khi người dùng mở app dưới hạn rồi tiếp tục dùng đến lúc vượt hạn.
- Main ngăn các lượt kiểm tra async chạy chồng nhau.

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

### 8. Ô nhập hạn mức bị ghi đè trong lúc đang sửa

Trạng thái: **Đã sửa**.

Vị trí chính: [settings_screen.dart](lib/features/settings/settings_screen.dart).

- Ô nhập theo dõi focus, trạng thái draft đã thay đổi và giá trị cấu hình đồng bộ gần nhất.
- Notification định kỳ từ tracker hoặc overlay không ghi đè khi người dùng đang focus hoặc có draft chưa lưu.
- Nội dung chỉ được đồng bộ khi hạn mức cấu hình thực sự thay đổi và field đang sạch, không có focus.
- Listener, controller và `FocusNode` được giải phóng đầy đủ.

## Nên cải thiện

### 9. Đồng hồ cần dựa trên thời gian đã trôi qua

Vị trí: [focus_session_controller.dart](lib/features/focus_session/focus_session_controller.dart), dòng 170.

- **Hiện tại:** Mỗi callback timer chỉ trừ một giây, kể cả đồng hồ tạm dừng.
- **Vấn đề:** Khi callback bị chậm hoặc tiến trình bị treo tạm thời, bộ đếm không bù phần thời gian đã trôi qua.
- **Cải thiện:** Dùng mốc thời gian kết thúc và tính lại thời gian còn lại; kiểm tra khi tắt màn hình và bật tiết kiệm pin. Đây là xử lý khi tiến trình còn sống, không yêu cầu khôi phục trận sau khi tiến trình bị tắt.
- **Nếu giữ nguyên:** Phiên có thể kéo dài hơn thời lượng người dùng chọn. Mức độ xảy ra trên điện thoại hiện chưa được đo.

### 10. Lịch sử phiên thiếu thời điểm thực tế

Vị trí: [focus_session_controller.dart](lib/features/focus_session/focus_session_controller.dart), dòng 237; [focus_history_service.dart](lib/features/dashboard/services/focus_history_service.dart), dòng 63.

- **Hiện tại:** Quỹ trận chỉ giữ số giây từng phiên. Khi thắng, toàn bộ phiên được ghi theo ngày và giờ trả thưởng.
- **Vấn đề:** Một trận kéo qua nhiều giờ hoặc qua nửa đêm sẽ dồn dữ liệu về thời điểm kết thúc; phục hồi trả thưởng hôm sau cũng ghi vào hôm sau.
- **Cải thiện:** Giữ thêm thời điểm của từng phiên trong quỹ và bản ghi trả thưởng. Việc chỉ công nhận giờ khi thắng vẫn có thể giữ nguyên.
- **Nếu giữ nguyên:** Lịch ngày và khung giờ vàng không phản ánh thời gian thực sự tập trung.

### 11. Kiểm thử thiết bị thật cho các luồng nền quan trọng

Trạng thái: **Đã bổ sung phần lớn unit/widget test; còn thiếu kiểm thử trên Android thật**.

Vị trí: thư mục [test](test), đặc biệt [analytics_metrics_test.dart](test/analytics_metrics_test.dart), [focus_history_test.dart](test/focus_history_test.dart), [settlement_test.dart](test/settlement_test.dart), [foreground_detection_test.dart](test/foreground_detection_test.dart) và [settings_screen_test.dart](test/settings_screen_test.dart).

- Đã thêm test hồi quy cho analytics không tạo dữ liệu mẫu, đổi ngày, lỗi và retry settlement, tính idempotent của trả thưởng, chuỗi sự kiện foreground/khóa màn hình và draft hạn mức.
- Bộ test hiện có 111 test đạt.
- Phần còn lại là kiểm thử tích hợp trên Android thật cho luồng cấp quyền → chạy nền → mở blacklist → khóa máy, vượt hạn sau khi app đã mở lâu và kết thúc trận khi overlay đang hiển thị.
- Cần kiểm tra trên nhiều phiên bản Android/OEM vì thời điểm UsageStats phát sự kiện có thể khác nhau.

### 12. Cấu hình ký bản release vẫn dùng khóa debug

Vị trí: [build.gradle.kts](android/app/build.gradle.kts), dòng 32.

- **Hiện tại:** Bản release dùng `signingConfigs.getByName("debug")`.
- **Vấn đề:** Khóa ký bản phát hành chưa được cấu hình riêng.
- **Cải thiện:** Trước khi phân phối chính thức, thiết lập khóa ký release và cách quản lý khóa ngoài Git.
- **Nếu giữ nguyên:** Bản release vẫn phụ thuộc khóa debug của môi trường build.

## Có thể tinh gọn

### 13. Bỏ dependency không dùng và test placeholder

Vị trí: [pubspec.yaml](pubspec.yaml), dòng 36; [widget_test.dart](test/widget_test.dart), dòng 1.

- **Hiện tại:** Có `cupertino_icons` nhưng không tìm thấy nơi dùng trong mã ứng dụng; một test chỉ kiểm tra `1 + 1 == 2`.
- **Vấn đề:** Chúng không giúp kiểm chứng tính năng hiện tại.
- **Cải thiện:** Bỏ dependency và test placeholder này.
- **Nếu giữ nguyên:** Tác động nhỏ, nhưng tăng phần phải duy trì mà không tạo giá trị.

Khả năng tinh gọn: bỏ 1 dependency trực tiếp và file test placeholder 7 dòng.

## Thứ tự ưu tiên hiện tại

Tám mục ưu tiên ban đầu đã được xử lý. Công việc còn lại nên theo thứ tự:

1. Kiểm thử các luồng UsageStats, khóa màn hình, cảnh báo hạn mức và overlay trên Android thật.
2. Sửa đồng hồ dựa trên thời gian thực đã trôi qua.
3. Lưu thời điểm thực tế của từng phiên tập trung.
4. Cấu hình khóa ký release trước khi phân phối.
5. Dọn dependency và test placeholder không dùng.

Chưa có lý do từ mã hiện tại để thay toàn bộ cách quản lý state hoặc thêm framework mới.

## Yêu cầu đã xác nhận và nội dung còn chờ

- Chủ dự án đã xác nhận: **Android tắt tiến trình hoặc người dùng vuốt đóng ứng dụng giữa trận = bỏ cuộc**. Không xem việc thiếu khôi phục trận là lỗi.
- Khôi phục khoản trả thưởng của một trận đã thắng là luồng khác với khôi phục trận đang chơi.
- Chủ dự án sẽ bổ sung yêu cầu hiện hành vì các tài liệu đang khác nhau. Chưa lấy `PROJECT_OVERVIEW.md` hoặc tài liệu khác làm chuẩn duy nhất để kết luận luật game đúng/sai.
- Đánh giá luật thưởng, mở khóa và đề xuất tính năng mới còn chờ yêu cầu hiện hành.

## Giới hạn kiểm tra và rủi ro

Chưa kiểm tra APK release, hành vi UsageStats/overlay trên điện thoại thật, pin/FPS, từng ảnh/font và từng dòng scaffold native của các nền tảng phụ.

Các thay đổi đã vượt qua unit/widget test và static analysis, nhưng hành vi phát sự kiện UsageStats, khóa màn hình và overlay vẫn cần xác nhận trên thiết bị Android thật. SharedPreferences không phải cơ sở dữ liệu giao dịch; cơ chế settlement hiện giảm rủi ro bằng journal tuần tự và idempotency key, nhưng vẫn cần kiểm thử việc tiến trình bị dừng tại nhiều thời điểm trong luồng trả thưởng.
