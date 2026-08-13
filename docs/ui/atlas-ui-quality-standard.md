# Atlas UI Quality Standard

**Status:** Accepted cross-module UI contract  
**Accepted on:** 06/08/2026  
**Last refined:** 11/08/2026 — ATLAS-UX-RESET-01 workflow-preservation and operator-pattern amendment  
**Reviewed baseline:** `057a30ef30121fc50ef983acd91704d2bca8e82c`  
**Authority:** [ATLAS-ACT-01 Hosted Staging and Connected-UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md), D-034, D-035, D-036 and D-037

## 1. Purpose

This standard defines the minimum Product, interaction, visual, language and accessibility quality required for connected Atlas operator workbenches.

It does not authorize new business capabilities, APIs, lifecycle states, calculations, persistence or client-owned authority.

The governing delivery shorthand remains:

**Workflow-led, contract-constrained, backend-authoritative.**

For the Application layer, that means:

> **The backend is the gatekeeper and workload manager serving the operator. The UI exposes the business job, current work context and genuine human decisions — not backend mechanics.**

A technically correct screen still fails Product review when a competent first-time operator cannot understand what to do.

## 2. First-user workbench contract

A normal workbench must make these answers obvious without requiring knowledge of Atlas architecture:

1. What job am I doing?
2. What business scope am I working on now?
3. What needs my attention?
4. What can I edit or inspect?
5. Is my work unsaved, saved or already committed downstream?
6. What is the one meaningful action I can take now?
7. What business consequence will that action have?

The normal reading flow is:

```text
workbench identity and business context
→ search / practical filters
→ attention or blockers when relevant
→ primary work surface
→ current saved / committed state
→ one visually dominant business action
→ secondary utilities
→ progressive-disclosure history / evidence / support detail
```

Do not make audit, evidence, lifecycle internals or technical identity part of the ordinary reading flow merely because the backend returns them.

## 3. Core principles

1. **Backend-owned authority.** React renders authoritative state, eligibility, quantities and safe messages returned by the backend. It may make an action stricter for local draft validity, dirty state, busy state or uncertain outcomes, but it must never make a backend-denied action available.
2. **Show the job, hide the machinery.** API names, capability codes, versions, fingerprints, batch IDs, pagination/chunk sizes, validation stages and internal snapshots do not belong in the normal operator flow.
3. **One current state.** Historical events never compete with the current business state.
4. **Exception first when an exception exists.** Blockers and required corrections are easier to find than successful background detail, but successful screens are not dominated by empty warning/evidence containers.
5. **Dense but human.** Operational tables may be information-dense, but typography, spacing and controls remain comfortable for sustained office use.
6. **Stable action hierarchy.** At a normal state, one business action is visually dominant. Secondary and utility actions are clearly subordinate.
7. **Native Vietnamese operator language.** Labels are written from business meaning in natural Vietnamese, not translated word-for-word from backend terminology.
8. **Fast target finding.** Every table-oriented workbench has a useful text search/filter unless there is a documented reason search would provide no value.
9. **Accessible interaction.** Keyboard, focus, semantics, contrast, readable sizing and live feedback are acceptance requirements.
10. **No automatic write retry.** Unknown outcomes require authoritative refresh.
11. **No fake simplification in React.** If an accepted backend contract forces several deterministic system steps to appear as human actions, stop and reassess the business boundary instead of silently chaining commands in the browser.
12. **No speculative design system.** Shared abstractions require real current consumers or a legitimate shell-level purpose.

## 4. Backend gatekeeper and human-action rule

Complex backend safety is welcome when it protects security, integrity, authorization, currentness, auditability, lineage, recovery, idempotency or transaction correctness.

That complexity should normally make the operator experience **simpler**, not more complicated.

A backend state does not automatically deserve a visible UI state.

Before exposing a public button or normal workflow step, ask:

1. Is the person authoring operational facts?
2. Is the person making a genuine business decision or commitment?
3. Is this a necessary exception, correction, acknowledgement or safety decision?

