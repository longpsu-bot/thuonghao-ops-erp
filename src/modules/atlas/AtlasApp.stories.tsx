import type { Meta, StoryObj } from "@storybook/react-vite";
import { AtlasApp } from "./AtlasApp";

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
