import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { userEvent, within } from "storybook/test";
import { AtlasAppView as AtlasApp } from "./AtlasApp";
import { createReviewAuthState } from "./review/reviewMode";
import { NeedGenerationWorkbench } from "./planning-inputs/need-generation/NeedGenerationWorkbench";
import { createReviewNeedGenerationApi } from "./planning-inputs/need-generation/reviewNeedGenerationApi";

const meta = {
  title: "Atlas/Planning workflow",
  component: AtlasApp,
  parameters: {
    layout: "fullscreen",
    docs: {
      description: {
        component:
          "Bản xem thử hai khu vực dữ liệu gốc thuộc RMVP-01. Mọi thay đổi chỉ tồn tại trong bộ nhớ và mất khi tải lại trang.",
      },
    },
  },
} satisfies Meta<typeof AtlasApp>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Schools: Story = {
  name: "Trường học",
  args: {
    initialPage: "customers-schools",
    reviewMode: true,
  },
};

export const IngredientsAndSuppliers: Story = {
  name: "Nguyên liệu và Nhà cung ứng",
  args: {
    initialPage: "ingredients-units",
    reviewMode: true,
  },
};

export const ModernOperationsShell: Story = {
  name: "Thực đơn tuần · trạng thái bình thường",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
};

export const LongNavigationLabels: Story = {
  name: "Nhãn điều hướng tiếng Việt dài · Quản trị",
  args: {
    initialPage: "ingredients-units",
    reviewMode: true,
  },
};

export const SuccessState: Story = {
  name: "Trạng thái thành công",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_approved",
    reviewMode: true,
  },
};

export const WarningState: Story = {
  name: "Thực đơn tuần · cảnh báo công thức",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_recipe_warning",
    reviewMode: true,
  },
};

export const BlockingState: Story = {
  name: "Thực đơn tuần · lỗi chặn",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_duplicate",
    reviewMode: true,
  },
};

export const ReadOnlyInformationState: Story = {
  name: "Trạng thái chỉ xem / thông tin",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
};

export const MobileShell: Story = {
  name: "Nguồn kế hoạch di động · 360 px",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
  parameters: {
    viewport: { defaultViewport: "mobile1" },
  },
};

async function selectPlanningTab(canvasElement: HTMLElement, name: string) {
  const canvas = within(canvasElement);
  await userEvent.click(await canvas.findByRole("tab", { name }));
  canvasElement.ownerDocument.defaultView?.scrollTo(0, 0);
}

function returnToTop(canvasElement: HTMLElement) {
  canvasElement.ownerDocument.defaultView?.scrollTo(0, 0);
}

async function runNeedGenerationTo(
  canvasElement: HTMLElement,
  target: "generated" | "validated" | "released" | "materialized",
) {
  const canvas = within(canvasElement);
  await selectPlanningTab(canvasElement, "Tạo nhu cầu");
  await userEvent.click(
    await canvas.findByRole("button", { name: "Tạo nhu cầu" }),
  );
  if (target === "generated") {
    returnToTop(canvasElement);
    return;
  }
  await userEvent.click(
    await canvas.findByRole("button", { name: "Kiểm tra nhu cầu" }),
  );
  if (target === "validated") {
    returnToTop(canvasElement);
    return;
  }
  await userEvent.click(
    await canvas.findByRole("button", { name: "Phát hành nhu cầu" }),
  );
  if (target === "released") {
    returnToTop(canvasElement);
    return;
  }
  await userEvent.click(
    await canvas.findByRole("button", { name: "Tạo nhu cầu xác nhận" }),
  );
  returnToTop(canvasElement);
}

function NeedGenerationEvidenceStory({
  state,
}: {
  state: "handoff-not-requested" | "generated-with-blockers";
}) {
  const [api] = useState(() => {
    const next = createReviewNeedGenerationApi("ready");
    if (state === "handoff-not-requested") {
      const original = next.getWorkbench.bind(next);
      next.getWorkbench = async (...args: Parameters<typeof original>) => {
        const result = await original(...args);
        if (result.kind === "success") {
          const workbench = result.response.workbench as Record<
            string,
            unknown
          >;
          const root = workbench.planning_input_set as Record<string, unknown>;
          root.readiness_status = "READY";
          workbench.allowed_actions = {
            create: false,
            validate: false,
            release: false,
            materialize: false,
            invalidate: false,
          };
          workbench.disabled_reasons = {
            create: "Chưa ghi nhận yêu cầu tạo nhu cầu.",
            validate: "Tạo nhu cầu trước.",
            release: "Kiểm tra nhu cầu trước.",
            materialize: "Phát hành nhu cầu trước.",
            invalidate: "Chưa có lần tạo nhu cầu.",
          };
        }
        return result;
      };
    } else {
      const original = next.create.bind(next);
      next.create = async (...args: Parameters<typeof original>) => {
        const result = await original(...args);
        if (result.kind === "success") {
          const workbench = result.response.authoritative_readback as Record<
            string,
            unknown
          >;
          const run = workbench.selected_run as Record<string, unknown>;
          run.blocking_issue_count = 1;
          workbench.blocking_issues = [
            {
              need_generation_issue_id: "storybook-blocker",
              issue_code: "MISSING_ELIGIBLE_RECIPE",
              message:
                "Thiếu công thức đủ điều kiện cho một dòng Thực đơn đã duyệt.",
            },
          ];
          workbench.allowed_actions = {
            create: false,
            validate: false,
            release: false,
            materialize: false,
            invalidate: true,
          };
          workbench.disabled_reasons = {
            create: "Đã có lần tạo nhu cầu đang hoạt động.",
            validate: "Cần xử lý lỗi chặn trước khi kiểm tra.",
            release: "Kiểm tra nhu cầu trước.",
            materialize: "Phát hành nhu cầu trước.",
            invalidate: null,
          };
        }
        return result;
      };
    }
    return next;
  });

  return (
    <main className="atlas-page">
      <NeedGenerationWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
        mode="review"
      />
    </main>
  );
}

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

