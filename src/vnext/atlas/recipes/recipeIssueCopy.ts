// Presentation only: codes and readiness remain authoritative backend facts.
const recipeIssueLabels: Record<string, string> = {
  SUBSTITUTE_INGREDIENT_INACTIVE: "Nguyên liệu thay thế đang ngừng sử dụng.",
  TARGET_INGREDIENT_INACTIVE: "Nguyên liệu cần điều chỉnh đang ngừng sử dụng.",
  ADDED_INGREDIENT_INACTIVE: "Nguyên liệu thêm đang ngừng sử dụng.",
  UNIT_INACTIVE: "Đơn vị tính đang ngừng sử dụng.",
  SCHOOL_NOT_ACTIVE: "Trường đã chọn đang ngừng hoạt động.",
  DISH_NOT_ACTIVE: "Món đã chọn đang ngừng sử dụng.",
  SCHOOL_TYPE_NOT_ACTIVE: "Loại trường đã chọn đang ngừng sử dụng.",
  PROPOSAL_REQUIRED: "Nhập nội dung điều chỉnh để xem tác động.",
  STABLE_IDENTITY_REQUIRED: "Chọn lại thành phần cần điều chỉnh.",
  SCOPE_ACTION_INVALID: "Hành động chưa phù hợp với phạm vi đã chọn.",
  TYPED_SCOPE_INVALID: "Chọn phạm vi và loại trường hợp lệ.",
  EFFECTIVE_PERIOD_INVALID: "Kiểm tra ngày bắt đầu và ngày kết thúc áp dụng.",
  PROPOSAL_NOT_EFFECTIVE_ON_PREVIEW_DATE:
    "Lệnh chưa áp dụng vào ngày đang xem.",
  REASON_REQUIRED: "Nhập lý do điều chỉnh.",
  REPLACE_PAYLOAD_INVALID: "Kiểm tra thành phần và nguyên liệu thay thế.",
  QUANTITY_PAYLOAD_INVALID: "Kiểm tra định lượng và đơn vị tính mới.",
  ADD_PAYLOAD_INVALID:
    "Kiểm tra nguyên liệu, định lượng và đơn vị tính cần thêm.",
  REMOVE_PAYLOAD_INVALID: "Chọn lại thành phần cần bỏ.",
  RECIPE_LINE_SCOPE_MISMATCH:
    "Thành phần không thuộc phạm vi công thức đã chọn.",
  SELF_REPLACEMENT: "Chọn nguyên liệu thay thế khác nguyên liệu hiện tại.",
  OVERLAPPING_ACTIVE_RULE: "Có lệnh khác cùng áp dụng trong khoảng ngày này.",
  REPLACEMENT_CYCLE:
    "Các lệnh thay thế đang tạo vòng lặp. Kiểm tra lại các lệnh liên quan.",
  TARGET_NOT_APPLICABLE: "Thành phần không áp dụng trong công thức đang xem.",
  AMBIGUOUS_SCHOOL_ADJUSTMENT:
    "Có nhiều lệnh cùng áp dụng cho trường này. Kiểm tra các lệnh liên quan.",
  DUPLICATE_EFFECTIVE_INGREDIENT:
    "Nguyên liệu bị trùng trong công thức áp dụng.",
  RECIPE_SELECTION_CONTEXT_REQUIRED: "Chọn món để xem công thức áp dụng.",
  CANONICAL_SCHOOL_TYPE_REQUIRED: "Chọn loại trường hợp lệ để xem công thức.",
  TYPED_RECIPE_ROOT_MISSING: "Chưa có công thức cho loại trường này.",
  RECIPE_SELECTION_BLOCKED: "Chưa có công thức sẵn sàng cho loại trường này.",
  AMBIGUOUS_SCHOOL_TYPE_RECIPE:
    "Có nhiều công thức cùng áp dụng cho loại trường này. Liên hệ người quản lý danh mục.",
  AMBIGUOUS_GENERAL_RECIPE:
    "Có nhiều công thức cùng áp dụng. Liên hệ người quản lý danh mục.",
  HISTORICAL_RECIPE_VERSION_NOT_FOUND:
    "Không tìm thấy công thức trong lịch sử đã chọn.",
};

export function recipeIssueCopy(issue: { code: string; message: string }) {
  return (
    recipeIssueLabels[issue.code] ??
    (/[^\u0000-\u007f]/.test(issue.message)
      ? issue.message
      : "Chưa thể áp dụng công thức. Kiểm tra dữ liệu hoặc liên hệ người quản lý.")
  );
}
