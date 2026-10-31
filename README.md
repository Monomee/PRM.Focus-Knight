# FocusKnight

**FocusKnight là ứng dụng Pomodoro được game hóa:** mỗi khoảng thời gian tập trung trở thành một trận chiến của hiệp sĩ trong thế giới pixel. Bạn chọn công việc, tập trung theo từng phiên, nghỉ giữa các phiên và nhận tài nguyên khi hoàn thành trọn trận.

Coin và Log dùng để xây làng; tổng thời gian tập trung được công nhận giúp tăng hạng, mở nhân vật và huy hiệu. Hoạt ảnh chiến đấu minh họa tiến độ, còn phần thưởng đến từ việc hoàn thành phiên tập trung.

Ứng dụng được xây dựng bằng Flutter, hướng tới **Android, màn hình dọc**. Dữ liệu lưu cục bộ bằng SharedPreferences, không cần tài khoản và chưa có đồng bộ đám mây.

## Chức năng

| Nhóm | Chức năng hiện có |
| --- | --- |
| Pomodoro | Đặt tên công việc; chọn thời gian tập trung, nghỉ ngắn, nghỉ dài và số phiên; xem lịch trình, giờ kết thúc và Coin dự kiến. |
| Trận chiến | Đồng hồ toàn màn hình, nhân vật và quái vật pixel; máu nhà goblin giảm theo thời gian; chuyển sang trại nghỉ giữa các phiên. |
| Điều khiển phiên | Tạm dừng một lần mỗi phiên, tối đa 5 phút; bỏ qua giờ nghỉ; giữ nút bỏ cuộc 2 giây; hộp thoại chờ 15 giây khi dùng nút Back trong phiên tập trung. |
| Phần thưởng | Tích lũy Coin, Log và giờ tập trung vào quỹ trận; nhận khi hoàn thành toàn bộ trận. Thua hoặc bỏ cuộc mất phần đang tạm giữ. |
| Làng | Xây và nâng cấp 8 công trình. Tháp canh tăng thời gian ân hạn, Kho lương cấp vé giữ chuỗi, Doanh trại tăng Coin; các công trình còn lại dùng trang trí. |
| Bộ sưu tập | Chọn nhân vật đã mở để ra trận; chọn huy hiệu làm avatar. |
| Chống xao nhãng | Theo dõi Facebook, TikTok, Instagram và YouTube; cảnh báo hạn mức; overlay nhắc quay lại tập trung và hình phạt khi dùng app bị chặn trong phiên focus. |
| Thống kê | Phút tập trung, số phiên, số lần xao nhãng trong ngày; biểu đồ 7 ngày, chuỗi ngày liên tiếp, lịch tháng và các màn phân tích. |
| Cài đặt | Quản lý quyền truy cập sử dụng, quyền overlay, hạn mức MXH chung và từng app, thời lượng nghỉ dài. |

### Hạng và nhân vật

Theo mã hiện tại, hạng được tính từ tổng giờ của các trận hoàn thành:

| Hạng | Tổng giờ tập trung | Nhân vật mở khóa |
| --- | --- | --- |
| Starter | 0 giờ | Pawn |
| Gold | 10 giờ | Lancer |
| Diamond | 30 giờ | Archer |
| Ruby | 70 giờ | Monk |
| Amethyst | 150 giờ | Warrior |

Nhân vật khác nhau về hình ảnh. Huy hiệu mở khi bạn đã mở nhân vật tương ứng và đạt hạng của huy hiệu đó.

## Cách sử dụng

### 1. Cấp quyền trên Android

Mở tab **Cài đặt**:

- Chọn **Cấp quyền** để cho phép truy cập dữ liệu sử dụng ứng dụng.
- Chọn **Cấp quyền Overlay** để cho phép hiển thị lời nhắc trên ứng dụng khác.
- Cho phép thông báo khi ứng dụng yêu cầu để nhận thông báo phiên và cảnh báo.
- Đặt hạn mức MXH theo ngày hoặc chỉnh riêng cho từng ứng dụng; chỉnh thời lượng nghỉ dài nếu cần.