export const AttendanceWarning: Story = {
  name: "Sĩ số · cảnh báo khác mặc định",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "attendance_diff_defaults",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sĩ số");
  },
};

export const PantryRows: Story = {
  name: "Pantry · có dòng bổ sung",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Pantry");
  },
};

export const PantryNoAdditions: Story = {
  name: "Pantry · xác nhận không có bổ sung",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
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

export const PantryBlocked: Story = {
  name: "Pantry · không có quyền truy cập",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "permission_denied",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Pantry");
  },
};

export const ReadinessReady: Story = {
  name: "Sẵn sàng đầu vào · sẵn sàng yêu cầu",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sẵn sàng đầu vào");
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    );
    returnToTop(canvasElement);
  },
};

export const ReadinessBlocked: Story = {
  name: "Sẵn sàng đầu vào · lỗi chặn",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "empty",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sẵn sàng đầu vào");
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    );
    returnToTop(canvasElement);
  },
};

export const ReadinessAmbiguous: Story = {
  name: "Sẵn sàng đầu vào · cần chọn bằng chứng",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_duplicate",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sẵn sàng đầu vào");
  },
};

export const ReadinessStale: Story = {
  name: "Sẵn sàng đầu vào · bằng chứng đã cũ",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "stale",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sẵn sàng đầu vào");
  },
};

export const ReadinessRequested: Story = {
  name: "Sẵn sàng đầu vào · đã yêu cầu tạo nhu cầu",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Sẵn sàng đầu vào");
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    );
    await userEvent.click(
      await canvas.findByRole("button", { name: "Yêu cầu tạo nhu cầu" }),
    );
    returnToTop(canvasElement);
  },
};

export const NeedGenerationHandoffNotRequested: Story = {
  name: "Tạo nhu cầu · chưa có bàn giao",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
  render: () => <NeedGenerationEvidenceStory state="handoff-not-requested" />,
};

export const NeedGenerationReadyToCreate: Story = {
  name: "Tạo nhu cầu · sẵn sàng tạo lần chạy",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await selectPlanningTab(canvasElement, "Tạo nhu cầu");
  },
};

export const NeedGenerationGenerated: Story = {
  name: "Tạo nhu cầu · rà soát bảng đã tạo",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await runNeedGenerationTo(canvasElement, "generated");
  },
};

export const NeedGenerationGeneratedWithBlockers: Story = {
  name: "Tạo nhu cầu · lần chạy có lỗi chặn",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
  render: () => <NeedGenerationEvidenceStory state="generated-with-blockers" />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Tạo nhu cầu" }),
    );
    returnToTop(canvasElement);
  },
};

export const NeedGenerationValidated: Story = {
  name: "Tạo nhu cầu · đã kiểm tra",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await runNeedGenerationTo(canvasElement, "validated");
  },
};

export const NeedGenerationReleased: Story = {
  name: "Tạo nhu cầu · sẵn sàng tạo nhu cầu xác nhận",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await runNeedGenerationTo(canvasElement, "released");
  },
};

export const NeedGenerationMaterialized: Story = {
  name: "Tạo nhu cầu · đã tạo Nhu cầu xác nhận",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  play: async ({ canvasElement }) => {
    await runNeedGenerationTo(canvasElement, "materialized");
  },
};

export const MobilePlanningNeedGeneration: Story = {
  name: "Quy trình Lập nhu cầu · di động 360 px",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "ready",
    reviewMode: true,
  },
  parameters: {
    viewport: { defaultViewport: "mobile1" },
  },
  play: async ({ canvasElement }) => {
    await runNeedGenerationTo(canvasElement, "generated");
  },
};
