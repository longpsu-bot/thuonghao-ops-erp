# Atlas Autopilot — Active Task

Task: **ATLAS-UX-ART-DIRECTION-02**  
Status: **ACTIVE — OWNER-SELECTED C / BOUNDED UI IMPLEMENTATION**  
Product authorization: **16 October 2026** — Owner explicitly redirected priority from overextended Autopilot/backend work to Atlas UX/UI design.  
Source: [approved GitHub Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389) and [execution brief](../implementation-tasks/TASK-ATLAS-UX-ART-DIRECTION-02.md).  
Starting main at transition: `d102b2f1b083005d6553867fa5ccdf8c988a0316`. Re-read current `origin/main` before task execution.

## Product priority and work authorization

**16 October 2026 — Owner selected C and explicitly authorized implementation.** The D1/D2 selection gate is satisfied by [Draft #391](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/391), head `6ac8f388ce14bc991058371e1232b094e733f6b3`. Implement only connected sloped tabs and supplier-rail PO presentation under the [bounded C scope](../ui/atlas-c-workspace-po-implementation.md). Preserve real thirteen-owner state, API clients, business guards, immutable documents and export semantics. Backend/Warehouse and #385–#388 remain parked. No merge or deployment is authorized.

**Stop creating additional backend performance/certification, Warehouse, or general cutover work merely to advance Autopilot.** Concentrate on making Atlas genuinely legible, efficient, aesthetically polished and practical for staff. This transition **supersedes Issue #389's older “wait until all #385–#388 are closed” start condition**: the design phase may proceed NOW while those existing Drafts are preserved. It does **not** approve their merges, alter their source code, or claim their business behavior is deployed.

Authoritative business and security boundaries remain unchanged: `OPS_SYSTEM_MAP v1.0`, **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**, Chakra UI v3, thirteen persistent workbench owners, current Planning/Procurement contracts and immutable released documents.

### Current parallel work — PARKED, not discarded

- [#385](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/385): login/PO states/XLSX wrapping, Draft, review/integration later.
- [#386](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/386): human Unit labels and draft School evidence, Draft, migration not deployed.
- [#387](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/387): bulk supplier allocation, Draft, migration not deployed.
- [#388](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/388): post-release Need correction, **INCOMPLETE Draft** with genuine 250-family multi-cycle performance failure. No forced success, CI weakening, merge, Staging deployment, additional performance cycle or runtime follow-up under this active design task.
- Older UI prototype Drafts remain archival references, not automatic implementation candidates.

Do not reset/delete local worktrees, commits, stashes, branches or PRs. Before any integration of these branches, independently assess compatibility and exact-head tests. **Do not wait for them to merge before producing design alternatives.**

## Bounded execution: two design deliverables

### Checkpoint D1 — skills, genuine current UI review, and design diagnosis

1. Verify the canonical local checkout in accordance with `AGENTS.md` (remote, clean worktree, current main, `pnpm ops:workspace`). If no authenticated local Codex/desktop runner is available, stop at GitHub handoff; do not claim that local implementation began.
2. Inspect the current Chakra application source and rendered populated workbenches, especially `src/vnext/atlas/AtlasVNextShell.tsx`, `src/vnext/atlas/procurement/ProcurementOrdersStage.tsx` and Procurement Allocation, plus existing UI agents and `.agents/skills`.
3. Audit external design skills by reviewing source/license/scripts/security. Prefer Anthropic Frontend Design, Emil Design Engineering, Impeccable and Vercel Web Design Guidelines as distinct creative/finishing/review inputs. Anthropic Design Plugin is **Claude-only optional**, not a directly installed Codex feature. Never blindly execute install commands, add paid services or unreviewed dependencies. Record what is and is not actually available.
4. Identify real shortcomings in visual hierarchy, dense layout, control alignment, crowded PO table, supplier detail, tab identity, weak visual rhythm and laptop viewport ergonomics. OPS v1 Retool is workflow vocabulary evidence only.
5. Produce a concise design diagnosis and skill provenance. **No Supabase, Retool, hosted data, API, RLS, migrations, business logic or production UI mutation.**

### Checkpoint D2 — visible, competing designs

Create **2–3 materially different rendered, comparable prototypes** for:

- The **connected angled/sloped-edge tab strip** inspired by the Owner's reference; active tab seamlessly joined to the white workplane, neutral inactive tabs, 13-workbench horizontal overflow, close/dirty/focus semantics retained.
- **Supplier-first PO workbench:** compact scannable orders, truthful draft/released/export state, document numbers and next action; disclose long School breakdown, exact quantities/Units and notes in usable detail rather than concatenated cells.
- Optionally show how the same design language improves Supplier Allocation while preserving the already-implemented backend supplier recommendation/explicit Save distinction.

Demonstrate populated Vietnamese operational examples and important states at **1366×768** first, then 1440, 1920, 768 and 390 widths where relevant. Provide screenshots/contact sheet and concise trade-offs. The alternatives should be genuinely different designs rather than trivial recolors.

**HARD STOP:** Request Owner visual selection before any production UI implementation. The previous general plan approved a design phase, NOT a specific final layout.

## Do not overbuild or over-certify

- One bounded design task; no Warehouse, backend, supplier commitments or unrelated cleanup.
- No repetitive multi-agent audit loops, new “proof infrastructure”, synthetic 50-School database pipelines, redundant Full CI runs or new business state machinery during D1/D2.
- Use existing fixtures and read-only evidence. A focused lint/format or static/preview smoke check is enough for a docs/prototype-only Draft.
- Independent design critique should identify **visual defects**, not just repeat typecheck status. Involve visual designer before implementation.
- Deliver one coherent Draft PR or evidence package for D1/D2, not numerous nested PRs. Do not merge a visual direction before Owner selection.

## Current environment and the parked previous task

Atlas Staging: `rnzxmxiiqgtdevzregff` — **read-only during this design task**, accepted migration 109.  
OPS v1 Supabase: `qnthofvccilhnefdcxnz` — NO WRITES. Retool: NO WRITES.  
Warehouse minimum receiving design [PR #384](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/384) merged 14 October; its [proposed design](../architecture/warehouse-receiving-minimum-design.md) and [proposed decision](../decisions/decision-atlas-warehouse-receiving-minimum.md) remain **UNAPPROVED FOR IMPLEMENTATION**. Preserve its four unresolved Product groups; it is not the current active task.

The historical 14 October Warehouse baton is preserved by Git history. This change updates only sequencing; it does not retroactively change that work's acceptance evidence.

## Required handoff

Return exact current baseline, verified canonical workspace, skill-source/provenance results, 2–3 visual directions, populated screenshots, top critical UX defects, conflicts/unknowns and a **STOP — AWAIT OWNER VISUAL SELECTION** verdict. Do not autonomously continue into a runtime implementation or another task.
