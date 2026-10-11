// Presentation only: catalogue eligibility and save blockers remain backend-owned.
const pantryIssueLabels: Record<string, string> = {
  PURPOSE_CATALOG_EMPTY:
    "Chưa có mục đích đặt hàng đang dùng. Liên hệ người quản lý danh mục.",
  PURPOSE_REQUIRED: "Chọn mục đích đặt hàng.",
  INVALID_PURPOSE_ID: "Mục đích đặt hàng không hợp lệ. Hãy chọn lại.",
  UNKNOWN_PURPOSE: "Không tìm thấy mục đích đặt hàng. Hãy chọn lại.",
  INACTIVE_PURPOSE: "Mục đích đặt hàng đã ngừng dùng. Hãy chọn lại.",
  DEFAULT_DELIVERY_LOCATION_MISSING:
    "Trường chưa có điểm giao mặc định. Liên hệ người quản lý danh mục.",
  DEFAULT_DELIVERY_LOCATION_INACTIVE:
    "Điểm giao mặc định đã ngừng dùng. Liên hệ người quản lý danh mục.",
  PURCHASE_UNIT_MISSING:
    "Nguyên liệu chưa có đơn vị mua. Liên hệ người quản lý danh mục.",
  PURCHASE_UNIT_INACTIVE:
    "Đơn vị mua đã ngừng dùng. Liên hệ người quản lý danh mục.",
};

export function pantryIssueCopy(issue: { code: string; message: string }) {
  return (
    pantryIssueLabels[issue.code] ??
    (/[^\u0000-\u007f]/.test(issue.message)
      ? issue.message
      : "Kiểm tra dữ liệu Hàng đặt riêng hoặc liên hệ người quản lý.")
  );
}
