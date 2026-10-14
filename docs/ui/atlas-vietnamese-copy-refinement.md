# Atlas Vietnamese copy refinement

Date: 13 October 2026

## Scope and acceptance

Refine operator-facing Vietnamese in the current vNext application: workspace
notices, sign-in guidance, School and master-data save recovery, Recipe import and
adjustment guidance, Hàng đặt riêng empty states and confirmation, and reconciliation
empty states. Existing accessible names, tests and review stories follow the revised
labels. Keep approved business job names and concepts.

Owner-requested follow-up: replace the literal workbench translation with contextual
UI wording. The launcher is “Chức năng”; its search is “Tìm chức năng”; the open-tab
list is “Màn hình đang mở”. Notices name the job directly, for example “Đơn mua”,
instead of inventing “bàn Đơn mua”. Internal Workbench identifiers are unchanged.
The D-048 decision, v2 design contract and UI inventory follow this explicit
owner-requested label amendment.

This is a presentation-only change. It changes no API, status, permission,
calculation, data or backend command. In particular, an uncertain save must still
ask the operator to reload and check its result rather than claim success; a selected
no-orders confirmation must not imply it has been saved. Weekly confirmation still
covers the whole week, not the filtered day or School.

Acceptance: wording describes the operator's action or the visible problem directly;
affected accessibility queries and focused tests pass; revised copy uses NFC Unicode;
the diff contains only copy, corresponding assertions and affected UI documentation.

## Writing conventions

- Use concise, professional Vietnamese. Avoid engineering descriptions such as
  “ngữ cảnh tại chỗ”, “dữ liệu mục tiêu” and “gửi lệnh lưu” in operator instructions.
- Say what happened, then what to do next. Preserve uncertainty, read-only boundaries,
  unsaved-change protection and date/School scope.
- Use “file Excel” in import instructions. Keep API identifiers and backend error
  codes unchanged.
- Use the approved “Hàng đặt riêng” name consistently in its table, empty states and
  weekly confirmation. Explain whole-week scope explicitly.
- Keep clear existing copy. Do not add a translation framework or rewrite approved
  business contracts to match a stylistic preference.
- Choose words by function rather than translating UI architecture literally:
  “Chức năng” opens a job, “màn hình” refers to the displayed job, and notices use
  that job's name whenever it is already known. Technical documentation can retain
  Workbench as the internal architecture term.

## Representative changes

| Before                                                      | After                                                                    |
| ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| Nhập workbook                                               | Nhập từ Excel                                                            |
| Ngữ cảnh kiểm tra tác động                                  | Kiểm tra tác động                                                        |
| Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức. | Đã gửi yêu cầu lưu nhưng chưa tải được kết quả. Hãy tải lại để kiểm tra. |
| Xác nhận toàn tuần không có bổ sung                         | Xác nhận cả tuần không có hàng đặt riêng                                 |
| Không có phạm vi đối chiếu hiện hành phù hợp.               | Chưa có dữ liệu đối chiếu cho trường và khoảng ngày đã chọn.             |
| Bàn làm việc                                                | Chức năng                                                                |
| Bàn làm việc đang mở                                        | Màn hình đang mở                                                         |

## Security and rollout

No security or persistence boundary changes. Existing backend privileges, RLS,
readback checks and uncertainty locks remain authoritative. No migration is needed;
rollback is reverting this copy-only commit. Hosted deployment and backend-generated
message translation are outside this pass.

## Validation

- Wider focused UI run: 29 suites and 541 tests passed. Three assertions in the
  workspace-notice and Recipe-import suites still matched old copy and were updated.
- Final affected-suite rerun: all 8 suites and 38 tests passed, including workspace
  handoff, operator ownership, Recipe-import recovery and Pantry review rows.
- Vietnamese copy validator: no errors or warnings. NFC Unicode, changed-file
  Prettier and diff whitespace checks passed.
- Owner follow-up: all 11 suites and 112 tests passed for shell navigation,
  convergence, workspace activation and operator ownership. Existing browser-script
  selectors follow the new labels; Python syntax checks passed.
- Local Chromium checks passed at 1280 × 800 and 390 × 844: launcher/title/search,
  accent-insensitive search, Recipe navigation and Excel-import labels. Screenshots
  were inspected for the launcher and import dialog. This used opt-in local fixtures
  and blocked external requests.
- Full frontend certification belongs to GitHub Actions. Hosted behavior was not
  checked in this copy pass.
