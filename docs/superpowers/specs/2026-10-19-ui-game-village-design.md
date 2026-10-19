# FocusKnight – UI mới, Rank/Nhân vật, Làng & Kinh tế

Ngày: 2026-10-19 · Trạng thái: đã duyệt · Mockup tham khảo: `.superpowers/brainstorm/1965-1792375693/content/screens-v1.html`, `screens-v2.html` (không commit)

Các mục đánh dấu **[call]** là quyết định của người viết spec, chủ dự án chưa xác nhận – builder có thể giữ hoặc chỉnh.

## 1. Mục đích

App Pomodoro cho người học/làm việc, có lớp game để giữ động lực. Hiện tại (`problem.md`):
- Game là idle-clicker rơi vàng, không gắn với nỗ lực tập trung.
- Đồ hoạ vẽ tay bằng `canvas.drawRect` (`pixel_stage_canvas.dart`), bỏ phí bộ asset Tiny Swords trong `ui/`.
- Màn game nhồi tab + form + thông số, gây phân tán khi đang tập trung.
- Dashboard bóng bẩy, rối.

Mục tiêu: **bên ngoài game = dashboard phẳng, đơn giản, dễ nhìn; bên trong phiên focus = UI game pixel hoàn toàn**. Phần thưởng chỉ đến từ thời gian tập trung thật.

## 2. Goals / Non-goals / Anti-goals

**Goals**
- Dashboard một cột, phẳng, 4 tab dưới: Trang chủ · Làng · Bộ sưu tập · Cài đặt.
- Màn focus full-screen dùng scene + sprite thật, animation sprite **không dùng Canvas/CustomPainter**.
- Hệ thống Rank → mở nhân vật + huy hiệu; chọn nhân vật ra trận và chọn huy hiệu làm avatar.
- Kinh tế Coin + Log trả một lần khi xong phiên; Làng để tiêu.
- Hình phạt khi rời app trong lúc focus (theo `problem.md` mục 1.D).

**Non-goals**
- Không chỉ số chiến đấu (ATK/HP/Crit), không skin tự chế, không companion/camp cosmetic cũ.
- Không backend, không đồng bộ cloud; vẫn `SharedPreferences`.
- Không hỗ trợ landscape/tablet riêng (app khoá portrait).

**Anti-goals (coi là thất bại dù chạy được)**
- Người dùng phải "tính toán tối ưu" building/chỉ số → app thành game RPG.
- Màn focus có chữ/tab/form gây xao nhãng.
- Có nguồn Coin/Log không đến từ thời gian focus (quái rơi vàng, tap…).
- Rank bị thổi phồng: không buff nào được cộng vào giờ; giờ chỉ đến từ các trận hoàn thành trọn vẹn.
- Thêm package mới chỉ để làm việc vài dòng code làm được.

## 3. Ràng buộc

- Flutter, Android là đích chính (thiết bị debug Samsung `R3CN90V2K3X` qua adb). Portrait.
- Dependencies hiện có: `usage_stats`, `flutter_foreground_task`, `flutter_overlay_window`, `shared_preferences`. Không thêm package; font pixel (vd. Pixelify Sans `.ttf`, OFL) được phép thêm như asset.
- Overlay chặn chạy trong **isolate riêng** (`overlayMain` trong `main.dart`) → không đọc được state của `CombatEngine`; muốn hiện HP/Coin trên overlay phải gửi qua `FlutterOverlayWindow.shareData` / `overlayListener`.
- Asset đang nằm ở `ui/` và **chưa khai báo** trong `pubspec.yaml`. Scene `battle_field.webp`, `camp_fire.webp` là ảnh **dọc 1080×1920** (không phải 16:9 như `problem.md` ghi).
- Test hiện có trong `test/` phải tiếp tục pass (hoặc cập nhật khi hành vi thay đổi có chủ đích).

## 4. Rank, Nhân vật, Huy hiệu (đã chốt với chủ dự án)

Rank tính từ `FocusHistoryService.totalFocusSecondsAllTime`.

| Rank | Ngưỡng giờ **[call: lấy từ problem.md]** | Mở nhân vật |
|---|---|---|
| Starter | 0h | Pawn |
| Gold | 10h | Lancer |
| Diamond | 30h | Archer |
| Ruby | 70h | Monk |
| Amethyst | 150h | Warrior |

