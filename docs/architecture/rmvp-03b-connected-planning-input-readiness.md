# RMVP-03B — Connected Planning Input Readiness

- **Status:** Accepted
- **Product Owner approval:** 31/07/2026
- **Domain:** Planning
- **Business owner:** Tổ Kế hoạch
- **Contract version:** `RMVP-03B.v1`
- **Canonical accepted decisions:** [Decision RMVP-03B](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md)
- **Canonical accepted API registry:** [RMVP-03B Planning Input Readiness API](../api/rmvp-03b-planning-input-readiness.md)
- **Parent contract:** [PD-01.4 Planning Domain Input Readiness](planning-domain-input-readiness-contract.md)

## 1. Outcome

RMVP-03B defines the accepted connected command, event, read-model, API, and Vietnamese
operator-UX contract for the Planning Input Readiness object that already
exists in private PostgreSQL persistence.

The connected surface answers one decision-first question:

> **Có thể yêu cầu tạo nhu cầu cho giai đoạn này không?**

The backend resolves one exact inclusive period, exposes exact candidate
Weekly Menu, Attendance, and Pantry approval evidence, creates an immutable
readiness evaluation, controls the closed lifecycle, and returns authoritative
readback. React coordinates selection and presentation only.

Product Owner approval on 31/07/2026 establishes Product and Architecture
authority only. It creates no executable authority. A separate bounded
implementation task is required before any migration, function, capability,
grant, adapter, React component, or test may be changed.

## 2. OPS_SYSTEM_MAP placement

| Layer               | RMVP-03B placement                                                             |
| ------------------- | ------------------------------------------------------------------------------ |
| Mission             | Operate a reliable, explainable school-catering ERP                            |
| Business capability | Decide whether controlled Planning inputs can be handed to Need Generation     |
| Business domain     | Planning                                                                       |
| Business object     | Planning Input Set, immutable readiness evaluation, immutable evaluation issue |
| Business contract   | PD-01.4 plus PANTRY-RDY-01 and PANTRY-RDY-02                                   |
| Command/event       | Evaluate readiness, request Need Generation handoff, invalidate readiness      |
| Read model          | One decision-first Planning Input Readiness workbench                          |
| Application         | Existing Vietnamese `Nguồn kế hoạch` workbench                                 |
| Technology          | Future bounded `atlas_api` functions over existing private PostgreSQL facts    |

Readiness remains inside Requirement Planning. It is not a fourth daily
operating stage and not a parallel application.

## 3. Phase 0 authority inventory

| Inventory subject                            | Authoritative finding                                                                                                                                                                                                                                       |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Planning Input Set root                      | `atlas_planning.planning_input_sets` owns one immutable exact inclusive period, current status, and exact current-evaluation pointer. It has no aggregate version and no School/customer split.                                                             |
| Evaluation and issue persistence             | `planning_input_evaluations` owns positive contiguous root-local versions, immutable `READY`/`NOT_READY` results, exact typed source bindings, counts, actor, and time. `planning_input_evaluation_issues` owns the complete immutable blocker/warning set. |
| Existing RMVP-03A readiness shape            | `get_planning_inputs_workbench` exposes a read-only two-source approval comparison for one Monday week. It is not the persisted Planning Input Set read and cannot authorize RMVP-03B actions.                                                              |
| Existing Planning Inputs and Pantry APIs     | RMVP-03A exposes one source workbench, two previews, and nine source commands. PANTRY-02 exposes a separate Pantry workbench, preview, and four source commands. Neither reads or writes Planning Input Set persistence.                                    |
| Available Planning capabilities              | `planning.inputs.read`, `planning.weekly_menu.write`, `planning.attendance.write`, `planning.pantry.write`, and `planning.inputs.approve` exist. No readiness-write capability exists.                                                                      |
| Runtime roles                                | `atlas_read_runtime` owns connected shaped reads. `atlas_planning_command_runtime` owns connected Planning source commands. No new runtime is authorized by the accepted boundary.                                                                          |
| Receipt, event, audit, and actor conventions | Existing commands resolve the authenticated subject to an active Actor, authorize capability plus `GLOBAL` scope, create one durable command receipt, emit one domain event and one audit event in the same transaction, and return authoritative readback. |
| React boundary                               | `PlanningInputsWorkbench` owns the shared week selector and the `Thực đơn tuần`, `Sĩ số`, and `Pantry` tabs. Pantry is a bounded submodule inside the same workbench.                                                                                       |
| Historical null-Pantry behavior              | Pre-PANTRY evaluations may retain a null Pantry family as immutable history. They cannot authorize a new Need Generation request.                                                                                                                           |
| Need Generation boundary                     | Existing private Need Generation persistence admits a run only after the root is `NEED_GENERATION_REQUESTED`; command/API behavior and the separate Pantry contribution amendment remain outside RMVP-03B.                                                  |

