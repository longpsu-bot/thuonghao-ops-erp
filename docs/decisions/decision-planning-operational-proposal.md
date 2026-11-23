# Decision D-046 — Ingredient-derived Planning Operational Proposal

**Status:** Accepted

**Date:** 23/09/2026

**Approval:** Product Owner, task authorization
`PLANNING-OPERATIONAL-PROPOSAL-01`.

## Quy tắc hiện hành và cách thay đổi (23/11/2026)

Quy tắc V1 áp dụng cho **đề xuất vận hành của phiếu nhu cầu lập mới**. Atlas cộng các nguồn của cùng dòng nhu cầu (cùng ngày, trường, điểm giao, nguyên liệu và đơn vị) rồi làm tròn tổng qua hai bước.

1. Làm tròn tổng lên đến bội số gần nhất của bước nguyên liệu (`Ingredient.order_step`).
2. Với **kg**, nếu kết quả bước 1 nhỏ hơn 2 kg, làm tròn đến một chữ số thập phân. Từ 2 kg trở lên, làm tròn đến số nguyên gần nhất. Với **các đơn vị khác**, làm tròn đến số nguyên gần nhất ở mọi mức. Atlas tính trên số thập phân chính xác và làm tròn lên tại điểm giữa.

| Nhu cầu gốc | Bước nguyên liệu | Sau bước 1 | Đề xuất |
| ----------: | ---------------: | ---------: | ------: |
|     1,21 kg |          0,25 kg |    1,25 kg |  1,3 kg |
|    1,21 lít |         0,25 lít |   1,25 lít |   1 lít |
|     1,84 kg |           0,1 kg |     1,9 kg |  1,9 kg |
|     1,91 kg |           0,1 kg |       2 kg |    2 kg |
|     2,01 kg |           0,1 kg |     2,1 kg |    2 kg |
|     2,49 kg |           0,1 kg |     2,5 kg |    3 kg |

Đề xuất có thể thấp hơn nhu cầu gốc. Nhân viên có thể xem cả hai số tại **Xác nhận nhu cầu → Xem cách hình thành nhu cầu**. Số lượng nhân viên tự nhập vẫn phải khớp bước xác nhận của đơn vị. Nếu đề xuất tự động không biểu diễn được theo bước xác nhận, Atlas báo lỗi và hủy lần lập phiếu.

**Đổi ngưỡng cho phiếu mới.** Tạo migration mới thay giá trị trả về của `atlas_core.new_need_whole_round_from()`. Ví dụ, trả về `3::numeric` để bắt đầu làm tròn kg đến số nguyên từ 3 kg, hoặc `NULL::numeric` để quay về chỉ làm tròn lên theo bước nguyên liệu. Ngưỡng có giá trị từ 1 trở lên. Ghi ngày áp dụng và ví dụ đã duyệt vào mục này. Cập nhật và chạy bộ kiểm thử [planning_operational_proposal.sql](../../supabase/tests/planning_operational_proposal.sql), gồm trường hợp dưới ngưỡng, đúng ngưỡng, làm tròn xuống, điểm giữa và đọc lại phiếu cũ trước khi triển khai lên Staging.

**Giữ lịch sử.** Phiếu mới lưu ngưỡng kg và danh sách đơn vị kg khi lập. Khi đọc lại hoặc tạo phiên bản kế tiếp trong cùng phiếu, Atlas vẫn dùng hai giá trị đã lưu. Phiếu lập theo phiên bản ngày 20/11 giữ số sau bước nguyên liệu nếu dưới ngưỡng. Phiếu có ngưỡng trống chỉ làm tròn lên theo bước nguyên liệu. Số gốc và số nhân viên đã xác nhận vẫn được giữ.

**Đổi công thức.** Phần tính theo đơn vị nằm trong hàm `atlas_core.unit_need_proposal`. Nếu đổi số chữ số thập phân hoặc cách xử lý điểm giữa, thêm phiên bản mới cho phiếu lập sau ngày triển khai và kiểm thử đọc lại cả hai loại phiếu cũ. Chạy lại các ví dụ cùng bộ kiểm thử SQL nêu trên. [Migration tính theo đơn vị](../../supabase/migrations/20261123030435_need_unit_rounding.sql)

Quy tắc theo đơn vị lấy từ hai hàm xuất phiếu của Retool v1 (`lib/js_shop_Export.js` và `lib/js_need_export_template.js`). Atlas áp dụng quy tắc này lúc tạo đề xuất nhu cầu, sau bước làm tròn riêng của nguyên liệu. Phiếu đi chợ dùng số lượng đã lưu.

## Original decision (23 September 2026)

Atlas keeps three quantity meanings distinct in school-catering Confirmed Need:

1. `theoretical_quantity` is the exact raw calculated requirement after all
   released contributions are aggregated to the seven-part operational
   identity. It is never rounded or overwritten.
2. The non-authoritative Draft proposal stored in the existing
   `confirmed_quantity` field is derived by PostgreSQL as
   `ceil(grouped_raw_requirement / ingredient.order_step) * ingredient.order_step`,
   where `grouped_raw_requirement` is the persisted exact
   `theoretical_quantity`.
3. Confirmed operational need is explicit human authority recorded by H1B1
   decision evidence.

