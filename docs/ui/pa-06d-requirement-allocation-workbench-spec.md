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

## 3. Workbench B — Phân bổ nhà cung cấp và phân bổ lại

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
Tổng số bước phân bổ: 100
Nguyên tắc phân bổ phần dư: Theo thứ tự ưu tiên phần dư đã hiển thị
Nhà cung cấp nhận phần dư: Nhà cung cấp C
Số dòng thêm mới: 0
Số dòng thay đổi: 3
Số dòng loại khỏi phương án: 0
```

It then lists every exact current/proposed portion and tick count. It exposes the complete residual-recipient order when more than one supplier has equal fractional entitlement. It does not use row position or supplier ID as an unexplained tie-break.

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

| Business concept              | Canonical English contract term | Approved Vietnamese UI term                 | Short label             | Long explanation                                                                  | Terms not to use                | Retool wording observed       | Reason for final choice                                               | Example sentence                                    | Approval status                        |
| ----------------------------- | ------------------------------- | ------------------------------------------- | ----------------------- | --------------------------------------------------------------------------------- | ------------------------------- | ----------------------------- | --------------------------------------------------------------------- | --------------------------------------------------- | -------------------------------------- |
| Raw demand result             | Raw Calculated Requirement      | Nhu cầu tính toán                           | Nhu cầu tính toán       | Kết quả tính từ nguồn nhu cầu và quy tắc/BOM trước quyết định vận hành            | Số lượng; SL lý thuyết          | `SL LT`, `qty_theoretical`    | Distinguishes calculation from confirmation                           | `Nhu cầu tính toán là 2,034 kg.`                    | Approved direction                     |
| Meaningful Planning amount    | Planning Operational Quantity   | Nhu cầu vận hành                            | Nhu cầu vận hành        | Lượng đã đưa về bước có ý nghĩa cho Planning, chưa phải lượng mua                 | Số lượng vận hành chung chung   | Master `SL`/orderable         | Separates Planning precision from purchase step                       | `Nhu cầu vận hành là 2,03 kg.`                      | Approved direction; exact step pending |
| Planning authoritative need   | Confirmed Operational Need      | Nhu cầu đã xác nhận                         | Nhu cầu đã xác nhận     | Lượng Planning đã xác nhận theo phiên bản và lý do                                | Nhu cầu xác nhận; actual need   | `SL`, `qty_actual`            | Completed-state wording is unambiguous                                | `Nhu cầu đã xác nhận là 2,01 kg.`                   | Approved direction                     |
| Purchase quantum              | Purchase Order Step             | Bước đặt hàng                               | Bước đặt hàng           | Mức tăng nhỏ nhất được phép khi đặt mua                                           | Precision; step; bước làm tròn  | `order_step`                  | Familiar operational term and consequence                             | `Bước đặt hàng là 0,1 kg.`                          | Approved direction                     |
| Rounding rule                 | Upward Purchase Quantization    | Làm tròn lên theo bước đặt hàng             | Quy tắc làm tròn        | Chuyển nhu cầu đã xác nhận thành bội số mua hợp lệ và không thấp hơn nhu cầu      | Làm tròn                        | `ceil_to_step` hidden         | States direction and basis                                            | `Quy tắc: Làm tròn lên theo bước đặt hàng.`         | Approved direction                     |
| Purchase proposal             | Proposed Purchasable Quantity   | Số lượng đề xuất đặt mua                    | Đề xuất đặt mua         | Kết quả backend đề xuất trước khi Procurement xác nhận                            | Số lượng đề xuất đặt; orderable | `SL`, `qty_final_orderable`   | Names the purchasing consequence                                      | `Số lượng đề xuất đặt mua là 2,10 kg.`              | Proposed refinement                    |
| Purchase authoritative total  | Confirmed Purchase Quantity     | Số lượng mua đã xác nhận                    | Lượng mua xác nhận      | Tổng purchasable quantity that allocations must equal                             | Tổng SL; nhu cầu mua            | Master `SL`                   | Distinguishes need from purchase commitment                           | `Số lượng mua đã xác nhận là 10,0 kg.`              | Approved direction                     |
| Current allocation sum        | Current Allocated Quantity      | Số lượng đã phân bổ                         | Đã phân bổ              | Tổng các phần nhà cung cấp hiện đang có hiệu lực                                  | Tổng chia; split total          | `Tổng phân bổ`, `split_total` | Natural and state-specific                                            | `Số lượng đã phân bổ hiện là 9,9 kg.`               | Approved direction                     |
| Supplier line amount          | Supplier Portion                | Số lượng phân bổ cho nhà cung cấp           | Phần phân bổ            | Số lượng chính xác dành cho một nhà cung cấp                                      | SL chia; split qty              | `SL chia`, `split_qty`        | Replaces abbreviation and names recipient                             | `Phần phân bổ cho Nhà cung cấp A là 3,3 kg.`        | Approved direction                     |
| Missing allocation            | Unallocated Balance             | Số lượng chưa phân bổ                       | Chưa phân bổ            | Phần confirmed purchase quantity chưa được gán cho supplier                       | Delta; còn lại                  | `delta`, trạng thái `OK`      | Expresses business gap directly                                       | `Còn 0,1 kg chưa phân bổ.`                          | Approved direction                     |
| Purchase rounding increase    | Rounding Difference             | Chênh lệch do làm tròn                      | Chênh lệch làm tròn     | Difference between proposed purchase and confirmed need, with sign                | Delta; làm tròn: 2,1            | Not explicit                  | Explains cause, not just result                                       | `Chênh lệch do làm tròn là +0,09 kg.`               | Approved direction                     |
| Leftover ticks                | Residual Quantity               | Phần dư phân bổ                             | Phần dư                 | Whole ticks left after provisional allocation                                     | Số lẻ; residual                 | Final-row hidden remainder    | Names allocation-specific consequence                                 | `Phần dư phân bổ là 0,1 kg.`                        | Approved direction                     |
| Share                         | Allocation Ratio                | Tỷ lệ phân bổ                               | Tỷ lệ                   | Derived explanatory proportion; does not author quantity                          | Ratio; tỷ lệ chia               | `split_ratio`                 | Natural, bounded meaning                                              | `Tỷ lệ phân bổ hiện tại là 33%.`                    | Approved direction                     |
| Recalculation                 | Proportional Rebalancing        | Phân bổ lại theo tỷ lệ                      | Phân bổ lại             | Recalculate supplier portions while preserving current proportions                | Cân bằng; rebalance             | `Cân bằng`                    | Names object and method                                               | `Xem trước phân bổ lại theo tỷ lệ.`                 | Proposed refinement                    |
| Sequential legacy action      | Sequential Fill/Cap Rebalancing | Phân bổ lần lượt theo số lượng đã nhập      | Phân bổ lần lượt        | Legacy method that caps rows in visible order; not recommended production default | Cân bằng                        | `Cân bằng`                    | Makes row-order behavior explicit if ever shown in legacy explanation | `Phương thức cũ phân bổ lần lượt theo thứ tự dòng.` | Legacy explanation only                |
| Proposed result               | Preview                         | Phương án xem trước                         | Xem trước               | Backend-calculated, version-bound proposal that is not yet saved                  | Preview; bản nháp kết quả       | Local state                   | Natural and explicit non-persistence                                  | `Phương án xem trước chưa được lưu.`                | Approved direction                     |
| Final decision dialog         | Final Confirmation              | Xác nhận giá trị sẽ lưu                     | Xác nhận lưu            | Shows every exact operational value and consequence before commit                 | Submit; chấp nhận; xác nhận     | Generic notifications         | Names consequence                                                     | `Các số lượng trên sẽ được lưu chính xác.`          | Approved direction                     |
| Persist action                | Save Confirmed Need             | Lưu nhu cầu đã xác nhận                     | Lưu nhu cầu             | Persists the exact reviewed Planning values through a command                     | Lưu thay đổi                    | `Lưu actual need` concept     | Names object                                                          | `Xác nhận và lưu nhu cầu đã xác nhận.`              | Proposed refinement                    |
| Persist allocation            | Save Allocation Proposal        | Lưu phương án phân bổ                       | Lưu phân bổ             | Persists exact preview-bound supplier portions                                    | Save NCC; submit                | `Đã lưu NCC`                  | Uses full business object                                             | `Xác nhận và lưu phương án phân bổ.`                | Proposed refinement                    |
| Persisted                     | Saved                           | Đã lưu                                      | Đã lưu                  | Command reports a persisted result but readback may still be pending              | Success                         | `Đã lưu NCC`                  | Clear outcome without overclaiming verification                       | `Đã lưu; đang xác minh dữ liệu.`                    | Approved direction                     |
| Persisted and checked         | Saved and Verified              | Đã lưu và xác minh                          | Đã xác minh             | Command result and authorized readback match exactly                              | COMMAND_COMPLETED               | Not present                   | Separates write response from proof                                   | `Đã lưu và xác minh.`                               | Approved direction                     |
| Outdated proposal             | Stale Preview                   | Dữ liệu đã thay đổi                         | Cần lập lại             | Relevant version/rule changed after preview; cannot commit                        | Stale; lỗi phiên bản            | Not explicit                  | Tells operator what happened                                          | `Dữ liệu đã thay đổi; hãy lập phương án mới.`       | Approved direction                     |
| Safe same-intent retry        | Exact Retry                     | Thử lại đúng yêu cầu vừa gửi                | Thử lại đúng yêu cầu    | Repeat only the same frozen request after a retryable concurrency result          | Retry; gửi lại                  | Not explicit                  | Prevents accidental new intent                                        | `Hãy thử lại đúng yêu cầu này.`                     | Proposed for review                    |
| Capability authorization      | Capability Denied               | Không có quyền thực hiện                    | Không có quyền          | Actor lacks the required action permission                                        | capability_denied               | Not explicit                  | Business wording, no code                                             | `Bạn không có quyền lưu phương án này.`             | Approved direction                     |
| Scope authorization           | Scope Denied                    | Ngoài phạm vi được phân công                | Ngoài phạm vi           | Actor may have capability but not for this site/destination                       | scope_denied                    | Not explicit                  | Explains distinction and recovery                                     | `Trường này nằm ngoài phạm vi được phân công.`      | Approved direction                     |
| Uncertain network outcome     | Ambiguous Transport             | Chưa xác định được kết quả lưu              | Chưa rõ kết quả         | Request may have reached backend; no blind new command                            | ambiguous_transport             | Generic error                 | Prevents duplicate intent                                             | `Không gửi một yêu cầu mới trước khi kiểm tra.`     | Approved direction                     |
| Readback conflict             | Readback Mismatch               | Dữ liệu lưu không khớp với kết quả xác minh | Không khớp              | Returned persisted snapshot differs from authorized readback                      | readback_mismatch               | Not present                   | States the exact operational risk                                     | `Không tiếp tục phát hành chứng từ.`                | Approved direction                     |
| Session invalid               | Session Expired                 | Phiên đăng nhập đã hết hạn                  | Hết phiên               | Reauthentication required; pending outcome must be resolved                       | Auth error                      | Not explicit                  | Natural and actionable                                                | `Đăng nhập lại rồi kiểm tra kết quả lưu.`           | Approved direction                     |
| Command/aggregate concurrency | Retryable Concurrency           | Dữ liệu đang được thao tác ở nơi khác       | Đang có thay đổi khác   | Same aggregate has concurrent work; exact retry may be safe                       | retryable concurrency           | Not explicit                  | Explains without technical jargon                                     | `Hệ thống đang xử lý thay đổi khác.`                | Proposed for review                    |
| Version                       | Aggregate Version               | Phiên bản dữ liệu                           | Phiên bản               | Version of the owned business aggregate bound to preview/commit                   | Version ID                      | Not consistently shown        | Clear operator concept; technical value secondary                     | `Phiên bản dữ liệu hiện tại: 4.`                    | Approved direction                     |
| PO released fact              | PO Committed Quantity           | Số lượng đã cam kết trên đơn đặt hàng       | Lượng trên đơn đặt hàng | Exact quantity in released supplier PO revision                                   | PO qty                          | `qty`                         | Distinguishes commitment from proposal                                | `Đã cam kết 3,3 kg trên đơn đặt hàng.`              | Approved direction                     |
| Dispatch committed fact       | Dispatch Committed Quantity     | Số lượng giao theo cam kết                  | Lượng giao cam kết      | Exact committed allocation consumed by Dispatch                                   | Dispatch qty                    | `qty` after re-ceiling        | Separates commitment from physical load/delivery                      | `Số lượng giao theo cam kết là 10,0 kg.`            | Approved direction                     |
| Physical load                 | Loaded Quantity                 | Số lượng đã xếp hàng                        | Đã xếp hàng             | Quantity physically confirmed as loaded                                           | Loaded qty                      | Not in planner                | Execution fact                                                        | `Đã xếp hàng 9,9 kg.`                               | Approved direction                     |
| Physical delivery             | Delivered Quantity              | Số lượng đã giao                            | Đã giao                 | Quantity physically confirmed delivered                                           | Delivered qty                   | Not in planner                | Execution fact                                                        | `Đã giao 9,8 kg.`                                   | Approved direction                     |
| Trace history                 | Audit Trail                     | Lịch sử thao tác                            | Lịch sử                 | Authorized account of actor, time, rule, before/after and command outcome         | Audit log                       | Limited user/time fields      | Familiar and operational                                              | `Xem lịch sử thao tác và lý do điều chỉnh.`         | Approved direction                     |

### 6.1 Reviewed terminology refinements

| Current direction/evidence | Final proposed term                | Reason                                                                  | Affected screens                        | Approval status     |
| -------------------------- | ---------------------------------- | ----------------------------------------------------------------------- | --------------------------------------- | ------------------- |
| `Nhu cầu xác nhận`         | `Nhu cầu đã xác nhận`              | Expresses completed authoritative state, not an input awaiting decision | Workbench A/B headers and confirmations | Approved direction  |
| `Số lượng đề xuất đặt`     | `Số lượng đề xuất đặt mua`         | Identifies Procurement consequence                                      | Workbench A table/preview               | Proposed refinement |
| `Chênh lệch làm tròn`      | `Chênh lệch do làm tròn`           | States cause naturally                                                  | Both workbenches and audit              | Approved direction  |
| Retool `SL`, `SL chia`     | Full quantity-specific labels      | Avoids ambiguity and abbreviations                                      | All tables/documents                    | Approved direction  |
| Retool `Cân bằng`          | `Xem trước phân bổ lại theo tỷ lệ` | Names object, method and non-persisted action                           | Workbench B                             | Proposed refinement |
| `Đã lưu NCC`               | `Đã lưu phương án phân bổ`         | Names the saved business object                                         | Workbench B result                      | Proposed refinement |

## 7. Language QA matrix

Codes: V=Vietnamese-only; N=natural Vietnamese; B=correct business meaning; T=consistent term; O=clear affected object; A=clear action; C=clear consequence; R=clear recovery; L=correct decimal/date locale; X=no unexplained acronym; E=no raw enum primary text; D=no literal translation. Results are after corrections.

| Proposed screen/surface              | V    | N    | B    | T    | O    | A    | C    | R    | L    | X    | E    | D    |
| ------------------------------------ | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Requirement queue/table              | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Requirement source/detail drawer     | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Quantity preview and confirmation    | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Allocation comparison table          | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Rebalancing preview and confirmation | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Save result/readback banner          | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Audit/history drawer                 | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |

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
