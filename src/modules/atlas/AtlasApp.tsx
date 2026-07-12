import { useState, type ReactNode } from "react";
import { activeStages, atlasGroups, atlasPages, type AtlasPage, type AtlasPageId } from "./atlasConfig";

const requirements = [
  ["ND-0713", "Súp bí đỏ", "620 suất", "13/07/2026", "Trường Nguyễn Du", "Bếp trung tâm · Tuyến Bắc", "75 kg bí đỏ"],
  ["MA-0714", "Cơm trưa", "430 suất", "14/07/2026", "Bếp Minh An", "Nhận tại kho", "250 kg gạo Jasmine"],
  ["VT-0714", "Canh rau củ", "280 suất", "14/07/2026", "Trường Võ Thị Sáu", "Bếp trường · Tuyến Đông", "36 kg rau củ"],
];

const purchaseLines = [
  ["Bí đỏ", "75 kg", "An Phú Produce", "Đã phân công", "Giao 05:30 · ghi chú phối hợp tùy chọn"],
  ["Gạo Jasmine", "250 kg", "Thành Công Foods", "Chuẩn bị đơn", "Không yêu cầu xác nhận NCC trong chu kỳ 24h"],
  ["Rau củ hỗn hợp", "36 kg", "Nông sản Phúc Long", "Đã phân công", "Giao cùng tuyến Đông"],
];

const receivingLines = [
  ["Bí đỏ", "75 kg", "75 kg", "Khớp", "matched"],
  ["Gạo Jasmine", "250 kg", "240 kg", "Thiếu 10 kg", "short"],
  ["Rau củ hỗn hợp", "36 kg", "36 kg", "Khớp", "matched"],
];

function Chip({ children, tone = "neutral" }: { children: ReactNode; tone?: string }) {
  return <span className={`atlas-chip ${tone}`}>{children}</span>;
}

function PageFrame({ page, children }: { page: AtlasPage; children: ReactNode }) {
  return <section className="atlas-page atlas-detail-page"><div className="page-kicker">ATLAS · DỮ LIỆU MẪU · KHÔNG TẠO CHỨNG TỪ</div><div className="detail-heading"><div><h1>{page.label}</h1><p>{page.responsibility}</p></div><Chip tone="prototype">Prototype tĩnh</Chip></div>{children}</section>;
}

function RequirementPage({ page }: { page: AtlasPage }) {
  return <PageFrame page={page}><div className="atlas-callout"><span>ĐIỂM BÀN GIAO 01</span><strong>Nhu cầu luôn đi cùng người nhận, ngày phục vụ và điểm đến.</strong><p>Không tách tuyến trường/bếp khỏi dòng nhu cầu trước khi chuyển sang mua hàng.</p></div><section className="atlas-panel"><div className="panel-heading"><div><span>DANH SÁCH NHU CẦU</span><h2>Phục vụ theo điểm đến</h2></div><Chip tone="teal">08 dòng</Chip></div><div className="atlas-table-wrap"><table className="atlas-table"><thead><tr><th>Mã</th><th>Món / dịch vụ</th><th>Quy mô</th><th>Ngày phục vụ</th><th>Khách hàng / trường</th><th>Bếp / điểm đến</th><th>Nhu cầu</th></tr></thead><tbody>{requirements.map((line) => <tr key={line[0]}>{line.map((cell) => <td key={cell}>{cell}</td>)}</tr>)}</tbody></table></div></section></PageFrame>;
}

function PurchasePage({ page }: { page: AtlasPage }) {
  return <PageFrame page={page}><div className="stage-context"><div><span>ĐẦU VÀO</span><strong>Nhu cầu đã gắn điểm đến</strong></div><div className="handoff-arrow">→</div><div><span>ĐẦU RA</span><strong>Danh sách đặt nhà cung cấp</strong></div></div><section className="atlas-panel"><div className="panel-heading"><div><span>CHUẨN BỊ ĐƠN HÀNG</span><h2>Phân công nguồn cung</h2></div><Chip tone="gold">Phối hợp tùy chọn</Chip></div><div className="atlas-table-wrap"><table className="atlas-table"><thead><tr><th>Nguyên liệu</th><th>Số lượng</th><th>Nhà cung cấp</th><th>Trạng thái</th><th>Ghi chú phối hợp</th></tr></thead><tbody>{purchaseLines.map((line) => <tr key={line[0]}>{line.map((cell, index) => <td key={cell}>{index === 3 ? <Chip tone="teal">{cell}</Chip> : cell}</td>)}</tr>)}</tbody></table></div></section><p className="boundary-note">Ghi chú phối hợp nhà cung cấp chỉ là thông tin tùy chọn; không hình thành một quy trình xác nhận bắt buộc.</p></PageFrame>;
}

