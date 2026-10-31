# Cấu trúc dự án FocusKnight

FocusKnight dùng Flutter/Dart cho giao diện và logic ứng dụng, cùng mã Android cho thông báo hệ thống. Nền tảng mục tiêu hiện tại là Android; các thư mục nền tảng khác vẫn có trong dự án.

## Thư mục gốc

```text
test_dart/
├── lib/                     # Mã Dart của ứng dụng
├── test/                    # Unit test và widget test
├── ui/                      # Ảnh nền, sprite, icon, huy hiệu và font
├── tool/                    # Công cụ tạo tài nguyên
├── android/                 # Android runner, quyền, service và cấu hình build
├── ios/                     # iOS runner và cấu hình nền tảng
├── macos/                   # macOS runner và cấu hình nền tảng
├── windows/                 # Windows runner và cấu hình CMake
├── linux/                   # Linux runner và cấu hình CMake
├── web/                     # Trang khởi động và manifest cho web
├── docs/superpowers/         # Thiết kế và kế hoạch triển khai đã lưu
├── pubspec.yaml             # Dependency, điều kiện Dart SDK, asset và font
├── pubspec.lock             # Phiên bản dependency đã resolve
├── analysis_options.yaml    # Cấu hình phân tích mã và lint
├── README.md                # Giới thiệu và hướng dẫn sử dụng
├── STRUCTURE.md             # Tài liệu cấu trúc này
└── PROJECT_REVIEW.md         # Báo cáo review kỹ thuật
```

`build/`, `.dart_tool/` và các thư mục `ephemeral/` chứa đầu ra build hoặc dữ liệu do công cụ sinh. Không chỉnh sửa chúng để thay đổi tính năng ứng dụng.

## Mã ứng dụng trong lib/

```text
lib/
├── main.dart
├── core/
│   ├── constants/            # Danh sách ứng dụng theo dõi/chặn
│   ├── game/                 # Luật game và trạng thái người chơi
│   ├── services/             # Thông báo, foreground service, guard và overlay
│   └── widgets/              # Thành phần giao diện dùng chung
└── features/
    ├── shell/                # Khung điều hướng 4 tab
    ├── home/                 # Trang chủ và trang phân tích
    ├── battle/               # Thiết lập và giao diện trận
    ├── focus_session/        # Đồng hồ, vòng đời trận và trả thưởng
    ├── village/              # Làng và xây/nâng cấp công trình
    ├── collection/           # Chọn nhân vật và huy hiệu
    ├── settings/             # Quyền và cài đặt người dùng
    ├── dashboard/
    │   ├── services/         # Lịch sử và tổng hợp phân tích
    │   └── widgets/          # Card biểu đồ phân tích
    ├── telemetry/            # Dữ liệu sử dụng và phát hiện app foreground
    └── overlay/              # Giao diện overlay trong isolate riêng
```

### Điểm khởi động

[main.dart](lib/main.dart) chứa:

- `main()`: khởi tạo Flutter, hướng màn hình và foreground service, rồi chạy ứng dụng.
- `FocusKnightApp`: cấu hình MaterialApp và theme chung.
- `FocusKnightHomePage`: tạo state và service, nạp tiến độ, tiếp tục xử lý khoản trả thưởng còn dở, theo dõi vòng đời ứng dụng và kết nối phát hiện xao nhãng với hình phạt.
- `overlayMain()`: điểm khởi động riêng cho giao diện overlay.

### core/: luật và thành phần dùng chung

