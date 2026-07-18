# PA-06D Requirement Quantity Review and Supplier Allocation Workbenches

**Status:** Future UI specification; no implementation is authorized

**Business contract:** [PA-06D Quantity Truth Contract](../architecture/pa-06d-quantity-truth-rounding-rebalancing-contract.md)

**Existing screen map:** [PA-06A Screen, Workbench, and I/O Map](pa-06a-screen-workbench-and-io-map.md)

## 1. Vietnamese-first interaction contract

All normal operator content is concise, natural, professional Vietnamese. English identifiers, API names, enum values, UUIDs and error codes may appear only in an expandable support detail. The normal surface distinguishes every quantity by business meaning and never uses `Số lượng` alone where more than one meaning is visible.

Operator examples use Vietnamese decimal commas and `dd/mm/yyyy`. Display precision comes from the applicable operational step. The final confirmation never exposes six-decimal entitlements; the explanation drawer may show a rounded ratio or a higher-precision raw calculation when needed.

## 2. Workbench A — Rà soát số lượng nhu cầu

### 2.1 Purpose and operator

Planning staff review calculated demand, select the meaningful operational quantity, see the Procurement quantization consequence, and confirm a versioned need. Procurement and managers may have read-only access. The workbench does not directly edit supplier allocation.

### 2.2 Entry context and filters

- Entry: `Lập nhu cầu` → `Rà soát số lượng nhu cầu`, from an authorized requirement queue or a returned aggregate link.
- Filters: `Ngày phục vụ`, `Trường / khách hàng`, `Nguồn nhu cầu`, `Nguyên liệu`, `Trạng thái`, `Có điều chỉnh`, `Có chênh lệch do làm tròn`.
- The header shows source set, service scope, Planning version, rule-set effective date, blocking issue count and release state.
- A missing authorized discovery read produces an unavailable state, never a private-table browser query.

### 2.3 Row identity and source trace

Technical identity is the immutable requirement line revision plus its owning aggregate/version. Normal UI shows service date, destination, source reference, ingredient and source-line label. `Xem nguồn và lịch sử` opens:

- source object and released revision;
- recipe/BOM or direct-source lineage as applicable;
- raw calculation components and unit conversions;
- prior confirmed revisions, actors, reasons and times;
- current rule-set version and effective date;
- commands/events/audit visible through authorized reads.

### 2.4 Table columns

| Vietnamese label         | Meaning and behavior                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------- |
| Ngày phục vụ             | `dd/mm/yyyy`; part of business context, not editable here                                   |
| Trường / khách hàng      | Authorized destination label                                                                |
| Nguồn nhu cầu            | Human-readable source type and reference                                                    |
| Nguyên liệu              | Ingredient name; internal ID only in support detail                                         |
| Đơn vị                   | Planning/purchase unit with conversion explanation if different                             |
| Nhu cầu tính toán        | Raw Calculated Requirement; normal column uses useful detail, full precision in explanation |
| Nhu cầu vận hành         | Planning Operational Quantity quantized to the approved Planning step                       |
| Nhu cầu đã xác nhận      | Current or proposed authoritative Planning value                                            |
| Bước đặt hàng            | Effective purchase step and rule source                                                     |
| Quy tắc làm tròn         | `Làm tròn lên theo bước đặt hàng` or explicit named rule                                    |
| Số lượng đề xuất đặt mua | Backend preview result; not client-calculated                                               |
| Chênh lệch do làm tròn   | Proposed purchase minus confirmed need, including sign and unit                             |
| Lý do điều chỉnh         | Required when proposed confirmed need differs from current/calculated policy                |
| Trạng thái               | Business wording such as `Chưa xác nhận`, `Sẵn sàng xem xét`, `Dữ liệu đã thay đổi`         |
| Phiên bản                | Human-readable aggregate version; technical details secondary                               |

Normal rows show step-derived digits. For example, confirmed need may show `2,01 kg` under a `0,01 kg` Planning step, while proposed purchase shows `2,10 kg` under a `0,1 kg` purchase step.

`Nhu cầu vận hành` is a working label only. Its approval state is **Proposed pending product-owner and operations-language review**; the candidate comparison in section 6.1 must be resolved before implementation.

### 2.5 Edit, preview, and confirmation flow

1. Operator enters `Nhu cầu đã xác nhận` and `Lý do điều chỉnh` where required.
2. Client performs only immediate input hygiene; backend resolves unit policy and calculates authoritative preview.
3. Action: `Xem trước số lượng xác nhận và đề xuất đặt mua`.
4. Preview shows raw, current, proposed Planning quantity, Planning step, purchase step, purchase rule, proposed purchasable quantity, rounding difference, versions and warnings.
5. Any input/source/rule/version change marks it `Dữ liệu đã thay đổi` and disables confirmation.
6. Final action: `Xác nhận và lưu nhu cầu đã xác nhận`.
7. Confirmation states every exact operational value to be persisted and the downstream consequence.
8. Success replaces draft state with the returned authoritative snapshot, then an authorized readback verifies it.
9. Only `Đã lưu và xác minh` permits progression to the next allowed action.

### 2.6 Warnings and gates

- Excessive input digits explain the approved Planning step and require correction; the UI does not silently trim.
- Missing Planning step or purchase step blocks preview.
- A proposed purchase below confirmed need is invalid and blocks confirmation.
- A released downstream PO blocks in-place modification and directs the operator to the correction workflow.
- Readback mismatch and uncertain transport block progression.

## 3. Workbench B — Phân bổ số lượng cho nhà cung cấp

### 3.1 Purpose and selected requirement header

Procurement staff allocate one confirmed purchase quantity across eligible suppliers and preview proportional rebalancing. The selected header shows:

