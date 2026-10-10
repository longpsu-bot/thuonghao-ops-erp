# TASK-ATLAS-DOCUMENT-SCHOOL-GROUPING-02

Owner task instruction, recorded verbatim in substance below. Execution evidence and the hosted configuration blocker are in `docs/runbooks/atlas-document-school-grouping-02.md` and `docs/testing/atlas-school-row-measurement.md`.

Continue Project Atlas in:

`longpsu-bot/thuonghao-ops-erp`

Current authoritative `main`:

`2f3741f38fe26adc9505ffd773c07c11c70b8c0e`

Atlas Staging:

`rnzxmxiiqgtdevzregff`

Current Staging migration state:

```text
97 migrations
tip: 20261010034834_atlas_po_document_code_backfill_rls_fix
```

Document System #360 is merged and the approved PO/PXK presentation must be preserved except where explicitly amended below.

Create ONE new bounded Draft PR.

Suggested branch:

`fix/atlas-document-school-grouping-02`

Suggested title:

`fix(atlas): separate cooking locations from Dispatch export groups`

Do NOT start general UI polish in this task.

==================================================

1. PRODUCT OWNER DECISIONS
   \==================================================

These rules are authoritative.

### PO

PO must ALWAYS retain each School separately.

Several Schools cooking at the same location do NOT become one School section.

Each School retains:

- stable School identity;
- School header;
- Ingredient lines;
- Unit;
- quantity;
- supplier note;
- service date;
- immutable released lineage.

Cooking location is only additional presentation/context.

### Dispatch

Dispatch grouping is a separate explicit relationship.

A shared cooking location does NOT imply shared Dispatch output.

Only explicitly assigned Dispatch Group members may combine.

================================================== 2. CORE MODEL CORRECTION
==================================================

Current Atlas risks conflating:

```text
Cooking location
```

with:

```text
Dispatch export group
```

This is now forbidden.

Model them independently.

Conceptually:

```text
School
├─ optional Cooking Location assignment
└─ optional Dispatch Group membership
```

A Dispatch Group must never determine the PO `Nấu tại` text.

A Cooking Location must never automatically determine Dispatch combination.

Apply:

`FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED`

================================================== 3. CURRENT ATLAS MODEL
==================================================

Current Atlas already has:

```text
atlas_admin.cooking_groups
atlas_admin.school_cooking_group_memberships
```

and released documents capture Cooking Group ID/name.

Do not casually duplicate authority.

Review whether the smallest safe correction is to evolve this existing authority into an explicit Cooking Location authority.

The desired semantic object is:

```text
Cooking Location
```

not a generic export grouping.

A Cooking Location must identify what the destination means explicitly.

Minimum conceptual facts:

```text
cooking_location_id
display_name
location_kind = SCHOOL | COMPANY
host_school_id nullable
active
version
```

For `SCHOOL`:

```text
host_school_id = stable School UUID
```

For the company kitchen:

```text
location_kind = COMPANY
display_name = Công ty Thượng Hảo
host_school_id = null
```

Exact table/column naming should follow the safest migration path from the existing model.

Do not introduce effective dating or workflow lifecycle unless proven necessary.

================================================== 4. COOKING ASSIGNMENT SEMANTICS
==================================================

Each School may have zero or one current Cooking Location.

The relationship must be explicit by IDs.

Examples:

```text
PHẠM VĂN CỘI
→ Cooking Location: PHẠM VĂN CỘI
→ host_school_id = PHẠM VĂN CỘI school_id

LÊ VĂN THẾ
→ same Cooking Location
→ host_school_id = PHẠM VĂN CỘI school_id

VĨNH TÂN
→ Cooking Location: VĨNH TÂN

VĨNH TÂN - PHÂN HIỆU
→ Cooking Location: VĨNH TÂN

CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)
→ Cooking Location: Công ty Thượng Hảo
```

No name matching may determine these relationships.

================================================== 5. PO HEADER PRESENTATION RULE
==================================================

