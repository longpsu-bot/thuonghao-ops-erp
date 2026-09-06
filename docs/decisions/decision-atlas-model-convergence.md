# ATLAS-MODEL-PRINCIPLE-01 — Facts explicit, state derived, supporting objects generated

**Prepared:** 6 September 2026

**Product direction:** Approved in the OPS architecture-audit follow-up.

**Document status:** Prepared implementation brief; not yet committed, independently accepted in a PR, deployed, or certified.

**Scope:** Implemented Master Data / Recipe, Planning, and Procurement. Warehouse design is excluded.

**Parent authority:** OPS_SYSTEM_MAP v1.0 / ARCH-002.

**Evidence baseline:** `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`, rechecked on 6 September 2026.

## 1. Decision

**FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

Atlas will converge existing implementations on one authority per business meaning. This is not permission to rewrite the ERP, flatten its domain boundaries, remove safeguards, or delete historical records.

The approved audit found selective over-modeling, particularly in overlapping Recipe interpretations, compatibility paths, and historical lifecycle vocabulary. The durable business facts and commitment boundaries largely remain justified. The first delivery must close demonstrated contradictory authority and preserve simplifications already implemented.

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

Supabase/PostgreSQL owns business facts, calculations, invariants, permission checks, currentness, concurrency, idempotency, transaction boundaries, and immutable evidence. React renders shaped results and coordinates interaction. Retool and OPS v1 are operational evidence, not architecture authority.

This decision refines implementation and operator workflow under the system map. It does not alter domain ownership. More recent, explicitly superseding Product amendments take precedence over the older statements they identify. Historical documents remain identifiable as historical.

## 3. Four classifications

| Classification            | Meaning                                                                                               | Persistence rule                                                                                                         |
| ------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| KEEP EXPLICIT             | A durable fact, human decision, externally meaningful commitment, or historical identity.             | Preserve its authoritative record and governed correction/history.                                                       |
| DERIVE                    | A current interpretation of other authoritative facts in an explicit context.                         | Do not add an independently editable status authority. A historical observation or cache is not a new business decision. |
| GENERATE                  | Supporting identities, records, proposals, defaults, or evidence required by a real business command. | Backend generation may produce permanent records. Generation does not mean ephemeral or automatically accepted.          |
| LEGACY / RETIRE CANDIDATE | Historical or redundant concepts that must not drive normal Product behavior.                         | Isolate normal routing first; retire physical APIs/columns only through a separately justified compatibility change.     |

Classify concepts, not whole tables indiscriminately. A Recipe line has explicit authored content and generated identity. A released document has an explicit historical number even when its initial value is generated.

## 4. Persistence and command decision test

Before adding or retaining an independently meaningful lifecycle, answer:

1. Does a person genuinely make this decision?
2. Is it externally meaningful, irreversible, or a commitment another party relies on?
3. Must its historical meaning remain stable after upstream data changes?
4. Is persistence required for authorization, concurrency, idempotency, or a stable revision head?
5. Can the current answer instead be deterministically derived from authoritative facts?
6. Can supporting records be generated inside the actual business command?

Persistence may be justified without a visible operator step. Complexity alone is not evidence of a defect.

A code change under this program must remove contradictory authority, eliminate stale independent state, remove an unnecessary operator lifecycle, consolidate duplicated rules, enable automatic supporting-object generation, or materially reduce a demonstrated integration risk. Aesthetic refactoring is insufficient.

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

The chain is a conceptual explanation, not a request for another persisted workflow graph.

## 6. Decisions retained from the approved model

### Recipe

A new Dish is immediately ACTIVE at version 1. Creation atomically provisions the two active canonical typed Recipe roots and creates no RecipeVersion. Recipe Save authors RecipeVersion evidence without activating the Dish or incrementing its version merely for activation.

Canonical roots use `v1-school-type-1` and `v1-school-type-2`; names and capitalization are display, not identity. A root without a released version can be editable while not effective-ready. Approved Weekly Menu evidence derives the Dish-wide normal-edit lock.