- `Ngày phục vụ`, `Trường / khách hàng`, `Nguyên liệu`, `Đơn vị`;
- `Nhu cầu đã xác nhận`, `Số lượng mua đã xác nhận`, `Bước đặt hàng`;
- `Phiên bản phân bổ`, `Tổng đã phân bổ`, `Số lượng chưa phân bổ`;
- rule-set version, current PO release state and source Planning revision.

The workbench is read-only until a future split-allocation backend contract exists. PA-05E's current full-line command is not a safe substitute.

### 3.2 Eligibility and comparison table

Eligibility is supplied by an authorized backend read with effective date, scope and reason. An ineligible supplier is not silently removed from a current released fact; it is shown as a blocking issue requiring the source owner or correction workflow.

| Column       | Meaning                                                                                       |
| ------------ | --------------------------------------------------------------------------------------------- |
| Nhà cung cấp | Eligible supplier business name                                                               |
| Hiện tại     | Exact current persisted portion                                                               |
| Đề xuất      | Exact backend-proposed whole-tick portion                                                     |
| Chênh lệch   | Proposed minus current, with sign                                                             |
| Tỷ lệ        | Derived explanatory share; not authoritative                                                  |
| Phần dư      | Residual ticks assigned to this supplier, normally `0`                                        |
| Trạng thái   | `Giữ nguyên`, `Tăng`, `Giảm`, `Thêm mới`, `Loại khỏi phương án`, or a blocking business state |

Footer totals show `Tổng hiện tại`, `Tổng đề xuất`, `Số lượng chưa phân bổ`, and exact equality to the confirmed purchase quantity.

### 3.3 Actions

- `Thêm nhà cung cấp vào phương án` — selects only from authorized eligible suppliers.
- `Sửa số lượng phân bổ` — accepts values that are exact multiples of the effective step; it never rounds silently.
- `Loại nhà cung cấp khỏi phương án` — creates a proposed removal and shows redistribution consequence.
- `Xem trước phân bổ lại theo tỷ lệ` — replaces the vague Retool action `Cân bằng`.
- `Xác nhận và lưu phương án phân bổ` — available only for a current backend preview with exact totals.

### 3.4 Proportional preview content

The preview must state:

```text
Phương pháp: Giữ nguyên tỷ lệ phân bổ hiện tại
Bước đặt hàng: 0,1 kg
Tổng số đơn vị theo bước đặt hàng: 100
Nguyên tắc phân bổ phần dư: Theo thứ tự ưu tiên phần dư đã hiển thị
Nhà cung cấp nhận phần dư: Nhà cung cấp C
Số dòng thêm mới: 0
Số dòng thay đổi: 3
Số dòng loại khỏi phương án: 0
```

It then lists every exact current/proposed portion and tick count. It exposes the complete residual-recipient order when more than one supplier has equal fractional entitlement. It does not use row position or supplier ID as an unexplained tie-break.

Only expandable support detail may append the technical word in parentheses, for example `Tổng số đơn vị theo bước đặt hàng (tick): 100`. The normal operator surface uses `Tổng số đơn vị theo bước đặt hàng` and never uses `tick` alone.

### 3.5 Manual edit, zero and release behavior

- A manual tick-valid portion becomes a preview input; all affected unlocked portions require a new backend preview.
- Support for explicitly locked portions is recommended but pending product approval and may be omitted from the first allocation backend task.
- A total of zero proposes removal of all unreleased portions and requires explicit confirmation.
- An allocation below or above the confirmed purchase total cannot be saved.
- A released PO disables edit/preview/commit. The page shows the PO reference and the authorized correction entry point.

### 3.6 Final confirmation and authoritative result

Final confirmation repeats the rule, step, confirmed purchase quantity, each exact persisted supplier portion, residual, recipient, added/changed/removed rows, source/aggregate versions and downstream PO effect. After commit, the UI discards local values, renders the command's returned snapshot, performs authorized readback and shows `Đã lưu và xác minh` only when exact equality is proven.

## 4. Operator-state matrix

