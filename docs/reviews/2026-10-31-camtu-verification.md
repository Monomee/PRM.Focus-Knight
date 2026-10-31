# Kiểm chứng nhánh camtu — 2026-10-31

> Đây là báo cáo phúc tra **trước khi sửa bổ sung**. Sau yêu cầu sửa, các phát hiện dưới đây đã được xử lý; kết quả hiện tại là 132 test đạt, analyze sạch, APK debug build/cài thành công và ca vượt hạn liên tục đã đạt trên Samsung Android 13. Xem [PROJECT_REVIEW.md](../../PROJECT_REVIEW.md) cho trạng thái mới nhất.

Đối tượng: commit `84b4132931c7700c64b93470e29d08b060adcfc1` (`fix: resolve project review issues`), so với commit cha `63094f2`.

Đã đọc 39 file Dart trong `lib/`, các test, tài liệu dự án, công cụ tạo icon, mã Android tùy chỉnh và rà cấu hình nền tảng. Mô hình đánh giá: một người dùng, dữ liệu cục bộ trên điện thoại; không yêu cầu khôi phục trận đang chơi sau khi tiến trình bị tắt.

Thay đổi này thêm journal trả thưởng, khóa chống cộng trùng, bộ dựng trạng thái foreground, bỏ thống kê mẫu và bảo vệ draft cài đặt. Chưa thể xác nhận tuyên bố đã hoàn thành toàn bộ mục 1–8.

## Kết quả theo PROJECT_REVIEW.md

| Mục | Kết luận | Bằng chứng |
| --- | --- | --- |
| 1. Lưu dữ liệu/trả thưởng | Chưa đạt | 4 ca hồi quy thất bại: hoàn lại tiền đã chi, mất khoản thưởng mới khi khoản cũ lỗi, lịch sử không đồng bộ sau khôi phục. |
| 2. Cộng phút qua nửa đêm | Đạt ca hồi quy hiện có | Ghi ngày mới đọc đúng tổng của ngày mới. Không bao gồm việc phân bổ thời điểm từng phiên, vốn thuộc mục 10. |
| 3. Dữ liệu mẫu trong analytics | Đạt phần đã kiểm tra | Không còn baseline giả, giữ `null` khi thiếu dữ liệu; các test thiếu dữ liệu đạt. |
| 4. Khóa máy bị phạt | Đạt ca Android đã chạy | Mở YouTube rồi tắt màn hình khoảng 16 giây; trở lại trận, thanh HP còn đầy. |
| 5. Vượt hạn khi app mở lâu | Chưa đạt trên thiết bị | YouTube từ 3m05s lên 4m44s, hạn mức 4 phút, không có thông báo trong lúc dùng liên tục. Mở lại khi đã quá hạn thì có cảnh báo. |
| 6. Đóng overlay khi thắng | Đạt ca Android đã chạy | Overlay có HP 75/100 trước khi hết giờ; tự đóng sau trận 1 phút trong khi YouTube vẫn phía trước. |
| 7. Chọn khung giờ vàng | Chưa đạt trường hợp gần bằng nhau | 599 phút ở 11–14h và 600 phút ở 21–24h nhưng chọn 11–14h. |
| 8. Ô nhập hạn mức | Đạt bảo vệ draft; lỗi nạp ban đầu | Draft 321 giữ nguyên qua 7 giây polling; nhưng khi khởi động ô hiện 60 dù cấu hình lưu 240. Widget test tái hiện lỗi nạp. |

## Cần sửa

### 1. Số dư đã chi quay lại sau khi nạp ví hoặc nhận thưởng tiếp — P1

Vị trí: [player_state.dart](../../lib/core/game/player_state.dart), dòng 37, 67, 109 và 170.

- **Vai trò:** `deposit()` ghi ví mới vào `fk_wallet_state`; `load()` ưu tiên đọc khóa này.
- **Lỗi:** `build()` trừ tiền rồi `_save()` chỉ ghi `fk_gold`/`fk_logs`, không cập nhật `fk_wallet_state`. Nhận 500 coin/100 log, xây tháp tốn 200/40, mở lại vẫn có 500/100. Nhận thêm 30/12 thì ví thành 530/112 thay vì 330/72.
- **Sửa tối thiểu:** Mọi thao tác thay đổi số dư phải cập nhật cùng bản ghi ví và giữ danh sách ID đã áp dụng; kiểm tra cả ghi đồng thời với settlement.
- **Nếu bỏ qua:** Xây làng không tiêu tài nguyên bền vững, kinh tế game sai ngay trong luồng sử dụng bình thường.

