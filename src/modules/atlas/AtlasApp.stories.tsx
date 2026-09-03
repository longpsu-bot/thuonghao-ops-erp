import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { expect, userEvent, within } from "storybook/test";
import { AtlasAppView as AtlasApp } from "./AtlasApp";
import { createReviewAuthState } from "./review/reviewMode";
import { NeedGenerationWorkbench } from "./planning-inputs/need-generation/NeedGenerationWorkbench";
import { PlanningInputsWorkbench } from "./planning-inputs/PlanningInputsWorkbench";
import {
  PlanningRailActionHost,
  PlanningRailActionProvider,
} from "./planning-inputs/PlanningRailActionPortal";
import { createReviewNeedGenerationApi } from "./planning-inputs/need-generation/reviewNeedGenerationApi";
import { createReviewPlanningInputReadinessApi } from "./planning-inputs/readiness/reviewPlanningInputReadinessApi";
import { ConfirmedNeedReviewWorkbench } from "./planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench";
import { createReviewConfirmedNeedApi } from "./planning-inputs/confirmed-needs/reviewConfirmedNeedApi";

const meta = {
  title: "Atlas/Planning workflow",
  component: AtlasApp,
  parameters: {
    layout: "fullscreen",
    docs: {
      description: {
        component:
          "Bản xem thử quy trình Lập nhu cầu theo D-036. Mọi thay đổi chỉ tồn tại trong bộ nhớ và mất khi tải lại trang.",
      },
    },
  },
} satisfies Meta<typeof AtlasApp>;

export default meta;
type Story = StoryObj<typeof meta>;

async function selectPlanningTab(canvasElement: HTMLElement, name: string) {
  const canvas = within(canvasElement);
  await userEvent.click(await canvas.findByRole("tab", { name }));
  canvasElement.ownerDocument.defaultView?.scrollTo(0, 0);
}

const confirmedNeedBatchId = "c4500000-0000-0000-0000-000000000001";

function ConfirmedNeedStateStory({
  outcome = "ready",
}: {
  outcome?: "ready" | "unknown-save" | "unknown-release" | "handoff-pending";
}) {
  const [api] = useState(() => {
    const next = createReviewConfirmedNeedApi("ready");
    if (outcome === "unknown-save")
      next.save = async () => ({
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Chưa chắc chắn thay đổi đã được lưu.",
        },
      });
    if (outcome === "unknown-release")
      next.releaseSaved = async () => ({
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Chưa chắc chắn nhu cầu đã được phát hành.",
        },
      });
    if (outcome === "handoff-pending")
      next.releasePurchaseHandoff = async () => ({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "RETRYABLE_CONCURRENCY_FAILURE",
          safe_message: "Bàn giao mua hàng chưa được tạo.",
          retryable: true,
        },
      });
    return next;
  });
  return (
    <PlanningRailActionProvider>
      <main className="atlas-page">
        <PlanningRailActionHost />
        <ConfirmedNeedReviewWorkbench
          authState={createReviewAuthState("ready")}
          api={api}
          initialBatchId={confirmedNeedBatchId}
          mode="review"
        />
      </main>
    </PlanningRailActionProvider>
  );
}

async function submitConfirmedNeedChanges(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  const quantity = await canvas.findByLabelText("Số lượng xác nhận Cà rốt");
  await userEvent.clear(quantity);
  await userEvent.type(quantity, "5.250000");
  await userEvent.selectOptions(
    canvas.getByLabelText("Lý do điều chỉnh Cà rốt"),
    "PLANNING_STEP_ADJUSTMENT",
  );
  await userEvent.click(canvas.getByRole("button", { name: "Lưu" }));
}

async function saveConfirmedNeed(canvasElement: HTMLElement) {
  await submitConfirmedNeedChanges(canvasElement);
  const canvas = within(canvasElement);
  await canvas.findByText("Đã lưu thay đổi.");
}

async function releaseConfirmedNeed(canvasElement: HTMLElement) {
  await saveConfirmedNeed(canvasElement);
  const canvas = within(canvasElement);
  await userEvent.click(
    canvas.getByRole("button", { name: "Chuyển sang lên đơn" }),
  );
  await userEvent.click(
    await canvas.findByRole("button", { name: "Xác nhận chuyển" }),
  );
}

