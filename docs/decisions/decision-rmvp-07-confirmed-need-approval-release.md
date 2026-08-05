# Decision RMVP-07 — Confirmed Need Approval and Release

**Status:** Accepted

**Accepted by Product/Architecture authority:** 05/08/2026

**Accepted baseline:** `c4d7970399f6b1c147700925f03e84efdafb0747`

**Contract:** [RMVP-07 Confirmed Need Approval and Release Contract](../architecture/rmvp-07-confirmed-need-approval-release-contract.md)

**Implementation handoff:** [TASK-RMVP-07A Confirmed Need Approval and Release Contract](../implementation-tasks/TASK-RMVP-07A-confirmed-need-approval-release-contract.md)

## 1. Context

RMVP-05 connects Confirmed Need review, preview and quantity confirmation. RMVP-06 connects complete-batch validation and creates immutable successful validation evidence. The merged Planning lifecycle now stops at `VALIDATED`.

The parent Confirmed Need contract already separates:

```text
VALIDATED
→ APPROVED
→ RELEASED_FOR_PURCHASE_HANDOFF
```

Existing physical structures include Confirmed Need batches, stable lines, immutable line revisions, approval snapshots and approval snapshot lines. They do not yet provide a connected school-catering approval command, an immutable release record bound to one approval snapshot, or application controls for approval and release.

Hosted OPS Supabase remains Atlas-free. Retained Retool and OPS v1 schema evidence use direct SQL/RPC orchestration and do not supply an authoritative Atlas approval/release contract. They are evidence of current operations, not target authority.

## 2. Accepted decisions

| ID | Decision | Accepted direction | Rationale |
| --- | --- | --- | --- |
| R7-P01 | Lifecycle boundary | Keep approval and release as separate complete-batch transitions: `VALIDATED → APPROVED → RELEASED_FOR_PURCHASE_HANDOFF`. | Validation, managerial acceptance and downstream authorization answer different business questions and already exist as separate parent states. |
| R7-P02 | API surface | Add exactly `approve_confirmed_needs(jsonb)` and `release_confirmed_needs_for_purchase_handoff(jsonb)` under `RMVP-07.v1`. | Two explicit commands are smaller and safer than a generic lifecycle mutation or a combined approve-and-release action. |
| R7-P03 | Capabilities | Use separate unbound capabilities `confirmed_need_approval.approve` and `confirmed_need_release.release`. | Preserves authorization separation without imposing a production staffing model in migration code. |
| R7-P04 | Runtime | Reuse `atlas_confirmed_need_review_runtime`; add no database role. | The runtime already owns the bounded Confirmed Need command family. Capability checks and exact grants provide separation without role proliferation. |
| R7-P05 | Actor separation | Do not require approving and releasing Actors to differ in the MVP contract. | OPS may operate with a small team. Separate capabilities and immutable audit are sufficient now; a later governance rule may require four-eyes approval. |
| R7-P06 | Approval precondition | Approval accepts only the exact current successful RMVP-06 validation attempt and batch version, with zero blockers, complete evidence and unchanged canonical fingerprint. | Approval must accept the evaluated fact set, not a mutable latest batch. |
| R7-P07 | Approval unit | Approve one complete batch and create one every-and-only immutable approval snapshot. Partial approval is prohibited. | Procurement handoff needs one coherent Planning commitment and no evidence supports partial-batch reconciliation. |
| R7-P08 | Warning behavior | RMVP-06 warnings remain visible and nonblocking; add no warning-acknowledgement relation. | The parent contract allows warnings after validation, while no approved business rule requires persisted acknowledgement. |
| R7-P09 | Zero quantity | Zero confirmed quantity may remain in the approved/released snapshot as a warning. CMD-03 must separately decide exclusion or blocking. | Planning approval and purchase-handoff materialization are different boundaries; RMVP-07 must not invent Procurement behavior. |
| R7-P10 | Approval persistence | Reuse existing approval snapshot and snapshot-line relations; add the exact successful validation-attempt binding and current approval pointer only. | Existing structures already model immutable approved quantities. A second approval aggregate would duplicate authority. |
| R7-P11 | Release persistence | Add exactly one append-only private relation `confirmed_need_releases` bound to the exact approval snapshot. | Batch fields or audit events alone cannot preserve multiple historical release cycles and provide a stable CMD-03 source. |
| R7-P12 | Release meaning | Release authorizes one exact approval snapshot for later Purchase Handoff; it creates no handoff, supplier assignment, PO or downstream fact. | Keeps Planning and Procurement ownership explicit and preserves CMD-03 as a separate transaction. |
| R7-P13 | Source drift | Approval and release both recompute/compare the canonical validation fingerprint and fail closed if source, policy, decision, Unit, quantity or membership facts changed. | An upstream correction must never be silently accepted or released. |
| R7-P14 | Revision effects | Approval/release may change only controlled line lifecycle metadata (`DRAFT → APPROVED → RELEASED`); quantity/source payload remains immutable. | Preserves exact historical revisions while reflecting current lifecycle authority. |
| R7-P15 | Read model | Extend the existing `get_confirmed_need_review` response additively; add no second read API. | One workbench should show review, validation, approval and release without duplicate reads or screens. |
| R7-P16 | Application | Keep approval and release in the existing Vietnamese `Xác nhận nhu cầu` tab. | Operators need one continuous Planning journey; a generic workflow inbox or separate dashboard is unnecessary. |
| R7-P17 | Vietnamese labels | Use `Phê duyệt lô nhu cầu` and `Phát hành sang bước lên đơn`; state clearly that release does not create supplier assignments or POs. | Matches operational language while preserving the Planning/Purchase Handoff boundary. |
| R7-P18 | Reopen | Reopen remains a separately authorized later slice. Source changes may block approval/release but never auto-reopen. | Reopen has broader correction and downstream consequences and should not be hidden inside approval/release. |
| R7-P19 | Direct wholesale | Preserve direct-wholesale `PA-05D.v1` unchanged; the first connected RMVP-07 implementation is `NEED_GENERATION` only. | Prevents the school-catering lifecycle from accidentally changing the existing atomic wholesale shortcut. |
| R7-P20 | Implementation ceiling | Future RMVP-07B: two APIs, two capabilities, zero roles/states/views/scope kinds, one new private relation, additive read/UI only. | Establishes an exact bounded implementation and prevents workflow/platform expansion. |

