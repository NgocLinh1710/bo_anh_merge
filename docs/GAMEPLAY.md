# Độ khó, mục tiêu và cứu trợ

Cân bằng, mục tiêu và cứu trợ áp dụng cho **chơi tự do**. Thử thách thời gian giữ
luật, thời gian và phần thưởng hiện có; không có đổi ô hoặc các huy hiệu này.
Câu hỏi vào ver 7–8 áp dụng cho **cả hai chế độ**.

Ver 1–6 sinh ảnh cấp thấp nhiều hơn, giảm hỗ trợ dần ở các ver sau. Ver 7–8 giữ
cấu hình mặc định và 3/4 cấp ảnh để là những ván ngắn. Không cần ghép lặp nhiều
vòng để mở một ảnh. Chỉnh tỉ lệ tại `lib/models/spawn_config.dart`.

## Mốc và kết quả mô phỏng

Chạy `dart run tool/simulate_balance.dart`: 500 seed mỗi ver, mỗi chiến lược,
không dùng cứu trợ, dừng tại lần đầu ghép ra ảnh cuối. Trung vị chỉ tính các ván
đạt ảnh cuối. Đây là mô phỏng, cần chơi thử thực tế trước khi chốt cân bằng.

| Ver | Trung vị cũ, chọn cặp ngẫu nhiên | Trung vị mới | Ván đạt ảnh cuối / 500 | Mốc Nhanh tay |
| --- | --- | --- | --- | --- |
| 1 | 85 | 95 | 500 | 90 |
| 2 | 90 | 96 | 500 | 95 |
| 3 | 106 | 117 | 500 | 115 |
| 4 | 124 | 137 | 500 | 135 |
| 5 | 133 | 173 | 498 | 165 |
| 6 | 196 | 254 | 481 | 240 |
| 7 | — | 3 | 500 | 3 |
| 8 | — | 7 | 500 | 7 |

Chiến lược dọn cặp thấp trước vẫn đạt ảnh cuối ở ít nhất 499/500 ván mỗi ver.
Ver 6 ghép cặp cao trước chỉ đạt 39/500 ván: việc dọn ảnh lẻ có ý nghĩa lớn.
Không bảo đảm có nước đi mãi; người chơi có thể thua.

## Huy hiệu và kỷ lục

- **Nhanh tay:** ghép ra ảnh cuối trong mốc lượt của ver. Mốc cấu hình tại
  `ChallengeGoals.targetMoves` trong `lib/models/collection_achievement.dart`.
- **Tự lực:** ghép ra ảnh cuối khi chưa dùng lượt đổi ô.
- **Phá kỷ lục số lượt:** hoàn thành nhanh hơn kỷ lục số lượt cũ của chính ver
  đó. Lần thắng đầu tiên lập mốc; bằng kỷ lục không tính là phá kỷ lục.

Chốt số lượt ngay lần ghép ra ảnh cuối đầu tiên trong ván. Chơi tiếp không làm
thay đổi mốc ấy. Đổi ô sau khi đã hoàn thành không thu hồi huy hiệu Tự lực.
Các huy hiệu là thành tích, không phát thêm xu; kỷ lục điểm cũ vẫn được giữ.
Mỗi ver lưu huy hiệu và kỷ lục qua các lần chơi lại.

## Đổi ô

Mỗi ván tự do có một lượt miễn phí: bấm **Đổi 1 ô**, rồi chạm ô muốn thay.
Ảnh thay thế khớp ảnh cấp thấp nhất khác cấp đang có trên bàn, không phải ảnh
cuối. Chỉ ô được chọn thay đổi, bảo đảm có một cặp ghép được. Có thể dùng khi
hết nước đi qua nút **Đổi 1 ô để cứu bàn**. Nếu ô chọn không có ảnh phù hợp,
game yêu cầu chọn ô khác và chưa trừ lượt. Hủy chọn cũng không trừ lượt.

