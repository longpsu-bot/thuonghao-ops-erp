import type { Filters, ViewMode } from "../types";

type Props = {
  filters: Filters;
  customers: string[];
  viewMode: ViewMode;
  onChange: (next: Filters) => void;
  onViewModeChange: (mode: ViewMode) => void;
  onReset: () => void;
};

const formatDate = (value: string) => {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
};
const parseDate = (value: string) => {
  const match = value.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  return match ? `${match[3]}-${match[2]}-${match[1]}` : "";
};

export function PlannerHeader({
  filters,
  customers,
  viewMode,
  onChange,
  onViewModeChange,
  onReset,
}: Props) {
  const field = (key: keyof Filters) => ({
    value: filters[key] as string,
    onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      onChange({ ...filters, [key]: e.target.value }),
  });
  const dateField = (key: "from" | "to") => ({
    value: formatDate(filters[key]),
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => {
      const parsed = parseDate(e.target.value);
      if (parsed) onChange({ ...filters, [key]: parsed });
    },
  });
  return (
    <header className="planner-header">
      <div className="prototype-banner">
        PROTOTYPE DỮ LIỆU MẪU · KHÔNG KẾT NỐI BACKEND · KHÔNG GHI DỮ LIỆU
      </div>
      <div className="title-row">
        <div>
          <h1>Không gian lập kế hoạch</h1>
          <p>Rà soát nhu cầu, ngoại lệ và mức sẵn sàng trước khi chuyển mua hàng</p>
        </div>
        <button className="secondary" onClick={onReset}>Tải lại dữ liệu mẫu</button>
      </div>
      <div className="view-mode" aria-label="Chế độ xem">
        <span>Chế độ xem</span>
        {([
          ["DATE", "Theo ngày"],
          ["CUSTOMER", "Theo trường / khách"],
          ["SOURCE", "Theo nguồn nhu cầu"],
          ["SUPPLIER", "Theo nhà cung cấp"],
        ] as const).map(([value, label]) => (
          <button
            key={value}
            className={viewMode === value ? "active-chip" : "chip"}
            onClick={() => onViewModeChange(value)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="filters">
        <label>
          Từ ngày
          <input inputMode="numeric" placeholder="dd/mm/yyyy" aria-label="Từ ngày" {...dateField("from")} />
        </label>
        <label>
          Đến ngày
          <input inputMode="numeric" placeholder="dd/mm/yyyy" aria-label="Đến ngày" {...dateField("to")} />
        </label>
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
            {customers.map((x) => <option key={x}>{x}</option>)}
          </select>
        </label>
        <label>
          Cảnh báo
          <select {...field("severity")}>
            <option value="">Tất cả</option>
            <option value="OK">Bình thường</option>
            <option value="INFO">Thông tin</option>
            <option value="WARNING">Cần chú ý</option>
            <option value="BLOCKING">Đang chặn</option>
          </select>
        </label>
        <label>
          Sẵn sàng mua hàng
          <select {...field("readiness")}>
            <option value="">Tất cả</option>
            <option value="READY">Sẵn sàng</option>
            <option value="NEEDS_REVIEW">Cần duyệt</option>
            <option value="BLOCKED">Đang chặn</option>
          </select>
        </label>
        <label className="search">
          Tìm kiếm
          <input placeholder="Nguyên liệu, nguồn, khách hàng…" {...field("search")} />
        </label>
      </div>
      <button
        className={filters.exceptionOnly ? "quick-filter active" : "quick-filter"}
        onClick={() => onChange({ ...filters, exceptionOnly: !filters.exceptionOnly })}
      >
        {filters.exceptionOnly ? "✓ " : ""}Chỉ xem dòng có vấn đề
      </button>
    </header>
  );
}