- Nhân vật: chỉ là mở khoá; đã mở thì chọn tự do, không khác chỉ số.
- Huy hiệu: lưới 5 nhân vật × 5 rank (`ui/ranks/<char>/<char>_<rank>.png`). Ô (char, rank) mở khi **char đã mở VÀ rank hiện tại ≥ rank của ô**. Nhân vật vừa mở nhận ngay mọi huy hiệu từ Starter tới rank hiện tại.
- Người dùng chọn 1 huy hiệu đã mở làm **avatar** trên header Trang chủ.
- Trạng thái lưu thêm: `selectedCharacter`, `selectedBadge`. Mọi thứ khác suy ra từ tổng giờ. Mặc định: Pawn + pawn_starter.
- Thay thế hoàn toàn `CosmeticsManager` / `skin_cosmetics.dart`.

## 5. Kinh tế & Hình phạt

**Thưởng** – tính một lần cho mỗi phiên trong `FocusSessionController._onFocusCompleted()` (cộng vào quỹ tạm giữ, xem dưới):
- `Coin = round(phútFocus × M_duration × (1 + buffDoanhTrại))`
- `Log = floor(phútFocus × 0.5)`
- `M_duration` **[call]**: <25p → 1.0; 25–49p → 1.2; ≥50p → 1.5.
- Xoá cơ chế quái rơi vàng trong `CombatEngine` và toàn bộ nâng cấp ATK/HP/Crit.
- Lưu `coin`, `log` vào `SharedPreferences` (giữ key `fk_gold` cho coin để không mất dữ liệu cũ **[call]**).

**Thưởng tạm giữ trong trận (đã chốt: phạt nặng)** – Coin/Log của mỗi phiên hoàn thành được cộng vào quỹ **tạm giữ của trận**, chỉ chuyển vào ví khi **hoàn thành toàn bộ trận**. Thua hoặc bỏ cuộc → mất toàn bộ quỹ tạm giữ của trận. **[call]** Chọn mô hình tạm giữ (thay vì cộng rồi trừ lại) để ví không bao giờ âm và Làng chỉ tiêu được tiền đã chắc chắn.
- **Thua/bỏ cuộc = không tính giờ, không tính coin (đã chốt)**: giờ focus của trận cũng được tạm giữ như Coin/Log; chỉ khi xong trọn trận mới ghi vào `FocusHistoryService` (tổng giờ/rank, phút trong ngày, số phiên, giờ vàng, ngày hoàn thành/streak). Trận thua chỉ ghi số lần xao nhãng. **[call]** áp dụng cho cả các phiên đã xong trong trận thua. Hiện `recordCompletedSession` được gọi sau mỗi phiên → phải dời về cuối trận.

**Hình phạt (đã chốt)** – thời gian ân hạn lấy từ Tháp canh:
- **Chỉ phạt khi mở app trong danh sách đen** (`BlacklistConstants`) trong lúc focus. Rời sang app khác (gọi điện, tin nhắn…) chỉ ghi 1 lần xao nhãng vào thống kê, không phạt. Đổi so với hiện tại: grace timer chỉ bắt đầu khi phát hiện app blacklist.
1. Mở app blacklist → hết ân hạn (10s mặc định) → hiện overlay + nhân vật **−25 HP** (HP tối đa 100).
2. Còn ở lại app blacklist: **cứ mỗi 30s trừ 15 Coin** từ quỹ tạm giữ của trận (không xuống dưới 0).
3. Mỗi lần quay lại app blacklist sau khi đã thoát ra → tính lại từ bước 1 (ân hạn + −25 HP).
4. HP về 0 → `isDefeated`, sprite `Dead.png`, trận kết thúc, mất toàn bộ quỹ tạm giữ.
- HP hồi đầy khi bắt đầu trận mới; không hồi giữa các phiên trong cùng trận **[call]**.
- Overlay hiển thị HP đang tụt, quỹ tạm giữ đang bị trừ (gửi qua `shareData`). Thay icon Material bằng icon pixel.

## 6. Luồng màn hình