If none applies, the step is probably deterministic system work and should normally remain backend-internal.

This is not an absolute rule that removes legitimate operational acknowledgements or safety decisions. Accepted business requirements remain authoritative.

When one business action requires backend workload partitioning, pagination or internal orchestration, the operator does not administer those implementation details. For example, an RPC row limit is not a user workflow concept.

## 5. Work context

Every workbench visibly identifies its current business scope.

Depending on the job, context may include:

- service week or date;
- School;
- Dish;
- Ingredient;
- Supplier;
- Delivery Location;
- document/reference number;
- row count;
- current saved or released/committed state.

Do not require the operator to infer context from table rows or hidden filter values.

Normal UI should not expose opaque UUIDs, internal revision numbers, fingerprints or capability identifiers. Those remain available only in support detail when genuinely useful.

## 6. Search and filters

Every table-oriented operational workbench should provide a prominent text search/filter unless a strong, documented reason shows that search would not help the job.

Search targets human-readable fields operators naturally remember, for example:

- Ingredient name;
- Dish name;
- School name;
- Supplier name;
- Delivery Location;
- business reference/document number.

When relevant rows are already loaded, simple client-side presentation filtering is sufficient.

Move search into an authoritative backend selector only when real pagination, data volume, security scope or performance requires it.

Do not build a generic search framework merely to satisfy this rule.

Text search may coexist with structured filters such as date, School, Supplier or status. Presentation filters must not silently change authoritative command scope unless the accepted business contract explicitly says they do.

## 7. Actions, Save and commitment

Action labels use a specific, natural business verb and consequence.

`Lưu` means preserve the operator's current authored work when that is the actual action.

A separate commitment action is used when the operator is genuinely releasing, confirming, sending or making work available downstream.

For Confirmed Need, D-037 establishes the current pattern:

```text
Edit
→ Lưu
→ continue working if needed
→ Chuyển sang lên đơn
```

Do not generalize `Lưu → Chuyển sang lên đơn` to every domain. The human-action rule determines each workflow.

Rules:

- use one primary action per local decision context where practical;
- keep secondary actions subordinate;
- quiet utility actions such as refresh/export/search support the job but do not compete with the primary business action;
- separate and confirm destructive or commitment-producing actions when consequence warrants confirmation;
- use backend-authorized eligibility and safe disabled reasons;
- busy state prevents duplicate submission;
- opening a confirmation never submits the command;
- focus enters and returns from dialogs correctly;
- unknown write outcomes disable further mutation until authoritative refresh.

Avoid labels derived from architecture such as `Hoàn tất xác nhận`, `Phê duyệt`, `Phát hành`, `Materialize`, or `Request` unless the operator is genuinely making that exact business decision.

## 8. Visual hierarchy and surface discipline

Atlas remains a modern, calm, precise B2B operations application under D-034. The shell may retain its dark navigation, light global header and warm-stone workspace, but individual workbenches should feel like one coherent work surface rather than boxes nested inside boxes.

Default hierarchy:

```text
Page
  └ Workbench
       ├ Context / toolbar
       ├ Main table or editor
       └ Action / exception area
```

Use spacing, typography, dividers and subtle surface changes before adding another bordered card.

Rules:

- the primary workbench dominates the available area;
- avoid a bordered container for every semantic group;
- cards are reserved for a real signal, blocker, critical summary or distinct support disclosure;
- zero cards is valid;
- avoid KPI walls, decorative deltas, trend arrows and trading-dashboard styling;
- evidence/history are normally collapsed or placed under `Chi tiết`, `Lịch sử` or another progressive-disclosure affordance;
- normal screens do not display checksums, signatures, internal versions or evidence identifiers just because they exist;
- avoid uppercase micro-headings for ordinary workflow structure;
- avoid arbitrary equal-width or oversized action buttons merely for symmetry.

