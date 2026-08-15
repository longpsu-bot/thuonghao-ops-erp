# Atlas Operator Workbench Patterns

**Status:** Proposed Product standard — ATLAS-UX-RESET-01  
**Reviewed baseline:** `c3015d7d2fa7e1ab9887ed8d8843619433b97638`  
**Evidence:** retained OPS v1 Retool exports, current connected Atlas Application, D-034, D-035, D-036, D-037, D-038 and ATLAS-UI-STANDARD-02

## 1. Purpose

This document records the Product-design lessons recovered from OPS v1 and the current Atlas implementation.

Atlas has materially stronger backend architecture than OPS v1. It has explicit authorization, authoritative commands, immutable evidence, lineage, idempotency, transaction safety and clearer domain ownership.

That does not automatically make the Application easier to operate.

OPS v1 frequently had poor implementation architecture but good **job decomposition**: staff entered a screen to do one recognizable job, worked directly in a table or form, and used short actions such as `Lưu`, `Đồng bộ`, `Tạo phiếu xuất kho` or `Khởi tạo PO`. Much technical orchestration remained hidden underneath Retool.

Atlas must combine the strengths:

> **Preserve the correct business-workflow fidelity and directness proven in OPS v1, use Atlas visual consistency, and keep business authority in the Atlas backend.**

This document defines interaction archetypes and review rules. It does not create a generic workflow engine, component framework or new business capability.

## 2. Governing principles

The architecture authority remains `OPS_SYSTEM_MAP` v1.0:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

The delivery shorthand remains:

**Workflow-led, contract-constrained, backend-authoritative.**

For established OPS v1 capabilities, workflow-led means:

```text
reconstruct actual operator workflow
→ identify real business invariants and lock/commitment boundaries
→ preserve those boundaries
→ improve confusing interaction/presentation
→ move unsafe browser/Retool authority into backend contracts
```

Canonical safeguard:

> **UI simplification may hide technical machinery, but it must never erase, bypass or redefine a real business boundary.**

A first-time-user standard therefore means that a new employee can understand the **correct business workflow** quickly. It does not mean reducing every workflow to the fewest visible steps.

## 3. What OPS v1 is evidence for

Retool is not architecture authority and is not the Atlas visual target.

It is strong evidence for:

- which jobs operators recognize as separate;
- the context operators choose first;
- which tables are used as the primary workspace;
- what staff search for by name;
- where direct editing is expected;
- which helper tools such as copy/import/export are useful;
- where explicit Save exists;
- where a real commitment, handoff, Change Order or correction is separate from Save;
- what staff need to see before acting;
- what practical exception and recovery paths already exist.

Do not copy:

- direct SQL;
- Retool state as business authority;
- client-owned calculation or validation authority;
- optimistic authority;
- hidden chained writes as transaction control;
- implicit authorization;
- destructive replacement merely because v1 implemented it;
- Retool component hierarchy or visual style.

The Product lesson is the mental model, not the implementation.

## 4. Evidence-backed v1 workflow inventory

The following inventory is intentionally expressed as operator jobs rather than database objects.

