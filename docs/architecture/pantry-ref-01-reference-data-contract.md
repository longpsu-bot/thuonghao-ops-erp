# PANTRY-REF-01 — Pantry Reference-Data Contract and Readiness Gate

- **Status:** Accepted product and reference-data contract
- **Approved by:** Product owner
- **Approval date:** 2026-07-28
- **Baseline:** `dd1c20d13af98cd7804436c54e469f5856d06326`
- **Task type:** Documentation and product decision only
- **Implementation:** Prohibited in PANTRY-REF-01
- **Next gate:** PANTRY-02 remains separately authorized and must not begin before this contract is merged

Related authority:

- [PANTRY-01 Planning-Owned Pantry Source Contract](pantry-01-planning-owned-pantry-source-contract.md)
- [Decision PANTRY-01](../decisions/decision-pantry-01-planning-owned-pantry-source.md)
- [RMVP-01 Independent Atlas Master Data](rmvp-01-independent-atlas-master-data.md)
- [PA-02 Physical Schema and Constraint Design](pa-02-physical-schema-and-constraint-design.md)
- [Decision PA-06E-H0A1 School and Delivery-Location Ownership](../decisions/decision-pa-06e-h0a1-school-delivery-location-ownership.md)
- [PANTRY-REF-01 decision record](../decisions/decision-pantry-ref-01-reference-data.md)
- [PANTRY-REF-01 task record](../implementation-tasks/TASK-PANTRY-REF-01-reference-data-contract.md)

## 1. Decision outcome and approval gate

PANTRY-REF-01 defines the mandatory reference-data contract that PANTRY-02
must implement. It does not create or change data.

The contract has two responsibilities:

1. approve a small, typed Pantry Purpose vocabulary that explains why Planning
   is recording an additional Ingredient need; and
2. define the exact readiness checks for existing School, Delivery Location,
   Ingredient, and Ingredient purchase-Unit references.

Repository authority and the retained read-only Pantry evidence did not
establish an exact production Purpose vocabulary. The Product Owner therefore
reviewed the proposed registry and assumptions and, on 2026-07-28, explicitly
approved both Purpose rows and `PREF-A01` through `PREF-A09` exactly as
proposed.

That approval accepts this documentation contract only:

- the Purpose registry is accepted business authority;
- no Purpose seed or production-data mutation is authorized;
- PANTRY-02 must not begin before this contract is merged and PANTRY-02 is
  separately authorized; and
- no implementation or deployment authority is inferred from product
  approval.

## 2. OPS_SYSTEM_MAP placement

| Layer               | PANTRY-REF-01 placement                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Mission             | Capture every additional operational Ingredient need with explainable purpose and valid typed references before purchasing or fulfilment.                    |
| Business Capability | Govern Pantry Purpose vocabulary and determine whether existing Planning/Admin references are ready for Pantry capture.                                      |
| Business Domain     | Planning owns Pantry Purpose meaning and Pantry reference validation; Admin / Master Data retains School, Delivery Location, Ingredient, and Unit authority. |
| Business Object     | `PantryNeedPurpose`; existing `School`, `DeliveryLocation`, `Ingredient`, and `Unit`.                                                                        |
| Business Contract   | This contract and PANTRY-01.                                                                                                                                 |
| Command / Event     | None. PANTRY-02 may later implement only the bounded Pantry commands and events authorized by PANTRY-01.                                                     |
| Read Model          | None. PANTRY-02 may later return eligible references and structured blockers through its bounded shaped-read surface.                                        |
| Application         | None. A future connected Pantry UI renders authoritative labels, note rules, statuses, order, references, issues, and allowed actions returned by Supabase.  |
| Technology          | Documentation only: zero relations, columns, APIs, capabilities, roles, policies, grants, seed rows, hosted resources, or data mutations.                    |

PANTRY-REF-01 does not move Pantry outside Planning and does not transfer
master-data ownership to Planning.

## 3. Authority and evidence finding

Approved repository authority establishes:

- Pantry is a Planning-owned source of additional Ingredient demand;
- every positive Pantry line has a typed Pantry Purpose;
- a valid zero-line approval uses the batch-level
  `no_additions_confirmed = true` fact and has no Pantry Purpose;
- legacy Pantry evidence records date, School, Ingredient, quantity, editable
  note, and an Ingredient-derived purchase Unit;
- Atlas uses typed Schools and same-customer default Delivery Locations;
- Atlas Ingredients have `ACTIVE`, `INACTIVE`, and `ARCHIVED` lifecycle
  states and may hold a nullable `purchase_unit_id`;
- Atlas Units have `ACTIVE` and `INACTIVE` lifecycle states; and
- current master-data commands require an active Unit when an Ingredient's
  purchasing fields are created or updated.

The retained `OPS - Lên đơn, Đặt hàng (1)` Retool JSON, verified at SHA-256
`6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371`,
is operational evidence only. Direct review of `ctl_pantry_load`, `tblPantry`,
`q_pantry_load`, `q_pantry_ingredients`, and `q_pantry_save_upsert` confirms
the Pantry fields recorded by PANTRY-01 and shows no authoritative, stable
Purpose catalog. Free-text legacy notes and numeric legacy identities cannot
be promoted into Atlas Purpose codes.

The evidence therefore does **not** establish:

- the number of initial Pantry Purposes;
- stable production codes;
- production Vietnamese labels or descriptions;
- Purpose display order;
- Purpose-specific note requirements; or
- whether a broader non-default Delivery Location is valid for a School.

Those are product decisions, not engineering inferences.

## 4. Canonical accepted Pantry Purpose registry

This table is the sole complete PANTRY-REF-01 Purpose registry. Other
PANTRY-REF-01 documents may summarize it or link to it but must not reproduce
the complete table.

The Product Owner approved every row below exactly as proposed on 2026-07-28.

<!-- prettier-ignore -->
| Stable lowercase code | Vietnamese operator label | Concise business meaning | Initial status | Display order | Note rule | Permitted use | Prohibited interpretation | Approval status |
|---|---|---|---|---:|---|---|---|---|
| `school_requested_supplement` | Bổ sung theo yêu cầu của trường | An identified School has explicitly requested an additional Ingredient quantity for the stated service date beyond the demand already represented by controlled Planning sources. | `ACTIVE` | 10 | `REQUIRED` | Record a positive additional Ingredient quantity for the same School, valid destination, and service date; the note identifies the request and explains what is being added. | Not a supplier choice, Purchase Order reason, Warehouse request, stock adjustment, Recipe override, Ingredient substitution, Dispatch exception, or permission to bypass Planning approval. | `APPROVED 2026-07-28` |
| `planning_identified_supplement` | Bổ sung do bộ phận Kế hoạch xác định | Planning or catering operations has identified a specific additional Ingredient quantity required to deliver service for the stated School and service date, and that quantity is not represented by another controlled Planning source. | `ACTIVE` | 20 | `REQUIRED` | Record a positive, service-specific addition after the responsible operator states the operational cause and confirms that it is not already represented elsewhere. | Not a generic “other” bucket, unnamed buffer, procurement rounding, safety-stock target, Warehouse routing, spoilage/stock correction, Recipe correction, substitution, Purchase Order reason, or Dispatch exception. | `APPROVED 2026-07-28` |

No third catch-all row is accepted. In particular, there is no `OTHER`,
`NO_ADDITIONS`, free-text-only, supplier, Warehouse, stock, Recipe,
substitution, Purchase Order, or Dispatch purpose.

### 4.1 Code contract

- Codes are stable lowercase `snake_case` business identifiers.
- Codes are not derived from numeric legacy IDs, UI order, labels, or database
  UUIDs.
- Once a code has been used by an operational Pantry line or approval
  snapshot, it is immutable.
- A label, description, status, display order, or note rule may change only
  through a separately approved governed catalog change. Such a change never
  rewrites a prior Pantry approval snapshot.
- Display order is an operator-presentation fact, not identity or precedence.

