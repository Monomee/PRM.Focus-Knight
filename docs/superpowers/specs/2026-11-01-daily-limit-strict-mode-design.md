# Strict mode cho hạn mức mạng xã hội hằng ngày

## Mục tiêu và phạm vi

FocusKnight là ứng dụng Flutter Android kết hợp Pomodoro với trận chiến pixel, phần thưởng Coin/Log, xây làng, mở nhân vật và thống kê tập trung. UsageStats theo dõi Facebook, TikTok, Instagram và YouTube. Hiện tại vượt hạn mức ngoài trận chỉ phát thông báo; overlay hiện có phục vụ trận Pomodoro.

Người dùng xác nhận Strict mode chỉ áp dụng cho hạn mức hằng ngày. Overlay, ân hạn và hình phạt HP/Coin trong trận giữ nguyên.

## Phương án

Tái sử dụng ScreenTimeTracker và OverlayService cùng overlay isolate hiện có. Thêm trạng thái hiển thị hạn mức vào BlockerOverlayWidget. Đây là phương án đề xuất vì dự án đã có quyền overlay, cửa sổ toàn màn hình và kênh truyền dữ liệu. Không thêm plugin hoặc service native song song: chúng lặp lại cơ chế đã có và tăng phạm vi kiểm thử.

## Hành vi đề xuất

- Thêm công tắc Strict mode trong Cài đặt, mặc định tắt; lưu lựa chọn qua các lần khởi động.
- Tắt: khi app đang mở đạt hạn mức, vẫn gửi thông báo theo cơ chế giới hạn tần suất hiện có.
- Bật: gửi thông báo và mở overlay che toàn màn hình, nhận thao tác chạm để không tương tác với nội dung app bên dưới.
- Overlay ghi tên app, hạn mức phút/ngày và lý do đã hết thời gian; chỉ có nút quay lại FocusKnight, không có nút tiếp tục lướt. Không hiển thị HP/Coin của trận cho hạn mức hằng ngày.
- Tự đóng overlay khi rời app bị chặn, khóa/tắt màn hình, trở về FocusKnight, tắt Strict mode hoặc hạn mức không còn bị vượt (đổi ngày/tăng hạn mức).
- Khi chuyển giữa các app quá hạn, cập nhật đúng tên và hạn mức trên overlay.
- Yêu cầu quyền overlay khi bật nếu chưa có; nếu chưa được cấp thì không báo chế độ chặn đã sẵn sàng. Thông báo vẫn hoạt động nếu được Android cho phép.
- Dùng hạn mức từng app hiện có; app chưa đặt riêng kế thừa giá trị mặc định chung. Không thay đổi ý nghĩa hạn mức thành tổng ngân sách chung của mọi app.

## Những phần cần sửa và kiểm tra

ScreenTimeTracker (lưu công tắc), SettingsScreen (công tắc và trạng thái quyền), main.dart (điều phối cảnh báo/overlay theo foreground), OverlayService (truyền trạng thái và đóng/mở an toàn), BlockerOverlayWidget (nội dung hạn mức), README và các test liên quan.

Test trạng thái mặc định, lưu/nạp công tắc, bật/tắt và thiếu quyền, thông báo ở cả hai chế độ, nội dung overlay hạn mức, đóng khi rời app, chuyển app, đổi ngày/tăng hạn mức và hồi quy overlay trong trận. Chạy toàn bộ Flutter test, analyze và build Android.

## Giới hạn và quyết định triển khai

Các giá trị mặc định và nội dung overlay ở trên là đề xuất của người triển khai. Không thay khóa ký, package ID, dữ liệu tiến độ hoặc luật trận. Không cài đè/gỡ app trên điện thoại trong phạm vi này.

Việc giám sát hiện nằm trong tiến trình Flutter, polling khoảng 2–3 giây. Tính năng này không bổ sung khả năng tiếp tục chặn sau khi Android/người dùng tắt tiến trình. Overlay cần quyền hiển thị trên ứng dụng khác và không phải khóa quản trị thiết bị.

## Trạng thái

Đã khôi phục và hoàn thiện triển khai sau phiên bị ngắt ngày 2026-11-01. Toàn bộ Flutter test, analyze, build APK release và xác minh chữ ký đạt. Bổ sung kênh native nhỏ để đóng cùng overlay service kể cả khi nó còn chờ khởi động; không thêm service hoặc dependency. Chưa cài APK mới hoặc nghiệm thu Strict mode trên điện thoại thật, bao gồm overlay đang mở qua nửa đêm.