| State                       | Workbench | Required Vietnamese presentation                                                                               | Allowed next action                       |
| --------------------------- | --------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| Loading                     | Both      | `Đang tải dữ liệu số lượng…`                                                                                   | Chưa có                                   |
| No selected context         | Both      | `Chưa chọn phạm vi làm việc. Hãy chọn ngày phục vụ và trường / khách hàng.`                                    | `Chọn phạm vi làm việc`                   |
| Empty result                | Both      | `Không có nhu cầu phù hợp với bộ lọc hiện tại. Chưa có dữ liệu nào được thay đổi.`                             | `Đổi bộ lọc`                              |
| Unchanged                   | A         | `Số lượng hiện tại chưa thay đổi.`                                                                             | `Chỉnh sửa` hoặc `Xem trước`              |
| Edited draft                | Both      | `Có thay đổi chưa được lưu. Hãy xem trước kết quả trước khi xác nhận.`                                         | `Xem trước` hoặc `Bỏ thay đổi`            |
| Invalid quantity            | Both      | `Số lượng không hợp lệ. Chưa có dữ liệu nào được lưu. Hãy nhập số lớn hơn hoặc bằng 0 theo quy định của dòng.` | `Sửa số lượng`                            |
| Excessive input precision   | Both      | `Số lượng có nhiều chữ số hơn bước cho phép. Chưa có dữ liệu nào được lưu. Hãy nhập theo bước 0,01 kg.`        | `Sửa số lượng`                            |
| Missing Planning step       | A         | `Chưa có bước xác nhận nhu cầu cho đơn vị này. Không thể xem trước hoặc lưu.`                                  | `Xem người phụ trách quy tắc`             |
| Missing purchase step       | Both      | `Chưa có bước đặt hàng hợp lệ. Không thể tính số lượng đề xuất đặt mua.`                                       | `Xem người phụ trách dữ liệu nguyên liệu` |
| Below-demand rounding       | A         | `Kết quả đề xuất thấp hơn nhu cầu đã xác nhận. Đây là kết quả không hợp lệ và chưa được lưu.`                  | `Xem chi tiết quy tắc`                    |
| Allocation below total      | B         | `Phương án còn thiếu 0,1 kg. Chưa thể lưu.`                                                                    | `Phân bổ phần còn thiếu`                  |
| Allocation above total      | B         | `Phương án vượt 0,2 kg. Chưa thể lưu.`                                                                         | `Giảm số lượng phân bổ`                   |
| Zero total                  | B         | `Số lượng mua đã xác nhận bằng 0. Phương án sẽ loại toàn bộ nhà cung cấp chưa phát hành đơn đặt hàng.`         | `Xem trước các dòng sẽ loại` hoặc `Hủy`   |
| Preferred supplier proposed | B         | `Nhà cung cấp A được đề xuất theo thứ tự ưu tiên hiện hành. Đề xuất này chưa được lưu.`                        | `Xem xét đề xuất` hoặc `Đổi nhà cung cấp` |
| Supplier manually changed   | B         | `Nhà cung cấp hoặc số lượng đã thay đổi. Hãy tính lại phương án trước khi lưu.`                                | `Tính lại phương án`                      |
| Preview calculating         | Both      | `Đang tính phương án xem trước…`                                                                               | Chưa có; chỉ cho phép hủy nếu an toàn     |
| Preview ready               | Both      | `Phương án đã sẵn sàng để xem xét. Các số lượng hiển thị là số lượng sẽ được lưu nếu xác nhận.`                | `Xác nhận` hoặc `Quay lại chỉnh sửa`      |
| Preview stale               | Both      | `Dữ liệu đã thay đổi sau khi lập phương án. Phương án này chưa được lưu.`                                      | `Tải lại và lập phương án mới`            |
| Submitting                  | Both      | `Đang lưu. Vui lòng không đóng trang hoặc gửi lại yêu cầu.`                                                    | Chưa có                                   |
| Saved and verified          | Both      | `Đã lưu và xác minh. Dữ liệu đọc lại khớp hoàn toàn với phương án đã xác nhận.`                                | `Tiếp tục`                                |
| Persisted/readback mismatch | Both      | `Dữ liệu lưu không khớp với kết quả xác minh. Không tiếp tục phát hành chứng từ.`                              | `Xem lịch sử thao tác` và liên hệ hỗ trợ  |
| Released PO exists          | Both      | `Đơn đặt hàng đã được phát hành nên không thể sửa trực tiếp số lượng này.`                                     | `Mở quy trình điều chỉnh`                 |
| Capability denied           | Both      | `Bạn không có quyền thực hiện thao tác này. Chưa có dữ liệu nào được lưu.`                                     | `Xem quyền cần có`                        |
| Scope denied                | Both      | `Dòng này nằm ngoài phạm vi bạn được phân công. Chưa có dữ liệu nào được lưu.`                                 | `Chọn lại phạm vi` hoặc liên hệ quản lý   |
| Retryable concurrency       | Both      | `Hệ thống đang xử lý thay đổi khác cho cùng dữ liệu. Chưa có kết quả lưu. Hãy thử lại đúng yêu cầu này.`       | `Thử lại đúng yêu cầu vừa gửi`            |
| Ambiguous transport         | Both      | `Chưa xác định được kết quả lưu do kết nối bị gián đoạn. Không gửi một yêu cầu mới.`                           | `Kiểm tra kết quả lưu`                    |
| Session expiry              | Both      | `Phiên đăng nhập đã hết hạn. Thay đổi chưa được gửi hoặc chưa xác định được kết quả.`                          | `Đăng nhập lại` rồi kiểm tra kết quả      |

## 5. Complete Vietnamese copy examples

These examples are complete dialog/banner content, not isolated labels.

### 5.1 Initial quantity review

**Title:** `Rà soát số lượng nhu cầu`

**Body:** `Hãy kiểm tra nhu cầu tính toán, nhu cầu vận hành và bước đặt hàng trước khi xác nhận. Dữ liệu hiện tại chưa được thay đổi.`

**Action:** `Xem nguồn và cách tính`

### 5.2 Quantity changed from calculated need

**Title:** `Nhu cầu xác nhận khác nhu cầu tính toán`

**Body:** `Nhu cầu tính toán là 2,03 kg. Bạn đang đề xuất xác nhận 2,10 kg. Chưa có dữ liệu nào được lưu. Hãy nhập lý do điều chỉnh trước khi xem trước.`

**Action:** `Nhập lý do điều chỉnh`

### 5.3 Rounding preview

**Title:** `Xem trước số lượng đề xuất đặt mua`

**Body:** `Nhu cầu đã xác nhận: 2,01 kg. Bước đặt hàng: 0,1 kg. Quy tắc: Làm tròn lên theo bước đặt hàng. Số lượng đề xuất đặt mua: 2,10 kg. Chênh lệch do làm tròn: +0,09 kg. Phương án này chưa được lưu.`

**Action:** `Tiếp tục xem xét`

### 5.4 Rounding would produce an invalid result

**Title:** `Kết quả làm tròn không hợp lệ`

**Body:** `Số lượng đề xuất đặt mua 2,00 kg thấp hơn nhu cầu đã xác nhận 2,01 kg. Chưa có dữ liệu nào được lưu. Không tiếp tục xác nhận; hãy báo người phụ trách quy tắc số lượng để kiểm tra.`

**Action:** `Xem chi tiết quy tắc`

### 5.5 Supplier-allocation preview

**Title:** `Xem trước phân bổ lại theo tỷ lệ`

**Body:** `Phương pháp: Giữ nguyên tỷ lệ phân bổ hiện tại. Số lượng mua đã xác nhận: 10,0 kg. Bước đặt hàng: 0,1 kg. Nhà cung cấp A: 3,3 kg; Nhà cung cấp B: 3,3 kg; Nhà cung cấp C: 3,4 kg. Có 3 dòng thay đổi. Phương án này chưa được lưu.`