### 2. Khoản thưởng mới không vào journal nếu khoản cũ đang lỗi — P1

Vị trí: [settlement.dart](../../lib/features/focus_session/settlement.dart), dòng 29; [focus_session_controller.dart](../../lib/features/focus_session/focus_session_controller.dart), dòng 259 và 285.

- **Vai trò:** `commit()` xử lý khoản đang chờ trước khi thêm khoản thưởng mới.
- **Lỗi:** Khi `_resume()` ném lỗi, hàm thoát trước `queue.add()` và `_writeQueue()`. Controller đã xóa quỹ trận và bỏ qua lỗi trả về. Test gửi hai khoản 30 và 60 coin khi history lỗi: journal chỉ giữ khoản 30.
- **Sửa tối thiểu:** Lưu khoản mới vào hàng đợi trước khi xử lý khoản cũ; giữ khả năng retry nếu lần ghi journal đầu tiên thất bại.
- **Nếu bỏ qua:** Thắng trận trong thời gian lỗi lưu trữ có thể mất hẳn khoản thưởng mới.

### 3. Khôi phục lịch sử chỉ nạp snapshot, không sửa các khóa thống kê — P1

Vị trí: [focus_history_service.dart](../../lib/features/dashboard/services/focus_history_service.dart), dòng 101, 128, 142, 179, 189 và 200.

- **Vai trò:** Phiên được ghi vào `fk_history_settlement_state` trước, rồi ghi sang các khóa theo ngày/giờ/số phiên.
- **Lỗi:** Nếu tiến trình dừng giữa hai bước, retry thấy ID đã áp dụng nên chỉ gọi `loadData()` rồi trả về. Tổng giờ và `todayFocusSeconds` lấy từ snapshot, nhưng các getter ngày/giờ/số phiên vẫn đọc khóa cũ. Test có snapshot 1500 giây, chưa có các khóa phụ: sau resume, tổng là 1500 nhưng getter ngày trả 0 và journal đã được xóa.
- **Sửa tối thiểu:** Các getter đọc cùng nguồn snapshot, hoặc retry đồng bộ đầy đủ các khóa phụ trước khi báo thành công. Kiểm tra kết quả ghi các khóa phụ nếu tiếp tục dùng chúng.
- **Nếu bỏ qua:** Tổng giờ, biểu đồ, lịch và số phiên hiển thị những số khác nhau sau khôi phục trả thưởng.

### 4. Cảnh báo vượt hạn vẫn bỏ lỡ khi dùng YouTube liên tục — P1

Vị trí: [screen_time_tracker.dart](../../lib/features/telemetry/screen_time_tracker.dart), dòng 63, 193 và 209; [main.dart](../../lib/main.dart), dòng 197–208.

- **Vai trò:** Bộ phát hiện giữ package foreground; điều kiện vượt hạn lấy tổng phút từ `queryAndAggregateUsageStats()`.
- **Lỗi đã quan sát:** Samsung Android 13, quyền usage/overlay/notification đã có. Đặt hạn mức YouTube 4 phút khi đang có 3m05s. Mở liên tục lúc 15:55:36; kiểm tra sau 40 và 75 giây không có thông báo `7004`. Trở về lúc 15:57:14, UI báo 4m44s/4m. Mở YouTube lần nữa thì thông báo `⚠️ Cảnh báo hạn mức: YouTube` xuất hiện trong 6 giây.
- **Hướng sửa:** Việc giữ package chưa đủ. Cần đo giá trị tổng thời gian trả về trong phiên app còn mở, rồi tính phần sử dụng đang diễn ra từ event/thời gian thực nếu aggregate chưa cập nhật. Đồng thời xác minh polling nền thực sự chạy. Chưa instrument từng poll nên nguyên nhân aggregate chậm cập nhật vẫn là giả thuyết, không phải kết luận đã chứng minh.
- **Nếu bỏ qua:** Luồng cảnh báo cốt lõi vẫn không nhắc đúng lúc vượt hạn trên thiết bị đã kiểm tra.

### 5. Ô hạn mức không đồng bộ ở lần nạp cấu hình đầu tiên — P1