| Operator job | v1 evidence / entry | Primary context | Main work surface | Normal action | Useful interaction lesson | Atlas interpretation |
| --- | --- | --- | --- | --- | --- | --- |
| Choose weekly menu | Home action `Chọn thực đơn cho ngày`; `menuAssign` | week, School | day × dish-type menu grid/table; Google Sheet source | synchronize/save current week | period first; familiar School/Dish language; import is a utility | preserve week-first menu job; backend owns source validation/currentness |
| Enter attendance | Home action `Nhập sỉ số`; `attendance` | service date | editable School table with student/teacher portions | `Lưu` | direct table editing; default values; one obvious save | preserve date/table/save mental model; remove browser-side payload authority |
| Record Pantry / special demand | PurchasePlanner `Hàng đặt riêng` | service period/date, School, Ingredient | practical editable list | `Lưu` | distinct source job, not a lifecycle screen | preserve separate authored source job; backend owns lineage/readiness |
| Confirm quantities / prepare order | `Xác nhận SL và lên đơn` | period and requirement family | dense quantity review/edit surface | save/continue into order work | operators reason about quantities, not generation internals | keep review/commitment business language; hide internal batch/workload mechanics |
| Produce supplier order | `Xuất đơn cho nhà cung ứng` | supplier / service period | supplier-grouped order view | generate/export supplier order | handoff is a recognizable downstream job | procurement slice should be supplier/job-oriented, not command-oriented |
| Prepare dispatch document | `Phiếu xuất kho` | service date / destination / order | dispatch lines/document surface | `Tạo phiếu xuất kho` | document creation is a real business action | preserve document job while backend owns eligibility and evidence |
| Reconcile PO vs dispatch | `Đối chiếu PO và Phiếu xuất kho` | PO / dispatch document | comparison table | resolve discrepancy / review | reconciliation deserves its own workbench | use a reconciliation archetype, not generic lifecycle detail |
| Maintain Ingredient catalog | Ingredient/Supplier app | search text, active status | searchable Ingredient table + selected detail | `Lưu`; activate/deactivate | prominent search; table → detail; supplier assignment is contextual | searchable catalog/detail editor; backend owns status/assignment commands |
| Maintain Supplier catalog | Ingredient/Supplier app | Supplier search | Supplier table + detail | `Lưu` | Supplier is a separate catalog job despite shared app | do not force Ingredient and Supplier into one generic editor if jobs diverge |
| Maintain School defaults | Admin `Chỉnh sửa sĩ số mặc định` | School | directly editable compact table | save changed defaults | fast bulk edits can be more efficient than one drawer per row | choose inline edit vs detail editor from actual job frequency, not component preference |
| Inspect current Dish/Recipe | Recipe app / current-effective views | Dish, recipe scope | current Recipe/BOM table | primarily read-only | current truth is a catalog job | make current-effective Recipe a searchable read-only catalog |
| Create Dish + initial Recipe | `BoMCreation` | new Dish, Recipe scope | creation form + composition table | create/save | creation is a distinct job; Recipe Copy avoids re-entry | preserve separate creation workbench; Copy is a helper inside creation |
| Copy Recipe during creation | Recipe copy modal/helper | target Dish + source Dish | source preview + target creation draft | apply copy | helper accelerates creation without redefining lifecycle | local form-fill helper; final creation command remains authoritative |
| Change locked Recipe | `SystemChangeOrder` | current Dish/Recipe, scope/effective context | intent-specific correction form | save/commit Change Order | business intents such as replace, quantity change, add, remove are meaningful | post-lock change remains a distinct Change Order workflow |
| Dish/School-specific Recipe correction | `overrideDish`, `overrideSchoolWise` | Dish/School/scope | override form + effective preview | `Lưu` | exception scope is explicit | preserve only where business requirement remains; backend owns effective calculation |
| Import Recipe workbook | `importrecipe` | workbook / target import set | parsed preview tables | import after review | import is a utility with preview, not the main Recipe maintenance model | keep only if actual operator need remains; do not let file schema define domain design |

This inventory is not a requirement to preserve every Retool page. It is evidence that different operator intentions often deserve different workbenches even when one backend aggregate can technically support them.

## 5. Product diagnosis: v1 versus current Atlas

### 5.1 What v1 frequently did better

1. **Direct job entry.** Home buttons are named after staff tasks rather than domain architecture.
2. **Context first.** Date, week, School, Dish or Ingredient selection usually appears before technical status.
3. **Table as the work surface.** Retool commonly lets operators scan and edit the data directly rather than navigating several presentation layers.
4. **Search by human memory.** Ingredient search uses the name/type operators remember.
5. **Utilities stay utilities.** Refresh, Download, import and copy support the job instead of becoming primary lifecycle concepts.
6. **Specialized correction jobs stay distinct.** Recipe creation, Change Order and overrides are not collapsed into one lifecycle editor.
7. **Immediate feedback.** Save/sync actions produce short operational notifications.

