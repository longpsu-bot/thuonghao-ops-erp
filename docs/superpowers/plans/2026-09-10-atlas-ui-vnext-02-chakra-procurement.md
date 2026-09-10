# Atlas UI vNext Procurement Implementation Plan

> Execute inline with the executing-plans skill. User requires exactly one agent; no delegation.

**Goal:** Deliver a Chakra v3 Procurement workbench over existing authoritative APIs, for local review and Storybook only.

**Architecture:** A narrow business-only bridge imports the existing request builders and models. A Procurement-specific controller owns scope generations, authoritative readback and command locks; focused Chakra components own local operator interaction. Backend remains the sole business authority.

**Tech stack:** Existing React, TypeScript, Chakra 3.37, Vitest and Testing Library. No new dependencies.

**Spec:** `docs/ui/atlas-vnext-design-language-v1.md`, D-034/D-035/D-045, `docs/api/school-catering-procurement.md`, and user task ATLAS-UI-VNEXT-02-CHAKRA-PROCUREMENT.

## Global constraints

- Start exactly at `6413d787539a5651f59956540f1fdc449b4665c2`, branch `feat/atlas-ui-vnext-02-chakra-procurement`.
- User approved creating this branch from the verified baseline in the clean E: checkout.
- Only `src/vnext/atlas/`, the boundary checker/tests, and task documentation may change.
- No backend, database, auth, API/model, legacy presentation/test, production routing, palette or dependency changes.
- Current confirmed-allocation path includes source-qualified Handoff compatibility when returned by that read; no recommendation bulk-confirmation UI.
- Decimal comparison uses six-place BigInt scaling. Proposals modify local drafts only. Explicit Save sends exact strings.
- Requests retain builder-owned version, source, auth subject, correlation and idempotency. Explicit retry reuses the same request; no automatic write retry.
- Stale/unknown outcomes and failed readback lock commands until successful authoritative recovery. New scope supersedes prior asynchronous work.
- One h1 and two operator jobs. Existing date/refresh/provider/shell and semantic recipes; 62/38 attached detail, local scrolling and stacked narrow layout.
- One Draft PR, no merge. No hosted business writes. Evidence and screenshot binaries stay outside the repository.

## Task 1 — business bridge and exact quantities

Files: `src/vnext/atlas/bridges/procurement.ts`, `procurement/procurementExactQuantity.ts`, matching tests, boundary checker/tests.

Bridge permits only reviewed `purchaseReviewApi`, `schoolCateringProcurementApi`, `schoolCateringProcurementModel`, `procurementOperatorCopy`, and type-only `connection/atlasRpc`. Their imports are non-presentation; the RPC module only imports the Supabase client type. Export libraries are excluded.

- [x] Write failing tests for six-place parsing, zero, large precision, invalid values, exact sum/difference, trimmed Vietnamese display and the exact bridge registry.
- [x] Run `pnpm exec vitest run src/vnext/atlas/procurement/procurementExactQuantity.test.ts scripts/check-atlas-vnext-ui-boundary.test.mjs` and observe red.
- [x] Implement `parseExactQuantity(string): bigint | null`, `formatExactQuantityForOperator(string | bigint | null): string`, and `sumExactQuantities(string[]): bigint | null`; run green and commit.

Example acceptance: `parseExactQuantity('9007199254740993.000001') === 9007199254740993000001n`; `sumExactQuantities(['0.1','0.2']) === 300000n`; invalid input never becomes zero.

## Task 2 — allocation reads and operator surface

Files: `ProcurementWorkbench.tsx`, `useProcurementWorkbench.ts`, `ProcurementAllocationTable.tsx`, `ProcurementSchoolScope.tsx`, workbench tests and local fixture data.

Interface: workbench accepts `authSubject`, `purchaseReviewApi`, `procurementApi`, `initialServiceDate`, optional `schools`, `initialStage`, `onExportXlsx` and `onExportPdf`. Reads consume the unmodified confirmed read builder and PO read builder.

- [x] Write and observe failing tests for initial read, single date scope, explicit School Apply, all-selection normalization, cancelled/zero School drafts, local search/filter, read supersession and failed-read command locks.
- [x] Implement scope generation invalidation before initiating reads; clear obsolete detail/draft, preserve catalogue, discard stale responses and fail closed.
- [x] Build table with operator state labels, precise quantities, explicit actions and semantic selected rail. Test absence of technical identities and keyboard/focus behavior.
- [x] Run targeted green tests and commit.

