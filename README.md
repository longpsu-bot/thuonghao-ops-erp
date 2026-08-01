# Thượng Hảo OPS ERP

**Project codename:** Atlas

Atlas is the operational management platform for Thượng Hảo's school catering and ingredient-distribution business.

The repository is the authoritative source for business definitions, architecture, contracts, implementation, tests, rollout guidance, and review history. Chat history and AI memory are working aids, not formal project records.

## Current status

Atlas has completed the Admin / Master Data Management in-memory prototype sequence, the bounded PD-05.1 Dispatch and Delivery foundation, the PD-05.2 Dispatch integration/operator-workflow review, the MVP vertical-slice operator review, and the fixture-backed MVP morning chaos simulation. The synthetic vertical slice now traces school catering, mixed fulfilment, wholesale, delivery exception/return, and blocked operating-day scenarios from source need to delivery outcome while preserving domain ownership and operator attention. Atlas page `mvp-operations-simulation` exposes the 02:00–08:00 simulation as a read-only review surface.

PA-01 defines the Atlas persistence contract. PA-02 defines the physical PostgreSQL/Supabase namespace, table catalog, typed cross-domain line spine, revision/snapshot patterns, evidence-application constraints, quantity/time conventions, transaction matrix, indexes, access preview, derived read models, legacy staging, and the first supplier-direct wholesale schema subset. PA-03 defines the actor/capability model, dedicated `atlas_api` function surface, revoke-first grants, RLS direction, security-definer hardening, mandatory idempotency and optimistic concurrency, deterministic locking/isolation, safe errors, reporting/storage/integration controls, and first-slice security tests. PA-04 is the merged version-controlled migration foundation for supplier-direct Slice 1: nine private Atlas schemas, 52 authoritative tables, two private security-invoker trace views, forced RLS, revoke-first privileges, and a 23-check pgTAP verification script. PA-05A is complete on `main` as the supplier-direct business-command/RPC and shaped-read contract. PA-05B is merged with five evidence-to-delivery commands, one authorized shaped trace, hardened runtime roles/RLS, and 64 focused pgTAP assertions. PA-05C adds three bounded, capability/scope-filtered API wrappers for evidence readiness, operator blockers, and command/audit timeline visibility. PA-05B-H1 closes Issue #82’s shared-runtime privilege risk by splitting the PA-05B command owners into Evidence and Dispatch roles, retaining read-only ownership for the approved read surface, and adding a 10-check effective-privilege audit.

PA-05D, PA-05E, PA-05B-H2, PA-05F, PA-05B-H3, and PA-05C-H2 are complete on `main`. PA-05G is implemented under Issue #100 as `supabase/tests/pa_05g_backend_end_to_end_acceptance.sql`: 82 rolled-back assertions prove one two-line/two-supplier path through all 17 command executions, exact Planning/Procurement/Evidence/Dispatch lineage, successful Trip closure, 17 completed receipts, 17 domain events, 17 audit events, all four authorized read surfaces, and the unchanged 18-function security boundary. Focused local validation passes. PA-06 is unblocked for planning only after PA-05G review and merge; React connection, deployment, production data, and rollout remain separate work.

The Planning Domain foundation and integration review are complete. The Procurement contract, bounded in-memory foundation, integration/operator-workflow review, and fulfilment-allocation amendment are complete as architecture baselines. The Warehouse domain contract, bounded in-memory receiving foundation, integration/operator-workflow review, Stock Release contract, and bounded in-memory Stock Release foundation are complete. The Admin / Master Data Management contract, School info, Ingredients & Suppliers, consolidated Dishes & Recipes foundations, and Admin integration/operator-workflow review are complete as in-memory prototypes. PD-05 Dispatch and Delivery starts from Planning-released dispatch requirements, Procurement fulfilment allocation, and physical fulfilment evidence rather than mandatory Warehouse release. Its in-memory foundation and operator review prove trip/load/delivery, attention, exception, return, and closure rules. Production/QA and Finance/Accounting are deferred for the MVP.

