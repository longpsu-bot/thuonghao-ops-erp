import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { expect, userEvent, within } from "storybook/test";
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
import type { RecipeApi } from "../atlas/recipes/recipeApi";
import { createReviewRecipeApi } from "../atlas/recipes/reviewRecipeApi";
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { DishRecipeAdminWorkbench } from "./DishRecipeAdminWorkbench";

type Scenario = "root-only" | "locked" | "school" | "copy-readback-failed";

function createLockedApi(): RecipeApi {
  const api = createReviewRecipeApi("ready");
  const getEffectiveWorkbench = api.getEffectiveWorkbench;
  api.getEffectiveWorkbench = async (...args) => {
    const result = await getEffectiveWorkbench(...args);
    if (result.kind !== "success") return result;
    const workbench = (result.response.workbench ?? result.response) as {
      base_authoring: {
        business_status: string;
        locked_for_normal_editing: boolean;
        lock_reason: string | null;
        allowed_actions: { save_recipe: boolean; release_recipe: boolean };
        disabled_reason_codes: {
          save_recipe: string | null;
          release_recipe: string | null;
        };
        disabled_reasons: {
          save_recipe: string | null;
          release_recipe: string | null;
        };
      };
      editable_state: string;
      is_editable: boolean;
      is_operationally_locked: boolean;
      allowed_actions: string[];
    };
    workbench.base_authoring.business_status = "LOCKED";
    workbench.base_authoring.locked_for_normal_editing = true;
    workbench.base_authoring.lock_reason =
      "Món này đã xuất hiện trong thực đơn tuần đã duyệt nên toàn bộ món — gồm cả hai công thức theo loại trường — bị khóa chỉnh sửa thông thường. Muốn thay đổi thành phần, hãy dùng Lệnh điều chỉnh.";
    workbench.base_authoring.allowed_actions.save_recipe = false;
    workbench.base_authoring.disabled_reason_codes.save_recipe =
      "SAVE_OPERATIONALLY_LOCKED";
    workbench.base_authoring.disabled_reasons.save_recipe =
      workbench.base_authoring.lock_reason;
    workbench.editable_state = "LOCKED_CHANGE_ORDER";
    workbench.is_editable = false;
    workbench.is_operationally_locked = true;
    workbench.allowed_actions = ["CREATE_CHANGE_ORDER"];
    return result;
  };
  return api;
}

function createCopyReadbackFailureApi(): RecipeApi {
  const api = createReviewRecipeApi("ready");
  const copyDishRecipes = api.copyDishRecipes;
  const getEffectiveWorkbench = api.getEffectiveWorkbench;
  let copied = false;
  let failed = false;
  api.copyDishRecipes = async (request) => {
    const result = await copyDishRecipes(request);
    copied = result.kind === "success";
    return result;
  };
  api.getEffectiveWorkbench = async (...args) => {
    const context = args[4];
    if (
      copied &&
      !failed &&
      context.kind === "system" &&
      context.schoolTypeId === "60000000-0000-4000-8000-000000000002"
    ) {
      failed = true;
      return {
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Readback unavailable after committed copy.",
        },
      } satisfies AtlasRpcResult;
    }
    return getEffectiveWorkbench(...args);
  };
  return api;
}

function RecipeScenarioStory({ scenario }: { scenario: Scenario }) {
  const [api] = useState(() =>
    scenario === "locked"
      ? createLockedApi()
      : scenario === "copy-readback-failed"
        ? createCopyReadbackFailureApi()
        : createReviewRecipeApi("ready"),
  );
  const [adjustmentApi] = useState(() =>
    createReviewRecipeAdjustmentApi("ready"),
  );
  return (
    <main className="atlas-page">
      <DishRecipeAdminWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        adjustmentApi={adjustmentApi}
        mode="review"
      />
    </main>
  );
}

const meta = {
  title: "Atlas/Recipes/Dish recipe workbench",
  component: DishRecipeAdminWorkbench,
  parameters: {
    layout: "fullscreen",
    docs: {
      description: {
        component:
          "Real Recipe workbench using shaped review responses for authoritative effective reads, typed base authoring and atomic two-scope copy recovery.",
      },
    },
  },
} satisfies Meta<typeof DishRecipeAdminWorkbench>;