For each School, derive its export label only from its stable School ID plus captured Cooking Location authority.

### School cooks at itself

If:

```text
cooking_location.location_kind = SCHOOL
AND cooking_location.host_school_id = school_id
```

then print only:

```text
<SCHOOL NAME>
```

Example:

```text
PHẠM VĂN CỘI
```

Do NOT print:

```text
PHẠM VĂN CỘI (Nấu tại: PHẠM VĂN CỘI)
```

### School cooks elsewhere

If:

```text
host_school_id != school_id
```

or the Cooking Location is `COMPANY`, print:

```text
<SCHOOL NAME> (Nấu tại: <COOKING LOCATION>)
```

Examples:

```text
LÊ VĂN THẾ (Nấu tại: PHẠM VĂN CỘI)

VĨNH TÂN - PHÂN HIỆU (Nấu tại: VĨNH TÂN)

CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2) (Nấu tại: Công ty Thượng Hảo)
```

Do not use a name-equality heuristic.

================================================== 6. PO SCHOOL SEPARATION
==================================================

This is a hard invariant.

Even when:

```text
School A → Cooking Location X
School B → Cooking Location X
School C → Cooking Location X
```

PO detail must remain:

```text
School A header
  Ingredient lines

School B header
  Ingredient lines

School C header
  Ingredient lines
```

Do NOT produce:

```text
Cooking Location X
  combined Ingredient lines
```

for PO.

================================================== 7. PO LINE GRAIN
==================================================

Never combine lines across distinct values of:

```text
school_id
service_date
ingredient_id
unit_id
supplier_note_snapshot
```

Cooking location does not reduce this grain.

Preserve exact quantity strings.

No IEEE-754 arithmetic.

================================================== 8. NEW DISPATCH GROUP AUTHORITY
==================================================

Add an independent Admin authority.

Conceptually:

```text
atlas_admin.dispatch_groups
atlas_admin.dispatch_group_members
```

Suggested minimum facts:

```text
dispatch_group_id
dispatch_group_name
active
display_order/version if genuinely needed
```

membership:

```text
dispatch_group_id
school_id
```

Each School should belong to zero or one current Dispatch Group unless evidence proves multiple membership is needed.

No effective-dated lifecycle is required for this task.

Private FORCE RLS and shaped API patterns must match existing Atlas Admin conventions.

================================================== 9. AUTHORITATIVE DISPATCH GROUPS
==================================================

Only these groups combine in this task:

### VĨNH TÂN

Members:

```text
VĨNH TÂN
VĨNH TÂN - PHÂN HIỆU
```

### CHUYÊN HÙNG VƯƠNG

Members:

```text
CHUYÊN HÙNG VƯƠNG (Sáng)
CHUYÊN HÙNG VƯƠNG (Trưa)
CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)
CHUYÊN HÙNG VƯƠNG (Chiều)
CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)
```

### PHÚ HOÀ ĐÔNG 1

Members:

```text
PHÚ HOÀ ĐÔNG 1
PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 1
PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 2
```

Explicitly EXCLUDE:

```text
PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 3
```

unless separately authorized later.

All other Schools remain separate.

================================================== 10. DISPATCH GROUPING RULE
==================================================

Dispatch combination is:

```text
service_date
+ dispatch_group_id
+ ingredient_id
+ unit_id
+ note
```

for explicitly grouped Schools.

Combine quantities only when all of the above match.

Do not merge:

- different service dates;
- different Ingredients;
- different Units;
- different notes.

Ungrouped School:

```text
service_date + school_id
```

remains its own Dispatch entity.

================================================== 11. REMOVE COOKING-BASED DISPATCH GROUPING
==================================================

Current Atlas `createSchoolDispatchZip(..., "entity")` uses:

```text
cooking_group_id
```

to form the entity group.

Remove this behavior.

Dispatch ZIP/grouped XLSX must use:

```text
captured dispatch_group_id
```

when present.

