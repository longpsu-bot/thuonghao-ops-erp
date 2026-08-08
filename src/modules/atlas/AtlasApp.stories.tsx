import type { Meta, StoryObj } from "@storybook/react-vite";
import { userEvent, within } from "storybook/test";
import { AtlasAppView as AtlasApp } from "./AtlasApp";

const meta = {
  title: "Atlas/Dữ liệu gốc",
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