**Action:** `Xem từng thay đổi`

### 5.6 Supplier residual explanation

**Title:** `Giải thích phần dư phân bổ`

**Body:** `Ba nhà cung cấp có tỷ lệ bằng nhau nên mỗi nhà cung cấp được tính 33,333… bước. Sau khi phân bổ 99 bước nguyên, còn dư 1 bước tương đương 0,1 kg. Theo thứ tự ưu tiên phần dư đang áp dụng, Nhà cung cấp C nhận bước còn lại. Giá trị sẽ lưu là 3,3 kg; 3,3 kg; và 3,4 kg.`

**Action:** `Đã hiểu`

### 5.7 Allocation below required total

**Title:** `Phương án chưa phân bổ đủ`

**Body:** `Số lượng mua đã xác nhận là 10,0 kg nhưng tổng đề xuất mới là 9,9 kg. Còn 0,1 kg chưa phân bổ. Chưa có dữ liệu nào được lưu. Hãy tăng một phần phân bổ theo bước 0,1 kg hoặc tính lại phương án.`

**Action:** `Tính lại phương án`

### 5.8 Allocation above required total

**Title:** `Phương án phân bổ vượt số lượng mua`

**Body:** `Số lượng mua đã xác nhận là 10,0 kg nhưng tổng đề xuất là 10,2 kg. Phương án vượt 0,2 kg. Chưa có dữ liệu nào được lưu. Hãy giảm các phần phân bổ hoặc tính lại phương án.`

**Action:** `Tính lại phương án`

### 5.9 Quantity changed after preview

**Title:** `Số lượng đã thay đổi`

**Body:** `Nhu cầu đã xác nhận hoặc quy tắc số lượng đã thay đổi sau khi lập phương án. Phương án đang xem chưa được lưu. Vui lòng tải lại dữ liệu và xem lại phương án phân bổ.`

**Action:** `Tải lại và lập phương án mới`

### 5.10 Save confirmation

**Title:** `Xác nhận phương án phân bổ`

**Body:** `Nhu cầu mua đã xác nhận: 10,0 kg. Bước đặt hàng: 0,1 kg. Nhà cung cấp A: 3,3 kg. Nhà cung cấp B: 3,3 kg. Nhà cung cấp C: 3,4 kg. Phần dư phân bổ: 0,1 kg. Nhà cung cấp nhận phần dư: Nhà cung cấp C. Các số lượng trên sẽ được lưu chính xác vào hệ thống và dùng để lập đơn đặt hàng.`

**Primary action:** `Xác nhận và lưu phương án phân bổ`

**Secondary action:** `Quay lại chỉnh sửa`

### 5.11 Save success

**Title:** `Đã lưu phương án phân bổ`

**Body:** `Hệ thống đã lưu 3 phần phân bổ theo đúng phương án xác nhận. Đang đọc lại dữ liệu để xác minh. Chưa phát hành đơn đặt hàng cho đến khi xác minh hoàn tất.`

### 5.12 Saved-and-verified result

**Title:** `Đã lưu và xác minh`

**Body:** `Dữ liệu đọc lại khớp hoàn toàn: Nhà cung cấp A 3,3 kg; Nhà cung cấp B 3,3 kg; Nhà cung cấp C 3,4 kg. Tổng phân bổ là 10,0 kg. Bạn có thể tiếp tục bước phát hành đơn đặt hàng khi các điều kiện khác đã sẵn sàng.`

**Action:** `Xem điều kiện phát hành đơn đặt hàng`

### 5.13 Persisted/readback mismatch

**Title:** `Dữ liệu lưu không khớp với kết quả xác minh`

**Body:** `Lệnh lưu đã trả về 10,0 kg nhưng dữ liệu đọc lại hiện là 9,9 kg. Không xác nhận lại và không phát hành chứng từ. Hãy mở lịch sử thao tác và liên hệ bộ phận hỗ trợ để kiểm tra.`

**Action:** `Xem lịch sử thao tác`

### 5.14 Permission denied

**Title:** `Không có quyền thực hiện`

**Body:** `Tài khoản của bạn không có quyền lưu nhu cầu đã xác nhận. Chưa có dữ liệu nào được lưu. Hãy liên hệ người quản lý quyền hoặc nhờ người có quyền thực hiện.`

**Action:** `Xem quyền cần có`

### 5.15 Scope denied

**Title:** `Ngoài phạm vi được phân công`

**Body:** `Trường / khách hàng này không thuộc phạm vi bạn được phân công. Chưa có dữ liệu nào được lưu. Hãy chọn phạm vi khác hoặc liên hệ người quản lý để kiểm tra phân công.`

**Action:** `Chọn lại phạm vi`

### 5.16 Uncertain write result

**Title:** `Chưa xác định được kết quả lưu`

**Body:** `Kết nối bị gián đoạn sau khi gửi yêu cầu nên chưa thể kết luận dữ liệu đã được lưu hay chưa. Không gửi một yêu cầu mới. Hãy kiểm tra kết quả theo mã thao tác và đọc lại dữ liệu trước khi thử lại.`

**Action:** `Kiểm tra kết quả lưu`

### 5.17 Expired session

**Title:** `Phiên đăng nhập đã hết hạn`

**Body:** `Không thể tiếp tục xác minh vì phiên đăng nhập đã hết hạn. Kết quả lưu có thể chưa xác định. Hãy đăng nhập lại, kiểm tra kết quả theo thao tác vừa gửi, rồi mới quyết định có cần thử lại hay không.`

**Action:** `Đăng nhập lại`

### 5.18 Released PO prevents modification

**Title:** `Không thể sửa vì đơn đặt hàng đã được phát hành`

**Body:** `Số lượng này đã được dùng trong đơn đặt hàng số PO-2026-0718-01. Hệ thống không thay đổi âm thầm dữ liệu đã phát hành. Hãy mở quy trình điều chỉnh hoặc hủy và phát hành phiên bản thay thế theo thẩm quyền.`

