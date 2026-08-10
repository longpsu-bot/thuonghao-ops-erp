import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { userEvent, within } from "storybook/test";
import { AtlasAppView as AtlasApp } from "./AtlasApp";
import { createReviewAuthState } from "./review/reviewMode";
import { NeedGenerationWorkbench } from "./planning-inputs/need-generation/NeedGenerationWorkbench";
import { createReviewNeedGenerationApi } from "./planning-inputs/need-generation/reviewNeedGenerationApi";
import { createReviewPlanningInputReadinessApi } from "./planning-inputs/readiness/reviewPlanningInputReadinessApi";
import { ConfirmedNeedReviewWorkbench } from "./planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench";
import {
  createReviewConfirmedNeedApi,
  createReviewConfirmedNeedFixture,
} from "./planning-inputs/confirmed-needs/reviewConfirmedNeedApi";
import { createConfirmedNeedWorkbookBlob } from "./planning-inputs/confirmed-needs/confirmedNeedWorkbook";
import { initialConfirmedNeedDraft } from "./planning-inputs/confirmed-needs/confirmedNeedModel";

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
  unknownConfirm = false,
}: {
  unknownConfirm?: boolean;
}) {
  const [api] = useState(() => {
    const next = createReviewConfirmedNeedApi("ready");
    if (unknownConfirm)
      next.confirm = async () => ({
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Chưa chắc chắn lệnh xác nhận đã được ghi nhận.",
        },
      });
    return next;
  });
  return (
    <main className="atlas-page">
      <ConfirmedNeedReviewWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        initialBatchId={confirmedNeedBatchId}
        mode="review"
      />
    </main>
  );
}

function confirmedNeedNextAction(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  return within(canvas.getByLabelText("Hành động tiếp theo")).getByRole(
    "button",
  );
}

async function prepareConfirmedNeedPreview(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  const quantity = await canvas.findByLabelText("Số lượng xác nhận Cà rốt");
  await userEvent.clear(quantity);
  await userEvent.type(quantity, "5.250000");
  await userEvent.selectOptions(
    canvas.getByLabelText("Lý do Cà rốt"),
    "PLANNING_STEP_ADJUSTMENT",
  );
  await userEvent.click(confirmedNeedNextAction(canvasElement));
  await canvas.findByLabelText("Bản xem trước xác nhận");
}

async function confirmConfirmedNeedQuantities(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  await prepareConfirmedNeedPreview(canvasElement);
  await userEvent.click(
    canvas.getByLabelText("Tôi đã kiểm tra bản xem trước số lượng"),
  );
  await userEvent.click(confirmedNeedNextAction(canvasElement));
  await canvas.findByRole("button", { name: "Hoàn tất xác nhận" });
}

async function completeConfirmedNeedBatch(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  await confirmConfirmedNeedQuantities(canvasElement);
  await userEvent.click(confirmedNeedNextAction(canvasElement));
  await canvas.findByRole("button", { name: "Phê duyệt lô nhu cầu" });
}

async function approveConfirmedNeedBatch(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  await completeConfirmedNeedBatch(canvasElement);
  await userEvent.click(confirmedNeedNextAction(canvasElement));
  await userEvent.click(
    await canvas.findByRole("button", { name: "Xác nhận phê duyệt" }),
  );
  await canvas.findByRole("button", {
    name: "Phát hành sang bước lên đơn",
  });
}

async function confirmedNeedWorkbookFile() {
  const workbench = createReviewConfirmedNeedFixture();
  const drafts = Object.fromEntries(
    workbench.lines.map((line) => [
      line.confirmed_need_line_id,
      initialConfirmedNeedDraft(line),
    ]),
  );
  const carrot = workbench.lines[1]!;
  drafts[carrot.confirmed_need_line_id] = {
    selected: true,
    exact_quantity: "5.250000",
    reason_code: "PLANNING_STEP_ADJUSTMENT",
    reason_note: "",
  };
  const blob = await createConfirmedNeedWorkbookBlob(workbench, drafts);
  return new File([blob], "confirmed-needs.xlsx", { type: blob.type });
}

async function uploadConfirmedNeedWorkbook(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  await canvas.findByText("Gạo thơm");
  await userEvent.upload(
    canvas.getByLabelText("Nhập Excel"),
    await confirmedNeedWorkbookFile(),
  );
  await canvas.findByLabelText("Đã đọc file Excel");
}

function NeedGenerationStateStory({
  currentness,
}: {
  currentness: "OUTDATED" | "CURRENT";
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
          confirmed_need_batch_status: "DRAFT_REVIEW",
        };
      }
      return result;
    };
    return next;
  });

  return (
    <main className="atlas-page">
      <NeedGenerationWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        preflightApi={preflightApi}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
        mode="review"
      />
    </main>
  );
}