See [`docs/architecture/roadmap.md`](docs/architecture/roadmap.md) for current status.

## Technology direction

- React + TypeScript for the primary application and interaction layer
- Supabase + PostgreSQL for future authoritative persistence, transactions, RLS, and backend business commands
- Codex as a bounded implementation assistant
- Retool retained as OPS v1 business evidence and for selected diagnostic/support tooling
- GitHub as the project source of truth

## Continue on another computer

Cloning this repository is sufficient to recover the approved project direction and current codebase.

```bash
git clone https://github.com/longpsu-bot/thuonghao-ops-erp.git
cd thuonghao-ops-erp
pnpm install
pnpm ops:workspace
pnpm test
pnpm dev
```

Requirements:

- Git
- Node.js compatible with the repository configuration
- pnpm
- GitHub access to the private repository

No Supabase credential or production-data access is required. The PA-04 through PA-05B-H3 migrations can be verified against a disposable local PostgreSQL/Supabase-compatible database without linking a hosted project.

Before changing code, read `AGENTS.md` and the relevant domain contract.

### RMVP-01 local master data

RMVP-01 uses an independent local Atlas database and an explicit one-way JSON snapshot. It does not connect to or mutate OPS v1/v2, Retool, or a hosted Supabase project.

```bash
pnpm exec supabase db reset --local
pnpm local:master-data:import -- --file supabase/local/rmvp_01_master_data_snapshot.example.json
pnpm local:auth:provision
pnpm local:rmvp01:verify
```

The importer validates source identities and references before target writes, stores typed legacy mappings plus inserted/updated/skipped/rejected counts and source/target reconciliation, and safely replays an identical snapshot. See [`RMVP-01 independent Atlas master data`](docs/architecture/rmvp-01-independent-atlas-master-data.md) for authority-cutover and rollback boundaries.

### RMVP-02A connected recipes and BOM

RMVP-02A connects the Vietnamese `Công thức` page to the existing private Dish, Recipe, Recipe Version, stable Recipe Line, and immutable Recipe Line Revision foundation. It adds no table or role. Draft BOM replacement, validation, Planning release, successor correction, copy, and narrow reviewed OPS v1 `.xlsx` import are backend-authoritative and audited.

```bash
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql --local
pnpm local:rmvp02a:verify
```

Workbook import creates draft-only state, requires existing active references, records typed legacy reconciliation, and never mutates OPS v1/v2 or Retool. See [`RMVP-02A connected Dishes, Recipes, and BOM`](docs/architecture/rmvp-02a-connected-recipes-bom.md) and the [`RMVP-02A API contract`](docs/api/rmvp-02a-recipes-bom.md).

### RMVP-02B Recipe adjustments and effective BOM

RMVP-02B extends the same Vietnamese `Công thức` workbench with one typed adjustment model, backend what-if preview, immutable successor/cancellation lineage, and authoritative explicit-date effective BOM. Fixed precedence is released base Recipe Version, system Ingredient, system Dish, School, then School-and-Dish. Planning facts and released operational history are unchanged.

```bash
pnpm exec supabase db reset --local
pnpm exec supabase test db supabase/tests/rmvp_02b_recipe_adjustments_effective_bom.sql --local
pnpm local:auth:provision
pnpm local:rmvp02b:verify
pnpm local:recipe-adjustments:import -- --file supabase/local/rmvp_02b_adjustment_snapshot.example.json
```

The local-only importer accepts exactly four explicit OPS v1 arrays, calculates the canonical checksum, rejects missing/ambiguous/cyclic references before writes, records reconciliation, and never connects to live OPS v1. The example contains no production data. See [RMVP-02B Recipe adjustments and effective BOM](docs/architecture/rmvp-02b-recipe-adjustments-effective-bom.md) and the [RMVP-02B API contract](docs/api/rmvp-02b-recipe-adjustments-effective-bom.md).

### RMVP-03A connected Weekly Menu and Attendance