Vị trí: [settings_screen.dart](../../lib/features/settings/settings_screen.dart), dòng 26–30 và 51–61.

- **Vai trò:** Controller được khởi tạo với hạn mức mặc định; `_syncedDailyLimit` là biến `late` có biểu thức khởi tạo.
- **Lỗi:** `_syncedDailyLimit` chỉ được tính khi đọc lần đầu. Nếu lần đọc đầu xảy ra trong notification nạp cấu hình 240, nó cũng thành 240; điều kiện `dailyLimit != _syncedDailyLimit` sai, controller vẫn là 60. Đã thấy trực tiếp trên điện thoại và tái hiện bằng widget test.
- **Sửa tối thiểu:** Khởi tạo giá trị đồng bộ cùng thời điểm với controller trước khi đăng ký listener; giữ logic bảo vệ draft hiện tại.
- **Nếu bỏ qua:** Người dùng thấy hạn mức khác cấu hình thực tế và có thể bấm Lưu để vô tình đổi 240 thành 60.

### 6. Làm tròn trước khi chọn giờ vàng khiến chọn sai khung — P2

Vị trí: [analytics_service.dart](../../lib/features/dashboard/services/analytics_service.dart), dòng 280–294.

- **Vai trò:** Dịch vụ chuẩn hóa các khung giờ rồi chọn tỷ lệ lớn nhất.
- **Lỗi:** 599/600 và 600/600 đều làm tròn thành 1,00. Vòng lặp chọn khung 599 phút xuất hiện trước, dù khung sau có 600 phút. Test kỳ vọng `21:00 - 24:00`, thực tế là `11:00 - 14:00`.
- **Sửa tối thiểu:** Chọn khung lớn nhất từ tổng giây/phút gốc; chỉ làm tròn dữ liệu hiển thị.
- **Nếu bỏ qua:** Mục 7 vẫn có trường hợp đưa ra khung giờ sai.

## Lệnh và kết quả

- Bộ test nguyên trạng trước khi bổ sung: `flutter test --no-pub --reporter expanded` → **111 đạt**.
- Sau khi bổ sung 6 ca tái hiện: cùng lệnh → **111 đạt, 6 thất bại**. Bốn ca cho mục 1, một ca cho mục 7, một widget test cho mục 8. Thất bại là các assertion về hành vi, không phải lỗi biên dịch test.
- `flutter analyze --no-pub` → **7 info, exit 1**, không có error/warning. Sáu chỗ thiếu ngoặc khối và một gợi ý null-aware element. Kết quả này khác ghi chú “không phát hiện lỗi” của PROJECT_REVIEW.md.
- `flutter build apk --debug --no-pub` → **đạt**, APK tại `build/app/outputs/flutter-apk/app-debug.apk`.
- Build có cảnh báo plugin `usage_stats` áp dụng Kotlin Gradle Plugin, có thể không tương thích một phiên bản Flutter tương lai; không chặn build hiện tại.
- Cài bằng `adb install -r` → **Success**, giữ dữ liệu ứng dụng.
- Thiết bị: Samsung SM-G781N, Android 13, kết nối USB. Các quyền đã được cấp từ trước; không kiểm thử luồng cấp quyền lần đầu.
- Log đã lấy bằng `adb logcat -d -t 1500 -s flutter AndroidRuntime`: không có lỗi được trả về trong cửa sổ log này.

Test bổ sung: [project_review_regression_test.dart](../../test/project_review_regression_test.dart).

Chạy riêng để giao lại cho thành viên nhóm:

```powershell
flutter test --no-pub test/project_review_regression_test.dart --reporter expanded
```

Không sửa mã ứng dụng hay các test cũ. Các test mới cố ý giữ assertion đúng để tiếp tục báo lỗi cho tới khi sửa implementation.

## Bằng chứng Android trong workspace

Các ảnh/log dưới `build/` bị Git bỏ qua và chỉ có ở máy này:

- `build/after-lock-review.png`: thanh HP đầy sau tắt màn hình.
- `build/victory-before.png`: overlay YouTube, HP 75/100.
- `build/victory-after.png`: YouTube còn foreground, overlay đã đóng sau trận.
- `build/settings-review.png`: ô nhập 60, hạn mức cấu hình 240.
- `build/limit-after-review.png`: YouTube 4m44s/4m sau ca không có cảnh báo.
- `build/draft-review.png`: draft 321 vẫn còn sau 7 giây.
- `build/review-tests.log`, `build/review-analyze.log`: kết quả các lệnh kiểm tra.

