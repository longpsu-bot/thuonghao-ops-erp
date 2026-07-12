import { useState, type ReactNode } from "react";
import {
  activeStages,
  atlasGroups,
  atlasPages,
  type AtlasPage,
  type AtlasPageId,
} from "./atlasConfig";

const requirements = [
  ["13/07/2026", "Trường Nguyễn Du", "Bếp trung tâm · Tuyến Bắc", "Súp bí đỏ", "620 suất", "Bí đỏ 75 kg"],
  ["14/07/2026", "Bếp Minh An", "Nhận tại kho Minh An", "Cơm trưa", "430 suất", "Gạo Jasmine 250 kg"],
  ["14/07/2026", "Trường Võ Thị Sáu", "Bếp trường · Tuyến Đông", "Canh rau củ", "280 suất", "Rau củ hỗn hợp 36 kg"],
];

const purchaseLines = [
  ["Gạo Jasmine", "NC-MA-0714 · tổng 250 kg", "Thành Công Foods", "150 kg", "Đã phân công", "Giao trước 05:30"],
  ["Gạo Jasmine", "NC-MA-0714 · tổng 250 kg", "An Phú Produce", "100 kg", "Chờ điều phối", "Nguồn bổ sung do tách đơn"],
  ["Bí đỏ", "NC-ND-0713 · 75 kg", "An Phú Produce", "75 kg", "Đã phân công", "Giao theo Tuyến Bắc"],
  ["Rau củ hỗn hợp", "NC-VT-0714 · 36 kg", "Nông sản Phúc Long", "36 kg", "Đã phân công", "Giao theo Tuyến Đông"],
];

const receivingLines = [
  ["An Phú Produce", "Bí đỏ", "75 kg", "75 kg", "Khớp", "Đủ cho Trường Nguyễn Du"],
  ["Thành Công Foods", "Gạo Jasmine", "150 kg", "140 kg", "Thiếu 10 kg", "Bếp Minh An còn thiếu 10 kg"],
  ["An Phú Produce", "Gạo Jasmine", "100 kg", "100 kg", "Khớp", "Phần tách đơn đã đủ"],
  ["Nông sản Phúc Long", "Rau củ hỗn hợp", "36 kg", "36 kg", "Khớp", "Đủ cho Tuyến Đông"],
];

function Chip({ children, tone = "neutral" }: { children: ReactNode; tone?: string }) {
  return <span className={`atlas-chip ${tone}`}>{children}</span>;
}

function PageFrame({ page, children }: { page: AtlasPage; children: ReactNode }) {
  return (
    <section className="atlas-page atlas-detail-page">
      <div className="page-kicker">ATLAS · DỮ LIỆU MẪU · KHÔNG TẠO CHỨNG TỪ</div>
      <div className="detail-heading">
        <div><h1>{page.label}</h1><p>{page.responsibility}</p></div>
        <Chip tone="prototype">Prototype tĩnh</Chip>
      </div>
      {children}
    </section>
  );
}

function RequirementPage({ page }: { page: AtlasPage }) {
  return (
    <PageFrame page={page}>
      <div className="atlas-callout">
        <span>ĐIỂM BÀN GIAO 01</span>
        <strong>Mỗi dòng nhu cầu cho biết rõ phục vụ ai và giao đến đâu.</strong>
        <p>Đơn vị phục vụ, điểm nhận và nhu cầu nguyên liệu được giữ cùng nhau trước khi lập kế hoạch mua hàng.</p>
      </div>
      <section className="atlas-panel">
        <div className="panel-heading"><div><span>DANH SÁCH NHU CẦU</span><h2>Nhu cầu theo đơn vị phục vụ và điểm nhận</h2></div><Chip tone="teal">08 dòng mẫu</Chip></div>
        <div className="atlas-table-wrap"><table className="atlas-table requirement-table"><thead><tr><th>Ngày phục vụ</th><th>Đơn vị phục vụ</th><th>Điểm nhận / bếp / tuyến</th><th>Món / dịch vụ</th><th>Quy mô</th><th>Nhu cầu nguyên liệu</th></tr></thead><tbody>{requirements.map((line) => <tr key={`${line[0]}-${line[1]}`}>{line.map((cell, index) => <td key={`${cell}-${index}`}>{cell}</td>)}</tr>)}</tbody></table></div>
      </section>
    </PageFrame>
  );
}

