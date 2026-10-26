---
target: Atlas replacement-readiness UI/UX (src/vnext/atlas)
total_score: 29
max_score: 40
na_heuristics:
p0_count: 0
p1_count: 1
target_identity: "file:E:\\Project\\OPS ERP\\thuonghao-ops-erp\\src\\vnext\\atlas"
timestamp: 2026-10-26T13-50-38Z
slug: src-vnext-atlas
---

Method: dual-agent (A: /root/ui_replacement_assessment_a · B: /root/ui_detector_assessment)

# Atlas UI/UX — review về mức độ sẵn sàng thay thế v1

## Kết luận định hướng

Atlas đã là một ứng viên thay thế v1 nghiêm túc. Sức thuyết phục không nằm ở việc trông hiện đại hơn, mà ở ba phẩm chất có giá trị vận hành: con số có thể truy nguyên, công việc giữ được ngữ cảnh qua nhiều màn hình, và trạng thái nghiệp vụ được trình bày ngay trong nơi ra quyết định. Đây là nền móng của một ERP mà operator có thể tin và doanh nghiệp có thể chuyển giao.

Khoảng cách còn lại là **trải nghiệm chấp nhận sản phẩm**. Atlas cần giúp người dùng cảm nhận lợi thế ấy trong 10 phút đầu, rồi giữ niềm tin ở các điểm cam kết cao như phân bổ nhà cung ứng và đơn mua. Không cần một dashboard trình diễn hay thay đổi design system; cần làm rõ “đang ở đâu — có thể làm gì — vì sao — bước tiếp theo là gì”, sử dụng đúng dữ liệu đã được backend xác nhận.

## Design Health Score

|        # | Heuristic                           |      Điểm | Vấn đề chính                                                                                                               |
| -------: | ----------------------------------- | --------: | -------------------------------------------------------------------------------------------------------------------------- |
|        1 | Visibility of System Status         |         2 | Trạng thái nhìn chung rõ, nhưng fixture chính thức có tín hiệu “Đã đủ” và “chưa khớp” cùng lúc ở Phân bổ NCC.              |
|        2 | Match Between System and Real World |         4 | Trường, điểm giao, sĩ số, NCC, PO/PXK, ngày dùng và đơn vị bám rất sát công việc thật.                                     |
|        3 | User Control and Freedom            |         3 | Có đóng tab/pane, Escape, lọc và giữ bản nháp; chưa thấy undo rộng hoặc lối thoát đồng đều ở mọi trạng thái.               |
|        4 | Consistency and Standards           |         4 | Workbar, bảng, detail pane, status badge và CTA chuyển bước dùng cùng một ngôn ngữ tương tác.                              |
|        5 | Error Prevention                    |         3 | Có disabled state, xác nhận, draft/release và bảo vệ phiên; một số disabled action chưa giải thích điều kiện mở.           |
|        6 | Recognition Rather Than Recall      |         3 | Nhãn, trạng thái, summary và lineage hỗ trợ nhận biết; acronym và bảng ngang trên mobile vẫn đòi hỏi nhớ.                  |
|        7 | Flexibility and Efficiency          |         3 | Search, sort, filter, import/export, dán hàng loạt và workspace tabs tốt; accelerator toàn cục/recent work còn mỏng.       |
|        8 | Aesthetic and Minimalist Design     |         3 | Bình tĩnh, đặc thù ERP, ít trang trí thừa; một số layout dùng chiều cao chưa hiệu quả.                                     |
|        9 | Error Recovery                      |         2 | Empty state và một số lỗi có hướng dẫn tốt; các trạng thái mâu thuẫn/chưa rõ điều kiện chưa dẫn người dùng tới cách xử lý. |
|       10 | Help and Documentation              |         2 | Lineage và helper text giàu giá trị, nhưng chưa có bản đồ công việc hoặc điểm vào trợ giúp dễ thấy.                        |
| **Tổng** |                                     | **29/40** | **Good — nền tảng vững; cần một vòng tập trung vào niềm tin và adoption.**                                                 |

## Design Specificity Verdict

**Đặc thù nghiệp vụ: cao. Đặc thù thị giác: trung bình-khá.**

