# Hướng phát triển cho 1.2.0 (Roadmap)

Phiên bản 1.2.0 tập trung đưa `flutter_app_update_guard` vào editor workflow thông qua VS Code extension, nhưng vẫn giữ CLI là nguồn logic chính.

## VS Code Extension

- [x] Khởi tạo extension TypeScript trong `extensions/vscode/`.
- [x] Tạo manifest `package.json` với commands, settings, activity bar view và sidebar view.
- [x] Tách source theo cấu trúc dễ mở rộng: `app/`, `commands/`, `services/`, `features/`, `workspace/`, `domain/`.
- [x] Tích hợp CLI theo thứ tự ưu tiên: `cliPath`, project-local `dart run flutter_app_update_guard`, global executable.
- [x] Hiển thị diagnostics trong `pubspec.yaml` cho dependency có risk cao hoặc vi phạm policy.
- [x] Thêm CodeLens cho `Simulate Upgrade` và `Inspect Package`.
- [x] Thêm sidebar Tree View hiển thị dependency, risk score và risk reasons.
- [x] Thêm command chạy check, fix, baseline, inspect, simulate và refresh tree.
- [x] Thêm hướng dẫn sử dụng extension vào README.
- [ ] Đóng gói `.vsix` và kiểm thử cài đặt extension từ file local.
- [ ] Thêm automated tests bằng `@vscode/test-electron`.
- [ ] Xuất bản extension lên VS Code Marketplace hoặc Open VSX.

## CLI & Reporting

- [ ] Thêm `--offline` để chỉ dùng cache và lockfile.
- [ ] Thêm cache Pub.dev API trên disk.
- [ ] Thêm `--changed-only` để chỉ kiểm tra dependency thay đổi trong Git diff.
- [ ] Thêm SARIF output để hiển thị cảnh báo trực tiếp trong GitHub Code Scanning.
- [ ] Thêm GitHub Step Summary output.
- [ ] Hiển thị confidence level cho mỗi risk reason.
- [ ] Cho phép custom risk weights trong YAML.
- [ ] Phân biệt production usage và test-only usage rõ hơn.

---

## Các tính năng nâng cao tiềm năng (Future Enhancements)

- [ ] Tích hợp API của OSV.dev để quét lỗ hổng bảo mật (CVE auditing).
- [ ] Tích hợp bot tự động bình luận kết quả quét dưới dạng Markdown lên PR (GitHub/GitLab PR Comment Bot).
- [ ] Cache kết quả chạy giả lập (`simulate`) thành công để tối ưu hóa thời gian CI.
- [ ] Hỗ trợ cấu hình Private Package Registry (ví dụ: các server pub riêng của doanh nghiệp).
- [ ] Xuất file HTML trực quan hóa đồ thị cây phụ thuộc (Dependency Graph Visualization).
- [ ] Tạo Android Studio / IntelliJ plugin dùng chung JSON output từ CLI.
