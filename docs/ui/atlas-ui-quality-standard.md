# Atlas UI Quality Standard

**Status:** Proposed cross-module UI contract

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Authority:** [ATLAS-ACT-01 Hosted Staging and Connected-UI Consolidation Contract](../architecture/atlas-act-01-hosted-staging-ui-consolidation-contract.md)

## 1. Purpose

This standard defines the minimum quality required for the existing connected Atlas UI before operator rehearsal.

It does not authorize new business capabilities, APIs, lifecycle states, calculations, persistence or client-owned authority.

A usable workbench must make these answers obvious:

- what object or period is being handled;
- what the authoritative current state is;
- what requires attention;
- what action is currently allowed;
- what that action will change;
- what evidence and history already exist;
- what the operator should do when the result is stale, blocked or uncertain.

## 2. Principles

1. **Backend-owned authority.** React displays lifecycle, eligibility, quantities and safe messages returned by the backend.
2. **One current state.** Historical events never compete with the current lifecycle message.
3. **Exception first.** Blockers and required actions are easier to find than successful background detail.
4. **Dense but bounded.** Operational tables may be dense but must not force page-wide horizontal overflow.
5. **Stable action hierarchy.** Primary, secondary, destructive and navigation actions have consistent meaning.
6. **Vietnamese operator language.** Labels are concise and familiar; technical codes stay available in support detail.
7. **Accessible interaction.** Keyboard, focus, semantics, contrast and live feedback are acceptance requirements.
8. **No automatic write retry.** Unknown outcomes require authoritative refresh.
9. **No visual rewrite of business contracts.** UI work preserves API and lifecycle behavior.
10. **No speculative design system.** A shared abstraction needs two real current consumers, except shell-level primitives.

## 3. Minimal visual foundation

UI-QUALITY-01 should define semantic CSS custom properties for:

- a small type scale;
- spacing and control heights;
- radii, borders and surfaces;
- focus outline;
- text, muted and disabled text;
- information, success, warning, blocking and unknown-outcome semantics;
- table header, row and selection states;
- content width and responsive breakpoints.

Tokens describe purpose, not module names. Business meaning must not rely on color alone.

A standard workbench follows:

```text
environment/prototype notice where applicable
→ workbench header and context
→ authoritative status and exception summary
→ primary workspace
→ evidence and history
→ secondary/support actions
```

## 4. Shared component rule

Do not prebuild a catalogue of components merely because one might be useful later.

UI-QUALITY-01 may normalize or add only components already repeated in at least two connected surfaces, plus shell-level components. Likely candidates are:

- `WorkbenchHeader`;
- `Panel` or `SectionPanel`;
- `StatusChip`;
- `NoticeBanner` or one `OperationalState` component with variants;
- `ActionGroup`;
- `ConfirmationDialog`;
- `ResponsiveTable` wrapper;
- `EvidenceSummary`;
- `LifecycleTimeline` only if two current workbenches adopt it.

Loading, empty, blocking, stale, unknown-outcome, read-only and access-denied presentation may be variants of one operational-state component rather than separate component families.

Reuse or evolve the existing shared module. Do not create parallel primitive families.

## 5. State presentation

### Loading

- Preserve layout where practical.
- State what is loading.
- Hide or disable commands while authoritative eligibility is unknown.

### Empty

Distinguish:

- no object selected;
- no records for the filter or period;
- a valid zero-line state;
- a missing prerequisite or blocked source.

### Blocking and warnings

Blockers appear before warnings. Each issue shows a safe message, affected object/line and next workspace or action when known. Warnings remain visible but do not look like blockers.

### Stale

A stale result explains that authoritative data changed and offers refresh. Local draft is preserved only when the API contract permits it. No write is replayed automatically.

### Unknown write outcome

The UI states that completion is uncertain, disables further mutation and requires authoritative refresh. It claims neither success nor failure and exposes no raw credential, SQL or transport diagnostic.

### Read-only

Read-only state explains whether editing is unavailable because of lifecycle, capability, stale/unknown outcome, archived history or missing prerequisite. It must not look like a broken form.