Otherwise use the exact School identity.

Do not fall back to Cooking Location.

================================================== 12. RELEASED DOCUMENT IMMUTABILITY
==================================================

Future released document evidence must freeze enough information to reproduce:

### Cooking presentation

```text
cooking_location_id
cooking_location_name
host_school_id / equivalent self-cooking discriminator
```

### Dispatch grouping

```text
dispatch_group_id nullable
dispatch_group_name nullable
```

A later Admin reassignment must not move an already released document into another group.

Historical released evidence remains unchanged.

No fabricated backfill for old releases.

================================================== 13. SCHOOL MASTER RECONCILIATION PRECONDITION
==================================================

Do NOT configure these relationships until School identity is reconciled.

Current verified mismatch:

### Live V1

```text
ID 52  BÌNH QUỚI
ID 10  BÌNH QUỚI - PHÂN HIỆU

ID 47  CHUYÊN HÙNG VƯƠNG (Sáng)
ID 48  CHUYÊN HÙNG VƯƠNG (Trưa)
ID 49  CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)
ID 50  CHUYÊN HÙNG VƯƠNG (Chiều)
ID 53  CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)
```

### Current Atlas Staging

currently has:

```text
v1-school-10 = BÌNH QUỚI
```

and no current Hùng Vương rows were found.

This is stale/incomplete master adoption.

Do not assign the wrong stable School IDs.

First use the existing controlled School/master reconciliation path.

If the canonical Atlas identity cannot be established safely:

stop hosted data configuration with:

`SCHOOL_MASTER_RECONCILIATION_REQUIRED`

Implementation and fixture tests may continue.

================================================== 14. DISPLAY ORDER
==================================================

Preserve all unrelated School relative ordering.

Apply only the Owner-authorized adjacency corrections.

### Bình Quới

Order:

```text
BÌNH QUỚI
BÌNH QUỚI - PHÂN HIỆU
```

adjacent, main first.

### Hùng Vương

Maintain:

```text
Sáng
Trưa
Trưa Mặn 2
Chiều
Chiều Mặn 2
```

In particular:

```text
CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)
```

must immediately follow:

```text
CHUYÊN HÙNG VƯƠNG (Chiều)
```

Do not reorder unrelated Schools.

Use stable School IDs and explicit target order.

Do not sort by School name to obtain this accidentally.

================================================== 15. VĨNH TÂN / OTHER RELATED SCHOOLS
==================================================

Do not infer further ordering rules merely from shared names.

The explicit Owner order changes in this task are:

- Bình Quới pair;
- Hùng Vương ordering.

Other Schools preserve existing relative order unless the reconciled authoritative School list already specifies otherwise.

================================================== 16. ROW HEIGHT — SCHOOL BANDS
==================================================

The existing generic `wrappedRowHeight()` character-count estimate is not sufficient for this requirement.

School header rows must use actual available width and Times New Roman 14 pt metrics.

For a School band spanning the complete visible detail table:

```text
one rendered line = 28 pt
each additional rendered line = +16 pt
```

Therefore:

```text
1 line → 28 pt
2 lines → 44 pt
3 lines → 60 pt
4 lines → 76 pt
5 lines → 92 pt
...
```

NO three-line cap.

================================================== 17. WIDTH MUST COME FROM THE ACTUAL SHEET
==================================================

Do not hardcode a fake generic character capacity.

Calculate available header width from the actual visible columns used by that sheet.

V1 reference School band spans:

```text
A:G
```

Atlas may have a different physical column arrangement because hidden metadata columns exist.

Use:

```text
sum(actual visible Excel column widths)
```

for the School band.

Hidden metadata columns do not contribute to visible width.

================================================== 18. TIMES NEW ROMAN MEASUREMENT
==================================================

Preserve:

```text
font: Times New Roman
size: 14 pt
wrapText: true
```

Implement a deterministic text-width/line-wrap helper grounded in measured Times New Roman 14 pt glyph advances.

Do not continue using:

