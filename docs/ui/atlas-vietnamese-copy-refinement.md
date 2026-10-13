# Atlas Vietnamese copy refinement

Date: 13 October 2026

## Scope and acceptance

Refine operator-facing Vietnamese in the current vNext application: workspace
notices, sign-in guidance, School and master-data save recovery, Recipe import and
adjustment guidance, Hàng đặt riêng empty states and confirmation, and reconciliation
empty states. Existing accessible names, tests and review stories follow the revised
labels. Keep approved workbench names and business concepts.

This is a presentation-only change. It changes no API, status, permission,
calculation, data or backend command. In particular, an uncertain save must still
ask the operator to reload and check its result rather than claim success; a selected
no-orders confirmation must not imply it has been saved. Weekly confirmation still
covers the whole week, not the filtered day or School.

Acceptance: wording describes the operator's action or the visible problem directly;
affected accessibility queries and focused tests pass; revised copy uses NFC Unicode;
the diff contains only copy, corresponding assertions and this record.

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
  contracts to match a stylistic preference.

## Representative changes

| Before                                                      | After                                                                                        |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Nhập workbook                                               | Nhập từ Excel                                                                                |
| Ngữ cảnh kiểm tra tác động                                  | Chọn món và trường để kiểm tra tác động                                                      |
| Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức. | Đã gửi yêu cầu lưu nhưng chưa tải được dữ liệu sau khi lưu. Hãy tải lại để kiểm tra kết quả. |
| Xác nhận toàn tuần không có bổ sung                         | Xác nhận cả tuần không có hàng đặt riêng                                                     |
| Không có phạm vi đối chiếu hiện hành phù hợp.               | Chưa có dữ liệu đối chiếu cho trường và khoảng ngày đã chọn.                                 |

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
- Full frontend certification belongs to GitHub Actions. Browser visual fit and
  hosted behavior were not checked in this copy pass.
