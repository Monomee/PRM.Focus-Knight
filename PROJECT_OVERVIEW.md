# FocusKnight – Tổng quan dự án

App Pomodoro (Android, portrait) có lớp game pixel Tiny Swords để giữ động lực. Bên ngoài trận là dashboard phẳng, đơn giản; trong phiên focus là UI game toàn màn hình. Phần thưởng chỉ đến từ thời gian tập trung thật.

Thiết kế chi tiết: `docs/superpowers/specs/2026-10-19-ui-game-village-design.md`.

## Tính năng

- **4 tab** (`features/shell/app_shell.dart`): Trang chủ · Làng · Bộ sưu tập · Cài đặt.
- **Trang chủ**: avatar huy hiệu, rank + tiến độ, Coin/Log, nút Bắt đầu, 3 ô hôm nay, biểu đồ 7 ngày + streak, trang Phân tích (lịch tháng, giờ vàng, tốc độ xao nhãng, tương quan).
- **Thiết lập trận** (bottom sheet): task, thời gian tập trung/nghỉ (preset hoặc tùy chỉnh), số phiên, nghỉ dài sau N phiên, thanh lịch trình, giờ xong và Coin dự kiến.
- **Trận**: nền `battle_field.webp`, timer trong ribbon, nhà goblin mất máu theo thời gian (hết giờ thì sập), quái chạy ra chỉ để trang trí. Tạm dừng 1 lần/phiên (tối đa 5 phút). Bỏ cuộc phải giữ nút 2s. Giữa các phiên là Camp (lửa trại, thưởng phiên, "Xung trận ngay").
- **Kinh tế**: mỗi phiên `Coin = phút × hệ số thời lượng × (1 + 10% × cấp Doanh trại)`, `Log = ⌊phút × 0.5⌋`. Coin/Log **và giờ focus** được tạm giữ, chỉ ghi nhận khi xong trọn trận. Thua/bỏ cuộc mất hết.
- **Hình phạt**: chỉ khi mở app trong blacklist lúc đang trận. Hết ân hạn (10s, Tháp canh nâng lên 12/15s) thì −25 HP + overlay; mỗi 30s ở lại −15 Coin quỹ trận; HP 0 là thua.
- **Rank**: Starter 0h → Gold 10h → Diamond 30h → Ruby 70h → Amethyst 150h, lần lượt mở Pawn, Lancer, Archer, Monk, Warrior. Huy hiệu (nhân vật × rank) mở khi nhân vật đã mở và đã đạt rank đó.
- **Làng**: 8 ô cố định. Có tác dụng: Tháp canh (ân hạn), Kho lương (1 vé giữ chuỗi/tuần), Doanh trại (+% Coin). Còn lại là trang trí; nhà nhân vật khoá theo rank.

## Cấu trúc mã

```
lib/
├── main.dart                      # Khởi tạo, vòng đời app, DistractionGuard, overlay entry
├── core/
│   ├── game/                      # Luật thuần + state người chơi
│   │   ├── progression.dart       # Rank, GameCharacter, badge
│   │   ├── economy.dart           # sessionReward, hằng số HP/thuế/pause
│   │   ├── village.dart           # Building, buildCost, graceSecondsFor
│   │   ├── battle_plan.dart       # BattlePlan, timeline, giờ xong
│   │   ├── player_state.dart      # Ví, nhân vật/huy hiệu đang chọn, building, vé
│   │   └── sprites.dart           # Bảng sprite sheet (số frame)
│   ├── services/                  # overlay, foreground task, distraction_guard
│   └── widgets/                   # SpriteAnim (không Canvas), PixelIcon, Ribbon, Flat theme
└── features/
    ├── focus_session/             # FocusSessionController: trận, quỹ tạm giữ, HP, pause
    ├── battle/                    # BattleScreen, Focus/Camp/Result view, setup sheet
    ├── home/  collection/  village/  settings/  shell/
    ├── dashboard/                 # FocusHistoryService, AnalyticsService, card phân tích
    ├── overlay/                   # BlockerOverlayWidget (isolate riêng, nhận shareData)
    └── telemetry/                 # ScreenTimeTracker
ui/                                # Asset Tiny Swords + font Pixelify Sans
```

## Lưu trữ (SharedPreferences)

`fk_gold` (coin), `fk_logs`, `fk_character`, `fk_badge`, `fk_buildings`, `fk_streak_tickets`, `fk_granary_built`, `fk_ticket_week`, `fk_shielded_dates`, `fk_last_plan`, `fk_long_rest_minutes`, cùng các key lịch sử focus/analytics sẵn có (`fk_completed_dates`, `fk_total_focus_seconds_all_time`, `fk_focus_sec_*`, …).

## Kiểm thử

`flutter test` – luật game, PlayerState, controller trận, guard hình phạt, vé giữ chuỗi và widget test cho các màn chính.
