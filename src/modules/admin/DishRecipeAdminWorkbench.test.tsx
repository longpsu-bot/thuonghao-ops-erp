import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { MantineProvider } from "@mantine/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
import type { RecipeAdjustmentApi } from "../atlas/recipe-adjustments/recipeAdjustmentApi";
import type {
  DishRecipeCopyCommandRequest,
  RecipeApi,
} from "../atlas/recipes/recipeApi";
import type {
  DishRecipeOperatorWorkbench,
  RecipeVersionStatus,
  RecipeWorkbenchData,
} from "../atlas/recipes/recipeModel";
import { createReviewRecipeApi } from "../atlas/recipes/reviewRecipeApi";
import * as recipeWorkbook from "../atlas/recipes/recipeWorkbook";
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { atlasTheme } from "../../theme";
import { DishRecipeAdminWorkbench } from "./DishRecipeAdminWorkbench";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

function renderWorkbench(
  api: RecipeApi = createReviewRecipeApi("ready"),
  adjustmentApi: RecipeAdjustmentApi = createReviewRecipeAdjustmentApi("ready"),
  authState: AtlasAuthState = createReviewAuthState("ready"),
) {
  return render(
    <MantineProvider theme={atlasTheme}>
      <DishRecipeAdminWorkbench
        authState={authState}
        api={api}
        adjustmentApi={adjustmentApi}
        mode="review"
      />
    </MantineProvider>,
  );
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((next) => {
    resolve = next;
  });
  return { promise, resolve };
}

function overrideSelection(
  change: (selected: {
    dish_id: string | null;
    locked_for_normal_editing: boolean;
    lock_reason: string | null;
    business_status: string;
    allowed_actions: Record<string, boolean>;
    disabled_reason_codes: Record<string, string | null>;
    disabled_reasons: Record<string, string | null>;
  }) => void,
) {
  const base = createReviewRecipeApi("ready");
  const getEffectiveWorkbench = base.getEffectiveWorkbench;
  return {
    ...base,
    async getEffectiveWorkbench(
      ...args: Parameters<RecipeApi["getEffectiveWorkbench"]>
    ) {
      const result = await getEffectiveWorkbench(...args);
      if (result.kind !== "success") return result;
      const workbench = (result.response.workbench ?? result.response) as {
        base_authoring: Parameters<typeof change>[0];
        editable_state: string;
        is_editable: boolean;
        is_operationally_locked: boolean;
        allowed_actions: string[];
      };
      change(workbench.base_authoring);
      if (workbench.base_authoring.locked_for_normal_editing) {
        workbench.editable_state = "LOCKED_CHANGE_ORDER";
        workbench.is_editable = false;
        workbench.is_operationally_locked = true;
        workbench.allowed_actions = ["CREATE_CHANGE_ORDER"];
      }
      return result;
    },
  } satisfies RecipeApi;
}

function lifecycleRecipeApi(
  versionStatus: RecipeVersionStatus,
  saveAllowed: boolean,
) {
  const api = createReviewRecipeApi("ready");
  const getWorkbench = api.getWorkbench;
  const getEffectiveWorkbench = api.getEffectiveWorkbench;
  api.getWorkbench = async (...args) => {
    const result = await getWorkbench(...args);
    if (result.kind !== "success") return result;
    const workbench = (result.response.workbench ??
      result.response) as unknown as RecipeWorkbenchData;
    const selectedVersion = workbench.recipe_versions.find(
      (version) =>
        version.recipe_version_id ===
        workbench.selected_recipe.recipe_version_id,
    );
    if (selectedVersion) selectedVersion.recipe_version_status = versionStatus;
    return result;
  };
  api.getEffectiveWorkbench = async (...args) => {
    const result = await getEffectiveWorkbench(...args);
    if (result.kind !== "success") return result;
    const workbench = (result.response.workbench ??
      result.response) as unknown as DishRecipeOperatorWorkbench;
    workbench.base_authoring.business_status =
      versionStatus === "RELEASED_FOR_PLANNING" ? "AVAILABLE" : "SAVED";
    workbench.base_authoring.allowed_actions.save_recipe = saveAllowed;
    workbench.base_authoring.disabled_reason_codes.save_recipe = saveAllowed
      ? null
      : "SAVE_CAPABILITY_REQUIRED";
    workbench.base_authoring.disabled_reasons.save_recipe = saveAllowed
      ? null
      : "Bạn chưa có quyền lưu công thức.";
    workbench.is_editable = saveAllowed;
    if (versionStatus !== "RELEASED_FOR_PLANNING") {
      const blockers = [
        {
          code: "RECIPE_SELECTION_BLOCKED",
          message: `Bản ${versionStatus} chưa phải công thức phát hành.`,
        },
      ];
      workbench.selected_recipe = null;
      workbench.effective_readiness = {
        status: "BLOCKED",
        blockers,
        warnings: [],
      };
      workbench.current_effective_bom = [];
      workbench.allowed_actions = [];
      workbench.blockers = blockers;
      workbench.history_periods = [];
    }
    return result;
  };
  return api;
}

async function openCreation() {
  fireEvent.click(
    await screen.findByRole("tab", { name: "Tạo món & công thức" }),
  );
  await screen.findByRole("heading", { name: "Tạo món & công thức" });
}

function lockedDishApi() {
  let lockedDishId: string | null = null;
  return overrideSelection((selected) => {
    lockedDishId ??= selected.dish_id;
    if (selected.dish_id !== lockedDishId) return;
    selected.locked_for_normal_editing = true;
    selected.lock_reason =
      "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.";
    selected.business_status = "LOCKED";
    selected.allowed_actions.save_recipe = false;
    selected.disabled_reason_codes.save_recipe = "SAVE_OPERATIONALLY_LOCKED";
    selected.disabled_reasons.save_recipe = selected.lock_reason;
  });
}

