// Presentation only: catalogue eligibility and save blockers remain backend-owned.
const pantryIssueLabels: Record<string, string> = {
  PURPOSE_CATALOG_EMPTY:
    "Chưa có phân loại nhập trực tiếp. Liên hệ người quản lý danh mục.",
  PURPOSE_REQUIRED:
    "Chưa xác định phân loại nhập trực tiếp. Tải lại dữ liệu hoặc liên hệ người quản lý.",
  INVALID_PURPOSE_ID:
    "Phân loại nhập trực tiếp không hợp lệ. Tải lại dữ liệu hoặc liên hệ người quản lý.",
  UNKNOWN_PURPOSE:
    "Không tìm thấy phân loại nhập trực tiếp. Tải lại dữ liệu hoặc liên hệ người quản lý.",
  INACTIVE_PURPOSE:
    "Phân loại nhập trực tiếp đã ngừng dùng. Liên hệ người quản lý danh mục.",
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
