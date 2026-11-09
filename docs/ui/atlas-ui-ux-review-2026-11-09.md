# Atlas — Review layout, hierarchy và typography ngày 09/11/2026

**Trạng thái:** Review hoàn tất; bản sửa Chi tiết lệnh đã được thực hiện. Trạng thái Frontend CI theo PR; các đề xuất còn lại chưa được triển khai.

**Phương pháp:** Hai đánh giá độc lập: A — `/root/ui_design_review`, đánh giá thiết kế; B — `/root/ui_evidence_review`, kiểm tra DOM, responsive và detector. Root tổng hợp và sửa presentation của `ChangeOrderDetail.tsx`.

**Nguồn:** Checkout được Owner cho phép tại `E:/Project/OPS ERP/thuonghao-ops-erp`, nhánh `codex/atlas-bom-reconciliation-followup`, baseline `e5f5db79a70aee68c15f838959aab8411439e15a`. Owner cho phép tiếp tục dù file kế hoạch đang có thay đổi chưa commit. Các thay đổi của công việc khác được giữ nguyên, ngoài phạm vi commit UI này.

## Kết luận

Lỗi nghiêm trọng nhất tập trung ở Chi tiết lệnh điều chỉnh: dữ liệu quyết định bị trình bày bằng chữ chú thích, nhãn cách giá trị quá xa và phần hiệu lực/lý do thiếu phân nhóm. Bản sửa xử lý lỗi này bằng các role chữ và khoảng cách hiện có của Atlas.

Bốn vấn đề tiếp theo có phạm vi nhỏ: thanh nhập Excel của Sĩ số bị phân mảnh; trạng thái trống Hàng đặt riêng chưa dẫn rõ thao tác tiếp theo; nhóm tiện ích Công thức trên điện thoại chưa có trục căn ổn định; số lượng của Xác nhận nhu cầu nằm ngoài vùng nhìn đầu tiên trên điện thoại. Phân bổ NCC, Nguyên liệu và phần đối chiếu chứng từ là các mẫu tham chiếu tốt cho những đợt sửa tiếp theo.

Không có cơ sở để đổi font toàn ứng dụng, tăng đồng loạt cỡ chữ hoặc áp cùng một bố cục cho cả 13 công việc. Giữ Inter tự host, semantic tokens, dense tables và một workplane chính của Atlas.

## Phạm vi và bằng chứng

- A xem giao diện desktop hiện tại của cả 13 owner; xem thêm các chi tiết Allocation, Đơn mua, Đối chiếu, Nguyên liệu và Công thức. Mẫu điện thoại trực tiếp gồm Lệnh điều chỉnh, Xác nhận nhu cầu, Phân bổ NCC và chi tiết Công thức.
- B đo DOM của cả 13 owner ở **1366 × 768** và **390 × 844**, cùng chi tiết Công thức, Chi tiết lệnh, lịch sử và phần mở rộng công thức hiệu lực.
- Các fixture gồm 33 dòng trường trong Thực đơn/Sĩ số, 34 trường trong cấu hình, 360 nguyên liệu, 37 NCC, 12 món; một số owner chỉ có một chứng từ/dòng nghiệp vụ hoặc trạng thái trống.
- 26 mẫu DOM không có overflow ở cấp document; các bảng rộng vẫn cuộn trong vùng riêng. Đây là kiểm tra hình học của fixture, không phải xác nhận mọi nội dung thực tế đều dễ sử dụng.
- Gallery ngày 29/10 chỉ dùng làm bằng chứng lịch sử, không thay thế render hiện tại.
- Một số ảnh native của B bị chậm khung hình và bị loại. Root hoàn tất batch Playwright sau cùng: **30 ảnh/30 measurement records**, gồm 26 trạng thái của 13 owner ở hai viewport và bốn trạng thái chi tiết Công thức/Lệnh điều chỉnh. Không có page error hoặc request ngoài localhost. Root đã xem cả bốn contact sheet và hai ảnh chi tiết cuối.
- Batch Playwright đầu tiên của Root dừng ở locator `tabpanel` không đủ cụ thể vì Allocation có tabpanel lồng nhau. Locator của script bằng chứng được giới hạn bằng tên owner; batch mới chạy đủ 30 trạng thái. Không sửa source ứng dụng hoặc bỏ assertion để xử lý lỗi script đó.

