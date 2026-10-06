# ATLAS-BACKEND-CONVERGENCE-02A — Backend surface audit and convergence plan

**Status:** Draft read-only audit; implementation proposals require separate approval.

**Observed:** 6 October 2026, Asia/Bangkok. Hosted catalog/statistics observations began at 03:11 UTC (10:11 Bangkok).

**Repository baseline:** `8584ee398728f790055e3c49b906a84eb02b0de3`, the verified merge commit of [PR #352](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/352). Branch: `audit/atlas-backend-convergence-02a`, created directly from clean latest `origin/main` in the owner-selected `E:/Project/OPS ERP/thuonghao-ops-erp`. The completed rehearsal branch was not rebased, reset, reused or cherry-picked. The workspace check's historical D-drive warning does not override this task's explicit checkout authorization.

**Hosted target:** Atlas Staging `rnzxmxiiqgtdevzregff`, PostgreSQL 17.6. Migration tip: `20261005032608_atlas_shopping_list_export_read`. Live OPS and Retool were not queried or changed.

**Authority:** [ARCH-002](arch-002-atlas-system-map.md), [model convergence](../decisions/decision-atlas-model-convergence.md), the [authority map through Procurement](atlas-authority-map-through-procurement.md), approved domain/API amendments and the decision/business-rule registers. **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.** Older statements that Staging is behind a September baseline are dated history; the October parity record and this inspection establish the current technical baseline, not operator acceptance.

## 1. Executive summary

The present backend is a functioning private-domain command surface with substantial historical compatibility, rather than 91 independent active implementations. There are **115 API identities, 257 Core functions, 113 private tables and two private views**. All 91 hosted migration versions and names match the repository. The existing exact security/catalog verifier passed again inside a read-only transaction. No current backend grant/RLS/catalog deviation was demonstrated.

The useful convergence targets are small: three equivalent pure-helper families; a duplicated supplier-split invariant whose two current writers differ in precision validation; and clearer ownership/caller documentation. Moving all business bodies into another schema, deleting revision/snapshot evidence, or building a generic command framework is unsupported. Source-specific allocation, date-specific currentness, Recipe context, human decisions and external commitments are semantically distinct.

**No object is certified unused or safe to retire.** Absence from normal React routing does not close external use, current contracts, import/reconciliation, immutable history or rollback obligations. The exhaustive [surface map](atlas-backend-surface-map.md) retains every API/Core signature, its evidence, all domain tables, the additional private function namespaces, legacy structures and all migration classifications.

**Implementation remains gated.** PR #352 is merged, but its [connected operator rehearsal](../testing/atlas-staging-connected-rehearsal.md) remains blocked on approved authentication. Complete that rehearsal, resolve demonstrated defects, then obtain approval of `PLANNING-PROCUREMENT-FREEZE-01` before 02B–02D. A successful catalog query is not an authenticated operator journey or a freeze approval.

## 2. Scope, evidence and acceptance

This change owns only this audit and its companion surface map. It creates no migration, SQL file, function, application behavior, dependency, test framework or hosted fixture. Existing scripts/tests/contracts are evidence; mutating verification programs were not executed. Hosted inspection used catalog/statistics SELECTs, advisors, a catalog-only DO block protected by `BEGIN TRANSACTION READ ONLY`, and non-executing EXPLAIN on direct table predicates. No business RPC was executed, even inside a rollback transaction.

Acceptance: inventory all effective API/Core identities and the requested domain relations; distinguish current calls from allowlist/test/historical evidence; give A–F retirement proof gaps; compare security with the intended contract; ground performance candidates in measurements; classify all migrations; propose bounded future slices with tests, rollback and exclusions. Focused verification checks inventory coverage, migration lineage, formatting, local links and the two-file scope. Full frontend validation belongs to the Draft PR's GitHub Actions.

Evidence strength is explicit:

| Evidence                                    | Meaning and limit                                                                                                                                         |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Current hosted catalogs and function bodies | Effective signatures, configuration, ownership, grants, RLS and textual call edges at observation time. No human-role success claim.                      |
| Current repository code/contracts/tests     | Static callers and accepted semantics at the pinned baseline. A reference in a test or registry is not a mounted React call.                              |
| PR #352 parity evidence                     | Dated structural/function/content comparison and deployed Data API/anonymous-denial checks; reused, not represented as newly repeated operator rehearsal. |
| Retained Retool/OPS-v1 evidence             | Offline fingerprints, described workflows and fixed source-table references. Current deployed Retool usage remains unverified.                            |
| Historical benchmarks/statistics            | Different dates, fixtures, settings and failed/successful paths. Not interchangeable with present operator latency.                                       |

`pg_depend` was inspected alongside current body references and repository callers. It is not a complete call graph: PostgreSQL does not track all dependencies inside string-bodied functions. Text references can also include comments or strings. No absence in either inventory proves safe deletion. See [PostgreSQL dependency tracking](https://www.postgresql.org/docs/17/ddl-depend.html).

## 3. Schema and object counts

Counts refer to existing effective hosted objects, not accumulated CREATE statements. SQL files are tracked `.sql` files across the repository, including migrations/tests/support SQL; not all 200 are migrations.

| Schema            |  Tables | Views | Indexes | Functions |
| ----------------- | ------: | ----: | ------: | --------: |
| atlas_admin       |      18 |     0 |      94 |         3 |
| atlas_api         |       0 |     0 |       0 |       115 |
| atlas_audit       |       2 |     0 |      10 |         0 |
| atlas_core        |       8 |     0 |      20 |       257 |
| atlas_dispatch    |      12 |     0 |      41 |         0 |
| atlas_evidence    |       2 |     0 |      10 |         0 |
| atlas_legacy      |       3 |     0 |      16 |        25 |
| atlas_planning    |      56 |     0 |     363 |        40 |
| atlas_procurement |      12 |     0 |      47 |         0 |
| atlas_reporting   |       0 |     2 |       0 |         0 |
| **Total**         | **113** | **2** | **601** |   **440** |

There are **200 tracked SQL files**, **91 repository/hosted migrations**, **112 authenticated-executable API identities**, and **655 RLS policies** (654 normal policies plus the separately checked Unit-lock policy). Index count includes constraint-backed indexes. There is no `atlas_warehouse` schema in this implemented surface; the bounded School PXK is not stock execution or authorization to add a fourth daily workflow stage.

## 4. API inventory and actual React callers

The companion map's API inventory assigns each of the 115 identities one primary task classification. Classification is whole-function placement, not permission to discard old contract versions accepted by the same function. `CURRENT_PUBLIC_CONTRACT` includes current documented support/composition commands even where not mounted in the normal UI. `COMPATIBILITY` still means supported behavior. No absence-only `UNUSED_CANDIDATE` is assigned.

Static source counts have different meanings:

| Surface                                        | Count | Evidence                                                                                                                                                                                                             |
| ---------------------------------------------- | ----: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Effective hosted API                           |   115 | `pg_proc` identity arguments and live grants; exact platform catalog.                                                                                                                                                |
| Browser allowlist                              |   112 | `src/modules/atlas/connection/atlasRpc.ts`; its existing registry test.                                                                                                                                              |
| Concrete non-review API adapter names          |    99 | Family `*Api.ts` methods, not all used by normal React.                                                                                                                                                              |
| Traced reachable normal vNext SQL names        |    51 | `src/main.tsx` → `AtlasVNextConnectedApp` → workbench registry/hooks/bridges, including optional Need detail and Shopping List. One additional lifecycle hook/dialog path is latent; no non-test opener was located. |
| Additional retained/support React caller names |    12 | Older generated-review/procurement workbench, standalone readiness and supplier-evidence workbenches.                                                                                                                |
| Registry names without concrete adapter        |    13 | Wholesale and older Dispatch execution family; current PA-05 contracts/tests remain.                                                                                                                                 |
| Private predecessor API reads                  |     3 | PO v1/v2 base reads and PXK v1 base; owner-only execute, current internal references.                                                                                                                                |

Primary classifications total 61 CURRENT_PUBLIC_CONTRACT, 50 COMPATIBILITY, three CURRENT_INTERNAL_SUPPORT, one UNKNOWN_REQUIRES_PROOF (`update_dish`, authority alignment below), zero LEGACY/TEST/REHEARSAL_ONLY/UNUSED_CANDIDATE. These counts describe API contract placement. External-use completeness remains unproven for every retirement candidate; UNKNOWN=1 does not imply all other external users are known.

The normal paths are Master Data; canonical Recipe/effective Change Orders; Menu/Attendance/Pantry consequential Save; daily preflight and atomic generation; Confirmed Need Save/Shopping List; explicit allocation Save; preparation; independent PO release; bounded School PXK; reconciliation. The surface map identifies the exact adapter source and traced caller paths per API.

Normal allocation still routes `CONFIRMED_NEED` and real `PURCHASE_HANDOFF` families to different writers; this is an accepted source distinction, not two current authorities for one source. Optional `ConfirmedNeedSupportDetail` calls the v1 generation read, so the low-level read cannot be labeled unused. Thirteen older wholesale/Trip names have no located React invocation beyond registry/tests, but their contracts, backend history and acceptance suites remain.

There is one additional normal read-only Edge connector, `atlas-weekly-menu-google-sync`, outside the SQL function counts. It fetches Menu source data; consequential acceptance remains a PostgreSQL command. No new Edge behavior is proposed.

## 5. Core responsibility map

The exhaustive signature index records responsibility/domain tags and evidence for all **257** Core functions. The same map separately accounts for 40 Planning guards, three Admin guards and 25 Legacy functions; ignoring those would omit important invariants/import dependencies.

| Responsibility                      | Existing family / important distinction                                                                                                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Authentication / Actor / capability | `pa_05b_current_auth_subject`, `resolve_actor`, `authorize_actor`; contract-specific authorize/global/scope adapters. Subject and active server-owned membership remain backend facts.                        |
| Receipt / idempotency               | `pa_05b_request_hash`, `begin_command`, `finish_command`; readiness/top-command receipt adapters. Child composition and request-field hash selection are not interchangeable.                                 |
| Expected-version / concurrency      | Family validate/prepare helpers, current source locks and top-command internal context. Root version, decision/revision identity, source fingerprint and expected current evaluation protect different facts. |
| Currentness                         | `issue_223_*`, `planning_contract_01_*`, `rmvp_03b_bindings_current`, `school_catering_*current/stale`, `direct_need_*`. Semantic daily freshness differs from revision-head identity.                        |
| Effective date / Recipe resolution  | `recipe_effective_*`, `rmvp_02b_*`, `uiq03a_*`, `uiq03b_*`. Strict typed/system/School contexts, dated applicability and historical resolution remain distinct.                                               |
| Planning calculation                | `rmvp_04_*`, `direct_need_*`, `issue_222/223_*`, planning contract helpers. COMPLETE direct Need must not fabricate Recipe/Attendance provenance.                                                             |
| Confirmed Need                      | `rmvp_05/06/07_*`, `d037_*`, `planning_contract_02b_*`. Human decision, validation, release and continuity evidence have different authority.                                                                 |
| Purchase Handoff                    | Materializer/release/preparation composition, `purchase_review_promote_allocations`, source projections. Planning release and Procurement acceptance retain owned boundaries.                                 |
| Procurement allocation              | `school_catering_*`, `purchase_review_*`. Shared exact-split rule candidates; different source locks/contributions remain.                                                                                    |
| PO                                  | `school_catering_po_*`, `purchase_order_revision_integrity_guard`, output freeze. Draft generation, replacement and immutable issued content are separate meanings.                                           |
| PXK / reconciliation                | `school_dispatch_*`, `school_fulfilment_*`, header freeze. Read-only comparison and issued School evidence do not create stock/trips.                                                                         |
| Error / audit / revision support    | Versioned error and `record_change/finish_success` adapters, immutable guards and snapshot helpers. Similar shape does not prove identical error certainty, attribution or membership.                        |
| Compatibility                       | Numeric-as-string adapters, base reads, renamed Recipe/Planning/Direct Need helpers. Many are on current call chains, even when their names say legacy.                                                       |

Physical `atlas_core` placement mixes cross-domain infrastructure and owned domain helpers. That obscures discoverability relative to PA-02, but current runtime ownership and contracts do not establish a blanket ownership breach. Keep the responsibility map; move a helper only for a demonstrated benefit under a separately reviewed dependency/grant contract.

## 6. Domain table ownership

The companion map classifies every table by owning domain and current fact/evidence/support meaning. All physical table owners are `atlas_owner`; business domain ownership is a separate concept. Classify contents, not whole tables indiscriminately: generated identity can carry an explicit authored decision, and current pointers can coexist with immutable revisions.

| Schema            | Durable authority and generated/derived distinction                                                                                                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| atlas_admin       | Governed party/location/Unit/Ingredient/Supplier facts, typed Recipe/BOM and dated adjustment intent/revisions. Root provisioning is generated; effective BOM and approved-Menu edit lock are derived.                                                    |
| atlas_planning    | Accepted Menu/Attendance/Pantry facts, explicit zero/no-additions and ADDITIVE/COMPLETE modes; bound generation evidence; human quantity decisions; source/release/continuity history. Readiness/currentness are derived, not another editable authority. |
| atlas_procurement | Accepted exact supplier splits and notes; allocation revisions; released PO number/content. Family identities, source promotion and drafts are generated. Balance/staleness/replacement readiness are derived.                                            |
| atlas_dispatch    | Separate older plan/trip/load/delivery facts and bounded immutable School PXK evidence. School PXK does not activate old Trip/Stop/Load stages or require stock/receiving/picking facts.                                                                  |
| atlas_evidence    | Physical supplier receipt/cross-dock quantities and exact applications. Evidence remains source-owned; Procurement commercial confirmation cannot replace it.                                                                                             |
| atlas_audit       | Append-only events/accountability in the same command transaction. Shared IDs are intentional linkage, not another editable quantity authority.                                                                                                           |
| atlas_legacy      | Import/checksum/reconciliation/mapping provenance and D-047 Unit-adoption proof. Necessary support, not routine independent business authority.                                                                                                           |
| atlas_core        | Actor/auth/membership/capability/scope facts and receipt/replay evidence. Generated receipt identity is justified security/concurrency persistence.                                                                                                       |

No table-level duplicate authority or unclear business owner was demonstrated. Specifically preserve Pantry approval-mode snapshots, plural Confirmed Need contribution membership, decision continuity, released PO output snapshots, PXK source/header snapshots and immutable D-047 adoption evidence. Deleting them would lose accepted history or proof rather than simplify state.

## 7. Legacy and compatibility retirement map

Every proposed exact object/signature must positively pass all six gates:

| Gate | Required proof                                                                                |
| ---- | --------------------------------------------------------------------------------------------- |
| A    | No React caller, including optional/retained/support callers.                                 |
| B    | No current supported contract or accepted coexistence obligation.                             |
| C    | No active Retool dependency that must remain operational.                                     |
| D    | No migration/import/reconciliation dependence.                                                |
| E    | No issued-document, immutable provenance or audit-history dependence.                         |
| F    | Tested safe rollback restoring semantics, callable identity, privileges and retained history. |

**PASS means proof of safe removal; a dependency is FAIL, absent evidence is UNPROVEN. No family below passes A–F.** Exact identity/source/incoming-reference rows in the surface map refine these families; this table is not a deletion manifest.

| Candidate family                                    | A                                                   | B                                    | C                    | D                                | E                                    | F        | Disposition                              |
| --------------------------------------------------- | --------------------------------------------------- | ------------------------------------ | -------------------- | -------------------------------- | ------------------------------------ | -------- | ---------------------------------------- |
| Low-level Recipe lifecycle/copy/old effective reads | Mixed normal/support/adapter-only                   | FAIL retained v1/v2 support          | UNPROVEN             | FAIL import/resolver use         | FAIL immutable Recipe/issuance proof | UNPROVEN | Retain; isolate normal routing.          |
| Readiness/generation v1/H0C stages                  | FAIL support read/workbench; others script/internal | FAIL coexistence                     | UNPROVEN             | FAIL tests/shared materializer   | FAIL bound run/release history       | UNPROVEN | Retain exact-day/historical rules.       |
| Confirmed Need v1 validation/approval/release       | No normal chain; tests/internal composition remain  | FAIL explicit v1 preservation        | UNPROVEN             | FAIL release/evidence checks     | FAIL decisions/snapshots/receipts    | UNPROVEN | Retain.                                  |
| Wholesale/supplier-direct/Trip surface              | No located normal School-route caller               | FAIL PA-05 contracts                 | UNPROVEN             | FAIL PA-05G lineage tests        | FAIL issued/load/delivery history    | UNPROVEN | Retain separately from School PXK.       |
| Three API predecessor reads                         | No browser execute; current API callers             | FAIL internal shaping                | UNPROVEN             | FAIL wrapper chain               | FAIL historical output shaping       | UNPROVEN | CURRENT_INTERNAL_SUPPORT; not dead APIs. |
| Core legacy/numeric compatibility aliases           | Mostly private                                      | FAIL current forwarding              | UNPROVEN             | FAIL effective call chains       | FAIL precision/history truth         | UNPROVEN | Retain required internals.               |
| Legacy imports/mappings/Unit adoption               | No direct normal React                              | FAIL governed import/D-047 contracts | UNPROVEN source-side | FAIL import/currentness proof    | FAIL provenance                      | UNPROVEN | Keep all three tables and 25 functions.  |
| Live OPS/Retool objects                             | Atlas decoupling only                               | FAIL continuity requirement          | UNPROVEN             | Known source import dependencies | UNPROVEN live retention              | UNPROVEN | Out of implementation scope.             |

Public arbitrary-period RMVP-04.v2 intent is already rejected by the retained dispatcher, while exact-day compatibility and private historical implementation remain. Do not confuse that bounded behavioral retirement with a physical deletion opportunity. Legacy index/constraint/trigger inventories are attached in the surface map and inherit their parent proof obligations.

## 8. Retool dependency evidence

No tracked Retool export JSON or legacy schema dump is present in the repository. This task did not re-open the external files or inspect the deployed Retool workspace. The [existing evidence register](atlas-model-convergence-evidence.md#5-retool--uploaded-source-evidence) retains four named exports and fingerprints: Admin, Công thức, Nguyên liệu và Nhà cung ứng, and Lên đơn/Đặt hàng. They prove earlier offline inspection, not current query deployment.

| Dependency/evidence                  | Concrete object/behavior                                                                                                                                               | Strength and retirement consequence                                                                                                                  |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Current reference-extraction script  | `public.schools`, `ingredients`, `suppliers`, `ingredient_suppliers`, `ingredient_type`, `ingredient_shopping_type` in `scripts/atlas-staging-v1-reference-source.mjs` | Current repository source dependency. Not newly queried on Live OPS. D cannot pass for source objects while extraction remains required.             |
| Recorded OPS-v1 fulfilment flow      | `app_confirm_dispatch`, then School/date grouping and PXK export; school-fulfilment closeout record                                                                    | Historical named operational dependency; current deployed invocation unverified. C/E remain open. Atlas does not copy destructive rebuild semantics. |
| Recorded preliminary PO print layout | Retool `lib/js_exportPOZip.js`, referenced by the Procurement contract                                                                                                 | Offline layout provenance. Not a live database call or permission to remove the v1 exporter.                                                         |
| Recorded XLSX import                 | Local quantity proposals followed by explicit Save                                                                                                                     | Workflow evidence retained by PR #352; no automatic database write authority.                                                                        |
| Existing migration tooling           | Fixed snapshot extractors, local imports, `atlas_legacy.import_batches/master_data_mappings/recipe_unit_adoption_evidence`                                             | Current import/reconciliation dependencies with typed provenance; no direct dependency from normal React to legacy internals.                        |

There is **no certified count of active deployed Retool database dependencies**. The surface map's UNKNOWN external-use limitation applies even when an Atlas function has a known current contract. Obtain a read-only exported query/resource inventory and operational-owner signoff before any candidate requiring C is approved. Retool's architecture remains evidence, not Atlas authority.

## 9. Security normalization audit

The existing `readCatalogAuthority`/`catalogVerificationSql` in `scripts/verify-atlas-staging.mjs` was reused with the existing identity manifest's managed application role. Its catalog-only assertions ran under database-enforced read-only transaction mode and returned `CATALOG_VERIFICATION_PASS`. The verifier checks exact signatures/owners/configuration, role posture, runtime schema CREATE, authenticated exposure, private relation access and policy count/digest. The full installer/runner was not executed.

| Check                                | Current observation                                                                                                                                                          | Assessment                                                                                                                     |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| API SECURITY DEFINER / configuration | All 115; fixed empty search_path. Only `execute_need_generation` also has reviewed `plan_cache_mode=force_generic_plan`.                                                     | Intended contract; no automatic switch to invoker.                                                                             |
| Other definer functions              | No missing fixed search_path across all 440 inspected functions.                                                                                                             | Catalog evidence; individual body qualifications still matter.                                                                 |
| Owners/runtime roles                 | Atlas roles are no-login, no-superuser, no-BYPASSRLS, no-inherit; API owners match exact domain/read runtime authority.                                                      | No role widening or reassignment proposed.                                                                                     |
| Execute                              | authenticated 112 API only; three API bases private. PUBLIC/anon/service_role execute count zero across Atlas. authenticated Core execute zero.                              | Reviewed allowlist boundary holds.                                                                                             |
| Schema grants                        | authenticated USAGE only on atlas_api; anon/service_role no Atlas schema USAGE/CREATE; non-owner Atlas runtime CREATE count zero.                                            | Current effective privileges match.                                                                                            |
| Direct relations                     | anon/authenticated/service_role have no SELECT/INSERT/UPDATE/DELETE across 113 tables/two views.                                                                             | Private RPC-only boundary holds.                                                                                               |
| RLS                                  | All 113 tables enabled and forced; normal policy digest and isolated Unit-lock policy match.                                                                                 | No missing-table-RLS finding.                                                                                                  |
| Reporting views                      | Both security_invoker=true, private.                                                                                                                                         | Preserve read runtime/base policy checks.                                                                                      |
| Actor/capability                     | Live `pa_05b_resolve_actor` uses current authenticated subject, checks asserted subject, active mapping/Actor and supported Actor type; family wrappers reuse authorization. | No user-editable metadata authorization found in reviewed normal paths. Static/delegated review, not successful human sign-in. |
| Service role / frontend              | Single reviewed SQL seam in atlasRpc; session subject injected, no automatic transport retry, no direct table seam.                                                          | No React service-role use demonstrated; no credential inventory/export performed.                                              |
| Default ACL                          | No Atlas pg_default_acl rows; existing function ACLs explicitly revoke default PUBLIC exposure.                                                                              | New functions must retain revoke-first discipline; absence of a future default rule is not a current leak.                     |
| Data API exposure / human session    | PR #352's platform verification/HTTP denial is retained evidence; not re-probed here.                                                                                        | Current successful operator authorization remains unproven. SQL privileges are not a human session.                            |

Security advisor produced **112 authenticated-definer warnings**, which describe the deliberately reviewed RPC boundary rather than 112 demonstrated defects. It also repeated **one disabled leaked-password-protection Auth observation**. That existing platform-setting finding belongs to the environment/Auth owner; no setting change is authorized or required to manufacture audit success. Guidance: [RPC lint](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Result: **zero demonstrated backend catalog/grant/RLS deviations**, one retained Auth configuration observation, and unresolved successful operator/security rehearsal. This is not blanket security certification. Grant normalization must preserve observable denial, capability/scope separation and immutable-history enforcement; do not mechanically flatten policies or owner roles.

## 10. Command/read consistency and duplicate families

Normal React consumes shaped authority. It does not rebuild Recipe precedence, Need arithmetic, PO numbering, currentness or issued snapshots from raw tables. Local split/step checks, Attendance proposals, display totals and base/effective display comparisons are advisory validation/presentation; backend command/readback remains authoritative. Pure in-memory domain models remain for original fixtures, with no located normal connected import path establishing a competing live authority.

The intended API → Core rules → domain facts direction is useful ownership guidance. PA-03/PA-05A do not require all API commands to be forwarding-only functions. Long approved API command bodies, authorized cross-domain reads and the explicitly approved preparation transaction are not automatic architectural defects. Three base API reads and numeric compatibility adapters preserve exact/historical shaping; raw-support identifiers alone do not prove unnecessary exposure.

| ID / family                               | Classification                     | Evidence / bounded conclusion                                                                                                                                             |
| ----------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D01 NFC trim/blank-to-null                | SAFE_TO_CONSOLIDATE                | `rmvp_03a_normalize_text`, `rmvp_03b_normalize_text`, `pantry_02_normalize_text`: same computation/configuration. Reuse one existing primitive behind names/ACLs.         |
| D02 JSONB UTF-8 SHA-256                   | SAFE_TO_CONSOLIDATE                | `rmvp_03a_sha256`, `rmvp_03b_sha256`, `pantry_02_sha256`: same bytes/null/hash semantics. Command request hash chooses fields and remains distinct.                       |
| D03 strict ISO-date parsing               | SAFE_TO_CONSOLIDATE for exact pair | `rmvp_03b_safe_date` and `rmvp_04_safe_date` current bodies identical. Permissive RMVP-02B and differently guarded PA-05D parser are excluded.                            |
| D04 global authorization adapters         | SEMANTICALLY_DIFFERENT             | Shared Actor/capability mechanism already exists; domain/capability/scope/error wrappers differ. Preserve them.                                                           |
| D05 versioned error envelopes             | SEMANTICALLY_DIFFERENT             | Contract version, safe details, read/command identity, blockers and certainty differ. No universal response rewrite.                                                      |
| D06 event/audit/finish families           | NEEDS_MORE_EVIDENCE                | Similar appends, different owned aggregate catalogs, runtime privileges, no-change/receipt behavior. Do not create a caller-controlled cross-domain writer.               |
| D07 supplier split validation/persistence | NEEDS_MORE_EVIDENCE                | Real repeated invariants and observed precision-check divergence; source locks/contributions differ. Investigate exact common invariant, retain source-qualified writers. |
| D08 Recipe context/resolver layers        | SEMANTICALLY_DIFFERENT             | Strict typed selection, system/School contexts and compatibility selected resolver intentionally compose. No GENERAL fallback in normal path.                             |
| D09 snapshots/revision heads              | SEMANTICALLY_DIFFERENT             | Different accepted facts/commitments/membership. Generated historical evidence remains durable; head identity is not freshness.                                           |
| D10 expected-version/receipt composition  | SEMANTICALLY_DIFFERENT             | Top command vs child receipt, root versions vs decision/source identities. No generic lifecycle machinery.                                                                |
| D11 stale/effective-date predicates       | SEMANTICALLY_DIFFERENT             | Relevant daily facts, historical range blockers, typed dated Recipe selection and downstream coverage have different meaning.                                             |
| D12 pagination/read authorization         | NEEDS_MORE_EVIDENCE                | Readiness combined history vs Confirmed Need exact partition/coherent export vs family filters. No measured/common implementation establishes safe universal paging.      |

Three small pure-helper families are safe computational candidates, **not authorization to apply a migration**. Compare null/Unicode/date/hash outputs, volatility, exceptions, effective execute grants and all callers before approved consolidation.

### D07 — observed precision discrepancy

Current hosted `school_catering_persist_allocation` lacks `INVALID_SPLIT_PRECISION`; `purchase_review_persist_allocation` contains it. Both current definitions include the October supplier-note amendment. The older writer coerces its sum to `numeric(20,6)` before comparison; the newer explicitly rejects over-precision/magnitude. Static reference: `20260831090000...` allocation body versus `20260903072648...`, amended by `20261001094403_procurement_supplier_line_note.sql`. The Procurement contract requires exact saved totals.

A safe scalar SELECT confirmed: supplied `1.0000004` becomes `1.000000` as numeric(20,6); coerced equality against `1.000000` is true, exact numeric equality is false. This proves coercion semantics and a current validation asymmetry, **not full command acceptance or production impact**. No allocation command was executed. Before a fix, reproduce the complete current Handoff-source command in an approved disposable environment and resolve its exact-total/compatibility interpretation. Frontend precision checks cannot close a backend trust boundary.

### Contract/route and certainty review risks

Confirmed Need requires explicit no-commit certainty; Procurement retains exact retry closure for contractually rolled-back retryable failures; Change Orders unlock other safe backend denials. These differences need family-level error/rollback proof before reuse, not an automatic generic certainty field.

The authority map labels generated purchase review a normal read, while the present normal vNext path uses Shopping List and retains generated review in an older component. Also RMVP-02A/D-038's older text says normal catalog editing/lifecycle controls are absent, while current vNext reaches bounded Dish metadata editing (`update_dish`). Later UI workspace documents mention metadata edit safeguards while preserving business contracts. Record this as **unresolved documentation/route alignment**, requiring Product/Architecture to identify the superseding authority; no backend rule, UI control or contract was edited by this audit. The `set_dish_lifecycle` hook/dialog code is latent: no non-test dialog opener was located, so it remains COMPATIBILITY rather than a proven reachable normal control.

## 11. Performance baseline and candidates

No optimization by intuition and no indexes added. Existing measurements identify specific generation/proof costs; this audit does not execute mutating commands to reproduce them.

| Path                         | Evidence                                                                                                                                                            | Current conclusion                                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Readiness                    | Local nested evaluation about 45 ms in final-closeout record; no current authenticated hosted distribution.                                                         | Preserve exact readiness checks; measurement gap.                                                         |
| Need Generation              | Retained hosted five-run P50 2928.917 / P95 3979.896 ms; dated normal target met. Earlier 8-second failures, guard profiles and generic-plan comparison documented. | Demonstrated historical cost and targeted fixes; no claim that old timeout remains current.               |
| Correction/rematerialization | Retained local 3891.100, 4084.594, 3977.302 ms; P50 3977.302, max 4084.594. 4-second operator target missed in that scope.                                          | Candidate P01; preserve full transaction rollback/current-source proof.                                   |
| D-047 proof                  | Retained 16-relation plan: planning 1047.557 ms, execution 0.596 ms; later local join-collapse correction.                                                          | Candidate P02: verify current planner evidence before further tuning, never remove provenance conditions. |
| Confirmed Need               | Guard costs recorded in scale work; current read/save operator distribution absent.                                                                                 | Candidate P03: exact-partition guard/read profiling after sign-in.                                        |
| Shopping List export         | Dedicated projection exists; PR #352 denial timings 993/299 ms are unauthenticated rejection, not successful read/export performance.                               | Measurement gap; no speculative cache/index.                                                              |
| Allocation / preparation     | Correctness/atomicity tests and static routes; no successful hosted runtime distribution found.                                                                     | Measurement gap; do not merge distinct writers for guessed speed.                                         |
| PO / PXK / reconciliation    | Existing immutable-snapshot/lineage scenarios; no successful hosted latency series found.                                                                           | Measurement gap; no premature stock/Warehouse abstractions.                                               |
| Workspace switching          | Retained local fixture medians181.00 ms desktop/126.45 ms narrow after persistent-workspace change.                                                                 | Frontend fixture evidence, separate from backend/network latency.                                         |

Performance evidence sources: [Need scale](../implementation-tasks/TASK-NEED-GENERATION-INTEGRITY-SCALE.md), [hosted closeout](../implementation-tasks/TASK-PLANNING-HOSTED-CLOSEOUT.md), [final closeout](../implementation-tasks/TASK-PLANNING-FINAL-CLOSEOUT-COMPLETION.md), [maintenance timeout](../implementation-tasks/TASK-PLANNING-MAINTENANCE-TIMEOUT-UX.md), [workspace fixture evidence](../ui/atlas-persistent-workspace-03c-evidence.md), and [operator rehearsal](../testing/atlas-staging-connected-rehearsal.md). These values retain their original fixture/date/transaction limits; tests' elapsed suite duration is not RPC latency.

### Newly read hosted statistics

`pg_stat_database.stats_reset` is `2026-07-24 08:28:18.170248+00`; it is not proof that function/statement statistics share exactly that window. The current inspection session has `track_functions=none`, while historical counters exist, so function counters are incomplete historical evidence. Top normalized statement entries include old execute-generation probes (one group 3 calls, mean 88295.863 ms, max 120007.595 ms), and repeated `scoped_runs/scoped_batches` proof/checkpoint queries (39 calls, mean 3333.321 ms; other groups14/10/9 calls, mean 3359.122/3256.577/3316.517 ms). Some statement texts explicitly create temporary correction checkpoints. Those operations were historical recorded SQL, **not executed by 02A**.

Historical function counters show execute-generation31 calls/126504.518 ms total, nested executor 31/126416.271, run creation 29/60977.014, generation integrity guard 23744/53083.888, membership total 8324/27881.008 and source consistency 8022/20355.257. Inclusive nested times must not be summed. Missing per-call dates/reset/role/context prevent attributing them to present normal operator behavior. P03/P04 are proof-work/query-frequency profiling candidates, not new demonstrated current SLA defects.

### Safe current plans and advisor candidates

Only non-ANALYZE, non-function direct-table generic EXPLAIN was used. The exact revision lookup uses `confirmed_need_line_revisions_validation_owner_key` (Index Only Scan, cost 0.27..1.39); exact contribution lookup uses `confirmed_need_line_revision_contributions_revision_idx` (Index Scan, cost 0.28..2.49). Date-batch and supplier-PO predicates use Seq Scan at small estimated costs 2.12 and1.02. These estimates are not runtimes, missing-index defects or plans under a human runtime role. EXPLAIN ANALYZE would execute its statement; it was not used. See [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/17/sql-explain.html).

Advisor output: **179 unindexed-FK observations**, **129 unused-index observations**, **16 multiple-permissive-policy observations**. P05 is a measured-workload triage family, not179 index additions/129 deletions/16 policy merges. Check real query plan, FK mutation workload, statistics window, constraint purpose and exact role predicate equivalence first. Guidance: [FK indexes](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys), [unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index), [policy duplication](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies).

The five performance candidate families are P01 correction tail, P02 D-047 planning cost, P03 integrity/current-source repeated proof, P04 repeated Planning proof/checkpoint query cost, P05 advisor workload triage. P01/P02 have retained measurements; P03/P04 have historical statistics/earlier profiles; P05 is unproven workload potential. None independently authorizes an optimization.

## 12. Migration history and clean bootstrap

All **91** migration versions **and names** match current Staging, with no hosted-only/missing entry. Complete per-file primary/secondary classification is in the surface map. Primary totals: 14 foundation, 45 contract evolution, 19 defect correction, 5 performance, 7 staging/import, 1 compatibility, 0 standalone physical retirement. Categories overlap through secondary tags.

Do not squash, rename, reorder or rewrite applied migrations. Later guarded `pg_get_functiondef` patches and OID-preserving renames mean the last CREATE statement alone is not current truth. In particular, `20260918064938_confirmed_need_partition_lookup_indexes.sql` also patches two integrity guards despite a stale index-only header; `20260802090000_pantry_ng_02...` includes appended function replacements despite its opening no-function comment. Approved complete implementations/task records govern; audit annotations explain the stale headers without editing historical SQL.

**Clean bootstrap recommendation:** use the existing ordered-migration replay in a new disposable environment. Separate schema replay, identity/capability provisioning, approved reference import and operational rehearsal facts. Reuse existing Supabase configuration, packages, import reconciliation and full-integration/catalog certification. No baseline generator, ORM, generic repository or new bootstrap engine is needed.

If a future measured onboarding problem justifies a versioned schema snapshot, generate it from a certified full replay, compare all effective objects/owners/grants/RLS/contract outcomes against replay, keep original history immutable, and approve a precise version boundary/forward upgrade route. It must not replace migration ledgers on existing environments. Do not copy a legacy schema dump or operational documents into a new Atlas environment as bootstrap authority.

Fresh-environment rollback is discard/replay before operational use. After use, rollback is reviewed restore/forward corrective migration with facts/revisions/receipts/releases retained; deleting a ledger entry or immutable adoption/document evidence is not rollback. 02A has no schema/data rollback effect: documentation rollback is a normal Git revert.

## 13. Proposed 02B / 02C / 02D slices

All slices are **proposals only**, after the three program gates. Each needs an exact affected-object manifest, focused regressions, updated contracts/task evidence and a separately reviewed rollback. Existing frameworks/suites are sufficient.

| Slice                                 | Allowed bounded scope/files                                                                                                                                                          | Acceptance and required checks                                                                                                                                                | Exclusions / rollback                                                                                                                                                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 02B-1 pure helper reuse               | One forward migration for D01–D03's eight existing helper identities, focused existing pgTAP extension and affected documentation.                                                   | Equal null/blank/Unicode/hash/leap-date/error results; existing aliases/callers/volatility/config/ACL preserved; catalog unchanged except reviewed bodies.                    | No API/lifecycle/quantity changes, permissive parser replacement or framework. Forward restore exact previous bodies/grants.                                                                         |
| 02B-2 allocation invariant            | First an approved disposable regression/contract review of D07; only then one bounded shared exact-split check if conflict confirmed. Current source writers/locks/lineage retained. | Over-precision/magnitude/duplicate/eligibility/total/note cases on both source kinds; one receipt/event/audit; stale/idempotent/retry rollback and immutable PO history.      | No merged aggregate, implicit supplier acceptance or silent source promotion. Forward restore body only if exact saved facts remain valid; no lossy history removal.                                 |
| 02B-3 proven retirement               | Exact identity-by-identity manifest only after A–F all pass, current contracts amend and operational owners sign off.                                                                | All clients/test/import/history paths covered; denied/old calls and restoration tested; exact grant boundary retained.                                                        | Currently **zero eligible removals**. No bulk atlas_legacy/schema/table drop or removal of private bases used now.                                                                                   |
| 02C-1 security contract normalization | Only demonstrated deviations from exact current owner/grant/RLS/capability/read contracts. Environment Auth observation routed separately.                                           | Negative anon/service/direct access; active/deactivated Actor/scope cases; fixed paths/role separation/policy digest; actual human rehearsal.                                 | No mechanical SECURITY INVOKER conversion, service-role reliance, policy flattening or broader grants. Restore reviewed privilege/policy manifest through forward correction.                        |
| 02C-2 measured performance            | One real high-value predicate/proof family at a time from P01–P05 after repeatable current baseline.                                                                                 | Same facts/outcomes/security under custom/generic plans where relevant; measured command/proof/transport scopes; timeout/no-partial-write and deferred-integrity regressions. | No speculative index cache/nesting cleanup, relaxed safeguards or universal timeout. Restore query/config/index definitions; document possible deadline regression.                                  |
| 02D bootstrap/certification           | Document and certify existing migration replay in disposable new environment; separately reviewed snapshot only if replay demonstrably insufficient.                                 | Exact history/catalog/security; same command/read/quantity/lineage/document outcomes; import replay/conflict; connected rehearsal and Product/Architecture certification.     | No historical squash, existing-environment ledger rewrite, automatic production cutover or Warehouse build. Discard disposable environment; operational recovery uses reviewed restore/forward path. |

Eight identities in 02B-1 means 3 normalizers +3 hash helpers +2 strict date parsers; it is not eight new abstractions. Consolidation should reuse the first existing implementation that satisfies the contract. Namespace cleanup alone does not warrant moving 257 Core functions.

## 14. Explicit DO-NOT-CHANGE list

- Business model, module ownership, three-stage baseline, lifecycle vocabulary, status precedence and calculation/rounding policies.
- Recipe typed context/precedence, effective dates, approved-Menu lock and truthful legacy issuance.
- Explicit zero/no-additions/direct composition, stable line identity and complete contribution/removal lineage.
- Human confirmation/supplier-split/note intent; generated support must not auto-accept it.
- Currentness, expected versions/fingerprints, deterministic locks, receipts/idempotency and whole-command rollback certainty.
- Released PO/PXK numbers/content/output snapshots; zero-supplier correction remains blocked pending approved cancellation.
- Capability/scope/RLS/backend authority, runtime role separation, deny-first privileges; no React service role.
- Applied migration text/order/ledger; immutable import/adoption/evidence/audit history.
- Current compatibility/API/Retool/OPS-v1 surfaces without A–F proof and separate approval.
- Hosted schema, functions, grants, RLS, Auth settings, business data, Retool and Live OPS in 02A.
- 02B/02C/02D implementation, speculative Warehouse facts/abstractions, new dependencies or test frameworks.

## 15. Risk matrix and recommended order

| Risk                                                                  | Severity / evidence                                                                     | Required response                                                                                                        |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Operator auth/rehearsal and freeze incomplete                         | Program blocker; matrix NOT RUN                                                         | Approved operator sign-in; complete existing matrix; resolve demonstrated defects; Product/Architecture freeze approval. |
| Retirement breaks private composition/import/history or v1 continuity | High; many positive dependencies, C/F open                                              | Retain; exact A–F proof before any removal.                                                                              |
| Allocation precision mismatch                                         | High trust-boundary review candidate; effective body/scalar proof, full command not run | Approved disposable complete-command regression and contract interpretation before fix/consolidation.                    |
| Dish route/document authority mismatch                                | Medium; older prohibition/newer metadata UI text overlap                                | Identify approved supersession; no opportunistic UI/backend change in audit.                                             |
| Error certainty generalized incorrectly                               | High data-loss risk; contracts differ                                                   | Preserve family no-commit/retry semantics; negative complete-transaction checks.                                         |
| Generated evidence mistaken for disposable state                      | High; immutable provenance/commitments                                                  | Preserve snapshots/revisions/decisions/adoption/receipts; derive only current interpretation.                            |
| Historical statistics presented as current SLA                        | Medium; old timeout/checkpoint groups, incomplete counters                              | Label window/context; obtain successful current authenticated baseline.                                                  |
| Generic advisors trigger bulk index/policy changes                    | Medium;179/129/16 raw observations                                                      | Measured predicate/role-specific triage only.                                                                            |
| Replay replaced by unproven schema dump                               | High; guarded patches/OID/history dependencies                                          | Existing chronological replay first; certified equivalent snapshot only after separate need/approval.                    |
| Existing Auth password-protection setting                             | Environment security observation; repeated advisor                                      | Environment/Auth owner review under separate authorization; do not change in 02A.                                        |

Recommended order: complete connected rehearsal → resolve demonstrated defects/document authority → approve freeze → 02B-1 small helper reuse → 02B-2 shared invariant only if needed → 02B-3 only proven retirements → 02C exact security/measured performance slices → 02D fresh bootstrap/final certification. Do not make Warehouse progress depend on aesthetic relocation; maintain the approved business gates.

## 16. Reproduction and completion boundary

Inventory source: `pg_proc`/`pg_namespace` with `pg_get_function_identity_arguments`, effective owners/config/ACL and privilege probes; `pg_class`/`pg_policy`/`pg_roles`/memberships/default ACLs; current function-body references; all tracked migration versions/names; repository callers/contracts/tests/scripts. Function hashes were observed for inventory identity, not used as an unsupported all-body-parity claim. PR #352 retains the earlier structural/content comparison.

Safe representative queries (SELECT/EXPLAIN only):

```sql
select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
       pg_get_userbyid(p.proowner), p.prosecdef, p.proconfig, p.proacl,
       has_function_privilege('authenticated',p.oid,'EXECUTE')
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname like 'atlas_%' order by 1,2,3;

select version,name from supabase_migrations.schema_migrations order by version;

explain (format json, generic_plan true)
select confirmed_need_line_revision_id,confirmed_need_line_id
from atlas_planning.confirmed_need_line_revisions
where confirmed_need_batch_id=$1::uuid
  and confirmed_need_line_revision_id=$2::uuid;

explain (format json, generic_plan true)
select confirmed_need_line_revision_id,theoretical_need_line_id
from atlas_planning.confirmed_need_line_revision_contributions
where confirmed_need_batch_id=$1::uuid
  and confirmed_need_line_revision_id=$2::uuid;
```

Focused deliverable validation must show all 115 API / 257 Core / 113 table / 91 migration rows, exact classification totals, correct local links, formatting, and a docs-only diff. GitHub's `Frontend CI / Format, typecheck, test, build` owns routine full validation. The Draft remains subject to Product/Architecture review; merging 02A would approve documentation only, not implicitly authorize implementation, hosted changes or freeze.

**02A effects:** BUSINESS_MODEL_CHANGES=0; SUPABASE_WRITES=0; RETOOL_CHANGES=0; LIVE_OPS_CHANGES=0. Catalog/statistical observation naturally does not freeze concurrent external activity, and is not a before/after business-content proof. No application behavior or migrations changed; no data payloads/credentials exported into the PR. Ponytail FULL: two evidence documents, existing verifier/frameworks, zero new operational machinery.

**Next task:** resume `ATLAS-STAGING-PARITY-REHEARSAL-01` with approved operator authentication, then resolve only demonstrated findings and seek `PLANNING-PROCUREMENT-FREEZE-01`. Keep 02B–02D proposed until those gates pass.