### 5.2 What Atlas currently does better

1. Backend-owned validation and authorization.
2. Explicit transaction and idempotency boundaries.
3. Immutable evidence and reproducibility.
4. Safer concurrency/currentness handling.
5. Better separation of business domains.
6. More consistent visual language and accessibility intent.
7. Better testability and transferability.

### 5.3 Where Atlas still underperforms Product-wise

1. Navigation can mirror system/domain structure rather than available jobs.
2. Page → WorkbenchHeader → Panel → nested section/card hierarchy can duplicate visual levels.
3. Shared state components sometimes speak backend language instead of business language.
4. Successful screens can show too much evidence/status merely because the backend returns it.
5. Planning has exposed source signatures/checksums, readiness/currentness concepts and audit versions too close to normal work.
6. Need Generation has presented internal source readiness as a visible dashboard rather than answering the operator question: can needs be created or updated?
7. Recipe before merged PR #191 was a Recipe Version lifecycle console rather than a current-catalog / creation / Change Order product; #191 is now the reference correction, not current debt.
8. Some catalogs accumulate many row actions instead of moving contextual operations into a selected-object detail surface.
9. Client-side shortcuts such as arbitrary result slicing can create hidden behavior instead of explicit pagination/search rules.
10. Shared components risk becoming the starting point for design rather than the consequence of repeated proven interaction patterns.

## 6. Canonical Atlas workbench archetypes

These are **interaction archetypes**, not required React base classes.

A child task should name the archetype it is using and explain why it matches the operator job. It should not create a generic implementation framework merely because multiple archetypes are documented.

### A. Job launcher

Use when staff begin from a small number of recurring jobs.

```text
role / work area
→ direct job choices
→ open the selected workbench
```

Examples: `Nhập sĩ số`, `Chọn thực đơn`, `Đặt đơn`.

Rules:

- labels describe jobs, not domains or backend objects;
- hide unavailable future modules rather than using the navigation as a roadmap;
- role/capability filtering happens before or while rendering navigation.

### B. Searchable catalog

Use when the job is primarily finding and inspecting current effective information.

```text
search + practical filters
→ dense current-effective table
→ optional detail
```

Examples: current Ingredient catalog, current Recipe catalog.

Rules:

- read-only is valid and should not resemble a disabled edit form;
- prioritize human-recognizable identity and current business facts;
- history/evidence is secondary.

### C. Catalog + detail editor

Use when operators repeatedly find one reference object and update a bounded set of fields.

```text
search / filter
→ table
→ select object
→ detail editor
→ Lưu
```

Examples: Ingredient detail, Supplier detail, School defaults when row-level editing is appropriate.

Rules:

- the table stays visible where comparison matters;
- contextual secondary jobs such as supplier priority may live in the selected detail, not as many row buttons;
- inline bulk editing is preferred when the real job is high-frequency bulk maintenance.

### D. Period editor

Use when staff author facts for a date/week and the period is the dominant context.

```text
period
→ search/filter within period
→ editable table/grid
→ Lưu
```

Examples: Attendance, Weekly Menu, Pantry.

Rules:

- the period is visually obvious;
- importing/syncing is a secondary source utility;
- automatic validation should surface only actionable issues;
- support evidence stays behind disclosure.

### E. Creation workbench

Use when the operator intentionally creates a new business identity or initial controlled record.

```text
create
→ required identity/context
→ author initial content
→ optional copy/import helper
→ review errors
→ create/save
```

Example: Dish + initial Recipe.

Rules:

- creation is not disguised as editing an empty catalog row if the business treats it as a separate job;
- copy/import fills the creation draft but does not become separate business authority;
- if the created object later locks, creation must clearly end before the correction workflow begins.

### F. Business correction / Change Order

Use when an existing business invariant forbids ordinary edit and the operator is making an accountable change.

```text
find current object
→ choose correction intent
→ specify effective scope/date
→ enter change
→ review consequence
→ commit Change Order
```

Examples: Recipe ingredient replacement, quantity change, add/remove ingredient.

