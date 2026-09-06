# ATLAS-MODEL-PRINCIPLE-01 — Facts explicit, state derived, supporting objects generated

**Prepared:** 6 September 2026

**Product direction:** Approved in the OPS architecture-audit follow-up.

**Document status:** **IMPLEMENTED / MERGED** through PR #258 at `11408a0b0ed5d3938321c90f38fd8a2f9c1ad587`; repository acceptance 56 / 56 PASS. Hosted Staging remains a separate NOT READY environment.

**Scope:** Implemented Master Data / Recipe, Planning, and Procurement. Warehouse design is excluded.

**Parent authority:** OPS_SYSTEM_MAP v1.0 / ARCH-002.

**Audit baseline:** `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`.

**Implemented repository authority:** `11408a0b0ed5d3938321c90f38fd8a2f9c1ad587`.

## 1. Decision

**FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

Atlas uses one authority per business meaning. This is not permission to flatten domain boundaries, remove safeguards, delete immutable evidence, or replace explicit human decisions with calculations.

The audit found selective over-modeling, especially in overlapping Recipe interpretations, compatibility paths, and lifecycle vocabulary. The adopted correction preserves durable business facts and commitment boundaries while removing contradictory authority and unnecessary operator ceremony.

## 2. Architecture authority

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

Supabase/PostgreSQL owns business facts, calculations, invariants, permission checks, currentness, concurrency, idempotency, transaction boundaries, and immutable evidence. React renders shaped results and coordinates interaction. Retool and OPS v1 remain operational evidence, not architecture authority.

This decision refines implementation and operator workflow under the system map. It does not alter domain ownership. More recent, explicitly superseding Product amendments take precedence over older statements they identify.

## 3. Four classifications

| Classification | Meaning | Persistence rule |
| --- | --- | --- |
| KEEP EXPLICIT | Durable fact, human decision, externally meaningful commitment, or historical identity. | Preserve authoritative record and governed correction/history. |
| DERIVE | Current interpretation of other authoritative facts in an explicit context. | Do not add an independently editable status authority. |
| GENERATE | Supporting identities, records, proposals, defaults, or evidence required by a real business command. | Backend generation may persist records; generated does not mean auto-accepted. |
| LEGACY / RETIRE CANDIDATE | Historical or redundant concepts that must not drive normal Product behavior. | Isolate normal routing first; physical retirement requires separate compatibility work. |

Classify concepts, not whole tables indiscriminately. A Recipe line has explicit authored content and generated identity. A released document has an explicit historical number even when its initial value is generated.

## 4. Persistence and command decision test

Before adding or retaining an independently meaningful lifecycle, ask:

1. Does a person genuinely make this decision?
2. Is it externally meaningful, irreversible, or relied on by another party?
3. Must its historical meaning remain stable after upstream facts change?
4. Is persistence required for authorization, concurrency, idempotency, or a stable revision head?
5. Can the current answer instead be deterministically derived from authoritative facts?
6. Can supporting records be generated inside the actual business command?

Persistence may be justified without a visible operator step. Complexity alone is not evidence of a business concept.

A change under this principle should remove contradictory authority, eliminate stale independent state, remove unnecessary operator ceremony, consolidate duplicated rules, generate required supporting objects automatically, or materially reduce a demonstrated integration risk. Aesthetic refactoring alone is insufficient.

## 5. Architectural gradient

Upstream work should be generative, derived, and low-ceremony. Human decisions remain explicit. External commitments become increasingly explicit and historically stable.

```text
Governed reference facts and Recipe evidence
→ accepted Menu / Attendance / Pantry inputs
→ bound generated Need evidence
→ human-confirmed quantities
→ human-confirmed supplier allocation
→ immutable issued purchase orders
```

This is a conceptual explanation, not a request for another persisted workflow graph.

## 6. Implemented decisions through Procurement

### Recipe

A new Dish is immediately ACTIVE at version 1. Creation atomically provisions the two active canonical typed Recipe roots and creates no RecipeVersion. Recipe Save authors RecipeVersion evidence without a separate Dish activation ceremony.

Canonical roots use `v1-school-type-1` and `v1-school-type-2`; names/capitalization are display, not identity. A root without a released version can be editable while not effective-ready. Approved Weekly Menu evidence derives the Dish-wide normal-edit lock.

