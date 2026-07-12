import type { DemandSource } from "../types";
const formatDate = (value: string) => `${value.slice(8, 10)}/${value.slice(5, 7)}/${value.slice(0, 4)}`;
const labels: Record<string, string> = {
  CATERING_MENU: "Thực đơn",
  WHOLESALE_ORDER: "Bán sỉ",
  PANTRY_ADD: "Bổ sung kho",
  MANUAL_DEMAND: "Thủ công",
  CORRECTION: "Điều chỉnh",
};
export function DemandSourcePanel({
  sources,
  selected,
  onSelect,
}: {
  sources: DemandSource[];
  selected: string;
  onSelect: (id: string) => void;
}) {
  return (
    <aside className="source-panel">
      <div className="section-heading">
        <div>
          <span className="eyebrow">NGUỒN ĐẦU VÀO</span>
          <h2>Nhu cầu</h2>
        </div>
        <button
          className={!selected ? "active-chip" : "chip"}
          onClick={() => onSelect("")}
        >
          Tất cả
        </button>
      </div>
      <div className="source-list">
        {sources.map((s) => (
          <button
            key={s.id}
            className={`source-card ${selected === s.id ? "selected" : ""}`}
            onClick={() => onSelect(s.id)}
          >
            <div>
              <span className="source-type">{labels[s.type]}</span>
              <span className="source-status">{s.status}</span>
            </div>
            <strong>{s.reference}</strong>
            <span>{s.customer}</span>
            <small>
              {formatDate(s.serviceDate)} · {s.basis}
            </small>
          </button>
        ))}
      </div>
    </aside>
  );
}
