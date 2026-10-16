# Atlas Autopilot Mandate

Status: **ACTIVE — OWNER-SELECTED C / BOUNDED FRONTEND IMPLEMENTATION**

Original approval: 14 October 2026.  
**Product priority amendment: 16 October 2026.**  
Current execution horizon: **resolve the four Owner UI issues in PR #392, then bounded remediation of the approved Need correction in preserved Draft #388 after UX is stable**. The Owner's 16 October delivery directive supersedes the recording-only status and broad Need-remediation pause. #385–#387 stay parked; Warehouse stays paused. Hosted Atlas access remains read-only; OPSv1/Retool remain NO-WRITE. No merge or deployment.

The six standing Owner delivery rules are delivery/value first; bounded scope/acceptance/completion; mandatory failure stops and escalation; focused development checks separated from release certification; preservation of unfinished PRs/evidence; and explicit PASS/FAIL/BLOCKED with actionable handoffs. [The active task](ACTIVE_TASK.md#product-priority-and-work-authorization) defines current acceptance. One consolidated diagnosis/correction is allowed; if the same acceptance failure recurs twice, stop with root cause and actionable FAIL rather than indefinite retries. These are delivery rules, not replacements for the existing security/Product hard stops.

## Control plane

GitHub repository `longpsu-bot/thuonghao-ops-erp` is the shared handoff between OPS Product/Architecture and local Atlas implementation. **Do not rely on chat memory as task authority.** Read `docs/autopilot/ACTIVE_TASK.md` and the linked [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389) first.

At this checkpoint the active loop is deliberately shortened:

```text
Owner design priority → verified checkout → skill/source audit
→ rendered alternatives (2–3) → independent visual critique
→ Owner selects a design → STOP until explicit selection
```

After Owner visual selection, normal bounded implementation / read-only audit / targeted CI / Product review / merge may resume. **No automatic unrelated task promotion or Staging deployment.** The four UI issues and bounded Need correction are explicitly authorized; they require no renewed design-selection ritual.

## Roles

OPS Product/Architecture selects product priorities and can approve bounded routine GitHub changes within the standing safety rules. The navigator/Terra role remains **read-only for implementation work**; the implementer/Sol/Codex owns bounded design prototype and code writes in its separately verified worktree. The independent visual reviewer must examine **rendered** evidence, not only source/style tests. If preferred names/models are unavailable, preserve role separation.

GitHub issue/PR comments do **not** by themselves launch Codex or interrupt an already-running local process. Do not claim automated execution without an actual connected runner confirmation.

## One staff member per operational task

`ONE_STAFF_PER_OPERATIONAL_TASK` remains in force. An authorized Actor can perform a normal operation with existing capabilities and exact scopes; don't add a generic second-person approval flow. Capability, relational scope, immutable evidence, audit and approved exception overrides remain mandatory. This design task makes **no** staff grants or permission changes.

## Hard Product stops (unchanged)

Stop before:

1. new/changed unresolved business policy;
2. paid or Production infrastructure;
3. first Production write-ownership transfer from OPS v1;
4. irreversible real supplier PO/PXK commitments;
5. destructive Production data correction;
6. material authorization broadening;
7. final Warehouse business design approval;
8. **production implementation of an unselected Atlas UI design.** Owner selected C; that selection gate is satisfied for the current bounded corrections, not unrelated design changes.

## Environment boundary

- Atlas Staging `rnzxmxiiqgtdevzregff`: **read-only for this active design phase**; prior approved bounded Staging processes remain historical evidence.
- OPS v1 Supabase `qnthofvccilhnefdcxnz`: hard NO-WRITE.
- Retool: continuity/workflow evidence; NO-WRITE.
- Atlas Production: not an approved target. No creation.

## Architecture

Use `OPS_SYSTEM_MAP v1.0` and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. PostgreSQL still owns authority for business facts, calculations, state derivation, currentness, concurrency, permissions, idempotency and released document history. Design skills cannot override business contracts. Chakra UI v3 remains the existing presentation foundation; typography, tab geometry, composition and information hierarchy are open to ambitious Product-directed redesign.

## Anti-overengineering rule

- Do **not** run further Warehouse contracts/migrations, broad performance studies, 8-cycle Need correction probes, repeated full-repo CI, extra autonomous agent loops, synthetic load programs or new architecture layers solely to “move Autopilot forward”.
- Do **not** merge/deploy Draft PRs #385–#388; preserve their state and existing evidence. #385–#387 remain parked; #388 alone has bounded remediation authority after stable UX.
- Read/use existing proofs instead of re-proving unchanged contracts. For **design-only** work, require real rendered comparison and focused checks—not a new certification infrastructure.
- Keep one active task in `ACTIVE_TASK.md` and a single explicit next Product decision. No automatic endless backlog execution; wait for Owner selection after D2.

## Active-task protocol

1. Read `AGENTS.md`, this file, `docs/autopilot/ACTIVE_TASK.md`, relevant approved contracts and the current `origin/main`.
2. Verify canonical workspace before implementation (`git rev-parse`, `git remote -v`, `git fetch origin`, `git status --short`, `pnpm ops:workspace`). Do not disturb dirty Codex checkouts.
3. Execute **only D1/D2**, create Draft artifacts for review, then stop for Owner selection.
4. Later task authorization requires an explicit update to this mandate/active baton, not extrapolation from an old roadmap.