### 4.2 Status and selection contract

- Initial registry status is either `ACTIVE` or `INACTIVE`.
- Only an `ACTIVE` Purpose may be selected for a new or corrected positive
  active Pantry line.
- An `INACTIVE` Purpose remains readable in historical working facts and
  immutable approval snapshots.
- If a selected Purpose becomes inactive before validation or approval, the
  current line is blocked until the operator selects an active Purpose and
  reviews the resulting signature change.
- The caller and React may not author Purpose status, order, label, note rule,
  or an unregistered code.

### 4.3 Note-rule contract

The future typed Purpose catalog must represent exactly one note rule per
Purpose:

| Note rule    | Line requirement                                                                                      |
| ------------ | ----------------------------------------------------------------------------------------------------- |
| `OPTIONAL`   | A note may be absent. If supplied, it must contain non-whitespace text after canonical normalization. |
| `REQUIRED`   | A note must contain non-whitespace text after canonical normalization.                                |
| `PROHIBITED` | A note must be absent after canonical normalization.                                                  |

For every rule:

- the note is line evidence, not Purpose identity;
- a note cannot replace a typed Purpose;
- React may collect and display the note but cannot decide whether it is
  required;
- preview, save, validate, and approve must apply the authoritative current
  Purpose rule;
- the canonical signature includes the normalized note; and
- the approval snapshot preserves the exact approved Purpose identity,
  code/label snapshot, note rule needed for interpretation, and line note
  where present.

The two accepted initial rows both use `REQUIRED`. No initial `OPTIONAL` or
`PROHIBITED` row is accepted.

## 5. Reference-readiness gate

PANTRY-02 must fail closed. A reference is selectable only when all criteria
for that reference pass at the time of the authoritative read. Preview, save,
validate, and approve must recheck current authority rather than trust a
previous browser result.

The shaped read should omit a reference from selectable results when
appropriate and return a structured blocker for an existing draft or submitted
identity that is no longer ready. React must not reconstruct eligibility from
raw rows.

### 5.1 School

A School is selectable only when:

1. `atlas_admin.schools.school_id` resolves to an existing typed Atlas School;
2. `school_status = 'ACTIVE'`;
3. its parent Customer still has `customer_type = 'SCHOOL_CATERING'`;
4. its parent Customer has `customer_status = 'ACTIVE'`; and
5. the authenticated caller is authorized for that School through the existing
   reviewed Atlas capability and scope model.

The School identity must be supplied as an existing typed ID returned by an
authorized read. A name, code, display order, legacy ID, client object, or
caller-authored customer relationship is not authority.

PANTRY-REF-01 creates no School relation, lifecycle, scope kind, capability,
role, policy, grant, or authorization inheritance rule.

### 5.2 Delivery Location

A Delivery Location is selectable for a Pantry line only when:

1. `atlas_admin.delivery_locations.delivery_location_id` resolves to an
   existing Atlas Delivery Location;
2. `location_status = 'ACTIVE'`;
3. its `customer_id` equals the selected School's `customer_id`;
4. on the approved baseline, its ID equals the School's existing
   `default_delivery_location_id`; and
5. the caller is authorized for the resulting School/location context through
   existing reviewed Atlas scope rules.

Criterion 4 is the only current typed School-to-location relationship in the
approved schema. Same-customer membership alone does not prove that another
location is valid for a School. A broader selection rule requires a separately
approved Admin / Master Data relationship before PANTRY-02; it must not be
invented in Pantry input or React state.

No caller-authored `school_id`/`delivery_location_id` association is accepted.
PANTRY-REF-01 creates no Pantry-specific location table or relationship.

### 5.3 Ingredient

An Ingredient is selectable only when:

1. `atlas_admin.ingredients.ingredient_id` resolves to an existing Atlas
   Ingredient;
2. `ingredient_status = 'ACTIVE'`;
3. `purchase_unit_id is not null`; and
4. `purchase_unit_id` resolves through its typed foreign key to an existing
   Unit whose `unit_status = 'ACTIVE'`.