**Action:** `Mở quy trình điều chỉnh`

## 6. Vietnamese glossary

“Approved direction” means the wording is required or directly supported by this task. “Proposed for review” means business-language review is still required before implementation.

| Khái niệm nghiệp vụ                  | Canonical English contract term | Thuật ngữ giao diện tiếng Việt              | Nhãn ngắn               | Giải thích dài                                                                          | Không dùng                      | Cách gọi quan sát trong Retool          | Lý do chọn                                                             | Câu ví dụ                                           | Trạng thái phê duyệt                                          |
| ------------------------------------ | ------------------------------- | ------------------------------------------- | ----------------------- | --------------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------- |
| Kết quả nhu cầu ban đầu              | Raw Calculated Requirement      | Nhu cầu tính toán                           | Nhu cầu tính toán       | Kết quả tính từ nguồn nhu cầu và định mức nguyên liệu trước quyết định vận hành         | Số lượng; SL lý thuyết          | `SL LT`, `qty_theoretical`              | Phân biệt kết quả tính toán với giá trị đã xác nhận                    | `Nhu cầu tính toán là 2,034 kg.`                    | Định hướng đã thống nhất                                      |
| Lượng có ý nghĩa cho Lập nhu cầu     | Planning Operational Quantity   | Nhu cầu vận hành                            | Nhu cầu vận hành        | Lượng đã đưa về bước có ý nghĩa cho bộ phận Lập nhu cầu, chưa phải lượng mua            | Số lượng vận hành chung chung   | Master `SL`/orderable                   | Phân biệt bước của Lập nhu cầu với bước đặt hàng                       | `Nhu cầu vận hành là 2,03 kg.`                      | Proposed pending product-owner and operations-language review |
| Nhu cầu có thẩm quyền                | Confirmed Operational Need      | Nhu cầu đã xác nhận                         | Nhu cầu đã xác nhận     | Lượng đã được bộ phận Lập nhu cầu xác nhận theo phiên bản và lý do                      | Nhu cầu xác nhận; actual need   | `SL`, `qty_actual`                      | Cách gọi trạng thái đã hoàn tất, không nhầm với đầu vào đang chờ duyệt | `Nhu cầu đã xác nhận là 2,01 kg.`                   | Định hướng đã thống nhất                                      |
| Đơn vị tăng khi đặt mua              | Purchase Order Step             | Bước đặt hàng                               | Bước đặt hàng           | Mức tăng nhỏ nhất được phép khi đặt mua                                                 | Độ chính xác; bước làm tròn     | `order_step`                            | Gần với ngôn ngữ vận hành và nêu rõ hệ quả                             | `Bước đặt hàng là 0,1 kg.`                          | Định hướng đã thống nhất                                      |
| Quy tắc làm tròn                     | Upward Purchase Quantization    | Làm tròn lên theo bước đặt hàng             | Quy tắc làm tròn        | Chuyển nhu cầu đã xác nhận thành bội số mua hợp lệ, không thấp hơn nhu cầu              | Làm tròn                        | `ceil_to_step` bị ẩn                    | Nêu rõ hướng làm tròn và căn cứ                                        | `Quy tắc: Làm tròn lên theo bước đặt hàng.`         | Định hướng đã thống nhất                                      |
| Đề xuất đặt mua                      | Proposed Purchasable Quantity   | Số lượng đề xuất đặt mua                    | Đề xuất đặt mua         | Kết quả hệ thống đề xuất trước khi bộ phận Mua hàng xác nhận                            | Số lượng đề xuất đặt; orderable | `SL`, `qty_final_orderable`             | Nêu rõ hệ quả mua hàng                                                 | `Số lượng đề xuất đặt mua là 2,10 kg.`              | Đề xuất chờ duyệt                                             |
| Tổng lượng mua có thẩm quyền         | Confirmed Purchase Quantity     | Số lượng mua đã xác nhận                    | Lượng mua xác nhận      | Tổng lượng mua mà các phần phân bổ cho nhà cung cấp phải cộng đúng bằng                 | Tổng SL; nhu cầu mua            | Master `SL`                             | Phân biệt nhu cầu với cam kết mua                                      | `Số lượng mua đã xác nhận là 10,0 kg.`              | Định hướng đã thống nhất                                      |
| Tổng lượng đã phân bổ                | Current Allocated Quantity      | Số lượng đã phân bổ                         | Đã phân bổ              | Tổng các phần phân bổ cho nhà cung cấp hiện đang có hiệu lực                            | Tổng chia; split total          | `Tổng phân bổ`, `split_total`           | Tự nhiên và gắn với trạng thái                                         | `Số lượng đã phân bổ hiện là 9,9 kg.`               | Định hướng đã thống nhất                                      |
| Lượng của một nhà cung cấp           | Supplier Portion                | Số lượng phân bổ cho nhà cung cấp           | Phần phân bổ            | Số lượng chính xác dành cho một nhà cung cấp                                            | SL chia; split qty              | `SL chia`, `split_qty`                  | Bỏ viết tắt và nêu rõ đối tượng nhận                                   | `Phần phân bổ cho Nhà cung cấp A là 3,3 kg.`        | Định hướng đã thống nhất                                      |
| Phần còn thiếu chưa phân bổ          | Unallocated Balance             | Số lượng chưa phân bổ                       | Chưa phân bổ            | Phần của số lượng mua đã xác nhận nhưng chưa được giao cho nhà cung cấp                 | Delta; còn lại                  | `delta`, trạng thái `OK`                | Diễn đạt trực tiếp khoảng thiếu nghiệp vụ                              | `Còn 0,1 kg chưa phân bổ.`                          | Định hướng đã thống nhất                                      |
| Phần tăng do làm tròn                | Rounding Difference             | Chênh lệch do làm tròn                      | Chênh lệch làm tròn     | Hiệu có dấu giữa số lượng đề xuất đặt mua và nhu cầu đã xác nhận                        | Delta; làm tròn: 2,1            | Không thể hiện rõ                       | Giải thích nguyên nhân, không chỉ nêu kết quả                          | `Chênh lệch do làm tròn là +0,09 kg.`               | Định hướng đã thống nhất                                      |
| Phần dư theo bước                    | Residual Quantity               | Phần dư phân bổ                             | Phần dư                 | Số đơn vị theo bước còn lại sau khi tính các phần phân bổ tạm thời                      | Số lẻ; residual                 | Phần dư cuối dòng bị ẩn                 | Nêu rõ hệ quả riêng của phân bổ                                        | `Phần dư phân bổ là 0,1 kg.`                        | Định hướng đã thống nhất                                      |
| Tỷ trọng                             | Allocation Ratio                | Tỷ lệ phân bổ                               | Tỷ lệ                   | Tỷ lệ dùng để giải thích; không phải giá trị có thẩm quyền để quyết định số lượng       | Ratio; tỷ lệ chia               | `split_ratio`                           | Tự nhiên và giới hạn đúng nghĩa                                        | `Tỷ lệ phân bổ hiện tại là 33%.`                    | Định hướng đã thống nhất                                      |
| Tính lại theo tỷ lệ                  | Proportional Rebalancing        | Phân bổ lại theo tỷ lệ                      | Phân bổ lại             | Tính lại phần của từng nhà cung cấp nhưng giữ tỷ lệ hiện tại                            | Cân bằng; rebalance             | `Cân bằng`                              | Nêu rõ đối tượng và phương pháp                                        | `Xem trước phân bổ lại theo tỷ lệ.`                 | Đề xuất chờ duyệt                                             |
| Cách tính lần lượt cũ                | Sequential Fill/Cap Rebalancing | Phân bổ lần lượt theo số lượng đã nhập      | Phân bổ lần lượt        | Cách cũ giới hạn từng dòng theo thứ tự hiển thị; không phải mặc định được khuyến nghị   | Cân bằng                        | `Cân bằng`                              | Làm rõ ảnh hưởng của thứ tự dòng khi giải thích cách cũ                | `Phương thức cũ phân bổ lần lượt theo thứ tự dòng.` | Chỉ dùng để giải thích cách cũ                                |
| Kết quả đề xuất                      | Preview                         | Phương án xem trước                         | Xem trước               | Phương án do hệ thống tính, gắn với phiên bản và chưa được lưu                          | Preview; bản nháp kết quả       | Trạng thái cục bộ                       | Tự nhiên và nêu rõ chưa lưu                                            | `Phương án xem trước chưa được lưu.`                | Định hướng đã thống nhất                                      |
| Hộp thoại quyết định cuối            | Final Confirmation              | Xác nhận giá trị sẽ lưu                     | Xác nhận lưu            | Hiển thị mọi giá trị vận hành chính xác và hệ quả trước khi lưu                         | Submit; chấp nhận; xác nhận     | Thông báo chung                         | Nêu rõ hệ quả                                                          | `Các số lượng trên sẽ được lưu chính xác.`          | Định hướng đã thống nhất                                      |
| Thao tác lưu nhu cầu                 | Save Confirmed Need             | Lưu nhu cầu đã xác nhận                     | Lưu nhu cầu             | Lưu các giá trị đã được bộ phận Lập nhu cầu rà soát thông qua lệnh nghiệp vụ            | Lưu thay đổi                    | Khái niệm `Lưu actual need`             | Nêu rõ đối tượng                                                       | `Xác nhận và lưu nhu cầu đã xác nhận.`              | Đề xuất chờ duyệt                                             |
| Thao tác lưu phân bổ                 | Save Allocation Proposal        | Lưu phương án phân bổ                       | Lưu phân bổ             | Lưu chính xác các phần của nhà cung cấp đã gắn với phương án xem trước                  | Save NCC; submit                | `Đã lưu NCC`                            | Dùng đầy đủ tên đối tượng nghiệp vụ                                    | `Xác nhận và lưu phương án phân bổ.`                | Đề xuất chờ duyệt                                             |
| Đã ghi nhận                          | Saved                           | Đã lưu                                      | Đã lưu                  | Lệnh nghiệp vụ báo đã ghi dữ liệu nhưng bước đọc lại có thể còn đang chờ                | Success                         | `Đã lưu NCC`                            | Nêu kết quả mà không khẳng định quá mức về việc xác minh               | `Đã lưu; đang xác minh dữ liệu.`                    | Định hướng đã thống nhất                                      |
| Đã ghi nhận và đối chiếu             | Saved and Verified              | Đã lưu và xác minh                          | Đã xác minh             | Kết quả lệnh nghiệp vụ và dữ liệu đọc lại có thẩm quyền khớp hoàn toàn                  | `COMMAND_COMPLETED`             | Chưa có                                 | Phân biệt phản hồi ghi dữ liệu với bằng chứng đã đối chiếu             | `Đã lưu và xác minh.`                               | Định hướng đã thống nhất                                      |
| Phương án đã cũ                      | Stale Preview                   | Dữ liệu đã thay đổi                         | Cần lập lại             | Phiên bản hoặc quy tắc liên quan thay đổi sau khi xem trước nên không thể lưu           | Stale; lỗi phiên bản            | Không thể hiện rõ                       | Nói rõ điều đã xảy ra                                                  | `Dữ liệu đã thay đổi; hãy lập phương án mới.`       | Định hướng đã thống nhất                                      |
| Thử lại cùng ý định                  | Exact Retry                     | Thử lại đúng yêu cầu vừa gửi                | Thử lại đúng yêu cầu    | Chỉ lặp lại cùng yêu cầu đã đóng băng sau lỗi đồng thời có thể thử lại                  | Retry; gửi lại                  | Không thể hiện rõ                       | Ngăn tạo nhầm một ý định mới                                           | `Hãy thử lại đúng yêu cầu này.`                     | Đề xuất chờ duyệt                                             |
| Quyền thực hiện hành động            | Capability Denied               | Không có quyền thực hiện                    | Không có quyền          | Người dùng thiếu quyền cho hành động được yêu cầu                                       | `capability_denied`             | Không thể hiện rõ                       | Dùng ngôn ngữ nghiệp vụ, không đưa mã lỗi ra bề mặt chính              | `Bạn không có quyền lưu phương án này.`             | Định hướng đã thống nhất                                      |
| Phạm vi được phân công               | Scope Denied                    | Ngoài phạm vi được phân công                | Ngoài phạm vi           | Người dùng có thể có quyền hành động nhưng không có quyền với trường hoặc điểm này      | `scope_denied`                  | Không thể hiện rõ                       | Giải thích sự khác biệt và cách xử lý                                  | `Trường này nằm ngoài phạm vi được phân công.`      | Định hướng đã thống nhất                                      |
| Kết quả mạng chưa rõ                 | Ambiguous Transport             | Chưa xác định được kết quả lưu              | Chưa rõ kết quả         | Yêu cầu có thể đã đến hệ thống nên không được gửi mù một lệnh mới                       | `ambiguous_transport`           | Lỗi chung                               | Ngăn tạo ý định trùng                                                  | `Không gửi một yêu cầu mới trước khi kiểm tra.`     | Định hướng đã thống nhất                                      |
| Xung đột khi đọc lại                 | Readback Mismatch               | Dữ liệu lưu không khớp với kết quả xác minh | Không khớp              | Ảnh chụp dữ liệu trả về sau khi lưu khác với dữ liệu đọc lại có thẩm quyền              | `readback_mismatch`             | Chưa có                                 | Nêu đúng rủi ro vận hành                                               | `Không tiếp tục phát hành chứng từ.`                | Định hướng đã thống nhất                                      |
| Phiên làm việc không còn hợp lệ      | Session Expired                 | Phiên đăng nhập đã hết hạn                  | Hết phiên               | Cần đăng nhập lại và phải xác định kết quả đang chờ                                     | Lỗi xác thực                    | Không thể hiện rõ                       | Tự nhiên và có hướng xử lý                                             | `Đăng nhập lại rồi kiểm tra kết quả lưu.`           | Định hướng đã thống nhất                                      |
| Xung đột thao tác đồng thời          | Retryable Concurrency           | Dữ liệu đang được thao tác ở nơi khác       | Đang có thay đổi khác   | Cùng đối tượng nghiệp vụ đang có thao tác khác; có thể an toàn khi thử lại đúng yêu cầu | Retryable concurrency           | Không thể hiện rõ                       | Giải thích mà không dùng thuật ngữ kỹ thuật                            | `Hệ thống đang xử lý thay đổi khác.`                | Đề xuất chờ duyệt                                             |
| Phiên bản                            | Aggregate Version               | Phiên bản dữ liệu                           | Phiên bản               | Phiên bản của đối tượng nghiệp vụ được gắn với bước xem trước và lưu                    | Version ID                      | Hiển thị không nhất quán                | Khái niệm rõ với người dùng; giá trị kỹ thuật chỉ ở phần hỗ trợ        | `Phiên bản dữ liệu hiện tại: 4.`                    | Định hướng đã thống nhất                                      |
| Lượng đã phát hành trên đơn đặt hàng | PO Committed Quantity           | Số lượng đã cam kết trên đơn đặt hàng       | Lượng trên đơn đặt hàng | Số lượng chính xác trong phiên bản đơn đặt hàng đã phát hành                            | PO qty                          | `qty`                                   | Phân biệt cam kết với đề xuất                                          | `Đã cam kết 3,3 kg trên đơn đặt hàng.`              | Định hướng đã thống nhất                                      |
| Lượng giao theo cam kết              | Dispatch Committed Quantity     | Số lượng giao theo cam kết                  | Lượng giao cam kết      | Lượng phân bổ đã cam kết mà bộ phận Giao hàng sử dụng                                   | Dispatch qty                    | `qty` sau khi làm tròn lại              | Phân biệt cam kết với lượng xếp hoặc giao thực tế                      | `Số lượng giao theo cam kết là 10,0 kg.`            | Định hướng đã thống nhất                                      |
| Lượng đã xếp thực tế                 | Loaded Quantity                 | Số lượng đã xếp hàng                        | Đã xếp hàng             | Số lượng thực tế đã được xác nhận là đã xếp                                             | Loaded qty                      | Không có trong màn lập đơn              | Nêu đúng sự kiện thực hiện                                             | `Đã xếp hàng 9,9 kg.`                               | Định hướng đã thống nhất                                      |
| Lượng đã giao thực tế                | Delivered Quantity              | Số lượng đã giao                            | Đã giao                 | Số lượng thực tế đã được xác nhận là đã giao                                            | Delivered qty                   | Không có trong màn lập đơn              | Nêu đúng sự kiện thực hiện                                             | `Đã giao 9,8 kg.`                                   | Định hướng đã thống nhất                                      |
| Lịch sử truy vết                     | Audit Trail                     | Lịch sử thao tác                            | Lịch sử                 | Nội dung có thẩm quyền về người thao tác, thời gian, quy tắc, trước/sau và kết quả lệnh | Audit log                       | Trường người dùng/thời gian còn hạn chế | Quen thuộc và phù hợp công việc vận hành                               | `Xem lịch sử thao tác và lý do điều chỉnh.`         | Định hướng đã thống nhất                                      |

