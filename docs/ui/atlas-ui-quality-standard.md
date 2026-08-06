# Atlas UI Quality Standard

**Status:** Proposed cross-module UI contract

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Authority:** [ATLAS-ACT-01 Hosted Staging and UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

## 1. Purpose

This standard defines how existing Atlas capabilities should look and behave before operator rehearsal.

It does not authorize new business capabilities, APIs, lifecycle states, calculations or persistence.

Atlas is a compact daily operations workbench, not a presentation dashboard. A polished Atlas screen must help an operator answer:

- what object or period am I working on;
- what is the authoritative current state;
- what requires attention;
- what action is available to me;
- what will the action change;
- what evidence and history already exist;
- what should I do when data is stale, blocked or uncertain.

## 2. Governing principles

1. **Business state is backend-owned.** React displays authoritative state and may hold local drafts; it does not infer lifecycle authority from presentation details.
2. **One current state.** Current lifecycle/status messaging is mutually exclusive. Historical events appear in a separate history treatment.
3. **Exception first.** Blocking issues and required actions are easier to find than successful background detail.
4. **Dense but bounded.** Operational tables may be dense, but they live inside scrollable bounded regions and do not force page-wide horizontal overflow.
5. **Consistent action hierarchy.** Primary, secondary, destructive and navigation actions have stable meaning across modules.
6. **Vietnamese operator language.** Labels are concise, consistent and operationally recognizable. Technical IDs remain available where they support audit or support work.
7. **Accessible by default.** Keyboard, focus, semantic labels, contrast and live feedback are part of acceptance, not later cleanup.
8. **No hidden automatic retry.** Unknown write outcomes require authoritative refresh before a new command.
9. **No visual rewrite of authority.** UI polish cannot change backend contracts, eligibility, quantities or immutable evidence.
10. **Local primitives first.** The first program uses existing React, CSS and Storybook. No external UI framework is introduced.

## 3. Visual foundation

### 3.1 Tokens

UI-QUALITY-01 should define local CSS custom properties for:

- font families and a small type scale;
- page, section and inline spacing;
- border radii;
- border and divider treatment;
- surface elevation;
- control heights;
- focus outline;
- text, muted text and disabled text;
- neutral, information, success, warning and danger semantics;
- table row, header and selection states;
- maximum content widths and responsive breakpoints.

Tokens describe semantic purpose rather than module names.

Do not encode lifecycle or business meaning only through color.

### 3.2 Typography

Use a restrained hierarchy:

- application title;
- page/workbench title;
- section title;
- body and table text;
- supporting metadata;
- code/ID treatment where needed.

Avoid multiple competing large headings inside one workbench. Table and form text must remain legible at operational density.

### 3.3 Page structure

A standard workbench uses:

```text
environment / prototype banner where applicable
→ page or workbench header
→ context and period controls
→ authoritative status and exception summary
→ primary workspace
→ details, evidence and history
→ secondary or support actions
```

Sticky regions must not cover content or trap keyboard focus.

## 4. Shared component contract

UI-QUALITY-01 should establish or normalize these reusable local components.

### 4.1 `WorkbenchHeader`

Required roles:

- title and concise description;
- environment/source indicator where relevant;
- authoritative current status;
- optional period/object identity;
- primary and secondary action slots.

### 4.2 `Panel` / `SectionPanel`

Required behavior:

- semantic heading relationship;
- optional summary and action area;
- predictable padding and divider treatment;
- no nested-card proliferation.

### 4.3 `StatusChip`

Required behavior:

- semantic status category plus text;
- accessible label independent of color;
- consistent sizes;
- no business eligibility inferred from chip appearance.

### 4.4 `NoticeBanner`

Types:

```text
information
success
warning
blocking
unknown_outcome
```

Required behavior:

- concise title/message;
- optional next action;
- appropriate live-region behavior;
- no raw database, Auth or transport diagnostics.

### 4.5 `ActionGroup`

Required hierarchy:

- one primary action per local decision context where practical;
- secondary actions visually subordinate;
- destructive actions separated and confirmed;
- disabled actions accompanied by backend-safe reason where available;
- busy state prevents duplicate submission;
- action labels use verbs and the business object.

### 4.6 `FormField`

Required behavior:

- label, control, help text and field error association;
- required state visible to assistive technology;
- no placeholder-only labels;
- local draft and authoritative saved state distinguishable.

### 4.7 `ConfirmationDialog`

Required behavior:

- focus moves into and returns from the dialog;
- action consequence is explicit;
- irreversible or commitment-producing actions name the object and scope;
- cancel remains available unless the operation is already in flight;
- no command is submitted on opening the dialog.

### 4.8 `ResponsiveTable`

Required behavior:

- semantic table headers;
- bounded horizontal scrolling when necessary;
- sticky columns only for stable identity/source fields;
- row focus/selection remains visible;
- numeric columns align consistently;
- empty and loading states do not render fake rows;
- narrow layouts may reveal a row-detail view rather than hide critical data.

### 4.9 `EvidenceSummary`

Use for:

- Actor and timestamp;
- version and snapshot identity;
- warning/blocker counts;
- source and lineage summaries.

Evidence is grouped, compact and copyable where support work needs exact IDs.

### 4.10 `LifecycleTimeline`

Required behavior:

- immutable history separate from current status;
- newest-first or oldest-first ordering explicitly consistent within Atlas;
- Actor, time, source/resulting version and reason visible where returned;
- technical event kinds may have Vietnamese display labels while retaining exact codes in detail.

### 4.11 `EmptyState`, `LoadingState`, `ReadOnlyState`, `ErrorState`

These states use stable language and layout. A blank panel is not an acceptable state treatment.

## 5. State presentation

### 5.1 Loading

- Preserve stable layout where practical.
- State what is loading.
- Do not show stale actions as available while authoritative eligibility is unknown.

### 5.2 Empty

Distinguish:

- no object selected;
- no records for the selected period/filter;
- object exists but has zero legitimate lines;
- missing prerequisite or blocked source.

### 5.3 Blocking

Blocking issues appear before warnings and normal detail.

Each issue should expose:

- safe operator message;
- affected object or line;
- responsible workspace or next action when known;
- technical code in support detail where useful.

### 5.4 Warning

Warnings are visible but do not visually imitate blockers. The UI does not invent acknowledgement requirements.

### 5.5 Stale version

A stale response:

- preserves local draft only where the API contract allows it;
- explains that authoritative data changed;
- offers refresh, not automatic write replay;
- removes or disables actions based on stale readback.

### 5.6 Unknown write outcome

An unknown outcome:

- states that completion is uncertain;
- removes command actions until authoritative refresh;
- never automatically retries;
- does not claim success or failure;
- preserves no sensitive transport diagnostic in visible UI.

### 5.7 Read-only

Read-only state identifies why editing is unavailable:

- lifecycle complete;
- capability denied;
- stale or unknown outcome;
- archived/history view;
- prerequisite missing.

Read-only must not look like a broken form.

## 6. Action and dialog language

Action labels use:

```text
verb + business object or consequence
```

Examples already accepted include:

- `Kiểm tra toàn bộ`
- `Phê duyệt lô nhu cầu`
- `Phát hành sang bước lên đơn`

Avoid generic labels such as `OK`, `Xử lý`, `Lưu dữ liệu` or `Submit` where a specific action is known.

Confirmation text must state when an action does not perform a likely downstream consequence. For example, Confirmed Need release states that it does not select suppliers or create purchase orders.

## 7. Tables and operational density

Table layout follows this order when applicable:

```text
source / trace identity
→ operational object identity
→ quantities and status
→ exceptions and decisions
→ Actor, evidence and timestamps
```

Guidelines:

- source and stable identity fields may remain sticky;
- quantities use controlled precision and unit labels;
- status uses text plus semantic treatment;
- actions do not occupy multiple competing columns;
- support metadata may move to row detail on narrow screens;
- filters and group summaries remain associated with the table they affect;
- row selection is not used as hidden command scope unless the backend contract explicitly supports partial actions.

## 8. Language, date and quantity standards

### 8.1 Language

- Operator UI is Vietnamese.
- Domain terms follow approved contracts and current operator terminology.
- Acronyms are expanded where users may not know them.
- Technical contract names and codes appear in support/evidence detail, not as the primary label.

### 8.2 Dates and time

- User-facing dates use `dd/mm/yyyy`.
- User-facing timestamps use Vietnamese locale and include time when operationally relevant.
- The source timezone must be consistent with the application contract.
- ISO timestamps may be shown in copyable technical detail, not as the sole display.

### 8.3 Quantities

- Display precision follows backend-controlled Unit and policy evidence.
- Do not round differently in separate components.
- Values and Unit remain visually adjacent.
- Zero, missing and unavailable are distinct states.

## 9. Responsive behavior

Minimum review widths:

```text
360 px
768 px
1280 px
```

Acceptance rules:

- no page-wide horizontal overflow at 360 px;
- tables may scroll inside their own wrapper;
- critical current status and primary action remain discoverable without horizontal scrolling;
- dialogs fit within the viewport and remain keyboard reachable;
- navigation and filters remain usable by touch;
- sticky elements do not consume most of the narrow viewport;
- large-screen layouts do not stretch line length or control groups without bound.

## 10. Accessibility contract

Every UI quality PR must review:

- semantic page and section headings;
- form labels and error associations;
- keyboard reachability and order;
- visible focus;
- dialog focus entry/return;
- button names and busy/disabled state;
- live regions for result notices;
- table header relationships;
- contrast and non-color status cues;
- reduced-motion compatibility for any animation;
- meaningful empty/loading/error text.

Automated checks are supporting evidence, not a replacement for keyboard review.

## 11. Storybook and review evidence

Shared primitives require Storybook stories covering at least:

- normal;
- disabled/read-only;
- warning/blocking;
- long Vietnamese text;
- narrow container;
- keyboard/focus-relevant dialog state.

Module quality PRs require:

- focused component tests;
- unchanged or intentionally updated existing behavior tests;
- UI Review Export;
- screenshots or review notes at the three minimum widths;
- exact list of business/API/migration files changed, expected to be zero.

## 12. Acceptance scorecard

A workbench is UI-certified only when:

| Dimension | Acceptance |
| --- | --- |
| Current state | Exactly one authoritative current-state treatment. |
| Action authority | Backend-provided allowed/disabled behavior; no status-only inference. |
| Errors | Loading, empty, blocked, warning, stale, unknown and read-only states are explicit. |
| Actions | Primary/secondary/destructive hierarchy is consistent. |
| Tables | Bounded, semantic, legible and usable at reviewed widths. |
| Language | Vietnamese labels, dates and domain terms are consistent. |
| Accessibility | Keyboard, focus, labels, semantics and contrast pass review. |
| Evidence | Actor/time/version/history are presented consistently. |
| Scope | No unapproved business or backend behavior changed. |
| Verification | Storybook, tests, build and UI Review Export pass. |

## 13. Prohibited shortcuts

UI quality work must not:

- add browser-side authoritative calculations;
- infer capability from visible role names;
- enable commands from lifecycle text alone;
- duplicate safe backend messages with conflicting client registries;
- automatically retry writes;
- hide blockers to make a page appear cleaner;
- remove audit IDs or evidence needed for support;
- add a UI framework, global state library or table library without a separate accepted decision;
- redesign all modules in one PR;
- modify SQL, migrations, RLS, RPCs or domain contracts to simplify styling.