function ReceivingPage({ page }: { page: AtlasPage }) {
  return <PageFrame page={page}><div className="receiving-metrics"><article><span>ĐẶT HÀNG</span><strong>361 kg</strong><small>Tổng fixture trong phiên nhận</small></article><article><span>THỰC NHẬN</span><strong>351 kg</strong><small>Đã đối chiếu theo dòng</small></article><article className="shortage"><span>CHÊNH LỆCH</span><strong>Thiếu 10 kg</strong><small>Gạo Jasmine cần được theo dõi</small></article></div><section className="atlas-panel"><div className="panel-heading"><div><span>ĐỐI CHIẾU NHẬP KHO</span><h2>Đặt hàng và thực nhận</h2></div><Chip tone="coral">01 cần chú ý</Chip></div><div className="atlas-table-wrap"><table className="atlas-table"><thead><tr><th>Nguyên liệu</th><th>Đã đặt</th><th>Thực nhận</th><th>Kết quả</th></tr></thead><tbody>{receivingLines.map((line) => <tr key={line[0]}>{line.slice(0, 3).map((cell, index) => <td key={`${line[0]}-${index}`}>{cell}</td>)}<td><Chip tone={line[4]}>{line[3]}</Chip></td></tr>)}</tbody></table></div></section><div className="atlas-callout warning"><span>CHÊNH LỆCH MẪU</span><strong>Gạo Jasmine: đặt 250 kg · nhận 240 kg · thiếu 10 kg.</strong><p>Đây là fixture hiển thị, không phải bút toán tồn kho hay xử lý kế toán.</p></div></PageFrame>;
}

function RecipePage({ page }: { page: AtlasPage }) {
  return <PageFrame page={page}><p className="upstream-label">Dữ liệu hỗ trợ · thượng nguồn của Lập nhu cầu</p><div className="recipe-grid">{[["Súp bí đỏ", "Catering · Trường Nguyễn Du", "Đang hoạt động", "BOM: bí đỏ 75 kg · kem 12 l · gia vị 4 kg"], ["Cơm trưa", "Catering · Bếp Minh An", "Đã khóa", "BOM: gạo Jasmine 250 kg · dầu ăn 8 l"], ["Canh rau củ", "Catering · Tuyến Đông", "Đang hoạt động", "BOM: rau củ 36 kg · gia vị 3 kg"]].map((dish) => <article className="recipe-card" key={dish[0]}><div><span className="dish-icon">◈</span><Chip tone={dish[2] === "Đã khóa" ? "neutral" : "teal"}>{dish[2]}</Chip></div><h2>{dish[0]}</h2><p>{dish[1]}</p><small>{dish[3]}</small></article>)}</div><div className="atlas-callout"><span>VAI TRÒ CÔNG THỨC</span><strong>Công thức là đầu vào để Lập nhu cầu, không phải một giai đoạn vận hành hằng ngày.</strong><p>Trang prototype tĩnh; không có chỉnh sửa BOM, CRUD hay gọi backend.</p></div></PageFrame>;
}

function ChangeControlPage({ page }: { page: AtlasPage }) {
  const changes = ["Thêm nguyên liệu", "Thay thế nguyên liệu", "Điều chỉnh định lượng", "Ngừng sử dụng / loại bỏ nguyên liệu"];
  return <PageFrame page={page}><p className="upstream-label">Quản trị thượng nguồn · không phải giai đoạn vận hành hằng ngày</p><section className="atlas-panel change-order"><div className="panel-heading"><div><span>CHANGE ORDER MẪU</span><h2>CO-REC-042 · Súp bí đỏ</h2></div><Chip tone="neutral">Inactive · mẫu</Chip></div><div className="change-grid"><div><span>LOẠI THAY ĐỔI</span>{changes.map((change) => <Chip key={change}>{change}</Chip>)}</div><div><span>NGÀY HIỆU LỰC</span><strong>20/07/2026</strong><span>LÝ DO / GHI CHÚ</span><p>Điều chỉnh theo nguồn cung mùa vụ; chỉ áp dụng sau khi được quản trị công thức xử lý.</p></div></div></section><div className="atlas-callout"><span>NGUYÊN TẮC KIỂM SOÁT</span><strong>Công thức đã khóa phải thay đổi qua change order, không sửa trực tiếp BOM gốc.</strong><p>Gửi change order và thực thi thay đổi chưa được triển khai trong prototype này.</p></div></PageFrame>;
}