RMVP-03A activates the Vietnamese `Nguồn kế hoạch` workbench for one explicit Monday-start week. It connects the existing Weekly Menu and Attendance aggregates, stable rows, exact approval snapshots, and inherited lifecycles without adding a table, trigger, role, module, or downstream write.

```bash
pnpm exec supabase test db supabase/tests/rmvp_03a_connected_weekly_menu_attendance.sql --local
pnpm local:rmvp03a:verify
```

Workbook and tab-paste input is previewed and checksum-bound before saving. Unknown references remain visible blockers, explicit attendance zero is preserved, reasoned reopen retains approval history, and readiness is a read-only comparison of the two current approvals. See [RMVP-03A Connected Weekly Menu and Attendance](docs/architecture/rmvp-03a-connected-weekly-menu-attendance.md) and the [RMVP-03A API contract](docs/api/rmvp-03a-planning-inputs.md).

### PANTRY-02 connected Pantry source

PANTRY-02 adds Pantry as the third Planning source tab. Operators select School, Ingredient, Purpose, exact quantity, and evidence; PostgreSQL derives the exact default Delivery Location and Ingredient purchase Unit. Every save requires an authoritative preview and performs a complete stable-line replacement.

```bash
pnpm exec supabase test db supabase/tests/pantry_02_connected_pantry_source.sql --local
pnpm local:pantry02:verify
```

The lifecycle is `DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED`. Approval preserves exact immutable snapshots, including an explicit zero-additions header with no fabricated line. The production migration seeds no Purpose and writes no readiness, Need Generation, Confirmed Need, handoff, Procurement, Warehouse, Dispatch, or Wholesale fact. See [PANTRY-02 Connected Pantry Source](docs/architecture/pantry-02-connected-pantry-source.md) and the [PANTRY-02 API contract](docs/api/pantry-02-source.md).

### RMVP-03B connected Planning Input Readiness

RMVP-03B implements one exact-period, three-source readiness workbench read and three transactional commands over the existing immutable Planning Input Set persistence. PostgreSQL owns candidate selection, issue derivation, lifecycle authority, idempotency, source-currentness checks, combined history pagination, events, and audit evidence.

```bash
pnpm exec supabase test db supabase/tests/rmvp_03b_connected_planning_input_readiness.sql --local
```

The Need Generation request is a handoff marker only: it creates no run or quantity. Invalidation retains immutable evaluations and never mutates an existing run. The database/API checkpoint and connected React fourth tab are implemented on the bounded branch; final validation and independent draft-PR review remain pending. The browser registry is exactly 67 functions, and the five focused frontend files pass 47 tests. See [RMVP-03B Connected Planning Input Readiness](docs/architecture/rmvp-03b-connected-planning-input-readiness.md), the [RMVP-03B API contract](docs/api/rmvp-03b-planning-input-readiness.md), and the [implementation record](docs/implementation-tasks/TASK-RMVP-03B-connected-planning-input-readiness-implementation.md).

### RMVP-01 UI review export

The downloadable UI review is a separate, deterministic browser-only mode for owner acceptance. It contains 33 sample schools, 180 sample ingredients, and 24 sample suppliers; it requires no credentials, makes no Supabase calls, and never writes data outside the current browser session. The persistent notice `Chế độ xem thử giao diện — dữ liệu không được lưu` distinguishes this mode from the connected application.

Build it only with the explicit review command:

```bash
pnpm build:review
node scripts/create-review-launcher.mjs dist "Open Atlas Review.bat" 4173
```

The normal `pnpm build` does not enable review data and continues to use the authenticated connected adapter. GitHub Actions publishes the review build as the `atlas-ui-review` artifact from the `UI Review Export` workflow.

## Read first