The old in-memory `src/modules/planning-input-readiness` prototype is
non-authoritative lower-order evidence. It models two generic sources, period
equality, and a mutable root version, and is not imported by the connected
Planning Inputs workbench. A future implementation must follow the approved
documents and merged persistence instead of reusing those prototype semantics.

## 4. Ambiguities closed by the accepted decisions

The authority review found no contradiction among approved documents,
migrations, and tests. It did expose choices that had deliberately been left
open:

- how an operator selects an exact period when the existing source UI is
  week-oriented;
- whether source evidence is silently resolved or explicitly carried from a
  backend-shaped read;
- whether the existing RMVP-03A read should be extended;
- which one capability and existing runtimes should own the commands;
- exact concurrency, invalidation-reason, event, and UX behavior; and
- how request/invalidation history is shown without adding fields or envelopes
  to the Planning Input Set.

The complete accepted answers exist only in the
[R3B-P01 through R3B-P12 registry](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md).

The repository also contains `docs/api/api-contracts.md` and the implemented
PA-06A application-facing registry. Neither is in this task's nine-file
boundary. Because RMVP-03B acceptance changes no implemented function surface,
those indexes are intentionally unchanged. A later separately authorized
implementation task must reconcile implemented-registry indexing within its
own authorized file scope.

## 5. Connected architecture

### 5.1 One dedicated authoritative read

The accepted architecture adds one dedicated shaped readiness workbench read rather than
extending `get_planning_inputs_workbench`.

This separation is necessary because:

- the persisted root grain is any exact inclusive period, not one Monday week;
- source-candidate selection spans the existing Menu, Attendance, and Pantry
  API boundaries;
- immutable evaluation, request, and invalidation histories do not belong in
  either source workbench; and
- the existing two-source `readiness` comparison must not compete with the
  persisted three-source authority.

After future connection, the dedicated RMVP-03B read is the sole authoritative
readiness read. The RMVP-03A comparison may remain source-tab context, but
React must not present it as permission to request Need Generation.

### 5.2 Explicit candidate review

The backend-shaped read returns every current approved source candidate that
overlaps the selected period, its exact typed root/version/snapshot identity,
coverage classification, approval evidence, and current/stale state.

For each source family, selection is deterministic:

| Current candidate evidence                                       | `selection_state` | `selected`                                   |
| ---------------------------------------------------------------- | ----------------- | -------------------------------------------- |
| Zero current approved overlapping candidates                     | `MISSING`         | Null                                         |
| Exactly one candidate                                            | `SELECTED`        | That exact candidate, selected automatically |
| Multiple candidates and no valid supplied selection              | `AMBIGUOUS`       | Null                                         |
| Multiple candidates and one exact current supplied candidate     | `SELECTED`        | That supplied candidate                      |
| A well-formed supplied prior-read candidate is no longer current | `STALE`           | The stale prior selection for display only   |

`AMBIGUOUS` and `STALE` disable evaluation. Exactly one candidate requires no
operator click. When multiple candidates exist, operator selection causes
another shaped read with that exact candidate triple; only a resulting
`SELECTED` state can return an enabled Evaluate action.

A missing family remains null and is evaluated as a backend-authored blocker.
A changed, stale, ownership-mismatched, or no-longer-read-returned candidate
causes fail-closed refresh behavior. There is no hidden “latest row wins”
rule.

### 5.3 Transaction boundaries

Each business action maps to one future transactional command:

1. evaluate and atomically create the first or next immutable evaluation plus
   its complete issue set;
2. request the handoff while retaining the exact current evaluation; or
3. invalidate the current readiness result while retaining its evidence.

Each accepted command uses the existing receipt, event, and audit relations.
Request and invalidation history are projected from those shared relations;
they are not duplicated in the Planning Input Set.

The request command derives all three source triples from the exact expected
current immutable evaluation. React does not repeat them. The backend loads
that evaluation and revalidates its Menu, Attendance, and Pantry bindings
under lock before recording the handoff.

`NEED_GENERATION_REQUEST_WITHDRAWN` is permitted only while no
`atlas_planning.need_generation_runs` row exists with the exact
`planning_input_set_id` and exact current `planning_input_evaluation_id`. Any
such row consumes the handoff regardless of run status. A consumed handoff fails as
`NEED_GENERATION_HANDOFF_ALREADY_CONSUMED`; readiness invalidation never
updates, invalidates, supersedes, or deletes the run.

