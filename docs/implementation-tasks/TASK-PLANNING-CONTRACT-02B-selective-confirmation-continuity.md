# TASK-PLANNING-CONTRACT-02B — Selective Confirmation Continuity

**Status:** Merged through PR #200; independent count-integrity correction merged through PR #201; locally certified by PLANNING-ACCEPTANCE-01 on 2026-08-18

**Baseline:** `b20ecb0507a50441e02ae1c1827efffa936e5603`

**Decision:** [D-040](../decisions/decision-register.md)

**Contract:** [Selective Confirmed Need Decision Continuity](../architecture/planning-contract-02b-selective-confirmation-continuity.md)

## Scope delivered

- Added immutable private `atlas_planning.confirmed_need_line_decision_continuity` evidence with the four accepted carry/invalidation kinds.
- Amended the existing PLANNING-CONTRACT-01 materializer, H1B1 pointer/integrity rules, RMVP-05 read model, RMVP-06 validation, RMVP-07 completeness, and D-037 readback without adding a public command or lifecycle.
- Preserved the original human decision across exact unchanged successors, including manual adjustments and changed Recipe/source composition.
- Added exact invalidation, no-resurrection, multi-generation carry, historical reconfirmation-chain, prior-unreviewed, replay, policy-change, changed/new/removed, and mixed-scenario coverage.
- Counted direct-predecessor business facts removed from the current successor independently of human-decision continuity, including unreviewed-only and reviewed/unreviewed mixed-removal regressions.
- Added backend result counts and bounded Need Generation/Confirmed Need presentation. React performs no business matching or count derivation.
- Kept PLANNING-CONTRACT-02A source replacement semantics, direct-wholesale compatibility, and the downstream release blocker unchanged.

## Explicit exclusions

No Staging/live/Retool mutation, Edge Function, public API, operator capability, new status, downstream correction workflow, partial release, XLSX work, Rice fixture work, Procurement, Warehouse, Dispatch, or production rollout is included.

## Migration and rollback effect

Migration `20260817045218_planning_contract_02b_selective_confirmation_continuity.sql` is additive for persistence and guarded/fail-closed for existing private function amendments. It creates no seed or production data. A rollback must be forward-only and preserve created continuity/history rows until all dependent reads and releases have been safely migrated; deleting human decisions or immutable operational evidence is prohibited.

## Certification record

The task gate requires a clean local Supabase reset, focused 02B pgTAP, H1B1/H0C/RMVP-04/05/06/07/D-037/02A/Pantry and platform catalog regression, the broad practical Planning SQL gate, affected and broader Planning frontend tests, typecheck, format, production build, and `git diff --check`. GitHub Actions remain blocked before runner by the repository billing/spending limit and are not represented as passing.

## Review focus

Independent Product/architecture review should verify the stable identity, exact numeric and policy predicates, private continuity evidence, absence of fake human decisions, direct-predecessor/no-resurrection rule, released downstream blocker, D-039 boundary, and backend-owned UI classifications/counts before merge.
