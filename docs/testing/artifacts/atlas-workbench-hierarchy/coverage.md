# Atlas hierarchy rollout coverage — 29 October 2026

**Status: IN_REVIEW.** Implementation, independent family review and local
evidence are delivered on `codex/atlas-workbench-hierarchy-rollout`, with final
source/test checkpoint `7de513d7`. PR publication, public gallery access,
latest-head `Frontend CI / Format, typecheck, test, build` and final Product /
architecture review remain integration gates. No CI PASS, merge or deployment
is claimed here.

Authority: [approved rollout](../../../ui/atlas-workbench-hierarchy-rollout.md),
[current task](../../../autopilot/ACTIVE_TASK.md) and merged Allocation reference
[#446](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/446), `777d3237`.
The [phone gallery](README.md) contains matched before/after sheets, individual
screens and additional support states. The branch URL and QR permit access from
a phone without this Codex chat once publication is verified.

## Thirteen-owner reconciliation

Every owner has a normal/default render at all seven required viewports. Some
owners automatically open a fixture record in that default first frame. The
selected matrix covers the eight owners identified below; it is not a claim
that every dialog or error state was rendered at every width.

| Owner                         | Delivered composition and reviewed support                                                                                         | Rendered evidence and qualification                                                                                                                                                                                                                                                                                                     |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Thực đơn                      | Persistent date/School scope, compact filter band; dense source table and Google Sheet authority retained                          | [Normal](menu-phone.png); intentional local table scrolling; unchanged source/Sync semantics                                                                                                                                                                                                                                            |
| Sĩ số                         | Labeled phone records, paired Student/Teacher controls and one focused narrow Review plane                                         | [Normal](attendance-phone.png), [Review](attendance-review-phone.png); Review at seven widths; explicit zero, blank/invalid semantics and Review focus retained                                                                                                                                                                         |
| Hàng đặt riêng                | Persistent scope and contained compact controls; inherited Review replacement composition                                          | [Normal](pantry-phone.png); independent Review behavior retained in source/direct tests, no standalone rendered Pantry Review                                                                                                                                                                                                           |
| Xác nhận nhu cầu              | Persistent scope, source evidence before persistent next action; exact comparison remains locally scrollable                       | [Normal](need-phone.png); family edit at 1440/390 and support disclosure at 390; exact quantity/Unit, reasons, dirty/UNKNOWN guards retained                                                                                                                                                                                            |
| Phân bổ NCC                   | Accepted #446 hierarchy retained; review-only, no forced layout rewrite                                                            | [Normal](allocation-phone.png), [selected](allocation-selected-phone.png), both seven widths; existing notes, focus, balance/eligibility and exit guards retained                                                                                                                                                                       |
| Đơn mua                       | Broad document beside bounded desktop rail; narrow selection replaces directory; loaded-scope utilities disclosed                  | [Normal](orders-phone.png), [selected](orders-selected-phone.png); family utility-open/default/selected captures; complete eligible loaded-period release/export arrays remain independent of search                                                                                                                                    |
| Phiếu xuất kho                | Labeled narrow records and broad selected document, persistent scope and loaded-period utilities                                   | [Normal](pxk-phone.png), [selected](pxk-selected-phone.png); family utility and Close checks; exact lines/Units, official versus preview/history and export modes retained; existing Dispatch owner                                                                                                                                     |
| Đối chiếu PO / Phiếu xuất kho | Narrow records expose identity, references, states and exact Unit totals; selected comparison replaces directory                   | [Normal](reconciliation-phone.png), [selected](reconciliation-selected-phone.png); family filters/focus and local evidence-table scrolling; read-only Dispatch reconciliation                                                                                                                                                           |
| Trường học                    | Shared context and dense full-draft defaults, paired phone inputs and independent cooking/dispatch forms                           | [Defaults](schools-phone.png), [cooking](schools-cooking-groups-phone.png), [dispatch](schools-dispatch-groups-phone.png); family group views at four widths; dirty-close dialog at desktop; hidden-dirty/full-draft scope retained                                                                                                     |
| Nguyên liệu                   | 320–340px desktop identity rail, narrow selected workplane, aligned Priority and Review; entry-specific owner scroll correction    | [Normal](ingredients-phone.png), [selected](ingredients-selected-phone.png), [Priority](ingredients-priority-phone.png), [long-name Review](ingredients-long-name-review-phone.png); lifecycle confirmation rendered at four family widths; 360 loaded fixture rows retained; archived/create semantics also source/direct-test covered |
| Nhà cung ứng                  | Same bounded rail/selected workplane with full status and contact facts retained                                                   | [Normal](suppliers-phone.png), [selected](suppliers-selected-phone.png); row/Create Close origins and dynamic priority focus tested; default full catalogue retained                                                                                                                                                                    |
| Công thức                     | Compact normal filters; selected workplane replaces chooser below `xl`; selected context/count and recipe lines lead               | [Normal](recipes-phone.png), [selected](recipes-selected-phone.png), [import](recipe-import-360x500.png), [dirty guard](recipe-dirty-guard-360x500.png); family Create/edit/Review checks; Save/use lock, copy/import, versions, dates and Units retained                                                                               |
| Lệnh điều chỉnh               | Compact ledger beside broad desktop workplane; narrow selected/edit replacement; settled Review dialogs and semantic issue anatomy | [Normal](changes-phone.png), [selected](changes-selected-phone.png), [successful Preview](change-review-360x500.png), [final blocked Preview](change-blocked-review-360x500.png); final warning anatomy is source/test-only; precedence, cancel/dirty/UNKNOWN behavior retained                                                         |

Shared shell, launcher/open-owner selector, account disclosure and sign-in were
review-only: the accepted composition already met the hierarchy. See
[launcher](launcher-phone.png) and [sign-in](signin-phone.png). Loading, expired
session and configuration-error variants retain source/direct-test coverage;
they are not separately rendered in this final matrix. Shared shell/session
source is unchanged from reference `777d3237` through `5ab69bf3`.

## Rendered matrix and provenance

The seven CSS viewports are **1920 × 1080, 1440 × 900, 1366 × 768, 1024 × 900,
650 × 900, 390 × 844 and 360 × 800**, at 100% zoom in local Chromium fixtures.

| Matrix                                 | States              | Evidence                                  | Recorded result                                                                     |
| -------------------------------------- | ------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------- |
| Thirteen normal/default owners × seven | 91                  | [JSON](after-matrix.json)                 | No page errors or document overflow; owner reading position checked                 |
| Eight selected owners × seven          | 56                  | [JSON](after-selected-matrix.json)        | No page errors, document overflow or horizontal owner drift                         |
| Sign-in, launcher and account × seven  | 21                  | [JSON](after-shared-matrix.json)          | No page errors, document overflow or window horizontal drift                        |
| Attendance Review × seven              | 7                   | [JSON](after-planning-review-matrix.json) | Review/focus reachable; no page errors, document overflow or horizontal owner drift |
| Total matrix                           | **175 PASS states** | Four original measurement files           | Representative states, not exhaustive state/viewport combinations                   |

Normal, selected and Attendance Review JSON retain each entry's `captureHead`.
The shared matrix did not record a capture head; unchanged shared source from
the merged reference is the source qualification. Other entries retain their
actual earlier batch heads. Later patches outside refreshed Recipe entries were
mechanical type-only/render-equivalent changes; `5ab69bf3` is the final retained
owner-test correction, not an assertion that every screenshot was recaptured at
that head.

Additional family captures cover detail, edit, utilities, confirmations, group
configuration and transitions at 1440/1024/390/360 widths, with actual heights
varying by family (some desktop captures are 1000px high). They do not establish
all states at the seven matrix heights. The public support table in the gallery
records exact dimensions, including 360 × 500 dialog stress cases.

The final blocked phone capture comes from the corrected semantic foreground,
not the earlier blocked fix round. Computed evidence: opaque white content,
opacity 1; header 68px, footer 68px, locally scrolling body 324px; body
scrollHeight 459px; `status.danger` and message both `rgb(122, 32, 32)`; Save
button count 0; document width 360/360; owner horizontal offset 0. The
[desktop blocker](change-blocked-review-desktop.png) corroborates the same final
foreground. The successful Preview has a wrapped 124px footer at 360 × 500.

## Final bounded correction — source `7de513d7`

The final integrated review identified three presentation defects and two minor
follow-ups. This source checkpoint corrects Reconciliation entry focus, selected
PXK/Reconciliation directory containment, and orphan cell separators in Supplier,
Recipe and Change Order record modes. School/Ingredient/Supplier phone headers
are now explicitly labeled **Sắp xếp** utility bands, with all existing axes,
ascending/descending/default cycles and keyboard controls retained. The real
Master workbench hidden/inert first-entry observer also has a focused regression:
no reset while either attribute remains, one reset on activation, and no reset
on later draft edits or reactivation. No controller change was needed.

[Focused geometry and computed-style evidence](final-fix-evidence.json) records
selected directories at 1440/1024 with equal scroll/client widths and identity
and action bounds inside each rail; Reconciliation scrolled entry at 360 with
filters expanded (scrollTop 180 → 0), visible H1, detail and Close, exact Close origin and retained reading position
on ordinary owner reactivation (scrollTop 80 retained); separators absent only in the actual record
modes and still present in desktop comparisons; and all phone sort axes at
360/390 with visible keyboard focus targets of at least 44px. The source-head
confirmation contains 21 focused states, separate from the 175-state matrix.

Only seven affected normal owners (PXK, Reconciliation, School, Ingredient,
Supplier, Recipe and Change Order) and six affected selected owners (the same
list without School) were refreshed across all seven widths: **49 normal and
42 selected captures** at `7de513d7`. Other matrix entries and support images
retain their earlier source qualifications. No old capture is relabeled.

The initial focused red run recorded three expected failures for the old focus
call and missing sort labels. The focused green run recorded **10 passed / two
new navigation-test query failures**: jsdom applies the narrow hidden-directory
fallback. The exact navigation rerun then passed **two tests / 109 skipped**,
asserting retained row/button identity and latest Close origin; real desktop
visibility is proved by Chromium. A separate initial targeted run passed the
actual inactive observer case. These separate runs are not a combined all-green
certification suite. Final source typecheck, changed-file formatting, UI boundary
and whitespace checks passed; Impeccable's mechanical scan returned no findings.
The scoped final Product/source/render confirmation and exact-head GitHub Actions
remain integration gates.

## Review, regression and contract evidence

All five families, counting the already accepted Allocation reference, reached
independent PASS. Earlier BLOCK/CONDITIONAL findings were retained in the local
review record and closed by scoped corrections: 360px compact-control
containment; complete narrow PXK/reconciliation records and PO replacement;
Priority/Review entry position; settled opaque dialogs, selected Recipe count
and exact warning/danger foreground. No new design system or page framework
was added.

Focused family checks cover affected UI semantics, exact quantities/Units,
loaded command scope, labels, focus origins/destinations, retained drafts and
dirty/UNKNOWN locks. Reported family runs include 72 passing School/master tests
and bounded subsequent master checks; Planning, documents and Recipe runs also
retain initial failures/timeouts and exact-case closure. These are separate
development runs, not one combined all-green certification run.

The rollout-wide owner run collected **14 files / 104 tests: 103 passed, one
failed**. The sole failure was a stale global visible-role query for `Tìm lệnh`
after returning to a retained open Create editor. The approved narrow layout
retains that search element and value while hiding its directory. Test-only
commit `5ab69bf3` scopes the retained search within its owner with `hidden: true`,
asserts the same element is not visible, and still proves the visible Create
editor identity/value. The exact complete journey rerun passed **2 tests,
12 skipped** across two files. Original input identities/values, read counts,
no-write assertions, sign-out/Close guards and the 30-second timeout remain.
The 103 already-passing cases were not repeated; no all-green combined rerun is
claimed.

Root's final `pnpm typecheck` passed, exit 0, on clean `5ab69bf3`, including the
existing Chakra type generation and TypeScript checks, with no tracked generated
changes. Changed-file formatting, `pnpm ui:vnext:check` and whitespace checks
passed during source integration. This packaging step separately checks owned
text formatting, gallery links, image dimensions, matrix invariants and QR
geometry. GitHub Actions owns the full routine suite; its result remains pending.

The branch changes only views/direct tests and an opt-in local blocked-Preview
fixture, plus documentation/evidence. Controllers, models, bridge/API contracts,
SQL, calculations, source identities/facts, lifecycle, eligibility, precedence,
permissions/RLS, dependencies, persistent owner lifetime and export formats are
unchanged. This UI rollout does not certify new backend/security behavior.

## Five implementation rulings

| Ruling                                                                            | Reason                                                                                                                                                            | Reversal cost if wrong                                                          |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Explicit canonical E checkout, isolated rollout branch and sequential writers     | Preserve the authorized real repository and avoid concurrent ownership collisions; the workspace script's older D warning is superseded by explicit authorization | Workspace/branch rework; no business-data correction                            |
| One visual capability across thirteen owners; Dispatch included, Receiving paused | Apply the accepted hierarchy to existing jobs without reopening Warehouse or changing module boundaries                                                           | Split the PR or restore bounded view changes                                    |
| Endpoint is a reviewable PR; no automatic merge/deploy                            | Owner review and latest-head CI remain required integration gates                                                                                                 | A later release needs separate execution; no layout rework                      |
| Latest approval supersedes earlier presentation-only narrow editor geometry       | One selected/review workplane must retain identity and recovery actions on phones; broad desktop planes use appropriate bounded rails                             | Reversible geometry change; guards and data stay protected                      |
| Check owner horizontal drift as well as document overflow                         | A shell owner can drift while the document appears contained; intentional wide table scrolling belongs inside the table viewport                                  | Narrow a legitimate assertion exception or correct local layout; no data change |

## Limits and handoff

- Local Chromium synthetic fixtures only. Physical phone/touch, virtual keyboard,
  screen-reader speech and other assistive technology are not certified.
- No hosted business writes, operational exports, live-data certification,
  supplier communication or physical operation was performed for these images.
  Synthetic date/warning inconsistencies remain unaltered.
- Loading/empty/error/permission-disabled/archived/UNKNOWN and warning variants
  have source/direct-test coverage where noted, not exhaustive runtime captures.
- Normal/selected images are original first frames. Contact sheets apply equal
  screenshot scaling; UI pixels and source facts were not retouched. Individual
  images remain available because sheets need zoom on a phone.
- `gallery-qr.png` is 456 × 456px: 49 × 49 QR modules, an unmodified four-module
  quiet zone and 8px/module, using installed ReportLab/Pillow. It encodes the
  exact branch README URL in [gallery-url.txt](gallery-url.txt). No dependency
  was added; public HTTP/scan-on-physical-phone verification remains after push.
- Warehouse Receiving remains **PAUSED**. PXK and reconciliation are existing
  Dispatch. The completed core-data mandate and historical evidence are retained;
  no data task or further implementation starts automatically.
- No migration. Rollback reverts the frontend/test/docs commits with no data
  effect. PR checks and Product/architecture review precede any separately
  authorized integration or release.
