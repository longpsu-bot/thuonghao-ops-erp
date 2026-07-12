# 05 — Mô hình cấu hình quy tắc tính toán

**Trạng thái:** Bản dành cho owner và nhân sự phụ trách dữ liệu  
**Mục đích:** Xác định cách OPS ERP lưu và áp dụng các rule tính toán để tránh logic ẩn.

---

## 1. Nguyên tắc cốt lõi

Mọi logic tính toán phải là rule có thể:

- xem được;
- chỉnh được theo quyền;
- có hiệu lực theo thời gian nếu cần;
- truy vết được trong kết quả;
- giải thích được khi kiểm tra;
- không hard-code ẩn trong code.

Không chấp nhận kiểu:

```text
Hệ thống tự biết cách tính.
```

Phải biết rõ:

```text
Rule nào được áp dụng?
Áp dụng cho nguyên liệu nào?
Áp dụng từ khi nào?
Ai cấu hình hoặc xác nhận?
Kết quả tính ra bao nhiêu?
```

---

## 2. Các nhóm rule cần có

### 2.1 Rule tính theo tỷ lệ công thức

Dùng cho nguyên liệu chính.

Ví dụ:

```text
Định lượng công thức: 5kg / 100 suất
Số suất thực tế: 250
Nhu cầu = 5 × 250 / 100 = 12.5kg
```

---

### 2.2 Rule khoán rau nêm/herb/condiment

Dùng cho nguyên liệu định lượng nhỏ, không đáng tối ưu chính xác từng gram theo đầu người.

Ví dụ:

```text
Hẹ trang trí: 40g / 20 suất
Số suất thực tế: 73
Nhu cầu = ceil(73 / 20) × 40g = 160g
```

Rule này là rule tính nhu cầu, không phải rule làm tròn mua hàng.

---

### 2.3 Rule quy đổi đơn vị

Ví dụ:

```text
1000g = 1kg
1 thùng = 48 bịch
1 bịch = 70ml
```

Cần phân biệt quy đổi chuẩn, quy đổi theo nguyên liệu và quy đổi theo đóng gói/nhà cung ứng.

---

### 2.4 Rule làm tròn mua hàng

Dùng sau khi đã tính ra nhu cầu.

Ví dụ:

```text
Nhu cầu: 1.23kg
Bước đặt hàng: 0.5kg
Số lượng mua: 1.5kg
```

---

### 2.5 Rule theo quy cách đóng gói

Ví dụ:

```text
1 thùng = 48 bịch
Chỉ mua nguyên thùng
```

---

### 2.6 Rule theo nhà cung ứng

Ví dụ:

```text
Nhà cung ứng A bán theo kg
Nhà cung ứng B bán theo bó
```

Nếu có khác biệt theo nhà cung ứng, rule phải ghi rõ phạm vi áp dụng.

---

## 3. Trường thông tin gợi ý cho bảng rule

Một rule tính toán nên có các thông tin sau:

```text
rule_id
rule_type
ingredient_id
ingredient_group_id
usage_class
threshold_quantity_per_recipe_basis
recipe_basis_portions
allowance_batch_size
allowance_quantity_per_batch
unit
rounding_method
order_step
minimum_order_quantity
supplier_id
effective_from
effective_to
priority
is_active
created_by
approved_by
note
```

Không phải rule nào cũng dùng tất cả các trường. Nhưng hệ thống cần đủ cấu trúc để không phải hard-code logic.

---

## 4. Thứ tự ưu tiên rule

Thứ tự ưu tiên đề xuất:

1. rule cụ thể cho dòng công thức nếu sau này có;
2. rule cụ thể theo nguyên liệu;
3. rule theo nhóm nguyên liệu;
4. rule theo nhà cung ứng nếu liên quan mua hàng;
5. rule mặc định toàn hệ thống.

Nếu có nhiều rule cùng áp dụng, hệ thống phải xác định theo `priority` và hiệu lực thời gian.

Nếu vẫn mơ hồ, hệ thống phải cảnh báo, không tự đoán.

---

## 5. Rule inference không được là magic rule

OPS ERP có thể tự suy ra cách tính từ config để giảm tải nhập liệu cho staff.

Ví dụ:

```text
Nguyên liệu thuộc nhóm rau nêm
Định lượng <= threshold
=> áp dụng herb/condiment batch allowance
```

Nhưng inference này vẫn phải ghi lại:

- rule_id nào đã áp dụng;
- vì sao dòng này đủ điều kiện;
- threshold là bao nhiêu;
- kết quả trước và sau khi áp dụng rule;
- có warning không.

Tức là tự suy ra được, nhưng không được ẩn.

---

## 6. Ví dụ rule herb/condiment

```text
rule_type: HERB_CONDIMENT_BATCH_ALLOWANCE
ingredient_group: Rau nêm
threshold_quantity_per_100_portions: 100g
allowance_batch_size: 20 portions
allowance_quantity_per_batch: 40g
unit: g
effective_from: 2026-07-01
priority: 100
active: true
```

Ý nghĩa:

```text
Nếu một nguyên liệu thuộc nhóm rau nêm và định lượng trong công thức <= 100g / 100 suất,
thì tính theo 40g / 20 suất thay vì tính tuyến tính từng gram theo đầu người.
```

Nếu hẹ trong món canh có định lượng 3kg / 100 suất thì vượt threshold, nên tính như nguyên liệu chính.

---

## 7. Trace cần lưu trong kết quả tính

Khi hệ thống tính ra một nhu cầu nguyên liệu, cần lưu hoặc hiển thị được:

```text
source_demand_id
recipe_line_id
ingredient_id
original_recipe_quantity
original_recipe_unit
calculation_method
applied_rule_id
threshold_used
quantity_before_rule
quantity_after_rule
unit_conversion_rule_id
rounding_rule_id
final_quantity
warning_codes
```

Mục tiêu: khi có người hỏi “tại sao số này ra như vậy?”, hệ thống trả lời được.

---

## 8. Staff cần làm gì trong giai đoạn review?

Staff không cần thiết kế rule table.

Staff cần cung cấp dữ liệu để owner và system architect chốt rule:

1. nguyên liệu thuộc nhóm nào;
2. nguyên liệu nào có thể dual-use;
3. đơn vị công thức và đơn vị mua hàng;
4. dòng công thức nào có định lượng nhỏ bất thường;
5. dòng công thức nào có định lượng lớn bất thường;
6. nguyên liệu nào nên tính khoán;
7. nguyên liệu nào cần exception.

---

## 9. Owner cần chốt gì trước khi implementation?

Trước khi Codex triển khai requirement engine, owner cần chốt:

1. các nhóm rule tính toán ban đầu;
2. danh sách nhóm nguyên liệu áp dụng herb/condiment rule;
3. threshold ban đầu;
4. allowance batch size ban đầu;
5. allowance quantity ban đầu;
6. rule làm tròn mua hàng;
7. quy tắc warning/blocking;
8. quyền ai được sửa rule;
9. cách lưu version và ngày hiệu lực rule.

---

## 10. Kết luận

Mục tiêu không phải là làm hệ thống phức tạp.

Mục tiêu là tránh các logic ẩn làm staff mất niềm tin vào số liệu.

Một rule tốt là rule mà người vận hành có thể xem, hiểu và giải thích được.