```text
text.length / guessed capacity
```

for these School headers.

Acceptable method:

1. obtain actual/measured TNR glyph advances in native QA;
2. use those metrics deterministically in exporter code;
3. convert actual Excel column widths to usable print width;
4. perform word-aware wrapping;
5. preserve explicit newlines;
6. allow long tokens to wrap;
7. calculate row height using `28 + 16 × (line_count - 1)`.

Do not embed or distribute font files.

================================================== 19. THEO HÀNG SCHOOL CELLS
==================================================

Apply the same measurement rule to School-name cells in:

`Theo hàng`

Those cells have less width than a full School header.

Therefore they may require more lines.

Use that cell's actual column width, not the full detail-table width.

Same rule:

```text
one line = 28 pt
+16 pt per additional wrapped line
```

Preserve Times New Roman 14 pt and wrapping.

================================================== 20. SCHOOL LABEL FORMAT
==================================================

Examples that must render semantically as follows:

```text
PHẠM VĂN CỘI

LÊ VĂN THẾ (Nấu tại: PHẠM VĂN CỘI)

VĨNH TÂN

VĨNH TÂN - PHÂN HIỆU (Nấu tại: VĨNH TÂN)

CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2) (Nấu tại: Công ty Thượng Hảo)
```

Preserve the School's canonical display name.

Do not modify School master names merely for Excel.

================================================== 21. DISPATCH COMBINED OUTPUT
==================================================

When grouped, the output represents a Dispatch export group, not a new School/PXK identity.

Combine line totals only for presentation/export packaging.

Do not create a new lifecycle aggregate merely to support XLSX.

Source released School documents and lineage must remain traceable in hidden metadata.

================================================== 22. RETOOL / V1 EVIDENCE
==================================================

Retool confirms separate authorities already existed operationally:

```text
po_export_groups
po_export_group_members

dispatch_export_groups
dispatch_export_group_members
dispatch_export_grouped
```

Live V1 Dispatch groups currently match the Owner-highlighted groups:

```text
VĨNH TÂN
CHUYÊN HÙNG VƯƠNG
PHÚ HOÀ ĐÔNG 1
```

Use this as migration/reconciliation evidence only.

Do not reproduce the V1 PO export-group behavior as an Atlas PO aggregation rule.

Atlas PO now keeps every School separate.

================================================== 23. ADMIN UI
==================================================

Extend the existing School/Admin surface minimally.

For each School expose two independent controlled facts:

```text
Nấu tại
Nhóm Dispatch
```

They must be visually and semantically distinct.

Changing one must not mutate the other.

Do not create a new persistent workbench.

================================================== 24. DATA CONFIGURATION
==================================================

Do not hardcode UUIDs in frontend/export code.

Relationship rows use stable backend `school_id`.

For migration/configuration scripts:

resolve only through already-approved canonical School identity.

Fail if expected Schools are:

- missing;
- duplicated;
- mismatched.

No name-only silent fallback.

================================================== 25. MIGRATION / STAGING
==================================================

Create migrations through the Supabase CLI after checking `--help`.

Do not edit the 97 already-applied migrations.

Do NOT deploy this task to Staging until:

- migration replay passes;
- master School reconciliation is resolved;
- Owner/document tests pass.

Live OPS remains read-only evidence.

Retool remains unchanged.

================================================== 26. PO TEST MATRIX
==================================================

Required cases:

### Self-cooking

```text
PHẠM VĂN CỘI
```

No `Nấu tại`.

### Other-school cooking

```text
LÊ VĂN THẾ (Nấu tại: PHẠM VĂN CỘI)
```

### Vĩnh Tân

```text
VĨNH TÂN
VĨNH TÂN - PHÂN HIỆU (Nấu tại: VĨNH TÂN)
```

Two separate School bands.

Never aggregate.

### Company cooking

```text
CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)
(Nấu tại: Công ty Thượng Hảo)
```

as the approved inline/wrapped header string.

### Same cooking location

