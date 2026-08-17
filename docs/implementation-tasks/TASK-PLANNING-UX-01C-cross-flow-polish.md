# PLANNING-UX-01C — Complete Planning operator journey polish

## Status

Implemented and locally validated on branch
`feat/planning-ux-01c-cross-flow-polish` from exact baseline
`80cdc2d6bf8d9374822c2e869fa2b93ab97df942`.

## Outcome

The Planning Application now presents one business-facing weekly sequence:

```text
Thực đơn → Sĩ số → Nhu cầu bổ sung → Tạo nhu cầu → Xác nhận nhu cầu
```

Primary screens use operator language, a restrained typographic hierarchy, and
one clear next action. Version identifiers, comparison signatures, source
counts, and other support evidence remain available in closed disclosures.

## Nhu cầu bổ sung

The former Pantry label is replaced on operator-facing surfaces by
`Nhu cầu bổ sung`. The workbench follows the established consequential-write
pattern:

```text
chỉnh sửa → Xem thay đổi → Lưu
```

Save remains unavailable until the exact current draft has a successful
authoritative Preview. Any material edit invalidates that Review. The explicit
zero-row confirmation remains available, and successful Save adopts the
authoritative readback. An unknown write outcome is reconciled by refreshing
the latest authoritative data rather than automatically submitting again.

## Tạo nhu cầu

The primary surface summarizes readiness and currentness in one sentence and
shows the next business action. Source-specific blocking guidance identifies
which saved input needs attention. Detailed source state and generation history
remain available on demand.

When source data changes after a Confirmed Need batch has already been released
for purchase handoff, the Application explains that the batch cannot be updated
directly and does not expose an executable correction action. This preserves
the released operational document and does not invent a future correction
workflow.

## Xác nhận nhu cầu

The normal lifecycle remains exactly `Lưu` then `Chuyển sang lên đơn`. The
release confirmation explicitly states that the action does not allocate a
supplier and does not create either a Purchase Handoff or Purchase Order.

## Responsive and accessibility disposition

The Planning sequence was reviewed at approximately 360 px, 768 px, and
1280 px. Mobile tabs use contained horizontal scrolling rather than creating
page-wide overflow. Primary controls retain mobile touch targets, tables keep
local horizontal scrolling where needed, and keyboard focus remains visible.

## Contract and environment boundary

This change is Application-only. It adds no migration, relation, column,
trigger, job, scheduler, API, Preview API, lifecycle state, capability, backend
orchestration, dependency, or generated type. Existing Planning Preview, Save,
Need Generation, and Confirmed Need contracts remain authoritative.

Atlas Staging, live OPS, Retool, Edge Functions, hosted data, Procurement, and
Warehouse were not mutated or started.

## Verification

- Focused changed-component tests: 3 files / 29 tests passed.
- Broader Planning-input and Atlas shell regression: 18 files / 127 tests
  passed.
- Typecheck passed.
- Repository formatting check passed.
- Production build passed with the existing non-blocking large-chunk advisory.
- `git diff --check` passed.
- Hosted CI: `BLOCKED BEFORE RUNNER — GitHub billing/spending limit`.
