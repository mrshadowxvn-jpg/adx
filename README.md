# Nhà Trọ 365 iOS v1.0.0

Ứng dụng iPhone dùng cùng dữ liệu WordPress tại `https://868686869.xyz/quan-ly-nha-tro/`. App không tạo cơ sở dữ liệu riêng nên phòng, khách thuê, CCCD, hóa đơn, SePay và thu chi luôn đồng bộ với web và Android.

## Chức năng

- Giữ phiên đăng nhập WordPress trong `WKWebView`.
- Giao diện quản lý toàn màn hình, không có thanh công cụ website.
- Chừa vùng an toàn cho tai thỏ/Dynamic Island và thanh thao tác của iPhone.
- Kéo xuống hoặc bấm nút xoay góc phải để tải lại từ máy chủ.
- Chọn ảnh hoặc dùng camera để tải đủ hai mặt CCCD.
- Sao chép nguyên ảnh hóa đơn PNG có mã QR vào clipboard rồi mở Zalo.
- Tải hợp đồng Word và CT01, sau đó mở bảng chia sẻ/lưu tệp của iOS.
- Mở liên kết nội bộ trong app và chặn cầu nối JavaScript mở địa chỉ ngoài không thuộc Zalo.
- Có sẵn mã tích hợp Firebase Messaging; app vẫn chạy bình thường khi chưa cấu hình Firebase.

## Yêu cầu

- macOS có Xcode 15 trở lên.
- iPhone chạy iOS 15 trở lên.
- Tài khoản Apple Developer để cài lâu dài trên máy thật hoặc phát hành TestFlight/App Store.
- Plugin Nhà Trọ 365 v3.13.0 và theme v3.3.0 trên WordPress.

## Build bản chạy cơ bản

1. Giải nén và mở `NhaTro365.xcodeproj` bằng Xcode.
2. Chọn target **NhaTro365 → Signing & Capabilities**.
3. Chọn Apple Developer Team của bạn và bật **Automatically manage signing**.
4. Giữ Bundle ID `xyz.a868686869.nhatro365.ios`, hoặc đổi sang Bundle ID thuộc tài khoản Apple của bạn.
5. Chọn iPhone rồi bấm **Run**.

Bản cơ bản đăng nhập, quản lý, tải lại, upload CCCD, tải giấy tờ và gửi ảnh hóa đơn qua Zalo được ngay. Firebase chỉ bật sau các bước bên dưới.

## Bật Firebase trên iOS

1. Trong đúng dự án Firebase đang dùng cho Android, thêm một ứng dụng **iOS**.
2. Nhập chính xác Bundle ID đang đặt trong Xcode; mặc định là `xyz.a868686869.nhatro365.ios`.
3. Tải `GoogleService-Info.plist`, kéo vào nhóm **NhaTro365** trong Xcode, chọn **Copy items if needed** và đánh dấu target **NhaTro365**.
4. Trong Xcode chọn **File → Add Package Dependencies**, nhập `https://github.com/firebase/firebase-ios-sdk.git` và thêm sản phẩm **FirebaseMessaging** vào target.
5. Ở **Signing & Capabilities**, bảo đảm có **Push Notifications** và **Background Modes → Remote notifications**.
6. Tạo APNs Authentication Key trong Apple Developer và tải khóa đó lên **Firebase Console → Project Settings → Cloud Messaging → Apple app configuration**.
7. Build lại app, cho phép thông báo và đăng nhập một lần. Plugin sẽ gắn token iPhone với đúng tài khoản chủ trọ.

Không đặt `serviceAccountKey.json` vào dự án iOS. File này tiếp tục được lưu mã hóa ở WordPress và dùng chung phía máy chủ.

## Phát hành và cập nhật

iOS không cho một app thông thường tự tải file IPA trong thư mục website rồi cài đè như APK Android. Cách dễ và ổn định là:

1. Chọn **Product → Archive** trong Xcode.
2. Chọn **Distribute App → App Store Connect**.
3. Phát hành bản thử qua TestFlight; khi ổn định thì gửi duyệt App Store.

Mỗi lần phát hành, tăng `MARKETING_VERSION` và `CURRENT_PROJECT_VERSION` trong target. Người dùng sẽ cập nhật qua TestFlight hoặc App Store.

## Lưu ý ký ứng dụng

File `NhaTro365.entitlements` đang khai báo môi trường APNs phát triển. Khi Archive bằng cấu hình phát hành, Xcode và provisioning profile của Apple sẽ ký lại quyền push phù hợp. Nếu Xcode báo lỗi provisioning, hãy xóa capability Push Notifications rồi thêm lại để Xcode tạo profile đúng cho Team của bạn.