Materialization resolves the exact active Ingredient and its versioned
`purchase_unit_id`/`order_step` set-wise across grouped identities. The
Ingredient purchase Unit must equal the controlled Unit and `order_step` must
be positive. It quantizes the aggregate once, never individual contributions.
There is no conversion, dimension default, global default, or guessed fallback.

Materialization also resolves exactly one H1A policy for the exact controlled
Unit and service date. H1A does not produce the proposal: it remains the minimum
human confirmation quantum. The Ingredient rounding step must be an exact
positive integer multiple of the H1A step so every generated proposal is
representable at confirmation. Missing/invalid Ingredient configuration,
missing/ambiguous H1A resolution, or incompatible steps reject the whole
materialization before any Confirmed Need write.

The rule applies to initial materialization and successor correction
materialization. Existing revisions and old-semantics Drafts are not rewritten;
an old Draft can adopt the new rule only through the approved explicit
correction/regeneration path. D-040 remains authoritative when an unchanged,
policy-compatible successor legitimately carries an existing human decision.

## System derivation versus human confirmation

System proposal derivation is not a human adjustment. If raw `0.025500 kg`
under Ingredient step `0.100000 kg` yields proposal `0.100000 kg`, accepting it
creates `UNCHANGED_PROPOSAL_ACCEPTED` with `PROPOSAL_ACCEPTED`. It does not
create `PLANNING_STEP_ADJUSTMENT`.

Human confirmation remains fail closed. Operator-entered quantity must already
be an exact whole number of the effective policy step under exact decimal
arithmetic. The client may provide immediate step-aware feedback using decimal
strings, but neither client nor backend rounds, ceilings, truncates, trims, or
returns a replacement quantity for invalid input. For example, when the
Ingredient-derived proposal is `1.500000 kg`, Ingredient step is `0.500000 kg`,
and H1A is `0.010000 kg`, human confirmation `1.370000 kg` is valid while
`1.375000 kg` is rejected. A real valid change uses
`ADJUSTED_QUANTITY_CONFIRMED` and
`OPERATIONAL_QUANTITY_ADJUSTMENT` with the required note.

This explicitly reconciles H1A-P06: its rejection rule governs operator-entered
confirmation, while D-046 governs the earlier deterministic system proposal.

## Presentation and evidence

The Confirmed Need workbench keeps the exact theoretical requirement,
Ingredient-derived proposal and human confirmation separately available. The
resting decision table prioritizes `Đề xuất vận hành` and `Số lượng xác nhận`;
it does not need to repeat the raw total or both policy helpers on every row.
`Xem cách hình thành nhu cầu` progressively presents recipe and direct
contributions, exact raw total, the revision's snapshotted Ingredient rounding
step, proposal, effective H1A confirmation step, confirmed value and atomic
source lines. This presentation must resolve one exact selected-run/current-
batch identity and fail closed when its match is missing or ambiguous.

An unchanged confirmation is presented quietly as acceptance of the proposal.
A real human change is determined by exact proposal-versus-confirmation
comparison and displays its signed delta; fresh lines
(`current_decision_id = null`) are not presented as adjusted merely because
their first decision is unsaved. H1A remains contextual confirmation policy and
the source of step-aware validation. Read-only historical protection remains
limited to actual authoritative decisions that cannot safely round-trip through
the current step-aware editor.

First Save semantics under D-037 do not change: every fresh line receives an
explicit first decision, unchanged proposals remain `PROPOSAL_ACCEPTED`, and a
real operator change remains an operational adjustment. The system proposal is
explained by exact raw quantity plus the Ingredient rounding snapshot and
creates no decision row itself. The table and progressive evidence changes do
not alter calculation, materialization, confirmation authority or persistence.

When either RMVP-05.v1 Confirm or RMVP-05.v2 Save creates an adjusted successor
revision, it copies `proposal_rounding_step` and
`proposal_rounding_ingredient_version` from the predecessor. It does not
re-resolve the current Ingredient. Authorized readback reconstructs the system
proposal from the revision's exact raw quantity and snapshotted step, keeping it
distinct from the human `confirmed_quantity_after`. A legacy revision whose
snapshot pair is null retains the prior `confirmed_quantity` readback fallback.

## Consequences and boundaries

The existing Confirmed Need aggregate and revision storage are reused. The
revision gains nullable `proposal_rounding_step` and
`proposal_rounding_ingredient_version` evidence columns: legacy revisions stay
null; materializer-created `NEED_GENERATION` revisions snapshot both values;
and a human-adjustment successor carries its predecessor's pair, including a
null pair from a pre-D-046 lineage. Both fields are immutable revision evidence. No
proposal table, aggregate, lifecycle, new public endpoint, fallback policy,
production seed, or generic rules engine is introduced. Reusing
`Ingredient.order_step` does not move human confirmation authority to
Procurement or alter downstream purchase semantics. Source membership,
theoretical lines, decisions, released
history, security boundaries, RLS, timeouts, retry behavior, Purchase Handoff,
Procurement, Warehouse, Dispatch, Retool, and OPS v1 semantics are unchanged.

Implementation is by one forward migration replacing the bounded private
materializer while preserving its signature, owner, security-definer posture,
empty search path, and grants. The migration rewrites no existing business row.
Rollback after deployment requires a reviewed forward migration; it must not
rewrite materialized or human-authorized history.

See the [implementation task](../implementation-tasks/TASK-PLANNING-OPERATIONAL-PROPOSAL-01.md).
