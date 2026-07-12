# 02 — Định nghĩa bảng nguyên liệu

**Trạng thái:** Bản phục vụ chốt table definition sau khi rà soát danh mục  
**Mục đích:** Xác định các trường dữ liệu cần có cho bảng nguyên liệu trong OPS ERP.

---

## 1. Nguyên tắc thiết kế

Bảng nguyên liệu không chỉ để lưu tên nguyên liệu. Bảng này là nền tảng cho:

- công thức;
- tính nhu cầu;
- đơn vị quy đổi;
- mua hàng;
- phân công nhà cung ứng;
- xuất hàng;
- báo cáo;
- truy vết thay đổi.

Do đó, mỗi trường trong bảng phải có mục đích rõ ràng.

---

## 2. Các trường thông tin đề xuất

### 2.1 Mã nguyên liệu

```text
ingredient_id
```

Dùng làm định danh ổn định trong hệ thống.

Nguyên tắc:

- không thay đổi tùy tiện;
- không tái sử dụng mã của nguyên liệu cũ cho nguyên liệu mới;
- không dựa vào tên nguyên liệu để làm định danh chính.

---

### 2.2 Tên chuẩn

```text
canonical_name
```

Tên chuẩn dùng trong hệ thống.

Ví dụ:

```text
Hẹ
Thịt heo xay
Cà rốt
Sữa chua uống 70ml hương dâu
```

Tên chuẩn phải đủ rõ để nhân sự mua hàng và bếp hiểu cùng một nghĩa.

---

### 2.3 Tên hiển thị tiếng Việt

```text
display_name_vi
```

Tên hiển thị cho staff.

Thông thường có thể giống tên chuẩn, nhưng vẫn nên tách riêng để sau này hỗ trợ song ngữ hoặc tên kỹ thuật.

---

### 2.4 Tên khác / alias

```text
aliases
```

Dùng để lưu các cách gọi khác.

Ví dụ:

```text
Hẹ lá, lá hẹ, rau hẹ
```

Alias giúp tìm kiếm và tránh tạo trùng nguyên liệu.

---

### 2.5 Nhóm nguyên liệu

```text
ingredient_group_id
```

Dùng để phân loại nguyên liệu.

Nhóm nguyên liệu có thể ảnh hưởng đến:

- màn hình lọc dữ liệu;
- danh sách mua hàng;
- quy tắc làm tròn;
- quy tắc tính khoán herb/condiment;
- báo cáo chi phí;
- phân công nhà cung ứng.

---

### 2.6 Trạng thái hoạt động

```text
is_active
```

Dùng để xác định nguyên liệu còn được sử dụng hay không.

Nguyên tắc:

- nguyên liệu đã từng phát sinh dữ liệu không nên xóa trực tiếp;
- nếu không dùng nữa thì chuyển sang inactive;
- công thức đang dùng nguyên liệu inactive phải có cảnh báo.

---

### 2.7 Đơn vị công thức mặc định

```text
default_recipe_unit
```

Đơn vị thường dùng khi nhập công thức.

Ví dụ:

```text
g
kg
trái
quả
cái
ml
```

---

### 2.8 Đơn vị mua hàng mặc định

```text
default_purchase_unit
```

Đơn vị thường dùng khi mua hàng.

Ví dụ:

```text
kg
bó
bịch
thùng
chai
gói
hộp
```

Nếu đơn vị mua hàng khác đơn vị công thức thì cần có quy đổi rõ ràng.

---

### 2.9 Bước đặt hàng / order step

```text
order_step
```

Dùng để làm tròn số lượng mua hàng.

Ví dụ:

```text
0.1 kg
0.5 kg
1 kg
1 bó
1 thùng
```

Order step là rule mua hàng, không phải định lượng công thức.

---

### 2.10 Loại quy đổi đơn vị

```text
conversion_policy
```

Cần xác định quy đổi của nguyên liệu là:

- quy đổi chuẩn toàn hệ thống;
- quy đổi riêng theo nguyên liệu;
- quy đổi theo nhà cung ứng/đóng gói;
- chưa rõ, cần xác nhận.

Ví dụ:

```text
1000g = 1kg
```

là quy đổi chuẩn.

Nhưng:

```text
1 bó hẹ = ? gram
```

có thể là quy đổi riêng theo vận hành hoặc không nên dùng làm quy đổi chính xác.

---

### 2.11 Cờ dual-use

```text
is_potential_dual_use
```

Dùng để đánh dấu nguyên liệu có thể vừa là nguyên liệu chính vừa là rau nêm/gia vị/trang trí.

Ví dụ:

```text
Hẹ
Hành lá
Ngò rí
Tỏi
Ớt
Gừng
Sả
```

Cờ này không tự quyết cách tính. Cách tính phải dựa trên rule cấu hình và định lượng công thức.

---

### 2.12 Ghi chú vận hành

```text
operational_note
```

Dùng để lưu các lưu ý như:

- chỉ mua ở nhà cung ứng cụ thể;
- cần đặt trước;
- dễ hư hỏng;
- đơn vị mua thực tế khác đơn vị công thức;
- cần owner xác nhận.

---

## 3. Không nên đưa gì vào bảng nguyên liệu?

Không nên hard-code logic tính toán trực tiếp vào bảng nguyên liệu nếu logic đó cần thay đổi theo thời gian.

Ví dụ không nên chỉ có một cột đơn giản kiểu:

```text
is_herb = true
```

rồi hệ thống tự xử lý ẩn phía sau.

Thay vào đó:

- bảng nguyên liệu có thể đánh dấu nhóm hoặc khả năng dual-use;
- rule tính toán phải nằm trong bảng cấu hình rule riêng;
- kết quả tính phải ghi lại rule đã áp dụng.

---

## 4. Các quyết định cần owner xác nhận

Sau khi staff rà soát xong, owner cần xác nhận:

1. danh sách field chính thức cho bảng nguyên liệu;
2. nhóm nguyên liệu chính thức;
3. đơn vị công thức mặc định;
4. đơn vị mua hàng mặc định;
5. cách xử lý nguyên liệu inactive;
6. cách xử lý nguyên liệu trùng;
7. cách đánh dấu nguyên liệu dual-use;
8. field nào bắt buộc nhập, field nào có thể để trống.

---

## 5. Kết luận

Bảng nguyên liệu phải đủ đơn giản để staff duy trì, nhưng đủ chặt để hệ thống tính toán chính xác.

Mọi logic tính toán phức tạp phải nằm trong cấu hình rule có thể xem, chỉnh và truy vết, không nằm trong logic ẩn của code.