Xem [bằng chứng được giữ lại](../testing/artifacts/atlas-ui-ux-review-20261109/README.md).

## Đối soát 13 workbench

| Workbench                     | Layout và hierarchy                                                                                                      | Typography                                                            | Kết luận / hành động                                                        |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Thực đơn                      | Ngày, phạm vi và bảng trường đọc theo trình tự rõ; bảng rộng cuộn cục bộ trên điện thoại.                                | Role tiêu đề/bảng phù hợp.                                            | Giữ bố cục; không thu chữ để ép bảng vào điện thoại.                        |
| Sĩ số                         | Tổng số, nhập file, hướng dẫn, tải mẫu và dán hàng loạt tách thành nhiều cụm ngang. Có nhiều vùng cuộn ở mẫu điện thoại. | Cỡ chữ theo hệ thống; sự cạnh tranh chủ yếu do vị trí và khoảng cách. | **P2:** gom nhóm nhập và căn trục điều khiển.                               |
| Hàng đặt riêng                | Mẫu trống có nhiều khoảng trắng; thao tác thêm dòng chưa nổi bật; cần nhãn cố định cho trường/điểm giao.                 | Thiếu phân cấp giữa hướng dẫn trống và thao tác bắt đầu.              | **P2:** làm rõ nhóm thêm hàng và hành động kế tiếp.                         |
| Xác nhận nhu cầu              | Ngữ cảnh và bằng chứng rõ; trên điện thoại lượng nằm ngoài vùng nhìn đầu tiên và mỗi hàng cao khoảng 154px.              | Role lượng/đơn vị đúng nhưng vị trí chưa giúp quét nhanh.             | **P2:** đưa tóm tắt lượng vào vùng nhìn đầu, giữ bảng so sánh cục bộ.       |
| Phân bổ NCC                   | Rail nhận diện gọn, mặt phẳng quyết định rộng, nhóm lượng và thao tác rõ.                                                | Role lượng, đơn vị và nhãn phù hợp.                                   | **Mẫu tham chiếu**, chưa cần sửa.                                           |
| Đơn mua                       | Rail chứng từ và nội dung chi tiết có vai trò rõ. Fixture hiện tại chỉ có một PO.                                        | Nhận diện chứng từ và dữ liệu được phân cấp.                          | Giữ; chưa kết luận về nhiều PO/NCC có tên dài.                              |
| Phiếu xuất kho                | Phạm vi và chứng từ dễ nhận diện; điện thoại dùng bản ghi có nhãn.                                                       | Dữ liệu và thông tin hỗ trợ phân biệt được.                           | Giữ; đây là owner Dispatch hiện có, không mở lại Warehouse Receiving.       |
| Đối chiếu PO / Phiếu xuất kho | Danh tính, trạng thái và bảng chứng cứ dẫn mắt hợp lý; cuộn bảng cục bộ.                                                 | Nhãn, tham chiếu và lượng có cấp độ rõ.                               | **Mẫu tham chiếu** cho màn kiểm tra dữ liệu.                                |
| Trường học                    | Bảng cấu hình dày nhưng có cấu trúc; điện thoại có cuộn owner và bảng.                                                   | Nhãn và dữ liệu nhất quán với hệ thống.                               | Giữ; kiểm tra tương tác cuộn trên thiết bị thật ở đợt responsive tiếp theo. |
| Nguyên liệu                   | Danh mục lớn và rail nhận diện có mật độ hợp lý; chi tiết rộng hơn vùng chọn.                                            | Phân biệt dữ liệu, nhãn và thông tin hỗ trợ.                          | **Mẫu tham chiếu** cho danh mục/chi tiết.                                   |
| Nhà cung ứng                  | Danh mục và tìm kiếm dùng pattern quen thuộc; không phát hiện lỗi ưu tiên cao ở mẫu hiện tại.                            | Nhất quán với danh mục Nguyên liệu.                                   | Giữ; kiểm tra thêm tên và liên hệ dài khi có fixture tương ứng.             |
| Công thức                     | Hai tiện ích sửa thông tin/sao chép dồn lệch phải ở chi tiết điện thoại, làm nhịp đọc bị gãy.                            | Role chữ đúng; vấn đề chính là nhóm và căn trục hành động.            | **P2:** một hàng tiện ích có wrap dưới nhận diện món.                       |
| Lệnh điều chỉnh               | Chi tiết trước sửa có nhãn–giá trị cách xa; hiệu lực/lý do/lịch sử ít phân nhóm.                                         | Giá trị chính dùng `helper` 13px.                                     | **P1 — đã sửa presentation**, chờ CI.                                       |

