# bo_anh

- Game không đăng nhập Google. Xu và tiến độ vẫn tự lưu trên trình duyệt,
  không phụ thuộc mạng hoặc sự kiện thoát trang. Tùy chọn **Sao lưu / Khôi phục**
  dùng mã người chơi và mã khôi phục, chỉ gọi Supabase khi người chơi chủ động.
  Cần chạy SQL trước khi dùng; hướng dẫn tại [docs/CLOUD_BACKUP.md](docs/CLOUD_BACKUP.md).
- Tiến độ cục bộ: xu, tiến độ thưởng, bộ đã mở,
  ván chơi và kỷ lục dùng chung bản ghi JSON `player_data_v1` trong
  SharedPreferences. Các thao tác đọc/ghi trong phiên game chạy tuần tự;
  lượt ghép và thưởng xu được ghi cùng nhau trước khi giao diện xác nhận.
  Mở khóa cũng trừ xu và thêm bộ ảnh trong một lần ghi.
- Dữ liệu định dạng cũ tự chuyển sang bản ghi mới khi đọc lần đầu; các khóa
  cũ được giữ nguyên để dự phòng, không nhập lại sau khi đã chuyển thành công.
  Dữ liệu lỗi không bị tự đặt về 0. Nếu không lưu được, game báo lỗi thay vì
  báo nhận thưởng thành công. Test hồi quy: `flutter test test/local_player_storage_test.dart`.
- Bước này chỉ lưu trên cùng trình duyệt và địa chỉ web. Xóa dữ liệu website,
  đổi tên miền hoặc dùng tab riêng tư không có bảo đảm khôi phục; hàng đợi
  hiện tại cũng không khóa giao dịch giữa nhiều tab chơi đồng thời.
  Chrome và Safari có vùng lưu trữ riêng, không chia sẻ số xu với nhau.
  Dùng một địa chỉ cố định khi chạy local: `flutter run -d chrome --web-port 3000`.
  Đổi cổng localhost cũng tạo vùng lưu trữ khác, có thể trông như mất xu.
- Kiểm tra sau deploy trên Chrome Android và Safari iPhone (chế độ thường):
  nhận xu rồi reload; rời trang rồi mở lại cùng URL; mở khóa bộ ảnh rồi reload.
  Xu và bộ đã mở phải giữ nguyên. Chỉ báo thưởng sau khi ghi thành công;
  thao tác đang chờ ghi lúc đóng trang đột ngột chưa được xác nhận là đã lưu.

- Khi ẩn tab hoặc chuyển ứng dụng, secret đang phát được tạm dừng cùng
  AudioContext, giữ vị trí và quyền ưu tiên. Quay lại game thử phát tiếp;
  Safari có thể cần thêm một lần chạm. Sound thường không phát lại sau khi ẩn.
  Chủ động dừng/chơi lại/rời màn chơi vẫn hủy secret. Trạng thái tạm dừng chỉ
  tồn tại trong phiên trang hiện tại, không được lưu qua reload/đóng tab.
- Khi ẩn tab, chuyển ứng dụng, khóa màn hình hoặc rời trang, game tháo
  iframe SoundCloud để không giữ nhạc nền chạy ngầm. Quay lại cần bấm loa
  để tải lại playlist từ đầu; âm lượng đã chọn vẫn được giữ. Chuyển màn hình
  bên trong game vẫn giữ nhạc liên tục. Game dọn Media Session của trang nếu
  trình duyệt hỗ trợ; thẻ media cũ trên hệ điều hành có thể vẫn được giữ lại.

- Hiệu ứng web dùng AudioContext chung trong `web/sound-effects.js`, được mở
  trực tiếp từ thao tác chạm/click/phím thật để hỗ trợ Safari iPhone. File MP3
  được tải, giải mã và lưu đệm; việc cộng xu bất đồng bộ không cần tạo lại
  phần tử audio cho mỗi file. Nhạc nền SoundCloud vẫn dùng trình phát riêng.
  Nếu tab bị gián đoạn khi ra nền, lần chạm tiếp theo thử khôi phục context.
  Trên Safari có hỗ trợ Audio Session API, đặt loại `playback` để hiệu ứng
  không bị chế độ im lặng của iPhone tắt riêng trong khi SoundCloud vẫn có tiếng.
- Kiểm tra hiệu ứng web: `node --test test/sound_effects_web_test.cjs`.
  Sau khi deploy, thử trên Safari iPhone: chạm Bắt đầu, đạt mốc nhận xu,
  ghép ảnh cuối để nghe secret; chuyển tab rồi quay lại và chạm để kiểm tra
  khôi phục. Cần kiểm tra nghe thực tế trên thiết bị ngoài các test tự động.

- Chơi tự do dùng cấu hình riêng từng ver trong `lib/models/spawn_config.dart`.
  Từ cấp 5, ảnh sinh ra tăng theo cấp cao nhất đã khám phá trong ván;
  35% cơ hội hỗ trợ ảnh cấp thấp còn sót trên bàn. Các ảnh sau nhóm khởi đầu
  1–3 và ảnh cuối vẫn phải mở bằng ghép. Chế độ thời gian giữ cách sinh cũ.
  Cấp đã khám phá được lưu cùng ván; ván cũ tự suy ra từ ảnh trên bàn.
- Chạy `dart run tool/simulate_balance.dart` để mô phỏng 500 ván/ver cho
  từng chiến lược ghép thấp trước, cao trước và chọn ngẫu nhiên. Mốc cân bằng
  dùng trung vị ghép thấp trước: ver 1 khoảng 120–150, ver 6 khoảng 250–320
  lượt tới ảnh cuối. Đây không phải số lượt cố định cho mọi người chơi.

- Ảnh trong mỗi collection được xếp theo số đầu tên file (1, 2, 10...),
  kể cả khi thiếu số hoặc có phần tên phía sau. Cấp độ vẫn liên tục từ 1;
  ảnh có số lớn nhất là cấp cuối. Ván đã lưu giữ cấp độ số, vì vậy ảnh tương
  ứng có thể thay đổi khi chuyển từ thứ tự tên cũ sang thứ tự số mới.
- Ghép thường chưa nhận xu không phát hiệu ứng. Khi nhận xu, phát ngẫu nhiên
  một MP3 trong `assets/sounds/sound_normal/` một lần. Ghép ra ảnh cuối phát
  `assets/sounds/sound_secret/Sound N.mp3` theo collection N (1–6) một lần,
  kể cả khi lượt đó đồng thời nhận xu. Sound thường không ngắt secret;
  nhạc nền SoundCloud được điều khiển riêng.

- Thanh âm lượng cạnh nút loa điều chỉnh nhạc nền từ 0–100%, mặc định 30%.
  Mức đã chọn được lưu trên trình duyệt cho lần mở sau; nếu trình duyệt chặn
  lưu trữ, vẫn chỉnh được âm lượng trong phiên hiện tại. Mức 0% làm nhạc im tiếng;
  nút loa vẫn dùng để tạm dừng/phát tiếp.

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
