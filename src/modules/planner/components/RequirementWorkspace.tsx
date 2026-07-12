import { formatDateVi } from "../date";
import type { LocalLineState, RequirementLine } from "../types";

const qty = (value: number) =>
  new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 2 }).format(value);

const sourceLabels: Record<string, string> = {
  CATERING_MENU: "Thực đơn",
  WHOLESALE_ORDER: "Bán sỉ",
  PANTRY_ADD: "Bổ sung kho",
  MANUAL_DEMAND: "Thủ công",
  CORRECTION: "Điều chỉnh",
};

const severityLabels: Record<string, string> = {
  OK: "Bình thường",
  INFO: "Thông tin",
  WARNING: "Cần kiểm tra",
  BLOCKING: "Đang chặn",
};

const supplierLabels: Record<string, string> = {
  ASSIGNED: "Đã gán NCC",
  MISSING: "Thiếu NCC",
  SUGGESTED: "NCC đề xuất",
  CONFLICT: "Xung đột NCC",
};

const readinessLabels: Record<string, string> = {
  READY: "Sẵn sàng",
  NEEDS_REVIEW: "Cần xử lý",
  BLOCKED: "Bị chặn",
};

const blockedReasons: Record<string, string> = {
  MISSING_SUPPLIER: "Thiếu nhà cung cấp",
  INACTIVE_INGREDIENT: "Nguyên liệu ngưng hoạt động",
};

export type RequirementGroup = {
  id: string;
  title: string;
  summary: string;
  lines: RequirementLine[];
};

export function RequirementTable({
  groups,
  selected,
  onSelect,
  states,
}: {
  groups: RequirementGroup[];
  selected?: string;
  onSelect: (id: string) => void;
  states: Record<string, LocalLineState>;
}) {
  const count = groups.reduce((total, group) => total + group.lines.length, 0);
  return (
    <section className="table-section">
      <div className="section-heading">
        <div>
          <span className="eyebrow">YÊU CẦU NGUYÊN LIỆU</span>
          <h2>
            Kiểm tra yêu cầu <small>{count} dòng</small>
          </h2>
        </div>
        <span className="legend">
          <i className="dot blocking" /> Chặn <i className="dot warning" /> Cần
          kiểm tra
        </span>
      </div>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th className="sticky-col sticky-date">Ngày</th>
              <th className="sticky-col sticky-customer">Trường / khách</th>
              <th className="sticky-col sticky-ingredient">Nguyên liệu</th>
              <th>Nguồn</th>
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
            {groups.map((group) => (
              <GroupRows
                key={group.id}
                group={group}
                selected={selected}
                onSelect={onSelect}
                states={states}
              />
            ))}
          </tbody>
        </table>
        {!groups.length && (
          <div className="empty">Không có dữ liệu phù hợp bộ lọc.</div>
        )}
      </div>
    </section>
  );
}

function GroupRows({
  group,
  selected,
  onSelect,
  states,
}: {
  group: RequirementGroup;
  selected?: string;
  onSelect: (id: string) => void;
  states: Record<string, LocalLineState>;
}) {
  return (
    <>
      <tr className="group-row">
        <td colSpan={13}>
          <strong>{group.title}</strong>
          <span>{group.summary}</span>
        </td>
      </tr>
      {group.lines.map((line) => {
        const local = states[line.id];
        const blockedReason =
          line.readiness === "BLOCKED"
            ? (blockedReasons[line.warningCode ?? ""] ??
              line.warningExplanation)
            : undefined;
        return (
          <tr
            key={line.id}
            className={`${selected === line.id ? "selected-row" : ""} severity-${line.severity.toLowerCase()}`}
            onClick={() => onSelect(line.id)}
          >
            <td className="sticky-col sticky-date">
              {formatDateVi(line.serviceDate)}
            </td>
            <td className="sticky-col sticky-customer">
              <strong>{line.customer}</strong>
              <small>{line.sourceReference}</small>
            </td>
            <td className="sticky-col sticky-ingredient">
              <strong>{line.ingredient}</strong>
              <small>{line.ingredientGroup}</small>
            </td>
            <td>{sourceLabels[line.sourceType]}</td>
            <td>{line.calculationMode}</td>
            <td className="num">{qty(line.rawQuantity)}</td>
            <td className="num adjusted">{qty(line.adjustedQuantity)}</td>
            <td className="num orderable">{qty(line.orderableQuantity)}</td>
            <td>{line.unit}</td>
            <td>
              <span className={`badge ${line.severity.toLowerCase()}`}>
                {severityLabels[line.severity]}
              </span>
              {blockedReason && (
                <small className="blocked-reason">
                  Bị chặn: {blockedReason}
                </small>
              )}
              {local?.flagged && <small className="flagged">Đã gắn cờ</small>}
            </td>
            <td>
              <span
                className={`badge supplier-${line.supplierStatus.toLowerCase()}`}
              >
                {supplierLabels[line.supplierStatus]}
              </span>
              <small>{line.supplierName}</small>
            </td>
            <td>
              <span className={`badge ready-${line.readiness.toLowerCase()}`}>
                {readinessLabels[line.readiness]}
              </span>
              {local?.locallyReady && <small>Nháp: sẵn sàng</small>}
              {local?.reviewed && <small>✓ Đã xem</small>}
            </td>
            <td>
              <button
                className="trace-button"
                onClick={(event) => {
                  event.stopPropagation();
                  onSelect(line.id);
                }}
              >
                Chi tiết →
              </button>
            </td>
          </tr>
        );
      })}
    </>
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
  onAction: (key: Exclude<keyof LocalLineState, "reviewNote">) => void;
  onReviewNoteChange: (value: string) => void;
  onClose: () => void;
}) {
  return (
    <aside className="drawer" aria-label="Chi tiết yêu cầu">
      <div className="drawer-head">
        <div>
          <span className="eyebrow">CHI TIẾT · PROTOTYPE</span>
          <h2>{line.ingredient}</h2>
          <p>
            {line.customer} · {formatDateVi(line.serviceDate)}
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
            {line.trace.map((step, index) => (
              <li key={`${step.label}-${index}`}>
                <span>{index + 1}</span>
                <div>
                  <strong>{step.label}</strong>
                  <b>{step.value}</b>
                  <small>{step.note}</small>
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
          <h3>Cảnh báo · {severityLabels[line.severity]}</h3>
          <strong>{line.warningCode ?? "Không có mã cảnh báo"}</strong>
          <p>{line.warningExplanation}</p>
        </section>
        <section>
          <h3>Xem trước gán nhà cung cấp</h3>
          <p>
            <strong>{supplierLabels[line.supplierStatus]}</strong>
            {line.supplierName ? ` · ${line.supplierName}` : ""}
          </p>
          <small>Chỉ là dữ liệu fixture; UI không tự chọn nhà cung cấp.</small>
        </section>
        <section>
          <h3>Ghi chú rà soát</h3>
          <textarea
            aria-label="Ghi chú rà soát"
            value={state.reviewNote}
            placeholder="Ghi chú này chỉ lưu cục bộ và sẽ mất khi tải lại trang."
            onChange={(event) => onReviewNoteChange(event.target.value)}
          />
        </section>
        <section>
          <h3>Câu hỏi chưa giải quyết</h3>
          <ul>
            {line.openQuestions.map((question) => (
              <li key={question}>{question}</li>
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
