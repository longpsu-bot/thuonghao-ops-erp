import type { Filters, PlannerViewMode } from "../types";
import { DateRangePickerVi } from "./DateRangePickerVi";

type Props = {
  filters: Filters;
  customers: string[];
  viewMode: PlannerViewMode;
  attentionOnly: boolean;
  onChange: (next: Filters) => void;
  onViewModeChange: (mode: PlannerViewMode) => void;
  onAttentionOnlyChange: (active: boolean) => void;
  onReset: () => void;
};

const viewModes: Array<{ value: PlannerViewMode; label: string }> = [
  { value: "DATE", label: "Theo ngày" },
  { value: "CUSTOMER", label: "Theo trường / khách" },
  { value: "SOURCE", label: "Theo nguồn nhu cầu" },
  { value: "SUPPLIER", label: "Theo nhà cung cấp" },
];

const warningLabels: Record<string, string> = {
  OK: "Bình thường",
  INFO: "Thông tin",
  WARNING: "Cần kiểm tra",
  BLOCKING: "Đang chặn",
};

const readinessLabels: Record<string, string> = {
  READY: "Sẵn sàng",
  NEEDS_REVIEW: "Cần xử lý",
  BLOCKED: "Bị chặn",
};

export function PlannerHeader({
  filters,
  customers,
  viewMode,
  attentionOnly,
  onChange,
  onViewModeChange,
  onAttentionOnlyChange,
  onReset,
}: Props) {
  const field = (key: keyof Filters) => ({
    value: filters[key],
    onChange: (
      event: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>,
    ) => onChange({ ...filters, [key]: event.target.value }),
  });

  return (
    <header className="planner-header">
      <div className="eyebrow">OPS ERP · KHÔNG GHI DỮ LIỆU</div>
      <div className="title-row">
        <div>
          <h1>Không gian lập kế hoạch</h1>
          <p>Rà soát nhu cầu, ngoại lệ và trạng thái sẵn sàng mua hàng.</p>
        </div>
        <button className="secondary" onClick={onReset}>
          Tải lại dữ liệu mẫu
        </button>
      </div>
      <div className="planner-controls">
        <DateRangePickerVi
          from={filters.from}
          to={filters.to}
          onChange={(from, to) => onChange({ ...filters, from, to })}
        />
        <label>
          Nguồn nhu cầu
          <select {...field("sourceType")}>
            <option value="">Tất cả nguồn</option>
            <option value="CATERING_MENU">Thực đơn</option>
            <option value="WHOLESALE_ORDER">Bán sỉ</option>
            <option value="PANTRY_ADD">Bổ sung kho</option>
            <option value="CORRECTION">Điều chỉnh</option>
          </select>
        </label>
        <label>
          Trường / khách hàng
          <select {...field("customer")}>
            <option value="">Tất cả</option>
            {customers.map((customer) => (
              <option key={customer}>{customer}</option>
            ))}
          </select>
        </label>
        <label>
          Cảnh báo
          <select {...field("severity")}>
            <option value="">Tất cả</option>
            {Object.entries(warningLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label>
          Sẵn sàng mua hàng
          <select {...field("readiness")}>
            <option value="">Tất cả</option>
            {Object.entries(readinessLabels).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label className="search">
          Tìm kiếm
          <input
            placeholder="Nguyên liệu, nguồn, khách hàng…"
            {...field("search")}
          />
        </label>
      </div>
      <div className="planner-toolbar">
        <div className="view-mode-control" role="group" aria-label="Chế độ xem">
          {viewModes.map((mode) => (
            <button
              key={mode.value}
              className={viewMode === mode.value ? "active" : ""}
              onClick={() => onViewModeChange(mode.value)}
            >
              {mode.label}
            </button>
          ))}
        </div>
        <label className="attention-filter">
          <input
            type="checkbox"
            checked={attentionOnly}
            onChange={(event) => onAttentionOnlyChange(event.target.checked)}
          />
          Chỉ xem dòng cần xử lý
        </label>
      </div>
    </header>
  );
}
