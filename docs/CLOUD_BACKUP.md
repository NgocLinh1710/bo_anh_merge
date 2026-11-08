# Sao lưu bằng mã khôi phục

## Thiết lập server (cần chủ project Supabase thực hiện)

1. Mở project `foairqpmcniidluqxvsk` → SQL Editor → New query.
2. Dán toàn bộ `supabase/migrations/202611080001_game_backups.sql` và Run.
3. Chạy `supabase/tests/game_backups.sql`; phải có thông báo PASS, không có lỗi.
   Test dùng role anon thực tế và rollback, không giữ bản lưu thử trên server.
4. Chạy/build Flutter như bình thường. Cấu hình URL/publishable key công khai
   nằm trong `lib/services/cloud_backup_service.dart`, có thể ghi đè bằng
   `--dart-define=SUPABASE_URL=...` và `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
   Không cần Google provider, Supabase Auth, email hay service_role trong ứng dụng.

SQL tạo schema riêng, một bảng và ba RPC. Không sửa hoặc xóa bảng hiện có của game.
Không đưa schema `game_backup_private` vào danh sách Exposed schemas của Data API.

## Người chơi sử dụng

- Ở màn hình chính chọn **Sao lưu / Khôi phục** → **Lưu tiến độ**.
- Lần đầu cần đồng ý gửi xu, tiến độ thưởng, bộ đã mở, ván chơi và kỷ lục lên
  Supabase. Không yêu cầu tên/email/điện thoại. Hạ tầng vẫn có thể xử lý IP/log;
  đây là phương án giảm thông tin thu thập, không phải bảo đảm không có dữ liệu cá nhân.
- Cất **toàn bộ mã BO1.…** ở nơi riêng ngoài trình duyệt. Mã người chơi riêng lẻ
  không khôi phục được. Ai giữ toàn bộ mã có quyền đọc/ghi/xóa bản sao.
- Chỉ cập nhật server khi bấm Lưu. Chơi xong nên bấm Lưu, không trông chờ lúc
  đóng tab. Sau khi xóa dữ liệu trình duyệt/đổi máy, nhập mã rồi Khôi phục.
- Khôi phục có xem trước số xu và xác nhận thay thế, không cộng hai số dư.
- **Xóa dữ liệu trên server** chỉ xóa bản sao đang liên kết; xu trên máy còn nguyên.
  Khi đã mất toàn bộ dữ liệu máy, cần khôi phục bằng mã trước để xóa bản server.
  Bản sao hạ tầng/nhật ký chịu thời hạn lưu của nhà cung cấp, không bị ứng dụng
  bảo đảm xóa tức thì. Không có mã và không còn dữ liệu máy thì không thể khôi phục.

## Bảo vệ bản sao và giới hạn

- Khóa khôi phục 256 bit từ Random.secure; server chỉ lưu SHA-256 của khóa kèm ID.
  Khóa đi trong body POST qua HTTPS, không đi trong URL, không được gửi trong payload
  tiến độ và không ghi log bởi code game. Nhà cung cấp hạ tầng vẫn cần cấu hình log phù hợp.
- Thu hồi toàn bộ quyền truy cập trực tiếp bảng/schema khỏi anon/authenticated.
  Chỉ RPC xác thực bằng khóa mới được đọc/ghi/xóa; ID công khai không đủ để truy cập.
- Ghi một snapshot trong một giao dịch. revision chống ghi đè giữa thiết bị;
  operation UUID cho phép thử lại cùng yêu cầu khi mất phản hồi mà không ghi hai lần.
- Mã và thao tác đang chờ được lưu cùng bản ghi cục bộ; kết quả khôi phục và mã
  liên kết cũng được thay thế cùng một lần ghi.
- Snapshot tối đa 16 KiB; tối đa 15.000 bản lưu đang tồn tại và 1.000 bản mới/ngày
  theo ngày server. Đây là chặn tăng trưởng lưu trữ, không phải giới hạn tần suất
  API đầy đủ. Trước khi quảng bá rộng cần theo dõi quota và bổ sung rate limiting /
  CAPTCHA ở lớp API nếu có lạm dụng. Không có cam kết miễn phí cho mọi lượng truy cập.
- Backup chấp nhận tiến độ do thiết bị gửi lên, không phải hệ thống chống sửa xu.
  Không dùng số xu này cho tiền thật, đổi thưởng hay bảng xếp hạng cạnh tranh
  nếu chưa bổ sung xác thực lượt chơi phía server.
- Sau khi delete đã được xác nhận, ứng dụng bỏ mã liên kết trên máy. Thiết bị khác
  đang giữ mã cũng không tự đồng bộ; người chơi phải quản lý các lần lưu thủ công.

## Kiểm tra

```powershell
flutter test
flutter run -d chrome --web-port 3000
```

Sau khi SQL đã chạy: lưu trên Chrome, giữ mã, khôi phục trên Safari/thiết bị khác;
thử sai mã; thử cancel khôi phục; lưu từ hai thiết bị; xóa rồi thử khôi phục lại.
Test Dart dùng server giả lập để kiểm tra client, không thay cho test SQL quyền
truy cập và thử API project thật. SQL đã kiểm tra bằng PostgreSQL nhúng PGlite,
gồm chạy migration lại hai lần, quyền role anon, sai mã, revision, thử lại yêu cầu
và xóa. Có thể chạy lại cục bộ:

```powershell
npm.cmd ci --prefix tool/backup-sql-tests
node tool/backup-sql-tests/test.mjs
```

Chưa áp dụng migration vào Supabase thật; vẫn cần chạy script trong SQL Editor
để xác nhận môi trường project của bạn trước khi thử trên điện thoại.

Tham khảo:
https://supabase.com/docs/guides/database/functions
https://supabase.com/docs/guides/database/postgres/row-level-security
