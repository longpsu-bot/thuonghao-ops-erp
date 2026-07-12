# 03 — Quy tắc đơn vị và quy đổi

**Trạng thái:** Bản dành cho staff và owner rà soát  
**Mục đích:** Xác định cách dùng đơn vị tính trong công thức, mua hàng, xuất hàng và báo cáo.

---

## 1. Vì sao đơn vị tính là phần rủi ro cao?

Sai đơn vị tính sẽ làm sai toàn bộ chuỗi vận hành.

Ví dụ:

```text
Công thức ghi 500g nhưng hệ thống hiểu là 500kg.
```

hoặc:

```text
Công thức tính bằng gram nhưng mua hàng bằng bó, không có quy đổi rõ ràng.
```

Những lỗi này có thể làm sai:

- nhu cầu nguyên liệu;
- danh sách mua hàng;
- phiếu đặt hàng;
- chi phí;
- giao hàng;
- báo cáo.

---

## 2. Các loại đơn vị cần phân biệt

### 2.1 Đơn vị công thức

Là đơn vị dùng trong định lượng công thức.

Ví dụ:

```text
g
kg
ml
lít
trái
quả
cái
```

Đơn vị công thức nên càng chuẩn càng tốt, vì đây là cơ sở tính nhu cầu.

---

### 2.2 Đơn vị mua hàng

Là đơn vị dùng khi đặt nhà cung ứng.

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

Đơn vị mua hàng có thể là đơn vị đóng gói hoặc đơn vị thương mại.

---

### 2.3 Đơn vị xuất hàng/giao hàng

Là đơn vị dùng khi kho hoặc tài xế giao cho trường/bếp.

Có thể giống hoặc khác đơn vị mua hàng.

Ví dụ:

```text
Mua theo thùng nhưng giao theo bịch.
Mua theo kg nhưng chia giao theo từng trường.
```

---

### 2.4 Đơn vị báo cáo

Là đơn vị dùng để tổng hợp và phân tích.

Ví dụ:

```text
kg cho rau/thịt/cá
lít hoặc ml cho chất lỏng
cái/bịch/hộp cho hàng đóng gói
```

---

## 3. Loại quy đổi

### 3.1 Quy đổi chuẩn toàn hệ thống

Quy đổi luôn đúng, không phụ thuộc nguyên liệu.

Ví dụ:

```text
1000g = 1kg
1000ml = 1l
```

Các quy đổi này có thể dùng chung.

---

### 3.2 Quy đổi theo nguyên liệu

Quy đổi chỉ đúng cho một nguyên liệu cụ thể.

Ví dụ:

```text
1 trái chuối = trọng lượng trung bình ? gram
1 bó hẹ = ? gram
1 bịch sữa chua = 70ml
```

Cần cẩn trọng vì quy đổi loại này có thể không chính xác tuyệt đối.

---

### 3.3 Quy đổi theo đóng gói / nhà cung ứng

Quy đổi phụ thuộc quy cách hàng hóa hoặc nhà cung ứng.

Ví dụ:

```text
1 thùng = 48 bịch
1 gói = 500g
1 chai = 1 lít
```

Nếu nhà cung ứng thay đổi quy cách đóng gói, rule phải có hiệu lực theo thời gian.

---

## 4. Quy tắc rà soát đơn vị

Với mỗi nguyên liệu, staff cần xác định:

1. đơn vị trong công thức là gì;
2. đơn vị mua hàng là gì;
3. đơn vị xuất/giao là gì;
4. có cần quy đổi không;
5. quy đổi là chuẩn toàn hệ thống hay riêng theo nguyên liệu;
6. quy đổi có đáng tin cậy không;
7. nếu không chắc thì đánh dấu `Cần xác nhận`.

---

## 5. Trường hợp cần đặc biệt chú ý

### 5.1 Rau nêm, herb, garnish

Ví dụ:

```text
Hẹ
Hành lá
Ngò rí
Rau thơm
```

Nếu mua theo bó nhưng công thức theo gram, cần xác định:

- có cần quy đổi bó sang gram không;
- hay chỉ dùng gram cho tính toán và mua theo kg;
- hay áp dụng rule tính khoán theo block người.

Không nên để hệ thống tự đoán.

---

### 5.2 Hàng đóng gói

Ví dụ:

```text
Sữa chua uống 70ml
Bánh gói
Sữa hộp
```

Cần ghi rõ:

- 1 đơn vị là gì;
- một thùng/gói lớn gồm bao nhiêu đơn vị nhỏ;
- công thức hoặc khẩu phần dùng đơn vị nào;
- mua hàng dùng đơn vị nào.

---

### 5.3 Nguyên liệu mua theo bó/cây/trái nhưng công thức theo gram

Đây là nhóm dễ phát sinh sai số.

Nếu không có quy đổi đáng tin cậy, nên cân nhắc:

- chuyển công thức về đơn vị mua thực tế;
- hoặc giữ công thức theo gram nhưng mua hàng làm tròn;
- hoặc dùng rule khoán nếu là rau nêm/herb.

---

## 6. Nguyên tắc rule hóa

Mọi quy đổi có ảnh hưởng đến tính toán phải là rule có thể xem và truy vết.

Không chấp nhận logic kiểu:

```text
Hệ thống tự biết 1 bó bằng bao nhiêu gram.
```

Nếu có quy đổi, phải biết:

- quy đổi nào được áp dụng;
- áp dụng từ ngày nào;
- áp dụng cho nguyên liệu nào;
- ai xác nhận;
- kết quả tính đã dùng rule nào.

---

## 7. Câu hỏi cần owner xác nhận

1. Đơn vị chuẩn cho từng nhóm nguyên liệu là gì?
2. Có cho phép dùng bó/cây/trái trong công thức không?
3. Quy đổi bó sang gram có nên dùng cho tính toán không?
4. Hàng đóng gói nên tính theo đơn vị nhỏ hay đơn vị thùng/gói lớn?
5. Quy đổi theo nhà cung ứng có cần version theo thời gian không?
6. Đơn vị nào bắt buộc phải có trong MVP?

---

## 8. Kết luận

Đơn vị tính là phần phải làm chặt trước khi viết engine tính toán.

Nếu đơn vị chưa rõ, requirement engine không được giả định ngầm. Phải cảnh báo hoặc yêu cầu xác nhận.
