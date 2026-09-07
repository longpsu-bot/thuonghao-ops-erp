# OPS-V1-SCHOOL-FULFILMENT-CUTOVER-READINESS-01A Design

**Status:** Product/architecture design approved for repository-only implementation planning

**Baseline:** `7251dc2764b5a91530af250a1cb2b4ce868fc61f` (`main`, merged PR #263)

**Follow-on gate:** `OPS-V1-SCHOOL-FULFILMENT-CUTOVER-READINESS-01B` — separately authorized Atlas Staging activation and connected rehearsal

## 1. Decision summary

PR #263 closes the core School fulfilment model through Direct Ingredient Need, Confirmed Need correction, exact supplier allocation, immutable/replacement School-catering Purchase Orders, and immutable School/date/location Phiếu xuất kho (PXK).

The next step is not Warehouse stock or another fulfilment lifecycle. It is a two-gate cutover-readiness program:

1. **01A — repository cutover readiness:** add the remaining read-only OPS v1 reconciliation capability, prepare the controlled connected UI and Staging rehearsal authority, upgrade the deterministic Staging test identity, and extend verification tooling. **01A performs no hosted mutation.**
2. **01B — authorized Staging activation and rehearsal:** from a separately approved exact merged `main` SHA, use the existing protected Atlas Staging deployment path, reconcile the Staging identity/foundation packages, run the real connected operator journeys, and verify the resulting hosted facts read-only.

This preserves the standing design principle:

> **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

The remaining PO ↔ PXK reconciliation is a derived Read Model over authoritative Planning, Procurement, and Dispatch facts. It is not a new business aggregate, persisted QA lifecycle, or correction workflow.

## 2. Authority and current observed state

### 2.1 Architecture authority

Apply `OPS_SYSTEM_MAP v1.0`:

`Mission → Business Capability → Business Domain → Business Object → Business Contract → Command/Event → Read Model → Application → Technology`.

Supabase/PostgreSQL remains authoritative for business facts, exact quantity lineage, currentness, permissions, concurrency, idempotency, immutable history, and release evidence. React consumes shaped contracts and does not reconstruct ERP authority.

OPS v1 / Retool is behavioral evidence only. Its direct SQL and mutable implementation patterns are not architecture authority.

### 2.2 Repository authority after PR #263

Current `main` owns:

- `ADDITIVE | COMPLETE` Direct Ingredient Need at School + service date;
- Recipe-derived and direct-Ingredient contribution composition;
- append-only Confirmed Need correction;
- exact saved supplier allocation;
- immutable released PO evidence and complete replacement PO roots;
- removed-supplier `CANCELLATION_REQUIRED` safety boundary without a cancellation command;
- immutable School PXK release/successor behavior;
- PXK readiness at exact School/date/captured-location scope, including relevant historical `REPLACEMENT_REQUIRED` and `CANCELLATION_REQUIRED` supplier commitments;
- XLSX/PDF PXK export and connected `Kho → Phiếu xuất kho` UI.

### 2.3 Atlas Staging observation before 01A

Approved Atlas Staging is `rnzxmxiiqgtdevzregff`.

Read-only inspection on 07/09/2026 found:

- migration tip `20260904081048 / master_data_creation_ux_02`;
- no `atlas_dispatch.school_dispatch_releases` relation;
- no `atlas_api.release_school_dispatch_document(jsonb)`;
- no School-catering PO replacement API from PR #263;
- the connected Pantry workbench still exists;
- one active managed synthetic Actor/Auth mapping;
- the managed Staging role currently exposes the existing 19-capability set, including `procurement.school_catering.read` and `procurement.school_catering.write`, but not the new PXK read/release capabilities;
- existing hosted reference/business state must not be reset or broadly reseeded.

The current hosted capability set alone is not used to infer the installed package version; repository package authority remains explicit.

### 2.4 OPS v1 behavior to preserve

The v1 PurchasePlanner has two distinct operator jobs relevant here:

- **Tạo phiếu xuất kho** — produce the School/date dispatch document;
- **Đối chiếu PO và Phiếu xuất kho** — compare purchasing quantity against dispatch quantity per School and Ingredient and surface discrepancies.

Atlas already owns the first job through immutable PXK release. 01A closes the second job as a read-only derived reconciliation surface.

## 3. Goals

01A must produce a repository state from which 01B can safely prove the full connected School fulfilment journey without inventing new lifecycle machinery.

Goals:

1. Add one authoritative read-only PO ↔ PXK reconciliation contract and connected workbench.
2. Attribute released PO quantity to the exact School/date/location through existing immutable allocation/contribution lineage rather than supplier aggregate totals.
3. Keep comparison status derived and separate from Procurement/PXK operational blockers.
4. Upgrade the deterministic Atlas Staging Identity package from `1.1.0` to `1.2.0` by adding exactly the two PXK capabilities required for the connected rehearsal.
5. Extend local package certification and Staging verification authority for that exact identity change.
6. Add a repository-owned, read-only post-rehearsal verifier for the three approved hosted operator scenarios.
7. Update the Staging runbook so the next mutation gate is explicit and uses the existing protected deployment tooling.
8. Leave Atlas Staging, live OPS, and Retool unchanged during 01A.

## 4. Non-goals

01A does **not**:

- deploy migrations to Atlas Staging;
- install or reconcile hosted Identity/Foundation packages;
- create hosted rehearsal business facts;
- reset or reseed Staging;
- copy live OPS/Retool payloads into Atlas;
- implement supplier cancellation;
- implement receiving, stock, lots, balances, reservations, picking, movements, trips, vehicles, drivers, delivery proof, or return-to-stock;
- reactivate the historical DispatchPlan/DispatchTrip/DispatchStop path as the normal School PXK path;
- create a generic currentness engine, generic provenance framework, QA workflow, discrepancy-resolution lifecycle, or persisted reconciliation status;
- change the approved Direct Need, Confirmed Need, allocation, PO replacement, or PXK business contracts unless a concrete regression is proven.

## 5. Reconciliation Read Model

### 5.1 Business purpose

The reconciliation workbench answers one operational question:

> For this School, service date, and captured delivery location, do the quantities represented by current supplier commitments agree with the current released PXK, and are there any authoritative commitment blockers that make the apparent equality unsafe?

It is a Read Model, not a business object with its own lifecycle.

### 5.2 Grain

**Summary grain**

```text
service_date
+ school_id
+ delivery_location_id
```

**Detail grain**

```text
service_date
+ school_id
+ delivery_location_id
+ ingredient_id
+ unit_id
```

The captured operational `delivery_location_id` from Confirmed Need/Handoff/Allocation lineage is authoritative. A later change to `school.default_delivery_location_id` does not move an existing reconciliation scope.

### 5.3 Scope discovery

A current summary scope is included when at least one current/active authoritative fact exists in the requested range:

- a current applicable Confirmed Need / current Allocation contribution for the School/date/location;
- attributable still-active released School-catering PO lineage for that School/date/location; or
- a current `RELEASED` School PXK for that School/date/location.

Superseded PO/PXK history alone does **not** manufacture a current reconciliation row. When a current scope exists, immutable predecessor/superseded documents remain available for drill-down and audit/history.

Purely empty School/date combinations are not manufactured.

### 5.4 PO quantity authority

The reconciliation **must not** compare PXK quantity with a whole supplier PO total.

For each detail key, `po_quantity` is the sum of exact quantities attributable to the requested School through the same typed lineage already used by Procurement/PXK:

```text
current Allocation Family Revision
→ exact Family Contribution
→ Supplier Split
→ current released School-catering PO line/revision coverage
→ School/date/captured location
```

If multiple suppliers legitimately cover one School Ingredient, their exact covered quantities are summed for that School detail key.

Current Allocation Family validity remains strict: source fingerprint and family quantity must match the current projection. A stale allocation revision is not treated as current purchasing authority.

### 5.5 PXK quantity authority

`pxk_quantity` comes only from the current `RELEASED` School PXK at the same School/date/location grain.

Superseded PXKs remain visible in history/export but do not contribute to the current comparison total.

If the current PXK fingerprint is no longer aligned with current fulfilment evidence, the existing PXK `REPLACEMENT_REQUIRED` state remains visible separately from the quantity comparison.

### 5.6 Derived comparison status

`comparison_status` is a closed read-only set:

```text
OK
NO_PO
NO_PXK
INGREDIENT_CHANGED
MISMATCH
```

For a discovered reconciliation scope, derive in this order:

1. **NO_PO** — current School Need/allocation or PXK evidence exists but no attributable current released PO coverage exists for the scope.
2. **NO_PXK** — attributable current released PO coverage exists but no current released PXK exists.
3. **INGREDIENT_CHANGED** — both sides exist, but the normalized `(ingredient_id, unit_id)` key sets differ.
4. **MISMATCH** — both sides have the same normalized key set, but at least one exact numeric quantity differs.
5. **OK** — both sides have identical normalized key sets and exact quantities.

Do not compare formatted strings or rounded display numbers. PostgreSQL numeric authority is exact; API quantities remain lossless strings at the browser boundary.

### 5.7 Operational blockers remain separate

`comparison_status = OK` does not by itself mean the School is safe to dispatch.

The read model must also surface the existing authoritative Procurement/PXK state, including relevant blockers such as:

- `PO_COVERAGE_INCOMPLETE`;
- `PROCUREMENT_NOT_CURRENT`;
- `CANCELLATION_REQUIRED`;
- PXK `REPLACEMENT_REQUIRED` / `BLOCKED` state and its existing blocker codes.

This preserves the distinction between:

- **quantity reconciliation** — do current PO-attributed quantities and current PXK quantities match?; and
- **commitment currentness** — are there still-active supplier/PXK facts that make release or reliance unsafe?

No reconciliation-specific `RESOLVED`, `APPROVED`, `ACKNOWLEDGED`, or similar persisted lifecycle is introduced.

### 5.8 API contract

Add one read-only browser API:

```text
atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)
```

Contract version:

```text
SCHOOL-FULFILMENT-RECONCILIATION.v1
```

Required request scope:

- `date_start`;
- `date_end`;
- `school_ids` array, empty meaning all authorized Schools;
- nullable `search`.

The date range is inclusive and capped at 31 days, matching the existing School PXK workbench boundary.

Authorization:

- resolve authenticated Actor through the existing command/read infrastructure;
- require existing capability `dispatch.school_release.read`;
- apply the same School/customer/location scope rules used by the PXK read path;
- no direct browser grants on private relations.

Implementation posture:

- stable, read-only, `SECURITY DEFINER`, empty `search_path`;
- owned by `atlas_read_runtime`;
- browser receives only the `atlas_api` shaped contract;
- no command receipt, domain event, or audit event because no business fact is written.

Suggested row payload:

```text
service_date
school_id
school_name
delivery_location_id
delivery_location_name
comparison_status
po_quantity
pxk_quantity
delta_quantity
purchase_order_numbers[]
pxk_document_number
pxk_state
blockers[]
warnings[]
details[]
```

Each detail contains Ingredient/Unit identity and display snapshots, exact PO/PXK quantities, exact delta, and source document identifiers sufficient for operator drill-down. Internal technical lineage IDs may be included only where they materially support traceability; the UI must not require operators to understand them.

## 6. Connected reconciliation workbench

Add a second focused `Kho` surface beside the existing PXK workbench:

```text
Kho
├─ Phiếu xuất kho
└─ Đối chiếu PO / Phiếu xuất kho
```

The reconciliation workbench is read-only.

Primary controls:

- date start/end;
- School selector;
- search by School, location, PO number, or PXK number.

Summary table:

```text
Ngày | Trường / điểm giao | PO | PXK | SL PO | SL PXK | Δ | Đối chiếu | Vận hành
```

Selecting a row shows Ingredient-level detail with:

```text
Nguyên liệu | Đơn vị | SL PO | SL PXK | Δ | Nguồn chứng từ
```

The UI must make a distinction between a quantity mismatch and an operational blocker. An `OK` quantity comparison with `PROCUREMENT_NOT_CURRENT` must not be styled as fully healthy.

No "resolve", "confirm", "accept", "override", or write action is added.

OPS v1 is the behavior reference, not the visual reference; use the existing compact Atlas workbench patterns.

## 7. Atlas Staging Identity package 1.2.0

Repository package authority is currently `atlas-staging-identity@1.1.0` with 19 reviewed capabilities.

01A upgrades the package to **`atlas-staging-identity@1.2.0`** while preserving the same deterministic Auth subject, Actor, role, membership, and single reviewed `GLOBAL` scope.

Add exactly:

```text
dispatch.school_release.read
dispatch.school_release.release
```

Recommended deterministic role-capability identities continue the existing sequence:

```text
a1010000-0000-4000-8000-000000000029  dispatch.school_release.read
a1010000-0000-4000-8000-000000000030  dispatch.school_release.release
```

Update the managed Auth metadata marker to `atlas-staging-identity@1.2.0`.

Do not add Warehouse, old DispatchPlan/Trip, supplier-cancellation, broad admin, or denial-only capabilities.

The reconciliation API reuses `dispatch.school_release.read`; it does not get a new capability merely because it is a separate read surface.

Package reconciliation remains exact-match/insert-if-absent/fail-closed under the existing package installer rules. 01A prepares and locally certifies the package; it does not install it on hosted Staging.

## 8. Foundation and hosted data ownership

The `atlas-staging-foundation` package remains a minimal prerequisite/reference package. 01A does not expand it into a fulfilment seed graph.

Existing hosted data is preserved. No Staging reset, truncation, or all-purpose reseed is permitted.

The connected rehearsal should reuse the dedicated synthetic Staging School/reference identities where valid and create the smallest missing business facts through real operator APIs/UI. Existing unrelated Schools, Ingredients, Suppliers, Purchase Orders, and history are not rewritten to make the rehearsal pass.

Missing canonical or prerequisite data is a reconciliation problem to report, not permission to fabricate production-like content.

## 9. Post-rehearsal verifier

01A adds a repository-owned **read-only** verifier for 01B. Suggested command:

```text
pnpm atlas:staging:school-fulfilment:verify
```

Suggested script:

```text
scripts/verify-atlas-staging-school-fulfilment.mjs
```

The verifier uses the existing approved Staging target guard, protected-value redaction, authenticated test user, and `atlas_api` contracts. It performs no hosted writes.

It validates the final state of three connected operator-authored scenarios in one reserved rehearsal week beginning Monday **17/09/2046**. The exact service dates are fixed so verification is deterministic and isolated from normal operational dates.

### Scenario A — Catering + Direct ADDITIVE

Service date: **17/09/2046**.

Operator journey:

```text
Menu + Attendance + released Recipe
+ Direct Ingredient Need (ADDITIVE)
→ Need Generation
→ Confirmed Need
→ saved Supplier Allocation
→ released PO
→ released PXK
→ reconciliation OK
```

Scenario A must contain both `RECIPE_DERIVED` and `PANTRY_DIRECT` contribution membership for the same School/date so the additive composition boundary is exercised. Verification proves exact quantity continuity, current supplier commitment coverage, current PXK, and `comparison_status = OK` with no unresolved operational blocker.

### Scenario B — Direct COMPLETE

Service date: **18/09/2046**.

Operator journey:

```text
Direct Ingredient Need (COMPLETE)
→ Need Generation without fabricated Menu/Attendance
→ Confirmed Need
→ saved Supplier Allocation
→ released PO
→ released PXK
→ reconciliation OK
```

Verification proves no fake Menu/Attendance binding and only approved Direct Need authority for the complete scope.

### Scenario C — Downstream correction and replacement

Service date: **19/09/2046**.

Operator journey:

```text
released Confirmed Need
→ saved Allocation
→ released PO
→ released PXK
→ append-only Confirmed Need correction
→ revised Allocation Save
→ complete replacement PO draft
→ explicit replacement release
→ successor PXK release
→ reconciliation OK
```

Verification proves:

- old Confirmed Need decision/revision retained;
- predecessor PO number/content retained and exportable;
- replacement PO has explicit predecessor lineage;
- predecessor becomes `SUPERSEDED` only when replacement releases;
- old PXK retained/exportable;
- successor PXK has predecessor lineage and becomes current;
- final reconciliation is `OK` and operationally current.

The removed-supplier cancellation case is not a successful rehearsal scenario because Atlas intentionally has no supplier-cancellation command. The verifier may prove `CANCELLATION_REQUIRED` blocks when such a condition exists, but 01A/01B do not invent a resolution.

## 10. 01B activation contract

01B is a separate operational authorization gate. 01A must make the intended sequence explicit but must not execute it.

After 01A is merged and a new exact `main` SHA is accepted for hosted mutation:

```text
exact merged main
→ existing guarded Atlas Staging migration deployment
→ platform-only verification
→ Identity 1.2.0 reconciliation
→ Foundation replay
→ default read-only atlas:staging:verify
→ controlled persistent connected Staging frontend
→ operator authors Scenario A / B / C through real connected workflows
→ atlas:staging:school-fulfilment:verify
→ Product/Architecture cutover decision
```

Use the existing protected `atlas-staging` environment, exact-main certification, live-OPS denylist, repository migration equality checks, and `atlas_api` exposure verification.

No manual hosted DDL, `migration repair`, database reset, ad-hoc Supabase Dashboard change, or automatic retry of an unknown write is permitted.

01B requires separate explicit Product Owner authorization because it mutates Atlas Staging.

## 11. Testing and certification for 01A

### 11.1 Database

Add focused pgTAP coverage for the reconciliation contract:

1. exact PO attribution by School contribution rather than supplier total;
2. multi-supplier quantities sum correctly for one School Ingredient;
3. `NO_PO`;
4. `NO_PXK`;
5. `INGREDIENT_CHANGED`;
6. `MISMATCH`;
7. `OK`;
8. exact numeric quantities preserved;
9. mutable School default location does not move captured scope;
10. superseded PO/PXK history is excluded from current totals but remains historical evidence;
11. `comparison_status = OK` may coexist with `PROCUREMENT_NOT_CURRENT` / `CANCELLATION_REQUIRED` and is not treated as operationally current;
12. actor/scope/RLS/API grant boundaries.

Register the new suite exactly once in Supabase Full Integration.

### 11.2 Frontend

Focused tests prove:

- date/School/search requests use the authoritative read API;
- stale async responses cannot overwrite newer filters;
- summary and detail exact quantities render losslessly;
- the five comparison statuses render correctly;
- operational blockers are visually distinct from comparison status;
- no reconciliation write action exists;
- navigation exposes `Kho → Đối chiếu PO / Phiếu xuất kho` without regressing `Kho → Phiếu xuất kho`.

### 11.3 Staging package/tooling

Update package and Staging-contract tests to prove:

- Identity package version is exactly `1.2.0`;
- exactly 21 capability bindings are managed;
- the only new capabilities versus 1.1.0 are the two PXK capabilities;
- deterministic IDs and existing Actor/role/scope identities are preserved;
- unrelated capabilities remain absent;
- local Identity first-install/replay/conflict behavior remains fail-closed;
- post-rehearsal verifier is read-only and rejects wrong target/live OPS;
- verifier redacts protected values;
- verifier fails on missing, stale, contradictory, or fabricated scenario lineage.

### 11.4 Broad gates

Before 01A is merge-ready:

- focused backend/frontend/package tests pass;
- `git diff --check` passes;
- Frontend CI passes;
- Supabase Smoke passes;
- Supabase Full Integration passes with the reconciliation suite registered once;
- Qodana status is reported without unrelated cleanup;
- Cloudflare preview passes if triggered.

No hosted Staging deployment is part of 01A acceptance.

## 12. Expected implementation surface

Exact files are locked in the implementation plan after repo inspection, but 01A is expected to touch these bounded areas:

- one forward Supabase migration for the read-only reconciliation API/private read helper(s);
- one focused pgTAP reconciliation suite and security-catalog adjustments if the API catalog changes;
- Full Integration static registration/test updates;
- one focused React reconciliation module under Atlas fulfilment/dispatch plus navigation wiring;
- Atlas RPC adapter/type tests for the read contract;
- `supabase/packages/atlas-staging-identity.v1.json` package version/capability update;
- existing Staging package tests/verifiers;
- one new read-only post-rehearsal verifier and tests;
- Staging deployment runbook / implementation record updates.

Do not refactor unrelated Recipe, Planning, Procurement, PXK export, or legacy Dispatch code.

## 13. Failure and stop conditions

Stop and return to Product/Architecture review if implementation discovery shows any of the following:

1. exact School PO attribution cannot be derived from existing PO → Split → Contribution → Handoff → Confirmed Need lineage;
2. reconciliation requires writing a new status, acknowledgement, or resolution record;
3. the connected Staging operator requires Warehouse/stock or old DispatchPlan/Trip capabilities to complete PXK/reconciliation;
4. Scenario B requires fabricated Menu/Attendance/Recipe facts despite `COMPLETE` Direct Need authority;
5. Scenario C requires mutating released PO/PXK content instead of successor evidence;
6. Staging activation would require resetting existing hosted state or copying live OPS/Retool business data;
7. live OPS or another project reference appears in a mutation path;
8. supplier cancellation is required to complete the three approved normal/correction scenarios;
9. a broad generic provenance/currentness framework is required instead of existing exact lineage.

## 14. Acceptance criteria

01A is accepted when repository evidence proves all of the following:

1. PO ↔ PXK reconciliation is a read-only derived contract with no persisted QA lifecycle.
2. PO quantity is attributable to exact School lineage, not supplier totals.
3. Comparison statuses `OK | NO_PO | NO_PXK | INGREDIENT_CHANGED | MISMATCH` are deterministic and tested.
4. Procurement/PXK blockers remain separate from quantity comparison status.
5. The connected UI exposes a read-only `Đối chiếu PO / Phiếu xuất kho` workbench under `Kho`.
6. Identity package `1.2.0` adds exactly `dispatch.school_release.read` and `dispatch.school_release.release`, preserving prior identities/scopes.
7. Local package certification proves the upgraded Identity package first-install/replay/fail-closed behavior.
8. The read-only post-rehearsal verifier deterministically checks Scenario A, B, and C and cannot mutate hosted state.
9. The Staging runbook defines, but does not execute, the separate 01B protected activation sequence.
10. Full repository certification remains green.
11. Atlas Staging, live OPS, and Retool are unchanged by 01A.
12. No supplier cancellation or Warehouse stock capability is introduced.

## 15. Roadmap handoff after 01B

Successful 01B rehearsal gives the Product Owner an evidence-based branch:

```text
Does real connected operation require supplier cancellation before v1 cutover?

YES
→ SCHOOL-CATERING-SUPPLIER-CANCELLATION-01
→ OPS-V1-CUTOVER-01

NO
→ OPS-V1-CUTOVER-01
```

Only after the relevant v1 School fulfilment path is replaced should Warehouse Receiving and later stock/inventory capabilities be considered as separate business-domain work.
