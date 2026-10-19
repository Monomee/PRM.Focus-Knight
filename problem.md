### 1. Tầng Logic & Hệ thống Game (Game System & Logic)

#### A. Tách bạch & Kết nối lại Kinh tế Pomodoro

* **Vấn đề hiện tại:** `CombatEngine` đang tự chạy vòng lặp đánh quái cứ vài giây lại rơi vài đồng vàng (`(currentStage * 8) + 5`). Điều này biến Pomodoro thành một game clicker/idle nông cạn, không gắn kết gì với sự nỗ lực tập trung của người dùng.


* **Cần sửa:**
1. **Triệt tiêu cơ chế rơi vàng tự do:** Quái vật trên màn hình chỉ là "Bao cát đại diện cho xao nhãng". Hiệp sĩ chém quái theo nhịp đếm giờ.


2. **Bổ sung tài nguyên `Log` (Gỗ):** Cập nhật `CombatEngine` và `FocusHistoryService` để lưu trữ cả `gold` và `logs` vào `SharedPreferences`.


3. **Đưa công thức kinh tế vào `FocusSessionController._onFocusCompleted()`:** Khi phiên kết thúc, tính thưởng theo công thức đã chốt:
* $\text{Coin} = (T_{\text{focus}} \times 1.0) \times M_{\text{duration}}$.


* $\text{Log} = \lfloor T_{\text{focus}} \times 0.5 \rfloor$.
Sau đó gọi sang `CombatEngine.rewardSessionComplete(coins, logs)` để cộng tài nguyên một lần duy nhất.







#### B. Thay thế Cơ chế Nâng cấp: Chuyển từ "Stat RPG" sang "Passive Camp Upgrades"

* **Vấn đề hiện tại:** `CampUpgradeSheet` đang cho mua ATK (+2), Max HP (+10), Crit Rate (+1%). Người dùng dùng app để học tập chứ không quan tâm hiệp sĩ gây 16 hay 18 sát thương.


* **Cần sửa:** Xóa bỏ bảng nâng cấp ATK/HP/Crit này. Thay bằng bảng **Nâng cấp Căn cứ (Base Buildings)** sử dụng bộ sprite `buildings`:


* **Trại Binh Mã (Doanh trại lính):** Tốn Coin + Log để nâng cấp $\rightarrow$ Buff: Tăng % EXP nhận được mỗi phiên.


* **Kho Lương Thực:** Buff: Đổi lấy Vé bảo vệ chuỗi (Streak Shield).


* **Tháp Canh Đá:** Buff: Tăng thời gian ân hạn Overlay từ 10s lên 15s trước khi phạt.





#### C. Thay thế Hệ thống Skin bằng Hệ thống Bậc Rank

* **Vấn đề hiện tại:** `CosmeticsManager` đang quản lý 3 bộ skin tự chế (`squire`, `paladin`, `assassin`).


* **Cần sửa:** Viết lại enum và manager thành **5 Bậc Rank** mở khóa theo `totalFocusHoursAllTime`:


* `Starter` (0h): Dùng sprite nhân vật **Pawn**.


* `Gold` (10h): Dùng sprite nhân vật **Lancer**.


* `Diamond` (30h): Dùng sprite nhân vật **Warrior**.


* `Ruby` (70h): Dùng sprite nhân vật **Archer**.


* `Amethyst` (150h): Dùng sprite nhân vật **Monk**.





#### D. Tích hợp Hình phạt vào `OverlayService` và `BlockerOverlayWidget`

* **Vấn đề hiện tại:** Khi mở app bị chặn, overlay chỉ hiện chữ cảnh báo và nút "Return to focus". Không có tổn thất gì cho người dùng.


* **Cần sửa:**
1. Trong `OverlayService`, khi hết 10 giây ân hạn (`onGraceExpired`): Gọi `CombatEngine.takePenaltyDamage(25)` (trừ 25% HP Hiệp sĩ).


2. Nếu người dùng cố tình ở lại app MXH quá 30 giây tiếp theo: Trừ tiếp 15 Coin (Thuế xao nhãng).
3. Khi HP về 0: Hiệp sĩ kích hoạt trạng thái `isDefeated = true` (sprite `dead`), hủy toàn bộ Coin/Log của ca làm việc đó.


4. Trên `BlockerOverlayWidget`: Hiển thị thanh máu đang tụt của Hiệp sĩ và số Coin bị phạt để tạo tâm lý tiếc của (Loss Aversion).



---

### 2. Tầng Đồ họa & Rendering (Sprite Sheet vs Canvas)

#### A. Khai tử `PixelStageCanvas` vẽ tay thủ công

* Toàn bộ file `pixel_stage_canvas.dart` hiện tại đang vẽ nhân vật bằng các lệnh `canvas.drawRect` ghép từng pixel. Cách làm này vừa tốn công, vừa xấu, vừa giật lag (chạy 60 FPS cố định), và hoàn toàn bỏ phí bộ asset *Tiny Swords* bạn đã có.


* **Kiến trúc mới thay thế:** Xây dựng `SpriteViewportWidget` theo cấu trúc 4 tầng:
1. **Lớp 1 (Nền tĩnh):** `Image.asset('assets/scenes/battlefield.webp')` tỉ lệ chuẩn 16:9, kích thước 1080×608 px, thiết lập `filterQuality: FilterQuality.none`.
2. **Lớp 2 (Công trình):** Hiển thị sprite công trình căn cứ tương ứng với cấp độ hiện tại (chỉ hiện ở scene Trại lính).


3. **Lớp 3 (Nhân vật động):** Bọc trong `RepaintBoundary`. Sử dụng `CustomPainter` cắt runtime từ file sprite sheet lớn (`Canvas.drawImageRect`).


