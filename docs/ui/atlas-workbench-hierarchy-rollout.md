# Atlas workbench hierarchy rollout

**Owner authorization:** 29 October 2026 — “approve, please proceed for every workbench and page”.

**Reference:** merged [#446](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/446), `777d3237`.

## Scope

Apply the accepted Allocation hierarchy to the thirteen production owners in
`AtlasWorkbenchRegistry.tsx`, their reachable detail/review/dialog surfaces, the
shared shell and sign-in/session states. These are different operator jobs, not
thirteen copies of one page template.

| Family                    | Owners                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------- |
| Planning                  | Thực đơn, Sĩ số, Hàng đặt riêng, Xác nhận nhu cầu                                  |
| Purchasing and fulfilment | Phân bổ NCC, Đơn mua, Phiếu xuất kho, Đối chiếu PO / Phiếu xuất kho                |
| Master data               | Trường học, Nguyên liệu, Nhà cung ứng                                              |
| Recipe governance         | Công thức, Lệnh điều chỉnh                                                         |
| Shared pages              | Launcher/open-owner navigation, sign-in/loading/expired/configuration-error states |

Warehouse Receiving remains paused and outside this rollout. PXK is the existing
Dispatch document owner; improving its presentation does not reopen Warehouse.
Legacy/prototype/certification-only pages and operational export formats are not
new production owners and are not redesigned.

## Spatial and typographic thesis

1. Keep the operator's current job, date/period and scope identifiable. Opening a
   detail must not automatically scroll that context out of sight.
2. Use one principal white workplane. A filter band, table heading, selected
   identity and editable field are distinct levels; extra enclosing frames do
   not supply hierarchy. Align peer labels and controls on common axes.
3. Let the business decision lead: quantities and Units, source assignments,
   document identity, recipe lines or the selected master record. Separate
   supporting metadata, histories and utilities from the primary task.
4. Keep desktop tables dense and comparable. On phones, use intentional labeled
   records or contained table scrolling according to the job; do not leave a
   detached status cell, an unlabeled quantity or inherited desktop dividers.
5. Keep the next business action reachable and proportionate. Use existing
   primary/secondary/utility recipes, with 40px desktop and 44px narrow targets.
   Compact long action groups through wrapping or existing disclosure, not
   smaller type or clipped labels.
6. Preserve the Wada adaptation, self-hosted Inter and current type roles. Titles,
   labels, helper text, quantities and Units retain their existing semantic
   styles; do not invent a second visual system.
7. Disclose supporting material only when its role permits it. Existing saved
   notes and operational blockers must remain discoverable. Moving or hiding a
   command must preserve its scope explanation, permission and guard semantics.
8. Keep DOM/focus order usable. Dynamic additions, removals and disclosures need
   an explicit focus destination; Close and guarded exits retain the original
   trigger and draft.

## Implementation boundaries

Allowed changes are view composition, responsive layout, existing semantic
styles, accessible field/group labeling and local presentation/focus state.
Directly affected tests, review fixtures where needed for visual coverage and
documentation are included. Reuse the existing Atlas provider, Chakra system,
workbar, context and table viewport. Add a shared layout primitive only when at
least two real consumers need the same contract.

Do not change controllers, bridge/API signatures, domain models, authoritative
calculations, eligibility, lifecycle, command payloads, export arrays, source
facts, permissions/RLS, database objects, dependencies or persistent owner
lifetimes. Do not reconcile inconsistent synthetic fixture facts through styling.
No hosted Save/release, production data change, supplier communication, manual
deployment or Warehouse work is authorized by this UI rollout.

## Acceptance

- All thirteen owners and shared pages have explicit reviewed coverage. A
  surface already meeting the reference can remain unchanged, with evidence.
- Peer content has consistent indentation and readable grouping; primary facts
  and actions are identifiable without relying on color.
- Normal/list and representative selected/edit/review states remain usable at
  1920×1080, 1440×900, 1366×768, 1024×900, 650×900, 390×844 and 360×800.
- No document-level horizontal overflow, clipped primary command or unintended
  loss of scope; intentional table scrolling remains local and discoverable.
- Focus, labels, 44px phone targets, dirty/exit/UNKNOWN locks, exact Units and
  loaded-scope explanations are preserved.
- Focused module and persistent-owner regressions pass. GitHub Actions owns full
  routine validation; a final PR requires the latest-head CI result.
- Evidence includes phone-accessible contact sheets, coverage and known limits.

One branch contains family-sized commits for this single visual capability.
The endpoint is a complete reviewable PR; no future merge or manual deployment
is inferred from approval of this rollout. Rollback reverts the frontend/test/docs
commits and has no migration or business-data effect.
