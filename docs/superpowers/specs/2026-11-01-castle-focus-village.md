# Castle và làng xây bằng Pomodoro

## Yêu cầu đã xác nhận

- Castle là nhà chính, luôn xuất hiện lớn ở trên giữa, không cần mua/mở khóa Castle.
- Ba nâng cấp chuyển vào Castle, giữ giá và số cấp cũ: Tháp canh/ân hạn (Starter, 2 cấp, 200 Coin + 40 Log cấp đầu); Kho lương/vé giữ chuỗi (Gold, 1 cấp, 150 + 30); Doanh trại/tăng Coin (Diamond, 2 cấp, 300 + 60). Giá cấp tiếp theo giữ hệ số 1,5. Dòng chưa đủ rank có lớp khóa và không mua được.
- Một lần thiết lập/chạy toàn bộ chuỗi Pomodoro tạo một công trình. Tổng phút = phút focus × số phiên, không tính nghỉ/pause.
- 1–30: House1; 31–60: Archery; 61–100: Tower; 101–150: Monastery; trên 150: Barracks. Setup hiển thị ảnh/tên công trình theo tổng phút hiện tại.
- Hoàn thành toàn bộ mới nhận nhà nguyên vẹn cùng phần thưởng. Thua/bỏ cuộc/phiên còn dang dở khi khởi động lại thành Goblin_House_Destroyed, chiếm ô vĩnh viễn, không sửa/xóa/xây đè. Công trình focus chỉ là thành tích, không cộng hiệu ứng nâng cấp.
- Giữ nâng cấp chức năng cũ trong Castle; hoàn đúng tổng Coin/Log các cấp nhà trang trí đã mua, một lần. Giữ ví, rank, nhân vật, huy hiệu và lịch sử.

## Quyết định triển khai

- Lưới 3×3/mảnh đất; tự dùng ô trống tiếp theo. Luôn có mảnh tiếp theo khi mảnh hiện tại đầy. Chỉ phần lưới thay đổi khi bấm Trước/Sau, Castle không chuyển trang. Tái sử dụng ảnh/font hiện có.
- Giữ các enum Building cũ để đọc dữ liệu/mức nâng cấp; chỉ ba chức năng được mua qua Castle. Thêm loại công trình focus và trạng thái đang xây/hoàn thành/đổ nát.
- Lưu migration marker, mức nâng cấp, ví và các ô xây trong cùng wallet snapshot, dưới khóa cũ. Ghi xong mới cập nhật bộ nhớ; thất bại không trừ tiền/khởi động phiên. Nâng cấp cũ vẫn có tác dụng nếu người dùng chưa đạt rank mới, nhưng mua thêm phải đủ rank.
- Bắt đầu phiên cần await ghi ô đang xây. Controller chặn bắt đầu đồng thời và không cho bỏ qua bước này. Hoàn thành cập nhật ô theo ID trong journal trả thưởng hiện có, idempotent khi retry/khởi động lại.
- Khi khởi động, nạp/migrate ví, tiếp tục journal thắng còn dở trước, sau đó mới chuyển các ô vẫn đang xây thành nhà đổ. Không đánh dấu công trình của một trận đã thắng thành nhà đổ chỉ vì tiến trình bị ngắt khi trả thưởng.
- Không đổi luật phần thưởng Coin/Log, rank, ân hạn, phạt, thời gian nghỉ hoặc theo dõi ứng dụng.

## Kiểm chứng

Test các ranh giới 30/31/60/61/100/101/150/151; rank/cấp/giá Castle; migration/hoàn tiền một lần và lỗi ghi; thắng/thua/bỏ cuộc/dang dở; retry sau trả tiền mà chưa hoàn thành ô; đồng thời bắt đầu hai phiên; lưới nhiều trang, Castle cố định, khóa rank, preview tổng focus bỏ giờ nghỉ. Chạy toàn bộ test/analyze/build và cài cập nhật tương thích, không xóa dữ liệu.
