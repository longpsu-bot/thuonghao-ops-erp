import { Fragment } from "react";
import type { LocalLineState, RequirementLine, ViewMode } from "../types";
const formatDate = (value: string) => `${value.slice(8, 10)}/${value.slice(5, 7)}/${value.slice(0, 4)}`;
const qty = (n: number) =>
  new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 2 }).format(n);
const labels: Record<string, string> = {
  CATERING_MENU: "Thực đơn",
  WHOLESALE_ORDER: "Bán sỉ",
  PANTRY_ADD: "Bổ sung",
  MANUAL_DEMAND: "Thủ công",
  CORRECTION: "Điều chỉnh",
  ASSIGNED: "Đã gán",
  MISSING: "Thiếu NCC",
  SUGGESTED: "Đề xuất",
  CONFLICT: "Xung đột",
  READY: "Sẵn sàng",
  NEEDS_REVIEW: "Cần duyệt",
  BLOCKED: "Đang chặn",
  OK: "Bình thường",
  INFO: "Thông tin",
  WARNING: "Cần chú ý",
  BLOCKING: "Đang chặn",
};

export function RequirementTable({
  lines,
  selected,
  onSelect,
  states,
  viewMode,
}: {
  lines: RequirementLine[];
  selected?: string;
  onSelect: (id: string) => void;
  states: Record<string, LocalLineState>;
  viewMode: ViewMode;
}) {
  const groupKey = (line: RequirementLine) => {
    if (viewMode === "CUSTOMER") return line.customer;
    if (viewMode === "SOURCE") return labels[line.sourceType];
    if (viewMode === "SUPPLIER") return line.supplierName ?? "Chưa có nhà cung cấp";
    return formatDate(line.serviceDate);
  };
  const groups = lines.reduce<Record<string, RequirementLine[]>>((result, line) => {
    const key = groupKey(line);
    (result[key] ??= []).push(line);
    return result;
  }, {});
  return (
    <section className="table-section">
      <div className="section-heading">
        <div>
          <span className="eyebrow">YÊU CẦU NGUYÊN LIỆU</span>
          <h2>
            Kiểm tra yêu cầu <small>{lines.length} dòng</small>
          </h2>
        </div>
        <span className="legend">
          <i className="dot blocking" /> Chặn <i className="dot warning" /> Cảnh
          báo
        </span>
      </div>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th>Ngày</th>
              <th>Trường / khách</th>
              <th>Nguồn</th>
              <th>Nguyên liệu</th>
              <th>Chế độ tính</th>
              <th className="num">Thô</th>
              <th className="num">Sau điều chỉnh</th>
              <th className="num">Đặt hàng</th>
              <th>ĐVT</th>
              <th>Cảnh báo</th>
              <th>Nhà cung cấp</th>
              <th>Sẵn sàng</th>
              <th>Truy vết</th>
            </tr>
          </thead>
          <tbody>
            {Object.entries(groups).map(([group, groupLines]) => (
              <Fragment key={group}>
                <tr className="group-row">
                  <td colSpan={13}>
                    <strong>{group}</strong>
                    <span>{groupLines.length} dòng · {groupLines.filter((x) => x.readiness === "READY").length} sẵn sàng · {groupLines.filter((x) => x.readiness === "BLOCKED").length} đang chặn</span>
                  </td>
                </tr>
                {groupLines.map((x) => {
              const local = states[x.id];
              return (
                <tr
                  key={x.id}
                  className={`${selected === x.id ? "selected-row" : ""} severity-${x.severity.toLowerCase()}`}
                  onClick={() => onSelect(x.id)}
                >
                  <td>
                    {formatDate(x.serviceDate)}
                  </td>
                  <td>
                    <strong>{x.customer}</strong>
                    <small>{x.sourceReference}</small>
                  </td>
                  <td>{labels[x.sourceType]}</td>
                  <td>
                    <strong>{x.ingredient}</strong>
                    <small>{x.ingredientGroup}</small>
                  </td>
                  <td>{x.calculationMode}</td>
                  <td className="num">{qty(x.rawQuantity)}</td>
                  <td className="num adjusted">{qty(x.adjustedQuantity)}</td>
                  <td className="num orderable">{qty(x.orderableQuantity)}</td>
                  <td>{x.unit}</td>
                  <td>
                    <span className={`badge ${x.severity.toLowerCase()}`}>
                      {labels[x.severity]}
                    </span>
                    {local?.flagged && (
                      <small className="flagged">Đã gắn cờ</small>
                    )}
                  </td>
                  <td>
                    <span
                      className={`badge supplier-${x.supplierStatus.toLowerCase()}`}
                    >
                      {labels[x.supplierStatus]}
                    </span>
                    <small>{x.supplierName}</small>
                  </td>
                  <td>
                    <span
                      className={`badge ready-${x.readiness.toLowerCase()}`}
                    >
                      {labels[x.readiness]}
                    </span>
                    {local?.locallyReady && <small>Nháp: sẵn sàng</small>}
                    {local?.reviewed && <small>✓ Đã xem</small>}
                  </td>
                  <td>
                    <button
                      className="trace-button"
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelect(x.id);
                      }}
                    >
                      Chi tiết →
                    </button>
                  </td>
                </tr>
              );
                })}
              </Fragment>
            ))}
          </tbody>
        </table>
        {!lines.length && (
          <div className="empty">Không có dữ liệu phù hợp bộ lọc.</div>
        )}
      </div>
    </section>
  );
}