## 9. Human-scale typography and controls

The UI must be comfortable for employees who use it for hours.

Use approximately:

```text
Workbench title       22–26 px / weight 600–700
Section heading       16–18 px / weight 600
Normal body           14–15 px / weight 400–500
Table content         13–14 px / weight 400–500
Field labels          13–14 px / weight 500–600
Helper text           12–13 px / weight 400
Buttons               14–15 px / weight around 600
```

11 px text is exceptional metadata. It is not normal size for instructions, filter labels, action consequences, operational statuses or field labels.

Control guidance:

```text
normal desktop controls     approximately 38–40 px high
primary desktop action      approximately 40 px high
mobile/touch target         approximately 44 px minimum where practical
```

Do not make every button or label weight 700.

Buttons should normally size from their content. Use larger/equal-width actions only when the workflow genuinely benefits from them.

Visual action hierarchy:

```text
primary business action     filled / strongest emphasis
secondary action            outline or subtle
utility action              quiet / text / icon where appropriate
```

Typography retains the approved Atlas font stack. The standard governs proportion and readability rather than requiring a new font dependency.

## 10. Vietnamese product language

Operator-facing UI is Vietnamese and is **authored from business meaning**, not translated from backend vocabulary.

Prefer short, direct operational language such as:

- `Lưu`;
- `Tải lại`;
- `Tìm kiếm`;
- `Cần xử lý`;
- `Cảnh báo`;
- `Chưa lưu`;
- `Đã lưu`;
- `Chuyển sang lên đơn`;
- `Đã chuyển sang lên đơn`;
- `Lịch sử`.

Avoid machine-translated or architecture-shaped language such as:

- `Hành động tiếp theo` when the action can simply be shown;
- `dữ liệu có thẩm quyền`;
- `lô` where the business does not naturally use that term;
- `phiên bản` for an internal revision;
- `bằng chứng quyết định`;
- lifecycle enum wording;
- API/request/materialization terminology.

Do not create a giant English-to-Vietnamese translation registry. Choose wording per workflow and actual business meaning.

Backend reason codes remain backend reason codes. UI copy should be concise, native and safe.

User-facing dates use `dd/mm/yyyy`. Timestamps include time only when operationally relevant. ISO values may appear in copyable support detail, not as the primary display.

Quantity precision follows backend Unit/policy evidence. Zero, missing and unavailable remain distinct, and values stay visually adjacent to their Unit.

## 11. Tables and operational density

Tables are the primary work surface where the job is naturally tabular.

Order columns from the operator's task perspective, not from database shape. A common pattern is:

```text
human-recognizable identity
→ business scope/context
→ editable or decision quantities
→ relevant status / exception
→ secondary support detail
```

Actor IDs, evidence IDs, internal versions and timestamps are not automatically table columns. Put them in row detail/history when they are support information rather than core work.

Requirements:

- semantic headers;
- bounded horizontal scrolling inside the table rather than page-wide overflow;
- sticky identity columns only where useful;
- visible row focus/selection;
- aligned numeric values and adjacent Units;
- explicit loading and empty states;
- primary action and critical status remain discoverable without scrolling the whole table;
- narrow layouts may use row detail for support metadata instead of hiding critical business information.

Do not add a third-party grid or virtualizer without an observed need.

## 12. Export affordances

A workbench may show secondary controls such as:

```text
Xuất Excel
Xuất PDF
```

before final export implementation exists.

Do not freeze speculative file contracts while authoritative tables/read models, business filtering scope or approved document layouts are still changing.

When export is eventually implemented, explicitly define the business contract for:

- template/layout;
- columns;
- filtering scope;
- grouping scope;
- filenames/document identity;
- currentness/audit expectations where applicable.

A disabled placeholder must not fake file generation. It should use a concise accessible explanation that the export format is not yet finalized.

## 13. State presentation

### Loading

- Preserve layout where practical.
- State what is loading only when the wait is meaningful.
- Hide or disable commands while authoritative eligibility is unknown.

