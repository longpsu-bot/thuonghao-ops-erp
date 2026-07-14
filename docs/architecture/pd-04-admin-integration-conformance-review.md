# PD-04 — Admin integration and architecture conformance review

**Status:** Implemented in this PR; pending review and merge

**Scope:** Admin / Master Data Management integration and operator-workflow review only

**Authority:** ARCH-001, ARCH-002, and the Admin / Master Data Management Domain Contract

## Summary

The merged School, Ingredients & Suppliers, and Dishes & Recipes foundations conform as three supporting sections of one Admin / Master Data Management domain. They govern future reference data through explicit, auditable commands and decision-first workbenches. They do not execute daily Planning, Procurement, Warehouse, Dispatch, Production/QA, or Finance/Accounting work.

This review adds no Admin business capability. It records the conformance result, adds focused integration evidence, and makes the existing operator boundary copy explicit. No contradiction with ARCH-001, ARCH-002, or the Admin contract was found; no architecture redesign is required.

## Conformance result

```text
Admin / Master Data Management
├── School Admin Workbench
├── Ingredients & Suppliers Admin Workbench
└── Dishes & Recipes Admin Workbench
```

Result: **conforms**.

Atlas may expose the sections as separate navigation destinations because they support different master-data decisions. The separation is presentation and task focus, not separate domain ownership. All three implementations live under `src/modules/admin/`, expose Admin-owned read models, use fixture-backed Admin state, and present future-reference governance rather than daily operational stages.

## Reviewed ownership

| Admin section           | Admin-owned facts                                                                                                                | Downstream use                                                              | Prohibited operational effect                                                                                      |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| School                  | School identity/status, group, type, service rule, delivery-location reference, operational profile, change evidence             | Planning and later fulfilment consume stable references                     | No attendance, daily demand, Planning recalculation, cancellation, dispatch, or delivery confirmation              |
| Ingredients & Suppliers | Ingredient identity/status, units, conversions, supplier identity/status, eligibility, default/preferred policy, change evidence | Recipes, Planning, Procurement, and Warehouse consume references            | No Procurement assignment, PO, supplier confirmation/commitment, receipt, stock movement, or financial transaction |
| Dishes & Recipes        | Dish identity/status, recipe/version, lock, BOM lines, school-type variants, change sets, review evidence                        | Planning and Need Generation consume an explicit released `recipeVersionId` | No historical recalculation, QA approval, Production execution, or downstream fact rewrite                         |

Operational domains remain the owners of the facts they create. Admin changes future master-data state; they do not reach into an already recorded operational object and alter it.

## Domain cohesion and Atlas exposure

The Atlas navigation places the Admin sections together under the supporting data/governance group. The workbenches answer related master-data decisions:

- Is this school valid for future Planning and downstream reference?
- Is this ingredient usable, and which suppliers are eligible reference choices?
- Is this dish and recipe version safe to release as a future Planning reference?

These are governance decisions, not the three active daily operating stages. Requirement Planning, Purchase Planning, and Warehouse Receiving remain separate operational surfaces owned by their respective domains.

The focused integration test renders all three Admin workbenches through Atlas and verifies that they are reachable as supporting master-data surfaces under the same navigation group.

## Downstream-safe reference review

The reviewed command results create new immutable state values and leave their input fixtures unchanged. Cross-domain safety follows two rules:

```text
Admin owns the current and future master-data reference.
The operational domain owns facts already created from an earlier reference or snapshot.
```

School changes therefore do not rewrite Planning inputs or released downstream records. Ingredient and supplier changes do not create Procurement or Warehouse objects. Recipe release creates a `FUTURE_PLANNING_REFERENCE_ONLY` record and preserves the selected `recipeVersionId`; the existing Planning, Need Generation, Confirmed Need, and Purchase Handoff usage records remain unchanged.

## Ingredient and supplier boundary

Ingredient profile, status, unit profile, conversion, group, and notes are Admin-owned facts. Supplier profile, status, eligibility, and default/preferred supplier policy are also Admin-owned facts.

`DefaultSupplierPolicyReference` explicitly reports:

```text
effect = ADMIN_REFERENCE_ONLY
createsPurchaseOrder = false
createsSupplierCommitment = false
```

The conformance test applies an ingredient profile edit and a default supplier policy command, then proves the resulting Admin state contains no Procurement assignment, Purchase Order, supplier confirmation, or supplier commitment fields. Procurement remains responsible for turning a released demand reference into an actual supplier decision or commitment.

