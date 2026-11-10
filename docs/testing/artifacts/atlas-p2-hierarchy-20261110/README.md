# Bằng chứng bốn follow-up P2 — 10/11/2026

[Thay đổi, contracts và giới hạn](../../../ui/atlas-p2-workbench-hierarchy-2026-11-10.md).

Baseline `c10e4c43950b18170efd54275444cfaec1c9b76e` cộng diff trình bày của task này; Chromium `151.0.7922.34`, device scale 1. Fixture local, không phải dữ liệu hosted hoặc bằng chứng lưu dữ liệu nghiệp vụ.

## Kết quả

**14 captures · 59/59 checks PASS · 0 page errors · 0 external requests.** Xem [kết quả gọn](browser-checks.json) và [script fixture check](browser_check.py). Root và UI reviewer đã xem các ảnh cuối. Local server đã được dừng sau kiểm tra.

- [Desktop bốn workbench](overview-1366.jpg)
- [Điện thoại bốn workbench](overview-390.jpg)

| Surface              | 1366 × 768                 | 390 × 844                 | 360 × 800                 |
| -------------------- | -------------------------- | ------------------------- | ------------------------- |
| Xác nhận nhu cầu     | [Ảnh](need-1366.png)       | [Ảnh](need-390.png)       | [Ảnh](need-360.png)       |
| Sĩ số                | [Ảnh](attendance-1366.png) | [Ảnh](attendance-390.png) | [Ảnh](attendance-360.png) |
| Hàng đặt riêng trống | [Ảnh](pantry-1366.png)     | [Ảnh](pantry-390.png)     | [Ảnh](pantry-360.png)     |
| Công thức đã chọn    | [Ảnh](recipe-1366.png)     | [Ảnh](recipe-390.png)     | [Ảnh](recipe-360.png)     |

Thêm hai trạng thái tại 390px: [lượng không hợp lệ](need-invalid-390.png), [thêm dòng Hàng đặt riêng](pantry-added-390.png).

## Các assertion chính

- Need: ô nhập đầu tiên nằm trong vùng nhìn, không pan ngang và hit-test được ở tâm cả bốn cạnh; sort giữ một input, exact draft và lý do; lượng sai bước khóa Save/Continue. Border nhận diện/nhóm lượng/lý do/bản ghi là 1px.
- Sĩ số: desktop căn input với nhóm tiện ích; điện thoại đặt tiện ích sau helper; hai đường phân cách rõ; Paste còn mở được.
- Pantry: heading/label liên kết đúng; giữ bảng trống trong DOM; Add disabled khi chưa chọn trường và enabled/thêm được khi hợp lệ; toolbar/data có divider.
- Recipe: hai tiện ích cùng chiều rộng, target ít nhất 44px, không clipping hoặc document overflow; divider với context rõ; Close trả focus về dòng mở.
- Mỗi capture kiểm tra document đúng viewport. Network route chỉ cho localhost/data/blob; không ghi nhận request ngoài localhost.

## Chạy lại

Script cần Python có Playwright/Chromium sẵn và Vite của repository chạy trên `127.0.0.1:5175`. Chạy từ root repository, truyền `--output` là thư mục mới; script từ chối ghi đè ảnh có sẵn. Script chỉ dùng fixture entry `atlas-vnext-review.html` và chặn external requests. Không cần tài khoản hosted hoặc thay đổi dependency của ứng dụng.

## Giới hạn và các lượt dở

Các batch bị ngắt hoặc failed oracle không được tính PASS. Đã sửa oracle bảng Pantry trống từ visible thành attached (đúng contract DOM hiện có), xử lý localhost server mất kết nối bằng server riêng có log, và thay hit probe ở góc bo tròn bằng tâm cạnh. Hai lỗi UI thực tế — ô Need bị cắt và Recipe360 tràn dọc — được sửa trước bộ ảnh cuối.

Không chứng nhận thiết bị thật, virtual keyboard, screen-reader speech, mọi breakpoint/200% zoom, mật độ dữ liệu thật hoặc mọi trạng thái ngoại lệ. CI của PR là gate full routine; bộ fixture này bổ sung bằng chứng responsive và tương tác.
