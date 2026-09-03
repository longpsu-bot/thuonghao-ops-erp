import { useState, type ReactNode } from "react";
import { Alert, Button, Group, Stack, Text, Title } from "@mantine/core";
import { ArrowClockwise } from "@phosphor-icons/react";
import type { AtlasPage } from "./atlasConfig";

/** Routine refresh only; recovery actions keep their explicit text. */
export function RefreshButton({
  onClick,
  disabled = false,
}: {
  onClick: () => void;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      className="secondary workbench-refresh-button"
      aria-label="Làm mới dữ liệu"
      title="Làm mới dữ liệu"
      onClick={onClick}
      disabled={disabled}
    >
      <ArrowClockwise size={17} aria-hidden="true" />
    </button>
  );
}

type HeadingLevel = 1 | 2 | 3;

export function WorkbenchHeader({
  eyebrow,
  title,
  context,
  status,
  actions,
  headingLevel = 1,
}: {
  eyebrow?: string;
  title: string;
  context?: ReactNode;
  status?: ReactNode;
  actions?: ReactNode;
  headingLevel?: HeadingLevel;
}) {
  return (
    <Group
      component="header"
      className="workbench-header"
      align="flex-start"
      justify="space-between"
      gap="lg"
      wrap="wrap"
    >
      <Stack className="workbench-header-copy" gap={4}>
        {eyebrow && (
          <Text className="workbench-header-eyebrow" component="span">
            {eyebrow}
          </Text>
        )}
        <Title order={headingLevel}>{title}</Title>
        {context && (
          <Text className="workbench-header-context" component="div">
            {context}
          </Text>
        )}
      </Stack>
      {(status || actions) && (
        <Stack className="workbench-header-aside" gap="xs" align="flex-end">
          {status}
          {actions && (
            <Group className="workbench-header-actions" gap="xs">
              {actions}
            </Group>
          )}
        </Stack>
      )}
    </Group>
  );
}

type OperationalStateVariant =
  | "information"
  | "warning"
  | "blocking"
  | "unknown-outcome"
  | "read-only"
  | "access-denied"
  | "system-error";

const operationalStatePresentation: Record<
  OperationalStateVariant,
  { color: string; label: string; urgent: boolean }
> = {
  information: { color: "blue", label: "Thông tin", urgent: false },
  warning: { color: "yellow", label: "Cần chú ý", urgent: false },
  blocking: { color: "red", label: "Đang bị chặn", urgent: true },
  "unknown-outcome": {
    color: "violet",
    label: "Kết quả chưa xác định",
    urgent: false,
  },
  "read-only": { color: "blue", label: "Chỉ xem", urgent: false },
  "access-denied": {
    color: "red",
    label: "Không có quyền truy cập",
    urgent: true,
  },
  "system-error": { color: "red", label: "Lỗi hệ thống", urgent: true },
};

export function OperationalState({
  variant,
  title,
  children,
  onAuthoritativeRefresh,
  compact = false,
}: {
  variant: OperationalStateVariant;
  title: string;
  children?: ReactNode;
  onAuthoritativeRefresh?: () => void;
  compact?: boolean;
}) {
  const presentation = operationalStatePresentation[variant];

  return (
    <Alert
      className={`operational-state ${variant}${compact ? " compact" : ""}`}
      color={presentation.color}
      variant="light"
      radius="sm"
      role={presentation.urgent ? "alert" : "status"}
      aria-live={presentation.urgent ? "assertive" : "polite"}
      aria-atomic="true"
      title={
        <Stack gap={2}>
          <Text className="operational-state-label" component="span">
            {presentation.label}
          </Text>
          <Text component="strong" fw={700}>
            {title}
          </Text>
        </Stack>
      }
    >
      {children && <div>{children}</div>}
      {variant === "unknown-outcome" && (
        <Text component="p" mt={4}>
          Chưa thể xác nhận thao tác đã thành công hay thất bại. Không tự động
          gửi lại thao tác. Hãy tải lại dữ liệu mới nhất trước khi quyết định
          bước tiếp theo.
        </Text>
      )}
      {onAuthoritativeRefresh && (
        <Button
          type="button"
          variant="outline"
          color={presentation.color}
          mt="sm"
          onClick={onAuthoritativeRefresh}
        >
          Tải lại dữ liệu
        </Button>
      )}
    </Alert>
  );
}

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
    ["Nguồn kế hoạch", "Thực đơn / Sĩ số / Nhu cầu bổ sung"],
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
