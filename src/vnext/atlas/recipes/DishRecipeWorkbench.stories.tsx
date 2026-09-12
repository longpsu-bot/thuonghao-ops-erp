import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useEffect, useMemo, useState } from "react";
import { userEvent, within } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { DishRecipeWorkbench } from "./DishRecipeWorkbench";
import {
  createRecipeReviewFixture,
  recipeFixtureDate,
  type RecipeScenario,
} from "./recipeReviewFixtures";
import { recipeReviewWorkbook } from "./recipeReviewWorkbook";
function Review({
  scenario = "DISH_ACTIVE_EDITABLE",
}: {
  scenario?: RecipeScenario;
}) {
  const fixture = useMemo(
    () => createRecipeReviewFixture(scenario),
    [scenario],
  );
  const [subject, setSubject] = useState("review-operator");
  useEffect(() => {
    if (scenario !== "AUTH_CHANGE_DELAYED_RESPONSE") return;
    const timer = setTimeout(() => setSubject("next-review-operator"), 30);
    return () => clearTimeout(timer);
  }, [scenario]);
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Công thức">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Chế độ xem thử giao diện — dữ liệu không được lưu
        </Text>
        <DishRecipeWorkbench
          authSubject={subject}
          api={fixture.api}
          initialDate={recipeFixtureDate}
        />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas/Recipes/Dish Recipe Workbench",
  component: Review,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Review>;
export default meta;
type Story = StoryObj<typeof meta>;
const select: Story["play"] = async ({ canvasElement }) => {
  const c = within(canvasElement);
  await userEvent.click(
    await c.findByRole("button", { name: "Xem công thức Canh bí đỏ thịt bằm" }),
  );
  await c.findByRole("heading", { name: "Công thức gốc" });
};
const dirty: Story["play"] = async (context) => {
  await select(context);
  const c = within(context.canvasElement);
  const input = await c.findByLabelText("Định lượng Bí đỏ");
  await userEvent.clear(input);
  await userEvent.type(input, "30");
};
const review: Story["play"] = async (context) => {
  await dirty(context);
  await userEvent.click(
    within(context.canvasElement).getByRole("button", { name: "Xem thay đổi" }),
  );
};
const save: Story["play"] = async (context) => {
  await review(context);
  await userEvent.click(
    within(context.canvasElement).getByRole("button", {
      name: "Lưu công thức",
    }),
  );
};
const copy: Story["play"] = async (context) => {
  await select(context);
  await userEvent.click(
    within(context.canvasElement).getByRole("button", {
      name: "Sao chép công thức",
    }),
  );
};
const copyResult: Story["play"] = async (context) => {
  await copy(context);
  const c = within(context.canvasElement);
  await userEvent.selectOptions(c.getByLabelText("Món nguồn"), "dish-1");
  await userEvent.type(
    c.getByLabelText("Lý do sao chép"),
    "Dùng định lượng mẫu",
  );
  await userEvent.click(c.getByRole("button", { name: "Xác nhận sao chép" }));
};
const imported =
  (invalid = false, apply = false): Story["play"] =>
  async (context) => {
    const c = within(context.canvasElement);
    await userEvent.click(
      await c.findByRole("button", { name: "Nhập workbook" }),
    );
    await userEvent.upload(
      c.getByLabelText("Chọn workbook .xlsx"),
      await recipeReviewWorkbook(invalid),
    );
    await c.findByText(/Kết quả kiểm tra:/);
    if (apply) {
      await userEvent.type(
        c.getByLabelText("Lý do nhập workbook"),
        "Nhập dữ liệu đã kiểm tra",
      );
      await userEvent.click(
        c.getByRole("button", { name: "Áp dụng workbook" }),
      );
    }
  };
export const Catalogue: Story = {};
export const EmptyCatalog: Story = { args: { scenario: "EMPTY_CATALOG" } };
export const DishActiveEditable: Story = { play: select };
export const DishActiveLocked: Story = {
  args: { scenario: "DISH_ACTIVE_LOCKED" },
  play: select,
};
export const DishInactive: Story = {
  args: { scenario: "DISH_INACTIVE" },
  play: select,
};
export const DishDraftLegacy: Story = {
  args: { scenario: "DISH_DRAFT_LEGACY" },
  play: select,
};
export const DishCreate: Story = {
  play: async ({ canvasElement }) =>
    userEvent.click(
      await within(canvasElement).findByRole("button", { name: "Tạo món mới" }),
    ),
};
export const DishEdit: Story = {
  play: async (context) => {
    await select(context);
    await userEvent.click(
      within(context.canvasElement).getByRole("button", {
        name: "Sửa thông tin món",
      }),
    );
  },
};
export const DishNameConflict: Story = {
  args: { scenario: "DISH_NAME_CONFLICT" },
  play: async (context) => {
    await DishCreate.play!(context);
    const c = within(context.canvasElement);
    await userEvent.type(c.getByLabelText("Tên món"), "Canh bí đỏ thịt bằm");
    await userEvent.selectOptions(
      c.getByLabelText("Loại món của món"),
      "type-0",
    );
    await userEvent.click(c.getByRole("button", { name: "Tạo món" }));
  },
};
export const DishStatusReadOnly: Story = { play: select };
export const RecipeEmptyScope: Story = {
  args: { scenario: "RECIPE_EMPTY_SCOPE" },
  play: select,
};
export const RecipeReadyBase: Story = { play: select };
export const RecipeDirty: Story = { play: dirty };
export const RecipeReview: Story = { play: review };
export const RecipeInvalidBasis: Story = {
  play: async (context) => {
    await select(context);
    const input = within(context.canvasElement).getByLabelText(
      "Số suất áp dụng cho định lượng",
    );
    await userEvent.clear(input);
    await userEvent.type(input, "1.5");
  },
};
export const RecipeInvalidQuantity: Story = {
  play: async (context) => {
    await select(context);
    const input = within(context.canvasElement).getByLabelText(
      "Định lượng Bí đỏ",
    );
    await userEvent.clear(input);
    await userEvent.type(input, "0");
  },
};
export const RecipeDuplicateIngredient: Story = {
  args: { scenario: "RECIPE_DUPLICATE_INGREDIENT" },
  play: select,
};
export const RecipeEffectiveDiffersFromBase: Story = {
  args: { scenario: "RECIPE_EFFECTIVE_DIFFERS_FROM_BASE" },
  play: select,
};
export const RecipeEffectiveBlocked: Story = {
  args: { scenario: "RECIPE_EFFECTIVE_BLOCKED" },
  play: select,
};
export const RecipeOperationallyLocked: Story = {
  args: { scenario: "RECIPE_OPERATIONALLY_LOCKED" },
  play: select,
};
export const SaveSuccess: Story = {
  args: { scenario: "SAVE_SUCCESS" },
  play: save,
};
export const SaveStale: Story = {
  args: { scenario: "SAVE_STALE" },
  play: save,
};
export const SaveUnknown: Story = {
  args: { scenario: "SAVE_UNKNOWN" },
  play: save,
};
export const SaveSuccessReadbackFailure: Story = {
  args: { scenario: "SAVE_SUCCESS_READBACK_FAILURE" },
  play: save,
};
export const CopyEligible: Story = {
  args: { scenario: "COPY_ELIGIBLE" },
  play: copy,
};
export const CopyIneligible: Story = {
  args: { scenario: "COPY_INELIGIBLE" },
  play: select,
};
export const CopySuccess: Story = {
  args: { scenario: "COPY_SUCCESS" },
  play: copyResult,
};
export const CopyUnknown: Story = {
  args: { scenario: "COPY_UNKNOWN" },
  play: copyResult,
};
export const ImportValid: Story = {
  args: { scenario: "IMPORT_VALID" },
  play: imported(),
};
export const ImportWithErrors: Story = {
  args: { scenario: "IMPORT_WITH_ERRORS" },
  play: imported(true),
};
export const ImportSuccess: Story = {
  args: { scenario: "IMPORT_SUCCESS" },
  play: imported(false, true),
};
export const ImportUnknown: Story = {
  args: { scenario: "IMPORT_UNKNOWN" },
  play: imported(false, true),
};
export const PermissionDenied: Story = {
  args: { scenario: "PERMISSION_DENIED" },
};
export const ReadFailure: Story = { args: { scenario: "READ_FAILURE" } };
export const AuthChangeDelayedResponse: Story = {
  args: { scenario: "AUTH_CHANGE_DELAYED_RESPONSE" },
};
