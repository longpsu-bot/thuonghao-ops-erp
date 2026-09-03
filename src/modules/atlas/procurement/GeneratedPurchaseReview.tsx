import { useEffect, useRef, useState } from "react";
import {
  generatedPurchaseReviewFromResult,
  generatedPurchaseReviewRequest,
  type GeneratedPurchaseReview as ReviewData,
  type PurchaseReviewApi,
} from "./purchaseReviewApi";
import {
  downloadGeneratedPurchaseReview,
  generatedReviewWarning,
  generatedSupplierLabel,
} from "./generatedPurchaseReviewExport";

export function GeneratedPurchaseReview({
  api,
  authSubject,
  serviceDate,
  onExport = downloadGeneratedPurchaseReview,
}: {
  api?: PurchaseReviewApi;
  authSubject: string | null;
  serviceDate: string;
  onExport?: (review: ReviewData) => void | Promise<void>;
}) {
  const [review, setReview] = useState<ReviewData | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const intent = useRef(0);
  const trigger = useRef<HTMLButtonElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    if (review?.rows.length) heading.current?.focus();
  }, [review]);
  useEffect(() => {
    intent.current += 1;
    setReview(null);
    setMessage(null);
    setBusy(false);
    return () => {
      intent.current += 1;
    };
  }, [serviceDate, api, authSubject]);
  const read = async () => {
    if (!api || !authSubject || !serviceDate) return;
    const current = ++intent.current;
    setBusy(true);
    setMessage(null);
    setReview(null);
    const result = await api.getGeneratedReview(
      generatedPurchaseReviewRequest(
        authSubject,
        crypto.randomUUID(),
        serviceDate,
      ),
    );
    if (current !== intent.current) return;
    const next = generatedPurchaseReviewFromResult(result);
    if (next && next.service_date === serviceDate) {
      setReview(next);
      if (!next.rows.length)
        setMessage("Chưa có nhu cầu dự kiến hiện hành cho ngày này.");
    } else
      setMessage(
        result.kind === "backend_error"
          ? result.error.safe_message
          : "Chưa tải được bản dự kiến hiện hành. Hãy tải lại.",
      );
    setBusy(false);
  };
  const exportXlsx = async () => {
    if (
      !review ||
      review.service_date !== serviceDate ||
      review.blockers.length
    )
      return;
    setBusy(true);
    const current = intent.current;
    try {
      await onExport(review);
    } catch {
      if (current === intent.current)
        setMessage(
          "Chưa tạo được XLSX dự kiến. Dữ liệu vận hành không thay đổi.",
        );
    } finally {
      if (current === intent.current) setBusy(false);
    }
  };
  return (
    <section
      className="generated-purchase-review"
      aria-label="Bản rà soát nhu cầu dự kiến"
    >
      <button
        ref={trigger}
        type="button"
        className="secondary"
        disabled={!api || !authSubject || !serviceDate || busy}
        onClick={() => void read()}
      >
        In bản dự kiến
      </button>
      {message && <p role="status">{message}</p>}
      {review &&
        review.service_date === serviceDate &&
        review.rows.length > 0 && (
          <div className="generated-purchase-review-sheet">
            <header>
              <div>
                <h3 ref={heading} tabIndex={-1}>
                  {review.document_label}
                </h3>
                <p>
                  Ngày phục vụ: {serviceDate.split("-").reverse().join("/")} ·
                  Chỉ dùng để rà soát trên giấy.
                </p>
              </div>
              <button
                type="button"
                className="secondary"
                disabled={busy || review.blockers.length > 0}
                onClick={() => void exportXlsx()}
              >
                Tải XLSX dự kiến
              </button>
              <button
                type="button"
                className="secondary"
                onClick={() => {
                  setReview(null);
                  trigger.current?.focus();
                }}
              >
                Đóng bản dự kiến
              </button>
            </header>
            <p>
              Đề xuất NCC chưa được lưu thành phân bổ. Bản này không phải đơn
              mua chính thức.
            </p>
            {review.blockers.map((message) => (
              <p key={message} role="status">
                {message}
              </p>
            ))}
            {review.warnings.map((message) => (
              <p key={message} role="status">
                {generatedReviewWarning(message)}
              </p>
            ))}
            <div className="generated-purchase-review-rows">
              {[...review.rows]
                .sort((a, b) =>
                  generatedSupplierLabel(a).localeCompare(
                    generatedSupplierLabel(b),
                    "vi",
                  ),
                )
                .map((row) => (
                  <article
                    key={`${row.school_id}:${row.delivery_location_id}:${row.ingredient_id}:${row.unit_id}`}
                  >
                    <strong>{generatedSupplierLabel(row)} · đề xuất</strong>
                    <span>
                      {row.school_name} · {row.location_name}
                    </span>
                    <span>{row.ingredient_name}</span>
                    <strong>
                      {row.family_quantity} {row.unit_code}
                    </strong>
                    {row.warnings.map((code) => (
                      <small key={code}>{generatedReviewWarning(code)}</small>
                    ))}
                  </article>
                ))}
            </div>
          </div>
        )}
    </section>
  );
}