### 6.1 Reviewed terminology refinements

The Planning Operational Quantity label remains a product-language decision. PA-06D records the following comparison without declaring a final term:

| Thuật ngữ ứng viên          | Ý nghĩa                                                         | Cách hiểu nhầm có thể xảy ra                                           | Mức phù hợp với ngôn ngữ hiện tại của nhân viên        | Thuật ngữ khuyến nghị                       | Trạng thái phê duyệt                                          |
| --------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------- | ------------------------------------------------------------- |
| `Nhu cầu vận hành`          | Nhu cầu sau khi áp dụng bước có ý nghĩa cho bộ phận Lập nhu cầu | Có thể bị hiểu là nhu cầu đã có hiệu lực hoặc là lượng cần đặt mua     | Ngắn gọn; mức phù hợp cần được người vận hành xác nhận | Khuyến nghị tạm thời                        | Proposed pending product-owner and operations-language review |
| `Nhu cầu đề xuất xác nhận`  | Nhu cầu đang được đề xuất để người có thẩm quyền xác nhận       | Có thể bị hiểu là nhu cầu đã được xác nhận hoặc là tên một trạng thái  | Nêu rõ đang chờ quyết định nhưng dài hơn               | Phương án thay thế để rà soát trên màn hình | Pending product-owner and operations-language review          |
| `Số lượng đề xuất xác nhận` | Số lượng được đề xuất để xác nhận                               | Không nêu rõ đó là nhu cầu; dễ lẫn với số lượng mua hoặc số lượng giao | Cấu trúc quen thuộc nhưng thiếu đối tượng nghiệp vụ    | Không khuyến nghị nếu thiếu tên đối tượng   | Pending product-owner and operations-language review          |

