# Bằng chứng review UI/UX Atlas — 09/11/2026

Review chính: [layout, hierarchy và typography](../../../ui/atlas-ui-ux-review-2026-11-09.md).

Baseline `e5f5db79a70aee68c15f838959aab8411439e15a`, cộng bản sửa cuối của `ChangeOrderDetail.tsx`. Dữ liệu là fixture local; không phải dữ liệu hosted hoặc bằng chứng ghi/lưu nghiệp vụ.

## Ảnh đối chiếu

| Ảnh                                                       | Kích thước | Phạm vi                                                                                |
| --------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------- |
| [Chi tiết trước sửa](change-detail-before-1366.png)       | 1366 × 768 | Root chụp trước khi sửa component; giá trị 13px, khoảng cách bắt đầu cột khoảng 411px. |
| [Chi tiết cuối — desktop](change-detail-final-1366.png)   | 1366 × 768 | Bản sửa cuối; giá trị 14px, cột cách nhau 176px, nhóm Sửa/Hủy gần nhau.                |
| [Chi tiết cuối — điện thoại](change-detail-final-390.png) | 390 × 844  | Bản sửa cuối; giá trị 15px; nhãn dài wrap trong cột riêng.                             |
| [Thanh nhập Sĩ số](attendance-1366.png)                   | 1366 × 768 | Bằng chứng P2 — các cụm nhập XLSX/tải mẫu/dán hàng loạt.                               |
| [Hàng đặt riêng trống](pantry-1366.png)                   | 1366 × 768 | Bằng chứng P2 — phân cấp nhóm thêm dòng và hướng dẫn trống.                            |
| [Chi tiết Công thức](recipe-detail-390.png)               | 390 × 844  | Bằng chứng P2 — nhóm tiện ích lệch phải trên điện thoại.                               |

## Đối soát toàn bộ owner

- Desktop: [Thực đơn → Đối chiếu](desktop-overview-1.jpg), [Trường học → Lệnh điều chỉnh](desktop-overview-2.jpg).
- Điện thoại: [Thực đơn → Đối chiếu](mobile-overview-1.jpg), [Trường học → Lệnh điều chỉnh](mobile-overview-2.jpg).
- [30 measurement records](verified-metrics.json): 13 owner × hai viewport, cộng chi tiết Công thức/Lệnh điều chỉnh × hai viewport. Bản xuất gọn giữ thời điểm chụp, viewport, kích thước document, bề rộng bảng, chiều cao hàng đầu và cỡ tiêu đề; không phụ thuộc đường dẫn TEMP.

Root hoàn tất batch Chromium `151.0.7922.34`: **30 captures**, **0 page errors**, **0 external requests**, kích thước PNG và DOM khớp viewport; document không overflow. Root đã xem bốn overview và hai ảnh chi tiết cuối. Helper quản lý server đã dừng server sau khi batch kết thúc.

## Số đo và nguồn kiểm tra

- Hai reviewer độc lập `/root/ui_design_review` và `/root/ui_evidence_review`; B đo DOM cả 13 owner ở hai viewport, A xem trực tiếp cả 13 owner desktop và một số trạng thái chi tiết/điện thoại. Root bổ sung bộ ảnh cuối sau bản sửa.
- Owner rộng 1346px desktop và 370px điện thoại; không có document overflow trong các mẫu đã đo.
- Chữ: title 26/24px, section 18px, label 14px, body 14/15px; font theo system hiện có. Đây là computed styles; không xác nhận riêng font download.
- Chi tiết: desktop nhãn 160px + gap 16px; điện thoại nhãn 128px + gap 16px. Nhãn dài không chồng lên giá trị trong mẫu đã đo.
- Bảng local: Thực đơn điện thoại 1120px trong vùng 353px; Xác nhận nhu cầu 1292px trong vùng 338px. Ở Xác nhận nhu cầu, lượng đề xuất tại x = 411px và lượng xác nhận tại x = 551px trong viewport 390px; mỗi hàng mẫu cao khoảng 154px.
- Scroll test native của B trên chi tiết điện thoại: owner 0 → 85px, document Y = 0. Đây là bằng chứng phụ của B, không thay cho measurement cuối được lưu trong JSON.
- Detector trước sửa: 160 markup files, exit 0, JSON `[]`; sau sửa quét riêng component cũng exit 0, JSON `[]`. Không dùng detector để kết luận tính thẩm mỹ.

## Bằng chứng bị loại và giới hạn

Một số ảnh native đầu tiên của B chứa khung hình menu cũ dù DOM đã cập nhật; không dùng những ảnh đó. Batch Playwright đầu của B mất session; không tính là PASS. Batch đầu của Root dừng vì locator tabpanel không phân biệt owner và tab lồng nhau; sửa đúng locator trong script bằng chứng rồi chạy batch mới hoàn chỉnh. Không sửa source ứng dụng để vượt lỗi script.

Gallery ngày 29/10 chỉ là bằng chứng lịch sử. Không có kiểm tra thiết bị thật, virtual keyboard, screen-reader speech, mọi trạng thái ngoại lệ hoặc hosted persistence. Fixture Đơn mua/Phân bổ/Đối chiếu có ít chứng từ; kết luận mật độ giữ giới hạn đó. Hai viewport này không xác nhận mọi breakpoint trung gian hoặc 200% zoom.
