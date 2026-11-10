# Atlas — Bốn follow-up P2 về hierarchy ngày 10/11/2026

**Phạm vi được Owner chấp thuận:** Xác nhận nhu cầu trên điện thoại → Sĩ số → Hàng đặt riêng → Công thức; có đường phân cách để phân biệt các nhóm nội dung. Đây là phần tiếp theo của [review UI/UX trong PR #463](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/463), không thay thế bản sửa Chi tiết lệnh của PR đó.

**Baseline:** `origin/main` tại `c10e4c43950b18170efd54275444cfaec1c9b76e`. Owner cho phép tạo worktree sạch; nhánh `codex/atlas-p2-workbench-hierarchy` nằm trong managed worktree `C:/Users/HOME/.codex/worktrees/atlas-p2-ui-hierarchy/thuonghao-ops-erp`. Checkout E-drive và các công việc reconciliation được giữ nguyên.

## Thay đổi

### 1. Xác nhận nhu cầu trên điện thoại

- Desktop giữ bảng so sánh sáu cột, frozen identity, các comparator và chu kỳ sort hiện có.
- Dưới `md`, mỗi dòng trở thành bản ghi có nhận diện trường/ngày/điểm giao, nguyên liệu, đề xuất, ô lượng xác nhận và Unit, thay đổi, lý do/ghi chú. Toàn bộ vẫn dùng một DOM và một input cho mỗi dòng.
- Đề xuất và lượng xác nhận nằm trong vùng nhìn theo chiều ngang; metadata ngày/điểm giao được ghép cùng hàng để ưu tiên ô lượng. Ba nút sort giữ tên, biểu tượng và trạng thái `aria-sort`.
- Đường 1px phân cách nhận diện/nguyên liệu với nhóm lượng, nhóm lý do và từng bản ghi. Loại bỏ divider dọc kế thừa của các ô bảng trong chế độ bản ghi.
- Các nhãn lặp lại header chỉ phục vụ bố cục điện thoại và có `aria-hidden`; tên truy cập của ô lượng/delta giữ nguyên. Context dùng cho `aria-describedby` vẫn tồn tại, cùng lỗi và lý do đọc-only.
- Không đổi exact decimals, Unit, giá trị đã lưu, delta, comparator, thứ tự mặc định, payload, quyền, historical read-only, dirty/UNKNOWN hoặc các điều kiện Save/Continue.

### 2. Sĩ số

- Tổng số có một hàng riêng; nhóm nhập XLSX và bảng dữ liệu được phân cách bằng border 1px.
- File và hướng dẫn là một nhóm. Trên desktop, Tải mẫu/Dán hàng loạt căn cùng trục với input; trên điện thoại, các nút nằm sau hướng dẫn và wrap theo chiều rộng.
- Giữ nguyên input/file identity, mô tả nhập cả tuần, parser, trường hợp dirty/importing, export callback, paste và Preview/Save.

### 3. Hàng đặt riêng

- Nhóm thêm có heading “Thêm hàng đặt riêng”, nhãn trường cố định có liên kết `for`/`id`, nhãn nguồn hiện có và hành động thêm primary khi hợp lệ.
- Trường tự chọn theo phạm vi một trường vẫn thể hiện đúng trường/điểm giao. Nguồn mặc định, danh mục active, purpose identity và điều kiện thêm không đổi.
- Border 1px phân biệt nhóm thêm với vùng dữ liệu/trạng thái trống; hướng dẫn trống gọn hơn.
- Bảng trống giữ trong DOM; header bảng vốn được ẩn trực quan trên điện thoại. Không dùng yêu cầu “table visible” để thay đổi hành vi rỗng hiện có.
- Giữ chooser keyboard/focus, local draft, danh tính dòng, Unit, mode lịch sử và tất cả backend commands.

### 4. Công thức

- Các tiện ích Sửa thông tin món/Sao chép công thức tạo thành một hàng căn trái dưới nhận diện món, chia đều chiều rộng trên điện thoại; chữ wrap trong nút khi không đủ chỗ, giữ target tối thiểu 44px.
- Border 1px phân cách nhóm tiện ích với ngữ cảnh loại/ngày công thức; divider nhận diện hiện có được giữ lại.
- Không đổi `canCopy`, handlers, type/date context, dữ liệu công thức, Close/focus, dirty/UNKNOWN hoặc Review/Save.

## Phạm vi file và tiêu chí hoàn tất

Năm component trình bày: `ConfirmedNeedTable.tsx`, `PlanningAttendanceStage.tsx`, `PlanningPantryStage.tsx`, `PantrySchoolChooser.tsx`, `DishRecipeWorkbench.tsx`; bổ sung các kiểm tra label/heading vào luồng Pantry hiện có. Bộ đọc DOM read-only trong `staging-planning-browser.mjs` và regression dùng dòng thực được cập nhật để đọc riêng giá trị delta. Không sửa controller, bridge, model, API, system/provider, dependency hoặc database.

Tiêu chí kiểm tra:

1. Ô lượng đầu tiên trên điện thoại nằm trọn trong vùng cuộn nhìn thấy, không cần pan ngang; proposal, saved quantity và Unit vẫn rõ.
2. Sort không mất draft/lý do và không nhân đôi input; giá trị không hợp lệ giữ Save/Continue disabled.
3. Nhóm nhập Sĩ số có trục căn ổn định và đường phân cách; thao tác paste còn truy cập được.
4. Hàng đặt riêng có label liên kết đúng, Add disabled trước khi hợp lệ và chỉ thêm khi chọn trường/nguồn hợp lệ.
5. Tiện ích Công thức có target điện thoại 44px, không clipping, wrap thẳng hàng; Close trả focus đúng.
6. Không có document overflow, page error hoặc request ngoài localhost trong fixture checks; desktop vẫn giữ mật độ bảng.

## Validation và bằng chứng

Xem [ảnh và browser checks](../testing/artifacts/atlas-p2-hierarchy-20261110/README.md). Bằng chứng dùng fixture local, không phải hosted persistence hoặc dữ liệu vận hành thật.

- Typecheck với typegen của custom Chakra và scoped formatting/UI boundary được kiểm tra cục bộ. Các giá trị border/minimum width dùng convention CSS-variable fallback của Atlas.
- Lần focused đầu: 171 tests, 170 PASS và một failure về accessible name của ô delta. Nhãn responsive được loại khỏi accessible name; rerun toàn bộ file Confirmed Need đạt 49/49, giữ nguyên assertion delta chính xác và các guard. Năm file còn lại đạt 122/122 ở lần chạy đầu. Đây là hai checkpoint, không phải một lần chạy combined toàn bộ 171 test.
- Batch browser đầu dừng vì script yêu cầu bảng Pantry rỗng phải hiển thị; sửa đúng oracle thành “giữ trong DOM”. Một batch khác bị ngắt kết nối localhost; không tính batch dở là PASS.
- Ảnh ban đầu cho thấy phần dưới input lượng bị cắt bởi mép vùng cuộn. Đã chỉnh nhịp nhóm và bỏ caption sort dư; kiểm tra cuối yêu cầu toàn bộ input nằm trong vùng nhìn và hit-test được ở tâm bốn cạnh. Probe ở góc bo tròn cho false positive nên đã sửa oracle, không sửa UI để vượt probe đó.
- Một lượt kiểm tra ghi nhận Công thức ở 360px bị tràn dọc 50px khi hai tiện ích thành hai hàng. Giữ một hàng nút co giãn với text wrap giải quyết lỗi mà không giảm cỡ chữ, ẩn nội dung hoặc giảm target.
- Bộ browser cuối **PASS 59/59 checks, 14 captures** ở 1366 × 768, 390 × 844 và 360 × 800; không document overflow, page error hoặc external request. Sort/draft/reason, invalid Save/Continue, Add eligibility và Close focus đều được kiểm tra. Read-only UI reviewer xác nhận PASS ở các ảnh điện thoại cuối.
- [CI đầu ở `e6ffe3e6`](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42742161410) qua format/typecheck nhưng thất bại một test DOM-reader (244 files/3.427 tests PASS): nhãn “Thay đổi” mới bị tính là giá trị delta, làm số dòng khác 0 thành 3 thay vì 1. Thêm marker chỉ vào giá trị và dùng cùng một expression đọc marker ở ba helper read-only, giữ fallback cho UI cũ chưa có marker. Giữ nguyên mọi guard và assertion một dòng thay đổi; thêm kiểm tra ba giá trị marker `+0,01 kg`, `—`, `—`. Closeout + Confirmed Need rerun **137/137 PASS**. Thay đổi marker không làm đổi layout/ảnh đã chụp; không thực thi lại Staging closeout.
- CI `Frontend CI / Format, typecheck, test, build` của PR là gate full routine, không bị thay thế bởi số đo hình học hoặc các lần chạy cục bộ.

## Tác động và giới hạn

Không migration, backend/API/permission/lifecycle/quantity/export change hoặc hosted write. Warehouse Receiving vẫn ngoài phạm vi. Rollback là revert frontend/test/docs; không có thao tác rollback dữ liệu.

Chưa kiểm tra thiết bị thật/bàn phím ảo, screen-reader speech, mọi trạng thái ngoại lệ hoặc mật độ dữ liệu thật. Hai chiều rộng điện thoại và desktop được ghi trong evidence; không suy rộng thành chứng nhận mọi breakpoint hay 200% zoom.
