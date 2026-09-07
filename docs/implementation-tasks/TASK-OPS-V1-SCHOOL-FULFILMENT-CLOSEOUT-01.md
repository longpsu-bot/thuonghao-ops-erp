# TASK-OPS-V1-SCHOOL-FULFILMENT-CLOSEOUT-01

**Status:** Implementation verified locally; Draft PR validation pending

**Owner:** Cross-domain bounded closeout: Planning, Procurement, School Dispatch

**Baseline:** `origin/main` `606009b6d9afa590a202974394194dd26d44926a`

**Branch:** `feat/ops-v1-school-fulfilment-closeout-01`

**Design:**
[2026-09-07 OPS v1 School Fulfilment Closeout](../superpowers/specs/2026-09-07-ops-v1-school-fulfilment-closeout-design.md)

**Plan:**
[2026-09-07 implementation plan](../superpowers/plans/2026-09-07-ops-v1-school-fulfilment-closeout.md)

## 1. Objective

Deliver one Draft PR containing five sequential slices:

1. truthful baseline CI repair;
2. Direct Ingredient Need convergence;
3. append-only Confirmed Need downstream correction;
4. complete replacement School-catering supplier POs;
5. immutable School/date/location Phiếu xuất kho release.

No merge, deployment, hosted mutation, OPS v1 mutation, Retool mutation, or stock
management is authorized.

## 2. Pre-implementation review record

### 2.1 Workspace and baseline

- Canonical checkout confirmed by the user:
  `D:/Project/Repo/OPS/thuonghao-ops-erp`.
- Git top level and `origin` resolve to `longpsu-bot/thuonghao-ops-erp`.
- `origin/main` was fetched and recorded at
  `606009b6d9afa590a202974394194dd26d44926a`.
- The checkout was clean before branch creation.
- The bounded branch was created directly from that exact commit.
- `pnpm ops:workspace` passed during preflight.

### 2.2 Frontend CI #688 / PR #262 regressions

Focused reproduction found one failure in each affected file.

`DishRecipeAdminWorkbench.test.tsx` prepared its selected-effective-Recipe response
for hard-coded `2026-09-06`, while the component correctly initialized to the current
Vietnam service date (`2026-09-07` during reproduction). The component's generation
guard and selected-Dish behavior are intact. The fixture date is stale; the fix is to
bind it to the runtime date while retaining the effective-detail assertion.

`RecipeAdjustmentWorkbench.test.tsx` attempted to invalidate an in-flight response by
selecting hard-coded `2026-09-07`. On the reproduction date this was already the
runtime default, so no context change occurred and the response was not obsolete.
The component's intent/generation invalidation is intact. The fix is to choose a
guaranteed different date while retaining the assertion that obsolete content never
appears.

Classification: independent time-sensitive test-fixture regressions, not production
stale-state defects and not a reason to weaken PR #257/#262 behavior.

### 2.3 RMVP-04 Full Integration #454

The verifier created its Pantry line on `weekStart`, then chose the first active Menu
line's actual `service_date` for the exact daily generation run. When that Menu line
was not Monday, the generator correctly produced Recipe evidence only for the chosen
date, so the verifier's mixed-evidence assertion failed.

The authoritative implementation uses exact service-date Pantry eligibility. The
fixture must place its Pantry line on the same selected service date. The mixed
`RECIPE_DERIVED | PANTRY_DIRECT` assertion remains unchanged.

Classification: independent verifier/currentness fixture regression, repaired in
Slice 0 before Direct Ingredient Need semantics are amended.

### 2.4 Current Pantry/direct Need persistence

Current typed structures are `pantry_need_purposes`, `pantry_need_batches`,
`pantry_need_lines`, approval snapshots, and snapshot lines. Lines already preserve
School/date/location/Ingredient/Unit/quantity/Purpose/note and materialize exact
`PANTRY_DIRECT` lineage. The aggregate currently has no additive-versus-complete
fact. Existing positive Pantry behavior is additive; existing snapshots must remain
valid without rewrite.

