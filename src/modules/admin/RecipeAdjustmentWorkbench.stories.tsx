import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { expect, userEvent, waitFor, within } from "storybook/test";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
import { RecipeAdjustmentWorkbench } from "./RecipeAdjustmentWorkbench";

const schoolId = "11000000-0000-4000-8000-000000000001";
const priorSystemAddLineId = "1a000000-0000-4000-8000-000000000002";
const potatoId = "17000000-0000-4000-8000-000000000004";

function AdjustmentStory({
  scenario = "ready",
  unknownMutation = false,
}: {
  scenario?: "ready" | "permission_denied";
  unknownMutation?: boolean;
}) {
  const [api] = useState(() => {
    const next = createReviewRecipeAdjustmentApi(scenario);
    if (unknownMutation) {
      next.create = async () => ({
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Chưa xác định điều chỉnh đã được ghi nhận hay chưa.",
        },
      });
    }
    return next;
  });
  return (
    <main className="atlas-page">
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        view="rules"
        mode="review"
      />
    </main>
  );
}

const meta = {
  title: "Atlas/Recipe adjustment convergence",
  component: AdjustmentStory,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof AdjustmentStory>;

export default meta;
type Story = StoryObj<typeof meta>;

async function openPriorAddTarget(canvasElement: HTMLElement) {
  const page = within(canvasElement.ownerDocument.body);
  await userEvent.click(
    await page.findByRole("button", { name: "Tạo điều chỉnh" }),
  );
  const dialog = await page.findByRole("dialog", { name: "Tạo điều chỉnh" });
  await userEvent.click(within(dialog).getByLabelText("Một trường"));
  await userEvent.selectOptions(
    within(dialog).getByLabelText("Trường"),
    schoolId,
  );
  const dish = within(dialog).getByLabelText("Món");
  await userEvent.click(dish);
  await userEvent.type(dish, "bí đỏ");
  await userEvent.click(
    await page.findByRole("option", { name: "Canh bí đỏ" }),
  );
  await userEvent.click(within(dialog).getByLabelText("Thay nguyên liệu"));
  const target = within(dialog).getByLabelText("Nguyên liệu trong công thức");
  await waitFor(() =>
    expect(
      within(target).getByRole("option", {
        name: /Gia vị thiếu đơn vị · 1,25/,
      }),
    ).toHaveValue(priorSystemAddLineId),
  );
  await userEvent.selectOptions(target, priorSystemAddLineId);
  return dialog;
}

export const PriorAddTarget: Story = {
  play: async ({ canvasElement }) => {
    const dialog = await openPriorAddTarget(canvasElement);
    await expect(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
    ).toHaveValue(priorSystemAddLineId);
  },
};

export const TemporalAndLegacyLedger: Story = {};

export const DeniedReadRecovery: Story = {
  args: { scenario: "permission_denied" },
};

export const UnknownMutationRecovery: Story = {
  args: { unknownMutation: true },
  play: async ({ canvasElement }) => {
    const page = within(canvasElement.ownerDocument.body);
    const dialog = await openPriorAddTarget(canvasElement);
    await userEvent.selectOptions(
      within(dialog).getByLabelText("Thay bằng"),
      potatoId,
    );
    await userEvent.type(
      within(dialog).getByLabelText("Lý do"),
      "Kiểm tra phục hồi kết quả chưa xác định.",
    );
    await userEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await page.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    await userEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await expect(await page.findByRole("alert")).toHaveTextContent(
      /Không gửi lại thao tác/i,
    );
  },
};