function NeedGenerationUnknownOutcomeStory() {
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
  name: "Thực đơn tuần · trạng thái bình thường",
  args: { initialPage: "planning-inputs", reviewMode: true },
};

export const MenuWarning: Story = {
  name: "Thực đơn tuần · cảnh báo công thức",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_recipe_warning",
    reviewMode: true,
  },
};

export const MenuBlocked: Story = {
  name: "Thực đơn tuần · lỗi chặn",
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
  name: "Sĩ số · mặc định cục bộ trước khi lưu",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sĩ số");
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Tạo từ sĩ số mặc định" }),
    );
  },
};

export const PantryRows: Story = {
  name: "Pantry · có dòng bổ sung",
  args: { initialPage: "planning-inputs", reviewMode: true },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Pantry");
  },
};

export const PantryNoAdditions: Story = {
  name: "Pantry · xác nhận không có bổ sung",
  args: { initialPage: "planning-inputs", reviewMode: true },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Pantry");
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

export const ConfirmedNeedEditable: Story = {
  name: "Xác nhận nhu cầu · chỉnh sửa trực tiếp",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
};

export const ConfirmedNeedValidImportReview: Story = {
  name: "Xác nhận nhu cầu · xem lại file Excel hợp lệ",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => uploadConfirmedNeedWorkbook(canvasElement),
};

export const ConfirmedNeedInvalidWorkbook: Story = {
  name: "Xác nhận nhu cầu · file Excel cũ hoặc không hợp lệ",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await canvas.findByText("Gạo thơm");
    await userEvent.upload(
      canvas.getByLabelText("Nhập Excel"),
      new File(["not-an-xlsx"], "confirmed-needs.xlsx"),
    );
    await canvas.findByText(/Bản nháp hiện tại được giữ lại/);
  },
};

export const ConfirmedNeedImportedDraftApplied: Story = {
  name: "Xác nhận nhu cầu · đã áp dụng bản nháp Excel",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await uploadConfirmedNeedWorkbook(canvasElement);
    await userEvent.click(
      canvas.getByRole("button", { name: "Áp dụng vào bảng" }),
    );
  },
};

export const ConfirmedNeedPreview: Story = {
  name: "Xác nhận nhu cầu · xem trước số lượng",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => prepareConfirmedNeedPreview(canvasElement),
};

export const ConfirmedNeedBlocked: Story = {
  name: "Xác nhận nhu cầu · chưa thể hoàn tất",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(await canvas.findByLabelText("Chọn Gạo thơm"));
    await userEvent.click(canvas.getByLabelText("Chọn Cà rốt"));
    await userEvent.click(confirmedNeedNextAction(canvasElement));
    await canvas.findByText(/Chưa thể hoàn tất xác nhận/);
  },
};

export const ConfirmedNeedReadyForCompletion: Story = {
  name: "Xác nhận nhu cầu · sẵn sàng hoàn tất",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) =>
    confirmConfirmedNeedQuantities(canvasElement),
};

export const ConfirmedNeedValidatedForApproval: Story = {
  name: "Xác nhận nhu cầu · đã kiểm tra, chờ phê duyệt",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => completeConfirmedNeedBatch(canvasElement),
};

export const ConfirmedNeedApprovedForRelease: Story = {
  name: "Xác nhận nhu cầu · đã phê duyệt, chờ phát hành",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => approveConfirmedNeedBatch(canvasElement),
};

export const ConfirmedNeedReleased: Story = {
  name: "Xác nhận nhu cầu · đã phát hành",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await approveConfirmedNeedBatch(canvasElement);
    await userEvent.click(confirmedNeedNextAction(canvasElement));
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xác nhận phát hành" }),
    );
    await canvas.findByText("Đã phát hành lô nhu cầu sang bước lên đơn.");
  },
};

export const ConfirmedNeedUnknownWriteOutcome: Story = {
  name: "Xác nhận nhu cầu · kết quả ghi chưa xác định",
  args: { initialPage: "planning-inputs", reviewMode: true },
  render: () => <ConfirmedNeedStateStory unknownConfirm />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await prepareConfirmedNeedPreview(canvasElement);
    await userEvent.click(
      canvas.getByLabelText("Tôi đã kiểm tra bản xem trước số lượng"),
    );
    await userEvent.click(confirmedNeedNextAction(canvasElement));
    await canvas.findByRole("button", {
      name: "Gửi lại đúng lệnh chưa chắc chắn",
    });
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