### Empty

Distinguish:

- no object selected;
- no records for the current search/filter/period;
- a valid zero-line state;
- a missing prerequisite or blocked source.

### Blocking and warnings

Blockers appear before warnings and use safe business language. Show the affected business object and practical next step when known.

### Stale

Explain that data changed and offer `Tải lại`. Preserve local draft only when the contract permits it. Never replay writes automatically.

### Unknown write outcome

State that completion is uncertain, disable further mutation and require authoritative refresh. Claim neither success nor failure and expose no raw SQL, credential or transport detail.

### Read-only

Explain the relevant business reason when needed. A read-only workbench must not look like a broken editable form.

## 14. Responsive and accessibility acceptance

Review widths:

```text
360 px
768 px
1280 px
```

Acceptance requires:

- no page-wide horizontal overflow at 360 px;
- table scrolling remains local to the table where required;
- dialogs fit and remain keyboard reachable;
- navigation, search and filters remain usable by touch and keyboard;
- visible focus and logical keyboard order;
- semantic headings, labels and table headers;
- field errors associated with controls;
- non-color status cues and adequate contrast;
- result notices use appropriate live-region behavior;
- reduced-motion compatibility for animation;
- long Vietnamese labels/messages wrap without destroying action hierarchy.

Automated checks support but do not replace keyboard and visual review.

## 15. First-time-operator acceptance

Every major workbench must pass this Product test:

> A competent Vietnamese office employee who has never seen Atlas opens the screen without explanation.

Within approximately five seconds, they should be able to tell:

1. what the screen is for;
2. what they are currently working on;
3. how to find the target they need;
4. what can be edited;
5. whether their work is saved;
6. what the visually primary action will do.

If those answers require Atlas database, lifecycle, capability or API vocabulary, the screen fails Product review even when CI is green.

## 16. OPS v1 / Retool lesson

OPS v1 / retained Retool remains Application-layer workflow evidence, not architecture authority.

Useful ideas to preserve where they match the actual job:

- simple operator mental models;
- explicit `Lưu`;
- fast text search;
- dense practical tables;
- direct Vietnamese task language;
- quick editing;
- practical exception handling;
- familiar export affordances.

Do not copy:

- direct browser SQL;
- JavaScript/local state as business authority;
- client-side calculation authority;
- hidden chained writes as transaction authority;
- implicit authorization;
- Retool component/layout structure as Atlas architecture.

A correct Atlas backend should make React comparatively boring.

## 17. Shared component rule

Do not prebuild a catalogue of components merely because one might be useful later.

Normalize or add shared primitives only when they have at least two real connected consumers or a legitimate shell-level purpose.

Likely recurring primitives include:

- `WorkbenchHeader`;
- `Panel` / `SectionPanel` only where a real surface boundary exists;
- `StatusChip`;
- one operational notice/state treatment;
- `ActionGroup`;
- `ConfirmationDialog` where multiple real commitment/destructive actions use it;
- a bounded table wrapper.

Evidence/timeline primitives should exist only when multiple workbenches genuinely need visible support-history treatment.

Reuse or evolve the existing shared module. Do not create parallel primitive families.

## 18. Review evidence

Each substantial UI-quality PR should publish:

- exact surfaces reviewed;
- first-user issue inventory and accepted deferred debt;
- exact changed-path manifest;
- shared components introduced or reused;
- text-search behavior where the workbench is table-oriented;
- visible Vietnamese labels materially changed;
- focused/regression test results;
- Storybook/UI Review Export result where applicable;
- responsive notes at 360/768/1280;
- keyboard/focus review;
- explicit business/API/contract delta.

For a UI-only task, zero backend delta is expected unless the Product review proves that the existing contract itself forces a false or confusing human workflow. In that case, stop the UI task and correct the business/backend boundary separately rather than hiding orchestration in React.

## 19. Certification scorecard