The working recommendation does not become final until the product owner and Vietnamese-speaking operations reviewer record an explicit decision.

| Hướng hiện tại/bằng chứng | Thuật ngữ đề xuất cuối               | Lý do                                                                       | Màn hình bị ảnh hưởng                     | Trạng thái phê duyệt     |
| ------------------------- | ------------------------------------ | --------------------------------------------------------------------------- | ----------------------------------------- | ------------------------ |
| `Nhu cầu xác nhận`        | `Nhu cầu đã xác nhận`                | Diễn đạt trạng thái có thẩm quyền đã hoàn tất, không phải đầu vào chờ duyệt | Tiêu đề và xác nhận của hai bàn làm việc  | Định hướng đã thống nhất |
| `Số lượng đề xuất đặt`    | `Số lượng đề xuất đặt mua`           | Nêu rõ hệ quả thuộc Mua hàng                                                | Bảng và phần xem trước của bàn làm việc A | Đề xuất chờ duyệt        |
| `Chênh lệch làm tròn`     | `Chênh lệch do làm tròn`             | Nêu nguyên nhân theo cách tự nhiên                                          | Hai bàn làm việc và lịch sử               | Định hướng đã thống nhất |
| Retool `SL`, `SL chia`    | Nhãn đầy đủ theo từng nghĩa số lượng | Tránh nhập nhằng và viết tắt                                                | Tất cả bảng và chứng từ                   | Định hướng đã thống nhất |
| Retool `Cân bằng`         | `Xem trước phân bổ lại theo tỷ lệ`   | Nêu đối tượng, phương pháp và việc chưa lưu                                 | Bàn làm việc B                            | Đề xuất chờ duyệt        |
| `Đã lưu NCC`              | `Đã lưu phương án phân bổ`           | Nêu đúng tên đối tượng nghiệp vụ đã lưu                                     | Kết quả của bàn làm việc B                | Đề xuất chờ duyệt        |

