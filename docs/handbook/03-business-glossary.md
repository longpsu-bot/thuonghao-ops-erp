# OPS ERP Handbook

## 03 — Business Glossary

**Document ID:** OPS-HANDBOOK-003  
**Version:** 0.1  
**Status:** Draft  
**Owner:** Architecture Function  
**Applies to:** Business documentation, API contracts, database naming, frontend labels, Codex tasks

---

## 1. Purpose

This glossary defines the official language of OPS ERP.

Every business process, module specification, database design, API contract, UI label, and Codex task should use these terms consistently unless a later approved decision supersedes this document.

The goal is to prevent ambiguity between business operations, software concepts, and legacy OPS v1 terminology.

---

## 2. Documentation language policy

### 2.1 Authoritative language

English is the authoritative language for architecture, engineering, API contracts, database design, Codex instructions, and implementation documentation.

Reason:

- Codex and most software engineering tools work best with English technical language.
- Future external software companies can onboard faster with English architecture and code documentation.
- PostgreSQL, TypeScript, React, Supabase, testing tools, and package documentation are English-first.
- English reduces ambiguity in technical naming.

### 2.2 Vietnamese usage

Vietnamese should be used selectively where it improves business adoption.

Vietnamese is appropriate for:

- business-facing labels;
- staff workflow guides;
- training materials;
- printed operational forms;
- customer-facing wording;
- Vietnamese regulatory or administrative content;
- selected glossary translations.

### 2.3 No full duplicate translation by default

The project should not fully translate every architecture document into Vietnamese by default.

Full duplicate translation creates maintenance risk because English and Vietnamese versions can drift.

Instead, OPS ERP should maintain:

- one authoritative English document;
- Vietnamese labels or summaries only when they are operationally useful;
- bilingual terminology tables for important business terms.

### 2.4 UI language

The production user interface may use Vietnamese labels for staff users, while the underlying code, database, API contracts, and developer documentation remain English.

---

## 3. Language principles

### 3.1 One term, one meaning

A term should not mean different things in different modules.

For example, `requirement` means derived ingredient need. It does not mean customer demand, purchase order quantity, or dispatch quantity.

### 3.2 Business term before technical term

Technical names should follow business concepts.

For example, the system should model `demand`, `requirement`, `purchase order`, and `dispatch document` before deciding table or component names.

### 3.3 Avoid legacy ambiguity

Legacy terms from OPS v1 may remain in adapters, but OPS ERP should use the glossary terms as the target language.

---

## 4. Core glossary