System-effective composition and School-effective composition are distinct contexts under the same accepted rules. Normal effective reads do not use a representative School or nullable GENERAL fallback. Copy is the existing atomic two-scope system-effective snapshot command, with explicit date and provenance; it leaves copied target versions in DRAFT for subsequent authored Save.

### Planning

Accepted inputs and explicit zero/no-additions facts remain durable. Working Attendance defaults are not confirmed Attendance. Readiness and semantic currentness are derived. Generation produces bound historical evidence inside one business command. Confirmed Need decisions are not replaceable by recalculating theoretical Need.

Existing automatic working defaults, consequential source Save, atomic daily generation, and selective confirmation continuity are preserved. Do not implement them again.

### Procurement

Recommendations and rebalance proposals are advisory. Saved exact supplier splits are explicit decisions. Allocation families, Handoff structures, promotion lineage, and draft POs are generated supporting work beneath accepted commands.

Purchase preparation remains one backend transaction composing existing release/Handoff/draft boundaries. Each official PO release remains a distinct commitment. Issuance is not proof of supplier receipt or acceptance.

## 7. Non-negotiable safeguards

Preserve authorization, RLS and capability checks, actor binding, exact quantities and Units, optimistic concurrency, deterministic locking, idempotency receipts, unknown-outcome protection, immutable audit/history, stable line targets, approval/release membership, correction lineage, current-revision uniqueness, official numbering, released PO immutability, and downstream commitment guards.

Do not mechanically remove `is_current`, version columns, snapshots, or lifecycle statuses. A persisted revision head identifies accepted history; derived freshness compares it with current inputs. They answer different questions.

Derived reads and previews must not create business records. A real command may generate its required supporting records atomically. Proposals never become accepted merely by reading or rendering them.

## 8. Authorized first delivery

**ATLAS-MODEL-CONVERGENCE-01** contains:

- this decision and a current authority/normal-command map through Procurement;
- adoption of existing canonical Recipe reads, base-authoring context, effective targeting, history, and Dish-copy command by the normal connected UI;
- targeted tests and end-to-end regression evidence for preserved boundaries;
- a read-only Staging readiness report and an explicitly separate deployment/cutover gate;
- corrections to living documentation and links to superseding Product decisions.

Planning/Procurement production behavior is not broadly refactored. Compatibility APIs remain callable. No new table, lifecycle, role, capability, generic workflow engine, deployment, data repair, or Warehouse design is authorized.

Where an existing Recipe contract demonstrably cannot support the accepted workflow, record the exact missing contract and a minimal follow-up proposal. Do not substitute frontend business logic, widen security, or invent a business rule. Complete independent in-scope work, but do not claim full acceptance while a required contract gap remains.

## 9. Alternatives considered

**Rewrite around fewer tables:** rejected. It would confuse fewer records with fewer authorities and put immutable history and concurrency at risk.

**Only relabel the UI:** rejected. Labels alone do not correct local effective selection, nullable scope, wrong copy semantics, or incomplete target identity.

**Bounded convergence on accepted contracts:** selected. It addresses evidenced contradictions while preserving existing business facts and working simplifications.

## 10. Merge, deployment, and acceptance

The implementation handoff authorizes a task branch, commits, push to that branch, and one Draft PR. It does not authorize merging, switching a PR to Ready without the recorded gate, direct hosted writes, or deployments. Normal repository CI may produce its existing non-production preview artifact; that is not permission to deploy a database or operational environment.

Code acceptance and hosted readiness are separate. A green local or CI gate cannot certify an unupgraded Staging environment. A table/API catalog inspection is not a security or business-journey certification.

Sources: [evidence register](../architecture/atlas-model-convergence-evidence.md), [authority map](../architecture/atlas-authority-map-through-procurement.md), and [bounded specification](../superpowers/specs/2026-09-06-atlas-model-convergence-design.md).