## 7. Language QA matrix

These are separate statuses and must not be collapsed into one final “Pass”:

- **Document language QA:** Passed
- **Product-owner terminology approval:** Pending
- **Rendered operations review:** Pending

Codes: V=Vietnamese-only; N=natural Vietnamese; B=correct business meaning; T=consistent term; O=clear affected object; A=clear action; C=clear consequence; R=clear recovery; L=correct decimal/date locale; X=no unexplained acronym; E=no raw enum primary text; D=no literal translation. The V–D results apply only to the written specification after correction. They do not close the two pending acceptance fields.

| Proposed screen/surface              | V    | N    | B    | T    | O    | A    | C    | R    | L    | X    | E    | D    | Product-owner terminology | Rendered operations review |
| ------------------------------------ | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ------------------------- | -------------------------- |
| Requirement queue/table              | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |
| Requirement source/detail drawer     | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |
| Quantity preview and confirmation    | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |
| Allocation comparison table          | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |
| Rebalancing preview and confirmation | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |
| Save result/readback banner          | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |
| Audit/history drawer                 | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pending                   | Pending                    |

### 7.1 Failures found and corrections applied

| Failure                                                                                     | Failed checks       | Correction                                                                      |
| ------------------------------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------- |
| Prototype/Retool labels included `SL`, `SL chia`, `delta`, `Loaded`, and generic `Cân bằng` | V, N, B, T, O, X, D | Replaced with quantity-specific Vietnamese terms and an explicit preview action |
| `Nhu cầu xác nhận` could mean input or completed state                                      | B, T                | Standardized on `Nhu cầu đã xác nhận`                                           |
| Generic `Lưu thay đổi`, `Xác nhận`, and `Chấp nhận` did not state consequence               | O, A, C             | Actions now name the exact object and persistence consequence                   |
| Raw technical states/error codes could become primary chips                                 | V, N, E             | Mapped each to business wording; support detail alone may show the code         |
| Existing errors did not state whether a write occurred or what to do                        | C, R                | Every error example now answers what happened, save certainty and next action   |
| PO one-decimal formatter could hide persisted digits                                        | B, L                | Contract requires step-derived digits and exact WYSIWYG values                  |
| ISO dates and decimal points could leak from technical payloads                             | L                   | Operator presentation uses `dd/mm/yyyy` and decimal commas                      |
| Residual behavior was hidden behind technical row order                                     | B, C                | Preview names residual ticks, recipient and visible business priority           |

Implementation cannot claim language acceptance until a Vietnamese-speaking operations reviewer repeats this matrix on rendered screens and records any revised term in the glossary and decision register.