| English term | Vietnamese label | Definition |
|---|---|---|
| Company | Công ty | The operating company using OPS ERP. |
| Customer | Khách hàng | An organization or person receiving goods or services. |
| School | Trường học | A customer or location receiving catering service. |
| Delivery Location | Điểm giao hàng | A physical place where goods are delivered. |
| Supplier | Nhà cung ứng | External party providing ingredients or goods. |
| User | Người dùng | A person using OPS ERP. |
| Role | Vai trò | A permission category assigned to a user. |
| Ingredient | Nguyên liệu | A purchasable or usable food/material item. |
| Unit | Đơn vị tính | Measurement or counting unit. |
| Purchase Unit | Đơn vị mua hàng | Unit used when ordering from a supplier. |
| Dish | Món ăn | Menu item served in catering. |
| Dish Type | Nhóm món | Menu planning classification such as soup, main dish, vegetable, dessert, beverage, or snack. |
| Recipe | Công thức | Definition of how to produce or serve a dish using ingredients. |
| Recipe Version | Phiên bản công thức | Specific approved version of a recipe used for calculation. |
| Recipe Line | Dòng công thức | One ingredient and quantity relationship inside a recipe version. |
| Demand | Nhu cầu khách hàng | Customer-facing request for goods or services. |
| Demand Source | Nguồn nhu cầu | Origin of demand, such as catering menu or wholesale order. |
| Demand Document | Chứng từ nhu cầu | Document-like container for demand lines. |
| Demand Line | Dòng nhu cầu | Single requested item inside a demand document. |
| Catering Demand | Nhu cầu suất ăn | Demand created from school menus, attendance, portions, and dishes. |
| Wholesale Demand | Nhu cầu bán nguyên liệu | Demand created from direct ingredient orders. |
| Manual Demand | Nhu cầu nhập tay | Demand entered directly by staff outside normal workflows. |
| Pantry Add | Bổ sung nhanh | Operational ingredient addition for quick adjustment or correction. |
| Service Date | Ngày phục vụ | Date on which catering service is delivered or consumed. |
| Delivery Date | Ngày giao hàng | Date on which goods are delivered. |
| Menu Plan | Kế hoạch thực đơn | Planned assignment of dishes to schools/customers and service dates. |
| Attendance | Số lượng ăn | Actual or expected count used for catering calculation. |
| Requirement | Nhu cầu nguyên liệu | Internal ingredient need derived from demand. |
| Raw Requirement | Nhu cầu nguyên liệu thô | First calculated requirement before adjustments and rounding. |
| Effective Requirement | Nhu cầu nguyên liệu hiệu lực | Requirement after adjustments, substitutions, removals, and overrides. |
| Final Requirement | Nhu cầu nguyên liệu chốt | Quantity accepted for operational planning after review. |
| Orderable Requirement | Nhu cầu có thể đặt hàng | Quantity transformed for procurement according to rounding and purchasing rules. |
| Requirement Line | Dòng nhu cầu nguyên liệu | One ingredient requirement line with source lineage. |
| Source Lineage | Truy vết nguồn gốc | Trace explaining where a requirement came from. |
| Effective Line Key | Khóa dòng hiệu lực | Stable identifier for an effective requirement line. |
| Adjustment | Điều chỉnh | Controlled change applied to demand or requirement. |
| Structural Adjustment | Điều chỉnh cấu trúc | Change that alters requirement generation structure. |
| Quantity Override | Ghi đè số lượng | Quantity change that does not redefine the permanent recipe. |
| Substitution | Thay thế | Replacement of one ingredient or requirement with another. |
| One-Order Substitution | Thay thế theo đơn | Substitution limited to a specific order/date/school/context. |
| Recurring Recipe Variation | Biến thể công thức định kỳ | Stable recurring customer/school-specific recipe variation. |
| Removal | Loại bỏ | Suppression/removal of an ingredient requirement. |
| Add-On | Bổ sung | Additional ingredient requirement beyond the normal calculated result. |
| Adjustment Reference | Mã tham chiếu điều chỉnh | Shared identifier linking related adjustment records. |
| Calculation | Tính toán | Process converting demand and business facts into requirements. |
| Calculation Run | Lần tính toán | Specific execution of the calculation process. |
| Calculation Version | Phiên bản tính toán | Version of calculation logic or rule set. |
| Recipe Explosion | Bung công thức | Conversion of dish demand into ingredient requirements. |
| Unit Normalization | Chuẩn hóa đơn vị | Conversion of quantities into compatible units. |
| Aggregation | Tổng hợp | Combining compatible requirement lines. |
| Rounding | Làm tròn | Converting calculated quantity into operational quantity. |
| Procurement Rounding | Làm tròn mua hàng | Rounding applied to create supplier-orderable quantities. |
| Warning | Cảnh báo | Non-blocking issue detected during calculation or review. |
| Blocking Error | Lỗi chặn | Issue that prevents workflow release. |
| Procurement | Thu mua | Process deciding what to buy, from whom, and in what quantity. |
| Supplier Eligibility | Điều kiện NCC | Rule or relationship indicating supplier can provide an ingredient. |
| Supplier Assignment | Phân bổ NCC | Assignment of requirement to supplier. |
| Supplier Split | Tách NCC | Requirement split across more than one supplier. |
| Purchase Plan | Kế hoạch mua hàng | Draft procurement plan before release. |
| Purchase Order | Đơn đặt hàng | Released commitment to purchase goods from supplier. |
| Purchase Order Line | Dòng đơn đặt hàng | Single ingredient/quantity/unit/price line in a purchase order. |
| Receiving | Nhận hàng | Recording goods received from suppliers. |
| Fulfilment | Thực hiện giao hàng | Preparation, packing, dispatch, delivery, and confirmation process. |
| Preparation | Chuẩn bị | Operational step before dispatch. |
| Picking | Soạn hàng | Selecting goods for customer/school/dispatch. |
| Packing | Đóng gói | Packaging picked goods for dispatch. |
| Dispatch | Xuất/giao hàng | Sending goods to a delivery location. |
| Dispatch Document | Phiếu xuất/giao hàng | Released operational document recording what should be dispatched. |
| Dispatch Line | Dòng phiếu xuất/giao hàng | Single line inside a dispatch document. |
| Delivery Confirmation | Xác nhận giao hàng | Evidence or record that goods were delivered. |
| Shortage | Thiếu hàng | Delivered/prepared/available quantity is less than required quantity. |
| Return | Hàng trả | Goods returned from customer, school, driver, or delivery process. |
| Draft | Bản nháp | Non-final state that can still be changed. |
| Approved | Đã duyệt | State accepted for the next process. |
| Released | Đã phát hành | State where a document becomes a business commitment. |
| Frozen | Đã khóa | State/property protecting historical quantities and calculation context. |
| Correction | Điều chỉnh sau phát hành | Controlled change after release. |
| Cancellation | Hủy | Controlled action voiding a document without deleting history. |
| Revision | Phiên bản sửa đổi | New version created after an approved/released document changes. |
| Audit Record | Nhật ký kiểm soát | Record of who changed what, when, why, and from where. |
| Source of Truth | Nguồn dữ liệu chuẩn | Authoritative place where a business fact is owned. |
| Legacy Adapter | Bộ chuyển tiếp dữ liệu cũ | Controlled interface for reading selected OPS v1 data. |
| Migration | Chuyển đổi dữ liệu | Moving selected legacy data into OPS ERP target model. |
| Reference | Tham chiếu | Reading or pointing to legacy data without copying it immediately. |
| Transform | Chuyển đổi cấu trúc | Converting legacy data into a new target structure. |
| Archive | Lưu trữ | Keeping legacy data for history but not active operation. |
| Discard | Không chuyển | Intentionally not carrying a legacy object forward. |
| Handbook | Sổ tay hệ thống | Authoritative architecture and business documentation. |
| Decision Register | Sổ quyết định | Index of important accepted, superseded, or rejected decisions. |
| Business Rule Register | Sổ quy tắc nghiệp vụ | Authoritative list of business rules. |
| Open Questions Register | Sổ câu hỏi mở | List of unresolved business or architecture questions. |
| Codex Task | Nhiệm vụ Codex | Bounded implementation task for Codex. |
| Module | Phân hệ | Bounded area owning a specific business capability. |
| API Contract | Hợp đồng API | Documented agreement defining API input, output, validation, errors, permissions, and behavior. |
| Command | Lệnh nghiệp vụ | Backend-authoritative business operation that changes state. |
| Read Model | Mô hình dữ liệu đọc | Query-oriented representation for UI/reporting. |

