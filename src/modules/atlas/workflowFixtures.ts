import type { AtlasPageId } from "./atlasConfig";

export type JourneyId = "CAT-0713-ND" | "WS-2026-0714";

export type WorkflowStage = {
  pageId: AtlasPageId;
  label: string;
  role: string;
  inputSnapshot: string;
  outputSnapshot: string;
  nextHandoff: string;
  blocker?: string;
};

export type WorkflowJourney = {
  id: JourneyId;
  name: string;
  sourceKind: "CATERING" | "WHOLESALE";
  context: string;
  sourceSummary: string;
  stages: WorkflowStage[];
};

export const workflowJourneys: WorkflowJourney[] = [
  {
    id: "CAT-0713-ND",
    name: "Suất ăn trường · Nguyễn Du",
    sourceKind: "CATERING",
    context: "13/07/2026 · Canh bí đỏ · 620 suất",
    sourceSummary:
      "Thực đơn Canh bí đỏ · 620 suất đã xác nhận trong dữ liệu mẫu",
    stages: [
      {
        pageId: "menu-planning",
        label: "Lập thực đơn",
        role: "Nhân viên lập kế hoạch",
        inputSnapshot: "Trường Tiểu học Nguyễn Du · 13/07/2026 · Canh bí đỏ",
        outputSnapshot: "Nhu cầu catering mẫu: 620 suất",
        nextHandoff: "Điểm danh và suất ăn",
      },
      {
        pageId: "attendance-portions",
        label: "Điểm danh và suất ăn",
        role: "Nhân viên lập kế hoạch",
        inputSnapshot: "620 suất theo thực đơn · số liệu điểm danh mẫu",
        outputSnapshot: "Cơ sở suất ăn mẫu đã xác nhận",
        nextHandoff: "Rà soát nhu cầu nguyên liệu",
      },
      {
        pageId: "requirement-review",
        label: "Rà soát nhu cầu nguyên liệu",
        role: "Nhân viên lập kế hoạch",
        inputSnapshot: "Nhu cầu catering và truy vết công thức mẫu",
        outputSnapshot: "Dòng nhu cầu mẫu sẵn sàng xác thực mua hàng",
        nextHandoff: "Phân bổ nhà cung cấp",
      },
      {
        pageId: "supplier-allocation",
        label: "Phân bổ nhà cung cấp",
        role: "Nhân viên mua hàng",
        inputSnapshot: "Dòng nhu cầu đặt hàng mẫu · điều kiện cung ứng mẫu",
        outputSnapshot: "Kế hoạch phân bổ mẫu theo nhà cung cấp",
        nextHandoff: "Đơn mua hàng",
      },
      {
        pageId: "purchase-orders",
        label: "Đơn mua hàng",
        role: "Nhân viên mua hàng",
        inputSnapshot: "Phân bổ mẫu theo nhà cung cấp",
        outputSnapshot: "Cam kết đơn mua hàng mẫu",
        nextHandoff: "Tiếp nhận và chuẩn bị kho",
      },
      {
        pageId: "warehouse-receiving",
        label: "Tiếp nhận và chuẩn bị kho",
        role: "Nhân viên kho",
        inputSnapshot:
          "Cam kết đơn mua hàng mẫu · danh sách chuẩn bị cho Nguyễn Du",
        outputSnapshot: "Hàng mẫu đã tiếp nhận và sẵn sàng bàn giao giao nhận",
        nextHandoff: "Lập kế hoạch giao nhận",
      },
      {
        pageId: "dispatch-planning",
        label: "Lập kế hoạch giao nhận",
        role: "Kho và giao nhận",
        inputSnapshot:
          "Hàng mẫu đã chuẩn bị · điểm giao Trường Tiểu học Nguyễn Du",
        outputSnapshot: "Bàn giao tài xế mẫu đã sẵn sàng",
        nextHandoff: "Kiểm soát vận hành",
      },
      {
        pageId: "operational-qa",
        label: "Kiểm soát vận hành",
        role: "Điều hành và quản lý",
        inputSnapshot:
          "Ảnh chụp demand, nhu cầu, mua hàng, kho và giao nhận mẫu",
        outputSnapshot: "Kết quả QA mẫu đã ghi nhận",
        nextHandoff: "Kết thúc hành trình mẫu",
      },
    ],
  },
  {
    id: "WS-2026-0714",
    name: "Bán sỉ · Bếp ăn Minh An",
    sourceKind: "WHOLESALE",
    context: "14/07/2026 · Gạo Jasmine · 250 kg",
    sourceSummary: "Đơn nguyên liệu trực tiếp: Gạo Jasmine · 250 kg",
    stages: [
      {
        pageId: "additional-demand",
        label: "Nhu cầu bổ sung",
        role: "Nhân viên lập kế hoạch",
        inputSnapshot: "Bếp ăn Minh An · 14/07/2026 · Gạo Jasmine 250 kg",
        outputSnapshot: "Nhu cầu nguyên liệu trực tiếp mẫu",
        nextHandoff: "Rà soát nhu cầu nguyên liệu",
      },
      {
        pageId: "requirement-review",
        label: "Rà soát nhu cầu nguyên liệu",
        role: "Nhân viên lập kế hoạch",
        inputSnapshot: "Nhu cầu trực tiếp mẫu, không có truy vết công thức",
        outputSnapshot: "Dòng nhu cầu mẫu cần xác thực mua hàng",
        nextHandoff: "Phân bổ nhà cung cấp",
      },
      {
        pageId: "supplier-allocation",
        label: "Phân bổ nhà cung cấp",
        role: "Nhân viên mua hàng",
        inputSnapshot: "250 kg Gạo Jasmine · điều kiện cung ứng mẫu",
        outputSnapshot: "Kế hoạch phân bổ mẫu sau rà soát",
        nextHandoff: "Đơn mua hàng",
        blocker:
          "Dữ liệu mẫu: cần rà soát nhà cung cấp trước khi mô phỏng bước tiếp theo.",
      },
      {
        pageId: "purchase-orders",
        label: "Đơn mua hàng",
        role: "Nhân viên mua hàng",
        inputSnapshot: "Phân bổ mẫu đã rà soát",
        outputSnapshot: "Cam kết đơn mua hàng mẫu",
        nextHandoff: "Tiếp nhận và chuẩn bị kho",
      },
      {
        pageId: "warehouse-receiving",
        label: "Tiếp nhận và chuẩn bị kho",
        role: "Nhân viên kho",
        inputSnapshot:
          "Cam kết đơn mua hàng mẫu · danh sách chuẩn bị cho Minh An",
        outputSnapshot: "Hàng mẫu đã tiếp nhận và sẵn sàng bàn giao giao nhận",
        nextHandoff: "Lập kế hoạch giao nhận",
      },
      {
        pageId: "dispatch-planning",
        label: "Lập kế hoạch giao nhận",
        role: "Kho và giao nhận",
        inputSnapshot: "Hàng mẫu đã chuẩn bị · điểm giao Bếp ăn Minh An",
        outputSnapshot: "Bàn giao tài xế mẫu đã sẵn sàng",
        nextHandoff: "Kiểm soát vận hành",
      },
      {
        pageId: "operational-qa",
        label: "Kiểm soát vận hành",
        role: "Điều hành và quản lý",
        inputSnapshot:
          "Ảnh chụp demand, nhu cầu, mua hàng, kho và giao nhận mẫu",
        outputSnapshot: "Kết quả QA mẫu đã ghi nhận",
        nextHandoff: "Kết thúc hành trình mẫu",
      },
    ],
  },
];

export const workflowJourneyById = Object.fromEntries(
  workflowJourneys.map((journey) => [journey.id, journey]),
) as Record<JourneyId, WorkflowJourney>;