function GenericPage({ page }: { page: AtlasPage }) { return <PageFrame page={page}><section className="atlas-panel generic-panel"><h2>{page.role}</h2><p>{page.input}</p><div><span>TRÁCH NHIỆM</span><strong>{page.responsibility}</strong></div><div><span>BÀN GIAO</span><strong>{page.handoff}</strong></div></section></PageFrame>; }

function OperationsHome({ onNavigate }: { onNavigate: (id: AtlasPageId) => void }) { return <section className="atlas-page home-page"><div className="home-hero"><div><div className="page-kicker">ATLAS · VẬN HÀNH SUẤT ĂN HỌC ĐƯỜNG</div><h1>Điều hành rõ ràng,<br />bàn giao liền mạch.</h1><p>Ba giai đoạn hằng ngày tập trung vào nhu cầu, kế hoạch mua và thực nhận tại kho.</p></div><div className="period-card"><span>KỲ PHỤC VỤ</span><strong>13 — 15<br />Tháng 07</strong><small>2026 · Dữ liệu mẫu</small></div></div><div className="stage-rail" aria-label="Ba giai đoạn vận hành hằng ngày">{activeStages.map((stage, index) => <button className={`stage-card ${stage.tone}`} onClick={() => onNavigate(stage.id)} key={stage.id}><span>{stage.number}</span><div><h2>{stage.label}</h2><p>{stage.summary}</p><strong>{stage.metric}</strong></div>{index < 2 && <i>→</i>}</button>)}</div><div className="home-grid"><section className="atlas-panel attention-panel"><div className="panel-heading"><div><span>ƯU TIÊN HÔM NAY</span><h2>Điểm cần xử lý</h2></div><Chip tone="coral">01 thiếu hụt</Chip></div><article><div className="attention-number">10 <small>kg</small></div><div><strong>Gạo Jasmine thiếu so với đơn</strong><p>Đặt 250 kg · nhận 240 kg · Thành Công Foods</p><button onClick={() => onNavigate("warehouse-receiving")}>Xem chi tiết nhận kho →</button></div></article></section><section className="atlas-panel handoff-panel"><div className="panel-heading"><div><span>LUỒNG BÀN GIAO</span><h2>Không mất ngữ cảnh</h2></div></div><ol><li><b>01</b><span>Nhu cầu + điểm đến</span><strong>Lập nhu cầu</strong></li><li><b>02</b><span>Phân công nguồn cung</span><strong>Lập kế hoạch mua hàng</strong></li><li><b>03</b><span>Đặt hàng ↔ thực nhận</span><strong>Nhập kho</strong></li></ol></section></div></section>; }

export function AtlasApp() {
  const [active, setActive] = useState<AtlasPageId>("operations-home"); const page = atlasPages.find((item) => item.id === active)!;
  const content = active === "operations-home" ? <OperationsHome onNavigate={setActive} /> : active === "requirement-planning" ? <RequirementPage page={page} /> : active === "purchase-planning" ? <PurchasePage page={page} /> : active === "warehouse-receiving" ? <ReceivingPage page={page} /> : active === "dishes-recipes" ? <RecipePage page={page} /> : active === "recipe-change-control" ? <ChangeControlPage page={page} /> : <GenericPage page={page} />;
  return <div className="atlas-shell"><aside className="atlas-sidebar"><div className="atlas-brand"><span>THƯỢNG HẢO</span><strong>ATLAS</strong><small>OPS ERP · Prototype</small></div><nav aria-label="Atlas navigation">{atlasGroups.map((group) => <div className="nav-group" key={group}><span>{group}</span>{atlasPages.filter((item) => item.group === group).map((item) => <button key={item.id} className={active === item.id ? "active" : ""} onClick={() => setActive(item.id)}>{item.label}</button>)}</div>)}</nav><div className="sidebar-boundary">Prototype tĩnh<br />Không backend · Không chứng từ</div></aside><div className="atlas-content"><header className="atlas-topbar"><div><span>VẬN HÀNH HÔM NAY</span><strong>Chủ nhật, 12/07/2026</strong></div><div className="topbar-status"><i />Có 01 chênh lệch cần theo dõi</div><Chip tone="prototype">Mock data</Chip></header>{content}</div></div>;
}
