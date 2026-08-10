import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { userEvent, within } from "storybook/test";
import { AtlasAppView as AtlasApp } from "./AtlasApp";
import { createReviewAuthState } from "./review/reviewMode";
import { NeedGenerationWorkbench } from "./planning-inputs/need-generation/NeedGenerationWorkbench";
import { createReviewNeedGenerationApi } from "./planning-inputs/need-generation/reviewNeedGenerationApi";
import { createReviewPlanningInputReadinessApi } from "./planning-inputs/readiness/reviewPlanningInputReadinessApi";

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