### 6.1 Trang chủ (dashboard phẳng)
Theo mockup v1 màn 1. Style: nền `#0F131C`, card `#151A26` phẳng viền 1.5px `#232A3B`, accent `#FFB300`, không gradient/glow. Icon dùng `ui/icons/*.png` (pixel, `FilterQuality.none`).
Thứ tự từ trên xuống:
1. Header: avatar huy hiệu · tên rank + thanh tiến độ "Xh / Yh → rank kế" · Coin & Log.
2. Card Bắt đầu: sprite idle nhân vật đang chọn, ô tên task, nút **Bắt đầu** → mở bottom sheet 6.2.
3. 3 ô hôm nay: phút focus, số phiên, số lần xao nhãng.
4. Biểu đồ cột 7 ngày + streak (thay/bổ sung lịch chấm tháng – **[call]** giữ lịch tháng ở trang Thống kê chi tiết).
5. Nhóm dòng thu gọn mở ra trang con: Giờ vàng, Tốc độ xao nhãng, Tương quan (dùng lại 3 widget card hiện có).

Phần telemetry / giới hạn app / quyền overlay & usage → tab **Cài đặt**.

### 6.2 Bottom sheet "Thiết lập trận" (phương án A – đã chốt)
- Tên task.
- Tập trung: chip 15/25/50 + "Tùy…" (nhập phút).
- Nghỉ ngắn: chip 3/5/10 + "Tùy…".
- Số phiên (stepper 1–8) và **Nghỉ dài sau N phiên** (stepper; độ dài nghỉ dài **[call]** = 15p, chỉnh trong Cài đặt).
- Thanh lịch trình tô màu (focus vàng / nghỉ xanh lá / nghỉ dài xanh dương), giờ xong dự kiến, Coin dự kiến.
- Nút **Xuất trận** → màn focus.
- Nhớ lựa chọn lần trước **[call]**.
- `FocusSessionController` phải bổ sung nghỉ dài (hiện chỉ có một loại nghỉ).

### 6.3 Màn Focus (phương án C – đã chốt)
Full-screen, không AppBar, không tab. Theo mockup v2 màn C.
- Nền `battle_field.webp` cover.
- HUD trên: timer trong `Ribbon_Yellow_3Slides.png` (co giãn bằng `centerSlice`), dưới là "Phiên i/n · tên task".
- **Nhà goblin = máu của phiên**: `Goblin_House.png` bên phải, thanh máu giảm tuyến tính theo thời gian còn lại; về 0 khi hết giờ → đổi sang `Goblin_House_Destroyed.png`. Góc trên hiện các nhà đã phá / còn lại của trận.
- Quái (torch/tnt/barrel, ngẫu nhiên) chạy ra từ nhà, nhân vật đang chọn tấn công theo nhịp. Thuần hình ảnh, không sinh tài nguyên.
- Nhân vật có thanh HP (mục 5). Khi bị phạt: nháy trắng ~60ms, ám đỏ ~150ms, giật lùi 4px.
- **Tạm dừng (đã chốt)**: mỗi phiên được dừng **1 lần, tối đa 5 phút**, hết 5 phút tự chạy tiếp. Khi dừng, timer + máu nhà goblin đứng yên; notification foreground hiện "Tạm dừng mm:ss". Mở app blacklist khi đang dừng vẫn bị phạt. `FocusSessionController` cần thêm pause/resume.
- Ghost controls: nhạc + tạm dừng góc trái dưới, bỏ cuộc góc phải dưới; mờ về opacity 0.2 sau 3s không chạm. Bỏ cuộc phải **giữ 2s**; giữ lại dialog Mindful Interruption hiện có cho nút back hệ thống.
- Hết giờ: quái biến mất, nhân vật chạy sang phải ~0.8s → chuyển Camp.

### 6.4 Camp (giờ nghỉ)
Theo mockup v1 màn 4: nửa trên `camp_fire.webp` + nhân vật idle + ribbon xanh "Nghỉ mm:ss"; nửa dưới sheet gỗ hiện +Coin/+Log vừa nhận **và tổng quỹ tạm giữ của trận** (ghi rõ "nhận khi xong trận"), cùng lối vào Làng (nâng cấp bằng ví hiện có, không dùng quỹ tạm giữ). Nút ghim đáy **Xung trận ngay** (= `finishRestBreak()`).
Phiên cuối của trận: Camp hiện tổng kết rồi nút "Về làng"/"Về trang chủ".

### 6.5 Tab Làng (phương án D – đã chốt)
Bản đồ cố định trên nền `camp_fire.webp`, các ô xây đặt ở toạ độ cố định (theo % màn hình). Building đã xây hiện sprite + cấp; ô trống hiện icon búa; ô khoá hiện điều kiện. Chạm → sheet chi tiết (tác dụng / chi phí / nút Xây-Nâng cấp).

