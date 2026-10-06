# BẢN 1: ĐẶC TẢ DỰ ÁN & KIẾN TRÚC KỸ THUẬT (PROJECT BLUEPRINT)

### 1. Thông tin chung & Định vị

- **Tên dự án (Tạm gọi):** **FocusKnight: Idle Pomodoro**
- **Nền tảng mục tiêu:** Android (Chạy và kiểm thử trực tiếp trên thiết bị thật qua cáp USB/ADB, không qua máy ảo).
- **Mục tiêu cốt lõi:** Xác thực vòng lặp hành vi (Core Loop Validation): Liệu việc "treo máy làm việc để nhân vật tự đánh quái kiếm tiền nâng cấp" có đủ giữ chân người dùng và giúp họ giảm thời gian lướt mạng xã hội hay không.

### 2. Danh mục Tính năng (Feature Scope)

#### A. Vòng lặp Tập trung & Gameplay thụ động (100% Passive)

- **Khởi tạo phiên (Setup):** Người dùng nhập nhãn công việc ngắn (ví dụ: *"Fix bug API"*, *"Đọc sách"*) và chọn mốc thời gian (mặc định 25 phút).
- **Chiến đấu tự động (Auto-battle):**
  - Nhân vật tự động bước đi, chạm trán quái vật theo từng Stage (Ải 1, Ải 2...).
  - Tự động xuất chiêu theo nhịp tốc độ đánh. Quái đánh trả rút máu nhân vật.
  - **Cơ chế Hồi sinh (Death Loop):** Khi nhân vật hết HP $\rightarrow$ Chết $\rightarrow$ Chờ 3 giây hồi sinh $\rightarrow$ Tự động chạy lại từ đầu Stage đó. Quá trình tập trung của người dùng **không bao giờ bị gián đoạn hay bắt bấm nút hồi sinh**.
- **Đồ họa Thủ tục (Procedural Pixel Art):** Toàn bộ nhân vật, quái vật, vũ khí và số nhảy sát thương được vẽ trực tiếp bằng `CustomPainter` của Dart thông qua các khối hình chữ nhật màu pixelated (không tốn thời gian tìm asset bên ngoài).

#### B. Giai đoạn Nghỉ ngơi & Nâng cấp (Rest Interval)

- **Kích hoạt:** Khi hết 25 phút Pomodoro, app tự chuyển sang trạng thái Nghỉ (5 phút) và phát chuông báo.
- **Cửa hàng Doanh trại (Camp Shop):** Màn hình nâng cấp mở khóa. Người dùng tiêu Vàng nhặt được trong ca làm việc để nâng:
  - *Sát thương (ATK)*: Tăng damage đòn đánh.
  - *Sinh lực (HP)*: Tăng trần máu và tốc độ tự hồi phục máu mỗi giây.
  - *Chí mạng (CRIT)*: Tăng % xác suất ra đòn nhân đôi sát thương.
- **Sau 5 phút nghỉ:** Chuông reo, khóa Shop, người dùng nhập tên việc mới và bước vào ca Focus tiếp theo.

#### C. Giám sát Thiết bị & Chống xao nhãng (Digital Wellbeing)

- **Đo lường thời gian MXH:** Tích hợp `usage_stats` quét thời gian mở Facebook, TikTok, Instagram trong ngày.
- **Chặn tương tác:** Khi thời gian dùng MXH chạm trần (ví dụ quá 30 phút/ngày) hoặc khi người dùng cố tình thoát app lúc đang trong phiên Focus, kích hoạt `flutter_overlay_window` vẽ một lớp phủ cảnh báo đè lên màn hình.
- **Tiến trình ngầm:** Duy trì `flutter_foreground_task` hiển thị notification đếm ngược trên thanh trạng thái, ngăn hệ điều hành Android kill tiến trình khi tắt màn hình.

### 3. Kiến trúc Kỹ thuật (Technical Architecture)

```text
lib/
├── core/
│   ├── constants/            # Package names blacklist, Game Balance Config
│   └── services/             # Foreground Task Service, Overlay Service
├── features/
│   ├── focus_session/        # Pomodoro Timer Logic, Session State (StateNotifier/ChangeNotifier)
│   ├── game_view/            # CustomPainter Engine: Pixel Hero, Mob, Damage Text, Game Math
│   ├── upgrade_shop/         # Camp/Shop UI, Currency State, Stats Calculation
│   ├── telemetry/            # UsageStats Tracker, Screen-time Calculator
│   └── overlay/              # Entry point overlayMain(), Blocker Widget
└── main.dart                 # App Entry, Route Management, Permission Gateway

```

- **State Management:** `ChangeNotifier` hoặc `StateNotifier` (giữ code tối giản, zero-boilerplate để code nhanh nhất).
- **Storage:** `shared_preferences` (đủ để lưu Vàng, Chỉ số nâng cấp, Hạn mức thời gian cho bản prototype mà không cần setup database phức tạp).
