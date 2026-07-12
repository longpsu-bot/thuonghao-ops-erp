import type { Filters } from "../types";

type Props = {
  filters: Filters;
  customers: string[];
  onChange: (next: Filters) => void;
  onReset: () => void;
};
export function PlannerHeader({
  filters,
  customers,
  onChange,
  onReset,
}: Props) {
  const field = (key: keyof Filters) => ({
    value: filters[key],
    onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      onChange({ ...filters, [key]: e.target.value }),
  });
  return (
    <header className="planner-header">
      <div className="eyebrow">OPS ERP · KHÔNG GHI DỮ LIỆU</div>
      <div className="title-row">
        <div>
          <h1>Không gian lập kế hoạch</h1>
          <p>
            Prototype dữ liệu tĩnh · mọi kết quả tính toán chỉ để duyệt hợp đồng
            tương lai
          </p>
        </div>
        <button className="secondary" onClick={onReset}>
          Tải lại dữ liệu mẫu
        </button>
      </div>
      <div className="filters">
        <label>
          Từ ngày
          <input type="date" {...field("from")} />
        </label>
        <label>
          Đến ngày
          <input type="date" {...field("to")} />
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
            {customers.map((x) => (
              <option key={x}>{x}</option>
            ))}
          </select>
        </label>
        <label>
          Cảnh báo
          <select {...field("severity")}>
            <option value="">Tất cả</option>
            <option>OK</option>
            <option>INFO</option>
            <option>WARNING</option>
            <option>BLOCKING</option>
          </select>
        </label>
        <label>
          Sẵn sàng mua hàng
          <select {...field("readiness")}>
            <option value="">Tất cả</option>
            <option>READY</option>
            <option>NEEDS_REVIEW</option>
            <option>BLOCKED</option>
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
    </header>
  );
}