Rules:

- do not turn Change Order into ordinary edit to reduce clicks;
- intent wording comes from the business job;
- successor/version machinery remains backend/internal;
- effective-date/scope rules must be reconstructed from evidence before implementation.

### G. Derivation / generation workbench

Use when the system computes a downstream result from already-authored sources.

```text
period/context
→ actionable blockers if any
→ one Generate / Update action
→ resulting table
```

Example: Need Generation.

Rules:

- do not expose readiness engines, source fingerprints, validation stages or run versions as normal concepts;
- if blocked, state the real missing/invalid business fact and provide a path to fix it;
- if current, show the result or next real job rather than a success dashboard.

### H. Review + commitment workbench

Use when the operator reviews/edits current work and then makes a genuine downstream commitment.

```text
find/filter
→ review/edit
→ Lưu
→ continue editing if needed
→ commit/send/release when business-ready
```

Example: Confirmed Need `Lưu` → `Chuyển sang lên đơn` where that business boundary is accepted.

Rules:

- Save and commitment remain separate only when the business semantics require both;
- deterministic backend validation does not become extra operator buttons;
- commitment consequence must be clear in business terms.

### I. Reconciliation / exception workbench

Use when the job is comparing two authoritative business records and resolving a discrepancy.

```text
select period/document set
→ aligned comparison
→ highlight mismatch
→ inspect evidence
→ resolve or route exception
```

Examples: PO versus Dispatch Slip reconciliation; later Warehouse receiving discrepancy handling.

Rules:

- comparison is the main work surface;
- exceptions dominate only when they exist;
- resolution options are business actions, not generic lifecycle transitions.

## 7. Workbench selection rule

Before designing a screen, answer:

1. What exact operator job is being completed?
2. Is this an established v1 workflow or a new capability?
3. Which business object is current truth?
4. Is the work read-only inspection, ordinary editing, creation, derivation, commitment, correction or reconciliation?
5. What context must be selected first?
6. What is the dominant work surface?
7. What is the genuine human action?
8. What technical machinery can disappear?
9. What business invariant must remain visible/enforced?
10. Which archetype best matches the job?

If the answer requires combining several archetypes, verify that the operator truly performs one job rather than combining screens for implementation convenience.

## 8. Mandatory workflow archaeology for established capabilities

Before freezing a UI or contract correction for an existing OPS v1 capability, inspect:

1. the Retool screen/workbench actually used;
2. normal operator sequence;
3. read-only versus write surfaces;
4. creation workflow;
5. search/filter patterns;
6. copy/import/export helpers;
7. lock/immutability behavior;
8. what happens after first operational use;
9. Change Order / override / correction paths;
10. live OPS schema/functions/triggers when required to verify an invariant.

Every child completion report must state:

```text
workflow preserved
workflow improved
workflow intentionally changed
```

Any `workflow intentionally changed` item requires explicit Product Owner approval.

If evidence is ambiguous, stop the design decision and raise the ambiguity. Do not invent a business rule merely to keep implementation moving.

## 9. Concept budget

Every concept visible by default must pay rent in the current human task.

Count the concepts a first-time operator must understand to complete the normal job.

Examples of concepts that usually do **not** belong in the normal reading flow:

- API contract/version;
- aggregate/version number;
- command/run IDs;
- fingerprints/checksums;
- capability codes;
- source snapshot IDs;
- validation stage names;
- pagination/chunk limits;
- internal predecessor/successor terminology;
- audit event identifiers.

The concept budget is not a fixed number. The test is whether removing the concept would make the operator less able to perform the correct business job.

Support and audit users may access additional detail through progressive disclosure or dedicated support views.

## 10. Information architecture

Atlas navigation should represent available work, not the implementation roadmap.

Preferred top-level logic:

```text
Work / operational jobs
Reference catalogs
Support / administration where authorized
```

Within an operational area, navigation should follow the operator sequence.

Example Planning sequence:

```text
Thực đơn
Sĩ số
Bổ sung
Tạo nhu cầu
Xác nhận nhu cầu
```