| File/module | Trách nhiệm |
| --- | --- |
| `constants/blacklist_constants.dart` | Tên và package của các ứng dụng được theo dõi/chặn. |
| `game/battle_plan.dart` | Kế hoạch trận, chuyển đổi JSON, giới hạn phút nhập, lịch trình và ước tính thời gian/phần thưởng. |
| `game/economy.dart` | Công thức Coin/Log và hằng số HP, hình phạt, thuế xao nhãng, thời gian tạm dừng. |
| `game/player_state.dart` | Ví, công trình, nhân vật/huy hiệu đang chọn, vé giữ chuỗi và lưu trạng thái người chơi. |
| `game/progression.dart` | Hạng, ngưỡng giờ, điều kiện mở nhân vật/huy hiệu và đường dẫn ảnh huy hiệu. |
| `game/sprites.dart` | Sprite sheet và số frame của nhân vật, quái và hoạt ảnh chết. |
| `game/village.dart` | Loại công trình, tác dụng, cấp tối đa và chi phí xây/nâng cấp. |
| `services/alert_notifier.dart` | Gọi Android qua MethodChannel `focusknight/alerts` để hiển thị thông báo cảnh báo. |
| `services/distraction_guard.dart` | Quản lý ân hạn, lần phạt HP và nhịp trừ Coin khi dùng app bị chặn. |
| `services/foreground_task_service.dart` | Khởi động/dừng foreground service và cập nhật thông báo phiên. |
| `services/overlay_service.dart` | Kiểm tra quyền, mở/đóng overlay và gửi trạng thái trận sang overlay. |
| `services/persistent_preferences.dart` | Không tin cache sau lỗi ghi cho đến khi đọc lại thành công; dùng chung cho ví, lịch sử và journal. |
| `widgets/cover_rect.dart` | Tính vùng ảnh theo cách hiển thị cover. |
| `widgets/flat_theme.dart` | Màu sắc, kiểu card và chip lựa chọn dùng chung. |
| `widgets/ribbon.dart` | Ribbon cho HUD và đồng hồ. |
| `widgets/sprite_anim.dart` | Hoạt ảnh sprite và icon pixel. |

### features/: các chức năng ứng dụng

| Thư mục | File chính và vai trò |
| --- | --- |
| `shell/` | `app_shell.dart`: khung 4 tab Trang chủ, Làng, Bộ sưu tập, Cài đặt. |
| `home/` | `home_screen.dart`: hạng, ví, bắt đầu/quay lại trận và thống kê nhanh. `analytics_screen.dart`: lịch tháng và các card phân tích. |
| `battle/` | `battle_launcher.dart`: mở thiết lập hoặc quay lại trận. `battle_setup_sheet.dart`: form cấu hình trận. `battle_screen.dart`: chọn giao diện theo trạng thái phiên. |
| `battle/` | `focus_view.dart`, `camp_view.dart`, `result_view.dart`: màn tập trung, nghỉ và kết quả. `mindful_interruption_dialog.dart`: hộp thoại trước khi bỏ cuộc qua nút Back. |
| `focus_session/` | `focus_session_controller.dart`: đồng hồ, chuyển phiên, nghỉ, HP, pause và quỹ trận. `settlement.dart`: lưu bản ghi khoản trả thưởng và tiếp tục xử lý khi cần. |
| `village/` | `village_screen.dart`: bản đồ và ô công trình. `building_sheet.dart`: chi tiết và thao tác xây/nâng cấp. |
| `collection/` | `collection_screen.dart`: chọn nhân vật và huy hiệu. |
| `settings/` | `settings_screen.dart`: quyền, hạn mức MXH, hạn mức từng app và thời lượng nghỉ dài. |
| `dashboard/services/` | `focus_history_service.dart`: lịch sử focus, số phiên, xao nhãng, streak và ngày được bảo vệ. `analytics_service.dart`: tổng hợp dữ liệu phân tích. |
| `dashboard/widgets/` | `golden_hours_card.dart`, `distraction_velocity_card.dart`, `correlation_chart_card.dart`: card giờ vàng, tần suất xao nhãng và tương quan. |
| `telemetry/` | `screen_time_tracker.dart`: UsageStats, tổng thời gian MXH, hạn mức và phát hiện ứng dụng vừa mở. |
| `overlay/` | `blocker_overlay_widget.dart`: giao diện nhắc quay lại trận, nhận HP/Coin/trạng thái thất bại qua dữ liệu chia sẻ. |

## Luồng xử lý chính

1. **Khởi động:** `main.dart` nạp người chơi và lịch sử, xử lý khoản trả thưởng còn dở, kiểm tra vé giữ chuỗi. Giao diện `AppShell` được dựng trong khi dữ liệu nạp bất đồng bộ.
2. **Bắt đầu trận:** `HomeScreen` → `openBattle()` → form thiết lập → `FocusSessionController.startFocusSession()` → `BattleScreen`.
3. **Chạy trận:** Controller cập nhật đồng hồ và trạng thái; giao diện chuyển giữa `FocusView`, `CampView` và `ResultView`. Phần thưởng từng phiên được giữ trong quỹ trận.
4. **Hoàn thành trận:** Controller gọi `Settlement` để ghi lịch sử qua `FocusHistoryService` và cộng tài nguyên vào `PlayerState`.
5. **Chống xao nhãng:** Bộ theo dõi vòng đời trong `main.dart` truy vấn `ScreenTimeTracker`, chuyển kết quả cho `DistractionGuard`; guard gọi controller để phạt và service để hiển thị overlay/cảnh báo.
6. **Overlay:** `OverlayService` gửi dữ liệu qua `FlutterOverlayWindow.shareData`; widget trong isolate riêng nhận qua `overlayListener`, không đọc trực tiếp controller.

