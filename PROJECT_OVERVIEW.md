# FOCUSKNIGHT: TỔNG QUAN DỰ ÁN & ĐẶC TẢ KIẾN TRÚC TOÀN DIỆN

> **FocusKnight** là ứng dụng di động kết hợp giữa **Kỹ thuật Pomodoro**, **Game Auto-Battler Đồ họa Pixel Thủ tục (Procedural Pixel Art)** và **Hệ thống Giám sát & Quản lý Thời gian Màn hình (Digital Wellbeing Telemetry)**.
> Dự án được phát triển theo tôn chỉ **Fail Fast / Lean MVP**: Tối ưu hóa hiệu năng, loại bỏ database cồng kềnh, không phụ thuộc tài nguyên đồ họa bên ngoài (100% vẽ bằng Canvas), kiến trúc phân lớp sạch sẽ và chống triệt để các lỗi logic thực tế.

---

## MỤC LỤC

1. [TỔNG QUAN TÍNH NĂNG (TÍNH NĂNG GÌ)](#1-tổng-quan-tính-năng-tính-năng-gì)
   - 1.1. Màn hình Dashboard 2 Tab (Trung tâm Điều khiển & Phân tích)
   - 1.2. Màn hình Trận đấu Pomodoro (Game Scene & Auto-Battler)
   - 1.3. Doanh trại & Xưởng Nâng cấp (Camp Upgrade Shop)
   - 1.4. Hệ thống Ngoại trang Thủ tục (Procedural Skins & Companions)
   - 1.5. Giám sát Sức khỏe Số & Chặn Xao nhãng (Digital Wellbeing)
2. [CƠ CHẾ KỸ THUẬT & THUẬT TOÁN (LÀM RA SAO)](#2-cơ-chế-kỹ-thuật--thuật-toán-làm-ra-sao)
   - 2.1. Đồ họa Pixel Procedural Canvas (PixelStageCanvas)
   - 2.2. Vòng lặp Chiến đấu & Trạng thái Idle (CombatEngine)
   - 2.3. Chu trình Pomodoro Đa phiên Tự động (FocusSessionController)
   - 2.4. Thuật toán Chuỗi Kỷ luật Chống Reset Đầu Ngày (Edge Case A)
   - 2.5. Cơ chế Đồng bộ Dữ liệu Tức thì Chống Stale State (Edge Case B)
   - 2.6. Quy tắc Phân định Blocker Overlay vs Heads-up Popup (Edge Case C)
   - 2.7. 15 Giây Mindful Interruption Log
   - 2.8. Bộ 3 Thuật toán Phân tích Chuyên sâu (Analytics Engine)
3. [CẤU TRÚC THƯ MỤC & MÃ NGUỒN (CẤU TRÚC NHƯ NÀO)](#3-cấu-trúc-thư-mục--mã-nguồn-cấu-trúc-như-nào)
   - 3.1. Sơ đồ Cây Thư mục Dự án
   - 3.2. Trách nhiệm của Từng Thành phần
   - 3.3. Luồng Dữ liệu & Quản lý Trạng thái (Data Flow & State Management)
4. [KẾT QUẢ KIỂM THỬ & TƯƠNG THÍCH THIẾT BỊ THẬT](#4-kết-quả-kiểm-thử--tương-thích-thiết-bị-thật)

---

## 1. TỔNG QUAN TÍNH NĂNG (TÍNH NĂNG GÌ)

### 1.1. Màn hình Dashboard 2 Tab (Trung tâm Điều khiển & Phân tích)
Màn hình chính của ứng dụng được chia thành **2 Tab điều hướng dạng Segmented Pill Bar**:

* **TAB 1: TẬP TRUNG (Focus & Control)**:
  - **Ngọn lửa kỷ luật (Streak Banner)**: Hiển thị số ngày kỷ luật liên tiếp (`🔥 X NGÀY LIÊN TIẾP`).
  - **Chỉ số hôm nay & Tích lũy**: Thẻ *"Hôm nay tập trung"* (`Xm`) và *"Tổng tích lũy"* (`Xh`) với viền neon tương phản cao.
  - **Nút hành động chính**: Nút bấm lớn màu hổ phách `VÀO CA CHIẾN ĐẤU (START POMODORO)` để chuyển ngay sang màn hình Game Scene.
  - **Lịch Kỷ luật Chấm Xanh (Monthly Dot-Grid Calendar)**: Lưới 7 cột (T2 -> CN). Các ngày có phiên hoàn thành 100% được chấm xanh ngọc `#10B981`. Bấm vào ô ngày hiển thị chính xác số phút đã tập trung trong ngày đó.
  - **Thẻ Screen-Time & Blocker Overlay**:
    - Ô nhập text thuần đặt hạn mức MXH trong ngày (phút/ngày) tự do, không bị giới hạn trần 180 phút.
    - Danh sách các mạng xã hội theo dõi (Facebook, TikTok, Instagram, YouTube) kèm thời gian đã dùng và hạn mức riêng. Có nút ✏️ để chỉnh số phút cho từng app độc lập.
    - Cụm nút quản lý cấp quyền Overlay và quyền Truy cập Sử dụng (Usage Access).

* **TAB 2: QUẢN LÝ & PHÂN TÍCH (Analytics & Insights)**:
  - **Biểu đồ Mối tương quan Xao nhãng (Correlation Analysis)**: Biểu đồ cột đôi 7 ngày thể hiện mối quan hệ giữa Số giờ lướt MXH (cột đỏ) và Tỉ lệ hoàn thành mục tiêu tập trung (cột xanh). Kèm nhận xét phân tích thông minh chỉ ra quy luật nghịch biến.
  - **Tần suất bồn chồn (Distraction Velocity)**: Đo lường số lần chạm/thoát app trung bình mỗi giờ làm việc (ví dụ: `1.5 lần/giờ`). Phân cấp 3 trạng thái: 🟢 *Tập trung sâu (Deep Flow)*, 🟡 *Bình thường (Moderate)*, 🔴 *Bồn chồn cao (High Restlessness)* cùng biểu đồ xu hướng 7 ngày.
  - **Khung giờ vàng (Golden Hours)**: Biểu đồ phân bổ năng suất theo 6 khung thời gian trong tuần và vinh danh Khung giờ vàng cá nhân (`👑 08:00 - 11:30`) kèm lời khuyên tối ưu hiệu suất sinh học.

---

### 1.2. Màn hình Trận đấu Pomodoro (Game Scene & Auto-Battler)
- **Procedural Canvas**: Toàn bộ sàn đấu, hiệp sĩ, quái orc, bầu trời đêm sao lấp lánh và hiệu ứng cuộn di chuyển được vẽ trực tiếp bằng Canvas.
- **Đồng hồ đếm ngược trực tiếp trên sàn đấu**: Hiển thị font điện tử monospace cỡ lớn (`fontSize: 42`), màu vàng kim tương phản cao, đặt **ngay dưới dòng STAGE**, hoàn toàn không dùng khung viền hay nền hộp, mở rộng tối đa tầm nhìn.
- **2 Tab ở đáy màn hình**: Thanh Tab (`Trận Đấu & Trại`, `Ngoại Trang`) nằm gọn ở dưới cùng của màn hình (`height: 50`), không che khuất trận đấu.
- **Tùy chỉnh đa phiên (Multi-Session)**: Cho phép chọn số phiên (1, 2, 3, 4 phiên), thời lượng tập trung (1m test, 15m, 25m Pomodoro, 50m) và thời gian nghỉ (30s test, 5m, 10m, 15m).
- **Chu trình tự động (Auto-progression)**: Hết phiên tập trung $\rightarrow$ Rung + Chuông + Báo nghỉ $\rightarrow$ Hết giờ nghỉ $\rightarrow$ Tự động chuyển và đếm ngược phiên tiếp theo cho đến khi hoàn thành toàn bộ chu trình.

---

### 1.3. Doanh trại & Xưởng Nâng cấp (Camp Upgrade Shop)
- Chỉ mở khóa trong **thời gian nghỉ giải lao (Rest Interval)**.
- Người dùng sử dụng Vàng tích lũy khi tiêu diệt quái trong ca tập trung để nâng cấp:
  - **Sát thương (ATK)**: Tăng damage đòn đánh cơ bản.
  - **Máu tối đa (HP)**: Tăng trần sinh lực giúp hiệp sĩ chịu đòn tốt hơn ở các Stage cao.
  - **Tỉ lệ Chí mạng (CRIT)**: Tăng xác suất ra đòn x2 sát thương kèm hiệu ứng rung màn hình.

---

### 1.4. Hệ thống Ngoại trang Thủ tục (Procedural Skins & Companions)
- Không cần tải ảnh bên ngoài, đổi màu bảng màu (Palette Swap) trực tiếp trên vector tọa độ Canvas.
- **Trang phục Hiệp sĩ (Hero Skins)**:
  - *Squire (Tập sự)*: Mở khóa mặc định (0h).
  - *Paladin Kim Hoàng (Royal Paladin)*: Mở khóa sau 1 giờ tập trung tích lũy.
  - *Shadow Assassin (Sát thủ bóng đêm)*: Mở khóa sau 5 giờ tập trung tích lũy.
- **Thú cưng Đồng hành (Camp Pets)**:
  - *Slime Xanh*: Mở khóa sau 2 giờ tập trung tích lũy, tự động nảy đồng hành bên cạnh hiệp sĩ.

---

### 1.5. Giám sát Sức khỏe Số & Chặn Xao nhãng (Digital Wellbeing)
- **Tự động reset lúc 00:00 đêm**: Bộ đếm thời gian sử dụng MXH lấy dữ liệu từ `UsageStats` tính từ đầu ngày `DateTime(year, month, day)` nên tự động đặt lại về 0 khi sang ngày mới mà không cần background cron job.
- **Blocker Overlay toàn màn hình**: Khi đang trong ca tập trung sâu Pomodoro mà người dùng cố tình mở ứng dụng giải trí bị chặn (Facebook, TikTok, Instagram, YouTube), hệ thống lập tức phủ lớp cảnh báo đen đỏ đè lên màn hình, yêu cầu bấm nút `RETURN TO FOCUS` để quay lại.
- **Cảnh báo vượt hạn mức ngày**: Khi dùng MXH ngoài giờ làm việc mà vượt quá số phút quy định, hệ thống gửi **thông báo nổi Heads-up (popup banner) của Android** nhắc nhở nghỉ ngơi, tuyệt đối không hiện blocker overlay gây ức chế.

---

## 2. CƠ CHẾ KỸ THUẬT & THUẬT TOÁN (LÀM RA SAO)

### 2.1. Đồ họa Pixel Procedural Canvas (`PixelStageCanvas`)
- Kế thừa `CustomPainter`, chạy ở tần số quét 60 FPS mượt mà thông qua `AnimationController.repeat()`.
- Nhân vật Hiệp sĩ và Quái thú được tạo từ các tọa độ pixel tỉ lệ theo chiều cao màn hình:
  $$\text{pixelSize} = \max\left(3.0, \lfloor\text{height} / 100\rfloor\right)$$
- Hiệu ứng chuyển động (Bobbing): Dùng hàm $\sin$ và $\cos$ theo thời gian để tạo nhịp bước đi và thở nhịp nhàng.
- Sát thương nhảy số (Floating Damage Text): Mỗi đòn đánh sinh ra một thực thể `DamageText` bay lên trên và mờ dần trong 0.8 giây.

---

### 2.2. Vòng lặp Chiến đấu & Trạng thái Idle (`CombatEngine`)
- **Trạng thái IDLE mặc định**: Khởi tạo với `isPaused = true`. Khi người dùng chỉ đang xem màn hình hoặc thiết lập phiên, nhân vật và quái thú giữ nguyên HP, không vung kiếm chém, không trừ máu.
- **Chỉ kích hoạt khi Start Game**: Khi người dùng nhấn nút *"BẮT ĐẦU CA TẬP TRUNG"*, phương thức `resumeCombat()` được gọi. Ticker Timer (chu kỳ 50ms) bắt đầu tính toán cooldown đòn đánh:
  - Hiệp sĩ đánh mỗi 1.0 giây.
  - Quái thú đánh trả mỗi 1.4 giây.
- **Cơ chế Hồi sinh Thụ động (Passive Respawn)**: Khi HP của Hiệp sĩ về 0 $\rightarrow$ `isDefeated = true`, màn hình phủ sắc đỏ mờ và đếm ngược 2.0 giây hồi sinh $\rightarrow$ Tự động hồi đầy máu và tiếp tục đánh. Quá trình tập trung của người dùng **hoàn toàn không bị gián đoạn**.

---

### 2.3. Chu trình Pomodoro Đa phiên Tự động (`FocusSessionController`)
- Quản lý 3 trạng thái: `setup` $\rightarrow$ `focus` $\rightarrow$ `rest`.
- Quản lý số phiên: `totalSessions` và `currentSession`.
- **Logic chuyển đổi tự động (Auto-progression)**:
  ```dart
  // Khi phiên tập trung đếm về 0:
  if (_currentSession < _totalSessions) {
    // Gửi thông báo Android + Rung Haptic + Chuông
    ForegroundTaskService.notifySessionEvent(
      title: '🎉 Hoàn thành phiên $_currentSession/$_totalSessions!',
      message: 'Bắt đầu nghỉ ngơi 5 phút. Phiên tiếp theo sẽ tự động bắt đầu.',
    );
    _phase = SessionPhase.rest;
    _remainingSeconds = _totalRestSeconds;
    _startRestCountdown();
  } else {
    // Hoàn tất toàn bộ chu trình
    ForegroundTaskService.notifySessionEvent(
      title: '🏆 Hoàn thành mục tiêu tập trung!',
      message: 'Chúc mừng! Bạn đã hoàn thành toàn bộ $_totalSessions phiên tập trung.',
    );
  }
  ```
- Duy trì Foreground Task notification trên thanh trạng thái hệ thống Android để ngăn OS kill tiến trình.

---

### 2.4. Thuật toán Chuỗi Kỷ luật Chống Reset Đầu Ngày (Edge Case A)
- **Vấn đề thực tế**: Nếu kiểm tra ngây thơ *"hôm nay chưa hoàn thành phiên nào $\rightarrow$ gán Streak = 0"*, người dùng mở app lúc 00:01 sáng sẽ thấy chuỗi của mình bị xóa mất.
- **Thuật toán chuẩn trong `FocusHistoryService`**:
  1. Lấy ngày hôm nay ($T$) và hôm qua ($T-1$) dạng chuỗi `YYYY-MM-DD`.
  2. Lấy danh sách ngày hoàn thành `completedDates` từ `SharedPreferences`.
  3. **Quy tắc tính toán**:
     - Nếu $T \in \text{completedDates}$: Đếm lùi liên tục từ $T$ về quá khứ ($T, T-1, T-2...$).
     - Nếu $T \notin \text{completedDates}$ nhưng $T-1 \in \text{completedDates}$: **Giữ nguyên chuỗi**, tính từ $T-1$ lùi về quá khứ (chờ phiên hoàn thành của ngày hôm nay).
     - Nếu cả $T$ và $T-1$ đều không có: Chuỗi chính thức đứt gãy $\rightarrow$ Trả về `0`.

---

### 2.5. Cơ chế Đồng bộ Dữ liệu Tức thì Chống Stale State (Edge Case B)
- Khi bấm *"VÀO CA CHIẾN ĐẤU"*, `dashboard_screen.dart` sử dụng:
  ```dart
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PomodoroGameScreen(...)),
  );
  // Ngay sau khi người dùng Pop quay về Dashboard:
  _loadDashboardData();
  ```
- Hàm `_loadDashboardData()` tải lại `completedDates`, tổng phút hôm nay và cập nhật lại lưới Lịch tháng. Loại bỏ hoàn toàn tình trạng chấm xanh không xuất hiện ngay sau khi hoàn thành phiên.

---

### 2.6. Quy tắc Phân định Blocker Overlay vs Heads-up Popup (Edge Case C)
- **Trong phiên Pomodoro (`sessionController.isFocusing == true`)**:
  - Nếu `getActiveBlacklistedPackage()` phát hiện Facebook/TikTok/YouTube đang ở foreground $\rightarrow$ Kích hoạt `FlutterOverlayWindow.showOverlay()` đè lên toàn màn hình để ngăn chặn xao nhãng.
- **Ngoài phiên Pomodoro**:
  - Nếu tổng thời gian MXH vượt quá hạn mức ngày hoặc ứng dụng vượt hạn mức riêng $\rightarrow$ Kích hoạt `ForegroundTaskService.notifyAppLimitExceeded()` gửi **thông báo đẩy Heads-up popup chuẩn Android**, **TUYỆT ĐỐI KHÔNG HIỂN THỊ OVERLAY**.

---

### 2.7. 15 Giây Mindful Interruption Log
- Được kích hoạt khi bấm nút *"Dừng phiên"* hoặc khi người dùng vuốt/bấm phím Back vật lý trên Android (thông qua `PopScope(canPop: false)`).
- Hiển thị Modal đếm ngược bắt buộc 15 giây hít thở sâu, khóa nút xác nhận thoát cho đến khi hết 15 giây.
- Thu thập lý do bồn chồn (*Mệt mỏi*, *Thèm lướt MXH*, *Việc đột xuất*) và ghi nhận 1 lượt gián đoạn vào telemetry để phục vụ tính toán Distraction Velocity.

---

### 2.8. Bộ 3 Thuật toán Phân tích Chuyên sâu (Analytics Engine)
Được triển khai trong `AnalyticsService`:

1. **Correlation Analysis**:
   - Truy vấn thời gian mở MXH từng ngày từ `UsageStats` trong 7 ngày gần nhất.
   - Truy vấn số giây tập trung thực tế từ `FocusHistoryService` cho từng ngày.
   - Tính toán tỉ lệ hoàn thành mục tiêu ngày so với chuẩn 75 phút/ngày:
     $$\text{CompletionRate} = \text{clamp}\left(\frac{\text{FocusHours}}{\text{TargetHours}}, 0.05, 1.0\right)$$
   - Thể hiện sự suy giảm rõ rệt của tỉ lệ hoàn thành khi số giờ MXH vượt ngưỡng 2h.

2. **Distraction Velocity (Tần suất bồn chồn)**:
   - Công thức đo lường:
     $$\text{Velocity} = \frac{\text{Số lần gián đoạn / thoát app}}{\text{Tổng số giờ tập trung}} \quad (\text{lần/giờ})$$
   - Phân cấp: $< 2.0$ (Deep Flow), $2.0 - 4.0$ (Moderate), $> 4.0$ (High Restlessness).
   - Xuất dữ liệu xu hướng 7 ngày phản ánh sự thuyên giảm của cảm giác bồn chồn khi duy trì kỷ luật.

3. **Golden Hours (Khung giờ vàng)**:
   - Ánh xạ 24 giờ trong ngày vào 6 khối thời gian sinh học:
     `05-08h`, `08-11h`, `11-14h`, `14-17h`, `17-21h`, `21-24h`.
   - Tìm kiếm khối thời gian có tổng số phút tập trung hoàn thành cao nhất $\rightarrow$ Xác định đỉnh cao sinh học cá nhân (ví dụ: `08:00 - 11:30` đạt hiệu suất 94%) và đưa ra lời khuyên sắp xếp công việc phù hợp.

---

## 3. CẤU TRÚC THƯ MỤC & MÃ NGUỒN (CẤU TRÚC NHƯ NÀO)

### 3.1. Sơ đồ Cây Thư mục Dự án

```text
d:\Dev_App\TestDart\test_dart\
├── android/                          # Cấu hình Android Native, Permissions & Manifest
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── blacklist_constants.dart      # Package names MXH mặc định & App names
│   │   └── services/
│   │       ├── foreground_task_service.dart  # Foreground service, sticky notification, heads-up popups
│   │       └── overlay_service.dart          # Quản lý quyền SYSTEM_ALERT_WINDOW & Overlay window
│   │
│   ├── features/
│   │   ├── dashboard/                        # Màn hình chính Dashboard 2 Tab
│   │   │   ├── dashboard_screen.dart         # UI chính chia 2 Tab: Focus/Control & Analytics
│   │   │   ├── services/
│   │   │   │   ├── analytics_service.dart    # Service tính toán Correlation, Velocity, Golden Hours
│   │   │   │   └── focus_history_service.dart# Lưu trữ Focus seconds, Streak logic, Interruptions
│   │   │   └── widgets/
│   │   │       ├── correlation_chart_card.dart   # Thẻ biểu đồ tương quan 7 ngày
│   │   │       ├── distraction_velocity_card.dart# Thẻ đo lường tần suất bồn chồn & xu hướng
│   │   │       └── golden_hours_card.dart        # Thẻ biểu đồ 6 khung giờ & vinh danh giờ vàng
│   │   │
│   │   ├── focus_session/                    # Quản lý phiên Pomodoro
│   │   │   └── focus_session_controller.dart # Countdown timer, multi-session cycles, auto-progression
│   │   │
│   │   ├── game_view/                        # Engine Game & Đồ họa Canvas
│   │   │   ├── combat_engine.dart            # Math loop, ATK/HP/CRIT, Idle state, floating damage
│   │   │   ├── pixel_stage_canvas.dart       # CustomPainter vẽ Knight, Mob, Terrain, Stage, Timer
│   │   │   ├── pomodoro_game_screen.dart     # Màn hình chiến đấu, 2 tab đáy, 15s Mindful Log
│   │   │   └── models/
│   │   │       └── skin_cosmetics.dart       # Quản lý bảng màu ngoại trang & Slime companion
│   │   │
│   │   ├── upgrade_shop/                     # Doanh trại nâng cấp
│   │   │   └── camp_upgrade_sheet.dart       # Giao diện nâng cấp mở trong giờ nghỉ
│   │   │
│   │   ├── telemetry/                        # Giám sát thời gian màn hình
│   │   │   └── screen_time_tracker.dart      # Đo lường usage_stats, đặt hạn mức ngày & từng app
│   │   │
│   │   └── overlay/                          # Lớp phủ cảnh báo
│   │       └── blocker_overlay_widget.dart   # Giao diện overlay chặn toàn màn hình
│   │
│   └── main.dart                             # Entrypoint ứng dụng & Entrypoint overlayMain()
│
├── test/                                     # Toàn bộ Unit & Integration Tests tự động
│   ├── analytics_metrics_test.dart           # Kiểm thử tính toán Correlation, Velocity, Golden Hours
│   ├── daily_limit_test.dart                 # Kiểm thử hạn mức thời gian ngày
│   ├── focus_history_test.dart               # Kiểm thử Streak Edge Case A & tích lũy giờ
│   └── multi_session_and_app_limit_test.dart # Kiểm thử đa phiên Pomodoro & hạn mức từng app
│
└── pubspec.yaml                              # Khai báo dependencies
```

---

### 3.2. Trách nhiệm của Từng Thành phần

| Tệp / Thư mục | Trách nhiệm chính |
| :--- | :--- |
| `main.dart` | Khởi chạy app, cấp phát `ChangeNotifier` providers, chạy vòng lặp ngầm giám sát MXH và đăng ký `overlayMain()`. |
| `foreground_task_service.dart` | Giữ tiến trình đếm ngược không bị Android kill khi tắt màn hình; phát thông báo nổi heads-up. |
| `overlay_service.dart` | Kiểm tra quyền `SYSTEM_ALERT_WINDOW`, hiển thị và đóng cửa sổ overlay toàn màn hình. |
| `focus_history_service.dart` | Quản lý persistence lịch sử tập trung, tính chuỗi Streak chống reset đầu ngày, lưu số lần gián đoạn. |
| `analytics_service.dart` | Tính toán số liệu phân tích: Mối tương quan MXH vs Mục tiêu, Tần suất bồn chồn, Khung giờ vàng. |
| `screen_time_tracker.dart` | Giao tiếp với plugin `usage_stats`, tính toán số phút mở MXH từ 00:00, quản lý hạn mức riêng từng app. |
| `combat_engine.dart` | Logic game auto-battler: tốc độ đánh, tính sát thương, tỷ lệ chí mạng, trạng thái Idle, nhặt vàng và hồi sinh. |
| `pixel_stage_canvas.dart` | Vẽ 100% đồ họa vector pixel bằng `CustomPainter`: nhân vật, quái vật, địa hình, thanh máu, đồng hồ đếm ngược. |
| `pomodoro_game_screen.dart` | Màn hình Pomodoro Battlefield với 2 tab ở đáy, bộ đếm ngược dừng phiên 15s Mindful Interruption Log. |
| `blocker_overlay_widget.dart` | Giao diện cảnh báo nền đen mờ 100% chặn tương tác khi mở MXH trong giờ làm việc. |

---

### 3.3. Luồng Dữ liệu & Quản lý Trạng thái (Data Flow & State Management)

```
[ User Action / Timer / Telemetry ]
               │
               ▼
┌───────────────────────────────────────────────┐
│              CORE STATE MANAGERS              │
│  - FocusSessionController (Vòng lặp ca làm)   │
│  - CombatEngine (Chiến đấu & Vàng & Chỉ số)   │
│  - ScreenTimeTracker (Đo thời gian MXH)       │
│  - FocusHistoryService (Lịch sử & Streak)     │
│  - AnalyticsService (Phân tích chuyên sâu)    │
└───────────────────────┬───────────────────────┘
                        │
       notifyListeners()│ (ChangeNotifier pattern)
                        ▼
┌───────────────────────────────────────────────┐
│               PRESENTATION LAYER              │
│  - DashboardScreen (Tab Focus & Tab Analytics)│
│  - PomodoroGameScreen (Canvas & 2 Tab Đáy)    │
│  - BlockerOverlayWidget (Cửa sổ Overlay)      │
└───────────────────────┬───────────────────────┘
                        │
                        ▼
┌───────────────────────────────────────────────┐
│            PERSISTENCE (Zero Boilerplate)     │
│  - SharedPreferences: Lưu Vàng, Chỉ số Hero,  │
│    Lịch sử ngày, Chuỗi Streak, Hạn mức app.   │
└───────────────────────────────────────────────┘
```

---

## 4. KẾT QUẢ KIỂM THỬ & TƯƠNG THÍCH THIẾT BỊ THẬT

### 4.1. Kiểm thử Mã nguồn Tĩnh (`flutter analyze`)
```bash
flutter analyze
# Analyzing test_dart...
# No issues found! (ran in 1.0s)
```
- **Kết quả:** Không có bất kỳ lỗi cú pháp, cảnh báo kiểu dữ liệu hay lint warning nào.

### 4.2. Kiểm thử Đơn vị Tự động (`flutter test`)
Toàn bộ **10/10 test cases** trong 4 tệp kiểm thử chuyên biệt đều đạt 100%:
- `test/analytics_metrics_test.dart`: Kiểm tra tính toán Correlation, Distraction Velocity, Golden Hours và Interruption tracking.
- `test/daily_limit_test.dart`: Kiểm tra tính toán hạn mức ngày và thời gian còn lại.
- `test/focus_history_test.dart`: Kiểm tra thuật toán tính Streak chống reset đầu ngày (Edge Case A) và tích lũy giờ tập trung.
- `test/multi_session_and_app_limit_test.dart`: Kiểm tra chu trình Pomodoro đa phiên tự động chuyển trạng thái và hạn mức riêng từng app (bỏ trần 180m).

### 4.3. Kiểm thử Biên dịch & Chạy Thực tế
- Biên dịch thành công gói cài đặt: `build\app\outputs\flutter-apk\app-debug.apk`.
- Tương thích và hiển thị hoàn hảo trên thiết bị thật **Samsung Galaxy (SM G781N / Android 13 API 33)**:
  - Khắc phục hoàn toàn lỗi overflow giao diện (0.558px trên Dashboard và 3px trên AppBar).
  - Không gặp lỗi kênh truyền nền tảng (Platform Channels) trong môi trường thử nghiệm nhờ cơ chế bọc lỗi an toàn.