Atlas không phải một admin template được đổi màu. “Trường / điểm giao”, “Sĩ số”, “Hàng đặt riêng”, “Xác nhận nhu cầu”, “Phân bổ NCC”, PO/PXK, lệnh điều chỉnh và phần “Cách hình thành nhu cầu” tạo thành một mô hình tương tác riêng cho vận hành suất ăn trường học. Workspace đa tab, trạng thái chưa lưu và CTA nối giai đoạn cũng tạo cảm giác đây là một công cụ làm việc liên tục, không phải tập hợp trang CRUD.

Bản sắc thị giác đến từ shell xanh đậm, tab workspace, mật độ dữ liệu và cách hiển thị bằng chứng. Cơ hội lớn nhất là đưa ngôn ngữ traceability xuyên suốt toàn hành trình, để mỗi quyết định quan trọng đều trả lời được nguồn, thay đổi, người/tác vụ và bước tiếp theo.

**Deterministic scan:** Impeccable detector chạy đúng một lần trên `src/vnext/atlas`, trả `[]`, exit 0, không có rule/file location hay false positive. Target có 157 file markup candidate. Kết quả này chỉ cho thấy không khớp các pattern tĩnh đã biết; nó không thay thế kiểm tra thủ công. Reviewer B vẫn xác nhận bốn vấn đề qua Staging/DOM/geometry.

## Ấn tượng tổng thể

Atlas tạo cảm giác điềm tĩnh, nghiêm túc và có chủ đích. Nó đặt ngày, trường, trạng thái, nguồn dữ liệu và hành động ngay trên mặt phẳng làm việc. Khi mở “Cách hình thành nhu cầu”, người dùng thấy từ công thức `8,25 kg`, bổ sung `2 kg`, nhu cầu lý thuyết `10,25 kg`, bước làm tròn và số xác nhận. Đây là khoảnh khắc Atlas thuyết phục hơn một màn hình nhập liệu: hệ thống giải thích được chính nó.

Tải nhận thức ở mức vừa phải. Operator quen việc có thể đọc nhanh các bảng và giữ nhiều workbench đang mở; người mới phải tự ghép 13 chức năng, acronym và thứ tự công việc. Hành trình cảm xúc vì vậy có đỉnh rất tốt ở lineage/đối chiếu, nhưng có “thung lũng” ở các trạng thái cam kết khi UI đưa tín hiệu chưa cùng một nghĩa hoặc giấu nội dung chính dưới fold.

## Những gì đang hoạt động tốt

1. **Traceability tạo niềm tin có thật.** “Cách hình thành nhu cầu” và công thức đối chiếu `Δ = SL PO − SL PXK` biến dữ liệu thành bằng chứng có thể kiểm tra. Empty state của Đơn mua còn nói rõ “không có đơn” không đồng nghĩa “không có nhu cầu”, tránh suy diễn nguy hiểm.

2. **Workspace giữ được dòng công việc.** Desktop duy trì nhiều tab, trạng thái chưa lưu/cần xử lý và phím Delete; mobile chuyển thành “Đang mở: …”. CTA “Tiếp tục phân bổ NCC” và “Xem đơn mua” nối các giai đoạn mà không làm mất phạm vi ngày/trường. Lịch sử PO cũ và PO kế nhiệm vẫn được nhận diện riêng, phù hợp nguyên tắc không âm thầm thay đổi chứng từ đã phát hành.

3. **Nền tảng responsive và accessibility tốt.** Menu giữ cột Trường khi cuộn ngang; focus ring rõ; launcher, Escape và focus-return hoạt động; detail pane nhận focus; icon-only control có accessible name. Các target nhìn thấy ở mobile đạt khoảng 44 px. Reviewer B không thấy warning/error console trong phiên đọc giới hạn.

## Priority Issues

### [P1] Một quyết định có thể nhận các tín hiệu trạng thái khác nhau

**Why it matters:** Trong fixture review chính thức, Phân bổ NCC đồng thời hiển thị “Cần xử lý 0 · Đã đủ 1” và “Tổng phân bổ chưa khớp nhu cầu”; mở chi tiết lại cho thấy `100 / 100 kg · Đã đủ`. Trên Staging, một PO đã thay thế còn xuất hiện cùng thông điệp “Đơn nháp cần cập nhật theo phân bổ hiện tại” — đây là concern đã được ghi ở #438, không phải một issue mới cần nhân đôi. Người dùng rời v1 chỉ khi họ không còn phải tự quyết định thông điệp nào đáng tin.

