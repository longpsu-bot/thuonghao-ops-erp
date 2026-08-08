# TASK-UI-QUALITY-02B — Planning Input Readiness + Need Generation

## Delivery identity

- Status: workflow-first correction implemented and under draft-PR review
- Existing draft PR: `#181`
- Exact baseline: `4a585f980464e4367a0b23ea6184ecf10fd70003` (PR #180)
- Branch: `codex/ui-quality-02b-readiness-need-generation`
- Head history: original UI-QUALITY-02B head `1ef54e8b11cb3cd91a40ce5f9e762b1fa4db5164`; the workflow-first correction commit is recorded by PR #181 and the completion report because a commit cannot contain its own final hash
- Accepted Application decision: [D-035 — Atlas Workflow-First Operator UX](../decisions/decision-atlas-workflow-first-operator-ux.md)
- Scope: Planning Input Readiness, Need Generation, and minimum outer Planning navigation safety only
- UI-QUALITY-02C Confirmed Need consolidation: not started

## Exact PR changed paths

1. `docs/architecture/roadmap.md`
2. `docs/decisions/decision-atlas-workflow-first-operator-ux.md`
3. `docs/decisions/decision-register.md`
4. `docs/implementation-tasks/TASK-UI-QUALITY-02B-readiness-need-generation.md`
5. `docs/ui/atlas-ui-quality-standard.md`
6. `src/modules/atlas/AtlasApp.stories.tsx`
7. `src/modules/atlas/AtlasApp.test.tsx`
8. `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
9. `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
10. `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx`
11. `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.tsx`
12. `src/modules/atlas/planning-inputs/need-generation/PlanningInputsNeedGenerationTab.test.tsx`
13. `src/modules/atlas/planning-inputs/readiness/PlanningInputReadinessWorkbench.test.tsx`
14. `src/modules/atlas/planning-inputs/readiness/PlanningInputReadinessWorkbench.tsx`
15. `src/styles.css`

No API, model, read-model, review-adapter, Supabase, script, dependency, Retool, Confirmed Need or other new path is changed.

## Feature-triage inventory

Each visible element has exactly one D-035 category.

| Surface | Visible element | Category | Presentation decision |
| --- | --- | --- | --- |
| Readiness | selected Planning week and exact inclusive period | A — Core work | Default visible first. |
| Planning wrapper | legacy two-source reference banner | A — Core work for source tabs | Remains on Menu, Attendance and Pantry; hidden on Readiness, Need Generation and Confirmed Need so it cannot compete with the authoritative current workflow. |
| Readiness | current answer: ready, needs attention or not checked | A — Core work | One plain-language decision area. |
| Readiness | Menu, Attendance and Pantry summaries | A — Core work | Exactly three default-visible source cards; period, state and useful approved version remain. |
| Readiness | blockers and warnings | A — Core work | Visible only when returned; blockers precede warnings. |
| Readiness | one Evaluate or Request action | A — Core work | Exactly one button when exactly one backend action is allowed. |
| Readiness | ambiguous candidate choice | B — Safety guardrail | Candidate selector appears only for `AMBIGUOUS`. |
| Readiness | missing/stale source state and disabled reason | B — Safety guardrail | Contextual, plain-language attention state; no disabled future command. |
| Readiness | unsaved candidate discard and `beforeunload` warning | B — Safety guardrail | Visible only on a realistic dirty transition. |
| Readiness | unexpected multiple forward actions | B — Safety guardrail | Fail closed with refresh guidance; no precedence is invented. |
| Readiness | exact retry / unknown outcome recovery | C — Exception / recovery | Appears only after the corresponding result; command ID is inside technical detail. |
| Readiness | invalidation reason and note | C — Exception / recovery | Backend-authorized only, under `Thao tác khác`. |
| Readiness | custom exact-period inputs | C — Exception / recovery | Preserved under `Đổi phạm vi đánh giá`; the outer week remains normal context. |
| Readiness | approval Actor/time, line count and snapshot identity | D — Audit / support | Moved under each card's `Chi tiết bằng chứng`. |
| Readiness | Planning Input Set and evaluation IDs/version | D — Audit / support | Available under `Chi tiết kỹ thuật`. |
| Readiness | immutable evaluation/request/invalidation history | D — Audit / support | Retained, collapsed by default. |
| Readiness | “authoritative/PostgreSQL/binding” explanations | E — Technical implementation detail | Removed from normal operator wording. |
| Need Generation | selected period and current plain-language state | A — Core work | Default visible first. |
| Need Generation | prerequisite blocker or current run blocker/warning | A — Core work | Contextual; blockers precede warnings. |
| Need Generation | filters and grouped requirements table | A — Core work | Filters stay attached; the table remains the dominant post-run surface. |
| Need Generation | one Create, Validate, Release or Confirmed Need action | A — Core work | Exactly one button when exactly one backend action is allowed. |
| Need Generation | row contribution detail | D — Audit / support | Discoverable from the row as `Chi tiết hình thành số lượng`; not a page-level concept. |
| Need Generation | invalidation | C — Exception / recovery | Backend-authorized only, under `Thao tác khác`. |
| Need Generation | exact retry / unknown outcome recovery | C — Exception / recovery | Appears only after an uncertain or retryable result, with no automatic retry. |
| Need Generation | custom period controls | C — Exception / recovery | Preserved under `Đổi phạm vi xem`. |
| Need Generation | attempt ordinal | D — Audit / support | A small run reference; it does not become a KPI card. |
| Need Generation | run version, detailed line count, input versions and technical IDs | D — Audit / support | Moved under `Chi tiết đầu vào và lần tạo`. |
| Need Generation | run history | D — Audit / support | Retained and collapsed by default. |
| Need Generation | Confirmed Need ID | D — Audit / support | Available only in technical detail after materialization. |
| Need Generation | four-stage lifecycle control panel and disabled future commands | E — Technical implementation detail | Removed from the normal UI. Backend lifecycle and commands remain unchanged. |
| Need Generation | “atomic/backend/materialization architecture” teaching text | E — Technical implementation detail | Replaced by plain business wording or kept only in support detail. |

## OPS v1 / Retool workflow evidence

The retained repository evidence shows a practical operator pattern: familiar Vietnamese task vocabulary, direct navigation, table-centred work, useful density, attached filters and immediate explicit actions. Atlas keeps those strengths. It does not copy Retool SQL, browser state authority, calculation, authorization, database ownership, component hierarchy or visual styling.

Atlas adds controlled readiness, immutable evidence, exact retry and correction history because they materially protect data integrity and auditability. D-035 makes them low-friction: Readiness is a checkpoint, one action advances the happy path, exception controls are contextual, and audit identity is available without becoming prerequisite reading.

## Readiness simplification and outer-week correction

The normal hierarchy is now:

```text
selected week / exact period
→ plain current answer
→ Menu + Attendance + Pantry summaries
→ blockers, then warnings when present
→ one backend-authorized next action
→ contextual correction and audit detail
```

The previous separate decision, duplicate disabled-reason and action panels were consolidated. Technical IDs, approval detail and custom dates no longer interrupt the ordinary scan. Ambiguity remains prominent only when it exists.

`PlanningInputReadinessWorkbench` now observes later `selectedWeekStart` / `selectedWeekEnd` changes while mounted. After the parent permits a week change, the child adopts the exact new period, invalidates late local reads/commands, clears unevaluated candidate selection and pending local command state, resets local correction fields, reports clean state to the parent and rereads authority. It never asks for a second discard confirmation. Focused coverage proves clean change, dirty rejected change and dirty confirmed change.

## Need Generation simplification

Before a run, the surface contains the period, prerequisite/current state, relevant blockers and one Create action. It does not show table filters, empty run metadata, materialization education or future lifecycle commands.

After a run, the surface contains plain current state, blockers/warnings, attached filters, the dominant grouped table and one next action. Validate, Release and Confirmed Need creation appear only when each is the sole backend-allowed forward command. A blocked expected action shows only its useful backend reason. Any unexpected multiple-forward-action combination fails closed and asks for refresh.

Materialization text appears only when `Tạo nhu cầu xác nhận` is the current action or has occurred. It says the released result moves to `Xác nhận nhu cầu` and does not yet order goods or select suppliers. Invalidation remains under `Thao tác khác`; history remains collapsed; exact retry appears only after uncertainty.

## Overengineering findings

| Atlas-only feature | Operator problem solved | Frequency | If hidden by default | Final placement | Architecture teaching risk |
| --- | --- | --- | --- | --- | --- |
| Readiness checkpoint | prevents generation from unapproved/missing inputs | every cycle | operator could advance without understanding readiness | core UI, simplified | low after reset |
| Source candidate selection | prevents silent choice among multiple approvals | rare | ambiguous work cannot be completed safely | contextual guardrail | low |
| Exact-period override | supports approved non-week periods | uncommon | weekly happy path unaffected | progressive disclosure | low |
| Invalidation | corrects a governed result without rewriting history | exceptional | normal work unaffected | contextual recovery | low |
| Exact retry / unknown outcome | prevents duplicate or assumed writes | exceptional | unsafe only after transport/concurrency uncertainty | contextual recovery | low |
| Snapshot/root/run identities | supports audit and support investigation | uncommon | ordinary work unaffected | audit detail | high if foregrounded; now demoted |
| Run lifecycle sequence | explains backend governance | never required as a four-control UI | ordinary operation becomes simpler | removed from normal UI | high; removed |
| Atomic contribution evidence | explains quantity lineage | occasional row investigation | table review remains complete | row detail | medium; renamed plainly |
| Materialization boundary | prevents mistaken belief that purchasing occurred | once at final action | risk exists only near/after the action | contextual consequence | low after contextualization |

No feature or backend evidence was deleted. The correction changes information priority only.

## Happy-path walkthrough

| Step | What the user sees first | What the user understands | What the user should do | Possible confusion after reset |
| --- | --- | --- | --- | --- |
| Weekly Menu approved | approved source state in the existing Menu tab | Menu is complete for the selected week | continue to Attendance | none introduced by 02B |
| Attendance approved | approved Attendance state for the same week | portions are ready | continue to Pantry | none introduced by 02B |
| Pantry approved | positive or explicit-zero Pantry evidence | Pantry input is complete | open Readiness | none introduced by 02B |
| Readiness not evaluated | week, `Chưa kiểm tra đầu vào`, three sources, one Evaluate action | this is a quick checkpoint | `Đánh giá mức sẵn sàng` | custom period remains available but subordinate |
| Readiness ready | `Đầu vào đã sẵn sàng`, three sources, one Request action | all inputs can move forward | `Yêu cầu tạo nhu cầu` | no architecture term is required |
| Need Generation before run | week, `Sẵn sàng tạo nhu cầu`, one Create action | prerequisite handoff is complete | `Tạo nhu cầu` | none |
| Generated | `Đã tạo — cần kiểm tra`, table, one Validate action | review rows, then check result | review table; `Kiểm tra nhu cầu` | row detail is optional support |
| Validated | `Đã kiểm tra — có thể phát hành`, table, one Release action | result can be committed to the next Planning step | `Phát hành nhu cầu` | none |
| Released | `Đã phát hành — có thể tạo nhu cầu xác nhận`, concise consequence, one action | next action creates review work, not an order | `Tạo nhu cầu xác nhận` | downstream boundary is stated once, contextually |
| Materialized | `Đã chuyển sang Xác nhận nhu cầu` and concise consequence | this has not ordered goods | continue in Confirmed Need later | UI-QUALITY-02C remains separate |

## Comprehension tests

- Five-second test: every normal state exposes the week, one plain current state, relevant blocker/absence, and one next action without opening support detail or reading IDs.
- First-time-operator test: no normal action requires understanding Planning Input Set, snapshot, immutable evaluation, source binding, command receipt, atomic contribution or materialization terminology.
- One-next-action test: a forward command renders only when it is the sole backend-allowed action. Future commands are absent. Multiple allowed forward actions are treated as an unexpected fail-closed response, not client precedence.
- Commands remain explicit Vietnamese text with decorative regular-outline icons; no business action is icon-only.

## Responsive and rendered review

The complete flow was rendered through Storybook at 360 px, 768 px and 1280 px. The 360 px review used browser device-metric emulation and confirmed `documentElement.scrollWidth <= innerWidth`; only the six-tab strip and generated-requirements table retain intentional local horizontal scrolling.

- 360 px: the mobile shell, period, current answer, contextual ambiguity, source cards and single action stack in reading order. Buttons and selectors use the available width, text wraps, and technical/audit detail stays closed.
- 768 px: Readiness blockers and Need Generation blockers remain scannable; generated requirements keep a bounded local table scroll; the materialization callback lands in the existing Confirmed Need tab without the legacy source banner competing above it.
- 1280 px: the exact period and current answer lead; three source cards scan as a row; the grouped requirements table is the dominant post-run object; support detail remains visibly subordinate.
- Keyboard-visible focus, explicit Vietnamese action labels, 44 px mobile action targets, regular-outline icons and native disclosure semantics remain intact.

| Review lens | Verdict | Evidence |
| --- | --- | --- |
| Architecture / authority | PASS | Backend actions, disabled reasons, quantities and lifecycle remain authoritative. |
| Product / workflow | PASS | The happy path reads as checkpoint → request → create → review → validate → release → Confirmed Need. |
| Readability | PASS | Plain current states precede supporting detail at every reviewed width. |
| Intuitiveness | PASS | One contextual next action is exposed; future commands are absent. |
| Cognitive load | PASS | Audit IDs, histories, custom periods and correction controls are progressively disclosed. |
| Layout | PASS | No page-level overflow at 360, 768 or 1280 px; wide operational tables and tabs scroll locally. |
| Visual design | PASS | D-034 hierarchy, spacing, surfaces, semantic color and regular-outline icon language are preserved. |
| Accessibility / usability | PASS | Explicit labels, focus treatment, target sizing, semantic headings and disclosure controls remain usable. |
| Overengineering | APPROPRIATELY SIMPLE | The checkpoint and audit controls remain, while the lifecycle control panel and architecture teaching are removed from normal work. |
| Implementation | PASS WITH DEBT | The bounded code is tested; the existing production bundle-size warning remains cross-cutting debt outside UI-QUALITY-02B. |

No unresolved UI-QUALITY-02B workflow debt was found in the rendered happy path. The unchanged Confirmed Need workbench still carries its pre-02C information density and technical wording; that is explicitly deferred to UI-QUALITY-02C rather than altered here.

## Authority and safety

- Backend `allowed_actions` and disabled reasons remain the only eligibility authority.
- React does not calculate readiness, candidate ranking, grouping, quantities, Recipe selection or materialization behavior.
- Retryable and uncertain writes retain the exact request and never retry automatically.
- Stale results clear eligibility and reread authority; late-response protection remains.
- All Phosphor icons touched by UI-QUALITY-02B use the D-034 regular-outline default.

## Validation and CI history

- Workspace verification: passed on the canonical repository and existing PR branch.
- Formatting: passed.
- Typecheck: passed.
- Focused Planning / Readiness / Need Generation validation: 9 files and 55 tests passed, including outer-week clean/rejected/confirmed transitions, backend-authorized one-next-action behavior, subordinate technical detail, contextual recovery and the two owner-authorized integration assertion updates.
- Full frontend suite: 70 files and 456 tests passed.
- Production build: passed; the pre-existing chunk-size warning remains.
- Review build: passed; the pre-existing chunk-size warning remains.
- Storybook/UI Review build: passed; the pre-existing chunk-size warning remains.
- Rendered workflow review: passed at true 360 px device metrics, 768 px and 1280 px.
- `git diff --check`: passed.
- Original head `1ef54e8b11cb3cd91a40ce5f9e762b1fa4db5164`: Frontend CI passed; UI Review Export passed; Qodana passed; Supabase Smoke passed; Supabase Full Integration skipped while draft.
- Workflow-reset head: local validation is complete; the exact pushed head and its current GitHub check state are reported in the completion report because the commit cannot record its own hash or post-push check state.

## Delta and deferred scope

- Dependency delta: zero
- Business/API/model/read-model/calculation delta: zero
- Lifecycle/permission delta: zero
- Supabase/hosted-data delta: zero
- Retool delta: zero
- Migration/rollback effect: none; rollback is a normal Git revert of presentation/documentation changes
- UI-QUALITY-02C: not started
- Merge/deployment: not authorized