1. [`AGENTS.md`](AGENTS.md) — repository operating rules and hard boundaries
2. [`ARCH-001 — OPS ERP Business Architecture`](docs/architecture/arch-001-ops-erp-business-architecture.md) — principles and domain-first method
3. [`ARCH-002 — Atlas System Map`](docs/architecture/arch-002-atlas-system-map.md) — official feature-placement, ownership, traceability, and delivery map
4. [`Atlas Vision`](docs/architecture/atlas-vision.md) — why Atlas exists and what success means
5. [`Roadmap`](docs/architecture/roadmap.md) — delivery order and current status
6. [`PA-01 — Atlas Persistence Contract`](docs/architecture/pa-01-atlas-persistence-contract.md) — proposed authority for future persistence design
7. [`PA-02 — Physical Schema and Constraint Design`](docs/architecture/pa-02-physical-schema-and-constraint-design.md) — proposed physical design before migrations
8. [`PA-03 — Authorization, Command, and Transaction Safety Design`](docs/architecture/pa-03-authorization-command-and-transaction-safety-design.md) — proposed security and command boundary before migrations
9. [`PA-04 — Supplier-direct Slice 1 Migration Foundation`](docs/architecture/pa-04-supplier-direct-slice-1-migration-foundation.md) — merged migration scope, security posture, verification, exclusions, and next gates
10. [`PA-05A — Supplier-direct command/RPC contract`](docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md) — approved callable command/read behavior
11. [`PA-05B — Supplier-direct command implementation`](docs/architecture/pa-05b-supplier-direct-command-implementation.md) — bounded SQL functions, security posture, idempotency, invariants, tests, exclusions, and next gates
12. [`PA-05C — Authorized read API wrappers`](docs/architecture/pa-05c-authorized-read-api-wrappers.md) — bounded readiness, blocker, and audit reads
13. [`PA-05B-H1 — Runtime-role hardening`](docs/architecture/pa-05b-h1-runtime-role-hardening.md) — least-privilege Evidence, Dispatch, and Read runtime ownership
14. [`PA-05D — Bounded Planning command family`](docs/architecture/pa-05d-planning-command-family-contract.md) — wholesale source-to-dispatch-requirement write contract
15. [`PA-05E — Bounded Procurement command family`](docs/architecture/pa-05e-procurement-command-family-contract.md) — exact supplier allocation and released supplier purchase-order contract
16. [`PA-05B-H2 — Multi-line Dispatch execution correction`](docs/architecture/pa-05b-h2-multiline-dispatch-execution-contract.md) — atomic multi-line load, trip-wide departure revalidation, and multi-line successful delivery
17. [`PA-05F — Bounded Dispatch setup command family`](docs/architecture/pa-05f-dispatch-setup-command-family-contract.md) — Evidence-gated Dispatch Plan, Plan Requirement, assigned Trip, and derived Stop setup
18. [`PA-05B-H3 — Successful Dispatch Trip closure`](docs/architecture/pa-05b-h3-successful-trip-closure-contract.md) — exact delivered-trip reconciliation, completion stamp, event, and audit contract
19. The relevant contract under `docs/architecture/`
20. The corresponding GitHub issue and pull request

## Architecture method

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command / Event
→ Read Model
→ Application
→ Technology
```

Business architecture comes before implementation. Implementation agents may execute approved contracts but must not invent or alter domain ownership, authoritative calculations, or production backend behavior without an explicit approved task.

## Delivery workflow

```text
Contract
→ GitHub issue
→ Bounded implementation branch
→ Tests and validation
→ Pull request
→ Review
→ Merge
```

Independent modules may be implemented in parallel when they have approved contracts, separate ownership, typed fixture interfaces, and a later bounded integration PR.

## Repository tour

- `src/modules/atlas/` — Atlas shell and application composition
- `src/modules/weekly-menu/` — Weekly Menu in-memory domain and workbench
- `src/modules/attendance/` — Attendance in-memory domain and workbench
- `src/modules/planning-input-readiness/` — Planning Input Readiness domain
- `docs/architecture/` — architecture baselines and domain contracts
- `docs/decisions/` — decision records
- `docs/business-rules/` — business-rule catalogue
- `docs/ui/` — UI specifications
- `docs/rollout/` — migration and rollout plans
- `.github/workflows/` — CI and review-artifact automation

## Standard validation

```bash
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
git diff --check
```