**Fix:** Mỗi dòng/quyết định chỉ có một kết luận chính lấy từ cùng authoritative snapshot. Nếu detail chưa hydrate, hiển thị trạng thái trung tính “Đang kiểm tra…”; nếu có nhiều lớp trạng thái, đặt nhãn phạm vi rõ như “Phân bổ hiện tại”, “Khả năng tạo đơn”, “Lịch sử đơn”. Đồng bộ summary, row badge, banner và detail trước khi nâng mức severity hoặc viết code; kiểm tra lại trên Staging sau đăng nhập.

**Suggested command:** `$impeccable harden`, rồi `$impeccable clarify`

### [P2] Mobile vẫn làm người dùng mất identity ở nơi nhập/duyệt số lượng

**Why it matters:** Attendance thật trên Staging có viewport 353 px nhưng bảng rộng 630 px; khi cuộn tới số Học sinh/Giáo viên/Tổng, tên Trường biến mất. Fixture Xác nhận nhu cầu có viewport 368 px nhưng nội dung rộng 1292 px, khiến số xác nhận, thay đổi và lý do nằm ngoài màn hình đầu. Operator phải nhớ dòng đang thuộc Trường nào, đúng tại nơi sai một hàng có thể làm thay đổi nhu cầu.

**Fix:** Trên mobile, chuyển Attendance và Xác nhận nhu cầu sang responsive row/card: identity Trường + Nguyên liệu luôn ở đầu, số đề xuất/xác nhận/trạng thái cùng một cụm, lý do nằm trong disclosure. Nếu tạm giữ bảng, cần sticky identity có chiều rộng hợp lý và cue “Vuốt ngang…” rõ; không pin nguyên cột 300 px làm mất chỗ nhập.

**Suggested command:** `$impeccable adapt`

### [P2] Layout laptop dùng chiều cao chưa đúng ưu tiên quyết định

**Why it matters:** Ở 1366×768 trên Staging, Menu chỉ cho khoảng bảy dòng trong vùng cuộn cao 288 px nhưng còn khoảng 161 px trống phía dưới. Trong Đơn mua ngày 20/10, detail bắt đầu ở 367 px và nội dung Nguyên liệu bắt đầu khoảng 786 px, dưới viewport; phần hỗ trợ PXK chiếm không gian trước dòng hàng cần duyệt. Cả hai làm công việc chính chậm hơn trên kích thước laptop phổ biến.

**Fix:** Cho bảng Menu chiếm phần chiều cao workbench còn lại theo state thực tế. Với PO, giữ một summary PXK ngắn phía trên và đặt chi tiết đối chiếu vào disclosure, để dòng nguyên liệu đầu tiên xuất hiện ngay trong viewport. Giữ mọi blocker, lịch sử và backend authority; chỉ thay đổi thứ bậc trình bày.

**Suggested command:** `$impeccable layout`, sau đó `$impeccable distill`

### [P2] Atlas chưa kể cho người mới một hành trình chuyển việc đủ ngắn

**Why it matters:** Launcher có 13 chức năng, trong đó tám mục “Công việc hằng ngày”; NCC/PO/PXK xuất hiện ngay và help toàn cục không thấy được. Một số action bị vô hiệu hóa mà không giải thích điều kiện gần nút. Người dùng có thể hoàn thành việc nếu đã biết quy trình, nhưng chưa nhanh chóng hiểu “Atlas giúp mình hơn ở đâu”.

**Fix:** Thêm một lớp hướng dẫn rất nhỏ trong launcher/workbench: “Bắt đầu từ Thực đơn → Sĩ số/Hàng đặt riêng → Xác nhận nhu cầu → Phân bổ NCC → Đơn mua”, giải nghĩa acronym tại lần gặp đầu, và giải thích điều kiện ngay cạnh disabled action. Chỉ dựa trên module hiện tại và context đã tải; không dựng global work queue hoặc trạng thái liên miền khi chưa có read contract.