System-effective and School-effective composition are distinct contexts under the same backend rules. Normal effective reads do not use a representative School or nullable GENERAL fallback. `SYSTEM_DISH` Preview/Create/Supersede uses exact Dish + canonical School Type. Dish copy remains one atomic two-scope system-effective snapshot command with explicit date and provenance, leaving target versions in DRAFT for authored Save.

Effective history shapes issuance per immutable revision. Imported legacy revisions without original attribution remain unattributed; Atlas importer identity/time are not presented as original business issuance. Later Atlas-native corrections and cancellations retain their own Actor/time.

### Planning

Accepted Menu, Attendance and Pantry inputs remain durable, including explicit zero/no-additions facts. Working Attendance defaults are generated proposals, not confirmed Attendance. Readiness and semantic currentness are derived. Need Generation creates bound historical evidence inside one command. Confirmed Need remains an explicit human decision.

Automatic working defaults, consequential source Save, atomic daily generation, and selective confirmation continuity are preserved.

### Procurement

Recommendations and rebalance proposals are advisory. Saved exact supplier splits are explicit decisions. Allocation families, Handoff structures, promotion lineage, and draft POs are supporting work generated beneath accepted commands.

Purchase preparation remains one backend transaction composing existing release/Handoff/draft boundaries. Each official PO release is a distinct external commitment with immutable released content and official numbering.

## 7. Non-negotiable safeguards

Preserve authorization, RLS and capability checks, Actor binding, exact quantities and Units, optimistic concurrency, deterministic locking, idempotency receipts, unknown-outcome protection, immutable audit/history, stable line targets, approval/release membership, correction lineage, current-revision uniqueness, official numbering, released PO immutability, and downstream commitment guards.

Do not mechanically remove `is_current`, version columns, snapshots, or lifecycle statuses. A persisted revision head identifies accepted history; derived freshness compares that history with current inputs. They answer different questions.

Derived reads and previews must not create business records. A real command may generate its required supporting records atomically. Proposals never become accepted merely by reading or rendering them.

## 8. Implemented convergence delivery

ATLAS-MODEL-CONVERGENCE-01 was completed and merged through PR #258.

It delivered:

- this decision and the current authority/normal-command map through Procurement;
- adoption of canonical Recipe reads, base-authoring context, effective targeting, history, and Dish-copy command by the normal connected UI;
- A07 true SYSTEM_DISH command context without representative School;
- A12 per-revision legacy issuance truth without importer fabrication;
- targeted tests and integrated regression evidence for preserved Planning/Procurement boundaries;
- 56 / 56 repository acceptance;
- a read-only Staging readiness report and a separately controlled hosted reconciliation/deployment gate.

Certified component PRs #259 and #260 were incorporated into #258 and are closed as superseded component evidence.

Planning/Procurement production behavior was not broadly refactored. Compatibility APIs remain callable. No new generic workflow engine, Warehouse design, hosted deployment, or Staging data repair was part of the merge.

## 9. Alternatives considered

**Rewrite around fewer tables:** rejected. It would confuse fewer records with fewer authorities and put immutable history and concurrency at risk.

**Only relabel the UI:** rejected. Labels alone do not correct effective selection, wrong context, copy semantics, stable targets, or provenance.

**Bounded convergence on accepted contracts:** selected and implemented. It addressed evidenced contradictions while preserving durable facts and working simplifications.

## 10. Repository acceptance versus hosted readiness

Repository acceptance is complete at `11408a0b0ed5d3938321c90f38fd8a2f9c1ad587` with 56 / 56 convergence criteria passing and exact-head CI/Full Integration evidence recorded in the implementation report.

Hosted readiness remains separate. Atlas Staging is currently **NOT READY** for the merged Recipe journey: its migration tip remains `20260904081048_master_data_creation_ux_02`, the new effective Recipe APIs are absent, and canonical typed Recipe-root coverage for the two active Dishes is missing.

Do not infer hosted operability from repository CI, Storybook, GitHub Pages, or branch previews. Staging migration/data reconciliation and the persistent connected hosted web app are separately controlled next steps. Live OPS and Retool remain outside the Atlas deployment target.

Sources: [evidence register](../architecture/atlas-model-convergence-evidence.md), [authority map](../architecture/atlas-authority-map-through-procurement.md), [implementation report](../implementation-tasks/TASK-ATLAS-MODEL-CONVERGENCE-01.md), and [Staging readiness runbook](../runbooks/atlas-model-convergence-staging-readiness.md).
