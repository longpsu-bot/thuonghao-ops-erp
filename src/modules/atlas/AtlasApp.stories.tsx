import type { Meta, StoryObj } from "@storybook/react-vite";
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
  name: "Nền tảng Modern Operations · Kế hoạch",
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
  name: "Trạng thái cảnh báo",
  args: {
    initialPage: "planning-inputs",
    initialReviewScenario: "menu_recipe_warning",
    reviewMode: true,
  },
};

export const BlockingState: Story = {
  name: "Trạng thái chặn / lỗi",
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
  name: "Vỏ ứng dụng di động · 360 px",
  args: {
    initialPage: "planning-inputs",
    reviewMode: true,
  },
  parameters: {
    viewport: { defaultViewport: "mobile1" },
  },
};