## 6. Decision-first read model

The workbench must return:

- exact `period_start` and `period_end`;
- exact resolved root identity and status, or explicit absence;
- current evaluation identity, version, result, counts, actor, and time;
- exact selected and alternative source candidates;
- typed Menu, Attendance, and Pantry root/version/snapshot identities;
- source periods, coverage, approval, current/stale state, and approval actor/time;
- Pantry positive-line evidence or explicit zero-additions evidence;
- blockers before warnings;
- backend-derived `allowed_actions` and disabled reasons;
- one bounded combined history of immutable evaluations and request/invalidation
  events, with complete source bindings and issues where applicable;
- `history_next_cursor` and `history_has_more`; and
- explicit historical null-Pantry labeling.

The read is a shaped projection, not an authorization cache. Every command
resolves actor/capability/scope again, locks authoritative rows, and revalidates
all expectations.

The optional history selector is:

```json
{
  "history_limit": 25,
  "history_cursor": "opaque backend cursor or null"
}
```

`history_limit` defaults to `25`, has minimum `1` and maximum `50`, and fails
validation outside that range. History uses one combined `history_items`
timeline ordered by backend-owned `(occurred_at DESC, history_kind_rank ASC,
history_item_id DESC)`, where the fixed kind rank is Evaluation, Need
Generation request, then invalidation. The first page establishes an immutable
high-water tuple; an opaque cursor binds the exact period, that high-water
tuple, and the last returned tuple. The same read returns later pages without
duplication or silent omission. React cannot author or decode the cursor.

Current root, current evaluation, current source evidence, issues, decision,
and `allowed_actions` are always returned independently of historical
pagination.

## 7. Vietnamese operator UX

### 7.1 Workbench integration

Future React work adds one fourth tab, `Sẵn sàng đầu vào`, inside the existing
`Nguồn kế hoạch` workbench. It does not add navigation, a module boundary, or
a parallel page.

The current Monday week remains a convenience. The readiness tab shows:

- `Từ ngày` and `Đến ngày` inclusive date inputs;
- a `Dùng cả tuần đang chọn` shortcut;
- the exact resulting period at all times; and
- a warning before discarding locally selected candidates.

### 7.2 Evidence and decision layout

The top of the tab asks:

> **Có thể yêu cầu tạo nhu cầu cho giai đoạn này không?**

Below it are three evidence cards:

1. `Thực đơn tuần`
2. `Sĩ số`
3. `Pantry`

Each card shows approval state, source period, exact approved version,
snapshot reference, coverage, current/stale state, and approval actor/time.
Exactly one candidate is selected automatically. Candidate choice is shown
only when multiple backend-shaped candidates exist; `AMBIGUOUS` and `STALE`
keep Evaluate disabled until a refreshed read returns `SELECTED`.

Pantry uses one of these explicit labels:

- `Có bổ sung Pantry — N dòng`; or
- `Đã xác nhận không có bổ sung Pantry — 0 dòng`.

Missing Pantry never uses the zero-additions label.

### 7.3 Status, issues, and actions

Operator status labels are:

- no root: `Chưa đánh giá`;
- `NOT_READY`: `Chưa sẵn sàng`;
- `READY`: `Sẵn sàng`;
- `NEED_GENERATION_REQUESTED`: `Đã yêu cầu tạo nhu cầu`; and
- `INVALIDATED`: `Đã vô hiệu hóa`.

Blocking issues appear first under `Lỗi chặn`. Warnings appear separately
under `Cảnh báo không chặn`; the UI provides no acknowledgement, waiver, or
override control.

The action labels are:

- `Đánh giá mức sẵn sàng` or `Đánh giá lại mức sẵn sàng`;
- `Yêu cầu tạo nhu cầu`; and
- `Vô hiệu hóa kết quả sẵn sàng`.

Buttons are disabled only from backend `allowed_actions`. React may require the
operator to choose a backend-returned candidate or enter a required reason
note, but it must not independently infer lifecycle eligibility.

`Yêu cầu tạo nhu cầu` submits the set ID, exact period, and command-envelope
expectations only. It neither asks the operator for source bindings nor repeats
them from browser state; the backend derives them from the expected immutable
evaluation.

### 7.4 Refresh, stale, and uncertainty behavior

- Period or candidate changes cause a new authoritative read.
- A successful command replaces visible state with its authoritative readback.
- A stale root, evaluation, or source response clears action eligibility and
  requires refresh.