Controller và service dùng `ChangeNotifier`; giao diện theo dõi thay đổi bằng listener hoặc `ListenableBuilder`.

## Lưu trữ

Dữ liệu được lưu cục bộ bằng SharedPreferences. Các nhóm khóa chính:

| Nhóm | Khóa tiêu biểu |
| --- | --- |
| Ví và bộ sưu tập | `fk_gold`, `fk_logs`, `fk_character`, `fk_badge` |
| Làng và giữ chuỗi | `fk_buildings`, `fk_streak_tickets`, `fk_granary_built`, `fk_ticket_week`, `fk_shielded_dates` |
| Thiết lập trận | `fk_last_plan`, `fk_long_rest_minutes` |
| Lịch sử | `fk_completed_dates`, `fk_total_focus_seconds_all_time`, `fk_focus_sec_*`, `fk_hourly_focus_*`, `fk_session_count_*`, `fk_interruption_day_*` |
| Hạn mức MXH | `fk_daily_limit_minutes`, `fk_app_limit_*` |
| Khoản trả thưởng đang xử lý | `fk_pending_settlement` |
| Snapshot ví và lịch sử | `fk_wallet_state` (số dư, công trình, ngày xây Kho lương, ID đã trả), `fk_history_settlement_state` (tổng giờ, ngày/giờ/số phiên, ID đã ghi) |

`fk_gold` là khóa Coin cũ dùng khi chưa có snapshot ví. Snapshot là nguồn ưu tiên cho ví và lịch sử; các khóa cũ vẫn được đọc để giữ tiến độ trước đây. Bản ghi trả thưởng phục vụ trận đã thắng; nó không lưu toàn bộ trạng thái để khôi phục trận đang chơi.

## Android

- [MainActivity.kt](android/app/src/main/kotlin/com/example/test_dart/MainActivity.kt): xử lý MethodChannel thông báo, tạo kênh cảnh báo và thông báo có thể mở lại ứng dụng.
- [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml): khai báo quyền usage stats, overlay, notification, wake lock và foreground service.
- [build.gradle.kts](android/app/build.gradle.kts): cấu hình ứng dụng Android và build.

Các plugin chính là `usage_stats`, `flutter_foreground_task`, `flutter_overlay_window` và `shared_preferences`.

## Tài nguyên và công cụ

```text
ui/
├── buildings/        # Công trình người chơi và nhà goblin
├── characters/       # Sprite nhân vật, quái và hoạt ảnh chết
├── fonts/            # PixelifySans.ttf
├── icons/            # Icon pixel
├── ranks/            # Huy hiệu theo nhân vật và hạng
├── ribbons/          # Ribbon cho HUD
└── scenes/           # Nền trận chiến, trại nghỉ và làng
```

[tool/make_icons.py](tool/make_icons.py) dùng Pillow để tạo launcher icon và notification icon Android từ ảnh huy hiệu. Asset và font dùng trong Flutter được khai báo trong `pubspec.yaml`.

## Kiểm thử và tài liệu

Thư mục `test/` chứa test cho luật game, kế hoạch trận, controller, trả thưởng, người chơi, lịch sử, giữ chuỗi, hạn mức, phát hiện foreground, guard và các widget chính. Chạy bằng `flutter test`; phân tích mã bằng `flutter analyze`.

- [README.md](README.md): giới thiệu ứng dụng và hướng dẫn sử dụng/chạy dự án.
- [PROJECT_REVIEW.md](PROJECT_REVIEW.md): vấn đề đã phát hiện và giới hạn kiểm tra.
- [docs/superpowers/specs/](docs/superpowers/specs/): tài liệu thiết kế đã lưu.
- [docs/superpowers/plans/](docs/superpowers/plans/): kế hoạch triển khai đã lưu.

Các tài liệu thiết kế/kế hoạch là tài liệu lịch sử; cần đối chiếu với mã và yêu cầu hiện hành khi thay đổi hành vi.