Đã xóa đúng khóa override YouTube do test thêm, trả lại chế độ kế thừa hạn mức chung 240 phút như trước test; đã đọc preferences xác nhận. Có bản sao preferences trước khi xóa khóa thử tại `files/focusknight-review-prefs-backup.xml` trong vùng dữ liệu riêng của ứng dụng trên điện thoại. Test tạo ba trận 1 phút đã thắng nên có thêm 3 phút lịch sử và 3 coin trong dữ liệu điện thoại. Không xóa tiến độ hiện có.

## Công việc còn lại và giới hạn

Ưu tiên sửa các phát hiện 1–5 trước khi xác nhận hoàn tất nhánh, sau đó sửa chọn giờ vàng. Các mục 9, 10, 12, 13 của review cũ vẫn còn; mục 11 mới được kiểm tra một phần trên một thiết bị. README còn câu analytics dùng dữ liệu mẫu và STRUCTURE chưa cập nhật các khóa snapshot mới.

Chưa kiểm tra APK release, OEM/Android khác, pin/FPS, tiết kiệm pin, kill tiến trình tại từng lệnh ghi thực tế, từng ảnh/font và toàn bộ scaffold native của các nền tảng phụ. Ca khôi phục giữa các lần ghi được mô phỏng bằng trạng thái lưu trữ tương ứng trong unit test.

Kết luận: **Chưa nên xác nhận đã sửa xong 1–8.** Mục 2, 3, 4, 6 đạt phạm vi đã kiểm tra; mục 1, 5, 7 còn lỗi; mục 8 bảo vệ draft đúng nhưng phát sinh lỗi đồng bộ ban đầu.

## Kết quả sửa bổ sung trong cùng ngày

- Ví lưu cả số dư và công trình vào cùng snapshot, tuần tự hóa xây làng/nhận thưởng. Hai ca hoàn lại tiền và ca ghi đồng thời đều đạt.
- Khoản thưởng mới được journal trước khi xử lý khoản cũ. Controller giữ khoản lỗi và cung cấp retry với cùng ID; lỗi ở lần ghi đầu không bị trận mới ghi đè.
- Getter ngày, giờ và số phiên đọc snapshot lịch sử với fallback khóa cũ. Retry sau gián đoạn không cộng trùng và không làm mất thống kê.
- Helper cache dùng chung giữ trạng thái chưa tin cậy qua lỗi ghi lẫn lỗi đọc phục hồi; chỉ cho dùng lại cache sau khi đọc thành công. Rà soát độc lập đã phát hiện trường hợp lỗi kép này; hai test tái hiện đã được chạy thất bại rồi đạt sau sửa.
- Tracker tính thời gian từ UsageEvents, gồm cả khoảng foreground còn mở; dedupe/overlap, khóa máy, đổi ngày và cấp quyền sau khởi động có test.
- Ca USB mới: 16:24:18 mở YouTube từ mức 4m51s, hạn mức 6 phút. Sau 45 giây chưa có cảnh báo; 16:25:48 đã có notification 7004 `Cảnh báo hạn mức: YouTube`, không mở lại app. Ảnh: `build/fixed-limit-alert.png`.
- Mục 7 chọn khung theo tổng phút gốc trước làm tròn; mục 8 khởi tạo baseline trước listener. Thiết bị hiển thị đúng hạn mức 240 sau khởi động (`build/fixed-settings.png`).
- Toàn bộ `flutter test --no-pub`: **132 đạt** (`build/fix-tests.log`); `flutter analyze --no-pub`: **No issues found**; APK debug build thành công và đã cài giữ dữ liệu.
- Đã bỏ đúng override YouTube do test thêm để trở lại kế thừa hạn mức chung 240 phút. Bản sao preferences trước phục hồi: `files/focusknight-fix-prefs-backup.xml` trong dữ liệu riêng của ứng dụng trên điện thoại. Đợt kiểm tra bản sửa không tạo thêm trận/thưởng.

Giới hạn còn lại: chưa kiểm tra release, nhiều OEM/Android hay kill thật tại từng bước ghi. Khi thiết bị hoàn toàn không ghi được journal đầu tiên, người dùng phải retry trước khi đóng tiến trình; UI đã thông báo điều này.