export function RequirementDetail({
  line,
  state,
  onAction,
  onReviewNoteChange,
  onClose,
}: {
  line: RequirementLine;
  state: LocalLineState;
  onAction: (key: keyof LocalLineState) => void;
  onReviewNoteChange: (note: string) => void;
  onClose: () => void;
}) {
  return (
    <aside className="drawer" aria-label="Chi tiết yêu cầu">
      <div className="drawer-head">
        <div>
          <span className="eyebrow">CHI TIẾT · PROTOTYPE</span>
          <h2>{line.ingredient}</h2>
          <p>
            {line.customer} · {formatDate(line.serviceDate)}
          </p>
        </div>
        <button className="icon-button" aria-label="Đóng" onClick={onClose}>
          ×
        </button>
      </div>
      <div className="drawer-body">
        <section>
          <h3>Nguồn & cơ sở</h3>
          <dl>
            <div>
              <dt>Tham chiếu</dt>
              <dd>{line.sourceReference}</dd>
            </div>
            <div>
              <dt>Cơ sở</dt>
              <dd>{line.sourceBasis}</dd>
            </div>
            <div>
              <dt>Chế độ</dt>
              <dd>{line.calculationMode}</dd>
            </div>
          </dl>
        </section>
        <section>
          <h3>
            Truy vết số lượng{" "}
            <span className="prototype-label">DỮ LIỆU MẪU</span>
          </h3>
          <ol className="trace-list">
            {line.trace.map((s, i) => (
              <li key={`${s.label}-${i}`}>
                <span>{i + 1}</span>
                <div>
                  <strong>{s.label}</strong>
                  <b>{s.value}</b>
                  <small>{s.note}</small>
                </div>
              </li>
            ))}
          </ol>
        </section>
        <section>
          <h3>Điều chỉnh</h3>
          <p>{line.adjustment}</p>
          {line.hasSubstitution && (
            <span className="badge warning">Có thay thế</span>
          )}
          {line.hasOverride && <span className="badge info">Có override</span>}
        </section>
        <section
          className={
            line.severity === "BLOCKING"
              ? "callout blocking-callout"
              : "callout"
          }
        >
          <h3>Cảnh báo · {labels[line.severity]}</h3>
          <strong>{line.warningCode ?? "Không có mã cảnh báo"}</strong>
          <p>{line.warningExplanation}</p>
        </section>
        <section>
          <h3>Xem trước gán nhà cung cấp</h3>
          <p>
            <strong>{labels[line.supplierStatus]}</strong>
            {line.supplierName ? ` · ${line.supplierName}` : ""}
          </p>
          <small>Chỉ là dữ liệu fixture; UI không tự chọn nhà cung cấp.</small>
        </section>
        <section className="review-note">
          <h3>Ghi chú rà soát cục bộ</h3>
          <textarea
            value={state.reviewNote}
            onChange={(event) => onReviewNoteChange(event.target.value)}
            placeholder="Ghi nhận điều cần kiểm tra hoặc bàn giao…"
          />
          <small>Chỉ lưu trong bộ nhớ trình duyệt; tải lại trang sẽ xóa ghi chú.</small>
        </section>
        <section>
          <h3>Câu hỏi chưa giải quyết</h3>
          <ul>
            {line.openQuestions.map((q) => (
              <li key={q}>{q}</li>
            ))}
          </ul>
        </section>
      </div>
      <div className="action-bar">
        <span>Mọi thao tác chỉ lưu trong bộ nhớ trình duyệt.</span>
        <div>
          <button onClick={() => onAction("reviewed")}>
            {state.reviewed ? "Bỏ đánh dấu" : "Đánh dấu đã xem"}
          </button>
          <button onClick={() => onAction("flagged")}>
            {state.flagged ? "Bỏ cờ" : "Gắn cờ vấn đề"}
          </button>
          <button onClick={() => onAction("substitutionDraft")}>
            {state.substitutionDraft
              ? "Đã tạo nháp thay thế"
              : "Tạo nháp thay thế"}
          </button>
          <button onClick={() => onAction("overrideDraft")}>
            {state.overrideDraft ? "Đã tạo nháp override" : "Tạo nháp override"}
          </button>
          <button
            disabled={line.readiness === "BLOCKED"}
            onClick={() => onAction("locallyReady")}
          >
            {state.locallyReady ? "Bỏ nháp sẵn sàng" : "Tạo nháp sẵn sàng"}
          </button>
        </div>
      </div>
    </aside>
  );
}
