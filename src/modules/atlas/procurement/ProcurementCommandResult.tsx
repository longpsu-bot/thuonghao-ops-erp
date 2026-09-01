import type { ProcurementCommandOutcome } from "./schoolCateringProcurementModel";

const headings: Record<ProcurementCommandOutcome["classification"], string> = {
  SUCCESS: "Lệnh đã hoàn tất",
  REPLAY_SUCCESS: "Lệnh đã hoàn tất trước đó",
  RETRYABLE_FAILURE: "Có thể thử lại đúng lệnh này",
  STALE: "Dữ liệu đã thay đổi",
  UNKNOWN_OUTCOME: "Chưa xác định được kết quả lệnh",
  BLOCKED: "Lệnh chưa thể hoàn tất",
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
  return (
    <section
      className={`procurement-command-result ${outcome.classification.toLowerCase()}`}
      role="region"
      aria-label="Kết quả lệnh Procurement"
    >
      <header>
        <strong>{headings[outcome.classification]}</strong>
        {outcome.code && <code>{outcome.code}</code>}
      </header>
      <p>{outcome.safe_message}</p>
      {outcome.classification === "UNKNOWN_OUTCOME" && (
        <p>
          bắt buộc tải lại dữ liệu có thẩm quyền trước khi tạo ý định thay đổi
          khác.
        </p>
      )}
      {outcome.affected_labels.length > 0 && (
        <p>Đối tượng: {outcome.affected_labels.join(", ")}</p>
      )}
      {outcome.current_versions.length > 0 && (
        <p>Phiên bản hiện tại: {outcome.current_versions.join(", ")}</p>
      )}
      {outcome.warnings.length > 0 && (
        <p>Cảnh báo: {outcome.warnings.join(", ")}</p>
      )}
      {outcome.blockers.length > 0 && (
        <p>Vướng mắc: {outcome.blockers.join(", ")}</p>
      )}
      {outcome.next_action && <p>Bước tiếp theo: {outcome.next_action}</p>}
      <div>
        {onRetry && outcome.classification === "RETRYABLE_FAILURE" && (
          <button type="button" className="primary" onClick={onRetry}>
            Thử lại đúng lệnh
          </button>
        )}
        {["STALE", "UNKNOWN_OUTCOME"].includes(outcome.classification) && (
          <button type="button" className="primary" onClick={onReload}>
            Tải lại dữ liệu hiện tại
          </button>
        )}
      </div>
    </section>
  );
}
