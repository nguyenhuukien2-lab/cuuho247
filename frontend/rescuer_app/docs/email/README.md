# OTP email Đối tác — Cứu Hộ 24/7

## Phạm vi thay đổi

Giữ nguyên thương hiệu, header navy, thông tin đăng ký, fallback metadata, hướng
dẫn hoàn thiện hồ sơ, lưu ý Admin phê duyệt và footer của email cũ. Chỉ thay khối
CTA thành mã OTP, và đổi những câu hướng dẫn bấm liên kết thành nhập/gửi lại mã.
Nhánh Đối tác không có link xác nhận/ConfirmationURL và chỉ dùng OTP. Nhánh
Customer dùng ConfirmationURL do Supabase cung cấp, không hiển thị OTP hoặc
yêu cầu nhập mã. Không hard-code localhost, URL token hay sửa sender/SMTP.

Không có Auth settings, template, SMTP hay dữ liệu production nào được sửa bởi
task này. Không deploy, commit hoặc tag.

## Cấu hình Supabase cần áp dụng thủ công

1. Authentication → Sign In / Providers → Email: **Confirm email = ON**.
2. **Email OTP length = 6**. Đừng giả định mặc định luôn là 6 và không cắt
   chuỗi Token bằng template. Hosted Auth field tương ứng là
   `mailer_otp_length`; nếu Dashboard không hiển thị, quản trị project có thể
   dùng Management API. Không đưa management token/service-role key vào app.
3. Kiểm tra **Email OTP Expiration** (`mailer_otp_exp`). App đang dùng 3600
   giây làm cửa sổ tham chiếu để chọn câu báo lỗi khi server trả lỗi mơ hồ.
   Nếu project dùng thời hạn khác, build app với
   `--dart-define=PARTNER_EMAIL_OTP_EXPIRY_SECONDS=<so-giay-cua-project>`.
   Đây chỉ là gợi ý UI; server luôn quyết định mã có hợp lệ hay không.
4. Authentication → Email Templates → Confirm signup: copy nguyên HTML từ
   `confirm_signup_vi.html`: Đối tác dùng `{{ .Token }}`, Customer dùng
   `{{ .ConfirmationURL }}` theo conditional metadata.
5. Giữ rate limit gửi email phù hợp; UI có countdown 60 giây cho cả lần
   signup và lần gửi lại. Backend rate limits vẫn là lớp bảo vệ chính.
6. Giữ Custom SMTP, sender Cứu Hộ 24/7, SPF/DKIM/DMARC đã cấu hình trước đó.
   Sửa HTML không đổi được tên người gửi và không tự provision SMTP.

Subject dành cho đối tác giữ nguyên:

```text
Cứu Hộ 24/7 | Xác nhận email đăng ký đối tác
```

Với project dùng chung các app, giữ Subject có điều kiện từ lượt trước:

```text
{{ if or (eq (printf "%v" .Data.account_type) "rescuer_partner") (eq (printf "%#v" .Data.partner_registration) "true") }}Cứu Hộ 24/7 | Xác nhận email đăng ký đối tác{{ else }}Cứu Hộ 24/7 | Xác nhận địa chỉ email{{ end }}
```

**Project chung:** Confirm signup và Subject đã tách hai nhánh. Khi
`account_type == "rescuer_partner"` HOẶC `partner_registration` là boolean true,
email giữ nguyên nội dung Đối tác và OTP; mọi tài khoản khác giữ cơ chế link
Customer. Không sửa Customer App. `printf`, `eq`, `or` là built-in Go Template,
không phải helper tùy biến. Dùng kiểu định dạng để cờ chuỗi `"false"`/`"true"`,
metadata thiếu hoặc kiểu dữ liệu không hợp lệ không bị hiểu nhầm là boolean true.
Subject copy trực tiếp từ `confirm_signup_subject.txt` để dùng cùng điều kiện.

OTP được xác nhận bằng request API trong app, không phải trình duyệt. Bước này
không cần thêm Redirect URL/deep link. Có thể bỏ URI confirm-email cũ khỏi
allowlist nếu không còn client cũ nào dùng; việc đó không cần cho OTP. Site URL
chung vẫn nên là HTTPS production hợp lệ để phục vụ các flow khác, không phải
localhost. Không tự đổi Site URL chung thành địa chỉ app Đối tác.