Purpose values such as `school_requested_supplement` describe why a line is direct.
Actual OPS v1 usage includes direct/wholesale School lists, so Purpose cannot safely
act as composition authority.

### 2.5 Need Generation

Current generation requires Menu, Attendance, and Pantry readiness for the selected
Planning Input Set. It emits typed `RECIPE_DERIVED | PANTRY_DIRECT` contributions and
preserves exact Pantry line lineage. Input snapshots currently require Menu and
Attendance references and permit nullable Pantry. Direct-complete therefore requires
a narrow conditional-nullability amendment, not fake sources or a new source
registry.

### 2.6 Historical direct-wholesale path

Historical wholesale tables and APIs (`wholesale_orders`,
`record_wholesale_source`, `release_wholesale_order`) remain compatibility surfaces.
They do not model the approved normal Application path. School is the authoritative
operational recipient for catering and direct/wholesale Need; backend compatibility
customer references derive from School.

### 2.7 Confirmed Need correction and downstream blocker

Confirmed Need already has stable lines, immutable revisions, decisions, predecessor
continuity, approval, and release evidence. Current Issue-222/D-042 guards return
`BLOCKED_BY_DOWNSTREAM_COMMITMENT` when downstream released commitments exist. The
guard protects immutable content but is too broad for the approved successor-fact
rule. It must be narrowed for the School-catering path without rewriting old facts or
silently changing supplier-direct wholesale behavior.

### 2.8 Allocation family projection/currentness

School-catering Allocation Families are keyed by service date, delivery location,
Ingredient, and Unit. Immutable family revisions own exact contribution membership
and supplier splits. Source fingerprints/currentness currently bind to released
Purchase Handoff lineage. The amendment must compare the complete current Confirmed
Need contribution membership so quantity or School redistribution produces stale
state even when a supplier aggregate total is unchanged. Revised allocation remains
an explicit Save.

### 2.9 Current PO behavior

The shared PO aggregate has immutable root/revision/line history and supports
`SUPERSEDED`, but the School-catering draft command skips roots already
`RELEASED_TO_SUPPLIER`. A unique active supplier/date index prevents a separate
replacement root. Released PO content and numbers are immutable. The implementation
must add direct predecessor lineage, permit one bounded replacement draft, and
supersede only during explicit replacement release.

If a supplier disappears from the revised allocation, Atlas must derive
`CANCELLATION_REQUIRED`, leave its old PO released and active, avoid zero-line
documents, and block overall Procurement currentness/PXK. No cancellation command is
authorized.

### 2.10 Dispatch architecture and OPS v1 evidence

Existing Atlas `create_dispatch_plan`, trip, load, and delivery commands belong to an
older supplier-direct execution model and are not the School PXK primitive.

Read-only OPS v1 and local Retool export inspection shows a simple operator flow:
choose a date/range, call `app_confirm_dispatch`, group by School/date, and export
`PHIẾU XUẤT KHO` with number/date/School/address and Ingredient/Unit/quantity/note.
OPS v1 destructively rebuilds lines. Atlas must preserve the operational simplicity
but replace rebuilds with immutable releases and typed lineage. OPS v1 evidence is
behavioral only; no live or Retool write was made.

## 3. Approved acceptance boundary

- `ADDITIVE | COMPLETE` authority lives at Pantry batch + School + service date.
- Purpose remains explanatory.
- Historical missing mode means `ADDITIVE`.
- Direct-complete Need does not require or fabricate Menu/Recipe/Attendance.
- Confirmed Need successor correction remains append-only and allowed after released
  School-catering PO/PXK.
- Allocation is stale until explicitly saved against the exact current source set.
- Positive affected suppliers receive complete separate replacement drafts.
- Old PO stays released while replacement is draft; explicit release assigns a new
  number and atomically supersedes old.
- Removed supplier derives cancellation-required, old PO stays active, Procurement
  is not current, and PXK is blocked.