Quyền truy cập sử dụng phục vụ theo dõi thời gian và phát hiện app gây xao nhãng. Quyền overlay phục vụ màn hình nhắc quay lại trận.

### 2. Thiết lập trận

Tại **Trang chủ**, bấm **BẮT ĐẦU**:

1. Nhập công việc muốn làm.
2. Chọn thời gian tập trung: 15, 25, 50 phút hoặc tùy chỉnh từ 1–180 phút.
3. Chọn nghỉ ngắn: 3, 5, 10 phút hoặc tùy chỉnh từ 1–60 phút.
4. Chọn từ 1–8 phiên và số phiên giữa các lần nghỉ dài; chọn **Tắt** nếu không dùng nghỉ dài.
5. Kiểm tra lịch trình, giờ kết thúc và Coin dự kiến, rồi bấm **XUẤT TRẬN**.

### 3. Tập trung và nghỉ

- Theo dõi đồng hồ; nhà goblin bị phá khi phiên tập trung kết thúc.
- Nếu cần, dùng **Tạm dừng** một lần trong phiên. Sau tối đa 5 phút, đồng hồ tự chạy tiếp.
- Giữa các phiên, màn trại hiển thị phần thưởng đang tạm giữ. Bấm **XUNG TRẬN NGAY** để bỏ qua giờ nghỉ, hoặc **Vào làng** để nâng cấp bằng tài nguyên đã có trong ví.
- Nếu đang ở Trang chủ mà trận vẫn chạy, bấm **QUAY LẠI TRẬN** để mở lại màn chiến đấu.
- Để bỏ cuộc, giữ nút ở góc dưới màn hình trong 2 giây. Nút Back mở hộp thoại cho phép tiếp tục tập trung hoặc xác nhận thoát sau thời gian chờ.

Trong phiên tập trung, mở ứng dụng thuộc danh sách chặn quá thời gian ân hạn sẽ bị trừ 25 HP và hiện overlay. Ân hạn mặc định là 10 giây, tăng lên 12/15 giây theo cấp Tháp canh. Tiếp tục ở lại bị trừ 15 Coin từ quỹ trận mỗi 30 giây, không xuống dưới 0. Hết HP là thua; giờ nghỉ không áp dụng hình phạt này.

### 4. Nhận thưởng và phát triển làng

Hoàn thành tất cả phiên để nhận Coin, Log và giờ tập trung của trận. Vào tab **Làng**, chạm một ô công trình để xem tác dụng, chi phí và xây/nâng cấp. Quỹ của trận đang chơi chưa thể dùng để xây làng.

Vào **Bộ sưu tập** để chọn nhân vật hoặc huy hiệu đã mở. Tại **Trang chủ**, chọn **Phân tích chi tiết** để xem lịch và biểu đồ.

## Chạy dự án

Cần Flutter SDK có Dart đáp ứng `^3.13.1` trong `pubspec.yaml`, Android SDK và thiết bị Android đã bật USB debugging hoặc máy ảo Android.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Thay `<device-id>` bằng mã thiết bị từ `flutter devices`. Nên kiểm tra theo dõi sử dụng, chạy nền và overlay trên điện thoại Android thật.

Kiểm tra mã và chạy test:

```sh
flutter analyze
flutter test
```

## Tài liệu dự án

- [Cấu trúc dự án](STRUCTURE.md): thư mục, vai trò các module và luồng xử lý chính.
- [Review kỹ thuật](PROJECT_REVIEW.md): các vấn đề đã phát hiện và thứ tự ưu tiên cải thiện.

README mô tả tính năng theo mã hiện tại. Phần phân tích hiển thị thiếu dữ liệu khi chưa có đủ lịch sử; các giới hạn về thống kê, lưu dữ liệu và chống xao nhãng được ghi trong bản review. Việc tắt tiến trình hoặc vuốt đóng giữa trận được quy định là bỏ cuộc; không khôi phục trận đang chơi.
