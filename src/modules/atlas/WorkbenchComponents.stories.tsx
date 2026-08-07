import type { Meta, StoryObj } from "@storybook/react-vite";
import { OperationalState, WorkbenchHeader } from "./WorkbenchComponents";

const meta = {
  title: "Atlas/Shared/Proven primitives",
  component: WorkbenchHeader,
  args: { title: "Nguồn kế hoạch" },
  parameters: { layout: "padded" },
} satisfies Meta<typeof WorkbenchHeader>;

export default meta;
type Story = StoryObj<typeof meta>;

export const ShellAndNestedHeading: Story = {
  render: () => (
    <div style={{ display: "grid", gap: "1.5rem" }}>
      <WorkbenchHeader
        eyebrow="Lập nhu cầu"
        title="Nguồn kế hoạch"
        context="Quản lý nguồn đầu vào theo đúng tuần phục vụ và trạng thái có thẩm quyền."
      />
      <WorkbenchHeader
        eyebrow="Nguồn đầu vào"
        title="Điều hành nguồn kế hoạch theo tuần"
        context="Tiêu đề cấp hai giữ đúng thứ bậc bên trong trang Atlas."
        headingLevel={2}
      />
    </div>
  ),
};

export const OperationalStates: Story = {
  render: () => (
    <div style={{ display: "grid", gap: "1rem", maxWidth: "48rem" }}>
      <OperationalState
        variant="information"
        title="Đang tải nguồn kế hoạch…"
      />
      <OperationalState variant="access-denied" title="Không có quyền truy cập">
        Bạn chưa có quyền xem dữ liệu của tuần phục vụ này. Hãy liên hệ người
        quản trị để kiểm tra phạm vi trường học được phân công trước khi tiếp
        tục.
      </OperationalState>
      <OperationalState
        variant="unknown-outcome"
        title="Chưa xác định kết quả phê duyệt"
        onAuthoritativeRefresh={() => undefined}
      />
    </div>
  ),
};

export const NarrowLongVietnameseText: Story = {
  parameters: { viewport: { defaultViewport: "mobile1" } },
  render: () => (
    <div style={{ width: "min(100%, 22.5rem)" }}>
      <OperationalState
        variant="warning"
        title="Nguồn dữ liệu đã thay đổi trong khi bạn đang rà soát"
      >
        Hãy tải lại dữ liệu có thẩm quyền và kiểm tra lại toàn bộ trường học,
        ngày phục vụ, món ăn và số suất trước khi quyết định bước tiếp theo.
      </OperationalState>
    </div>
  ),
};
