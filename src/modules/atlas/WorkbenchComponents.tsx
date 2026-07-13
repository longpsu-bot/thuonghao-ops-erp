import { useState, type ReactNode } from "react";
import type { AtlasPage } from "./atlasConfig";

export function Chip({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: "neutral" | "ok" | "warning" | "danger";
}) {
  return <span className={`workbench-chip ${tone}`}>{children}</span>;
}
export function Recipient({
  name,
  context,
}: {
  name: string;
  context: string;
}) {
  return (
    <>
      {name}
      <br />
      <small>{context}</small>
    </>
  );
}
export function CompactTable({
  headers,
  children,
}: {
  headers: string[];
  children: ReactNode;
}) {
  return (
    <table className="compact-table">
      <thead>
        <tr>
          {headers.map((header) => (
            <th key={header}>{header}</th>
          ))}
        </tr>
      </thead>
      <tbody>{children}</tbody>
    </table>
  );
}
export function ActionBar({ actions }: { actions: string[] }) {
  const [notice, setNotice] = useState("");
  return (
    <>
      {
        <div className="workbench-actions">
          {actions.map((action, index) => (
            <button
              key={action}
              className={index === 0 ? "primary" : ""}
              onClick={() =>
                setNotice(`${action}: thao tác prototype được ghi nhận cục bộ.`)
              }
            >
              {action}
            </button>
          ))}
        </div>
      }
      {notice && <p className="prototype-notice">{notice}</p>}
    </>
  );
}

export function TracePanel({ onClose }: { onClose: () => void }) {
  const stages = [
    ["Nguồn kế hoạch", "Thực đơn tuần / Sĩ số / Hàng đặt riêng / Pantry"],
    ["Công thức / định lượng", "Canh bí đỏ · 0,225 kg/suất"],
    ["Nhu cầu tính toán", "75 kg theo 320 suất thực tế"],
    ["Nhu cầu thực tế xác nhận", "72 kg · điều chỉnh -3 kg"],
    ["Phân bổ NCC", "Phân bổ chính và bổ sung"],
    ["PO", "PO-0714-008"],
    ["Phiếu xuất kho", "PXK-0714-ND"],
    ["Phiếu nhận hàng", "PNH-0714-008 · biểu mẫu trước nhận"],
    ["Nhập kho", "240 / 250 kg đã nhận"],
    ["Ngoại lệ", "Thiếu 10 kg · Thu mua xử lý"],
  ];
  return (
    <>
      <button
        className="trace-scrim"
        aria-label="Đóng chuỗi truy xuất"
        onClick={onClose}
      />
      <aside className="trace-panel" aria-label="Chuỗi truy xuất">
        <div className="trace-panel-head">
          <div>
            <span>TRACEABILITY · STATIC PROTOTYPE</span>
            <h2>Chuỗi truy xuất</h2>
            <strong>OPS-2026-0714-MA-GAO-001</strong>
          </div>
          <button aria-label="Đóng chuỗi truy xuất" onClick={onClose}>
            ×
          </button>
        </div>
        <ol className="atlas-trace-list">
          {stages.map(([stage, detail], index) => (
            <li key={stage}>
              <span>{index + 1}</span>
              <div>
                <b>{stage}</b>
                <small>{detail}</small>
              </div>
            </li>
          ))}
        </ol>
        <p className="trace-prototype-note">
          Chỉ minh hoạ liên kết dữ liệu cục bộ; không tạo sự kiện, chứng từ hay
          nhật ký kiểm toán thực tế.
        </p>
      </aside>
    </>
  );
}
export function PageShell({
  page,
  children,
}: {
  page: AtlasPage;
  children: ReactNode;
}) {
  return (
    <main className="atlas-page">
      <div className="page-kicker">ATLAS · ĐIỀU HÀNH HẰNG NGÀY</div>
      <h1>{page.label}</h1>
      <div className="page-meta">
        <span>
          <b>Quyết định</b>
          {page.decision}
        </span>
        <span>
          <b>Đối tượng</b>
          {page.object}
        </span>
        <span>
          <b>Trạng thái</b>
          {page.state}
        </span>
        <span>
          <b>Bàn giao</b>
          {page.handoff}
        </span>
      </div>
      {children}
    </main>
  );
}
export function Panel({
  title,
  description,
  status,
  children,
}: {
  title: string;
  description?: string;
  status?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="work-panel">
      <div className="panel-heading">
        <div>
          <h2>{title}</h2>
          {description && <p>{description}</p>}
        </div>
        {status}
      </div>
      {children}
    </section>
  );
}
