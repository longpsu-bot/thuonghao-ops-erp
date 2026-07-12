# 04 — Hướng dẫn rà soát dòng công thức

**Trạng thái:** Bản dành cho staff rà soát công thức  
**Mục đích:** Kiểm tra từng dòng công thức trước khi hệ thống tự động tính nhu cầu nguyên liệu.

---

## 1. Vì sao cần rà soát dòng công thức?

Công thức là nơi chuyển từ món ăn sang nhu cầu nguyên liệu.

Nếu công thức sai, hệ thống có thể vẫn tính rất nhanh nhưng kết quả sẽ sai.

Cần rà soát để phát hiện:

- nguyên liệu sai;
- định lượng sai;
- đơn vị sai;
- công thức thiếu nguyên liệu;
- nguyên liệu không còn sử dụng;
- nguyên liệu có định lượng bất thường;
- nguyên liệu vừa là nguyên liệu chính vừa là rau nêm/gia vị/trang trí.

---

## 2. Các thông tin cần có cho mỗi dòng công thức

Mỗi dòng công thức cần kiểm tra:

1. món ăn;
2. phiên bản công thức nếu có;
3. loại trường/suất ăn nếu có;
4. nguyên liệu;
5. định lượng;
6. đơn vị;
7. basis của công thức, ví dụ 100 suất;
8. ghi chú;
9. trạng thái nguyên liệu;
10. có cần rule đặc biệt không.

---

## 3. Quy tắc kiểm tra định lượng

### 3.1 Định lượng bằng 0 hoặc trống

Cần kiểm tra ngay.

Có thể là:

- thiếu dữ liệu;
- nguyên liệu không còn dùng;
- dòng công thức bị nhập nhầm;
- cần xóa khỏi công thức.

Không nên để hệ thống tự hiểu dòng trống là 0 nếu chưa xác nhận.

---

### 3.2 Định lượng quá nhỏ

Ví dụ:

```text
Hẹ: 5g / 100 suất
Hành lá: 10g / 100 suất
Ngò: 8g / 100 suất
```

Cần kiểm tra:

- có phải dùng để trang trí/nêm không;
- có đáng tính chính xác theo từng người không;
- có nên dùng rule khoán theo block người không;
- đơn vị có bị nhập sai không.

---

### 3.3 Định lượng quá lớn

Ví dụ:

```text
Muối: 5kg / 100 suất
Hẹ: 10kg / 100 suất
```

Cần kiểm tra:

- có nhập sai đơn vị không;
- có nhầm g thành kg không;
- có nhầm công thức 100 suất với công thức khác không;
- có phải là nguyên liệu chính thật không.

---

### 3.4 Nguyên liệu dual-use

Một nguyên liệu có thể có nhiều vai trò.

Ví dụ hẹ:

```text
Món canh hẹ: hẹ là nguyên liệu chính
Món khác: hẹ chỉ dùng để nêm/trang trí
```

Không nên tách thành hai nguyên liệu khác nhau nếu thực tế là cùng một nguyên liệu.

Cách xử lý đúng:

- giữ một nguyên liệu chuẩn;
- dùng rule tính toán để quyết định cách tính theo định lượng/ngữ cảnh;
- lưu trace để biết rule nào đã áp dụng.

---

## 4. Phân biệt nguyên liệu chính và rau nêm/gia vị/trang trí

### 4.1 Nguyên liệu chính

Là nguyên liệu có định lượng đáng kể và ảnh hưởng chính đến món ăn.

Cách tính thường là tỷ lệ theo số suất.

Ví dụ:

```text
Rau cải: 8kg / 100 suất
Thịt heo: 6kg / 100 suất
Hẹ trong món canh hẹ: 3kg / 100 suất
```

---

### 4.2 Rau nêm / herb / condiment / garnish

Là nguyên liệu dùng ít để nêm, tạo mùi, trang trí hoặc hoàn thiện món.

Cách tính chính xác từng gram theo từng suất thường không đáng tối ưu.

Ví dụ:

```text
Hành lá
Ngò rí
Hẹ trang trí
Ớt
Rau thơm
```

Với nhóm này, có thể dùng rule khoán:

```text
40g / 20 suất
50g / 50 suất
```

Tùy loại nguyên liệu và quyết định sau rà soát.

---

## 5. Staff cần đánh dấu gì?

Khi rà công thức, staff nên đánh dấu:

```text
OK
Cần xác nhận nguyên liệu
Cần xác nhận đơn vị
Cần xác nhận định lượng
Định lượng quá nhỏ
Định lượng quá lớn
Có thể là rau nêm/herb/condiment
Có thể là nguyên liệu chính
Có thể dual-use
Nguyên liệu inactive
Thiếu nhà cung ứng
```

---

## 6. Không yêu cầu staff chọn usage class cho mọi dòng ở MVP

Ở giai đoạn đầu, staff không cần phân loại thủ công từng dòng là MAIN, HERB, CONDIMENT, GARNISH.

Hệ thống sẽ được thiết kế theo hướng:

- suy ra từ cấu hình rule;
- dựa vào nhóm nguyên liệu;
- dựa vào định lượng trên basis công thức;
- cho phép exception khi cần.

Tuy nhiên, staff cần đánh dấu các trường hợp nghi ngờ để owner xem lại.

---

## 7. Ví dụ rà soát

### Ví dụ 1 — Hẹ trong món canh

```text
Món: Canh hẹ
Nguyên liệu: Hẹ
Định lượng: 3kg / 100 suất
```

Nhận xét:

```text
Có khả năng là nguyên liệu chính.
Tính theo tỷ lệ số suất.
```

---

### Ví dụ 2 — Hẹ dùng để nêm

```text
Món: Món mặn khác
Nguyên liệu: Hẹ
Định lượng: 40g / 100 suất
```

Nhận xét:

```text
Có khả năng là rau nêm/herb.
Không nên tối ưu từng gram theo đầu người.
Cần xem xét rule khoán theo block người.
```

---

### Ví dụ 3 — Định lượng bất thường

```text
Món: Canh
Nguyên liệu: Muối
Định lượng: 4kg / 100 suất
```

Nhận xét:

```text
Cần xác nhận ngay.
Có khả năng sai đơn vị hoặc sai định lượng.
```

---

## 8. Kết quả cần bàn giao

Sau khi rà soát công thức, staff cần gửi:

1. danh sách dòng công thức OK;
2. danh sách dòng cần xác nhận nguyên liệu;
3. danh sách dòng cần xác nhận đơn vị;
4. danh sách dòng có định lượng bất thường;
5. danh sách dòng có thể dùng rule khoán herb/condiment;
6. danh sách công thức thiếu hoặc sai nguyên liệu;
7. câu hỏi cần owner xác nhận.

---

## 9. Nguyên tắc cuối cùng

Không được để hệ thống tự tính dựa trên giả định ẩn.

Nếu một dòng công thức cần cách tính đặc biệt, cách tính đó phải là rule có thể xem, chỉnh và truy vết.
