# Rà soát giao diện Atlas cho nhân sự

## Mở Storybook tại máy cục bộ

1. Cài dependencies bằng `pnpm install`.
2. Chạy `pnpm storybook`.
3. Mở địa chỉ được hiển thị trong terminal, mặc định là `http://localhost:6006`.

## Cần rà soát

- Câu chữ tiếng Việt: có rõ vai trò, trạng thái, việc cần làm và bước bàn giao không.
- Luồng thao tác: nhân sự có biết phải xử lý ngoại lệ nào trước và chuyển việc cho ai không.
- Các trạng thái mẫu: kế hoạch bình thường, ưu tiên ngoại lệ, bị chặn/thiếu dữ liệu và ghi chú nhập kho.
- Những thông tin, cảnh báo hoặc bước nghiệp vụ còn thiếu để hoàn thành công việc hằng ngày.

## Chưa cần rà soát

- Tính đúng của số lượng, quy tắc tính, làm tròn, phân bổ hay quyết định nghiệp vụ.
- Phân quyền, đăng nhập, lưu dữ liệu, phát hành chứng từ, tồn kho và đối soát thực tế.
- Hiệu năng, tích hợp Supabase/Retool/Google Sheets, hay dữ liệu sản xuất.

## Phạm vi dữ liệu

Tất cả nội dung trong Storybook là fixture/mock cục bộ. Không có kết nối tới Supabase, Retool, Google Sheets, dữ liệu sản xuất hoặc dịch vụ AI.