---

## 5. Terms that must not be confused

### Demand vs Requirement

Demand is customer-facing. Requirement is internal ingredient need derived from demand.

### Requirement vs Purchase Order

Requirement says what the company needs. Purchase order says what the company commits to buy from a supplier.

### Effective Requirement vs Final Requirement

Effective requirement is the result after rules and adjustments. Final requirement is the reviewed quantity accepted for operation.

The exact boundary will be refined in the Calculation Specification.

### Substitution vs Recipe Change

A substitution affects a defined operational scope. A recipe change updates the permanent recipe definition or recipe version.

### Quantity Override vs Structural Adjustment

A quantity override changes quantity only. A structural adjustment changes what ingredient or requirement exists.

### Released vs Approved

Approved means accepted for the next step. Released means the document has become an operational commitment and must be protected from silent recalculation.

### Correction vs Deletion

A correction preserves history. Deletion removes data and should not be used for released operational records.

---

## 6. Naming implications

Database, API, and frontend module names should prefer English glossary terms.

Examples:

- `demand_documents`
- `demand_lines`
- `requirement_lines`
- `adjustments`
- `purchase_orders`
- `dispatch_documents`
- `calculation_runs`

Vietnamese names may appear in UI labels, exported forms, and staff-facing guides.

---

## 7. Open terminology questions

### OQ-GLOSSARY-001

Should staff-facing UI use Vietnamese only, or Vietnamese primary with English technical hints for power users?

### OQ-GLOSSARY-002

Should `Dispatch Document` be translated as `Phiếu xuất kho`, `Phiếu giao hàng`, or a context-specific label depending on whether inventory is active?

### OQ-GLOSSARY-003

Should `Requirement` be translated consistently as `Nhu cầu nguyên liệu`, or should staff-facing screens use simpler labels such as `Số lượng cần mua` depending on workflow?

---

## 8. Approval rule

New terms may be added to this glossary as the domain model evolves.

If a term affects module boundaries, database naming, API contracts, or business rules, it must also be reflected in the Decision Register or Business Rule Register where appropriate.