Đổi ô không tăng điểm, số lượt ghép, tiến độ nhận xu hoặc lượt thắng. Chỉ xác
nhận đổi sau khi lưu thành công; lỗi lưu vẫn giữ nguyên bàn và lượt cứu trợ.
Tải lại trang giữ trạng thái đã dùng; chơi lại tạo ván mới với một lượt đổi ô.

## Lưu và tương thích

Trạng thái ván, xu và huy hiệu dùng chung giao dịch JSON `player_data_v1`.
Bản sao lưu bao gồm huy hiệu và trạng thái đổi ô, hỗ trợ đủ tám ver.
Bản cũ thiếu các trường mới vẫn đọc được, mặc định chưa dùng cứu trợ.
Ván cũ đã từng tạo ảnh cuối không được tự suy đoán số lượt hoàn thành để cấp
huy hiệu hồi tố. Chơi ván mới để lập kỷ lục.

Kiểm tra: `flutter test`, `dart run tool/simulate_balance.dart` và
`dart run test/support/gameplay_checks.dart`. Chơi thử trên điện thoại: chọn/hủy
đổi ô, cứu bàn hết nước, reload sau cứu trợ, hoàn thành và phá kỷ lục, chơi lại,
sao lưu rồi khôi phục sang trình duyệt khác.

## Câu hỏi vào ver 7–8

- Ver 7 tốn **111 xu** để mở khóa. Câu hỏi: “Ngày 14 Casper chính thức có
  danh phận ở hành trình ATVNCG 2026 là ngày nào?”. Người chơi chọn bằng lịch
  trong năm 2026, ban đầu hiển thị `--/--/2026`. Đáp án cấu hình: **18/05/2026**.
- Ver 8 tốn **142 xu** để mở khóa. Câu hỏi: “Món ăn gì được Tiên tử kết hợp
  khi ăn lẩu kim chi?”. Bốn lựa chọn A. Bánh ngọt; B. Panna cotta chanh;
  C. Sữa chua Hy lạp; D. Khoai mì hấp cốt dừa. Đáp án: **B**.

Luồng: xác nhận trả xu → câu hỏi → trả lời đúng → chọn chế độ → chơi.
Mỗi lần vào ver từ màn bộ sưu tập đều phải trả lời lại, kể cả ver đã mở trước
khi cập nhật. Đúng không mất thêm xu. Chơi lại ngay trong màn game vẫn thuộc
lần vào ver hiện tại, không hỏi lại.

Chỉ khi gửi một đáp án sai, ver mới khóa lại. Số xu đã trả không được hoàn;
không trừ thêm tại thời điểm trả lời sai. Muốn thử lại phải mua mở khóa lần nữa
với giá hiện tại. Đóng câu hỏi, hủy lịch hoặc chưa chọn đáp án không tính sai,
không thu thêm xu; lần sau có thể trả lời tiếp bằng quyền mở khóa đã mua.

Khóa lại chỉ thu hồi quyền truy cập, giữ nguyên ván đang lưu, huy hiệu và kỷ lục.
Trạng thái khóa dùng danh sách mở khóa hiện có, được lưu ngay, giữ qua reload
và đi cùng bản sao lưu. Không lưu trạng thái “đã trả lời đúng” để bỏ qua câu hỏi
ở lần vào sau. Cấu hình câu hỏi tại `lib/models/collection_quiz.dart`.

Kiểm thử: `flutter test test/collection_quiz_test.dart test/collection_quiz_dialog_test.dart`;
kiểm tra đáp án thuần Dart: `dart run test/support/quiz_checks.dart`.
Chơi thử: mở ver → sai → reload → mua lại → đúng → đóng chọn chế độ → vào lại
và xác nhận câu hỏi xuất hiện tiếp. Kiểm tra hủy câu hỏi không trừ thêm xu,
không vào được game trước khi trả lời đúng, và hết xu thì không thể mua lại.