Two Schools assigned the same Cooking Location remain distinct PO sections.

================================================== 27. DISPATCH TEST MATRIX
==================================================

### Vĩnh Tân

two member Schools combine.

### Hùng Vương

five specified Schools combine.

### Phú Hoà Đông 1

exactly:

```text
main
PH1
PH2
```

combine.

PH3 remains separate.

### Shared cooking but no Dispatch group

must remain separate.

### Same Dispatch group but different note

do not combine.

### Same Dispatch group but different Unit

do not combine.

### Different service date

do not combine.

================================================== 28. ROW-HEIGHT TEST MATRIX
==================================================

Test using actual exporter column widths:

- one-line full-width School header → 28 pt;
- two-line → 44 pt;
- three-line → 60 pt;
- four-line → 76 pt;
- long no-space token;
- Vietnamese diacritics;
- `Nấu tại` suffix;
- narrower `Theo hàng` School cell;
- same text produces more lines in narrower column;
- no arbitrary cap.

Native Excel QA must verify no clipping.

================================================== 29. DISPLAY ORDER TESTS
==================================================

Test that:

```text
BÌNH QUỚI
BÌNH QUỚI - PHÂN HIỆU
```

are adjacent in that order.

Test:

```text
CHUYÊN HÙNG VƯƠNG (Chiều)
CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)
```

are adjacent in that order.

Assert unrelated School relative ordering is unchanged.

================================================== 30. PRESERVE APPROVED DOCUMENT PRESENTATION
==================================================

Do not reopen:

- hidden `Mã hàng`;
- visible `Mã NCC`;
- frozen supplier notes;
- PO/PXK typography already approved;
- PXK `Đạt / Không đạt`;
- hidden metadata;
- exact quantity display;
- Shopping List A+.

This task changes only:

- explicit Cooking Location semantics;
- explicit Dispatch Group semantics;
- School-header text;
- Dispatch combination;
- measured School-row heights;
- targeted display ordering.

================================================== 31. VALIDATION
==================================================

Run:

- new Admin/RLS SQL tests;
- PO snapshot tests;
- PXK/Dispatch snapshot tests;
- PO exporter tests;
- Dispatch grouped-export tests;
- metadata lineage tests;
- row-height native Excel QA;
- display-order tests;
- Shopping List regression;
- full SQL/pgTAP;
- chronological migration replay;
- frontend format/typecheck/test/build;
- exact-head GitHub CI.

Do not weaken thresholds.

================================================== 32. FINAL RESPONSE
==================================================

Return:

```text
TASK_STATUS:
STARTING_MAIN_SHA:
BRANCH:
FINAL_SHA:
DRAFT_PR:

SCHOOL_MASTER_RECONCILIATION:
COOKING_LOCATION_MODEL:
DISPATCH_GROUP_MODEL:
RELATIONSHIPS_SEPARATE:

PO_SCHOOL_SEPARATION:
PO_SELF_COOKING_LABEL:
PO_REMOTE_COOKING_LABEL:

DISPATCH_VINH_TAN:
DISPATCH_HUNG_VUONG:
DISPATCH_PHU_HOA_DONG_1:
OTHER_SCHOOLS_SEPARATE:

ROW_HEIGHT_MEASUREMENT:
FULL_HEADER_WIDTH_SOURCE:
THEO_HANG_WIDTH_SOURCE:
NO_LINE_CAP:

BINH_QUOI_ORDER:
HUNG_VUONG_ORDER:
OTHER_ORDER_PRESERVED:

MIGRATIONS_ADDED:
STAGING_WRITES:
LIVE_OPS_WRITES:
RETOOL_CHANGES:

PO_TEST_STATUS:
DISPATCH_TEST_STATUS:
ROW_HEIGHT_QA:
SECURITY_STATUS:
MIGRATION_REPLAY_STATUS:
FRONTEND_CI_STATUS:

OPEN_FINDINGS:
```

Do not merge or deploy automatically.
