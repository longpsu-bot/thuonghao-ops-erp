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
