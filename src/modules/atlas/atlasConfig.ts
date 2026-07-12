export type AtlasPageId =
  | "operations-home"
  | "demand-overview"
  | "attendance-portions"
  | "menu-planning"
  | "additional-demand"
  | "requirement-review"
  | "supplier-allocation"
  | "purchase-orders"
  | "dispatch-planning"
  | "operational-qa"
  | "customers-schools"
  | "ingredients-units"
  | "dishes-recipes"
  | "suppliers-eligibility"
  | "users-access"
  | "audit-diagnostics"
  | "integration-status";

export type AtlasPage = {
  id: AtlasPageId;
  label: string;
  group: string;
  role: string;
  input: string;
  responsibility: string;
  output: string;
  handoff: string;
  primaryAction: string;
};

export const atlasPages: AtlasPage[] = [
  {
    id: "operations-home",
    label: "Operations Home",
    group: "Overview",
    role: "Điều phối vận hành",
    input: "Tín hiệu theo kỳ vận hành",
    responsibility: "Ưu tiên công việc và ngoại lệ xuyên luồng",
    output: "Điểm vào đúng trang",
    handoff: "Planning hoặc Procurement",
    primaryAction: "Xem hai hành trình mẫu",
  },
  {
    id: "demand-overview",
    label: "Demand Overview",
    group: "Planning",
    role: "Planning",
    input: "Menu, điểm danh, đơn sỉ và bổ sung",
    responsibility: "Kiểm tra tính đầy đủ nguồn nhu cầu",
    output: "Bộ nguồn sẵn sàng rà soát",
    handoff: "Attendance, Menu hoặc Additional Demand",
    primaryAction: "Rà soát nguồn thiếu",
  },
  {
    id: "attendance-portions",
    label: "Attendance and Portions",
    group: "Planning",
    role: "Planning",
    input: "Trường, ngày phục vụ, mặc định",
    responsibility: "Xác nhận cơ sở suất ăn",
    output: "Cơ sở số lượng",
    handoff: "Menu Planning",
    primaryAction: "Xác nhận suất",
  },
  {
    id: "menu-planning",
    label: "Menu Planning",
    group: "Planning",
    role: "Planning",
    input: "Trường, ngày, món ăn",
    responsibility: "Rà soát thực đơn catering",
    output: "Nhu cầu catering",
    handoff: "Requirement Review",
    primaryAction: "Kiểm tra thực đơn",
  },
  {
    id: "additional-demand",
    label: "Additional Demand",
    group: "Planning",
    role: "Planning",
    input: "Khách hàng, nguyên liệu, ngày",
    responsibility: "Ghi nhận nhu cầu trực tiếp mẫu",
    output: "Nhu cầu nguyên liệu trực tiếp",
    handoff: "Requirement Review",
    primaryAction: "Rà soát đơn sỉ/bổ sung",
  },
  {
    id: "requirement-review",
    label: "Requirement Review",
    group: "Planning",
    role: "Planning",
    input: "Yêu cầu, trace, cảnh báo và điều chỉnh mẫu",
    responsibility: "Rà soát requirement trước khi chuyển mua hàng",
    output: "Yêu cầu sẵn sàng xác thực mua hàng",
    handoff: "Supplier Allocation",
    primaryAction: "Kiểm tra ngoại lệ",
  },
  {
    id: "supplier-allocation",
    label: "Supplier Allocation",
    group: "Procurement",
    role: "Purchasing",
    input: "Yêu cầu orderable đã xác thực và eligibility",
    responsibility: "Phân bổ nhà cung cấp (prototype tách biệt)",
    output: "Kế hoạch mua hàng cân bằng",
    handoff: "Purchase Orders",
    primaryAction: "Xem hàng chưa phân bổ",
  },
  {
    id: "purchase-orders",
    label: "Purchase Orders",
    group: "Procurement",
    role: "Purchasing",
    input: "Phân bổ cân bằng và lịch sử",
    responsibility: "Rà soát phát hành PO",
    output: "Cam kết nhà cung cấp đã phát hành",
    handoff: "Dispatch Planning",
    primaryAction: "Xem bản nháp PO",
  },
  {
    id: "dispatch-planning",
    label: "Dispatch Planning",
    group: "Fulfilment",
    role: "Warehouse / Dispatch",
    input: "PO context và dữ liệu giao nhận",
    responsibility: "Chuẩn bị chứng từ dispatch",
    output: "Dispatch sẵn sàng phát hành",
    handoff: "Operational QA",
    primaryAction: "Xem kế hoạch giao",
  },
  {
    id: "operational-qa",
    label: "Operational QA",
    group: "Fulfilment",
    role: "Operations / Management",
    input: "Snapshot demand, requirement, PO, dispatch",
    responsibility: "Điều phối ngoại lệ và đối soát",
    output: "Ngoại lệ được phân tuyến",
    handoff: "Trang chịu trách nhiệm",
    primaryAction: "Xem ngoại lệ",
  },
  {
    id: "customers-schools",
    label: "Customers and Schools",
    group: "Master Data",
    role: "Master Data",
    input: "Khách hàng và trường",
    responsibility: "Duy trì danh mục đối tác",
    output: "Tham chiếu hợp lệ",
    handoff: "Planning",
    primaryAction: "Rà soát danh mục",
  },
  {
    id: "ingredients-units",
    label: "Ingredients and Units",
    group: "Master Data",
    role: "Master Data",
    input: "Nguyên liệu và đơn vị",
    responsibility: "Duy trì tham chiếu nguyên liệu",
    output: "Nguyên liệu hợp lệ",
    handoff: "Planning / Procurement",
    primaryAction: "Rà soát đơn vị",
  },
  {
    id: "dishes-recipes",
    label: "Dishes and Recipes",
    group: "Master Data",
    role: "Master Data",
    input: "Món, công thức và phiên bản",
    responsibility: "Duy trì định nghĩa công thức",
    output: "Cơ sở công thức",
    handoff: "Requirement Review",
    primaryAction: "Rà soát công thức",
  },
  {
    id: "suppliers-eligibility",
    label: "Suppliers and Eligibility",
    group: "Master Data",
    role: "Master Data",
    input: "Nhà cung cấp và eligibility",
    responsibility: "Duy trì quan hệ cung ứng",
    output: "Eligibility tham chiếu",
    handoff: "Supplier Allocation",
    primaryAction: "Rà soát eligibility",
  },
  {
    id: "users-access",
    label: "Users and Access",
    group: "Administration",
    role: "Administration",
    input: "Người dùng và vai trò",
    responsibility: "Quản lý truy cập (placeholder)",
    output: "Ma trận quyền được duyệt",
    handoff: "Backend Auth/RLS sau này",
    primaryAction: "Xem phạm vi prototype",
  },
  {
    id: "audit-diagnostics",
    label: "Audit and Diagnostics",
    group: "Administration",
    role: "Administration",
    input: "Sự kiện và ngoại lệ",
    responsibility: "Hỗ trợ chẩn đoán",
    output: "Điểm cần điều tra",
    handoff: "Trang chịu trách nhiệm",
    primaryAction: "Xem giả định audit",
  },
  {
    id: "integration-status",
    label: "Integration Status",
    group: "Administration",
    role: "Administration",
    input: "Trạng thái kết nối",
    responsibility: "Hiển thị biên giới prototype",
    output: "Nhận thức không-backend",
    handoff: "Architecture review",
    primaryAction: "Xem trạng thái",
  },
];

export const journeys = [
  {
    id: "CAT-0713-ND",
    name: "Catering · Nguyễn Du",
    context: "13/07/2026 · Canh bí đỏ · 620 suất",
    flow: [
      "Menu Planning",
      "Attendance and Portions",
      "Requirement Review",
      "Supplier Allocation",
      "Purchase Orders",
      "Dispatch Planning",
      "Operational QA",
    ],
  },
  {
    id: "WS-2026-0714",
    name: "Wholesale · Bếp ăn Minh An",
    context: "14/07/2026 · Gạo Jasmine · 250 kg",
    flow: [
      "Additional Demand",
      "Requirement Review",
      "Supplier Allocation",
      "Purchase Orders",
      "Dispatch Planning",
      "Operational QA",
    ],
  },
];