## Năm ưu tiên cụ thể

### P1 — Chi tiết lệnh điều chỉnh

**Ảnh hưởng:** Người vận hành phải dò ngang và đọc nhiều dòng cùng cấp để biết món/nguyên liệu, phạm vi, định lượng và thời gian áp dụng.

**Nguồn:** [ChangeOrderDetail.tsx](../../src/vnext/atlas/recipes/ChangeOrderDetail.tsx).

**Đã chỉnh:** Giới hạn bề rộng vùng đọc; đặt loại lệnh và trạng thái trong cùng header; đưa phạm vi xuống dòng hỗ trợ; giới hạn cột nhãn; dùng `label` và `body` thay cho `helper`; dùng `quantityInline` cho lượng; gắn nhãn Hiệu lực/Lý do; giới hạn chiều dài dòng của ghi chú và lịch sử; căn gần hai hành động với khoảng cách `md`.

**Số đo:** Mép bắt đầu giá trị cách mép nhãn khoảng **411px trước sửa → 176px sau sửa** ở desktop. Sau sửa, cột nhãn 160px + gap 16px; điện thoại 128px + gap 16px. Giá trị là **14px desktop / 15px điện thoại, weight 500**; nhãn 14px; tiêu đề phần 18px. Không đổi dữ liệu, cách tính, Unit, quyền, điều kiện sửa/hủy hoặc controller.

### P2 — Thanh nhập Sĩ số

**Nguồn:** [PlanningAttendanceStage.tsx](../../src/vnext/atlas/planning/PlanningAttendanceStage.tsx), nhóm nhập XLSX/tải mẫu/dán hàng loạt.

**Đề xuất:** Một hàng desktop gồm tổng số ở trái và nhóm nhập ở phải; điều khiển chung trục, gap 16px. Hướng dẫn nằm ngay dưới trường chọn file. Trên điện thoại: trường → hướng dẫn → các nút wrap, giữ target 44px. Giữ nguyên parser, Preview, Save và phạm vi nhập.

### P2 — Trạng thái trống Hàng đặt riêng

**Nguồn:** [PlanningPantryStage.tsx](../../src/vnext/atlas/planning/PlanningPantryStage.tsx), trường mới và nút `+ Thêm dòng`.

**Đề xuất:** Nhóm “Thêm hàng đặt riêng” có nhãn cố định Trường/điểm giao và Nguồn; một hành động thêm rõ ràng khi đầu vào hợp lệ; hướng dẫn trống ngắn bên dưới. Có thể ẩn header bảng khi chưa có dòng, sau khi kiểm tra pattern và accessibility hiện có. Giữ các điều kiện hợp lệ và lệnh backend hiện hành.

### P2 — Tiện ích Công thức trên điện thoại

**Nguồn:** [DishRecipeWorkbench.tsx](../../src/vnext/atlas/recipes/DishRecipeWorkbench.tsx), các nút “Sửa thông tin món” và “Sao chép công thức”.

**Đề xuất:** Một nhóm tiện ích wrap ngay dưới nhận diện món, gap 10px, target 44px; chia phần rộng có sẵn ở 390px và cho phép xuống hàng gọn ở 360px. Ngữ cảnh loại/ngày công thức theo sau; hành động xem thay đổi vẫn có ưu tiên riêng. Không sửa logic sao chép hoặc phát hành.

### P2 — Lượng xác nhận nằm ngoài vùng nhìn đầu tiên trên điện thoại

**Nguồn:** [ConfirmedNeedTable.tsx](../../src/vnext/atlas/planning-confirmed/ConfirmedNeedTable.tsx); ảnh/measurement cuối của Root bổ sung cho hai đánh giá độc lập.

