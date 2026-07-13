import type { Meta, StoryObj } from "@storybook/react-vite";
import { AtlasApp } from "./AtlasApp";

const meta = {
  title: "Atlas/Bàn điều hành và bàn giao",
  component: AtlasApp,
  parameters: {
    docs: {
      description: {
        component:
          "Các trang hiển thị mẫu bàn giao vận hành. Thao tác chỉ phản hồi cục bộ và không tạo chứng từ, dữ liệu hay sự kiện thật.",
      },
    },
  },
} satisfies Meta<typeof AtlasApp>;

export default meta;
type Story = StoryObj<typeof meta>;

export const ExceptionFirstControlBoard: Story = {
  name: "Bảng điều hành — ưu tiên ngoại lệ",
  args: { initialPage: "control-board" },
};

export const PurchasePlanning: Story = {
  name: "Lập kế hoạch mua hàng — thiếu phân bổ NCC",
  args: { initialPage: "purchase-planning" },
};

export const DocumentRelease: Story = {
  name: "Phát hành đơn / phiếu — cần rà soát chênh lệch",
  args: { initialPage: "document-release" },
};

export const WarehouseReceivingPlaceholder: Story = {
  name: "Nhập kho — ghi chú workflow mẫu",
  args: { initialPage: "warehouse-receiving" },
  parameters: {
    docs: {
      description: {
        story:
          "Đây là ghi chú workflow nhận hàng mẫu, chưa phải quy trình kho, chứng từ, tồn kho hay đối soát có hiệu lực.",
      },
    },
  },
};