## Task 3 — supplier decisions and dirty dialog

Files: `ProcurementSupplierDetail.tsx`, `ProcurementSupplierDetail.test.tsx`.

Interface: authoritative `row`, `disabled`, `onSave(SupplierSplitInput[])`, `onClose()`; controller owns post-save readback. Remount detail on authoritative read replacement.

- [x] Write/observe red tests for saved splits, exact balance, invalid/blank quantities, backend action denial, eligible additions/removal, advisory recommendation/rebalance, ineligible historical split visibility, exact Save payload and focus.
- [x] Implement participating supplier editor and compact running balance. Do not derive proposals locally.
- [x] Write/observe red dirty-close tests: clean closes immediately; dirty opens Chakra Dialog; cancel retains draft; discard closes; reopening restores authority. Portal content remains under `.atlas-vnext`.
- [x] Run green tests and commit.

## Task 4 — commands, recovery and preparation

Files: controller, `ProcurementCommandFeedback.tsx`, workbench tests.

- [x] Write/observe red for source-qualified confirmed Save and Handoff Save compatibility, authoritative readback, stale locks, transport/rejected-promise unknown locks, explicit exact-request retry and cancellation of obsolete retries.
- [x] Map operator-safe feedback without diagnostic codes or versions. Distinguish uncertain completion from safe retryable failure.
- [x] Write/observe red for ready/allowed/current preparation with no active editor, exact preparation builder, PO readback before stage transition, failed readback uncertainty and recovery.
- [x] Implement one command runner with immediate duplicate suppression, generation guards, retained retry closure and successful-read-only unlock; run green and commit.

## Task 5 — purchase orders

Files: `ProcurementOrdersStage.tsx`, `ProcurementOrdersStage.test.tsx`, controller tests.

- [x] Write/observe red for supplier table/detail, exact lines, focus return, DRAFT_CURRENT release, DRAFT_STALE materialization, released replacement, cancellation blocker, superseded history and immutable export eligibility.
- [x] Implement one dominant action per backend state. Use existing builders; never regenerate lines or mutate released snapshots in React.
- [x] Preserve warnings with state and secondary XLSX/PDF callback actions; test stale/unknown safety and exact request/readback semantics; run green and commit.

## Task 6 — deterministic review fixtures and stories

Files: `procurementReviewFixtures.ts`, `ProcurementWorkbench.stories.tsx` and fixture tests.

- [x] Provide typed local API fixtures for normal, saved split, rebalance, reallocation, blocked, empty, read failure, retryable failure, unknown, ready, draft/stale/released/replacement/cancellation/superseded PO states. Fixtures return explicit snapshots, not duplicated backend algorithms.
- [x] Wrap every story with AtlasVNextProvider and AtlasVNextShell. Keep global Storybook untouched.
- [x] Verify fixture interactions with focused tests and commit.

## Task 7 — visual verification and closeout

- [x] Create an external pure-vNext local harness. Block non-local HTTP/WebSocket traffic. Capture browser version/DPR, console, network, required scenarios and 1366×768, 1440×900, 1920×1080, 360×800 viewports.
- [x] Inspect desktop density, toolbar, local overflow, detail ratio/minimum, balance/footer reachability, Vietnamese wrapping, School/Dialog keyboard use, focus, reduced motion and selected rails. Fix verified defects with focused regression tests.
- [x] Produce the eight-panel contact sheet outside the repository and record exact paths.
- [x] Fresh `pnpm ui:vnext:check`, `pnpm ui:vnext:typegen`, `pnpm typecheck`, all vNext Procurement tests, unchanged legacy Procurement regression, `pnpm build`, `pnpm build-storybook`, touched-file Prettier and `git diff --check`.
- [x] Self-review security and scope, document files/bridge/parity/evidence/risks. No migration or rollback effects; removal of isolated vNext files rolls back this presentation.
- [ ] Narrow commits, push branch, open one Draft PR with required evidence and exact start/final SHAs. Stop without merging; broad certification belongs to GitHub Actions.
