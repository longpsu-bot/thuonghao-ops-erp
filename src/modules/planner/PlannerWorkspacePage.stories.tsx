import type { Meta, StoryObj } from "@storybook/react-vite";
import { PlannerWorkspacePage } from "./PlannerWorkspacePage";

const meta = {
  title: "Atlas/Lập nhu cầu/Không gian rà soát",
  component: PlannerWorkspacePage,
  parameters: {
    docs: {
      description: {
        component:
          "Prototype dùng fixture cục bộ. Số lượng và truy vết chỉ phục vụ góp ý UI, không phải kết quả nghiệp vụ.",
      },
    },
  },
} satisfies Meta<typeof PlannerWorkspacePage>;

export default meta;
type Story = StoryObj<typeof meta>;

export const NormalPlanner: Story = {
  name: "Trạng thái kế hoạch bình thường",
  args: { reviewScenario: "normal" },
};

export const ExceptionFirst: Story = {
  name: "Ưu tiên ngoại lệ cần xử lý",
  args: { reviewScenario: "exception-first" },
};

export const BlockedOrMissingData: Story = {
  name: "Bị chặn hoặc thiếu dữ liệu",
  args: { reviewScenario: "blocked" },
};