function FirstTimeConfirmedNeedStory() {
  const [confirmedNeedApi] = useState(() =>
    createReviewConfirmedNeedApi("ready"),
  );
  const [readinessApi] = useState(() =>
    createReviewPlanningInputReadinessApi("ready", { currentNeed: true }),
  );
  return (
    <main className="atlas-page">
      <PlanningInputsWorkbench
        authState={createReviewAuthState("ready")}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-03"
        mode="review"
      />
    </main>
  );
}

function NeedGenerationStateStory({
  currentness,
  confirmedNeedStatus = "DRAFT_REVIEW",
}: {
  currentness: "OUTDATED" | "CURRENT";
  confirmedNeedStatus?: "DRAFT_REVIEW" | "RELEASED_FOR_PURCHASE_HANDOFF";
}) {
  const [api] = useState(() => createReviewNeedGenerationApi("ready"));
  const [preflightApi] = useState(() => {
    const next = createReviewPlanningInputReadinessApi("ready");
    const original = next.preflight.bind(next);
    next.preflight = async (...args: Parameters<typeof original>) => {
      const result = await original(...args);
      if (result.kind === "success" && result.response.preflight) {
        const preflight = result.response.preflight as Record<string, unknown>;
        preflight.downstream_currentness = currentness;
        preflight.current_need = {
          need_generation_run_id: "storybook-current-run",
          need_generation_run_version: 3,
          need_generation_run_status: "RELEASED_FOR_CONFIRMATION",
          confirmed_need_batch_id: "storybook-current-batch",
          confirmed_need_batch_version: 1,
          confirmed_need_batch_status: confirmedNeedStatus,
        };
      }
      return result;
    };
    return next;
  });

  const [serviceDate, setServiceDate] = useState("2026-08-03");
  return (
    <main className="atlas-page">
      <NeedGenerationWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        preflightApi={preflightApi}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
        selectedServiceDate={serviceDate}
        onServiceDateChange={setServiceDate}
        mode="review"
      />
    </main>
  );
}

function NeedGenerationUnknownOutcomeStory() {
  const [serviceDate, setServiceDate] = useState("2026-08-03");
  const [api] = useState(() => {
    const next = createReviewNeedGenerationApi("ready");
    next.execute = async () => ({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "Mất kết nối khi ghi nhu cầu.",
      },
    });
    return next;
  });
  const [preflightApi] = useState(() =>
    createReviewPlanningInputReadinessApi("ready"),
  );
  return (
    <main className="atlas-page">
      <NeedGenerationWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        preflightApi={preflightApi}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
        selectedServiceDate={serviceDate}
        onServiceDateChange={setServiceDate}
        mode="review"
      />
    </main>
  );
}

export const Schools: Story = {
  name: "Trường học",
  args: { initialPage: "customers-schools", reviewMode: true },
};

export const IngredientsAndSuppliers: Story = {
  name: "Nguyên liệu và Nhà cung ứng",
  args: { initialPage: "ingredients-units", reviewMode: true },
};

export const SourceWorkbenchNormal: Story = {
  name: "Thực đơn · trạng thái bình thường",
  args: { initialPage: "planning-inputs", reviewMode: true },
};

export const MenuWarning: Story = {
  name: "Thực đơn · cảnh báo công thức",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_recipe_warning",
    reviewMode: true,
  },
};

export const MenuBlocked: Story = {
  name: "Thực đơn · lỗi chặn",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_duplicate",
    reviewMode: true,
  },
};

export const AttendanceEditable: Story = {
  name: "Sĩ số · bảng chỉnh sửa",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "attendance_draft",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sĩ số");
  },
};

export const AttendanceDefaults: Story = {
  name: "Sĩ số · giá trị làm việc có sẵn trước khi lưu",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sĩ số");
    const canvas = within(canvasElement);
    await canvas.findAllByRole("spinbutton", { name: /Suất học sinh/ });
  },
};

