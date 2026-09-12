import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useMemo } from "react";
import { userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { IngredientSupplierWorkbench } from "./IngredientSupplierWorkbench";
import {
  createIngredientSupplierReviewFixture,
  type IngredientSupplierScenario,
} from "./ingredientSupplierReviewFixtures";

function Review({
  scenario = "INGREDIENTS_DENSE_360",
}: {
  scenario?: IngredientSupplierScenario;
}) {
  const api = useMemo(
    () => createIngredientSupplierReviewFixture(scenario),
    [scenario],
  );
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Nguyên liệu và Nhà cung ứng">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Chế độ xem thử giao diện — dữ liệu không được lưu
        </Text>
        <IngredientSupplierWorkbench authSubject="review-operator" api={api} />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}

const meta = {
  title: "Atlas/Master Data/Ingredient Supplier Workbench",
  component: Review,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Review>;
export default meta;
type Story = StoryObj<typeof meta>;

async function openIngredient(canvas: ReturnType<typeof within>, name: string) {
  await userEvent.click(
    await canvas.findByRole("button", {
      name: new RegExp(`^(Xem / sửa|Xem) ${name}$`),
    }),
  );
}
async function dirtyIngredient(canvas: ReturnType<typeof within>) {
  await openIngredient(canvas, "Rau muống");
  const input = await canvas.findByLabelText("Tên nguyên liệu");
  await userEvent.clear(input);
  await userEvent.type(input, "Rau muống sạch");
}
async function supplierJob(canvas: ReturnType<typeof within>) {
  await userEvent.click(
    await canvas.findByRole("tab", { name: "Nhà cung ứng" }),
  );
}

export const DenseIngredientLanding: Story = {
  args: { scenario: "INGREDIENTS_DENSE_360" },
};
export const IngredientAttachedDetail: Story = {
  args: { scenario: "INGREDIENT_ACTIVE" },
  play: async ({ canvasElement }) =>
    openIngredient(within(canvasElement), "Rau muống"),
};
export const IngredientCreate: Story = {
  args: { scenario: "INGREDIENT_CREATE" },
  play: async ({ canvasElement }) => {
    await userEvent.click(
      await within(canvasElement).findByRole("button", {
        name: "Tạo nguyên liệu",
      }),
    );
  },
};
export const IngredientDirtyEdit: Story = {
  args: { scenario: "INGREDIENT_DIRTY" },
  play: async ({ canvasElement }) => dirtyIngredient(within(canvasElement)),
};
export const IngredientReview: Story = {
  args: { scenario: "INGREDIENT_REVIEW" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await dirtyIngredient(canvas);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xem thay đổi" }),
    );
  },
};
export const ActiveLifecycleConfirm: Story = {
  args: { scenario: "LIFECYCLE_DEACTIVATE" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await openIngredient(canvas, "Rau muống");
    await userEvent.click(
      await canvas.findByRole("button", { name: "Ngừng dùng" }),
    );
  },
};
export const InactiveLifecycleChoices: Story = {
  args: { scenario: "LIFECYCLE_REACTIVATE" },
  play: async ({ canvasElement }) =>
    openIngredient(within(canvasElement), "Cà rốt Đà Lạt"),
};
export const ArchivedReadOnly: Story = {
  args: { scenario: "INGREDIENT_ARCHIVED" },
  play: async ({ canvasElement }) =>
    openIngredient(within(canvasElement), "Thịt heo nạc"),
};
export const PrioritySix: Story = {
  args: { scenario: "PRIORITY_SIX" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await openIngredient(canvas, "Nguyên liệu sơ chế 009");
    await userEvent.click(
      await canvas.findByRole("button", { name: "Ưu tiên NCC" }),
    );
  },
};
export const PriorityInvalidDuplicate: Story = {
  args: { scenario: "PRIORITY_DUPLICATE_SUPPLIER" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await openIngredient(canvas, "Rau muống");
    await userEvent.click(
      await canvas.findByRole("button", { name: "Ưu tiên NCC" }),
    );
    const selects = await canvas.findAllByLabelText(/Nhà cung ứng ưu tiên/);
    await userEvent.selectOptions(selects[1]!, "supplier-01");
  },
};
export const PriorityInactiveSupplier: Story = {
  args: { scenario: "PRIORITY_INACTIVE_SUPPLIER" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await openIngredient(canvas, "Rau muống");
    await userEvent.click(
      await canvas.findByRole("button", { name: "Ưu tiên NCC" }),
    );
  },
};
export const EmptyPriorityReplacement: Story = {
  args: { scenario: "PRIORITY_EMPTY_REPLACEMENT" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await openIngredient(canvas, "Rau muống");
    await userEvent.click(
      await canvas.findByRole("button", { name: "Ưu tiên NCC" }),
    );
    for (const button of await canvas.findAllByRole("button", { name: /^Gỡ/ }))
      await userEvent.click(button);
  },
};
export const SupplierLanding: Story = {
  args: { scenario: "SUPPLIERS_37" },
  play: async ({ canvasElement }) => supplierJob(within(canvasElement)),
};
export const SupplierEdit: Story = {
  args: { scenario: "SUPPLIER_ACTIVE" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await supplierJob(canvas);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xem / sửa NCC Minh Tâm" }),
    );
  },
};
export const SupplierReview: Story = {
  args: { scenario: "SUPPLIER_DIRTY" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await supplierJob(canvas);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xem / sửa NCC Minh Tâm" }),
    );
    const input = await canvas.findByLabelText("Người liên hệ");
    await userEvent.type(input, "Lan");
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xem thay đổi" }),
    );
  },
};
export const UnknownOutcome: Story = {
  args: { scenario: "INGREDIENT_UNKNOWN" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await dirtyIngredient(canvas);
    await userEvent.click(
      await canvas.findByRole("button", { name: "Xem thay đổi" }),
    );
    await userEvent.click(
      await canvas.findByRole("button", { name: "Lưu nguyên liệu" }),
    );
    await canvas.findByText(
      "Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.",
    );
  },
};
export const ReadFailure: Story = { args: { scenario: "READ_FAILURE" } };
export const Mobile: Story = {
  args: { scenario: "INGREDIENTS_DENSE_360" },
  parameters: { viewport: { defaultViewport: "mobile1" } },
};