Do not expose future/unavailable modules as disabled teaching controls unless a concrete product reason requires it.

`OPS_SYSTEM_MAP` remains the architecture map underneath; it is not required to become the sidebar taxonomy.

## 11. Component-design rule

Design starts from the operator archetype, not the shared component inventory.

Shared components should remain low-level presentation primitives with proven reuse.

Useful categories may include:

- workbench header/context;
- search/filter toolbar;
- bounded table wrapper;
- detail drawer/pane;
- business notice/banner;
- action group;
- confirmation dialog;
- history/support disclosure.

Rules:

- `Panel`/cards are not default semantic wrappers;
- status chips appear only when status materially helps scanning;
- shared state components accept business copy rather than generating architecture vocabulary;
- no shared component should require lifecycle/version terminology merely because the backend has it;
- do not create `CatalogWorkbench`, `ChangeOrderEngine`, `WorkflowStep`, or similar generic frameworks without multiple proven implementations and a concrete maintenance benefit;
- fewer Atlas-specific components with stronger usage rules are preferable to a large custom design system.

## 12. Interaction and visual rules recovered from v1

Preserve the useful mental models while using Atlas visual standards:

- put search where staff expect to find an object quickly;
- allow direct table editing when the actual job is bulk row maintenance;
- use table → detail when the job is object maintenance;
- keep one dominant action in the current context;
- keep Download/Refresh/Import/Copy as utilities unless they are the job itself;
- show current scope before status;
- prefer concise outcome notifications;
- avoid explanatory prose that teaches implementation mechanics;
- do not turn every backend state into a card, chip or section;
- use human-scale typography and controls from ATLAS-UI-STANDARD-02.

### Review before authoritative Save

For editable operational workbenches, use:

```text
Edit
→ review the pending business changes
→ authoritative Save
```

Review shows human business facts and only the relevant pending changes, represents the exact intended Save, and becomes invalid after any material edit. For direct authored facts, a local Before/After review may be sufficient. For derived or consequential calculations, use an authoritative backend Preview when the backend must compute the business consequence. This rule does not require a new backend Preview API for every form and does not make Review another lifecycle state.

Verified OPS v1 Attendance evidence adds a mandatory future Planning case: Menu assignment establishes working Attendance only for the covered School/service dates, initially using School defaults. Those default-derived rows are not confirmed Attendance. Later School-default changes may refresh only future quantities that still represent the previous default; operator-entered or confirmed quantities must never be overwritten. Menu planning normally precedes Attendance confirmation, which operationally occurs about 2–3 days before service; this timing is context, not an automatic deadline. The normal future Application should open already-seeded rows for review/edit/Preview/Save rather than presenting `Tạo từ sĩ số mặc định` as a primary business action. Need Generation must continue to require confirmed/current Attendance, not merely seeded rows.

## 13. Current Atlas Product debt identified by this review

This is a design debt register, not authorization for an all-at-once refactor.

### High priority

- UI-QUALITY-03C-A addresses School-default bulk maintenance; the remaining connected Admin debt is Ingredient/Supplier consolidation.
- Need Generation still exposes readiness/currentness and evidence concepts too prominently for a derivation job.
- Planning support detail has exposed technical source evidence such as checksums in the normal workbench.
- Navigation still includes architecture/roadmap-shaped grouping and unavailable modules.

### Medium priority

- `Panel` and nested surfaces are overused in some workbenches.
- shared `OperationalState` copy has historically used phrases such as authoritative-data wording that operators do not naturally use;
- some catalog rows expose too many possible actions simultaneously;
- history can show internal status/version syntax instead of business events;
- Ingredient list currently contains a client-side visible-row slice rather than an explicit large-result behavior.

### Keep

- the merged #191 Recipe catalog/creation/lock boundary;
- the merged #194 Change Order first-user redesign;
- Mantine as generic presentation foundation;
- Atlas visual consistency from D-034;
- backend-owned authority;
- current search-first improvements;
- human-scale typography rules;
- native Vietnamese requirement;
- responsive/accessibility acceptance;
- bounded tables and progressive disclosure.