| Dimension | Acceptance |
| --- | --- |
| First-user comprehension | Job, scope, editable target, saved state and main action are obvious without architecture vocabulary. |
| Work context | Current business period/object/scope is visible and understandable. |
| Search | Table-oriented workbench has a fast useful text search/filter or a documented reason not to. |
| Action authority | Backend-provided eligibility is the maximum permission; React can only restrict further. |
| Action hierarchy | One meaningful business action dominates the normal state. |
| Operational states | Loading, empty, blocker, warning, stale, unknown and read-only states are clear when they occur. |
| Tables | Bounded, semantic and legible at reviewed widths. |
| Typography | Human-scale text/control proportions support sustained use. |
| Language | Vietnamese is natural, concise and business-accurate rather than translated backend terminology. |
| Evidence/history | Support detail is available when needed but does not compete with core work. |
| Accessibility | Keyboard, focus, labels, semantics, contrast and touch targets pass review. |
| Scope | No hidden client authority or unapproved business behavior is introduced. |
| Verification | Appropriate tests, build and visual review pass; green CI alone is not sufficient Product acceptance. |

## 20. Prohibited shortcuts

UI quality work must not:

- add browser-side authoritative calculations;
- infer capability from role names or lifecycle text;
- promote an action the backend did not authorize;
- duplicate backend-safe messages with conflicting client registries;
- automatically retry writes;
- chain backend lifecycle commands in React to simulate one business action;
- expose API workload limits as operator workflow;
- hide real blockers for visual cleanliness;
- make technical evidence part of the normal flow merely to prove it exists;
- use tiny text, excessive nested borders/cards or uniformly bold controls to compensate for unclear information hierarchy;
- add a UI framework, grid, global state library or CSS runtime without a separate accepted need;
- build a generic search/filter/export framework without proven consumers;
- polish unconnected downstream prototypes before their connected slices;
- redesign every module in one PR;
- silently modify SQL, migrations, RLS, RPCs or domain contracts inside a presentation-only task.

When a UI review reveals that the backend contract itself creates unnecessary human ceremony, stop and elevate that as a workflow/contract correction under OPS_SYSTEM_MAP rather than preserving a bad boundary for the sake of implementation convenience.

## 21. Workflow preservation and operator archetypes

ATLAS-UX-RESET-01 adds a required safeguard for established OPS v1 capabilities:

> **UI simplification may hide technical machinery, but it must never erase, bypass or redefine a real business boundary.**

For an established capability, do not redesign the workflow from first principles merely because Atlas can implement a cleaner backend lifecycle. Reconstruct the actual operator job first, identify real lock/immutability/commitment and correction boundaries, preserve them, and then improve the interaction.

Before freezing a UI or contract correction for an existing capability, inspect the retained workflow evidence for:

- normal operator sequence;
- read-only versus write surfaces;
- creation workflow;
- search/filter behavior;
- copy/import/export helpers;
- lock/immutability behavior;
- first operational use;
- Change Order / override / correction paths;
- live OPS functions/triggers where needed to verify an invariant.

The child report must classify changes as:

```text
workflow preserved
workflow improved
workflow intentionally changed
```

Any intentionally changed workflow requires explicit Product Owner approval. If evidence is ambiguous, raise the ambiguity rather than inventing a rule to keep coding.

Do not generalize one domain's successful interaction pattern into another domain without proving equivalent business semantics. `Edit → Save` in Planning and `Lưu → business commitment` in Confirmed Need are not universal Atlas templates.

Use the evidence-backed interaction archetypes in [Atlas Operator Workbench Patterns](atlas-operator-workbench-patterns.md) to frame Product design before component selection. The archetypes guide behavior; they do not authorize a generic React workbench framework.

From now on, the certification scorecard also requires **workflow fidelity**: an aesthetically simpler UI fails Product review if it changes a real business invariant, lock point, Change Order requirement, accountable human decision or operator responsibility without explicit approval.