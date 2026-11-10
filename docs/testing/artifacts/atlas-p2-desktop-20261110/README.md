# Atlas P2 — review desktop ngày 10/11/2026

Desktop là ưu tiên Owner vừa xác nhận. Đây là bản chỉnh tiếp theo của [bốn P2](../../../ui/atlas-p2-workbench-hierarchy-2026-11-10.md), cùng nhánh/PR, không thay thế bằng chứng Chi tiết lệnh trong PR #463.

**21 captures · 98/98 checks PASS · không page error, external request hoặc document overflow.** Chromium 151.0.7922.34, scale 1, fixture local. Không dùng dữ liệu hosted hoặc thực hiện hosted Save. Root và reviewer độc lập đã kiểm tra ảnh; Review mở bằng Preview fixture hiện có, không diễn giải các số tổng hợp trong fixture thành dữ liệu vận hành thật.

## Gallery chính

| Trạng thái                 | 1920 × 1080                       | 1440 × 900                        | 1366 × 768                        |
| -------------------------- | --------------------------------- | --------------------------------- | --------------------------------- |
| Xác nhận nhu cầu           | [Ảnh](need-1920.png)              | [Ảnh](need-1440.png)              | [Ảnh](need-1366.png)              |
| Sĩ số                      | [Ảnh](attendance-1920.png)        | [Ảnh](attendance-1440.png)        | [Ảnh](attendance-1366.png)        |
| Sĩ số — Review             | [Ảnh](attendance-review-1920.png) | [Ảnh](attendance-review-1440.png) | [Ảnh](attendance-review-1366.png) |
| Hàng đặt riêng — trống     | [Ảnh](pantry-1920.png)            | [Ảnh](pantry-1440.png)            | [Ảnh](pantry-1366.png)            |
| Hàng đặt riêng — thêm dòng | [Ảnh](pantry-added-1920.png)      | [Ảnh](pantry-added-1440.png)      | [Ảnh](pantry-added-1366.png)      |
| Hàng đặt riêng — Review    | [Ảnh](pantry-review-1920.png)     | [Ảnh](pantry-review-1440.png)     | [Ảnh](pantry-review-1366.png)     |
| Công thức — đã chọn        | [Ảnh](recipe-1920.png)            | [Ảnh](recipe-1440.png)            | [Ảnh](recipe-1366.png)            |

## Kết quả và tái lập

- Need có đủ sáu cột không pan ngang; dòng bình thường 55,8px, năm dòng đầy đủ ở 1366 và sáu dòng ở hai kích thước còn lại. Sort giữ đúng một input, bản nháp và lý do; lượng không hợp lệ tiếp tục khóa Save/Continue.
- Sĩ số có label/file/nút cùng trục và helper một dòng trên workplane rộng. Trong Review, toàn bộ control nằm trong cột soạn thảo. Focus chuyển đến Review và trở lại trigger; tiêu đề công việc còn trong vùng nhìn.
- Hàng đặt riêng có label liên kết đúng và group thêm thẳng hàng khi rộng, wrap trong Review. Add vẫn khóa khi chưa đủ điều kiện và hoạt động sau chọn trường/nguyên liệu hợp lệ.
- Công thức có tiện ích/ngữ cảnh căn cùng trục, target 40px, số suất gọn và ô lượng nguyên liệu đầu tiên nằm trước footer. Close trả focus đúng dòng mở.
- Typography giữ các vai trò Inter hiện tại; hierarchy đến từ căn hàng, tỷ lệ cột, nhóm dữ liệu, trọng lượng số và các đường phân cách 1px.

[Kết quả gọn](browser-checks.json) giữ viewport, geometry chính và từng tên check. Dùng [script hiện có](../atlas-p2-hierarchy-20261110/browser_check.py) với Vite local trên `127.0.0.1:5175`:

```powershell
python docs/testing/artifacts/atlas-p2-hierarchy-20261110/browser_check.py --desktop --output <thu-muc-moi>
```

Script từ chối ghi đè ảnh. Bỏ `--desktop` để chạy checkpoint hồi quy 1366/390/360; lần cuối đạt 14 captures / 70 checks. Ảnh hồi quy được kiểm tra tại máy, không nhân đôi bộ ảnh điện thoại đã có vào gallery desktop.

Local focused: bốn file 119/119 PASS; sau thay đổi focus, toàn bộ Planning Sources 44/44 PASS. Typecheck, scoped formatting, UI boundary, whitespace và detector PASS. Đây là các checkpoint riêng; GitHub Actions của commit mới sở hữu full routine.

## Giới hạn

Review tables trong cột hẹp vẫn sử dụng cuộn ngang cục bộ hiện có. Không chứng nhận mọi trạng thái, chiều dài dữ liệu thật, 200% zoom, OS font scaling, thiết bị thật, virtual keyboard hoặc screen-reader speech. Không có migration, thay đổi backend/quyền hoặc thao tác dữ liệu hosted. Rollback là revert trình bày/focus, browser checks và tài liệu.
