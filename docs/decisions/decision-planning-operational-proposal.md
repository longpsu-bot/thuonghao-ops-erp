# Decision D-046 — Ingredient-derived Planning Operational Proposal

**Status:** Accepted

**Date:** 23/09/2026

**Approval:** Product Owner, task authorization
`PLANNING-OPERATIONAL-PROPOSAL-01`.

## Quy tắc hiện hành và cách thay đổi (23/11/2026)

**Nhu cầu theo định mức.** Với mỗi món trong thực đơn, Atlas tính lượng nguyên liệu theo công thức có hiệu lực và số suất. Các món dùng chung nguyên liệu được cộng lại theo ngày, trường, điểm giao và đơn vị. Hàng đặt riêng, nếu có, là một nguồn bổ sung có thể tra riêng. Atlas lưu tổng gốc với đầy đủ độ chính xác trong **Xác nhận nhu cầu → Xem cách hình thành nhu cầu**.

**Đề xuất vận hành.** Atlas lấy tổng gốc của từng dòng và làm tròn lên một lần theo nấc áp dụng cho mặt hàng. Lượng đã đúng nấc giữ nguyên, kể cả số 0. Thay đổi bước làm tròn chỉ ảnh hưởng cách lập đề xuất cho phiếu mới. Định mức món và số lượng gốc vẫn truy được theo nguồn.

| Dòng nhu cầu                             | Nấc áp dụng                                                    | Ví dụ                                                                   |
| ---------------------------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Rau nêm tính bằng kg, tổng gốc dưới 2 kg | 0,1 kg                                                         | 0,12 → 0,2 kg; 1,91 → 2 kg                                              |
| Rau nêm tính bằng kg, tổng gốc từ 2 kg   | 0,5 kg                                                         | 2 → 2 kg; 2,26 → 2,5 kg; 2,51 → 3 kg                                    |
| Các dòng còn lại                         | Bước đặt hàng của nguyên liệu tại thời điểm lập phiên bản dòng | 2,26 kg với bước 0,1 kg → 2,3 kg; 1,21 lít với bước 0,25 lít → 1,25 lít |

**Danh sách rau nêm đã duyệt.** Hành lá (960), Ngò rí (989), Ngò gai (988), Rau ôm (1004), Rau quế (1078), Rau kinh giới (1109) và Rau thơm các loại (1120). Số trong ngoặc là phần số của mã `v1-ingredient-…`. Hẹ lá, Cần ta, Cần tây, Sả bào và Sả cây dùng bước đặt hàng riêng. Quy tắc áp dụng ở bước lập nhu cầu sau khi đã tính định mức món.

**Điều chỉnh sau này.** Đổi bước mua thông thường trong danh mục nguyên liệu. Khi đổi danh sách rau nêm, cập nhật phần lấy mã nguyên liệu của hàm lập phiếu bằng một migration mới. Mỗi phiếu mới chụp lại danh sách mã định danh nguyên liệu, đơn vị kg và ngưỡng. Để đổi ngưỡng cho phiếu lập sau, cập nhật `atlas_core.new_need_whole_round_from()` bằng migration với ngưỡng kg dương được duyệt. Nếu đổi nấc 0,1 hoặc 0,5 kg, tạo phiên bản công thức và lưu dấu phiên bản trên phiếu mới để có thể đọc lại phiếu cũ. Ghi ngày áp dụng, danh sách hoặc nấc mới và ví dụ vào mục này. [Migration quy tắc rau nêm](../../supabase/migrations/20261123044946_herb_need_ceiling.sql)

**Kiểm tra khi thay đổi.** Chạy [bộ kiểm thử đề xuất nhu cầu](../../supabase/tests/planning_operational_proposal.sql) cho lượng bằng 0, dưới ngưỡng, đúng ngưỡng, trên ngưỡng, số đã đúng nấc, nguyên liệu thường và đọc lại phiếu cũ. Kiểm tra Đề xuất và Đã lưu trên phiếu mới. Phiếu đi chợ xuất số đã xác nhận, kể cả khi nhân viên đã điều chỉnh. Bước xác nhận theo đơn vị vẫn áp dụng cho số đã lưu.

**Lịch sử và khôi phục.** Phiếu lập trước thay đổi giữ công thức tại thời điểm lập, kể cả khi đọc lại hoặc sửa trong cùng phiếu. Phiếu ngày 13/11/2026 đã thử trên Staging dùng quy tắc v1 cũ, trong đó 2,26 kg hành lá được đề xuất 2 kg. Các phiên bản trước đó dùng ngưỡng sau bước nguyên liệu hoặc chỉ làm tròn lên theo bước nguyên liệu. Khi cần quay lại chính sách trước, dùng migration mới để chọn chính sách đó cho phiếu lập tiếp theo và giữ dữ liệu, công thức đọc của các phiếu đã lập.

### Cân giao cho trường và mua theo quy cách

**Từ định mức đến đơn đặt.** Ví dụ, công thức và số suất cho ra đúng 2,26 kg hành lá tại một trường. Lượng gốc là 2,26 kg. Cột **Đề xuất vận hành** hiển thị 2,5 kg theo nấc rau nêm. Nhân viên xem tình hình thực tế rồi chốt **Số lượng xác nhận**. Nếu chốt 2,5 kg thì Phiếu đi chợ ghi đúng 2,5 kg. Nếu điều chỉnh, phiếu xuất ghi đúng số đã lưu. Lượng chốt là căn cứ phân bổ nhà cung cấp; lượng đặt thực tế với từng nhà cung cấp được ghi trên đơn mua phát hành.

Với nguyên liệu mua theo kg và cân giao theo lạng, bước 0,1 kg dùng được ở bước lập nhu cầu. Với hàng giao nguyên hộp, đơn vị giao là hộp và bước giao có thể là một hộp. Riêng hàng mua nguyên gói rồi mở ra chia cho nhiều trường cần ghi rõ cả lượng cân giao lẫn khối lượng mỗi gói. Tên nguyên liệu hoặc đơn vị “Gói” trong danh mục chưa đủ để suy ra một gói nặng bao nhiêu kg.

Ví dụ nghiệp vụ: ba trường đã chốt 0,3 kg mỗi trường, cùng nguyên liệu, ngày và nhà cung cấp. Phiếu đi chợ và phiếu giao của từng trường ghi 0,3 kg. Nếu nhà cung cấp chỉ bán gói 1 kg thì tổng cần giao là 0,9 kg, lượng cần đặt là 1 kg và phần dư do quy cách là 0,1 kg. Mỗi nhà cung cấp thực hiện đơn riêng nên phần gom để tính số gói cũng phải theo từng nhà cung cấp.

**Phạm vi hiện hành.** Atlas đã áp dụng các nấc cân giao nêu trên và xuất Excel theo lượng đã lưu. Khi phát hành đơn mua, [hợp đồng Đơn mua](../api/school-catering-procurement.md) hiện yêu cầu tổng giao các trường bằng lượng đặt. Ví dụ mua nguyên gói có phần dư là yêu cầu cho bước mua hàng; thay bước của nguyên liệu thành 1 kg trên màn hình nhu cầu sẽ làm sai cả ba dòng giao.

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
