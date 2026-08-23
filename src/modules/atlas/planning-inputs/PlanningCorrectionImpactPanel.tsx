import type {
  PlanningCorrectionChain,
  PlanningCorrectionImpact,
} from "./planningCorrectionApi";
import { viDate } from "./planningInputsModel";

type Props = {
  impact: PlanningCorrectionImpact | null;
  busy: boolean;
  onPrepare: (chain: PlanningCorrectionChain) => void;
};

export function PlanningCorrectionImpactPanel({
  impact,
  busy,
  onPrepare,
}: Props) {
  if (!impact) return null;
  if (!impact.material_change)
    return (
      <p className="operator-notice">
        Dữ liệu nghiệp vụ không thay đổi; không có ngày phục vụ bị ảnh hưởng.
      </p>
    );
  return (
    <section
      className="planning-correction-impact"
      aria-label="Ảnh hưởng hiệu chỉnh"
    >
      <h3>Ảnh hưởng trước khi lưu</h3>
      <p>
        Atlas xác định {impact.affected_service_dates.length} ngày phục vụ bị
        ảnh hưởng từ dữ liệu nguồn chuẩn hóa.
      </p>
      <ul>
        {impact.date_impacts.map((dateImpact) => (
          <li key={dateImpact.service_date}>
            <strong>{viDate(dateImpact.service_date)}</strong>:{" "}
            {dateImpact.operator_message}
            {dateImpact.chains
              .filter(
                (chain) =>
                  chain.confirmed_need_batch_id &&
                  (dateImpact.correction_policy ===
                    "PLANNING_RELEASE_CORRECTION_REQUIRED" ||
                    dateImpact.correction_policy ===
                      "LEGACY_RANGE_CORRECTION_REQUIRED"),
              )
              .map((chain) => (
                <div key={chain.need_generation_run_id}>
                  {chain.is_legacy_range && (
                    <span>
                      Khoảng cũ {viDate(chain.period_start)}–
                      {viDate(chain.period_end)}. Cam kết{" "}
                      {chain.confirmed_need_status === "DRAFT_REVIEW" ||
                      chain.confirmed_need_status === "REOPENED"
                        ? "đang rà soát"
                        : "đã phát hành"}
                      .{" "}
                    </span>
                  )}
                  <button
                    type="button"
                    className="secondary"
                    disabled={busy}
                    onClick={() => onPrepare(chain)}
                  >
                    {chain.confirmed_need_status === "DRAFT_REVIEW" ||
                    chain.confirmed_need_status === "REOPENED"
                      ? "Đưa Nhu cầu cũ về lịch sử"
                      : "Mở lại cam kết Kế hoạch"}
                  </button>
                </div>
              ))}
            <details>
              <summary>Chi tiết hỗ trợ</summary>
              <code>{dateImpact.correction_policy}</code>
            </details>
          </li>
        ))}
      </ul>
      {!impact.save_allowed && (
        <p className="operator-notice warning">
          Chưa thể lưu nguồn cho đến khi hoàn tất hành động được yêu cầu.
        </p>
      )}
    </section>
  );
}
