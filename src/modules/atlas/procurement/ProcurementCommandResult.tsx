import type { ProcurementCommandOutcome } from "./schoolCateringProcurementModel";
import {
  isTechnicalProcurementCode,
  procurementOperatorMessages,
} from "./procurementOperatorCopy";

const headings: Record<ProcurementCommandOutcome["classification"], string> = {
  SUCCESS: "Đã hoàn tất",
  REPLAY_SUCCESS: "Thao tác đã hoàn tất trước đó",
  RETRYABLE_FAILURE: "Chưa thể hoàn tất thao tác",
  STALE: "Dữ liệu đã thay đổi",
  UNKNOWN_OUTCOME: "Chưa xác nhận kết quả",
  BLOCKED: "Chưa thể hoàn tất",
};

export function ProcurementCommandResult({
  outcome,
  onReload,
  onRetry,
}: {
  outcome: ProcurementCommandOutcome;
  onReload: () => void;
  onRetry?: () => void;
}) {
  const warnings = procurementOperatorMessages(
    outcome.warnings,
    "Có cảnh báo cần kiểm tra trước khi tiếp tục.",
  );
  const blockers = procurementOperatorMessages(
    outcome.blockers,
    "Thao tác chưa thể tiếp tục; hãy tải lại và kiểm tra dữ liệu hiện tại.",
  );
  const technicalCodes = Array.from(
    new Set(
      [outcome.code, ...outcome.warnings, ...outcome.blockers].filter(
        (value): value is string =>
          value !== null && isTechnicalProcurementCode(value),
      ),
    ),
  );
  const hasTechnicalDetails =
    technicalCodes.length > 0 || outcome.current_versions.length > 0;

  return (
    <section
      className={`procurement-command-result ${outcome.classification.toLowerCase()}`}
      role="region"
      aria-label="Kết quả lệnh Procurement"
    >
      <header>
        <strong>{headings[outcome.classification]}</strong>
      </header>
      <p>{outcome.safe_message}</p>
      {outcome.classification === "UNKNOWN_OUTCOME" && (
        <p>Hãy tải lại dữ liệu hiện tại trước khi tiếp tục thao tác.</p>
      )}
      {outcome.affected_labels.length > 0 && (
        <p>Đối tượng: {outcome.affected_labels.join(", ")}</p>
      )}
      {warnings.length > 0 && <p>Cảnh báo: {warnings.join(", ")}</p>}
      {blockers.length > 0 && <p>Vướng mắc: {blockers.join(", ")}</p>}
      {outcome.next_action && <p>Bước tiếp theo: {outcome.next_action}</p>}
      <div>
        {onRetry && outcome.classification === "RETRYABLE_FAILURE" && (
          <button type="button" className="primary" onClick={onRetry}>
            Thử lại thao tác
          </button>
        )}
        {["STALE", "UNKNOWN_OUTCOME"].includes(outcome.classification) && (
          <button type="button" className="primary" onClick={onReload}>
            Tải lại dữ liệu hiện tại
          </button>
        )}
      </div>
      {hasTechnicalDetails && (
        <details className="procurement-technical-details">
          <summary>Chi tiết kỹ thuật</summary>
          {technicalCodes.length > 0 && (
            <p>
              Mã chẩn đoán:{" "}
              {technicalCodes.map((code) => (
                <code key={code}>{code}</code>
              ))}
            </p>
          )}
          {outcome.current_versions.length > 0 && (
            <p>Phiên bản hiện tại: {outcome.current_versions.join(", ")}</p>
          )}
        </details>
      )}
    </section>
  );
}