- PXK is a School/date/location immutable release with read-only preview and explicit
  release/replacement; it has no stock or trip prerequisite.

## 4. Allowed and prohibited modules

Allowed: affected Planning input/Need/Confirmed Need modules, school-catering
Procurement, bounded School PXK, exact navigation/export support, focused tests,
forward migrations, and narrow authoritative documentation.

Prohibited: stock/receiving/lot/reservation/pick/movement/return/inventory work,
DispatchPlan/Trip/vehicle/driver/load expansion, generic workflow/source/recipient
models, broad dependencies or cleanup, test weakening, hosted deployment/data writes,
and OPS v1 or Retool writes.

## 5. Validation record

Local evidence recorded before the Draft PR review gate:

- [x] Slice 0 focused frontend tests: 115/115 green across the two independent
      runtime-date regression files.
- [x] RMVP-04 mixed atomic evidence: the full prerequisite browser-key chain and
      exact readiness/request/generate/validate/release/CMD-15/readback journey pass
      for generated service date `2046-08-13`.
- [x] Slice 1 focused direct-Need evidence: 24/24 pgTAP and 22/22 frontend tests.
- [x] Slice 2 focused downstream-correction evidence: 23/23 pgTAP, including an
      already released PXK that remains current and unchanged while the factual
      correction is saved.
- [x] Slice 3 focused PO replacement/removal-safety evidence: 91/91 pgTAP and
      95/95 adjacent Procurement frontend tests.
- [x] Slice 4 focused PXK evidence: 46/46 pgTAP and 48/48
      navigation/RPC/workbench/export frontend tests.
- [x] Draft hardening preserves legacy `PANTRY-02.v2` as implicit `ADDITIVE` and
      restores the untouched Planning atomic suite to 196/196.
- [x] Full Integration explicitly registers the Direct Need convergence and School
      PXK suites exactly once without removing an existing suite.
- [x] Full Integration passes all 88 registered commands end to end. Its final
      Procurement verifier now scopes the existing-batch probe with one
      argument-safe SQL string, so Windows execution cannot drop the batch filter.
- [x] Mutable School-default regression: captured Location A remains releasable
      after the default changes to same-Customer Location B; B inherits no Need and
      cross-Customer scope remains invalid. The expanded PXK suite passes 46/46.
- [x] PXK currentness is exact to service-date + School + captured location: an
      unrelated stale or cancellation-required School B PO does not block School A,
      while a shared stale PO and a cancellation-required commitment whose immutable
      lineage covered School A still block School A. Current exact Supplier 2 coverage
      also cannot override a still-active `REPLACEMENT_REQUIRED` Supplier 1 PO whose
      immutable lineage includes School A; explicit replacement release supersedes
      that predecessor and unblocks A.
- [x] All four focused business database suites pass together: 184/184 assertions.
- [x] Exact whole-platform security catalog passes 23/23 after its bounded five-table,
      two-capability, four-physical-API, and least-privilege grant update.
- [x] The platform catalog and four business suites pass together: 207/207
      assertions.
- [x] Touched-file Prettier check passes.
- [x] Typecheck and production build pass; the existing large-chunk advisory remains
      non-blocking and no build gate was weakened.
- [x] Final `git diff --check` passes after the validation record is complete.
- [ ] Exact Draft PR head Frontend CI passes.
- [ ] Exact Draft PR head Full Integration passes.
- [x] Supported local Supabase Smoke path passes end to end.
- [ ] Qodana status recorded without broad cleanup.
- [ ] Cloudflare preview URL recorded if generated.

## 6. Security, migration, and rollback

Every new relation is private, RLS-enabled/forced, and unavailable directly to
browser roles. Commands use least-privilege runtimes, fixed empty `search_path`,
fully qualified SQL, actor/capability checks, expected versions/fingerprints,
deterministic locking, idempotency, receipts, events, audits, and safe errors.

Migrations are forward-only. No Atlas Staging migration/backfill is authorized.
Operational rollback must be a forward change that disables new entry points while
retaining all immutable release evidence.