export const PantryRows: Story = {
  name: "Nhu cầu bổ sung · có dòng",
  args: { initialPage: "planning-inputs", reviewMode: true },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Nhu cầu bổ sung");
  },
};

export const PantryNoAdditions: Story = {
  name: "Nhu cầu bổ sung · xác nhận không có bổ sung",
  args: { initialPage: "planning-inputs", reviewMode: true },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Nhu cầu bổ sung");
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xóa dòng 1" }),
    );
    await userEvent.click(
      canvas.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    );
  },
};

export const NeedGenerationReadyNotGenerated: Story = {
  name: "Tạo nhu cầu · sẵn sàng, chưa tạo",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Tạo nhu cầu");
  },
};

export const NeedGenerationBlocked: Story = {
  name: "Tạo nhu cầu · đầu vào cần xử lý",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "empty",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Tạo nhu cầu");
  },
};

export const NeedGenerationOutdated: Story = {
  name: "Tạo nhu cầu · cần cập nhật",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <NeedGenerationStateStory currentness="OUTDATED" />,
};

export const NeedGenerationReleasedOutdated: Story = {
  name: "Tạo nhu cầu · đã lên đơn, không thể cập nhật trực tiếp",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => (
    <NeedGenerationStateStory
      currentness="OUTDATED"
      confirmedNeedStatus="RELEASED_FOR_PURCHASE_HANDOFF"
    />
  ),
};

export const NeedGenerationCurrent: Story = {
  name: "Tạo nhu cầu · hiện hành, mở Xác nhận nhu cầu",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <NeedGenerationStateStory currentness="CURRENT" />,
};

export const GeneratedRequirementsTable: Story = {
  name: "Tạo nhu cầu · bảng nhu cầu đã tạo",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Tạo nhu cầu");
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Tạo nhu cầu" }),
    );
    canvasElement.ownerDocument.defaultView?.scrollTo(0, 0);
  },
};

export const NeedGenerationUnknownOutcome: Story = {
  name: "Tạo nhu cầu · kết quả ghi chưa xác định",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <NeedGenerationUnknownOutcomeStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Tạo nhu cầu" }),
    );
  },
};

export const MobilePlanningNeedGeneration: Story = {
  name: "Quy trình Lập nhu cầu · di động 360 px",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  parameters: { viewport: { defaultViewport: "mobile1" } },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Tạo nhu cầu");
  },
};

export const PermissionState: Story = {
  name: "Nguồn kế hoạch · không có quyền truy cập",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "permission_denied",
    reviewMode: true,
  },
};

export const ConfirmedNeedFirstTimeOperator: Story = {
  name: "Xác nhận nhu cầu · nhân viên mới lần đầu sử dụng",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <FirstTimeConfirmedNeedStory />,
  parameters: {
    docs: {
      description: {
        story:
          "Nhân viên chọn tuần, vào Xác nhận nhu cầu, tìm theo nguyên liệu hoặc trường, chỉnh số lượng, lưu rồi chuyển sang lên đơn khi dữ liệu đã hoàn chỉnh.",
      },
    },
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(
      canvas.getByRole("tab", { name: "Xác nhận nhu cầu" }),
    );
    await canvas.findByText("Gạo thơm");
    await userEvent.selectOptions(
      canvas.getByLabelText("Trường"),
      "a1100000-0000-0000-0000-000000000001",
    );
    const quantity = canvas.getByLabelText("Số lượng xác nhận Cà rốt");
    await userEvent.clear(quantity);
    await userEvent.type(quantity, "5.250000");
    await userEvent.selectOptions(
      canvas.getByLabelText("Lý do điều chỉnh Cà rốt"),
      "PLANNING_STEP_ADJUSTMENT",
    );
    await canvas.findByRole("button", { name: "Lưu" });
  },
};

export const ConfirmedNeedEditable: Story = {
  name: "Xác nhận nhu cầu · chỉnh sửa trực tiếp",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
};

export const ConfirmedNeedBlocked: Story = {
  name: "Xác nhận nhu cầu · dòng điều chỉnh cần sửa",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const quantity = await canvas.findByLabelText("Số lượng xác nhận Cà rốt");
    await userEvent.clear(quantity);
    await userEvent.type(quantity, "5.250000");
    await canvas.findByText(/Hãy chọn lý do/);
  },
};