**Quan sát ở 390px:** Cột đề xuất bắt đầu tại x = 411px, cột lượng xác nhận tại x = 551px; hàng mẫu cao khoảng 154px. Vùng nhìn đầu tiên chủ yếu có danh tính trường và nguyên liệu; phải cuộn ngang để đọc lượng là nội dung cần quyết định. Bảng vẫn cuộn được và không có bằng chứng mất nội dung.

**Đề xuất:** Đưa tóm tắt đề xuất/đã lưu/giá trị chỉnh và Unit vào phần nhìn thấy của bản ghi điện thoại; giữ bảng đối chiếu đầy đủ hoặc disclosure hiện có cho chi tiết. Giảm lặp danh tính trong cùng hàng nếu vẫn giữ đầy đủ context và accessible labels. Không thay đổi lượng, lý do, trạng thái xác nhận hoặc payload.

## Quy chuẩn dùng cho các đợt sửa tiếp theo

1. Nội dung quyết định dùng `body`, `table`, `quantityInline`; `helper` dành cho chú thích, provenance và hướng dẫn.
2. Dùng proximity và trục căn để nhóm thông tin; giữ một workplane, hạn chế thêm khung/card.
3. Giữ thang khoảng cách 6/10/16/24px, tiêu đề công việc 26/24px, body 14/15px, input điện thoại 16px và target 40/44px.
4. Điện thoại chuyển chi tiết thành vùng làm việc chính; chỉ bảng cần so sánh nhiều cột mới giữ cuộn ngang cục bộ.
5. Mỗi sửa đổi phải giữ context ngày/phạm vi, exact Units, focus/Close, draft và các khóa dirty/UNKNOWN hiện có.

## Kiểm tra, giới hạn và tác động

- Typecheck (`pnpm exec tsc -b --pretty false`), UI boundary và diff whitespace đã qua ở bước kiểm tra cục bộ. Không thêm logic nghiệp vụ hay dependency; không thêm test chỉ để kiểm tra tên class/style.
- Vitest cục bộ **BLOCKED trước khi chạy assertion**: worker startup timeout ở cả fork pool và thread pool. Lần đầu còn phát hiện bản baseline trong `.superpowers`; lần cuối đã giới hạn đúng `--dir src --pool=threads --maxWorkers=1 src/vnext/atlas/recipes/RecipeCapability.test.tsx` nhưng worker vẫn timeout sau 60 giây. Không tăng timeout, không bỏ assertion, không sửa cấu hình test để vượt lỗi. Các session bị mất giữa chừng không được tính là kết quả kiểm tra.
- **GitHub Actions `Frontend CI / Format, typecheck, test, build` vẫn là gate bắt buộc.** Review UI không thay thế CI; trạng thái mới nhất được ghi trong PR.
- Detector trước sửa quét 160 markup files, exit 0, JSON `[]`; lần kiểm tra riêng `ChangeOrderDetail.tsx` sau bản sửa cuối cũng exit 0, JSON `[]`. Các kết quả này không thay thế đánh giá trực quan hoặc kiểm thử hành vi.
- Scroll test chi tiết trên điện thoại: owner `scrollTop` 0 → 85, document `scrollY` vẫn 0; không ghi nhận mất nội dung trong mẫu đó.
- Chưa kiểm tra thiết bị thật/bàn phím ảo, screen-reader speech, mọi trạng thái lỗi/khóa, font download hoặc dữ liệu hosted. Chưa chứng minh mật độ chứng từ thật với nhiều tên dài.
- Bản sửa chỉ có presentation frontend; không migration, không ghi dữ liệu nghiệp vụ, không thay đổi API/quyền/lifecycle/export và không mở Warehouse. Rollback bằng cách revert file UI; không có tác động rollback database.
- Bốn đề xuất P2 là backlog review, chưa phải tuyên bố đã sửa. Thứ tự đề nghị: Xác nhận nhu cầu điện thoại → Sĩ số → Hàng đặt riêng → tiện ích Công thức; sau đó kiểm tra responsive có chọn lọc.

Questions skipped: Owner đã xác định phạm vi layout, hierarchy và typography; công việc hiện tại là review toàn bộ và sửa Chi tiết lệnh, không tự mở rộng sang triển khai bốn đề xuất P2.
