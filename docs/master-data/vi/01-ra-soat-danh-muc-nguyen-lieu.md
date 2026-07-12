# 01 — Rà soát danh mục nguyên liệu

**Trạng thái:** Bản dành cho staff rà soát  
**Mục đích:** Chuẩn hóa danh mục nguyên liệu trước khi chốt table definition và rule tính toán.

---

## 1. Vì sao cần rà soát kỹ danh mục nguyên liệu?

Danh mục nguyên liệu là nền tảng của toàn bộ OPS ERP.

Nếu danh mục nguyên liệu sai, các phần sau sẽ sai theo:

- công thức món ăn;
- nhu cầu nguyên liệu;
- danh sách mua hàng;
- phân công nhà cung ứng;
- phiếu đặt hàng;
- phiếu xuất kho/giao hàng;
- báo cáo chi phí và kiểm soát vận hành.

Nguyên tắc: **một nguyên liệu phải có một định nghĩa rõ ràng, một tên chuẩn và một cách tính rõ ràng.**

---

## 2. Các trường cần rà soát cho từng nguyên liệu

Staff cần kiểm tra từng nguyên liệu theo các nhóm thông tin sau.

### 2.1 Tên nguyên liệu

Cần kiểm tra:

- tên nguyên liệu hiện tại;
- tên chuẩn đề xuất;
- cách gọi khác nếu có;
- lỗi chính tả;
- tên quá chung chung;
- nguyên liệu bị trùng do khác cách viết.

Ví dụ cần xử lý:

```text
Hẹ
Lá hẹ
Hẹ lá
Rau hẹ
```

Nếu đây là cùng một nguyên liệu thì cần thống nhất một tên chuẩn.

---

### 2.2 Trạng thái sử dụng

Cần xác định nguyên liệu:

- đang sử dụng;
- tạm ngưng;
- không còn sử dụng;
- trùng với nguyên liệu khác;
- cần xác nhận thêm.

Không nên xóa nguyên liệu cũ ngay nếu đã từng phát sinh dữ liệu. Nên đánh dấu không hoạt động hoặc cần xử lý.

---

### 2.3 Nhóm nguyên liệu

Cần gán nhóm để phục vụ quản lý và rule tính toán.

Nhóm gợi ý:

- thịt;
- cá/hải sản;
- trứng;
- rau củ;
- rau nêm/herb;
- gia vị/condiment;
- hàng khô;
- trái cây;
- đồ uống;
- sữa/sữa chua;
- bao bì/vật tư;
- khác/cần xác nhận.

Một số nguyên liệu có thể khó phân loại. Nếu không chắc, đánh dấu `Cần xác nhận`.

---

### 2.4 Đơn vị mua hàng

Cần kiểm tra đơn vị dùng khi mua hàng hoặc đặt nhà cung ứng.

Ví dụ:

- kg;
- g;
- bó;
- cây;
- trái;
- quả;
- chai;
- bịch;
- thùng;
- gói;
- hộp.

Cần ghi rõ nếu đơn vị mua là đơn vị đóng gói, ví dụ:

```text
1 bịch = 70ml
1 thùng = 48 bịch
1 bó = khoảng bao nhiêu gram? cần xác nhận nếu dùng để tính toán
```

---

### 2.5 Đơn vị trong công thức

Cần kiểm tra đơn vị dùng trong công thức có khác đơn vị mua hàng không.

Ví dụ:

```text
Công thức dùng: gram
Mua hàng dùng: kg
```

Trường hợp này cần có quy đổi rõ ràng:

```text
1000g = 1kg
```

Không được để hệ thống tự đoán nếu đơn vị không rõ.

---

### 2.6 Nhà cung ứng

Cần kiểm tra:

- nguyên liệu có nhà cung ứng chưa;
- có nhiều nhà cung ứng không;
- nhà cung ứng mặc định là ai;
- có nguyên liệu nào chưa có nhà cung ứng;
- có nhà cung ứng đã ngưng nhưng vẫn còn gán không.

---

### 2.7 Nguyên liệu có thể vừa là nguyên liệu chính vừa là rau nêm/gia vị/trang trí

Cần đánh dấu các nguyên liệu có khả năng dùng theo nhiều vai trò.

Ví dụ:

```text
Hẹ
Hành lá
Ngò rí
Rau thơm
Tỏi
Ớt
Gừng
Sả
```

Ví dụ hẹ:

- nếu dùng nhiều trong món canh thì là nguyên liệu chính;
- nếu dùng ít để nêm/trang trí thì nên tính khoán theo block người.

Staff không cần tự quyết rule cuối cùng. Chỉ cần đánh dấu nguyên liệu có khả năng dual-use để owner xem xét sau.

---

## 3. Các cờ rà soát nên dùng

Nên có cột ghi chú/cờ rà soát như sau:

```text
OK
Cần đổi tên
Cần gộp trùng
Cần xác nhận nhóm
Cần xác nhận đơn vị
Cần xác nhận nhà cung ứng
Có khả năng dual-use
Có khả năng herb/condiment
Không còn sử dụng
```

---

## 4. Các lỗi thường gặp

### 4.1 Trùng nguyên liệu

Một nguyên liệu có nhiều tên khác nhau.

Ví dụ:

```text
Thịt heo xay
Heo xay
Thịt nạc xay
```

Cần xác định có phải cùng một nguyên liệu hay không.

---

### 4.2 Tên nguyên liệu quá chung

Ví dụ:

```text
Rau
Gia vị
Thịt
Cá
```

Tên này không đủ để mua hàng và tính toán. Cần làm rõ.

---

### 4.3 Đơn vị không thống nhất

Ví dụ:

```text
Cùng một nguyên liệu lúc ghi kg, lúc ghi bó, lúc ghi gói.
```

Cần xác định đơn vị công thức, đơn vị mua hàng và quy đổi nếu có.

---

### 4.4 Nguyên liệu đã ngưng nhưng vẫn còn trong công thức

Cần đánh dấu để kiểm tra lại công thức hoặc thay thế nguyên liệu.

---

## 5. Kết quả cần bàn giao

Sau khi rà soát xong, staff cần gửi lại:

1. danh sách nguyên liệu chuẩn;
2. danh sách nguyên liệu cần gộp;
3. danh sách nguyên liệu cần đổi tên;
4. danh sách nguyên liệu chưa rõ nhóm;
5. danh sách nguyên liệu chưa rõ đơn vị;
6. danh sách nguyên liệu chưa có nhà cung ứng;
7. danh sách nguyên liệu có khả năng là rau nêm/herb/condiment;
8. câu hỏi cần owner xác nhận.

---

## 6. Nguyên tắc quan trọng

Không cố sửa cho xong nếu chưa chắc.

Nếu dữ liệu chưa rõ, hãy đánh dấu `Cần xác nhận`.

Mục tiêu của đợt rà soát này không phải là làm đẹp danh sách, mà là đảm bảo hệ thống tính toán sau này **đúng, giải thích được và kiểm soát được**.
