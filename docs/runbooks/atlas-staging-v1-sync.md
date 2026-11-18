# Đồng bộ OPS v1 vào Atlas Staging

Chạy thủ công workflow **Atlas Staging V1 Sync** trên nhánh `main`. Workflow
đọc OPS v1 để lấy dữ liệu danh mục và cấu hình công thức, cùng lịch sử Recipe
Change Order. Phạm vi loại trừ School Order, Dish Order và dữ liệu vận hành
hằng ngày. Đích ghi duy nhất là Atlas Staging `rnzxmxiiqgtdevzregff`.

## Cách chạy

1. Chọn `mode=preview`. Commit `main` cần có **Frontend CI** và **Supabase
   Full Integration** thành công. Nếu Full Integration chưa chạy trên commit
   hiện tại, kích hoạt workflow **Supabase Integration** trên `main` trước.
2. Với Change Order, đọc artifact `recipe-history-<run_id>`. Kiểm tra số bản
   ghi theo bảng, số bản ghi bất hoạt và `content_checksum`. Khi đã đối chiếu,
   chạy lại workflow với `mode=apply-history`, mã đó trong
   `reviewed_content_checksum` và mã dự án Staging trong `target_project_ref`.
   Kết quả phải ghi nhận `preserved: true`, số bản ghi đối chiếu khớp và
   `replay_status: REPLAYED`.
3. Với danh mục, xem log **Snapshot, adopt existing IDs, preview, apply and
   verify**. Đọc `planned_counts`, `issue_categories` và `blockers`. Nếu trạng
   thái là `PREVIEW` và phạm vi thay đổi đã được rà soát, dùng
   `source.content_checksum` của chính phần danh mục để chạy `mode=apply-master`.
   Điền cùng mã dự án Staging. Kết quả cần có `STAGING_MASTER_DATA_LOADED`,
   `operational_data_unchanged: true`, `replay_status: REPLAYED` và
   `AUTHENTICATED_MASTER_READS_PASS`.

Mỗi lần ghi lấy một snapshot mới. Nếu nội dung V1 thay đổi, chạy lại Preview
và đối chiếu mã mới. Trong lần chạy danh mục, backend dùng cùng snapshot để lập
kế hoạch, kiểm tra lại mã kế hoạch khi ghi và đối chiếu kết quả sau ghi. Lịch sử
và danh mục chạy độc lập, nên vẫn có thể lưu lịch sử khi danh mục còn vướng
kiểm tra nghiệp vụ. Các mã kiểm tra tương ứng với từng phần.

## Kiểm tra khi chạy lại

- Lịch sử Change Order lưu trạng thái và ngày hiệu lực gốc để tra cứu. Việc
  nhập lịch sử không kích hoạt quy tắc V1 trong công thức Atlas. [Hợp đồng lưu
  lịch sử](../api/recipe-change-order-history.md).
- Nếu Preview danh mục bị chặn hoặc hết thời gian, giữ lại log và xử lý các
  mục vướng bằng quy trình hiện hành trước khi thử ghi. Các cam kết công thức
  đã phát hành tiếp tục được kiểm tra theo hợp đồng nhập danh mục. [Hợp đồng
  nhập danh mục](../implementation-tasks/TASK-ATLAS-STAGING-MASTER-LOAD-01.md).
- Khi cần sửa kết quả đã ghi, dùng quy trình hiệu chỉnh có kiểm soát và giữ
  biên nhận nhập. Snapshot gốc ở trong phiên chạy. Artifact lịch sử chỉ chứa
  kết quả đối chiếu và mã kiểm tra.