function PurchasePage({ page }: { page: AtlasPage }) {
  return (
    <PageFrame page={page}>
      <div className="stage-context"><div><span>ĐẦU VÀO</span><strong>Nhu cầu gắn đơn vị phục vụ và điểm nhận</strong></div><div className="handoff-arrow">→</div><div><span>ĐẦU RA</span><strong>Phân công nguồn cung theo từng phần</strong></div></div>
      <section className="atlas-panel">
        <div className="panel-heading"><div><span>PHÂN CÔNG MUA HÀNG</span><h2>Một nhu cầu có thể tách cho nhiều nhà cung cấp</h2></div><Chip tone="gold">Có tách đơn</Chip></div>
        <div className="atlas-table-wrap"><table className="atlas-table purchase-table"><thead><tr><th>Nguyên liệu</th><th>Nhu cầu liên quan</th><th>Nhà cung cấp</th><th>Số lượng phân công</th><th>Trạng thái</th><th>Ghi chú phối hợp</th></tr></thead><tbody>{purchaseLines.map((line, rowIndex) => <tr key={`${line[0]}-${line[2]}`}>{line.map((cell, index) => <td key={`${rowIndex}-${index}`}>{index === 4 ? <Chip tone={cell === "Chờ điều phối" ? "gold" : "teal"}>{cell}</Chip> : cell}</td>)}</tr>)}</tbody></table></div>
      </section>
      <p className="boundary-note">Ví dụ: nhu cầu gạo Jasmine 250 kg của Bếp Minh An được tách 150 kg và 100 kg cho hai nhà cung cấp. Ghi chú phối hợp là tùy chọn, không phải quy trình xác nhận bắt buộc.</p>
    </PageFrame>
  );
}

function ReceivingPage({ page }: { page: AtlasPage }) {
  return (
    <PageFrame page={page}>
      <div className="receiving-metrics"><article><span>ĐÃ ĐẶT</span><strong>361 kg</strong><small>Gồm các dòng đã phân công</small></article><article><span>THỰC NHẬN</span><strong>351 kg</strong><small>Đối chiếu theo nhà cung cấp</small></article><article className="shortage"><span>CHÊNH LỆCH</span><strong>Thiếu 10 kg</strong><small>Liên quan Bếp Minh An</small></article></div>
      <section className="atlas-panel">
        <div className="panel-heading"><div><span>ĐỐI CHIẾU NHẬP KHO</span><h2>Nhận hàng theo nhà cung cấp và phần phân công</h2></div><Chip tone="coral">01 cần xử lý</Chip></div>
        <div className="atlas-table-wrap"><table className="atlas-table receiving-table"><thead><tr><th>Nhà cung cấp</th><th>Nguyên liệu</th><th>Đã đặt</th><th>Thực nhận</th><th>Chênh lệch / kết quả</th><th>Ảnh hưởng / hướng xử lý</th></tr></thead><tbody>{receivingLines.map((line, rowIndex) => <tr key={`${line[0]}-${line[1]}`}>{line.slice(0, 4).map((cell, index) => <td key={`${rowIndex}-${index}`}>{cell}</td>)}<td><Chip tone={line[4] === "Thiếu 10 kg" ? "short" : "matched"}>{line[4]}</Chip></td><td>{line[5]}</td></tr>)}</tbody></table></div>
      </section>
      <div className="atlas-callout warning"><span>CHÊNH LỆCH MẪU</span><strong>Thành Công Foods giao thiếu 10 kg gạo Jasmine: đã đặt 150 kg, thực nhận 140 kg.</strong><p>Ảnh hưởng: Bếp Minh An còn thiếu 10 kg. Đây là thông tin theo dõi fixture, không phải bút toán tồn kho hoặc tác vụ điều phối thực tế.</p></div>
    </PageFrame>
  );
}

function RecipePage({ page }: { page: AtlasPage }) {
  const dishes = [["Súp bí đỏ", "Suất ăn · Trường Nguyễn Du", "Đang hoạt động", "BOM: bí đỏ 75 kg · kem 12 l · gia vị 4 kg"], ["Cơm trưa", "Suất ăn · Bếp Minh An", "Đã khóa", "BOM: gạo Jasmine 250 kg · dầu ăn 8 l"], ["Canh rau củ", "Suất ăn · Tuyến Đông", "Đang hoạt động", "BOM: rau củ 36 kg · gia vị 3 kg"]];
  return <PageFrame page={page}><p className="upstream-label">Dữ liệu hỗ trợ · đầu vào của Lập nhu cầu</p><div className="recipe-grid">{dishes.map((dish) => <article className="recipe-card" key={dish[0]}><div><span className="dish-icon">●</span><Chip tone={dish[2] === "Đã khóa" ? "neutral" : "teal"}>{dish[2]}</Chip></div><h2>{dish[0]}</h2><p>{dish[1]}</p><small>{dish[3]}</small></article>)}</div><div className="atlas-callout"><span>VAI TRÒ CÔNG THỨC</span><strong>Công thức là dữ liệu đầu vào của Lập nhu cầu, không phải giai đoạn vận hành hằng ngày.</strong><p>Trang prototype tĩnh; không có chỉnh sửa BOM, CRUD hoặc gọi backend.</p></div></PageFrame>;
}