## Recipe boundary and consolidated workbench

Atlas exposes exactly one Dishes & Recipes navigation destination and one `DishRecipeAdminWorkbench`. The same surface contains dish identity/status, recipe versions, lifecycle and lock state, BOM lines, ingredient/unit references, school-type variants, change/review evidence, blockers, warnings, downstream usage, and command-gated actions.

This preserves the approved product decision:

```text
Dish identity
+ recipe versions
+ lock state
+ BOM lines
+ school-type variants
+ change/review evidence
= one consolidated Atlas workbench
```

Released and locked versions reject direct edits. Correction uses a successor recipe version or change set. `ReleaseRecipeVersionForPlanning` accepts only a validated version, creates a future Planning reference preserving `recipeVersionId`, and does not mutate prior operational usage. Admin recipe review explicitly grants neither QA approval nor Production approval.

## OPS v1 and Retool boundary

OPS v1 Retool pages remain qualitative evidence of operator needs and historical constraints. Their three-layer recipe page split is not reproduced as an Atlas domain model or page structure. No Retool code, query, page, or integration is added by the Admin foundations or this review.

## Technology and security boundary

The reviewed state shapes are local TypeScript fixtures and contain no Supabase client, Retool query, backend command, credential, or production-data integration fields. This review adds no:

- Supabase migration or PostgreSQL schema;
- RLS policy, RPC, or Edge Function;
- backend integration or credential;
- production-data access or mutation;
- Planning recalculation;
- Procurement commitment;
- Warehouse movement;
- Dispatch implementation;
- QA approval or Production execution;
- Finance or Accounting behavior;
- supplier scoring, stock optimization, or generic workflow engine.

Security implications are unchanged. The prototype has no authentication, authorization, persistence, or service-role access; future production enforcement remains a separately approved backend concern.

## Operator-workflow review

Each workbench is decision-first and command-gated:

- School detail and status/display-order changes require explicit commands and evidence.
- Ingredient/supplier eligibility and preference changes require explicit commands and remain reference-only.
- Recipe validation, release, correction, and lock/version governance expose only actions permitted by the selected lifecycle state.

The React workbenches coordinate local interaction with domain commands. They do not create a second write path or reconstruct downstream ERP behavior in UI handlers.

## Focused test evidence

`src/modules/atlas/adminIntegration.test.tsx` proves:

- all three Admin workbenches are available through Atlas under one supporting master-data navigation group;
- Dishes & Recipes has one consolidated destination and surface rather than Retool-style layers;
- ingredient edits and default supplier policy remain Admin reference data and create no Procurement fields or commitments;
- recipe release preserves `recipeVersionId` and leaves Planning, Need Generation, Confirmed Need, and Purchase Handoff usage facts unchanged;
- the workbench boundary copy names the prohibited operational effects;
- Admin fixture state contains no Supabase, Retool, backend, credential, production-data, Planning recalculation, Procurement commitment, Warehouse movement, QA, Production, Finance, or Accounting behavior fields.

Existing PD-04.1, PD-04.2, and PD-04.3 tests continue to own detailed command and lifecycle coverage. This review does not duplicate those implementation tests.

## Known prototype limitations

- State is fixture-backed and in memory; it is not authoritative persistence.
- The navigation grouping proves product/domain cohesion, not production authorization boundaries.
- Downstream references are typed prototype records, not database snapshots or transactional handoffs.
- Conformance tests inspect the current public state/read-model shapes; future persistence requires its own schema, privilege, transaction, idempotency, and migration review.

## Migration and rollback effects

There is no database or production-data migration. Rollback consists only of reverting this review document, the focused conformance test, the boundary-copy clarification, and the README/roadmap status updates. Existing Admin foundation behavior is unchanged.

## Recommended next step

Review and merge this PD-04 conformance baseline without expanding Admin scope. Then proceed to the next separately approved roadmap capability. Before any Admin production persistence, define authoritative backend commands, constraints, authorization, RLS, transactions, idempotency, and release-snapshot behavior in a dedicated contract and implementation task.

## Final conclusion

PD-04 Admin / Master Data Management is internally coherent and architecture-conformant at the in-memory prototype boundary. The three workbenches govern future master-data references, preserve operational ownership and released history, retain the one-workbench Dishes & Recipes decision, and add no prohibited production or downstream behavior.
