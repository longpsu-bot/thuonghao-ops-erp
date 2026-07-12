export type AtlasPageId =
  | "operations-home"
  | "requirement-planning"
  | "purchase-planning"
  | "warehouse-receiving"
  | "customers-schools"
  | "ingredients-units"
  | "suppliers-eligibility"
  | "dishes-recipes"
  | "recipe-change-control"
  | "prototype-boundary";

export const atlasGroups = [
  "Tổng quan",
  "Quy trình hằng ngày",
  "Dữ liệu hỗ trợ",
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
};

export const atlasPages: AtlasPage[] = [
  { id: "operations-home", label: "Bảng điều hành", group: "Tổng quan", role: "Điều phối vận hành", input: "Kỳ phục vụ mẫu", responsibility: "Điều phối ba điểm bàn giao hằng ngày", output: "Ưu tiên tác nghiệp rõ ràng", handoff: "Ba giai đoạn vận hành" },
  { id: "requirement-planning", label: "Lập nhu cầu", group: "Quy trình hằng ngày", role: "Điều phối nhu cầu", input: "Nhu cầu, ngày phục vụ, điểm đến", responsibility: "Giữ nhu cầu, đối tượng phục vụ và điểm đến trong cùng một dòng kế hoạch", output: "Nhu cầu sẵn sàng lập kế hoạch mua", handoff: "Lập kế hoạch mua hàng" },
  { id: "purchase-planning", label: "Lập kế hoạch mua hàng", group: "Quy trình hằng ngày", role: "Mua hàng", input: "Nhu cầu đã gom theo điểm đến", responsibility: "Phân công nhà cung cấp và chuẩn bị danh sách đặt hàng", output: "Danh sách đặt nhà cung cấp", handoff: "Nhập kho" },
  { id: "warehouse-receiving", label: "Nhập kho", group: "Quy trình hằng ngày", role: "Kho", input: "Danh sách đã đặt", responsibility: "Đối chiếu số lượng đặt với số lượng nhận và hiển thị chênh lệch", output: "Kết quả nhận hàng mẫu", handoff: "Đối soát/kế toán trong tương lai" },
  { id: "customers-schools", label: "Khách hàng & Trường học", group: "Dữ liệu hỗ trợ", role: "Dữ liệu nền", input: "Khách hàng, trường, bếp, điểm giao", responsibility: "Cung cấp ngữ cảnh điểm đến", output: "Tham chiếu điểm đến hợp lệ", handoff: "Lập nhu cầu" },
  { id: "ingredients-units", label: "Nguyên liệu & Đơn vị", group: "Dữ liệu hỗ trợ", role: "Dữ liệu nền", input: "Nguyên liệu và đơn vị", responsibility: "Cung cấp tham chiếu nguyên liệu", output: "Dữ liệu dùng cho kế hoạch", handoff: "Lập nhu cầu và mua hàng" },
  { id: "suppliers-eligibility", label: "Nhà cung cấp & Điều kiện cung ứng", group: "Dữ liệu hỗ trợ", role: "Dữ liệu nền", input: "Nhà cung cấp và điều kiện", responsibility: "Cung cấp lựa chọn phân công", output: "Nguồn cung khả dụng", handoff: "Lập kế hoạch mua hàng" },
  { id: "dishes-recipes", label: "Món ăn & Công thức", group: "Dữ liệu hỗ trợ", role: "Quản trị công thức", input: "Món ăn và BOM mẫu", responsibility: "Hiển thị công thức đầu vào của lập nhu cầu", output: "Tham chiếu công thức", handoff: "Lập nhu cầu" },
  { id: "recipe-change-control", label: "Kiểm soát thay đổi công thức", group: "Dữ liệu hỗ trợ", role: "Quản trị thay đổi", input: "Yêu cầu thay đổi mẫu", responsibility: "Bảo vệ BOM đã khóa thông qua change order", output: "Nguyên tắc thay đổi công thức", handoff: "Quản trị công thức" },
  { id: "prototype-boundary", label: "Ranh giới prototype", group: "Quản trị", role: "Quản trị", input: "Phạm vi giao diện", responsibility: "Nêu rõ giới hạn mock data", output: "Ranh giới triển khai", handoff: "Rà soát kiến trúc" },
];

export const activeStages = [
  { id: "requirement-planning" as const, number: "01", label: "Lập nhu cầu", summary: "Nhu cầu, đối tượng phục vụ và điểm đến", metric: "08 dòng cần rà soát", tone: "teal" },
  { id: "purchase-planning" as const, number: "02", label: "Lập kế hoạch mua hàng", summary: "Phân công nguồn cung và chuẩn bị đơn", metric: "04 nhà cung cấp", tone: "gold" },
  { id: "warehouse-receiving" as const, number: "03", label: "Nhập kho", summary: "Đối chiếu đặt hàng và thực nhận", metric: "01 chênh lệch", tone: "coral" },
];