## 6. Actions and confirmation

Action labels use a specific verb and business object or consequence.

Accepted examples include:

- `Kiểm tra toàn bộ`;
- `Phê duyệt lô nhu cầu`;
- `Phát hành sang bước lên đơn`.

Rules:

- use one primary action per local decision context where practical;
- keep secondary actions subordinate;
- separate and confirm destructive or commitment-producing actions;
- show backend-safe disabled reasons when available;
- busy state prevents duplicate submission;
- opening a confirmation never submits the command;
- focus enters and returns from dialogs correctly;
- consequence text states when a likely downstream action does **not** occur.

## 7. Tables and operational density

Tables should order information as:

```text
stable/source identity
→ operational object identity
→ quantities and state
→ exceptions and decisions
→ Actor, evidence and time
```

Requirements:

- semantic headers;
- bounded horizontal scrolling;
- sticky columns only for stable identity where useful;
- visible row focus/selection;
- aligned numeric values and adjacent Units;
- explicit loading and empty states, not fake rows;
- critical status and primary action remain discoverable without table scrolling;
- narrow layouts may use row detail for support metadata instead of hiding critical data.

Do not add a third-party grid or virtualizer in this phase.

## 8. Language, date and quantity

- Operator UI is Vietnamese.
- User-facing dates use `dd/mm/yyyy`.
- Timestamps include time when operationally relevant and use the application timezone consistently.
- ISO values may appear in copyable support detail, not as the only display.
- Quantity precision follows backend Unit/policy evidence.
- Zero, missing and unavailable are distinct.
- Values and Unit remain visually adjacent.

## 9. Responsive and accessibility acceptance

Review widths:

```text
360 px
768 px
1280 px
```

Acceptance requires:

- no page-wide horizontal overflow at 360 px;
- dialogs fit and remain keyboard reachable;
- navigation and filters remain usable by touch and keyboard;
- sticky elements do not consume most of a narrow viewport;
- visible focus and logical keyboard order;
- semantic headings, labels and table headers;
- field errors associated with controls;
- non-color status cues and adequate contrast;
- result notices use appropriate live-region behavior;
- reduced-motion compatibility for any animation.

Automated checks support but do not replace keyboard review.

## 10. Review evidence

Shared primitives need focused stories or fixtures for the states they actually support, including long Vietnamese text and narrow containers.

Each UI-quality PR must publish:

- exact surfaces reviewed;
- issue inventory and accepted deferred debt;
- exact changed-path manifest;
- shared components introduced or reused;
- focused and regression test results;
- Storybook/UI Review Export result where applicable;
- responsive notes at 360/768/1280;
- keyboard/focus review;
- explicit zero business migration/API/contract delta.

## 11. Certification scorecard

| Dimension | Acceptance |
| --- | --- |
| Current state | Exactly one authoritative current-state treatment. |
| Action authority | Backend-provided eligibility and disabled reason. |
| Operational states | Loading, empty, blocker, warning, stale, unknown and read-only are explicit. |
| Actions | Primary/secondary/destructive hierarchy is consistent. |
| Tables | Bounded, semantic and legible at reviewed widths. |
| Language | Vietnamese labels, dates and domain terms are consistent. |
| Accessibility | Keyboard, focus, labels, semantics and contrast pass review. |
| Evidence | Actor, time, version and history are presented consistently. |
| Scope | No unapproved backend or business behavior changed. |
| Verification | Tests, build and visual review pass. |

## 12. Prohibited shortcuts

UI quality work must not:

- add browser-side authoritative calculations;
- infer capability from role names or lifecycle text;
- duplicate backend-safe messages with conflicting client registries;
- automatically retry writes;
- hide blockers for visual cleanliness;
- remove support evidence needed for audit;
- add a UI framework, grid, global state library or CSS runtime without a separate accepted decision;
- polish unconnected downstream prototypes before their connected slices;
- redesign every module in one PR;
- modify SQL, migrations, RLS, RPCs or domain contracts to simplify presentation.
