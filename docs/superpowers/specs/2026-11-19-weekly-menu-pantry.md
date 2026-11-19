# Hàng đặt riêng theo số ngày có thực đơn

**Quy tắc nghiệp vụ đã chốt ngày 19/11/2026.** Staff cấu hình định mức theo trường và nguyên liệu, tính bằng đơn vị mua cho mỗi ngày có thực đơn. Mỗi tuần, Atlas ghi toàn bộ lượng vào nhu cầu của ngày đầu tiên trường có thực đơn.

## Cách xác định lượng và ngày nhận

Lấy các ngày phân biệt của từng trường trong bản Thực đơn tuần đã lưu thành công. Với mỗi lệnh đang áp dụng cho trường, nhân định mức chính xác với số ngày đó. Ngày nhận là ngày nhỏ nhất trong tập ngày. Trường có nhiều món, nhiều nhóm ăn hoặc nhiều khung bữa trong một ngày vẫn chỉ được tính một lần. Tuần trống có lượng phát sinh bằng 0 và không tạo dòng. Sĩ số không tham gia phép tính.

| Thực đơn của trường trong tuần | Định mức | Kết quả |
| --- | --- | --- |
| Thứ Ba có hai món, thứ Tư và thứ Năm mỗi ngày một món | 0,4 kg tỏi/ngày | 1,2 kg vào thứ Ba |
| Thêm thực đơn thứ Sáu vào ví dụ trên | 0,4 kg tỏi/ngày | 1,6 kg vào thứ Ba, thay cho 1,2 kg |
| Bỏ món cuối cùng của thứ Sáu | 0,4 kg tỏi/ngày | 1,2 kg vào thứ Ba |
| Đổi món nhưng giữ nguyên các ngày có thực đơn | 0,4 kg tỏi/ngày | Giữ nguyên lượng và ngày nhận |
| Trường khác chỉ có thực đơn thứ Năm | 0,4 kg tỏi/ngày | 0,4 kg vào thứ Năm nếu trường này cũng có lệnh |

## Thao tác của nhân viên

Trong **Hàng đặt riêng**, nhân viên chọn trường, nguyên liệu và nhập **Định mức mỗi ngày có thực đơn**. Atlas hiển thị đơn vị mua theo danh mục. Lệnh được dùng cho các tuần tiếp theo cho đến khi ngừng áp dụng. Khi xem một tuần, nhân viên xem được các ngày đã tính, định mức, tổng lượng và ngày nhận. Giữ cùng bộ chọn trường và nguyên liệu, cách nhập số thập phân và quyền Planning đang dùng. Chỉ có một kiểu lệnh tính cho cả tuần.

## Tích hợp Planning

- PostgreSQL sở hữu lệnh và phép tính. Nguồn ngày là các dòng của đúng bản duyệt Thực đơn tuần, có khóa trường, ngày phục vụ và món. Dùng số thập phân chính xác và đơn vị mua đã xác định. Lưu dấu vết phiên bản lệnh, phiên bản thực đơn và các ngày tạo ra lượng của tuần.
- Xem tác động trên dữ liệu thực đơn đề xuất trước khi lưu. Khi lưu hoặc đồng bộ thực đơn thành công, đối chiếu lại cả tuần của trường. Khi thêm ngày thứ Sáu, tập ngày chịu tác động bao gồm cả ngày thứ Ba nếu lượng giao thứ Ba thay đổi. Tính lại cả ngày nhận cũ và mới khi chúng khác nhau.
- Cùng quy tắc đối chiếu áp dụng khi lưu hoặc ngừng lệnh cho tuần chịu tác động. Đồng bộ lại cùng một thực đơn, bấm lưu lại hoặc hai nhân viên cùng thao tác phải cho một kết quả. Dùng khóa tuần, kiểm tra phiên bản và biên nhận của Planning. Một bản xem trước đã cũ cần tải lại.
- Dòng phát sinh thuộc nguồn **Hàng đặt riêng**. Bảo toàn nguồn **Bổ sung**, các dòng nhập tay, bản nháp đang làm việc và tất cả các trường khác khi lưu. Phân biệt đóng góp của lệnh với một dòng nhập tay bằng định danh có kiểu. Không dùng ghi chú làm dấu nhận dạng.
- Với nhu cầu đang lập, đưa đúng các ngày bị ảnh hưởng vào luồng tính lại hiện có. Khi đã chốt nhu cầu hoặc phát hành chứng từ, hiện tác động lên ngày giao đầu tuần và dùng cơ chế điều chỉnh có thẩm quyền. Đơn mua và phiếu xuất kho đã phát hành giữ nguyên lịch sử của chúng.

## Tách nguồn khi trùng nguyên liệu

Hàng đặt riêng tự động, Hàng đặt riêng thủ công và nhu cầu từ thực đơn là các nguồn riêng. Cùng trường, ngày, nguyên liệu và đơn vị, 0,5 kg tỏi nhập tay và 1,6 kg từ lệnh được lưu và hiển thị riêng. Hai phần đóng góp 2,1 kg vào nhu cầu lý thuyết, trước phần từ thực đơn. Chạy lại lệnh chỉ đối chiếu dòng tự động. Nhân viên sửa lượng thủ công tại dòng thủ công và sửa định mức tại lệnh.

## Nghiệm thu

Kiểm tra các ví dụ trong bảng bằng PostgreSQL và đường vào thực tế từ thao tác lưu Thực đơn. Bổ sung trường hợp chưa nhập sĩ số, tuần trống, hai trường có lịch khác nhau, cùng mặt hàng nhập tay, lưu lặp và cập nhật đồng thời. Kiểm tra cả trường hợp thứ Sáu thay đổi sau khi thứ Ba đã có chứng từ. Trên màn hình, kiểm tra nhập định mức và xem lượng qua bàn phím, ở độ rộng laptop và điện thoại. Khi chạy migration trên dữ liệu cũ, danh sách lệnh ban đầu rỗng. Nếu cần dừng tính năng sau triển khai, bảo toàn lịch sử lệnh và các chứng từ đã dùng chúng.

Đã đối chiếu phép tính bằng truy vấn PostgreSQL chỉ đọc trên tập giá trị giả lập. Trường A có ba ngày, gồm một ngày có hai món, cho 1,2 kg. Thêm ngày thứ tư cho 1,6 kg ở cùng ngày nhận. Trường B có một ngày cho 0,4 kg và trường trống không xuất hiện. Đây là kiểm tra phép tính, chưa phải kiểm thử đường lưu dữ liệu qua ứng dụng.

Tham chiếu: [quy tắc BR-051](../../business-rules/business-rule-register.md), [định danh dòng Pantry](../../architecture/pantry-02-connected-pantry-source.md), [điều chỉnh và chứng từ đã phát hành](../../decisions/decision-ops-v1-school-fulfilment-closeout.md), [ngày có thực đơn của trường trong bản duyệt](../../../supabase/migrations/20260719165444_pa_06e_h0a3a_weekly_menu_persistence_foundation.sql).