**Suggested command:** `$impeccable onboard`, sau đó `$impeccable clarify`

### [P2] Accessible name và ngôn ngữ lịch chưa khớp hoàn toàn với UI nhìn thấy

**Why it matters:** Trường có nhãn nhìn thấy “Tìm trường” nhưng accessibility tree chỉ đọc `aria-label="Tìm trong công việc"`; người dùng voice control không thể gọi đúng nhãn họ nhìn thấy. Date picker Việt hóa phần thị giác nhưng một số accessible day/range text vẫn bắt đầu bằng “Choose”/“Starting range from”. Shell cũng chưa có skip link trực tiếp, dù cơ chế Tab-to-panel hiện tại đã giúp giảm vấn đề.

**Fix:** Dùng cùng một tên cho visible label và accessible name ở mọi breakpoint; hoàn tất translation của day/range bằng API Chakra đang dùng; thêm skip target gọn vào main landmark.

**Suggested command:** `$impeccable harden`

## Persona Red Flags

**Lan — operator hằng ngày:** Bộ lọc ngày/trường, summary và workspace tabs giúp vào việc nhanh. Rủi ro lớn nhất là khi “Đã đủ” và “chưa khớp” cùng xuất hiện: Lan sẽ quay về bước kiểm tra ngoài hệ thống. Ở laptop, Menu và PO còn buộc cuộn nhiều hơn mức cần thiết.

**Jordan — người mới chuyển từ v1:** Tên nghiệp vụ đầy đủ và CTA nối bước là điểm tựa tốt, nhưng 13 chức năng, acronym và disabled action không có lý do khiến Jordan phải hỏi người cũ. Một journey rail nhỏ sẽ giảm đào tạo mà không cần tạo dashboard mới.

**Alex — power user:** Search, sort, filter, import/export, dán hàng loạt và tab keyboard behavior đã tạo nền hiệu suất tốt. Trần tiếp theo nằm ở recent work, focus-search/chuyển workbench bằng phím và vài batch action có bằng chứng từ operator; không nên thêm command palette chung chung trước khi có log sử dụng.

**Sam — người dùng phụ thuộc accessibility:** Focus, Escape, named regions và touch target nhìn chung mạnh. Attendance mất tên Trường khi tới cột số, Xác nhận nhu cầu quá rộng, và accessible label khác nhãn nhìn thấy là các điểm gây mất ngữ cảnh thực tế.

## Minor Observations

- No-result copy tốt: “Không tìm thấy chức năng phù hợp. Thử tìm bằng tên khác” và “Không có nguyên liệu phù hợp bộ lọc” cho người dùng đường lui rõ.
- Status badge luôn có chữ, không phụ thuộc màu.
- Tab vát và shell xanh đậm tạo một mức bản sắc vừa đủ; không cần rebrand để chứng minh Atlas.
- Giá trị `60,000001 kg` trong fixture là bằng chứng độ chính xác có chủ đích và được test, không phải lỗi floating-point. Tuy nhiên, với người dùng, sáu chữ số thập phân trông giống rò rỉ kỹ thuật; nếu dữ liệu thật có mức chính xác này, nên giữ nguyên exact value nhưng giải thích hoặc phân cấp cách hiển thị, tuyệt đối không tự làm tròn.
- GitHub Pages URL trong `STAFF_REVIEW.md` hiện trả 404. Đây là lỗi kênh review/tài liệu, không phải lỗi UI Atlas.

## Questions to Consider

1. Nếu lời hứa cốt lõi là “không cần tự kiểm tra lại”, ba câu **Có thể hành động chưa? Vì sao? Tiếp theo làm gì?** có nên xuất hiện nhất quán ở mọi điểm cam kết?
2. “Cách hình thành nhu cầu” có nên trở thành ngôn ngữ sản phẩm xuyên suốt từ Planning đến PO/PXK, thay vì chỉ là một disclosure rất tốt trong vài màn hình?
3. Trong 10 phút đầu, Atlas nên dạy 13 chức năng hay dẫn người dùng qua một ngày làm việc mẫu có điểm bắt đầu và điểm kết thúc?
4. Mobile có cần giữ bảng nhiều cột, hay nên trở thành hàng đợi quyết định theo từng Trường/nguyên liệu?
