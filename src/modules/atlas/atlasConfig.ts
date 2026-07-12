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

export const atlasGroups = [
  "Tổng quan",
  "Lập kế hoạch",
  "Mua hàng",
  "Thực hiện",
  "Dữ liệu danh mục",
  "Quản trị",
] as const;

export type AtlasGroup = (typeof atlasGroups)[number];

export type AtlasPage = {
  id: AtlasPageId;
  label: string;
  group: AtlasGroup;
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
    label: "Trang điều hành",
    group: "Tổng quan",
    role: "Điều phối vận hành",
    input: "Tín hiệu theo kỳ vận hành",
    responsibility: "Ưu tiên công việc và ngoại lệ xuyên luồng",
    output: "Điểm vào đúng trang",
    handoff: "Lập kế hoạch hoặc Mua hàng",
    primaryAction: "Xem hai hành trình mẫu",
  },
  {
    id: "demand-overview",
    label: "Tổng quan nhu cầu",
    group: "Lập kế hoạch",
    role: "Nhân viên lập kế hoạch",
    input: "Thực đơn, điểm danh, đơn sỉ và bổ sung",
    responsibility: "Kiểm tra tính đầy đủ nguồn nhu cầu",
    output: "Bộ nguồn sẵn sàng rà soát",
    handoff: "Điểm danh, Thực đơn hoặc Nhu cầu bổ sung",
    primaryAction: "Rà soát nguồn thiếu",
  },
  {
    id: "attendance-portions",
    label: "Điểm danh và suất ăn",
    group: "Lập kế hoạch",
    role: "Nhân viên lập kế hoạch",
    input: "Trường, ngày phục vụ, mặc định",
    responsibility: "Xác nhận cơ sở suất ăn",
    output: "Cơ sở số lượng",
    handoff: "Lập thực đơn",
    primaryAction: "Xác nhận suất",
  },
  {
    id: "menu-planning",
    label: "Lập thực đơn",
    group: "Lập kế hoạch",
    role: "Nhân viên lập kế hoạch",
    input: "Trường, ngày, món ăn",
    responsibility: "Rà soát thực đơn catering",
    output: "Nhu cầu catering",
    handoff: "Rà soát nhu cầu nguyên liệu",
    primaryAction: "Kiểm tra thực đơn",
  },
  {
    id: "additional-demand",
    label: "Nhu cầu bổ sung",
    group: "Lập kế hoạch",
    role: "Nhân viên lập kế hoạch",
    input: "Khách hàng, nguyên liệu, ngày",
    responsibility: "Ghi nhận nhu cầu trực tiếp mẫu",
    output: "Nhu cầu nguyên liệu trực tiếp",
    handoff: "Rà soát nhu cầu nguyên liệu",
    primaryAction: "Rà soát đơn sỉ/bổ sung",
  },
  {
    id: "requirement-review",
    label: "Rà soát nhu cầu nguyên liệu",
    group: "Lập kế hoạch",
    role: "Nhân viên lập kế hoạch",
    input: "Yêu cầu, truy vết, cảnh báo và điều chỉnh mẫu",
    responsibility: "Rà soát nhu cầu trước khi chuyển mua hàng",
    output: "Nhu cầu sẵn sàng xác thực mua hàng",
    handoff: "Phân bổ nhà cung cấp",
    primaryAction: "Kiểm tra ngoại lệ",
  },
  {
    id: "supplier-allocation",
    label: "Phân bổ nhà cung cấp",
    group: "Mua hàng",
    role: "Nhân viên mua hàng",
    input: "Nhu cầu đặt hàng đã xác thực và điều kiện cung ứng",
    responsibility: "Phân bổ nhà cung cấp (bản mẫu tách biệt)",
    output: "Kế hoạch mua hàng cân bằng",
    handoff: "Đơn mua hàng",
    primaryAction: "Xem hàng chưa phân bổ",
  },
  {
    id: "purchase-orders",
    label: "Đơn mua hàng",
    group: "Mua hàng",
    role: "Nhân viên mua hàng",
    input: "Phân bổ cân bằng và lịch sử",
    responsibility: "Rà soát phát hành đơn mua hàng",
    output: "Cam kết nhà cung cấp đã phát hành",
    handoff: "Lập kế hoạch giao nhận",
    primaryAction: "Xem bản nháp đơn mua hàng",
  },
  {
    id: "dispatch-planning",
    label: "Lập kế hoạch giao nhận",
    group: "Thực hiện",
    role: "Kho và giao nhận",
    input: "Ngữ cảnh đơn mua hàng và dữ liệu giao nhận",
    responsibility: "Chuẩn bị chứng từ giao nhận",
    output: "Giao nhận sẵn sàng phát hành",
    handoff: "Kiểm soát vận hành",
    primaryAction: "Xem kế hoạch giao nhận",
  },
  {
    id: "operational-qa",
    label: "Kiểm soát vận hành",
    group: "Thực hiện",
    role: "Điều hành và quản lý",
    input: "Tổng hợp nhu cầu, yêu cầu, đơn mua hàng, giao nhận",
    responsibility: "Điều phối ngoại lệ và đối soát",
    output: "Ngoại lệ được phân tuyến",
    handoff: "Trang chịu trách nhiệm",
    primaryAction: "Xem ngoại lệ",
  },
  {
    id: "customers-schools",
    label: "Khách hàng và trường học",
    group: "Dữ liệu danh mục",
    role: "Quản trị dữ liệu danh mục",
    input: "Khách hàng và trường",
    responsibility: "Duy trì danh mục đối tác",
    output: "Tham chiếu hợp lệ",
    handoff: "Lập kế hoạch",
    primaryAction: "Rà soát danh mục",
  },
  {
    id: "ingredients-units",
    label: "Nguyên liệu và đơn vị",
    group: "Dữ liệu danh mục",
    role: "Quản trị dữ liệu danh mục",
    input: "Nguyên liệu và đơn vị",
    responsibility: "Duy trì tham chiếu nguyên liệu",
    output: "Nguyên liệu hợp lệ",
    handoff: "Lập kế hoạch / Mua hàng",
    primaryAction: "Rà soát đơn vị",
  },
  {
    id: "dishes-recipes",
    label: "Món ăn và công thức",
    group: "Dữ liệu danh mục",
    role: "Quản trị dữ liệu danh mục",
    input: "Món, công thức và phiên bản",
    responsibility: "Duy trì định nghĩa công thức",
    output: "Cơ sở công thức",
    handoff: "Rà soát nhu cầu nguyên liệu",
    primaryAction: "Rà soát công thức",
  },
  {
    id: "suppliers-eligibility",
    label: "Nhà cung cấp và điều kiện",
    group: "Dữ liệu danh mục",
    role: "Quản trị dữ liệu danh mục",
    input: "Nhà cung cấp và điều kiện cung ứng",
    responsibility: "Duy trì quan hệ cung ứng",
    output: "Điều kiện cung ứng tham chiếu",
    handoff: "Phân bổ nhà cung cấp",
    primaryAction: "Rà soát điều kiện cung ứng",
  },
  {
    id: "users-access",
    label: "Người dùng và quyền truy cập",
    group: "Quản trị",
    role: "Quản trị hệ thống",
    input: "Người dùng và vai trò",
    responsibility: "Quản lý truy cập (chức năng dự kiến)",
    output: "Ma trận quyền được duyệt",
    handoff: "Xác thực/phân quyền backend sau này",
    primaryAction: "Xem phạm vi prototype",
  },
  {
    id: "audit-diagnostics",
    label: "Kiểm toán và chẩn đoán",
    group: "Quản trị",
    role: "Quản trị hệ thống",
    input: "Sự kiện và ngoại lệ",
    responsibility: "Hỗ trợ chẩn đoán",
    output: "Điểm cần điều tra",
    handoff: "Trang chịu trách nhiệm",
    primaryAction: "Xem giả định kiểm toán",
  },
  {
    id: "integration-status",
    label: "Trạng thái tích hợp",
    group: "Quản trị",
    role: "Quản trị hệ thống",
    input: "Trạng thái kết nối",
    responsibility: "Hiển thị biên giới prototype",
    output: "Nhận thức không có backend",
    handoff: "Rà soát kiến trúc",
    primaryAction: "Xem trạng thái",
  },
];

export const journeys = [
  {
    id: "CAT-0713-ND",
    name: "Catering · Nguyễn Du",
    context: "13/07/2026 · Canh bí đỏ · 620 suất",
    flow: [
      "Lập thực đơn",
      "Điểm danh và suất ăn",
      "Rà soát nhu cầu nguyên liệu",
      "Phân bổ nhà cung cấp",
      "Đơn mua hàng",
      "Lập kế hoạch giao nhận",
      "Kiểm soát vận hành",
    ],
  },
  {
    id: "WS-2026-0714",
    name: "Bán sỉ · Bếp ăn Minh An",
    context: "14/07/2026 · Gạo Jasmine · 250 kg",
    flow: [
      "Nhu cầu bổ sung",
      "Rà soát nhu cầu nguyên liệu",
      "Phân bổ nhà cung cấp",
      "Đơn mua hàng",
      "Lập kế hoạch giao nhận",
      "Kiểm soát vận hành",
    ],
  },
];