- A retryable concurrency response permits retry of the exact unchanged
  request.
- Transport uncertainty is shown as unknown outcome, never success. React
  retains the same command and idempotency identities for an exact replay or
  refreshes the authoritative read before any later action.

The history drawer is `Lịch sử đánh giá`. It loads up to the backend-returned
limit and uses the same readiness read plus opaque
`history_next_cursor` to load more when `history_has_more` is true. Combined
history items show historical evaluations and request/invalidation events in
backend order. Historical evaluations show their exact result, source
evidence, issues, evaluator, and time. A null-Pantry historical evaluation
displays:

> `Đánh giá lịch sử trước khi yêu cầu Pantry — không có liên kết Pantry; không
dùng để yêu cầu tạo nhu cầu.`

## 8. Safe operator messages

Future implementation uses bounded Vietnamese messages:

| Outcome                            | Safe message                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Evaluation is `READY`              | `Đã đánh giá: giai đoạn này sẵn sàng để yêu cầu tạo nhu cầu.`                                             |
| Evaluation is `NOT_READY`          | `Đã đánh giá: cần xử lý các lỗi chặn trước khi yêu cầu tạo nhu cầu.`                                      |
| Request recorded                   | `Đã ghi nhận yêu cầu chuyển sang bước tạo nhu cầu; chưa tạo lần chạy hay số lượng nhu cầu.`               |
| Readiness invalidated              | `Đã vô hiệu hóa kết quả sẵn sàng hiện tại.`                                                               |
| Stale root/evaluation/source       | `Dữ liệu đã thay đổi. Hãy tải lại và kiểm tra bằng chứng nguồn trước khi thử lại.`                        |
| Invalid lifecycle                  | `Trạng thái hiện tại không cho phép thao tác này. Hãy tải lại.`                                           |
| Capability denied                  | `Bạn không có quyền thực hiện thao tác này.`                                                              |
| Required invalidation note missing | `Hãy nhập lý do cụ thể trước khi vô hiệu hóa.`                                                            |
| Need Generation handoff consumed   | `Yêu cầu tạo nhu cầu đã được tiếp nhận thành lần chạy. Không thể rút lại bằng thao tác này.`              |
| Retryable concurrency              | `Dữ liệu đang được cập nhật. Có thể thử lại đúng yêu cầu.`                                                |
| Transport uncertainty              | `Chưa thể xác nhận thao tác đã hoàn tất. Không tiếp tục bước sau; hãy thử lại đúng yêu cầu hoặc tải lại.` |
| Session expired                    | `Phiên làm việc đã hết. Vui lòng đăng nhập lại.`                                                          |

Raw SQL, relation names, policies, roles, JWT contents, stack traces, and
credentials are never operator messages.

## 9. Security and future implementation ceiling

The accepted future implementation ceiling is:

- at most one migration;
- exactly one shaped read plus at most three commands, for at most four
  `atlas_api` functions;
- at most one new capability;
- zero relations;
- zero views;
- zero roles or runtime roles;
- zero scope kinds;
- zero automatic source triggers;
- zero new readiness lifecycle states;
- reuse of `atlas_read_runtime`, `atlas_planning_command_runtime`, shared
  receipts, domain events, audit events, Actor resolution, and `GLOBAL` scope;
- authenticated execution only, with private relations remaining unavailable
  to browser roles; and
- integration into the existing Planning Inputs module.

This ceiling is binding Product and Architecture authority, not implementation
authorization.

## 10. Historical and downstream boundary

RMVP-03B preserves:

- immutable historical null-Pantry evaluations;
- direct re-evaluation from `NOT_READY` and `INVALIDATED`;
- mandatory invalidation before re-evaluating `READY` or
  `NEED_GENERATION_REQUESTED`;
- no automatic source trigger;
- request as a handoff marker only; and
- no creation or mutation of a Need Generation run, contribution, Recipe/BOM
  calculation, Theoretical Need, Confirmed Need, Purchase Handoff,
  Procurement, Warehouse, Dispatch, Wholesale, OPS v1/v2, Retool, hosted
  Supabase, or production data.

The separate Pantry Need Generation amendment remains not started.

If a Need Generation run already exists for the exact set and evaluation,
readiness invalidation neither changes that run nor treats its later status as
unconsumed.

## 11. Migration and rollback effect

This documentation task has no schema, data, grant, application, deployment,
or operational rollback effect. It is reverted through normal Git history.

A later approved implementation must state its own additive migration and
forward-only rollback effects while preserving immutable readiness, receipt,
event, and audit history.
