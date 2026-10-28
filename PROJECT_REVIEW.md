# Review dự án FocusKnight

Ngày review: 2026-10-28.

Tài liệu này tổng hợp 13 vấn đề đã báo cáo trong phiên review. Không có mã nguồn ứng dụng nào được sửa trong quá trình review.

## Phạm vi và kết quả kiểm tra

FocusKnight là ứng dụng Pomodoro kết hợp game pixel: hoàn thành trận để nhận tài nguyên, nâng làng và mở nhân vật. Đánh giá kỹ thuật dựa trên mô hình hiện tại: dữ liệu lưu trên một điện thoại Android, không có máy chủ.

Đã đọc toàn bộ 39 file Dart trong `lib/`, 22 file test, phần Android tùy chỉnh, công cụ tạo icon và tài liệu; rà soát thêm cấu hình các nền tảng còn lại.

- `flutter analyze --no-pub`: không phát hiện lỗi.
- `flutter test --no-pub`: 99 test đạt.
- Sau khi review, Git không có thay đổi mã nguồn.

Các phát hiện dưới đây dựa trên việc đọc mã và đối chiếu test hiện có. Chưa tái hiện từng lỗi trên thiết bị thật.

Điểm tốt: luật game tách khỏi giao diện, tái sử dụng component hợp lý và có test cho nhiều luồng chính. Ưu tiên cải thiện độ tin cậy của dữ liệu, chống xao nhãng và thống kê.

## Cần sửa

### 1. Lỗi lưu dữ liệu bị bỏ qua nhưng vẫn đánh dấu đã trả thưởng

Vị trí: [player_state.dart](lib/core/game/player_state.dart), dòng 123; [settlement.dart](lib/features/focus_session/settlement.dart), dòng 35.

- **Hiện tại:** Ví và lịch sử bắt lỗi ghi dữ liệu bằng `catch (_) {}`.
- **Vấn đề:** Nếu ghi thất bại, `Settlement` vẫn có thể đánh dấu bước đó đã hoàn thành và xóa bản ghi chờ xử lý.
- **Cải thiện:** Cho lỗi ghi dữ liệu truyền về nơi trả thưởng; chỉ đánh dấu hoàn tất sau khi xác nhận lưu thành công.
- **Nếu giữ nguyên:** Người dùng có thể thấy nhận thưởng trên màn hình nhưng mất tiền hoặc lịch sử sau khi mở lại app.

### 2. Số phút hôm qua có thể bị cộng sang hôm nay

Vị trí: [focus_history_service.dart](lib/features/dashboard/services/focus_history_service.dart), dòng 63.

- **Hiện tại:** `_todayFocusSeconds` được nạp khi đọc dữ liệu, rồi cộng dồn mỗi lần hoàn thành phiên.
- **Vấn đề:** App mở qua nửa đêm không đặt lại biến này. Ví dụ hôm qua có 60 phút, hôm nay hoàn thành 25 phút thì khóa dữ liệu hôm nay được ghi thành 85 phút.
- **Cải thiện:** Theo dõi ngày của bộ đếm, hoặc đọc số giây từ đúng khóa ngày trước khi cộng.
- **Nếu giữ nguyên:** Dashboard, thống kê theo ngày và tốc độ xao nhãng đều có thể sai.

### 3. Thống kê đang trình bày dữ liệu mẫu như dữ liệu cá nhân

Vị trí: [analytics_service.dart](lib/features/dashboard/services/analytics_service.dart), dòng 128; [correlation_chart_card.dart](lib/features/dashboard/widgets/correlation_chart_card.dart), dòng 102.

- **Hiện tại:** Khi thiếu dữ liệu, app tự điền giờ MXH, giờ tập trung, hai lần xao nhãng và xu hướng bảy ngày. Câu kết luận “40%/95%” được viết cố định.
- **Vấn đề:** Người mới cài vẫn nhận được báo cáo về hành vi chưa xảy ra; người không xao nhãng vẫn có thể bị tính hai lần.
- **Cải thiện:** Bỏ dữ liệu mẫu khỏi báo cáo thật; phân biệt rõ `0`, chưa có dữ liệu và chưa cấp quyền. Chưa đủ dữ liệu thì chưa đưa kết luận.
- **Nếu giữ nguyên:** Người dùng không thể tin báo cáo dù giao diện hiển thị đẹp.

### 4. Khóa màn hình sau khi mở app bị chặn vẫn có thể bị phạt

Vị trí: [screen_time_tracker.dart](lib/features/telemetry/screen_time_tracker.dart), dòng 184 và 228.

- **Hiện tại:** Bộ phát hiện chỉ lấy sự kiện mở ứng dụng và nhớ package gần nhất.
- **Vấn đề:** Sau khi mở YouTube rồi khóa màn hình, sự kiện đóng/tạm dừng hoặc khóa màn hình không xóa package đã nhớ. Guard vẫn có thể coi YouTube đang được sử dụng.
- **Cải thiện:** Xử lý cả sự kiện rời ứng dụng và trạng thái màn hình; thêm test cho chuỗi mở YouTube → khóa máy trong thời gian ân hạn.
- **Nếu giữ nguyên:** Người dùng có thể mất HP hoặc Coin khi điện thoại đã khóa. Cần xác nhận thêm trên thiết bị thật.

### 5. Cảnh báo hạn mức có thể bỏ lỡ lúc người dùng vượt hạn

Vị trí: [screen_time_tracker.dart](lib/features/telemetry/screen_time_tracker.dart), dòng 199; [main.dart](lib/main.dart), dòng 187.