4. **Lớp 4 (HUD Đếm giờ):** Viên HUD Capsule nổi (Top-Center) và các nút bấm Ghost.



#### B. Xử lý Trạng thái Hoạt ảnh (Animation State Machine)

* Chỉ chạy nhịp **8 – 12 FPS** cho animation nhân vật (dùng `AnimationController` với thời gian ~600ms lặp lại 6 frame). Điều này vừa giảm triệt để tải cho GPU/pin, vừa tạo đúng chất hoạt họa Trung cổ của Tiny Swords.


* **Xử lý Hurt bằng Code:** Áp dụng `ColorFilter.mode(Colors.white, BlendMode.srcIn)` trong 60ms đầu tiên, sau đó ám đỏ 150ms kết hợp dịch chuyển `Offset(-4, 0)` để tạo lực giật lùi (knockback).
* **Xử lý Chuyển cảnh bằng Sprite Run:** Khi hết giờ Focus, tắt sprite quái vật, cho Hiệp sĩ chạy (`run`) từ trái sang phải màn hình trong 0.8 giây trước khi trượt nền sang Trại lính.



---

### 3. Tầng Giao diện & Trải nghiệm Người dùng (UI/UX)

#### A. Màn hình Trận đấu (`PomodoroGameScreen`)

* **Lỗi UX hiện tại:** Bạn đang nhồi nhét cả TabBar (Trận Đấu & Trại / Ngoại Trang), cả bảng điều khiển thiết lập phiên, và danh sách thông số trận đấu vào cùng một màn hình. Khi người dùng đang tập trung, việc nhìn thấy một màn hình đầy chữ và tab như vậy gây phân tán nhận thức nghiêm trọng.


* **Cần chỉnh sửa:**
1. **Phân chia 2 chế độ rõ rệt:**
* **Chế độ Setup (Chuẩn bị):** Cho phép cấu hình Task Name, số phiên, thời gian tập trung (15p, 25p, 50p), thời gian nghỉ. Viewport phía trên hiển thị Hiệp sĩ đang đứng nghỉ (`idle`).


* **Chế độ Combat (Đang tập trung):** Khi bấm "Bắt đầu", **toàn bộ TabBar và các vùng cấu hình bên dưới biến mất hoàn toàn**. Màn hình chuyển thành không gian tối tĩnh lặng (Zen Mode). Nửa trên là Viewport chiến đấu, nửa dưới chỉ để lại câu trích dẫn truyền cảm hứng hoặc tên Task đang làm việc dạng tối giản.




2. **Ghost Controls trong Viewport:**
* Nút Nhạc và Nút Tạm dừng ở 2 góc dưới viewport sẽ tự động mờ dần về `opacity: 0.2` sau 3 giây không chạm màn hình.
* Nút Bỏ cuộc bắt buộc phải dùng thao tác **Giữ 2 giây (Long-press)** để ngăn chặn việc chạm nhầm làm hỏng phiên.


3. **Camp Phase (Khi hết giờ và bước vào giờ nghỉ):**
* Viewport co lại còn 25–30% chiều cao màn hình.
* Nửa dưới tự động trượt lên một Bottom Sheet hiển thị số Coin và Log vừa nhận được, đi kèm danh sách Nâng cấp Căn cứ.
* **Nút "Xung trận ngay (Bỏ qua nghỉ)":** Nằm cố định ở đáy màn hình (Bottom Pin) để người dùng có thể duy trì đà làm việc (Flow State) nếu không muốn nghỉ 5 phút.







#### B. Màn hình Dashboard Chính (`dashboard_screen.dart`)

* **Lược bỏ phong cách bo tròn bóng bẩy:** Hiện tại bạn đang dùng khá nhiều gradient bóng đổ (`BoxShadow` màu cam, viền mờ rực sáng...). Hãy làm sạch giao diện theo hướng **Neo-Retro Minimalist**:


* Đổi tất cả các card thành dạng phẳng, nền Dark Slate (`#11151F`), viền 1.5px màu nét mực mực đen/xám tối (`#232A3B`).


* Thay thế các icon tròn bóng bẩy bằng chính **12 icon pixel** bạn đã trích xuất từ pack `UI Elements` (coin, sword, shield, log...).




* **Thanh trạng thái trên AppBar:** Đưa cả 2 chỉ số tài nguyên lên góc phải AppBar: `[Coin Icon] X Coin  •  [Log Icon] Y Log`.



---

### Kế hoạch hành động từng bước (Next Steps)

Đừng cố sửa tất cả cùng một lúc. Hãy làm tuần tự theo 4 bước sau để kiểm soát chất lượng code:

1. **Bước 1 (Clean Engine):** Sửa `CombatEngine` và `FocusSessionController` để chốt xong bài toán kinh tế (tính Coin/Log theo thời gian thực và xóa vòng lặp đánh quái rơi vàng vô tội vạ).


2. **Bước 2 (Rendering Viewport):** Xóa `PixelStageCanvas`. Dựng một `BattleSceneView` mới dùng ảnh nền WebP 16:9 và viết `CustomPainter` cắt sprite sheet của Warrior/Enemy Tiny Swords.


3. **Bước 3 (UI Flow Refactor):** Sửa lại `PomodoroGameScreen`: ẩn toàn bộ tab khi bắt đầu Focus, gắn timer HUD lên đỉnh Viewport, và hiện Bottom Sheet Trại lính khi đến giờ nghỉ.


4. **Bước 4 (Penalty & Upgrades):** Kết nối hình phạt mất máu của Hiệp sĩ vào `OverlayService` và thay thế bảng nâng cấp chỉ số thành nâng cấp công trình căn cứ.



