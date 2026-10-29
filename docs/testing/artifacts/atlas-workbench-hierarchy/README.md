# Atlas hierarchy review — phone gallery

Actual Chromium renders from the local Atlas review fixture, using the approved
Wada adaptation and Inter. Normal/selected phone captures are 390 × 844 CSS
pixels at 2× scale (780 × 1688 image pixels); open an individual image for
readable text. Supporting captures below state their own dimensions. These images do not establish a
hosted release or physical-device certification.

To open this gallery on another device, scan the [gallery QR code](gallery-qr.png)
from your desktop, or use the [encoded branch URL](gallery-url.txt). This is a
repository gallery and does not require access to this Codex chat. Public HTTP
access must be verified after the branch is pushed; it is pending at this local
packaging checkpoint.

## Contact sheets

- [Planning](planning-sheet.png)
- [Purchasing and Dispatch](operations-sheet.png)
- [Schools and master data](master-data-sheet.png)
- [Recipes and change orders](governance-sheet.png)
- [Selected records](selected-records-sheet.png)

## Individual screens

| Workbench                     | Normal view                       | Selected record                                                     |
| ----------------------------- | --------------------------------- | ------------------------------------------------------------------- |
| Thực đơn                      | [Phone](menu-phone.png)           | Read-only source table                                              |
| Sĩ số                         | [Phone](attendance-phone.png)     | [Review](attendance-review-phone.png)                               |
| Hàng đặt riêng                | [Phone](pantry-phone.png)         | Review contract/source tests retained; no standalone Review capture |
| Xác nhận nhu cầu              | [Phone](need-phone.png)           | Quantity comparison scrolls locally                                 |
| Phân bổ NCC                   | [Phone](allocation-phone.png)     | [Phone](allocation-selected-phone.png)                              |
| Đơn mua                       | [Phone](orders-phone.png)         | [Phone](orders-selected-phone.png)                                  |
| Phiếu xuất kho                | [Phone](pxk-phone.png)            | [Phone](pxk-selected-phone.png)                                     |
| Đối chiếu PO / Phiếu xuất kho | [Phone](reconciliation-phone.png) | [Phone](reconciliation-selected-phone.png)                          |
| Trường học                    | [Phone](schools-phone.png)        | Bulk defaults and separate configuration forms                      |
| Nguyên liệu                   | [Phone](ingredients-phone.png)    | [Phone](ingredients-selected-phone.png)                             |
| Nhà cung ứng                  | [Phone](suppliers-phone.png)      | [Phone](suppliers-selected-phone.png)                               |
| Công thức                     | [Phone](recipes-phone.png)        | [Phone](recipes-selected-phone.png)                                 |
| Lệnh điều chỉnh               | [Phone](changes-phone.png)        | [Phone](changes-selected-phone.png)                                 |
| Sign-in                       | [Phone](signin-phone.png)         | Existing session states retained                                    |
| Chức năng                     | [Phone](launcher-phone.png)       | Existing shell retained                                             |

## Matched comparisons

Before and after use the same fixture, viewport and image scale. No source facts
or screenshots were retouched.

- [Attendance records](attendance-comparison.png)
- [Reconciliation directory](reconciliation-comparison.png)
- [Selected Ingredient](ingredients-comparison.png)
- [Selected Recipe](recipes-comparison.png)
- [Selected Change Order](changes-comparison.png)

## Supporting states

These are actual additional fixture states, separate from the normal/selected
first-frame gallery. The 360 × 500 images are short-viewport dialog stress
checks, not 390 × 844 captures. Scrollable content is intentionally only partly
visible in a first frame.

| Surface                                        | CSS viewport | Image pixels | Evidence                                       |
| ---------------------------------------------- | ------------ | ------------ | ---------------------------------------------- |
| Attendance Review                              | 390 × 844    | 780 × 1688   | [Open](attendance-review-phone.png)            |
| Ingredient Supplier priority                   | 390 × 844    | 390 × 844    | [Open](ingredients-priority-phone.png)         |
| Long-name master-data Review                   | 390 × 844    | 390 × 844    | [Open](ingredients-long-name-review-phone.png) |
| School cooking configuration                   | 390 × 844    | 390 × 844    | [Open](schools-cooking-groups-phone.png)       |
| School dispatch configuration                  | 390 × 844    | 390 × 844    | [Open](schools-dispatch-groups-phone.png)      |
| Recipe import validation                       | 360 × 500    | 360 × 500    | [Open](recipe-import-360x500.png)              |
| Recipe dirty-exit guard                        | 360 × 500    | 360 × 500    | [Open](recipe-dirty-guard-360x500.png)         |
| Change Order successful Preview                | 360 × 500    | 360 × 500    | [Open](change-review-360x500.png)              |
| Change Order blocked Preview, final foreground | 360 × 500    | 360 × 500    | [Open](change-blocked-review-360x500.png)      |
| Change Order blocked Preview, desktop          | 1440 × 900   | 1440 × 900   | [Open](change-blocked-review-desktop.png)      |

The successful Preview shows Save eligibility; Save was not invoked. The blocked
Preview has no Save action. Final warning anatomy is source/direct-test covered;
there is no runtime warning screenshot in this package.

[Coverage, verification and limitations](coverage.md)

Warehouse Receiving remains paused. PXK and reconciliation are existing Dispatch
views. No Save, release, approve, export or hosted business command was invoked
to make these images.