## Luồng app

1. `auth.signUp(email, password, data)`, không truyền emailRedirectTo.
2. Khi cần xác nhận, mở màn hình **Xác nhận email**: email che một phần, 6 ô số,
   nút XÁC NHẬN, Gửi lại mã, countdown và loading.
3. Người dùng nhập từng số hoặc dán cả 6 số. App không tự generate/hash/lưu OTP.
4. Service gọi SDK Supabase chính thức:

   ```dart
   await client.auth.verifyOTP(
     type: OtpType.email,
     email: email.trim(),
     token: code,
   );
   ```

   Không dùng signInWithOtp để thay đăng ký bằng mật khẩu và không tạo bảng/RPC
   OTP riêng. `OtpType.email` là loại email verification hiện được khuyến nghị.
5. Sau khi có session, gọi `auth.getUser()`, kiểm tra `emailConfirmedAt` và
   email của đúng tài khoản trước khi mở bước hồ sơ đối tác.
6. Gửi lại bằng `auth.resend(type: OtpType.signup, email: email)`, không redirect.
7. Nếu verifyOTP đã thành công nhưng getUser mất mạng, nút thử lại chỉ gọi
   getUser, không gửi lại OTP một lần đã dùng.

Mã được giữ tạm trong các ô nhập, xóa ngay khi submit và khi đóng màn hình;
không log, không lưu local storage/database/metadata. Session được SDK lưu theo
cơ chế Auth bình thường; không nhầm session với mã OTP do người dùng nhập.

Thông báo:
- Sai: “Mã xác nhận không chính xác. Vui lòng kiểm tra và thử lại.”
- Hết hạn: “Mã xác nhận đã hết hạn. Vui lòng yêu cầu mã mới.”
- Gửi lại: “Mã xác nhận mới đã được gửi đến email của bạn.”
- Mất mạng/rate limit được dịch sang tiếng Việt, không hiện raw error/token.

Supabase có thể trả cùng `otp_expired` / “expired or invalid” cho mã sai và mã
hết hạn. App không thể biết tuyệt đối hai trường hợp từ lỗi đó. Nó dùng thời
điểm gửi trong phiên hiện tại và thời hạn cấu hình để chọn thông báo; khi server
nói rõ chỉ hết hạn, dùng thông báo hết hạn. Với mã gửi từ phiên trước không còn
mốc thời gian, lỗi mơ hồ được hiển thị như mã không đúng và có nút gửi lại.
Mốc cục bộ không chặn một mã mà server chấp nhận và không quyết định quyền truy cập.

## Những gì giữ nguyên

Metadata signup:
- `full_name`: tên đã trim.
- `account_type = rescuer_partner`.
- `registered_at`: HH:mm - dd/MM/yyyy, Asia/Ho_Chi_Minh (UTC+07:00).
- `partner_registration = true`: tương thích nhận diện cũ.

registered_at chỉ hiển thị email; timestamp nghiệp vụ do server/database tạo.
Không thêm CCCD, điện thoại, giấy phép, password, access/refresh token hoặc
private credential vào metadata/email. Token OTP của Auth là biến .Token được
người dùng yêu cầu, không phải access token, TokenHash hay service-role key.

Không tự duyệt hồ sơ. Tài khoản vẫn phải bổ sung thông tin, phương tiện, dịch vụ,
giấy tờ và được Admin phê duyệt trước khi Online/nhận đơn. Signing Android hiện
có và các thay đổi không liên quan được giữ nguyên.

## Test từ đầu

1. Áp dụng template, Confirm email, OTP length = 6 và kiểm tra SMTP/TTL trên
   project kiểm thử được quản lý. Chưa thay đổi production bằng code này.
2. Build/cài lại app chứa sửa đổi OTP. Bản APK cũ chưa có màn hình này.
3. Đăng ký email mới bạn kiểm soát → app mở Xác nhận email.
4. Email giữ nguyên thương hiệu, tên/email, tài khoản, ngày giờ Việt Nam,
   trạng thái, hướng dẫn và footer; vùng CTA chỉ có mã 6 số, không có link.