export default meta;
type Story = StoryObj<typeof meta>;

async function openAuthoring(canvasElement: HTMLElement) {
  const canvas = within(canvasElement);
  await userEvent.click(await canvas.findByRole("tab", { name: "Công thức" }));
  await canvas.findByRole("heading", { name: "Công thức" });
  return canvas;
}

export const RootOnlyAuthoring: Story = {
  name: "Root-only Dish remains authorable",
  render: () => <RecipeScenarioStory scenario="root-only" />,
  play: async ({ canvasElement }) => {
    const canvas = await openAuthoring(canvasElement);
    await userEvent.click(
      await canvas.findByRole("option", { name: /Cơm trắng/ }),
    );
    await expect(
      await canvas.findByText(
        /Chưa có công thức đã phát hành cho loại trường này/,
      ),
    ).toBeVisible();
    await expect(
      canvas.getByPlaceholderText("Tìm nguyên liệu để thêm…"),
    ).toBeEnabled();
  },
};

export const LockedRecipe: Story = {
  name: "Operationally locked Recipe",
  render: () => <RecipeScenarioStory scenario="locked" />,
  play: async ({ canvasElement }) => {
    const canvas = await openAuthoring(canvasElement);
    await expect(await canvas.findByRole("alert")).toHaveTextContent(
      "thực đơn đã duyệt",
    );
    await expect(canvas.getByRole("button", { name: "Lưu" })).toBeDisabled();
  },
};

export const SchoolEffectiveContext: Story = {
  name: "School effective context",
  render: () => <RecipeScenarioStory scenario="school" />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await expect(
      await canvas.findByLabelText("Chi tiết công thức hiệu lực"),
    ).toHaveTextContent("12");
    const context = await canvas.findByLabelText("Ngữ cảnh công thức");
    await canvas.findByRole("option", { name: /Trường Tiểu học Minh Khai/ });
    await userEvent.selectOptions(
      context,
      "school:11000000-0000-4000-8000-000000000001",
    );
    await expect(context).toHaveValue(
      "school:11000000-0000-4000-8000-000000000001",
    );
    await expect(
      canvas.getByLabelText("Chi tiết công thức hiệu lực"),
    ).toHaveTextContent("14");
  },
};

export const MixedIssuanceHistory: Story = {
  name: "Mixed legacy and Atlas-native effective history",
  render: () => <RecipeScenarioStory scenario="school" />,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    await userEvent.click(await canvas.findByText("Lịch sử BOM hiệu lực"));
    await expect(
      await canvas.findByText("Không có dữ liệu từ OPS v1"),
    ).toBeVisible();
    await expect(await canvas.findByText("Nguyễn Điều phối")).toBeVisible();
    await expect(await canvas.findByText("Trần Quản trị")).toBeVisible();
  },
};

export const CopyCommittedReadbackFailed: Story = {
  name: "Copy committed, one DRAFT readback failed",
  render: () => <RecipeScenarioStory scenario="copy-readback-failed" />,
  play: async ({ canvasElement }) => {
    const canvas = await openAuthoring(canvasElement);
    await userEvent.click(
      await canvas.findByRole("option", { name: /Cơm trắng/ }),
    );
    await canvas.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    await userEvent.click(
      canvas.getByRole("button", { name: "Sao chép công thức" }),
    );
    await userEvent.selectOptions(
      canvas.getByLabelText("Món nguồn"),
      "10000000-0000-4000-8000-000000000001",
    );
    await userEvent.click(
      canvas.getByRole("button", { name: "Sao chép hai công thức" }),
    );
    const dialog = canvas.getByRole("dialog", {
      name: "Sao chép công thức",
    });
    await expect(
      await within(dialog).findByText(
        /đã ghi nhận sao chép.*chưa đọc lại được/i,
      ),
    ).toBeVisible();
    await expect(canvas.getAllByRole("alert")).toHaveLength(1);
    await expect(
      within(dialog).getByRole("button", {
        name: "Đối soát kết quả sao chép",
      }),
    ).toBeVisible();
  },
};
