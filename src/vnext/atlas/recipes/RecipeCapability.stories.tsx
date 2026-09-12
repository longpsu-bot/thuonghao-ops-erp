import type { Meta, StoryObj } from "@storybook/react-vite";
import { Text } from "@chakra-ui/react";
import { useEffect, useMemo, useState } from "react";
import { userEvent, within, waitFor } from "storybook/test";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { AtlasVNextShell } from "../AtlasVNextShell";
import { RecipeCapability } from "./RecipeCapability";
import { createRecipeReviewFixture } from "./recipeReviewFixtures";
import {
  changeDate,
  createChangeOrderFixture,
  type ChangeOrderScenario,
} from "./changeOrderReviewFixtures";
function Review({
  scenario = "ACTIVE",
  job = "changes",
}: {
  scenario?: ChangeOrderScenario;
  job?: "recipes" | "changes";
}) {
  const base = useMemo(
    () => createRecipeReviewFixture("DISH_ACTIVE_EDITABLE"),
    [],
  );
  const changes = useMemo(() => createChangeOrderFixture(scenario), [scenario]);
  const [subject, setSubject] = useState("review-operator");
  useEffect(() => {
    if (scenario !== "AUTH_CHANGE_DELAYED_RESPONSE") return;
    const timer = setTimeout(() => setSubject("next-operator"), 30);
    return () => clearTimeout(timer);
  }, [scenario]);
  return (
    <AtlasVNextProvider>
      <AtlasVNextShell activeModule="Công thức">
        <Text textStyle="helper" color="fg.muted" mb="sm">
          Chế độ xem thử giao diện — dữ liệu không được lưu
        </Text>
        <RecipeCapability
          authSubject={subject}
          recipeApi={base.api}
          adjustmentApi={changes.api}
          initialDate={changeDate}
          initialJob={job}
        />
      </AtlasVNextShell>
    </AtlasVNextProvider>
  );
}
const meta = {
  title: "Atlas/Recipes/Unified Recipe Capability",
  component: Review,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Review>;
export default meta;
type Story = StoryObj<typeof meta>;
const createEditor =
  (scenario: ChangeOrderScenario): Story["play"] =>
  async ({ canvasElement }) => {
    const c = within(canvasElement);
    const select = async (label: string, value: string) =>
      userEvent.selectOptions(await c.findByLabelText(label), value);
    await userEvent.click(
      await c.findByRole("button", { name: "Tạo lệnh điều chỉnh" }),
    );
    const ingredient =
      scenario === "SYSTEM_INGREDIENT_CREATE" || scenario === "SCHOOL_CREATE";
    const school =
      scenario === "SCHOOL_CREATE" || scenario === "SCHOOL_DISH_CREATE";
    if (ingredient) await select("Điều chỉnh", "ingredient");
    if (school) {
      await select("Áp dụng cho", "one");
      await select("Trường", "school-0");
    }
    if (!ingredient) {
      await select("Món", "dish-0");
      if (!school) await select("Loại công thức", "scope-0");
    }
    const action =
      scenario === "ACTION_REMOVE"
        ? "REMOVE"
        : scenario === "ACTION_ADJUST_QUANTITY"
          ? "ADJUST_QUANTITY"
          : scenario === "ACTION_ADD" || scenario === "SYSTEM_DISH_ADD"
            ? "ADD"
            : "REPLACE";
    await select("Hành động", action);
    if (ingredient) {
      await select("Nguyên liệu", "ingredient-0");
      if (!school) await select("Trường kiểm tra", "school-0");
      await select("Món kiểm tra", "dish-0");
    } else if (action !== "ADD") {
      await waitFor(() => {
        if (
          (c.getByLabelText("Thành phần hiện tại") as HTMLSelectElement)
            .disabled
        )
          throw new Error("Loading targets");
      });
      await select(
        "Thành phần hiện tại",
        scenario === "SYSTEM_DISH_TARGET_PRIOR_ADD"
          ? "ADJUSTMENT_LINE:prior-add-line"
          : "RECIPE_LINE:base-line",
      );
    }
    if (action === "REPLACE")
      await select("Nguyên liệu thay thế", "ingredient-3");
    if (action === "ADD") await select("Nguyên liệu thêm", "ingredient-3");
    if (["ADD", "ADJUST_QUANTITY"].includes(action))
      await userEvent.type(c.getByLabelText("Định lượng mới"), "1,5");
    await userEvent.type(
      c.getByLabelText("Lý do điều chỉnh"),
      "Điều chỉnh theo thực đơn đã thống nhất",
    );
  };
const preview =
  (scenario: ChangeOrderScenario): Story["play"] =>
  async (context) => {
    await createEditor(scenario)!(context);
    const c = within(context.canvasElement);
    await userEvent.click(c.getByRole("button", { name: "Xem tác động" }));
    await c.findByRole("dialog", { name: "Xem tác động" });
    if (scenario === "SYSTEM_DISH_SCHOOL_INSPECTION") {
      await userEvent.click(c.getByText("Kiểm tra tại một trường"));
      await userEvent.selectOptions(
        c.getByLabelText("Kiểm tra tác động tại trường"),
        "school-0",
      );
      await c.findByRole("table", { name: "Công thức tại trường" });
    }
    if (
      [
        "UNKNOWN_CREATE",
        "FAILED_UNKNOWN_RECOVERY",
        "SUCCESS_READBACK",
        "STALE",
        "PERMISSION_DENIED",
      ].includes(scenario)
    ) {
      await userEvent.click(
        c.getByRole("button", { name: "Lưu lệnh điều chỉnh" }),
      );
      if (scenario === "FAILED_UNKNOWN_RECOVERY")
        await userEvent.click(
          await c.findByRole("button", { name: "Tải lại để xác nhận" }),
        );
    }
  };
const detail: Story["play"] = async ({ canvasElement }) => {
  const c = within(canvasElement);
  await userEvent.selectOptions(await c.findByLabelText("Tình trạng"), "all");
  await userEvent.click(
    await c.findByRole("button", {
      name: "Xem lệnh Thay nguyên liệu Canh bí đỏ thịt bằm",
    }),
  );
};
const correction: Story["play"] = async (context) => {
  await detail!(context);
  const c = within(context.canvasElement);
  await userEvent.click(c.getByRole("button", { name: "Sửa lệnh" }));
  await userEvent.clear(c.getByLabelText("Lý do điều chỉnh"));
  await userEvent.type(
    c.getByLabelText("Lý do điều chỉnh"),
    "Cập nhật thời gian theo kế hoạch mới",
  );
  await waitFor(() => {
    if (
      (c.getByRole("button", { name: "Xem tác động" }) as HTMLButtonElement)
        .disabled
    )
      throw new Error("Loading targets");
  });
  await userEvent.click(c.getByRole("button", { name: "Xem tác động" }));
  await c.findByRole("dialog", { name: "Xem tác động" });
};
const cancellation: Story["play"] = async (context) => {
  await detail!(context);
  const c = within(context.canvasElement);
  await userEvent.click(c.getByRole("button", { name: "Hủy lệnh" }));
  await c.findByRole("dialog", { name: "Hủy lệnh" });
  await userEvent.type(
    c.getByLabelText("Lý do hủy"),
    "Thực đơn không còn áp dụng thay thế",
  );
};
export const BaseRecipe: Story = {
  args: { job: "recipes" },
  play: async ({ canvasElement }) => {
    const c = within(canvasElement);
    await userEvent.click(
      await c.findByRole("button", {
        name: "Xem công thức Canh bí đỏ thịt bằm",
      }),
    );
  },
};
export const Landing: Story = {};
export const Empty: Story = { args: { scenario: "EMPTY" } };
export const SystemDishCreate: Story = {
  play: createEditor("SYSTEM_DISH_CREATE"),
};
export const SystemDishPreview: Story = {
  play: preview("SYSTEM_DISH_PREVIEW"),
};
export const SystemDishSchoolInspection: Story = {
  play: preview("SYSTEM_DISH_SCHOOL_INSPECTION"),
};
export const SystemDishAdd: Story = { play: createEditor("SYSTEM_DISH_ADD") };
export const SystemDishTargetPriorAdd: Story = {
  play: createEditor("SYSTEM_DISH_TARGET_PRIOR_ADD"),
};
export const SchoolDishCreate: Story = {
  play: createEditor("SCHOOL_DISH_CREATE"),
};
export const SchoolCreate: Story = { play: createEditor("SCHOOL_CREATE") };
export const SystemIngredientCreate: Story = {
  play: createEditor("SYSTEM_INGREDIENT_CREATE"),
};
export const ActionReplace: Story = { play: preview("ACTION_REPLACE") };
export const ActionAdjustQuantity: Story = {
  play: preview("ACTION_ADJUST_QUANTITY"),
};
export const ActionAdd: Story = { play: preview("ACTION_ADD") };
export const ActionRemove: Story = { play: preview("ACTION_REMOVE") };
export const Active: Story = { args: { scenario: "ACTIVE" }, play: detail };
export const Scheduled: Story = {
  args: { scenario: "SCHEDULED" },
  play: detail,
};
export const ActiveChangeScheduled: Story = {
  args: { scenario: "ACTIVE_CHANGE_SCHEDULED" },
  play: detail,
};
export const ActiveCancellationScheduled: Story = {
  args: { scenario: "ACTIVE_CANCELLATION_SCHEDULED" },
  play: detail,
};
export const ActiveResumed: Story = {
  args: { scenario: "ACTIVE_RESUMED" },
  play: detail,
};
export const Expired: Story = { args: { scenario: "EXPIRED" }, play: detail };
export const Cancelled: Story = {
  args: { scenario: "CANCELLED" },
  play: detail,
};
export const Correctable: Story = { play: detail };
export const Cancellable: Story = { play: detail };
export const LegacyUnattributedHistory: Story = {
  args: { scenario: "LEGACY_UNATTRIBUTED_HISTORY" },
  play: detail,
};
export const SupersedePreview: Story = { play: correction };
export const CancelDialog: Story = { play: cancellation };
export const PreviewBlocked: Story = {
  args: { scenario: "PREVIEW_BLOCKED" },
  play: preview("PREVIEW_BLOCKED"),
};
export const PreviewWarning: Story = {
  args: { scenario: "PREVIEW_WARNING" },
  play: preview("PREVIEW_WARNING"),
};
export const Stale: Story = {
  args: { scenario: "STALE" },
  play: preview("STALE"),
};
export const UnknownCreate: Story = {
  args: { scenario: "UNKNOWN_CREATE" },
  play: preview("UNKNOWN_CREATE"),
};
export const UnknownSupersede: Story = {
  args: { scenario: "UNKNOWN_SUPERSEDE" },
  play: async (context) => {
    await correction!(context);
    const c = within(context.canvasElement);
    await userEvent.click(c.getByRole("button", { name: "Lưu sửa lệnh" }));
  },
};
export const UnknownCancel: Story = {
  args: { scenario: "UNKNOWN_CANCEL" },
  play: async (context) => {
    await cancellation!(context);
    const c = within(context.canvasElement);
    await userEvent.click(c.getByRole("button", { name: "Xác nhận hủy" }));
  },
};
export const FailedUnknownRecovery: Story = {
  args: { scenario: "FAILED_UNKNOWN_RECOVERY" },
  play: preview("FAILED_UNKNOWN_RECOVERY"),
};
export const SuccessReadback: Story = {
  args: { scenario: "SUCCESS_READBACK" },
  play: preview("SUCCESS_READBACK"),
};
export const PermissionDenied: Story = {
  args: { scenario: "PERMISSION_DENIED" },
  play: preview("PERMISSION_DENIED"),
};
export const ReadFailure: Story = { args: { scenario: "READ_FAILURE" } };
export const AuthChangeDelayedResponse: Story = {
  args: { scenario: "AUTH_CHANGE_DELAYED_RESPONSE" },
};
export const Mobile: Story = {
  args: { scenario: "MOBILE" },
  play: createEditor("SCHOOL_DISH_CREATE"),
  globals: { viewport: { value: "mobile1", isRotated: false } },
};
