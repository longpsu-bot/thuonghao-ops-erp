# Đồng bộ OPS v1 vào Atlas Staging

Chạy thủ công workflow **Atlas Staging V1 Sync** trên nhánh `main`. Workflow
đọc OPS v1 để nhập món đang hoạt động chưa có mapping trong Atlas, cùng công
thức, định lượng và danh mục phụ thuộc của các món đó. Workflow cũng đối chiếu
danh mục đã có, bổ sung nguyên liệu, nhà cung cấp và quan hệ cung ứng độc lập
đủ điều kiện, và nhập lịch sử Recipe Change Order. Phạm vi loại trừ School
Order, Dish Order và dữ liệu vận hành hằng ngày. Đích ghi duy nhất là Atlas
Staging `rnzxmxiiqgtdevzregff`.

Theo chỉ đạo ngày 19/11/2026, V1 là nguồn quyết định cho danh mục đã có mapping.
Tên, trạng thái, cấu hình trường, đơn vị phát hành và thứ tự ưu tiên nhà cung
cấp được đồng bộ theo V1 trong phạm vi kế hoạch đã đối chiếu. [Phạm vi và
điều kiện kiểm tra](../implementation-tasks/TASK-ATLAS-V1-AUTHORITATIVE-CATALOG.md).

## Cách chạy

1. Chọn `mode=preview`. Commit `main` cần có **Frontend CI** và **Supabase
   Full Integration** thành công. Nếu Full Integration chưa chạy trên commit
   hiện tại, kích hoạt workflow **Supabase Integration** trên `main` trước.
2. Với Change Order, đọc artifact `recipe-history-<run_id>`. Kiểm tra số bản
   ghi theo bảng, số bản ghi bất hoạt và `content_checksum`. Khi đã đối chiếu,
   chạy lại workflow với `mode=apply-history`, mã đó trong
   `reviewed_checksum` và mã dự án Staging trong `target_project_ref`.
   Kết quả phải ghi nhận `preserved: true`, số bản ghi đối chiếu khớp và
   `replay_status: REPLAYED`.
3. Với danh mục, xem log **Reconcile and preview or apply eligible master data**.
   Đối chiếu `planned_changes`, `catalog_differences` và `issues`. Nếu trạng thái
   là `PREVIEW` và phạm vi thay đổi đã được rà soát, dùng
   `reviewed_plan_checksum` của phần danh mục trong `reviewed_checksum` để
   chạy `mode=apply-master`. Điền cùng mã dự án Staging. Kết quả cần có
   `APPLIED`, `operational_data_unchanged: true`,
   `unrelated_master_facts_unchanged: true` và `replay_status: REPLAYED`.
   `NO_CHANGES` nghĩa là không còn thay đổi đủ điều kiện để ghi. Các chênh lệch
   trong `catalog_differences` vẫn có thể cần xử lý.

Mỗi lần ghi lấy một snapshot mới. Nếu nội dung V1 thay đổi, chạy lại Preview
và đối chiếu mã mới. Với danh mục, mã đã rà soát còn gắn với commit và kế hoạch
thay đổi ở Atlas. Backend kiểm tra lại kế hoạch trong giao dịch ghi và đối
chiếu kết quả sau ghi. Lịch sử và danh mục chạy độc lập, nên vẫn có thể lưu
lịch sử khi danh mục còn vướng kiểm tra nghiệp vụ. Các mã kiểm tra tương ứng
với từng phần.

## Kiểm tra khi chạy lại

- Lịch sử Change Order lưu trạng thái và ngày hiệu lực gốc để tra cứu. Việc
  nhập lịch sử không kích hoạt quy tắc V1 trong công thức Atlas. [Hợp đồng lưu
  lịch sử](../api/recipe-change-order-history.md).
- Danh mục có mapping giữ nguyên định danh và nhận giá trị hiện tại của V1.
  Tên nhà cung cấp chứa ghi chú vẫn được lưu nguyên nghĩa nguồn. Ưu tiên
  cung ứng được cập nhật trong cùng giao dịch, quan hệ vắng ở V1 được ngừng
  dùng và giữ lịch sử. Va chạm với đối tượng chưa có mapping cần được xử lý.
- View tính BOM V1 dùng đơn vị mua của nguyên liệu. So sánh công thức nhận
  biết bằng chứng tiếp nhận D-047 khớp đúng phiên bản hiện hành, đơn vị và số
  lượng. Các khác biệt công thức còn lại tiếp tục được báo theo từng ngữ
  cảnh. Hiệu lực Change Order vẫn được xác định theo ngày.
- Khi cần sửa kết quả đã ghi, dùng quy trình hiệu chỉnh có kiểm soát và giữ
  biên nhận nhập. Nếu lượt Apply dừng sau khi gửi lệnh ghi, đối chiếu biên
  nhận theo `snapshot_id` trong Staging trước khi chạy lại. Snapshot gốc ở trong
  phiên chạy. Artifact lịch sử chỉ chứa kết quả đối chiếu và mã kiểm tra.
