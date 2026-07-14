export type AtlasPageId =
  | "control-board"
  | "planning-sources"
  | "requirement-planning"
  | "purchase-planning"
  | "document-release"
  | "warehouse-receiving"
  | "warehouse-stock-release"
  | "customers-schools"
  | "ingredients-units"
  | "suppliers-eligibility"
  | "recipe-governance"
  | "prototype-boundary";

export const atlasGroups = [
  "Vận hành hằng ngày",
  "Dữ liệu & quản trị",
] as const;
export type AtlasGroup = (typeof atlasGroups)[number];

export type AtlasPage = {
  id: AtlasPageId;
  label: string;
  group: AtlasGroup;
  decision: string;
  object: string;
  state: string;
  handoff: string;
};

export const atlasPages: AtlasPage[] = [
  {
    id: "control-board",
    label: "Bảng điều hành",
    group: "Vận hành hằng ngày",
    decision: "Việc nào cần xử lý trước khi vận hành tiếp tục?",
    object: "Ngoại lệ vận hành",
    state: "Theo dõi và điều phối",
    handoff: "Trang công việc có ngoại lệ",
  },
  {
    id: "planning-sources",
    label: "Nguồn kế hoạch",
    group: "Vận hành hằng ngày",
    decision: "Nguồn nào tạo ra nhu cầu nguyên liệu cần được kiểm tra?",
    object: "Dòng nguồn kế hoạch",
    state: "Nhập nguồn → kiểm tra → xác nhận",
    handoff: "Tổng hợp & xác nhận nhu cầu",
  },
  {
    id: "requirement-planning",
    label: "Tổng hợp & xác nhận nhu cầu",
    group: "Vận hành hằng ngày",
    decision: "Nhu cầu thực tế nào được xác nhận?",
    object: "Dòng nhu cầu",
    state: "Nhập thực tế → xác nhận",
    handoff: "Lập kế hoạch mua hàng và phát hành",
  },
  {
    id: "purchase-planning",
    label: "Lập kế hoạch mua hàng",
    group: "Vận hành hằng ngày",
    decision: "Phân bổ nhu cầu đã xác nhận cho NCC nào?",
    object: "Phân bổ NCC",
    state: "Chưa phân công → đủ phân công",
    handoff: "Chuẩn bị PO",
  },
  {
    id: "document-release",
    label: "Phát hành chứng từ",
    group: "Vận hành hằng ngày",
    decision: "Tài liệu vận hành nào đủ điều kiện phát hành?",
    object: "PO, phiếu xuất kho, dòng đối chiếu",
    state: "Nháp → sẵn sàng → phát hành",
    handoff: "Nhập kho & xử lý chênh lệch",
  },
  {
    id: "warehouse-receiving",
    label: "Nhập kho & xử lý chênh lệch",
    group: "Vận hành hằng ngày",
    decision: "Kết quả nhận hàng ảnh hưởng ai và cần làm gì tiếp?",
    object: "Dòng nhận hàng / ngoại lệ",
    state: "Ghi nhận → xử lý ngoại lệ",
    handoff: "Thu mua / BGĐ theo ngoại lệ",
  },
  {
    id: "warehouse-stock-release",
    label: "Warehouse stock release",
    group: atlasGroups[0],
    decision: "Can traced stock leave Warehouse-controlled custody?",
    object: "Reservation, pick list, Warehouse release, stock movement",
    state: "Reserve → pick → release custody → post stock reduction",
    handoff:
      "Custody evidence only; destination delivery remains outside Warehouse",
  },
  {
    id: "customers-schools",
    label: "Khách hàng & Trường học",
    group: "Dữ liệu & quản trị",
    decision: "Điểm nhận nào hợp lệ?",
    object: "Đơn vị nhận",
    state: "Dữ liệu tham chiếu",
    handoff: "Lập nhu cầu",
  },
  {
    id: "ingredients-units",
    label: "Nguyên liệu & Đơn vị",
    group: "Dữ liệu & quản trị",
    decision: "Nguyên liệu và đơn vị nào được dùng?",
    object: "Nguyên liệu",
    state: "Dữ liệu tham chiếu",
    handoff: "Lập nhu cầu",
  },
  {
    id: "suppliers-eligibility",
    label: "Nhà cung cấp & Điều kiện cung ứng",
    group: "Dữ liệu & quản trị",
    decision: "NCC nào đủ điều kiện cung ứng?",
    object: "Hồ sơ NCC",
    state: "Dữ liệu tham chiếu",
    handoff: "Lập kế hoạch mua hàng",
  },
  {
    id: "recipe-governance",
    label: "Kiểm soát thay đổi công thức",
    group: "Dữ liệu & quản trị",
    decision: "Thay đổi công thức nào được đề xuất?",
    object: "Đề xuất thay đổi công thức",
    state: "Hiệu lực / khóa / đề xuất",
    handoff: "Dữ liệu hỗ trợ lập nhu cầu",
  },
  {
    id: "prototype-boundary",
    label: "Ranh giới prototype",
    group: "Dữ liệu & quản trị",
    decision: "Điều gì nằm ngoài prototype?",
    object: "Phạm vi",
    state: "Tham chiếu",
    handoff: "Rà soát kiến trúc",
  },
];