**Building có tác dụng (chỉ 3 – đã chốt):**
| Building | Sprite | Tác dụng | Cấp |
|---|---|---|---|
| Tháp canh | Tower | Ân hạn rời app 10s → 12s → 15s | 2 |
| Kho lương | House1 | +1 vé giữ chuỗi mỗi tuần (tối đa giữ 1 vé **[call]**) | 1 |
| Doanh trại | Barracks | +10% / +20% Coin mỗi phiên | 2 |

**Building trang trí (chỉ hình ảnh, chỗ tiêu tài nguyên):**
- Nhà của nhân vật, chỉ xây khi đã mở nhân vật đó: Archery (Archer), Monastery (Monk), Castle (Warrior) **[call cho Castle]**. Lancer/Pawn không có nhà riêng **[call]**.
- House2, House3: nhà dân, xây thêm cho làng đông.
- Building trang trí có tối đa 3 cấp; khác biệt cấp chỉ ở nhãn cấp (asset chỉ có 1 hình/building) **[call]**.

Chi phí **[call, chỉnh sau khi chơi thử]**: building có tác dụng 150–300 Coin + 30–60 Log mỗi cấp, tăng ×1.5 mỗi cấp; trang trí 100–400 Coin + 20–80 Log.

**Ô xây [call]**: 8 ô cố định, mỗi building chỉ có 1 bản (Tower, House1, Barracks, Archery, Monastery, Castle, House2, House3). Lưu `Map<buildingId, level>` (0 = chưa xây). Ô khoá chỉ vì nhân vật chưa mở (Archery/Monastery/Castle).

**Vé giữ chuỗi [call]**: Kho lương cấp 1 → mỗi tuần lịch (thứ Hai) cấp 1 vé, giữ tối đa 1. Khi phát hiện một ngày trống trong chuỗi (sau ngày xây Kho lương) và còn vé → tiêu vé và **lưu ngày đã bù** (`fk_shielded_dates`); `calculateStreak` coi ngày trong danh sách này như ngày đã hoàn thành. Không bù ngày trước khi xây Kho lương.

### 6.6 Bộ sưu tập
Theo mockup v1 màn 2: hàng nhân vật (đã mở chạy idle, chưa mở tối + rank cần đạt), chạm để chọn ra trận; lưới huy hiệu 5×5, chạm ô đã mở để đặt làm avatar; dòng "Còn Xh để mở ...".

### 6.7 Cài đặt
Chuyển nguyên từ dashboard cũ: quyền usage stats & overlay, hạn mức MXH/ngày, giới hạn từng app; thêm độ dài nghỉ dài.

## 7. Kỹ thuật đã chốt

- **Animation sprite không dùng Canvas**: một widget dùng chung, sheet là dải ngang các frame vuông (số frame = width/height). Hiển thị bằng `ClipRect` + `OverflowBox`/`Align` (hoặc `FractionalTranslation`) quanh `Image.asset(filterQuality: FilterQuality.none)`, đổi frame bằng `AnimationController` ~10 FPS. Lật hướng bằng `Transform.flip`.
  - Kích thước frame thực tế: phần lớn 192px; Lancer 320px; Barrel 128px; `Dead.png` 128px.
- Khai báo assets trong `pubspec.yaml` từ thư mục `ui/` (giữ nguyên vị trí hoặc chuyển sang `assets/` – builder quyết).
- Xoá `pixel_stage_canvas.dart`, `skin_cosmetics.dart`, `camp_upgrade_sheet.dart` (thay bằng Làng), phần stat/upgrade/gold-drop của `combat_engine.dart`.
- Font pixel chỉ dùng trong màn game/Camp/Làng; dashboard dùng font hệ thống.

## 8. Thứ tự triển khai đề xuất **[call]**
Mỗi bước chạy được trên điện thoại:
1. Assets + widget sprite + màn Focus mới (C) + Camp, nối với controller hiện có.
2. Kinh tế Coin/Log + nghỉ dài + bottom sheet Thiết lập (A).
3. Dashboard phẳng 4 tab + Bộ sưu tập + Rank/huy hiệu + Cài đặt.
4. Làng + 3 buff + vé giữ chuỗi.
5. Hình phạt + overlay mới.

## 9. Để builder tự quyết
Cấu trúc file/thư mục, tên class, cách quản lý state (giữ `ChangeNotifier` như hiện tại là ổn), toạ độ ô xây trên bản đồ, nhịp tấn công/spawn quái, chi tiết animation chuyển cảnh, nội dung text/copy.
