import { useEffect, useState } from "react";
import { formatDateVi, parseDateVi } from "../date";

type Props = {
  from: string;
  to: string;
  onChange: (from: string, to: string) => void;
};

export function DateRangePickerVi({ from, to, onChange }: Props) {
  const [draftFrom, setDraftFrom] = useState(formatDateVi(from));
  const [draftTo, setDraftTo] = useState(formatDateVi(to));

  useEffect(() => setDraftFrom(formatDateVi(from)), [from]);
  useEffect(() => setDraftTo(formatDateVi(to)), [to]);

  const apply = () => {
    const nextFrom = draftFrom ? parseDateVi(draftFrom) : "";
    const nextTo = draftTo ? parseDateVi(draftTo) : "";
    if ((draftFrom && !nextFrom) || (draftTo && !nextTo)) return;
    onChange(nextFrom ?? "", nextTo ?? "");
  };

  const today = () => {
    const iso = new Date().toISOString().slice(0, 10);
    setDraftFrom(formatDateVi(iso));
    setDraftTo(formatDateVi(iso));
    onChange(iso, iso);
  };

  const clear = () => {
    setDraftFrom("");
    setDraftTo("");
    onChange("", "");
  };

  return (
    <div className="date-range-vi" aria-label="Khoảng ngày lập kế hoạch">
      <label>
        Từ ngày
        <input
          aria-label="Từ ngày"
          inputMode="numeric"
          placeholder="dd/mm/yyyy"
          value={draftFrom}
          onChange={(event) => setDraftFrom(event.target.value)}
          onBlur={apply}
        />
      </label>
      <label>
        Đến ngày
        <input
          aria-label="Đến ngày"
          inputMode="numeric"
          placeholder="dd/mm/yyyy"
          value={draftTo}
          onChange={(event) => setDraftTo(event.target.value)}
          onBlur={apply}
        />
      </label>
      <div className="date-range-actions">
        <button type="button" onClick={today}>
          Hôm nay
        </button>
        <button type="button" onClick={clear}>
          Xóa
        </button>
        <button type="button" className="apply-date" onClick={apply}>
          Áp dụng
        </button>
      </div>
    </div>
  );
}
