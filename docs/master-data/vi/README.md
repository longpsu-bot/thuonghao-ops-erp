# Bộ tài liệu rà soát dữ liệu danh mục — Tiếng Việt

**Mục đích:** Bộ tài liệu này dùng để nhân sự nội bộ rà soát danh mục nguyên liệu, đơn vị tính, định lượng công thức và các quy tắc tính toán trước khi xây dựng requirement engine.

**Lưu ý về ngôn ngữ:** Bản tiếng Anh là tài liệu kỹ thuật có tính thẩm quyền cho kiến trúc và triển khai. Bản tiếng Việt này là bản phục vụ vận hành, rà soát nội bộ và đào tạo nhân sự.

---

## Thứ tự rà soát đề xuất

1. `01-ra-soat-danh-muc-nguyen-lieu.md`
   - Dùng trước tiên.
   - Nhân sự rà từng nguyên liệu: tên, nhóm, đơn vị mua, đơn vị công thức, trạng thái, nhà cung ứng, ghi chú.

2. `03-quy-tac-don-vi-va-quy-doi.md`
   - Dùng để kiểm tra đơn vị tính và quy đổi.
   - Đây là phần rủi ro cao vì sai đơn vị sẽ làm sai toàn bộ nhu cầu mua hàng.

3. `04-huong-dan-ra-soat-dong-cong-thuc.md`
   - Dùng khi rà soát định lượng trong từng dòng công thức.
   - Đặc biệt chú ý nguyên liệu có định lượng quá nhỏ, quá lớn, hoặc vừa là nguyên liệu chính vừa là rau nêm/gia vị/trang trí.

4. `05-mo-hinh-cau-hinh-quy-tac-tinh-toan.md`
   - Dùng để chốt các rule tính toán.
   - Mọi logic tính toán phải là rule có thể xem, chỉnh, truy vết; không dùng logic ẩn.

5. `02-dinh-nghia-bang-nguyen-lieu.md`
   - Dùng sau khi staff rà soát xong.
   - Tài liệu này giúp chốt table definition cho danh mục nguyên liệu.

---

## Nguyên tắc rà soát

- Không sửa dữ liệu theo cảm tính nếu chưa rõ nguồn gốc.
- Nếu không chắc, đánh dấu `Cần xác nhận` thay vì đoán.
- Mỗi nguyên liệu phải có một tên chuẩn.
- Không tạo nhiều nguyên liệu trùng nhau chỉ vì khác cách gọi.
- Đơn vị công thức và đơn vị mua hàng phải rõ ràng.
- Nguyên liệu vừa là nguyên liệu chính vừa là rau nêm/condiment phải được ghi chú.
- Các quy tắc tính toán phải được cấu hình và truy vết, không để thành “magic rule”.

---

## Kết quả cần bàn giao sau rà soát

Sau khi rà soát, staff cần gửi lại:

1. danh sách nguyên liệu đã chuẩn hóa;
2. danh sách nguyên liệu trùng/lỗi cần gộp hoặc xử lý;
3. danh sách nguyên liệu chưa rõ nhóm;
4. danh sách nguyên liệu có vấn đề về đơn vị tính;
5. danh sách nguyên liệu có khả năng là rau nêm/herb/condiment;
6. danh sách công thức có định lượng bất thường;
7. các câu hỏi cần chủ sở hữu sản phẩm xác nhận.