- **Hiện tại:** Ngoài trận, app chỉ tìm sự kiện mở ứng dụng trong 12 giây gần nhất.
- **Vấn đề:** Người dùng mở YouTube khi chưa vượt hạn, tiếp tục xem vài phút rồi mới vượt hạn. Khi đó sự kiện mở YouTube đã nằm ngoài cửa sổ truy vấn.
- **Cải thiện:** Giữ trạng thái ứng dụng đang hoạt động giữa các lần kiểm tra, đồng thời xử lý đúng sự kiện rời app và khóa máy.
- **Nếu giữ nguyên:** Chức năng nhắc hạn mức có thể im lặng đúng lúc cần nhắc.

### 6. Overlay chưa được đóng khi thắng trận trong app bị chặn

Vị trí: [main.dart](lib/main.dart), dòng 182; [blocker_overlay_widget.dart](lib/features/overlay/blocker_overlay_widget.dart), dòng 43.

- **Hiện tại:** Overlay tự đóng sau thất bại; nhánh ngoài trận chỉ đóng khi người dùng rời ứng dụng blacklist.
- **Vấn đề:** Nếu phiên cuối hết giờ trong khi overlay đang mở trên YouTube, trận đã thắng nhưng overlay vẫn có thể tiếp tục che màn hình.
- **Cải thiện:** Đóng overlay và reset guard ngay khi trận kết thúc, có xử lý riêng nếu cần hiển thị thất bại trong năm giây.
- **Nếu giữ nguyên:** Người dùng vẫn bị chặn sau khi đã hoàn thành trận.

### 7. Khung giờ vàng có thể hiển thị sai khung giờ cao nhất

Vị trí: [analytics_service.dart](lib/features/dashboard/services/analytics_service.dart), dòng 284.

- **Hiện tại:** Chỉ một số khung giờ được chuyển thành `peakTimeSlot`; những khung còn lại giữ mặc định buổi sáng.
- **Vấn đề:** Nếu dữ liệu tập trung cao nhất nằm trong 21–24 giờ hoặc 11–14 giờ, app vẫn có thể khuyên làm việc lúc 08:00–11:30.
- **Cải thiện:** Lấy nhãn trực tiếp từ khung thắng cuộc. Đồng thời sửa việc gộp 00–05 giờ vào nhãn “21h–24h”.
- **Nếu giữ nguyên:** Lời khuyên mâu thuẫn với chính biểu đồ của người dùng.

### 8. Ô nhập hạn mức bị ghi đè trong lúc đang sửa

Vị trí: [settings_screen.dart](lib/features/settings/settings_screen.dart), dòng 36.

- **Hiện tại:** Mọi thông báo thay đổi từ tracker hoặc overlay đều đồng bộ lại nội dung ô nhập.
- **Vấn đề:** Tracker làm mới mỗi ba giây. Người dùng đang sửa `60` thành `120`, chưa bấm Lưu, có thể bị trả lại `60`.
- **Cải thiện:** Không đồng bộ đè khi người dùng đang nhập; chỉ cập nhật khi giá trị cấu hình thực sự thay đổi.
- **Nếu giữ nguyên:** Cài đặt khó thao tác và có thể lưu nhầm giá trị.

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

### 11. Test đang thiếu các tình huống dễ làm mất niềm tin nhất

Vị trí: thư mục [test](test/), đặc biệt [analytics_metrics_test.dart](test/analytics_metrics_test.dart), [focus_history_test.dart](test/focus_history_test.dart), [settlement_test.dart](test/settlement_test.dart) và [foreground_detection_test.dart](test/foreground_detection_test.dart).

- **Hiện tại:** Bộ test bao phủ khá tốt luật thưởng, xây làng, pause, hình phạt và các màn chính.
- **Vấn đề:** Test analytics chủ yếu kiểm tra dữ liệu có tồn tại và nằm trong khoảng hợp lệ; số liệu bịa vẫn vượt qua. Chưa có test cho các trường hợp đổi ngày, lỗi ghi dữ liệu và kết thúc trận khi overlay mở.
- **Cải thiện:** Thêm test hồi quy cho các mục trên, ưu tiên lưu dữ liệu và chống phạt nhầm. Thêm một luồng kiểm thử trên Android thật cho cấp quyền → chạy nền → mở blacklist → khóa máy.
- **Nếu giữ nguyên:** “99 test đạt” chưa chứng minh được các hành vi nền quan trọng.

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

## Thứ tự ưu tiên

Ưu tiên xử lý **1 → 2 → 3 → 4 → 5 → 6** trước khi thêm tính năng.

Chưa có lý do từ mã hiện tại để thay toàn bộ cách quản lý state hoặc thêm framework mới.

## Yêu cầu đã xác nhận và nội dung còn chờ

- Chủ dự án đã xác nhận: **Android tắt tiến trình hoặc người dùng vuốt đóng ứng dụng giữa trận = bỏ cuộc**. Không xem việc thiếu khôi phục trận là lỗi.
- Khôi phục khoản trả thưởng của một trận đã thắng là luồng khác với khôi phục trận đang chơi.
- Chủ dự án sẽ bổ sung yêu cầu hiện hành vì các tài liệu đang khác nhau. Chưa lấy `PROJECT_OVERVIEW.md` hoặc tài liệu khác làm chuẩn duy nhất để kết luận luật game đúng/sai.
- Đánh giá luật thưởng, mở khóa và đề xuất tính năng mới còn chờ yêu cầu hiện hành.

## Giới hạn kiểm tra và rủi ro

Chưa kiểm tra APK release, hành vi trên điện thoại thật, pin/FPS, từng ảnh/font và từng dòng scaffold native của các nền tảng phụ.

Rủi ro chính: lỗi lưu dữ liệu và phạt nhầm vẫn có thể tồn tại dù toàn bộ test hiện tại đạt.
