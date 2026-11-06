# bo_anh

## Nhạc nền SoundCloud (web)

- Chạy `flutter pub get`, sau đó `flutter run -d chrome`.
- Nhạc tự thử phát khi mở game. Nếu trình duyệt chặn autoplay có tiếng,
  game thử phát lại khi người chơi chạm/bấm phím tương tác; cũng có thể bấm loa.
  Nút **🔊/🔇** tạm dừng/phát tiếp và giữ vị trí bài; biểu tượng sáng khi
  SoundCloud xác nhận đang phát. Giao diện chỉ hiện nút loa ở góc dưới bên phải,
  trong hàng riêng nằm ngoài vùng game để không đè xu hay nút chơi. Hàng này
  tính khoảng an toàn của thiết bị và co lại khi màn hình nằm ngang thấp;
  trình phát SoundCloud chạy phía sau, không hiện thanh nhạc hay danh sách bài.
- Playlist tiếp tục khi chuyển màn hình trong game và tự lặp để
  phát lại từ đầu khi bài cuối kết thúc. Số bài phụ thuộc playlist thực tế,
  không cố định là 15. Tải lại trang sẽ đặt lại trình phát.
- Thay playlist tại `playlistUrl` trong `web/music.js` và cập nhật liên kết
  cùng tên hiển thị trong `web/index.html`.
- Cần mạng và playlist/bài hát cho phép nhúng, khả dụng tại nơi người nghe.
  Trình duyệt có thể dừng nhạc khi tab ngủ hoặc khóa màn hình. Tính năng này
  chỉ áp dụng cho web, không tải nhạc về hoặc bảo đảm lượt nghe/doanh thu.
- Chỉ đưa nhạc vào sử dụng sau khi có đầy đủ quyền dùng làm nhạc nền game.
  Việc playlist công khai hoặc cho phép nhúng không thay thế giấy phép.
- Kiểm tra logic player: `node --test test/music_player_test.cjs`.
- Kiểm tra thủ công: phát playlist, chuyển từ trang chủ sang bộ ảnh rồi vào
  game; nhạc phải tiếp tục. Thử tắt/bật bằng loa và lặp
  bài cuối; thử màn hình điện thoại và trường hợp chặn kết nối SoundCloud.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