5. Nhập/dán mã → XÁC NHẬN → Auth server xác nhận email → tiếp tục hồ sơ.
   Chưa được Online trước khi Admin duyệt.
6. Nhập sai khi mã còn hiệu lực → thông báo sai. Chờ hết TTL trên project test
   rồi nhập mã → thông báo hết hạn theo giới hạn phân biệt được mô tả ở trên.
7. Hết countdown → Gửi lại mã → thông báo thành công → mã mới, countdown reset.
8. Tắt mạng trước verifyOTP và giữa verifyOTP/getUser, bật mạng và thử lại.
   Không báo verified khi server chưa xác nhận.
9. Đóng/mở app ở màn hình OTP: không phục hồi mã đã nhập. Nhập email từ lối
   “Xác nhận email bằng mã OTP” ở đăng nhập và yêu cầu mã mới nếu cần.
10. Kiểm tra email tài khoản Customer (metadata thiếu, cờ false hoặc loại khác):
    chỉ có nút xác nhận link cũ do Supabase tạo, không có mã/hướng dẫn OTP.

## File thay đổi

Kết quả kiểm tra local sau khi tách template dùng chung:

- `flutter analyze --no-pub`: PASS, không có issue.
- `flutter test --no-pub`: PASS, **232 tests**.
- Go chuẩn `html/template` + `text/template`, không custom FuncMap: PASS,
  **27 lượt render**, gồm hai loại tài khoản, metadata thiếu/sai kiểu và escaping.
- Email Đối tác sau render khớp bản OTP trước (chỉ chuẩn hóa whitespace khi
  đối chiếu); không có href/link xác nhận. Customer giữ nguyên giá trị
  ConfirmationURL và không lộ OTP hoặc hướng dẫn nhập mã.
- Subject cả hai nhánh đã được render và so sánh với chuỗi mong đợi.
- Không sửa code Customer App, SMTP, Auth settings hoặc production; không
  deploy, commit, tag hay gửi email thật.

Có Go trong PATH thì chạy validator từ `frontend/rescuer_app`:

```text
go run tools/validate_signup_templates.go docs/email/confirm_signup_vi.html docs/email/confirm_signup_subject.txt
```

Ở lượt kiểm tra này, Go chính thức được tải/check SHA256 và dùng tạm trong
thư mục ignored `.tmp/signup-template-go`, không cài vào hệ thống.

- `lib/services/partner_email_auth.dart`: hợp đồng verify OTP, mask email, TTL UI.
- `lib/services/rescuer_service.dart`: verifyOTP, bỏ emailRedirectTo signup/resend.
- `lib/app/partner_email_confirmation.dart`: trạng thái OTP, resend countdown/retry.
- `lib/screens/auth/partner_email_confirmation_screen.dart`: UI 6 ô, paste/loading.
- `lib/app/connected_app.dart`: bỏ chủ xử lý deep link của bước email.
- `lib/app/rescuer_controller.dart`: bắt đầu countdown khi signup gửi mã.
- `lib/screens/preparation/preparation_forms.dart`: lối vào xác nhận OTP.
- `lib/main.dart`: không tự xử lý URL session cho bước email.
- `android/app/src/main/AndroidManifest.xml`: bỏ intent filter confirm-email cũ.
- `pubspec.yaml`, `pubspec.lock`: app_links trở lại dependency gián tiếp của SDK.
- `test/partner_auth_test.dart`, `test/partner_email_confirmation_test.dart`.
- `docs/email/confirm_signup_vi.html`, tài liệu này.
- `docs/email/confirm_signup_subject.txt`: Subject conditional khớp Body.
- `tools/validate_signup_templates.go`: parse/render Go chuẩn, không custom
  FuncMap; kiểm tra tách OTP/link, fallback metadata, escaping, Subject và giữ
  nguyên email Đối tác so với bản đối chiếu.

Tài liệu đối chiếu:
- https://supabase.com/docs/reference/dart/auth-verifyotp
- https://supabase.com/docs/reference/dart/auth-resend
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/reference/api/v1-update-auth-service-config
- https://github.com/supabase/auth/blob/master/internal/api/verify.go
