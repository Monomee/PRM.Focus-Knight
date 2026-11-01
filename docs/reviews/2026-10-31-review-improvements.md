# Xác minh cải thiện mục 9–13

Ngày: 2026-10-31. Phạm vi: `PROJECT_REVIEW.md` mục 9, 10, 12, 13. Mục 11 nghiệm thu thủ công do chủ dự án thực hiện.

## Thay đổi

- Đồng hồ dùng hạn kết thúc cho focus/nghỉ/pause, bù callback trễ, cập nhật khi resume và trước khi xử lý xao nhãng. Skip và bỏ cuộc không thể ghi đè kết quả của giai đoạn đã hết hạn.
- Quỹ trận và journal giữ khoảng tập trung thực tế, loại trừ pause. Lịch sử chia theo giờ/ngày; số phiên theo ngày hoàn thành. Chỉ ghi khi thắng, giữ cơ chế ID chống trả/ghi trùng.
- Journal cũ thiếu timestamp giữ fallback cũ; không suy đoán lại lịch sử đã ghi. Timestamp mới lưu UTC và phân bổ theo múi giờ địa phương khi xử lý.
- Release dùng keystore riêng qua file bị ignore `android/key.properties`; có mẫu và hướng dẫn trong README. Thiếu cấu hình bị chặn tại `preReleaseBuild`, không dùng debug signing.
- Bỏ `cupertino_icons` và placeholder `test/widget_test.dart`; lockfile không có nâng cấp package khác.

## Bằng chứng kiểm tra

| Kiểm tra | Kết quả |
| --- | --- |
| Baseline `flutter test --no-pub` | 132 đạt |
| Test tái hiện callback trễ trước khi sửa | Fail: sau 2,2 giây chỉ giảm từ 4 xuống 3, thay vì còn tối đa 2 |
| Test tái hiện journal có timestamp qua nửa đêm trước khi sửa | Fail: ngày cũ nhận 0 thay vì 600 giây |
| Test skip đến trễ trước khi sửa | Fail: thời gian phiên kế tiếp bị đặt lại 10 thay vì còn 6 giây |
| Test bỏ cuộc sau khi trận hết giờ trước khi sửa | Fail: kết quả thua thay vì thắng |
| Test skip cũ khi đã chuyển sang giờ nghỉ tiếp theo trước khi sửa | Fail: bỏ qua nhầm giờ nghỉ tiếp theo |
| `flutter test --no-pub --reporter expanded` sau cùng | **146 đạt**, thêm 15 test thật và bỏ 1 placeholder |
| `flutter analyze --no-pub` sau cùng | Không phát hiện lỗi |
| `flutter build apk --debug --no-pub` sau cùng | Đạt, `build/app/outputs/flutter-apk/app-debug.apk` |
| `android/gradlew.bat :app:preReleaseBuild --offline --console=plain` khi chưa có khóa | Fail đúng dự kiến: `Release signing requires android/key.properties` |
| `git check-ignore` với cấu hình và keystore trong Android | Các file bị ignore |
| `git diff --check` | Đạt |

Test mới còn bao phủ: qua nhiều giai đoạn/nghỉ dài, khoảng pause qua ranh giới giờ, pause tự hết 5 phút, phần lẻ giây, phiên nhiều giờ, giữ dữ liệu cũ, timestamp không hợp lệ và retry sau khi lịch sử đã ghi nhưng journal chưa lưu tiến độ.

## Smoke test qua ADB

- Thiết bị: Samsung SM-G781N, serial `R3CN90V2K3X`, Android 13 / API 33.
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: Success, không xóa dữ liệu ứng dụng.
- `adb shell am start -W -n com.example.test_dart/.MainActivity`: Status: ok.
- `pidof` xác nhận tiến trình còn chạy; `dumpsys activity` xác nhận MainActivity resumed.
- Không thấy `FATAL EXCEPTION`, `Unhandled Exception`, `E/flutter` trong 300 dòng log gần nhất của riêng tiến trình tại thời điểm kiểm tra. Không xóa log hệ thống.
- Không thay đổi quyền, hạn mức, dữ liệu lưu hoặc khởi tạo trận thử trên điện thoại trong đợt này.

## Còn chờ

- Chủ dự án nghiệm thu mục 11: khóa màn hình/tiết kiệm pin, pause tự hết, mở lại sau hạn kết thúc, cấp quyền lần đầu và khác biệt OEM/Android. Smoke test không chứng minh các ca này.
- Chủ dự án cung cấp khóa release, sao lưu mật khẩu/keystore và kiểm tra APK/AAB ký thật. Chưa tạo hoặc dùng khóa production.
- Chưa kiểm tra đổi giờ hệ thống/múi giờ giữa trận hoặc khi retry, pin/FPS và các nền tảng phụ.
- Build có cảnh báo sẵn về `usage_stats` dùng Kotlin Gradle Plugin và chênh lệch SDK XML; không nâng dependency/toolchain trong phạm vi này.