`INACTIVE` and `ARCHIVED` Ingredients are not selectable. PANTRY-REF-01 adds no
Ingredient purchasing-field, supplier, package, conversion, or stock
requirement beyond the four criteria above.

Supplier eligibility, supplier priority, supplier availability, Warehouse
stock availability, and Warehouse routing are not Pantry reference-readiness
criteria.

### 5.4 Unit

Unit authority remains exactly:

```text
atlas_admin.ingredients.purchase_unit_id
→ atlas_admin.units.unit_id
```

The operator does not select a Unit. React does not submit, map, infer, cache as
authority, or override a `unit_id`.

PANTRY-02 must later:

1. accept the Ingredient identity without caller-authoritative Unit identity;
2. resolve the current non-null `purchase_unit_id` on the backend;
3. require the resolved Unit to be `ACTIVE`;
4. return the resolved Unit ID, code, and label for review;
5. re-resolve it during preview, save, validate, and approve;
6. include the resolved Unit in the canonical signature and working fact; and
7. block a missing, inactive, or stale persisted Unit until authoritative
   refresh and reviewed save.

PANTRY-REF-01 introduces no Ingredient Unit Profile, Unit conversion, fallback
Unit, client-side mapping, or caller override.

### 5.5 Purpose

A Purpose is selectable only when:

1. it resolves to an existing typed Pantry Purpose row;
2. its status is `ACTIVE`;
3. the line satisfies its authoritative note rule; and
4. the Purpose is attached to a positive active Pantry line.

No Purpose is selectable for a zero-line no-additions approval.

## 6. Zero-additions boundary

PANTRY-REF-01 preserves the PANTRY-01 controlled-absence contract:

- `no_additions_confirmed = true` is authoritative batch-level absence
  evidence;
- a zero-line approved snapshot has no Pantry Purpose;
- Pantry Purpose is required only for positive active Pantry lines;
- no Purpose such as `NO_ADDITIONS`, `NONE`, or `NOT_APPLICABLE` may replace
  the batch-level boolean;
- no zero-quantity Pantry line may be created; and
- one or more active lines require `no_additions_confirmed = false`.

## 7. Validation and blocker behavior

Future PANTRY-02 preview, save, validate, and approve must return safe,
structured blockers for at least:

- unknown, inactive, or unauthorized School;
- inactive School Customer or invalid customer classification;
- unknown, inactive, wrong-customer, non-default, or unauthorized Delivery
  Location;
- unknown, inactive, or archived Ingredient;
- missing Ingredient `purchase_unit_id`;
- unknown or inactive resolved Unit;
- persisted Unit stale against the Ingredient's current purchase Unit;
- unknown or inactive Purpose;
- missing required note, present prohibited note, or whitespace-only supplied
  note;
- any caller-authored Unit or School/location relationship treated as
  authoritative;
- a Purpose on a zero-line no-additions batch; and
- a positive active line without an active Purpose.

Failures write no partial Pantry state. Changing a reference, Purpose, or note
changes canonical business content and therefore changes the source signature.

## 8. PANTRY-02 preservation boundary

PANTRY-REF-01 does not expand PANTRY-02.

PANTRY-02 remains limited to:

- exactly five private Pantry relations;
- at most six APIs;
- at most one new capability;
- zero new roles, including runtime roles;
- one bounded migration; and
- reuse of existing Planning runtimes.

The future typed Purpose catalog is one of the five relations already
authorized by PANTRY-01. Reference validation must reuse the existing Admin
relations. It does not justify another Purpose, School, location, Ingredient,
Unit, mapping, profile, or readiness relation.

Hosted or production Purpose seed remains a separate deployment decision even
after product approval. Approval of codes and labels does not itself authorize
inserting rows.

## 9. Security, historical meaning, and ownership

- Admin / Master Data retains authority over Schools, Delivery Locations,
  Ingredients, and Units.
- Planning owns Pantry Purpose meaning and validation of a submitted Pantry
  line against current references.