function ChangeControlPage({ page }: { page: AtlasPage }) {
  const changes = ["Thêm nguyên liệu", "Thay thế nguyên liệu", "Điều chỉnh định lượng", "Ngừng sử dụng / loại bỏ nguyên liệu"];
  return <PageFrame page={page}><p className="upstream-label">Quản trị dữ liệu · không phải giai đoạn vận hành hằng ngày</p><section className="atlas-panel change-order"><div className="panel-heading"><div><span>CHANGE ORDER MẪU</span><h2>CO-REC-042 · Súp bí đỏ</h2></div><Chip>Không hiệu lực · mẫu</Chip></div><div className="change-grid"><div><span>LOẠI THAY ĐỔI</span>{changes.map((change) => <Chip key={change}>{change}</Chip>)}</div><div><span>NGÀY HIỆU LỰC</span><strong>20/07/2026</strong><span>LÝ DO / GHI CHÚ</span><p>Điều chỉnh theo nguồn cung mùa vụ; chỉ áp dụng sau khi được quản trị công thức xử lý.</p></div></div></section><div className="atlas-callout"><span>NGUYÊN TẮC KIỂM SOÁT</span><strong>Công thức đã khóa phải thay đổi qua change order, không sửa trực tiếp BOM gốc.</strong><p>Gửi change order và thực thi thay đổi chưa được triển khai trong prototype này.</p></div></PageFrame>;
}

function GenericPage({ page }: { page: AtlasPage }) { return <PageFrame page={page}><section className="atlas-panel generic-panel"><h2>{page.role}</h2><p>{page.input}</p><div><span>TRÁCH NHIỆM</span><strong>{page.responsibility}</strong></div><div><span>BÀN GIAO</span><strong>{page.handoff}</strong></div></section></PageFrame>; }

function OperationsHome({ onNavigate }: { onNavigate: (id: AtlasPageId) => void }) {
  return <section className="atlas-page home-page"><div className="ops-heading"><div><div className="page-kicker">ATLAS · BẢNG ĐIỀU HÀNH VẬN HÀNH</div><h1>Danh sách công việc trong ngày</h1><p>Kỳ phục vụ 13/07/2026 — 15/07/2026 · Dữ liệu mẫu để rà soát nhu cầu, nguồn cung và thực nhận.</p></div><Chip tone="prototype">Prototype tĩnh</Chip></div><div className="stage-rail" aria-label="Ba giai đoạn vận hành hằng ngày">{activeStages.map((stage, index) => <button className={`stage-card ${stage.tone}`} onClick={() => onNavigate(stage.id)} key={stage.id}><span>{stage.number}</span><div><h2>{stage.label}</h2><p>{stage.summary}</p><strong>{stage.metric}</strong></div>{index < 2 && <i>→</i>}</button>)}</div><div className="home-grid"><section className="atlas-panel attention-panel"><div className="panel-heading"><div><span>ƯU TIÊN CẦN XỬ LÝ</span><h2>Thiếu gạo Jasmine từ Thành Công Foods</h2></div><Chip tone="coral">Thiếu 10 kg</Chip></div><article><div className="attention-number">10 <small>kg</small></div><div><strong>Bếp Minh An chưa đủ nhu cầu phục vụ</strong><p>Đặt 150 kg · nhận 140 kg · còn thiếu 10 kg cho dòng nhu cầu NC-MA-0714.</p><button onClick={() => onNavigate("warehouse-receiving")}>Xem đối chiếu nhập kho →</button></div></article></section><section className="atlas-panel handoff-panel"><div className="panel-heading"><div><span>LUỒNG BÀN GIAO</span><h2>Giữ thông tin xuyên suốt</h2></div></div><ol><li><b>01</b><span>Đơn vị phục vụ + điểm nhận</span><strong>Lập nhu cầu</strong></li><li><b>02</b><span>Phân công, có thể tách nguồn</span><strong>Lập kế hoạch mua hàng</strong></li><li><b>03</b><span>Nhà cung cấp + thực nhận</span><strong>Nhập kho</strong></li></ol></section></div></section>;
}

export function AtlasApp() {
  const [active, setActive] = useState<AtlasPageId>("operations-home");
  const page = atlasPages.find((item) => item.id === active)!;
  const content = active === "operations-home" ? <OperationsHome onNavigate={setActive} /> : active === "requirement-planning" ? <RequirementPage page={page} /> : active === "purchase-planning" ? <PurchasePage page={page} /> : active === "warehouse-receiving" ? <ReceivingPage page={page} /> : active === "dishes-recipes" ? <RecipePage page={page} /> : active === "recipe-change-control" ? <ChangeControlPage page={page} /> : <GenericPage page={page} />;
  return <div className="atlas-shell"><aside className="atlas-sidebar"><div className="atlas-brand"><span>THƯỢNG HẢO</span><strong>ATLAS</strong><small>OPS ERP · Prototype</small></div><nav aria-label="Atlas navigation">{atlasGroups.map((group) => <div className="nav-group" key={group}><span>{group}</span>{atlasPages.filter((item) => item.group === group).map((item) => <button key={item.id} className={active === item.id ? "active" : ""} onClick={() => setActive(item.id)}>{item.label}</button>)}</div>)}</nav><div className="sidebar-boundary">Prototype tĩnh<br />Không backend · Không chứng từ</div></aside><div className="atlas-content"><header className="atlas-topbar"><div><span>VẬN HÀNH HÔM NAY</span><strong>Thứ hai, 13/07/2026</strong></div><div className="topbar-status"><i />01 chênh lệch cần theo dõi</div><Chip tone="prototype">Dữ liệu mẫu</Chip></header>{content}</div></div>;
}