export const ConfirmedNeedSaved: Story = {
  name: "Xác nhận nhu cầu · đã lưu",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => saveConfirmedNeed(canvasElement),
};

export const ConfirmedNeedReleased: Story = {
  name: "Xác nhận nhu cầu · đã chuyển sang lên đơn",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await releaseConfirmedNeed(canvasElement);
    await canvas.findByText("Đã chuyển sang lên đơn.");
    await expect(
      canvas.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
  },
};

export const ConfirmedNeedUnknownWriteOutcome: Story = {
  name: "Xác nhận nhu cầu · kết quả ghi chưa xác định",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory outcome="unknown-save" />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await submitConfirmedNeedChanges(canvasElement);
    await canvas.findByText(/Atlas sẽ không tự gửi lại/);
    await expect(canvas.getByRole("button", { name: "Lưu" })).toBeDisabled();
    await expect(
      canvas.getByRole("button", { name: "Làm mới" }),
    ).toHaveTextContent("Làm mới");
  },
};

export const ConfirmedNeedRefreshRequired: Story = {
  name: "Xác nhận nhu cầu · cần làm mới sau kết quả chuyển chưa rõ",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory outcome="unknown-release" />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await releaseConfirmedNeed(canvasElement);
    await canvas.findByText(
      "Chưa xác định được kết quả chuyển. Hãy làm mới dữ liệu trước khi tiếp tục.",
    );
    await expect(
      canvas.getByRole("button", { name: "Chuyển sang lên đơn" }),
    ).toBeDisabled();
    await expect(
      canvas.getByRole("button", { name: "Làm mới" }),
    ).toHaveTextContent("Làm mới");
  },
};

export const ConfirmedNeedHandoffPending: Story = {
  name: "Xác nhận nhu cầu · đã phát hành, bàn giao còn chờ",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory outcome="handoff-pending" />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await releaseConfirmedNeed(canvasElement);
    await canvas.findByText("Nhu cầu đã phát hành; Bàn giao mua hàng còn chờ.");
    await expect(
      canvas.getByRole("button", { name: "Thử lại bàn giao" }),
    ).toBeEnabled();
    await expect(
      canvas.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
  },
};

export const ConfirmedNeedMobile360: Story = {
  name: "Xác nhận nhu cầu · di động 360 px",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  parameters: {
    viewport: {
      defaultViewport: "confirmedNeedMobile",
      viewports: {
        confirmedNeedMobile: {
          name: "Mobile 360",
          styles: { width: "360px", height: "800px" },
        },
      },
    },
  },
};

export const VietnameseCalendar: Story = {
  name: "Nguồn kế hoạch · lịch tiếng Việt",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(await canvas.findByLabelText("Tuần phục vụ"));
  },
};

export const ProcurementAllocation: Story = {
  name: "Mua hàng · phân bổ đề xuất",
  args: {
    initialPage: "procurement",
    initialReviewScenario: "procurement_default",
    reviewMode: true,
  },
};

export const ProcurementRebalance: Story = {
  name: "Mua hàng · cân bằng 60/40 thành 72/48",
  args: {
    initialPage: "procurement",
    initialReviewScenario: "procurement_rebalance",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Mở phân bổ Gạo thơm" }),
    );
  },
};

export const ProcurementStalePurchaseOrder: Story = {
  name: "Mua hàng · đơn nháp cần cập nhật",
  args: {
    initialPage: "procurement",
    initialReviewScenario: "procurement_stale_po",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Đơn mua" }),
    );
    await userEvent.click(
      await canvas.findByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
  },
};

export const ProcurementReleasedPurchaseOrder: Story = {
  name: "Mua hàng · đơn đã phát hành",
  args: {
    initialPage: "procurement",
    initialReviewScenario: "procurement_released_po",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Đơn mua" }),
    );
    await userEvent.click(
      await canvas.findByRole("button", { name: "Mở đơn mua NCC An Phú" }),
    );
  },
};