describe("Recipe creation-and-lock workbench", () => {
  it("does not issue Recipe reads or writes after the session expires", async () => {
    const api = createReviewRecipeApi("ready");
    const adjustmentApi = createReviewRecipeAdjustmentApi("ready");
    const getWorkbench = vi.spyOn(api, "getWorkbench");
    const getEffectiveWorkbench = vi.spyOn(api, "getEffectiveWorkbench");
    const createDish = vi.spyOn(api, "createDish");
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    const copyDishRecipes = vi.spyOn(api, "copyDishRecipes");
    const getAdjustmentWorkbench = vi.spyOn(adjustmentApi, "getWorkbench");
    renderWorkbench(api, adjustmentApi, createReviewAuthState("session_lost"));

    expect(
      await screen.findByText(/Phiên làm việc đã hết.*đăng nhập lại/),
    ).toBeVisible();
    expect(getWorkbench).not.toHaveBeenCalled();
    expect(getEffectiveWorkbench).not.toHaveBeenCalled();
    expect(getAdjustmentWorkbench).not.toHaveBeenCalled();
    expect(createDish).not.toHaveBeenCalled();
    expect(saveRecipe).not.toHaveBeenCalled();
    expect(copyDishRecipes).not.toHaveBeenCalled();
  });

  it("fails closed when the authoritative effective read is denied", async () => {
    const api = createReviewRecipeApi("ready");
    const denied = createReviewRecipeApi("permission_denied");
    api.getEffectiveWorkbench = denied.getEffectiveWorkbench;
    const getWorkbench = vi.spyOn(api, "getWorkbench");
    const getEffectiveWorkbench = vi.spyOn(api, "getEffectiveWorkbench");
    const createDish = vi.spyOn(api, "createDish");
    const createDraft = vi.spyOn(api, "createDraft");
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    const releaseRecipe = vi.spyOn(api, "releaseRecipe");
    const setDishLifecycle = vi.spyOn(api, "setDishLifecycle");
    const copyDishRecipes = vi.spyOn(api, "copyDishRecipes");
    renderWorkbench(api);

    const denial = await screen.findByText(
      /Bạn không có quyền thực hiện thao tác này/,
    );
    expect(denial).toHaveAttribute("role", "alert");
    expect(getWorkbench).toHaveBeenCalledTimes(1);
    expect(getEffectiveWorkbench).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("tab", { name: "Tạo món & công thức" }));
    const create = screen.getByRole("button", { name: "Tạo món mới" });
    expect(create).toBeDisabled();
    fireEvent.click(create);
    expect(screen.queryByLabelText("Biểu mẫu món ăn")).toBeNull();
    expect(createDish).not.toHaveBeenCalled();
    expect(createDraft).not.toHaveBeenCalled();
    expect(saveRecipe).not.toHaveBeenCalled();
    expect(releaseRecipe).not.toHaveBeenCalled();
    expect(setDishLifecycle).not.toHaveBeenCalled();
    expect(copyDishRecipes).not.toHaveBeenCalled();
  });

  it("loads one authoritative effective detail on demand and labels base-only catalog search truthfully", async () => {
    const api = createReviewRecipeApi("ready");
    const getEffectiveWorkbench = vi.spyOn(api, "getEffectiveWorkbench");
    renderWorkbench(api);

    expect(
      await screen.findByLabelText("Chi tiết công thức hiệu lực"),
    ).toHaveTextContent("Hành lá hiệu lực");
    expect(
      (screen.getByLabelText("Ngày áp dụng") as HTMLInputElement).value,
    ).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(screen.getByLabelText("Ngữ cảnh công thức")).toHaveValue(
      "system:60000000-0000-4000-8000-000000000001",
    );
    expect(
      screen.getByLabelText("Tìm món hoặc nguyên liệu trong công thức gốc"),
    ).toBeVisible();
    expect(getEffectiveWorkbench).toHaveBeenCalledTimes(1);

    fireEvent.change(
      screen.getByLabelText("Tìm món hoặc nguyên liệu trong công thức gốc"),
      { target: { value: "thịt heo" } },
    );
    expect(getEffectiveWorkbench).toHaveBeenCalledTimes(1);
  });

  it("uses only canonical returned scope IDs for normal authoring and keeps root-only authoring writable while effective readiness is blocked", async () => {
    const api = createReviewRecipeApi("ready");
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    renderWorkbench(api);
    await screen.findByLabelText("Chi tiết công thức hiệu lực");
    await openCreation();

    const scope = screen.getByLabelText("Áp dụng cho");
    expect(within(scope).queryByRole("option", { name: "Tất cả" })).toBeNull();
    expect(scope).toHaveValue("60000000-0000-4000-8000-000000000001");

    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    expect(
      await screen.findByText(
        /Chưa có công thức đã phát hành cho loại trường này/,
      ),
    ).toBeVisible();
    expect(
      screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"),
    ).toBeEnabled();
    fireEvent.change(screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"), {
      target: { value: "hành" },
    });
    fireEvent.click(screen.getByRole("option", { name: "Hành lá" }));
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(saveRecipe).toHaveBeenCalledTimes(1));
    expect(saveRecipe.mock.calls[0][0].payload).toMatchObject({
      dish_id: "10000000-0000-4000-8000-000000000002",
      school_type_id: "60000000-0000-4000-8000-000000000001",
      recipe_version_id: null,
    });
  });

  it.each([
    {
      versionStatus: "DRAFT" as const,
      saveAllowed: true,
      historyLabel: "Đã lưu để chỉnh sửa",
      businessLabel: "Đã lưu",
    },
    {
      versionStatus: "VALIDATED" as const,
      saveAllowed: true,
      historyLabel: "Bản công thức trước đây",
      businessLabel: "Đã lưu",
    },
    {
      versionStatus: "RELEASED_FOR_PLANNING" as const,
      saveAllowed: true,
      historyLabel: "Sẵn sàng cho Lập nhu cầu",
      businessLabel: "Sẵn sàng cho Lập nhu cầu",
    },
    {
      versionStatus: "VALIDATED" as const,
      saveAllowed: false,
      historyLabel: "Bản công thức trước đây",
      businessLabel: "Đã lưu",
    },
  ])(
    "uses backend base-authoring authority for $versionStatus with Save=$saveAllowed",
    async ({ versionStatus, saveAllowed, historyLabel, businessLabel }) => {
      const api = lifecycleRecipeApi(versionStatus, saveAllowed);
      const saveRecipe = vi.spyOn(api, "saveRecipe").mockResolvedValue({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "EXPECTED_TEST_STOP",
          safe_message: "Test stops after observing the submitted command.",
        },
      });
      const validateVersion = vi.spyOn(api, "validateVersion");
      const releaseRecipe = vi.spyOn(api, "releaseRecipe");
      const setDishLifecycle = vi.spyOn(api, "setDishLifecycle");
      renderWorkbench(api);
      await screen.findByLabelText("Chi tiết công thức hiệu lực");
      await openCreation();

      expect(screen.getAllByText(businessLabel)).not.toHaveLength(0);
      if (versionStatus === "RELEASED_FOR_PLANNING") {
        expect(screen.queryByText(/chưa phải công thức phát hành/)).toBeNull();
      } else {
        expect(
          await screen.findByText(
            new RegExp(`Bản ${versionStatus} chưa phải công thức phát hành`),
          ),
        ).toBeVisible();
      }
      fireEvent.click(screen.getByText("Lịch sử công thức"));
      expect(screen.getAllByText(historyLabel)).not.toHaveLength(0);
      fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
        target: { value: "24" },
      });
      const save = screen.getByRole("button", { name: "Lưu" });

      if (saveAllowed) {
        expect(save).toBeEnabled();
        fireEvent.click(save);
        await waitFor(() => expect(saveRecipe).toHaveBeenCalledTimes(1));
      } else {
        expect(save).toBeDisabled();
        fireEvent.click(save);
        expect(saveRecipe).not.toHaveBeenCalled();
        expect(
          screen.getByText("Bạn chưa có quyền lưu công thức."),
        ).toBeVisible();
      }
      expect(validateVersion).not.toHaveBeenCalled();
      expect(releaseRecipe).not.toHaveBeenCalled();
      expect(setDishLifecycle).not.toHaveBeenCalled();
    },
  );

  it("keeps late effective reads from replacing the latest selected context", async () => {
    const base = createReviewRecipeApi("ready");
    const first = await base.getEffectiveWorkbench(
      "subject",
      "correlation",
      "2026-09-06",
      "10000000-0000-4000-8000-000000000001",
      { kind: "system", schoolTypeId: "60000000-0000-4000-8000-000000000001" },
    );
    const slow = deferred<AtlasRpcResult>();
    const fast = deferred<AtlasRpcResult>();
    let call = 0;
    const getEffectiveWorkbench: RecipeApi["getEffectiveWorkbench"] = vi.fn(
      async () => {
        call += 1;
        if (call === 1) return first;
        return call === 2 ? slow.promise : fast.promise;
      },
    );
    renderWorkbench({ ...base, getEffectiveWorkbench });
    await screen.findByLabelText("Chi tiết công thức hiệu lực");

    fireEvent.change(screen.getByLabelText("Ngày áp dụng"), {
      target: { value: "2026-09-05" },
    });
    await waitFor(() => expect(getEffectiveWorkbench).toHaveBeenCalledTimes(2));
    fireEvent.change(screen.getByLabelText("Ngày áp dụng"), {
      target: { value: "2026-09-07" },
    });
    await waitFor(() => expect(getEffectiveWorkbench).toHaveBeenCalledTimes(3));
    fast.resolve(
      await base.getEffectiveWorkbench(
        "subject",
        "correlation",
        "2026-09-07",
        "10000000-0000-4000-8000-000000000001",
        {
          kind: "system",
          schoolTypeId: "60000000-0000-4000-8000-000000000001",
        },
      ),
    );
    await waitFor(() =>
      expect(screen.getByLabelText("Ngày áp dụng")).toHaveValue("2026-09-07"),
    );
    slow.resolve(
      await base.getEffectiveWorkbench(
        "subject",
        "correlation",
        "2026-09-05",
        "10000000-0000-4000-8000-000000000001",
        {
          kind: "system",
          schoolTypeId: "60000000-0000-4000-8000-000000000001",
        },
      ),
    );
    await waitFor(() =>
      expect(screen.getByLabelText("Ngày áp dụng")).toHaveValue("2026-09-07"),
    );
  });

  it("navigates to a School effective context as read-only authoritative data", async () => {
    renderWorkbench();
    await screen.findByRole("option", { name: /Trường Tiểu học Minh Khai/ });
    fireEvent.change(screen.getByLabelText("Ngữ cảnh công thức"), {
      target: {
        value: "school:11000000-0000-4000-8000-000000000001",
      },
    });
    await waitFor(() =>
      expect(screen.getByLabelText("Ngữ cảnh công thức")).toHaveValue(
        "school:11000000-0000-4000-8000-000000000001",
      ),
    );
    expect(
      screen.getByLabelText("Chi tiết công thức hiệu lực"),
    ).toHaveTextContent("14");
    await openCreation();
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toBeDisabled();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
  });

  it("keeps a second same-type School free of another School's exception", async () => {
    const unaffectedSchoolId = "11000000-0000-4000-8000-000000000003";
    const api = createReviewRecipeApi("ready");
    const getEffectiveWorkbench = api.getEffectiveWorkbench;
    vi.spyOn(api, "getEffectiveWorkbench").mockImplementation(
      async (authSubject, correlationId, asOfDate, selectedDishId, context) => {
        if (
          context.kind !== "school" ||
          context.schoolId !== unaffectedSchoolId
        )
          return getEffectiveWorkbench(
            authSubject,
            correlationId,
            asOfDate,
            selectedDishId,
            context,
          );
        const result = await getEffectiveWorkbench(
          authSubject,
          correlationId,
          asOfDate,
          selectedDishId,
          {
            kind: "system",
            schoolTypeId: "60000000-0000-4000-8000-000000000001",
          },
        );
        if (result.kind !== "success") return result;
        const workbench = (result.response.workbench ??
          result.response) as unknown as DishRecipeOperatorWorkbench;
        workbench.context_kind = "SCHOOL";
        workbench.school_id = unaffectedSchoolId;
        workbench.school_exception_count = 0;
        return result;
      },
    );
    const adjustmentApi = createReviewRecipeAdjustmentApi("ready");
    const getAdjustmentWorkbench = adjustmentApi.getWorkbench;
    vi.spyOn(adjustmentApi, "getWorkbench").mockImplementation(
      async (...args) => {
        const result = await getAdjustmentWorkbench(...args);
        if (result.kind !== "success") return result;
        const workbench = (result.response.workbench ?? result.response) as {
          schools: Array<{
            school_id: string;
            school_code: string;
            school_name: string;
            school_type_id: string;
            school_status: string;
          }>;
        };
        workbench.schools.push({
          school_id: unaffectedSchoolId,
          school_code: "truong-nguyen-du",
          school_name: "Trường Tiểu học Nguyễn Du",
          school_type_id: "12000000-0000-4000-8000-000000000001",
          school_status: "ACTIVE",
        });
        return result;
      },
    );
    renderWorkbench(api, adjustmentApi);
    const detail = await screen.findByLabelText("Chi tiết công thức hiệu lực");
    expect(detail).toHaveTextContent("12");
    const context = screen.getByLabelText("Ngữ cảnh công thức");

    fireEvent.change(context, {
      target: {
        value: "school:11000000-0000-4000-8000-000000000001",
      },
    });
    await waitFor(() => expect(detail).toHaveTextContent("14"));
    expect(detail).toHaveTextContent("Ngoại lệ Trường đang đóng góp: 1");

    fireEvent.change(context, {
      target: { value: `school:${unaffectedSchoolId}` },
    });
    await waitFor(() =>
      expect(context).toHaveValue(`school:${unaffectedSchoolId}`),
    );
    expect(detail).toHaveTextContent("12");
    expect(detail).toHaveTextContent("Ngoại lệ Trường đang đóng góp: 0");
    await openCreation();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
  });

  it("opens on a read-only current-effective catalog with useful Recipe information", async () => {
    renderWorkbench();

    expect(
      await screen.findByRole("tab", { name: "Danh sách", selected: true }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Canh bí đỏ thịt bằm")).not.toHaveLength(0);
    expect(screen.getByText("Món canh")).toBeVisible();
    expect(document.body).not.toHaveTextContent("canh-bi-do-thit-bam");
    expect(screen.getAllByText(/Bí đỏ.*Thịt heo xay/)).toHaveLength(2);
    expect(
      screen.getByLabelText("Chi tiết công thức hiệu lực"),
    ).toHaveTextContent("Hành lá hiệu lực");
    expect(
      screen.getByText(/Bảng danh sách dùng công thức gốc/),
    ).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Xem" })).not.toHaveLength(0);
    for (const forbidden of [
      "Sửa",
      "Xác thực",
      "Đưa vào sử dụng",
      "Tạo phiên bản kế nhiệm",
    ]) {
      expect(screen.queryByRole("button", { name: forbidden })).toBeNull();
    }
  });

  it("filters the catalog by Dish code and current Ingredient name", async () => {
    renderWorkbench();
    const search = await screen.findByPlaceholderText(
      "Tìm theo món, mã món hoặc nguyên liệu gốc…",
    );
    fireEvent.change(search, { target: { value: "thịt heo" } });
    const catalog = screen.getAllByRole("table")[0];
    expect(
      within(catalog).getByText("Canh bí đỏ thịt bằm"),
    ).toBeInTheDocument();
    expect(within(catalog).queryByText("Cơm trắng")).toBeNull();

    fireEvent.change(search, { target: { value: "com-trang" } });
    expect(within(catalog).getByText("Cơm trắng")).toBeInTheDocument();
    expect(within(catalog).queryByText("Canh bí đỏ thịt bằm")).toBeNull();
    expect(catalog).not.toHaveTextContent("com-trang");
  });

  it("renders authoritative BOM periods while keeping imported attribution explicitly nullable", async () => {
    renderWorkbench();
    const history = await screen.findByText("Lịch sử BOM hiệu lực");
    fireEvent.click(history);

    const previousPeriod = screen
      .getByRole("heading", {
        name: /Từ 2026-06-01 đến trước 2026-07-01/,
      })
      .closest("section")!;
    expect(within(previousPeriod).getByText("Bí đỏ")).toBeVisible();
    expect(within(previousPeriod).getByText("Thịt heo xay")).toBeVisible();
    expect(
      screen.getByRole("heading", { name: /Từ 2026-07-01 trở đi/ }),
    ).toBeVisible();
    expect(screen.getByText(/SYSTEM_INGREDIENT · từ 2026-07-01/)).toBeVisible();
    expect(
      screen.getByText("Không có thông tin người ban hành gốc"),
    ).toBeVisible();
    expect(screen.getByText("Không có thời điểm ban hành gốc")).toBeVisible();
    expect(
      screen.getByText(/không được coi là thông tin ban hành gốc/),
    ).toBeVisible();
    const period = screen
      .getByRole("heading", { name: /Từ 2026-07-01 trở đi/ })
      .closest("section")!;
    expect(within(period).getByText("Hành lá hiệu lực")).toBeVisible();
    expect(within(period).getByText("Thịt heo xay")).toBeVisible();
  });

  it("shows human Dish identity in the creation finder without normalized codes", async () => {
    renderWorkbench();
    await openCreation();

    const finder = screen.getByRole("listbox");
    const option = within(finder).getByRole("option", {
      name: /Canh bí đỏ thịt bằm.*Món canh/,
    });
    expect(option).toBeVisible();
    expect(option).not.toHaveTextContent("canh-bi-do-thit-bam");
  });

  it("keeps creation as a distinct job with Dish context, scope and basis", async () => {
    renderWorkbench();
    await openCreation();

    expect(
      await screen.findByRole("heading", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Loại món: Món canh/)).toBeVisible();
    expect(document.body).not.toHaveTextContent("canh-bi-do-thit-bam");
    expect(screen.getByLabelText("Áp dụng cho")).toHaveValue(
      "60000000-0000-4000-8000-000000000001",
    );
    expect(screen.getByLabelText("Số suất áp dụng cho định lượng")).toHaveValue(
      100,
    );
    expect(screen.getAllByText("Sẵn sàng cho Lập nhu cầu")).not.toHaveLength(0);
    expect(
      screen.queryByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeNull();
  });

  it("searches loaded active Ingredients without a huge select", async () => {
    renderWorkbench();
    await openCreation();
    const search = screen.getByPlaceholderText("Tìm nguyên liệu để thêm…");
    fireEvent.change(search, { target: { value: "hành" } });
    fireEvent.click(screen.getByRole("option", { name: "Hành lá" }));

    expect(screen.getByText("Hành lá")).toBeInTheDocument();
    expect(document.body).not.toHaveTextContent("hanh-la");
    expect(screen.getAllByText("Có thay đổi chưa lưu")).not.toHaveLength(0);
  });

  it("matches an Ingredient code without rendering it in the result", async () => {
    renderWorkbench();
    await openCreation();
    const search = screen.getByPlaceholderText("Tìm nguyên liệu để thêm…");
    fireEvent.change(search, { target: { value: "hanh-la" } });

    const option = screen.getByRole("option", { name: "Hành lá" });
    expect(option).toBeVisible();
    expect(option).not.toHaveTextContent("hanh-la");
  });

  it("uses human Ingredient and Unit names in the BOM table", async () => {
    renderWorkbench();
    await openCreation();

    const table = screen.getByRole("table");
    expect(within(table).getByText("Bí đỏ")).toBeVisible();
    expect(
      within(table).getAllByRole("option", { name: "Kilôgam" }),
    ).not.toHaveLength(0);
    expect(table).not.toHaveTextContent("bi-do");
    expect(table).not.toHaveTextContent("KG");
  });

  it("copies both effective scopes into DRAFTs without auto-save and permits explicit unchanged Save", async () => {
    const api = createReviewRecipeApi("ready");
    const copyDishRecipes = vi.spyOn(api, "copyDishRecipes");
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    const releaseRecipe = vi.spyOn(api, "releaseRecipe");
    const copyVersion = vi.spyOn(api, "copyVersion");
    const getEffectiveWorkbench = vi.spyOn(api, "getEffectiveWorkbench");
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));

    expect(
      screen.getByRole("dialog", { name: "Sao chép công thức" }),
    ).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.change(screen.getByLabelText("Ngày chụp công thức nguồn"), {
      target: { value: "2026-09-05" },
    });
    fireEvent.change(screen.getByLabelText("Lý do sao chép"), {
      target: { value: "Dùng bộ công thức đã duyệt cho món đích." },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );

    await waitFor(() => expect(copyDishRecipes).toHaveBeenCalledTimes(1));
    const request = copyDishRecipes.mock.calls[0][0];
    expect(request).toMatchObject({
      contract_version: "RECIPE-EFFECTIVE.v1",
      expected_version: 1,
      reason_code: "COPY_DISH_RECIPES",
      reason_note: "Dùng bộ công thức đã duyệt cho món đích.",
      payload: {
        source_dish_id: "10000000-0000-4000-8000-000000000001",
        target_dish_id: "10000000-0000-4000-8000-000000000002",
        as_of_date: "2026-09-05",
      },
    });
    expect(request.command_id).toMatch(/^[0-9a-f-]{36}$/i);
    expect(request.idempotency_key).toContain(request.command_id);
    expect(saveRecipe).not.toHaveBeenCalled();
    expect(copyVersion).not.toHaveBeenCalled();
    expect(await screen.findByText(/đã lưu hai công thức NHÁP/)).toBeVisible();
    expect(screen.queryByRole("dialog")).toBeNull();
    const copyReadbacks = getEffectiveWorkbench.mock.calls.filter(
      ([, , date, dishId]) =>
        date === "2026-09-05" &&
        dishId === "10000000-0000-4000-8000-000000000002",
    );
    expect(copyReadbacks.map(([, , , , context]) => context)).toEqual(
      expect.arrayContaining([
        {
          kind: "system",
          schoolTypeId: "60000000-0000-4000-8000-000000000001",
        },
        {
          kind: "system",
          schoolTypeId: "60000000-0000-4000-8000-000000000002",
        },
      ]),
    );
    expect(screen.getByLabelText("Định lượng Hành lá hiệu lực")).toHaveValue(
      12,
    );
    expect(screen.getByLabelText("Định lượng Thịt heo xay")).toHaveValue(8);
    expect(screen.queryByLabelText("Định lượng Bí đỏ")).toBeNull();

    fireEvent.change(screen.getByLabelText("Áp dụng cho"), {
      target: { value: "60000000-0000-4000-8000-000000000002" },
    });
    expect(await screen.findByLabelText("Định lượng Bí đỏ")).toHaveValue(27);
    expect(screen.queryByLabelText("Định lượng Hành lá hiệu lực")).toBeNull();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();

    fireEvent.change(screen.getByLabelText("Áp dụng cho"), {
      target: { value: "60000000-0000-4000-8000-000000000001" },
    });
    expect(
      await screen.findByLabelText("Định lượng Hành lá hiệu lực"),
    ).toHaveValue(12);

    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    fireEvent.click(save);
    await waitFor(() => expect(saveRecipe).toHaveBeenCalledTimes(1));
    expect(saveRecipe.mock.calls[0][0].payload.lines).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          ingredient_id: "40000000-0000-4000-8000-000000000099",
          quantity_per_basis: 12,
        }),
        expect.objectContaining({
          ingredient_id: "40000000-0000-4000-8000-000000000002",
          quantity_per_basis: 8,
        }),
      ]),
    );
    expect(releaseRecipe).not.toHaveBeenCalled();
  });

  it("retains an unknown copy request across ordinary refresh and reconciles by persisted command evidence without resending", async () => {
    const api = createReviewRecipeApi("ready");
    const realCopy = api.copyDishRecipes;
    const copyDishRecipes = vi
      .spyOn(api, "copyDishRecipes")
      .mockImplementation(async (request) => {
        await realCopy(request);
        return {
          kind: "transport_error",
          diagnostic: {
            code: "NETWORK_FAILURE",
            safeMessage: "Connection ended after dispatch.",
          },
        };
      });
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );

    expect(
      await screen.findByText(/chưa xác định yêu cầu sao chép/),
    ).toBeVisible();
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("tab", { name: "Danh sách" }));
    fireEvent.click(screen.getByRole("button", { name: "Tải lại" }));
    await waitFor(() =>
      expect(screen.getByText(/chưa xác định yêu cầu sao chép/)).toBeVisible(),
    );
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);

    fireEvent.click(
      screen.getByRole("button", { name: "Đối soát kết quả sao chép" }),
    );
    expect(await screen.findByText(/đã lưu hai công thức NHÁP/)).toBeVisible();
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);
  });

  it("keeps a known successful copy blocked when a DRAFT readback fails and recovers without a second copy", async () => {
    const api = createReviewRecipeApi("ready");
    const realEffective = api.getEffectiveWorkbench;
    let copied = false;
    let failReadback = true;
    const realCopy = api.copyDishRecipes;
    const copyDishRecipes = vi
      .spyOn(api, "copyDishRecipes")
      .mockImplementation(async (request) => {
        const result = await realCopy(request);
        copied = true;
        return result;
      });
    vi.spyOn(api, "getEffectiveWorkbench").mockImplementation(
      async (...args) => {
        const context = args[4];
        if (
          copied &&
          failReadback &&
          context.kind === "system" &&
          context.schoolTypeId === "60000000-0000-4000-8000-000000000002"
        ) {
          failReadback = false;
          return {
            kind: "transport_error",
            diagnostic: {
              code: "NETWORK_FAILURE",
              safeMessage: "Readback unavailable.",
            },
          };
        }
        return realEffective(...args);
      },
    );
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );

    expect(
      await screen.findByText(/đã ghi nhận sao chép.*chưa đọc lại được/i),
    ).toBeVisible();
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);
    const dialog = screen.getByRole("dialog", { name: "Sao chép công thức" });
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    expect(within(dialog).getByRole("alert")).toHaveTextContent(
      /đã ghi nhận sao chép.*chưa đọc lại được/i,
    );
    fireEvent.click(
      within(dialog).getByRole("button", {
        name: "Đối soát kết quả sao chép",
      }),
    );
    expect(await screen.findByText(/đã lưu hai công thức NHÁP/)).toBeVisible();
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);
  });

  it("reconciles a malformed success envelope from persisted copy evidence without resending", async () => {
    const api = createReviewRecipeApi("ready");
    const realCopy = api.copyDishRecipes;
    const copyDishRecipes = vi
      .spyOn(api, "copyDishRecipes")
      .mockImplementation(async (request) => {
        const result = await realCopy(request);
        if (result.kind !== "success") return result;
        return {
          ...result,
          response: {
            ...result.response,
            scope_results: (result.response.scope_results as unknown[]).slice(
              0,
              1,
            ),
          },
        } as AtlasRpcResult;
      });
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );

    expect(await screen.findByText(/đã lưu hai công thức NHÁP/)).toBeVisible();
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);
  });

  it("retries only a backend-authorized retryable copy with the exact retained request", async () => {
    const api = createReviewRecipeApi("ready");
    const realCopy = api.copyDishRecipes;
    let rejected = false;
    const copyDishRecipes = vi
      .spyOn(api, "copyDishRecipes")
      .mockImplementation(async (request) => {
        if (!rejected) {
          rejected = true;
          return {
            kind: "backend_error",
            error: {
              success: false,
              error_code: "TEMPORARY_FAILURE",
              safe_message: "Temporary failure.",
              retryable: true,
            },
          };
        }
        return realCopy(request);
      });
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );
    await screen.findByRole("button", { name: "Thử lại yêu cầu cũ" });
    const retained = copyDishRecipes.mock.calls[0][0];
    fireEvent.click(screen.getByRole("button", { name: "Thử lại yêu cầu cũ" }));

    expect(await screen.findByText(/đã lưu hai công thức NHÁP/)).toBeVisible();
    expect(copyDishRecipes).toHaveBeenCalledTimes(2);
    expect(copyDishRecipes.mock.calls[1][0]).toBe(retained);
  });

  it("refreshes after a known stale copy denial without retrying the request", async () => {
    const api = createReviewRecipeApi("ready");
    const copyDishRecipes = vi.spyOn(api, "copyDishRecipes").mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_VERSION",
        safe_message: "Món đích đã thay đổi. Hãy xem lại trước khi sao chép.",
        retryable: false,
      },
    });
    const getWorkbench = vi.spyOn(api, "getWorkbench");
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );

    expect(await screen.findByText(/Dữ liệu đã thay đổi/)).toBeVisible();
    await waitFor(() => expect(getWorkbench).toHaveBeenCalledTimes(3));
    expect(copyDishRecipes).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole("dialog")).toBeNull();
    expect(
      screen.queryByRole("button", { name: "Thử lại yêu cầu cũ" }),
    ).toBeNull();
  });

  it("supersedes only a confirmed non-committed retryable copy with a fresh intent", async () => {
    const api = createReviewRecipeApi("ready");
    const copyDishRecipes = vi.spyOn(api, "copyDishRecipes").mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "TEMPORARY_FAILURE",
        safe_message: "Temporary failure.",
        retryable: true,
      },
    });
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );
    await screen.findByRole("button", { name: "Bỏ yêu cầu cũ" });
    fireEvent.click(screen.getByRole("button", { name: "Bỏ yêu cầu cũ" }));
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.change(screen.getByLabelText("Ngày chụp công thức nguồn"), {
      target: { value: "2026-09-08" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );
    await waitFor(() => expect(copyDishRecipes).toHaveBeenCalledTimes(2));
    expect(copyDishRecipes.mock.calls[1][0].command_id).not.toBe(
      copyDishRecipes.mock.calls[0][0].command_id,
    );
    expect(copyDishRecipes.mock.calls[1][0].payload.as_of_date).toBe(
      "2026-09-08",
    );
  });

  it("does not discard dirty authoring when a copy is proposed", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    const api = createReviewRecipeApi("ready");
    const copyDishRecipes = vi.spyOn(api, "copyDishRecipes");
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    await screen.findByText(
      /Chưa có công thức đã phát hành cho loại trường này/,
    );
    fireEvent.change(screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"), {
      target: { value: "hành" },
    });
    fireEvent.click(screen.getByRole("option", { name: "Hành lá" }));
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Món nguồn"), {
      target: { value: "10000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Sao chép hai công thức" }),
    );

    expect(confirm).toHaveBeenCalledTimes(1);
    expect(copyDishRecipes).not.toHaveBeenCalled();
    expect(
      screen.getByRole("dialog", { name: "Sao chép công thức" }),
    ).toBeVisible();
  });

  it.each(["affected-id", "legacy-readback"])(
    "creates from a locked Dish and saves the new identity using %s",
    async (responseShape) => {
      const api = lockedDishApi();
      const baseCreateDish = api.createDish;
      const createDish = vi
        .spyOn(api, "createDish")
        .mockImplementation(async (request) => {
          const result = await baseCreateDish(request);
          if (responseShape === "legacy-readback" || result.kind !== "success")
            return result;
          const dishes = result.response.dishes as Array<{
            dish_name: string;
            dish_id: string;
          }>;
          return {
            ...result,
            response: {
              ...result.response,
              affected_aggregate_ids: {
                dish_id: dishes.find(
                  (item) => item.dish_name === request.payload.dish_name,
                )!.dish_id,
              },
              dishes: [],
            },
          };
        });
      const saveRecipe = vi.spyOn(api, "saveRecipe");
      const setDishLifecycle = vi.spyOn(api, "setDishLifecycle");
      const releaseRecipe = vi.spyOn(api, "releaseRecipe");
      renderWorkbench(api);
      await openCreation();

      expect(screen.getByRole("alert")).toHaveTextContent(/thực đơn đã duyệt/);
      fireEvent.change(screen.getByPlaceholderText("Tìm theo tên món…"), {
        target: { value: "Canh bí đỏ" },
      });
      fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
      expect(screen.queryByRole("alert")).toBeNull();
      expect(screen.queryByLabelText("Mã món")).toBeNull();
      expect(screen.queryByLabelText("Thứ tự hiển thị")).toBeNull();
      expect(screen.queryByLabelText("Tham gia sinh nhu cầu")).toBeNull();
      const notes = screen.getByLabelText("Ghi chú vận hành (không bắt buộc)");
      expect(notes).not.toBeRequired();
      expect(notes).toHaveValue("");
      fireEvent.change(screen.getByLabelText("Tên món"), {
        target: { value: "Món mới 03A" },
      });
      fireEvent.change(screen.getByLabelText("Loại món"), {
        target: { value: "80000000-0000-4000-8000-000000000001" },
      });
      fireEvent.click(screen.getByRole("button", { name: "Lưu món ăn" }));

      await waitFor(() => expect(createDish).toHaveBeenCalledTimes(1));
      expect(
        screen.getByRole("tab", {
          name: "Tạo món & công thức",
          selected: true,
        }),
      ).toBeInTheDocument();
      expect(
        await screen.findByRole("heading", { name: "Món mới 03A" }),
      ).toBeInTheDocument();
      expect(
        screen.getByRole("option", { name: /Món mới 03A/, selected: true }),
      ).toBeVisible();
      expect(screen.queryByRole("alert")).toBeNull();
      expect(createDish.mock.calls[0][0].payload).not.toHaveProperty("dish_id");
      expect(createDish.mock.calls[0][0].payload).toEqual({
        dish_name: "Món mới 03A",
        dish_type_id: "80000000-0000-4000-8000-000000000001",
        dish_category: "",
        operational_notes: "",
      });

      fireEvent.change(
        screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"),
        { target: { value: "hành" } },
      );
      fireEvent.click(screen.getByRole("option", { name: "Hành lá" }));
      expect(screen.getAllByText("Có thay đổi chưa lưu")).not.toHaveLength(0);

      fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
      await waitFor(() => expect(saveRecipe).toHaveBeenCalledTimes(1));
      expect(saveRecipe.mock.calls[0][0].payload).toMatchObject({
        school_type_id: "60000000-0000-4000-8000-000000000001",
        recipe_version_id: null,
        basis_portions: 100,
      });
      expect(saveRecipe.mock.calls[0][0].payload.dish_id).not.toBe(
        "10000000-0000-4000-8000-000000000001",
      );
      expect(setDishLifecycle).not.toHaveBeenCalled();
      expect(releaseRecipe).not.toHaveBeenCalled();

      const result = await api.getWorkbench(
        "00000000-0000-4000-8000-000000000001",
        "00000000-0000-4000-8000-000000000002",
      );
      expect(result.kind).toBe("success");
      if (result.kind !== "success")
        throw new Error("Expected review readback");
      const workbench = (result.response.workbench ?? result.response) as {
        dishes: Array<{
          dish_id: string;
          dish_code: string;
          dish_status: string;
          requires_need_generation: boolean;
          version: number;
        }>;
        selected_recipe: { business_status: string };
      };
      expect(
        workbench.dishes.find(
          (item) =>
            item.dish_id === saveRecipe.mock.calls[0][0].payload.dish_id,
        ),
      ).toMatchObject({
        dish_status: "ACTIVE",
        version: 1,
        requires_need_generation: true,
      });
      expect(workbench.selected_recipe.business_status).toBe("AVAILABLE");

      expect(
        screen.getByRole("tab", {
          name: "Tạo món & công thức",
          selected: true,
        }),
      ).toBeInTheDocument();
      expect(
        screen.getByRole("heading", { name: "Món mới 03A" }),
      ).toBeInTheDocument();
    },
  );

  it("keeps a successful Dish creation blocked when authoritative readback fails", async () => {
    const api = createReviewRecipeApi("ready");
    const realCreateDish = api.createDish;
    const realGetWorkbench = api.getWorkbench;
    let created = false;
    let failReadback = true;
    const createDish = vi
      .spyOn(api, "createDish")
      .mockImplementation(async (request) => {
        const result = await realCreateDish(request);
        created = result.kind === "success";
        return result;
      });
    const getWorkbench = vi
      .spyOn(api, "getWorkbench")
      .mockImplementation(async (...args) => {
        if (created && failReadback) {
          failReadback = false;
          return {
            kind: "transport_error",
            diagnostic: {
              code: "NETWORK_FAILURE",
              safeMessage: "Dish readback failed after commit.",
            },
          };
        }
        return realGetWorkbench(...args);
      });
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    fireEvent.change(screen.getByLabelText("Tên món"), {
      target: { value: "Món chờ đối soát" },
    });
    fireEvent.change(screen.getByLabelText("Loại món"), {
      target: { value: "80000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu món ăn" }));

    expect(
      await screen.findByText(/đã ghi nhận tạo món.*chưa đọc lại được/i),
    ).toBeVisible();
    expect(screen.getByRole("alert")).toHaveTextContent(
      /Chưa xác định thao tác vừa rồi/,
    );
    expect(screen.getByLabelText("Tên món")).toHaveValue("Món chờ đối soát");
    expect(screen.getByRole("button", { name: "Lưu món ăn" })).toBeDisabled();
    expect(createDish).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole("button", { name: "Tải lại" }));
    await waitFor(() => expect(getWorkbench).toHaveBeenCalledTimes(3));
    expect(screen.getByRole("button", { name: "Lưu món ăn" })).toBeDisabled();
    expect(screen.getByLabelText("Tên món")).toHaveValue("Món chờ đối soát");
    expect(createDish).toHaveBeenCalledTimes(1);
  });

  it("shows Dish Type names without normalized codes", async () => {
    renderWorkbench();
    await openCreation();
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));

    const selector = screen.getByLabelText("Loại món");
    expect(
      within(selector).getByRole("option", { name: "Món canh" }),
    ).toBeVisible();
    expect(selector).not.toHaveTextContent("soup");
    expect(selector).not.toHaveTextContent("savory");
  });

  it("keeps a backend conflict in the new-dish form and restores the existing lock on cancel", async () => {
    const api = lockedDishApi();
    vi.spyOn(api, "createDish").mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "CONFLICT",
        safe_message: "The dish code is already in use.",
      },
    } as AtlasRpcResult);
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    renderWorkbench(api);
    await openCreation();
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    fireEvent.change(screen.getByLabelText("Tên món"), {
      target: { value: "Món trùng mã" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu món ăn" }));
    expect(
      await screen.findByText(/Dữ liệu mục tiêu đang xung đột/),
    ).toBeVisible();
    expect(screen.getByLabelText("Tên món")).toHaveValue("Món trùng mã");
    expect(screen.queryByRole("alert")).toBeNull();
    expect(saveRecipe).not.toHaveBeenCalled();
    fireEvent.click(
      within(screen.getByLabelText("Biểu mẫu món ăn")).getByRole("button", {
        name: "×",
      }),
    );
    expect(
      screen.getByRole("heading", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeVisible();
    expect(screen.getByRole("alert")).toHaveTextContent(/thực đơn đã duyệt/);
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(screen.queryByText(/Dữ liệu mục tiêu đang xung đột/)).toBeNull();
  });

  it("keeps workbook checksum and lifecycle interpretation in collapsed technical detail", async () => {
    vi.spyOn(recipeWorkbook, "reviewRecipeWorkbook").mockResolvedValue({
      fileName: "cong-thuc.xlsx",
      canonicalJson: '{"rows":[]}',
      checksum: "a".repeat(64),
      rows: [],
      errors: [],
      warnings: [],
      sourceCounts: {
        dishes: 2,
        recipes: 3,
        recipeVersions: 3,
        recipeLines: 7,
      },
      lifecycleInterpretation: "Chỉ tạo phiên bản công thức NHÁP.",
    });
    renderWorkbench();
    await openCreation();
    fireEvent.click(screen.getByRole("button", { name: "Nhập workbook" }));
    fireEvent.change(screen.getByLabelText("Workbook công thức .xlsx"), {
      target: { files: [new File(["fixture"], "cong-thuc.xlsx")] },
    });

    expect(await screen.findByText("Số món")).toBeVisible();
    expect(screen.getByText("Số công thức")).toBeVisible();
    expect(screen.getByText("Số dòng nguyên liệu")).toBeVisible();
    expect(screen.getByText("Lỗi cần xử lý")).toBeVisible();
    expect(screen.getByText("Kết quả kiểm tra")).toBeVisible();
    expect(screen.getByText("Checksum")).not.toBeVisible();
    expect(
      screen.getByText(/Chỉ tạo phiên bản công thức NHÁP/),
    ).not.toBeVisible();

    fireEvent.click(screen.getByText("Chi tiết kỹ thuật"));
    expect(screen.getByText("Checksum")).toBeVisible();
    expect(screen.getByText(/Chỉ tạo phiên bản công thức NHÁP/)).toBeVisible();
  });

  it("Save makes an eligible pre-use Recipe available through one backend command", async () => {
    const base = createReviewRecipeApi("ready");
    const saveRecipe = vi.spyOn(base, "saveRecipe");
    const releaseRecipe = vi.spyOn(base, "releaseRecipe");
    renderWorkbench(base);
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(screen.getAllByText("Sẵn sàng cho Lập nhu cầu")).not.toHaveLength(
        0,
      ),
    );
    expect(saveRecipe).toHaveBeenCalledTimes(1);
    expect(releaseRecipe).not.toHaveBeenCalled();
    expect(
      screen.queryByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeNull();
  });

  it("renders an operationally used identity read-only and directs it to Change Order", async () => {
    const api = overrideSelection((selected) => {
      selected.locked_for_normal_editing = true;
      selected.lock_reason =
        "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.";
      selected.business_status = "LOCKED";
      selected.allowed_actions.save_recipe = false;
      selected.disabled_reason_codes.save_recipe = "SAVE_OPERATIONALLY_LOCKED";
      selected.disabled_reasons.save_recipe = selected.lock_reason;
    });
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    renderWorkbench(api);
    await openCreation();

    expect(screen.getByRole("alert")).toHaveTextContent(
      "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
    );
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toBeDisabled();
    expect(
      screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"),
    ).toBeDisabled();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Sao chép công thức" }),
    ).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Đi đến Điều chỉnh" }));
    expect(
      await screen.findByRole("tab", { name: "Điều chỉnh", selected: true }),
    ).toBeInTheDocument();
    expect(saveRecipe).not.toHaveBeenCalled();
  });

  it("does not silently discard unsaved work when changing Dish or navigation", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });

    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    expect(
      screen.getByRole("heading", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: "Danh sách" }));
    expect(
      screen.getByRole("tab", { name: "Tạo món & công thức", selected: true }),
    ).toBeInTheDocument();
    expect(confirm).toHaveBeenCalledTimes(2);
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    expect(screen.queryByLabelText("Biểu mẫu món ăn")).toBeNull();
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toHaveValue(24);
    expect(confirm).toHaveBeenCalledTimes(3);
  });

  it("loads the catalog Dish context before entering creation instead of retaining another Dish lock", async () => {
    renderWorkbench(lockedDishApi());
    const rice = (await screen.findByText("Cơm trắng")).closest("tr")!;
    fireEvent.click(within(rice).getByRole("button", { name: "Xem" }));
    await waitFor(() =>
      expect(screen.getByRole("heading", { name: "Cơm trắng" })).toBeVisible(),
    );
    await openCreation();
    expect(screen.queryByRole("alert")).toBeNull();
    expect(
      screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"),
    ).toBeEnabled();
    expect(screen.queryByLabelText(/Định lượng Bí đỏ/)).toBeNull();
  });

  it("keeps an unknown Save blocked when authoritative readback does not match and never retries", async () => {
    const base = createReviewRecipeApi("ready");
    const saveRecipe = vi.fn(async (): Promise<AtlasRpcResult> => ({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "The local Supabase service could not be reached.",
      },
    }));
    renderWorkbench({ ...base, saveRecipe });
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(/Chưa xác định thao tác Lưu vừa rồi/),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(saveRecipe).toHaveBeenCalledTimes(1);
    fireEvent.click(
      screen.getByRole("button", { name: "Đối soát kết quả Lưu" }),
    );
    expect(
      await screen.findByText(/Dữ liệu đọc lại chưa khớp nội dung Lưu/),
    ).toBeVisible();
    expect(
      screen.getByText(/Chưa xác định thao tác Lưu vừa rồi đã hoàn tất/),
    ).toBeVisible();
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toHaveValue(24);
    expect(saveRecipe).toHaveBeenCalledTimes(1);
  });

  it("blocks a known successful Save until the exact authoring content can be read back", async () => {
    const api = createReviewRecipeApi("ready");
    const realSave = api.saveRecipe;
    const realEffective = api.getEffectiveWorkbench;
    let saved = false;
    let failOnce = true;
    const saveRecipe = vi
      .spyOn(api, "saveRecipe")
      .mockImplementation(async (request) => {
        const result = await realSave(request);
        saved = true;
        return result;
      });
    vi.spyOn(api, "getEffectiveWorkbench").mockImplementation(
      async (...args) => {
        if (saved && failOnce) {
          failOnce = false;
          return {
            kind: "transport_error",
            diagnostic: {
              code: "NETWORK_FAILURE",
              safeMessage: "Readback failed after commit.",
            },
          };
        }
        return realEffective(...args);
      },
    );
    renderWorkbench(api);
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(
      (await screen.findAllByText(/đã ghi nhận Lưu.*chưa đọc lại được/i))[0],
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toHaveValue(24);
    fireEvent.click(
      screen.getByRole("button", { name: "Đối soát kết quả Lưu" }),
    );
    await waitFor(() =>
      expect(
        screen.queryByRole("button", { name: "Đối soát kết quả Lưu" }),
      ).toBeNull(),
    );
    expect(saveRecipe).toHaveBeenCalledTimes(1);
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toHaveValue(24);
  });

  it("keeps technical version evidence behind support history disclosure", async () => {
    renderWorkbench();
    await openCreation();
    const history = screen.getByText("Lịch sử công thức");
    expect(history.closest("details")).not.toHaveAttribute("open");
    expect(screen.getByText(/Số lưu trữ:/)).not.toBeVisible();
    fireEvent.click(history);
    fireEvent.click(screen.getByText("Chi tiết hỗ trợ"));
    expect(screen.getByText(/Số lưu trữ:/)).toBeVisible();
  });
});