## 3. Accepted command and event registry

| Command | Event | Source state | Result state |
| --- | --- | --- | --- |
| `ApproveConfirmedNeeds` | `ConfirmedNeedsApproved` | `VALIDATED` | `APPROVED` |
| `ReleaseConfirmedNeedsForPurchaseHandoff` | `ConfirmedNeedsReleasedForPurchaseHandoff` | `APPROVED` | `RELEASED_FOR_PURCHASE_HANDOFF` |

Rejected commands emit no domain event and create no approval or release evidence.

## 4. Accepted persistence direction

### Approval

Use:

- existing `confirmed_need_approval_snapshots`;
- existing `confirmed_need_snapshot_lines`;
- one exact successful-validation-attempt FK on the snapshot; and
- one current approval-snapshot pointer on the batch.

Do not create another approval aggregate, editable snapshot or browser-authored line list.

### Release

Add one append-only relation:

```text
confirmed_need_releases
```

Each row names:

- the batch;
- exact approval snapshot;
- approved source version;
- resulting released version;
- released Actor/time; and
- command identity.

One approval snapshot has at most one release record. A future reapproval creates another approval snapshot and may create another release record. Historical records are never overwritten.

## 5. Accepted security direction

- separate approval and release capabilities;
- no migration-time production binding;
- existing runtime reuse;
- fixed empty search path;
- execute only for `authenticated`;
- revoke `PUBLIC`, `anon` and `service_role`;
- private forced-RLS relations;
- no browser table access;
- backend-resolved Actor and scope; and
- exact receipt, event and audit evidence.

A production role may later receive both capabilities. RMVP-07 does not require two different people.

## 6. Accepted UI direction

The sixth Planning Inputs tab displays:

```text
VALIDATED
→ Phê duyệt lô nhu cầu
→ Đã phê duyệt; chờ phát hành
→ Phát hành sang bước lên đơn
→ Đã phát hành sang bước lên đơn
```

The server determines action eligibility and disabled reasons. The browser cannot infer eligibility from status alone.

Release confirmation must state that the action does not assign suppliers or create a purchase order.

## 7. Explicit non-decisions and exclusions

This decision does not approve:

- RMVP-07B implementation;
- SQL, migrations, APIs, grants, RLS or generated types;
- a production capability binding;
- a hosted Supabase or Retool change;
- a production Planning policy seed;
- reopen behavior;
- CMD-03 or Purchase Handoff creation;
- zero-line Purchase Handoff policy;
- partial approval or release;
- mandatory distinct approval/release Actors;
- warning acknowledgement infrastructure;
- notification or workflow/task infrastructure;
- supplier allocation or purchase order creation;
- Procurement, Warehouse or Dispatch mutation; or
- automatic downstream correction.

## 8. Consequences

The connected Planning path is now architecturally complete through release authority:

```text
Planning inputs
→ Need Generation
→ Confirmed Need review and confirmation
→ validation
→ approval
→ release authority
```

It is not yet connected through CMD-03. The next implementation slice after this documentation merges is RMVP-07B. CMD-03/Purchase Handoff and reopen remain later separately governed tasks.

Documentation rollback is a normal Git revert. No database rollback applies.