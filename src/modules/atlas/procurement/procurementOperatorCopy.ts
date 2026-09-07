const reasonLabels: Record<string, string> = {
  STALE_VERSION: "Dữ liệu đã thay đổi; hãy tải lại trước khi tiếp tục.",
  SOURCE_CHANGED: "Nhu cầu nguồn đã thay đổi; hãy tải lại và kiểm tra phân bổ.",
  ALLOCATION_IMBALANCED: "Tổng phân bổ chưa khớp nhu cầu.",
  NO_ELIGIBLE_SUPPLIER: "Chưa có nhà cung cấp phù hợp.",
  AMBIGUOUS_SUPPLIER_PRIORITY:
    "Có nhiều nhà cung cấp cùng mức ưu tiên; cần chọn thủ công.",
  PO_DRAFT_STALE: "Đơn nháp cần cập nhật theo phân bổ hiện tại.",
  SUPPLIER_INACTIVE: "Nhà cung cấp hiện không hoạt động.",
  SUPPLIER_INELIGIBLE: "Nhà cung cấp không còn phù hợp với nguyên liệu này.",
  PO_LINES_MISSING: "Đơn mua chưa có đủ dòng hàng để phát hành.",
  PO_ALREADY_RELEASED: "Đơn đã được phát hành cho nhà cung cấp.",
  PO_REPLACEMENT_REQUIRED:
    "Đơn đã phát hành không còn khớp phân bổ hiện tại; cần phát hành đơn thay thế.",
  CANCELLATION_REQUIRED:
    "Cần xử lý hủy cam kết với nhà cung cấp trước khi tiếp tục.",
  PO_SUPERSEDED: "Đơn này đã được thay thế nhưng vẫn được giữ để tra cứu.",
};

export function isTechnicalProcurementCode(value: string) {
  return /^[A-Z][A-Z0-9_]*$/.test(value);
}

export function procurementOperatorMessage(value: string, fallback: string) {
  return (
    reasonLabels[value] ??
    (isTechnicalProcurementCode(value) ? fallback : value)
  );
}

export function procurementOperatorMessages(
  values: string[],
  fallback: string,
) {
  return Array.from(
    new Set(values.map((value) => procurementOperatorMessage(value, fallback))),
  );
}