Do not respond to this debt by launching a broad component rewrite. Repair each workbench when its bounded operator slice is active.

## 14. Merged PR #191 as the first continuation case

PR #191 is now merged and is the first concrete application of this reset.

It preserves three Recipe jobs:

```text
current-effective catalog
creation + Recipe Copy helper
post-lock Change Order
```

The creation workbench does not silently create a successor after the established lock condition. First committed approved-menu use is represented by immutable approved Weekly Menu snapshot evidence, and normal base Recipe/BOM composition changes are then prohibited. Post-lock composition change belongs to RMVP-02B `Điều chỉnh`; Dish metadata and Dish/Recipe-root lifecycle administration remain separately governed.

This is workflow-preservation evidence, not a universal lifecycle template for other domains.

UI-QUALITY-03B is now merged through PR #194. The current Admin continuation is UI-QUALITY-03C: School defaults in PR #195, followed by the separate Ingredient/Supplier consolidation slice.

## 15. Product review gate for future PRs

For every PR involving an established business workflow, root review must answer:

1. What existing operator workflow was inspected?
2. What exact workflow is preserved?
3. Which changes are interaction/visual improvements only?
4. Did any business invariant change?
5. Did the lock/immutability point change?
6. Did ordinary edit replace a Change Order or exception workflow?
7. Did the PR invent a new human action?
8. Did it remove a real human action?
9. Did it generalize a pattern from another domain without equivalent business semantics?
10. Is the chosen workbench archetype appropriate?
11. Can a first-time operator understand the correct workflow in about five seconds?
12. Is the UI simpler than the implementation beneath it without becoming business-incorrect?

Hosted CI is ordinarily part of release certification, but it is not sufficient Product evidence by itself. Under an explicitly approved temporary CI-deferred development policy, repository merges may proceed only with strong local validation and independent Product/architecture review; the deferred hosted gates remain certification debt and must be restored before Atlas is treated as release-certified for staging/production deployment.

## 16. Application to future Warehouse work

Warehouse must not begin from inventory tables or backend states.

Start with the real Receiving job:

```text
what shipment is expected?
→ what physically arrived?
→ what quantity/lot/condition was received?
→ is there a discrepancy?
→ who accepts or routes the exception?
→ what evidence is required?
```

Only after that workflow is reconstructed should Atlas define the minimum Receiving contract and connect the Application.

Likely archetypes:

- Receiving: period/work queue + commitment/evidence;
- discrepancy: reconciliation/exception;
- stock catalog: searchable catalog;
- stock count/adjustment: business correction.

Do not design a generic Warehouse lifecycle UI first.

## 17. Delivery sequence after this reset

The Recipe/Admin sequence is now:

```text
PR #191 Recipe/BOM correction — merged
→ ATLAS-UX-RESET-01 operator-pattern standard
→ UI-QUALITY-03B Change Order redesign — merged #194
→ UI-QUALITY-03C-A School defaults — current #195
→ UI-QUALITY-03C-B Ingredient/Supplier consolidation
→ cross-flow operator review
```

PR #193 separately made UI Review Export manual-only and does not change this Product sequence.

Future slices must use workflow archaeology and the archetype-selection rule from the beginning rather than removing backend-shaped UX after implementation is deep.

## 18. Non-goals

ATLAS-UX-RESET-01 does not:

- change OPS_SYSTEM_MAP;
- weaken backend authority;
- authorize any new business workflow;
- change Recipe/Planning contracts by itself;
- replace D-034 visual direction;
- replace ATLAS-UI-STANDARD-02 first-user requirements;
- create a React component framework;
- create a workflow engine;
- mutate Retool or live OPS;
- deploy Atlas;
- start Procurement, Warehouse, Production/QA or Dispatch implementation.

Its purpose is to ensure that future Atlas UI work starts from the correct human job and preserves real business boundaries while allowing the backend to remain rigorous and largely invisible.