- Browser roles receive no direct private-relation access.
- Existing capability and scope evaluation remains backend-authoritative.
- React receives no service-role credential and no permanent Purpose or Unit
  mapping.
- A later master-data or Purpose change may block new work but never rewrites
  an immutable Pantry approval snapshot.
- Pantry reference validity does not grant supplier, Warehouse, Procurement,
  Dispatch, Admin, or legacy-system write authority.

## 10. Product Owner-approved assumptions and decisions

The Product Owner approved `PREF-A01` through `PREF-A09` exactly as proposed on
2026-07-28.

| ID         | Accepted assumption or decision                                                                                                                       | Approval basis                                                                                        | Status                |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------- |
| `PREF-A01` | The initial vocabulary has exactly two Purposes: School-requested supplement and Planning-identified supplement.                                      | Retained evidence proves no production Purpose list; Product selected the bounded initial vocabulary. | `APPROVED 2026-07-28` |
| `PREF-A02` | Request origin is the useful initial distinction: an identified School request versus an internally identified Planning/catering need.                | Product accepted this categorization as the first-slice business distinction.                         | `APPROVED 2026-07-28` |
| `PREF-A03` | Both initial Purposes start `ACTIVE`; there is no initially inactive row.                                                                             | Product approved the initial lifecycle state.                                                         | `APPROVED 2026-07-28` |
| `PREF-A04` | Both initial Purposes require a non-blank note; no initial Purpose has an optional or prohibited note.                                                | Product approved the mandatory line-evidence rule.                                                    | `APPROVED 2026-07-28` |
| `PREF-A05` | The exact stable codes and Vietnamese labels in section 4 are the accepted initial production vocabulary.                                             | Product approved the exact codes and operator wording.                                                | `APPROVED 2026-07-28` |
| `PREF-A06` | Display orders are 10 and 20, leaving deterministic gaps for later separately approved additions.                                                     | Product approved the initial presentation order.                                                      | `APPROVED 2026-07-28` |
| `PREF-A07` | `planning_identified_supplement` is sufficiently exact with a mandatory causal note and will not become a generic `OTHER` bucket.                     | Product accepted its bounded meaning and governance rule.                                             | `APPROVED 2026-07-28` |
| `PREF-A08` | A selectable School also requires its parent `SCHOOL_CATERING` Customer to be active.                                                                 | Product approved the parent-customer operational-readiness gate.                                      | `APPROVED 2026-07-28` |
| `PREF-A09` | On the current schema, the only selectable location for a School is its exact active `default_delivery_location_id`; same-customer alternatives fail. | Product approved the first-slice School/location gate.                                                | `APPROVED 2026-07-28` |

If the Product Owner wants another Purpose, each added row must provide every
column in the canonical registry. A generic `OTHER` or free-text-only Purpose
requires explicit approval of its exact business meaning and a mandatory note
rule.

## 11. Acceptance outcome

PANTRY-REF-01 is accepted because:

1. the Product Owner explicitly approved every registry row and `PREF-A01`
   through `PREF-A09` exactly as proposed;
2. the architecture contract remains the sole complete registry;
3. the decision record and decision register record the accepted outcome;
4. all School, Delivery Location, Ingredient, Unit, Purpose, and zero-additions
   rules remain exact and backend-authoritative;
5. PANTRY-02 limits remain unchanged; and
6. the change remains documentation-only.

Product approval satisfies the product-contract gate only. It authorizes no
seed, migration, API, React, hosted, production, or legacy-system action.

## 12. Explicit exclusions and change effect

PANTRY-REF-01 adds zero:

- relations or columns;
- SQL files or migrations;
- functions, APIs, commands, events, or read models;
- capabilities, roles, policies, grants, or runtime changes;
- seed rows or production-data mutations;
- React or generated-type changes;
- hosted Supabase resources;
- OPS v1, OPS v2, or Retool changes;
- Planning Input Readiness or Need Generation changes; and
- PANTRY-02 implementation.

There is no database migration or rollback effect. Documentation rollback is a
normal Git revert. No operational or released fact changes.
