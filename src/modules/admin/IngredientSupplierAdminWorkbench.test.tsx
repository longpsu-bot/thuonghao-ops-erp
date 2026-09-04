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
import { atlasTheme } from "../../theme";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
import type { MasterDataApi } from "../atlas/master-data/masterDataApi";
import { IngredientSupplierAdminWorkbench } from "./IngredientSupplierAdminWorkbench";

afterEach(cleanup);

const authSubject = "10000000-0000-0000-0000-000000000101";
const authState = {
  status: "authenticated",
  authSubject,
  user: { id: authSubject },
  session: {
    access_token: "test",
    refresh_token: "test",
    expires_in: 3600,
    token_type: "bearer",
    user: { id: authSubject },
  },
} as unknown as AtlasAuthState;

const suppliers = Array.from({ length: 7 }, (_, index) => ({
  supplier_id: `supplier-${index + 1}`,
  supplier_code: `supplier-${index + 1}`,
  supplier_name: index === 0 ? "NCC Minh Tâm" : `NCC ${index + 1}`,
  supplier_status: "ACTIVE" as const,
  contact_name: index === 0 ? "Nguyễn Minh" : null,
  contact_phone: index === 0 ? "0900000001" : null,
  contact_email: index === 0 ? "minh@example.invalid" : null,
  version: index === 0 ? 7 : 1,
}));

const ingredientTypes = [
  {
    ingredient_type_id: "type-dry",
    ingredient_type_code: "thuc_pham_kho_gia_vi",
    ingredient_type_name: "Thực phẩm khô - gia vị",
    display_order: 15,
    ingredient_type_status: "ACTIVE" as const,
  },
  {
    ingredient_type_id: "type-vegetable",
    ingredient_type_code: "rau_cu_qua",
    ingredient_type_name: "Rau củ quả",
    display_order: 12,
    ingredient_type_status: "ACTIVE" as const,
  },
];

const ingredientOrderGroups = [
  {
    ingredient_order_group_id: "group-pantry",
    ingredient_order_group_code: "pantry",
    ingredient_order_group_name: "Hàng đặt riêng",
    display_order: 1,
    ingredient_order_group_status: "ACTIVE" as const,
  },
  {
    ingredient_order_group_id: "group-vegetable",
    ingredient_order_group_code: "daily_vegetable",
    ingredient_order_group_name: "Rau củ",
    display_order: 2,
    ingredient_order_group_status: "ACTIVE" as const,
  },
];

function ingredient(index: number) {
  return {
    ingredient_id: `ingredient-${index}`,
    ingredient_code: index === 1 ? "rice" : `ingredient-${index}`,
    ingredient_name: index === 1 ? "Gạo Jasmine" : `Nguyên liệu ${index}`,
    ingredient_status: "ACTIVE" as const,
    ingredient_type_id: index === 1 ? "type-dry" : "type-vegetable",
    ingredient_type_name: index === 1 ? "Thực phẩm khô - gia vị" : "Rau củ quả",
    ingredient_order_group_id: index === 1 ? "group-pantry" : "group-vegetable",
    ingredient_order_group_name: index === 1 ? "Hàng đặt riêng" : "Rau củ",
    ingredient_type: index === 1 ? "Thực phẩm khô - gia vị" : "Rau củ quả",
    shopping_type: index === 1 ? "Hàng đặt riêng" : "Rau củ",
    purchase_unit_id: "unit-kg",
    purchase_unit_code: "kg",
    purchase_unit_name: "Kilôgam",
    order_step: index === 1 ? 0.1 : 1,
    version: index === 1 ? 4 : 1,
    supplier_priorities:
      index === 1
        ? [
            {
              supplier_eligibility_id: "eligibility-1",
              supplier_id: "supplier-1",
              supplier_name: "NCC Minh Tâm",
              priority: 1,
            },
          ]
        : [],
  };
}

function masterData(ingredientCount = 1) {
  return {
    ingredients: Array.from({ length: ingredientCount }, (_, index) =>
      ingredient(index + 1),
    ),
    suppliers,
    units: [
      {
        unit_id: "unit-kg",
        unit_code: "kg",
        unit_name: "Kilôgam",
        unit_status: "ACTIVE" as const,
      },
    ],
    ingredient_types: ingredientTypes,
    ingredient_order_groups: ingredientOrderGroups,
  };
}

function success(extra: Record<string, unknown>): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...extra },
  };
}

const stale: AtlasRpcResult = {
  kind: "backend_error",
  error: {
    success: false,
    error_code: "STALE_VERSION",
    safe_message: "Stale.",
  },
};

const unknownOutcome: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: {
    code: "NETWORK_FAILURE",
    safeMessage: "Network failed.",
  },
};

type ApiOptions = {
  data?: ReturnType<typeof masterData>;
  readResults?: AtlasRpcResult[];
  writes?: Partial<
    Record<
      | "createIngredient"
      | "updateIngredient"
      | "setIngredientLifecycle"
      | "createSupplier"
      | "updateSupplier"
      | "replacePriorities",
      AtlasRpcResult
    >
  >;
};

function createApi(options: ApiOptions = {}) {
  const data = options.data ?? masterData();
  const reads = options.readResults ?? [success(data)];
  const getIngredientsAndSuppliers = vi.fn();
  reads.forEach((result) =>
    getIngredientsAndSuppliers.mockResolvedValueOnce(result),
  );
  getIngredientsAndSuppliers.mockResolvedValue(reads.at(-1));
  const write = (name: keyof NonNullable<ApiOptions["writes"]>) =>
    vi
      .fn()
      .mockResolvedValue(
        options.writes?.[name] ??
          success({ safe_operator_message: `${name} accepted.` }),
      );
  return {
    getIngredientsAndSuppliers,
    createIngredient: write("createIngredient"),
    updateIngredient: write("updateIngredient"),
    setIngredientLifecycle: write("setIngredientLifecycle"),
    createSupplier: write("createSupplier"),
    updateSupplier: write("updateSupplier"),
    replacePriorities: write("replacePriorities"),
  };
}

async function renderReady(connected = createApi()) {
  render(
    <MantineProvider theme={atlasTheme} forceColorScheme="light">
      <IngredientSupplierAdminWorkbench
        authState={authState}
        api={connected as unknown as MasterDataApi}
      />
    </MantineProvider>,
  );
  expect(await screen.findByText("Gạo Jasmine")).toBeInTheDocument();
  return connected;
}

function firstButton(name: string) {
  return screen.getAllByRole("button", { name })[0]!;
}

function editIngredientName(value: string) {
  fireEvent.click(firstButton("Sửa"));
  fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
    target: { value },
  });
}

function openSupplierEditor() {
  fireEvent.click(screen.getByRole("tab", { name: /Nhà cung ứng/ }));
  fireEvent.click(firstButton("Xem và sửa"));
}

function editSupplierName(value: string) {
  openSupplierEditor();
  fireEvent.change(screen.getByLabelText("Tên nhà cung ứng"), {
    target: { value },
  });
}

function openPriorityEditor() {
  fireEvent.click(firstButton("Ưu tiên"));
  fireEvent.click(screen.getByRole("button", { name: "Thêm nhà cung ứng" }));
}

async function openReview() {
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  const dialog = await screen.findByRole("dialog", { name: "Xem thay đổi" });
  await waitFor(() => expect(dialog).toBeVisible());
  return dialog;
}

async function saveReview() {
  const dialog = await openReview();
  fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));
  return dialog;
}

function fillIngredientCreate() {
  fireEvent.click(screen.getByRole("button", { name: "Tạo nguyên liệu" }));
  fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
    target: { value: "Bí đỏ" },
  });
  fireEvent.change(screen.getByLabelText("Đơn vị mua"), {
    target: { value: "unit-kg" },
  });
  fireEvent.change(screen.getByLabelText("Loại nguyên liệu"), {
    target: { value: "type-vegetable" },
  });
  fireEvent.change(screen.getByLabelText("Nhóm đặt hàng"), {
    target: { value: "group-vegetable" },
  });
  fireEvent.change(screen.getByLabelText("Mức làm tròn khi đặt hàng"), {
    target: { value: "2" },
  });
}

describe("Ingredient and Supplier operator workflow", () => {
  it("keeps internal Ingredient and Supplier codes searchable without showing them in normal lists", async () => {
    await renderReady();
    fireEvent.change(screen.getByLabelText("Tìm nguyên liệu"), {
      target: { value: "rice" },
    });
    expect(screen.getByText("Gạo Jasmine")).toBeVisible();
    expect(screen.queryByText("rice")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: /Nhà cung ứng/ }));
    fireEvent.change(screen.getByLabelText("Tìm nhà cung ứng"), {
      target: { value: "supplier-1" },
    });
    expect(screen.getByText("NCC Minh Tâm")).toBeVisible();
    expect(screen.queryByText("supplier-1")).not.toBeInTheDocument();
  });

  it("shows only Vietnamese human Unit names in the catalog, create/edit choices, and Review", async () => {
    const data = masterData();
    data.units = [
      {
        unit_id: "unit-kg",
        unit_code: "v1-unit-kg",
        unit_name: "Kilogram",
        unit_status: "ACTIVE",
      },
      {
        unit_id: "unit-bo",
        unit_code: "v1-unit-bo",
        unit_name: "Bó",
        unit_status: "ACTIVE",
      },
      {
        unit_id: "unit-bich",
        unit_code: "v1-unit-bich",
        unit_name: "Bịch",
        unit_status: "ACTIVE",
      },
      {
        unit_id: "unit-hu-1",
        unit_code: "v1-unit-hu-1",
        unit_name: "Hũ",
        unit_status: "ACTIVE",
      },
      {
        unit_id: "unit-hu-2",
        unit_code: "v1-unit-hu-2",
        unit_name: "Hủ",
        unit_status: "ACTIVE",
      },
    ];
    data.ingredients[0]!.purchase_unit_code = "v1-unit-kg";
    data.ingredients[0]!.purchase_unit_name = "Kilogram";
    const connected = await renderReady(createApi({ data }));
    expect(screen.queryByText(/v1-unit-/)).not.toBeInTheDocument();
    fillIngredientCreate();
    const choices = within(screen.getByLabelText("Đơn vị mua")).getAllByRole(
      "option",
    );
    expect(choices.map((choice) => choice.textContent)).toEqual([
      "Chọn đơn vị",
      "Bịch",
      "Bó",
      "Hủ",
      "Hũ",
      "Kilogram",
    ]);
    expect(choices.map((choice) => choice.getAttribute("value"))).toEqual([
      "",
      "unit-bich",
      "unit-bo",
      "unit-hu-2",
      "unit-hu-1",
      "unit-kg",
    ]);
    const createReview = await openReview();
    expect(within(createReview).getByText("Kilogram")).toBeVisible();
    expect(screen.queryByText(/v1-unit-/)).not.toBeInTheDocument();
    fireEvent.click(
      within(createReview).getByRole("button", { name: "Quay lại" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Hủy" }));
    editIngredientName("Gạo mới");
    expect(
      within(screen.getByLabelText("Đơn vị mua")).getByRole("option", {
        name: "Kilogram",
      }),
    ).toHaveValue("unit-kg");
    const editReview = await openReview();
    expect(within(editReview).getAllByText("Kilogram")).toHaveLength(2);
    expect(screen.queryByText(/v1-unit-/)).not.toBeInTheDocument();
    expect(connected.createIngredient).not.toHaveBeenCalled();
  });

  it("renders both classifications as API-backed business selects with corrected labels", async () => {
    await renderReady();
    fireEvent.click(firstButton("Sửa"));

    const type = screen.getByLabelText("Loại nguyên liệu");
    const group = screen.getByLabelText("Nhóm đặt hàng");
    expect(type.tagName).toBe("SELECT");
    expect(group.tagName).toBe("SELECT");
    expect(
      within(type).getByRole("option", { name: "Rau củ quả" }),
    ).toBeVisible();
    expect(
      within(group).getByRole("option", { name: "Hàng đặt riêng" }),
    ).toBeVisible();
    expect(screen.queryByLabelText("Cách mua")).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Bước đặt hàng")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Mức làm tròn khi đặt hàng")).toHaveAttribute(
      "type",
      "number",
    );
  });

  it("preserves both catalog jobs, search/filter behavior, fields, and all 75 matching Ingredients", async () => {
    const connected = createApi({ data: masterData(75) });
    await renderReady(connected);

    expect(screen.getByRole("tab", { name: "Nguyên liệu 75" })).toBeVisible();
    expect(screen.getByRole("tab", { name: "Nhà cung ứng 7" })).toBeVisible();
    expect(screen.getByText("Nguyên liệu 75")).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Sửa" })).toHaveLength(75);

    fireEvent.change(screen.getByLabelText("Tìm nguyên liệu"), {
      target: { value: "Nguyên liệu 75" },
    });
    expect(screen.getByText("Nguyên liệu 75")).toBeInTheDocument();
    expect(screen.queryByText("Nguyên liệu 74")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Trạng thái"), {
      target: { value: "INACTIVE" },
    });
    expect(
      screen.getByText("Không có nguyên liệu phù hợp bộ lọc."),
    ).toBeVisible();

    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng 7" }));
    fireEvent.change(screen.getByLabelText("Tìm nhà cung ứng"), {
      target: { value: "NCC 7" },
    });
    expect(screen.getByText("NCC 7")).toBeVisible();
    expect(screen.queryByText("Nguyễn Minh")).not.toBeInTheDocument();
  });

  it("reviews an exact new Ingredient, preserves the draft on return, and writes only from a fresh Review", async () => {
    const refreshed = masterData();
    refreshed.ingredients.push({ ...ingredient(2), ingredient_name: "Bí đỏ" });
    const connected = createApi({
      readResults: [success(masterData()), success(refreshed)],
    });
    await renderReady(connected);

    fireEvent.click(screen.getByRole("button", { name: "Tạo nguyên liệu" }));
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: /^Lưu$/ }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Hủy" }));
    fillIngredientCreate();
    expect(screen.queryByLabelText("Mã nguyên liệu")).not.toBeInTheDocument();

    let dialog = await openReview();
    expect(connected.createIngredient).not.toHaveBeenCalled();
    await waitFor(() =>
      expect(within(dialog).getByText("Nguyên liệu mới")).toBeVisible(),
    );
    expect(within(dialog).getByText("Bí đỏ")).toHaveClass("changed");
    expect(within(dialog).getByText("Kilôgam")).toBeVisible();
    fireEvent.click(within(dialog).getByRole("button", { name: "Quay lại" }));
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument(),
    );
    expect(screen.getByLabelText("Tên nguyên liệu")).toHaveValue("Bí đỏ");

    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: "Bí đỏ hồ lô" },
    });
    expect(
      screen.queryByRole("button", { name: /^Lưu$/ }),
    ).not.toBeInTheDocument();
    dialog = await openReview();
    expect(within(dialog).getByText("Bí đỏ hồ lô")).toHaveClass("changed");
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(connected.createIngredient).toHaveBeenCalledOnce(),
    );
    expect(connected.createIngredient).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 1,
        payload: {
          ingredient_name: "Bí đỏ hồ lô",
          purchase_unit_id: "unit-kg",
          ingredient_type_id: "type-vegetable",
          ingredient_order_group_id: "group-vegetable",
          order_step: 2,
        },
      }),
    );
    await waitFor(() =>
      expect(connected.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2),
    );
    expect(screen.queryByLabelText("Tên nguyên liệu")).not.toBeInTheDocument();
  });

  it("reviews Ingredient Before/After values and saves the reviewed version and payload exactly once", async () => {
    const updated = masterData();
    updated.ingredients[0] = {
      ...updated.ingredients[0]!,
      ingredient_name: "Gạo Jasmine mới",
      order_step: 10,
      version: 5,
    };
    const connected = createApi({
      readResults: [success(masterData()), success(updated)],
    });
    await renderReady(connected);
    editIngredientName("Gạo Jasmine mới");
    fireEvent.change(screen.getByLabelText("Mức làm tròn khi đặt hàng"), {
      target: { value: "10" },
    });

    const dialog = await openReview();
    expect(connected.updateIngredient).not.toHaveBeenCalled();
    expect(within(dialog).getByText("Gạo Jasmine mới")).toHaveClass("changed");
    expect(within(dialog).getByText("10")).toHaveClass("changed");
    expect(within(dialog).getAllByText("Kilôgam").at(-1)).toHaveClass(
      "unchanged",
    );
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(connected.updateIngredient).toHaveBeenCalledOnce(),
    );
    expect(connected.updateIngredient).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 4,
        payload: {
          ingredient_id: "ingredient-1",
          ingredient_name: "Gạo Jasmine mới",
          purchase_unit_id: "unit-kg",
          ingredient_type_id: "type-dry",
          ingredient_order_group_id: "group-pantry",
          order_step: 10,
        },
      }),
    );
  });

  it("treats canonical Ingredient and Supplier representations as no-op edits", async () => {
    const data = masterData();
    data.ingredients[0]!.order_step = 5;
    const connected = createApi({ data });
    await renderReady(connected);
    fireEvent.click(firstButton("Sửa"));
    const review = screen.getByRole("button", { name: "Xem thay đổi" });

    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: " Gạo Jasmine " },
    });
    fireEvent.change(screen.getByLabelText("Mức làm tròn khi đặt hàng"), {
      target: { value: "5.0" },
    });
    fireEvent.change(screen.getByLabelText("Loại nguyên liệu"), {
      target: { value: "type-dry" },
    });
    fireEvent.change(screen.getByLabelText("Nhóm đặt hàng"), {
      target: { value: "group-pantry" },
    });
    expect(review).toBeDisabled();
    expect(
      screen.queryByRole("dialog", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(connected.updateIngredient).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "Hủy" }));
    fireEvent.click(screen.getByRole("tab", { name: /Nhà cung ứng/ }));
    fireEvent.click(screen.getAllByRole("button", { name: "Xem và sửa" })[1]!);
    fireEvent.change(screen.getByLabelText("Tên nhà cung ứng"), {
      target: { value: " NCC 2 " },
    });
    fireEvent.change(screen.getByLabelText("Người liên hệ"), {
      target: { value: "   " },
    });
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(connected.updateSupplier).not.toHaveBeenCalled();
  });

  it("reviews and creates a Supplier without exposing a direct Save", async () => {
    const connected = createApi();
    await renderReady(connected);
    fireEvent.click(screen.getByRole("tab", { name: /Nhà cung ứng/ }));
    fireEvent.click(screen.getByRole("button", { name: "Tạo nhà cung ứng" }));
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    expect(screen.queryByLabelText("Mã nhà cung ứng")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Tên nhà cung ứng"), {
      target: { value: "NCC Mới" },
    });
    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "new@example.invalid" },
    });
    const dialog = await openReview();
    expect(connected.createSupplier).not.toHaveBeenCalled();
    expect(within(dialog).getByText("Nhà cung ứng mới")).toBeVisible();
    expect(within(dialog).getByText("new@example.invalid")).toHaveClass(
      "changed",
    );
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(connected.createSupplier).toHaveBeenCalledOnce(),
    );
    expect(connected.createSupplier.mock.calls[0]![0]).toMatchObject({
      expected_version: 1,
      payload: {
        supplier_name: "NCC Mới",
        contact_name: "",
        contact_phone: "",
        contact_email: "new@example.invalid",
      },
    });
    expect(
      connected.createSupplier.mock.calls[0]![0].payload,
    ).not.toHaveProperty("supplier_code");
  });

  it("reviews and updates a Supplier with the reviewed expected version", async () => {
    const connected = createApi();
    await renderReady(connected);
    editSupplierName("NCC Minh Tâm mới");
    const dialog = await openReview();
    expect(within(dialog).getByText("NCC Minh Tâm mới")).toHaveClass("changed");
    expect(connected.updateSupplier).not.toHaveBeenCalled();
    fireEvent.click(within(dialog).getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(connected.updateSupplier).toHaveBeenCalledOnce(),
    );
    expect(connected.updateSupplier.mock.calls[0]![0]).toMatchObject({
      expected_version: 7,
      payload: {
        supplier_id: "supplier-1",
        supplier_name: "NCC Minh Tâm mới",
        contact_name: "Nguyễn Minh",
        contact_phone: "0900000001",
        contact_email: "minh@example.invalid",
      },
    });
  });

  it("enforces six unique active Suppliers and priorities 1–6 before Review", async () => {
    const connected = createApi();
    await renderReady(connected);
    fireEvent.click(firstButton("Ưu tiên"));
    for (let index = 0; index < 5; index += 1) {
      fireEvent.click(
        screen.getByRole("button", { name: "Thêm nhà cung ứng" }),
      );
    }
    expect(
      screen.getByRole("button", { name: "Thêm nhà cung ứng" }),
    ).toBeDisabled();

    fireEvent.change(screen.getByLabelText("Nhà cung ứng ưu tiên 2"), {
      target: { value: "supplier-1" },
    });
    expect(screen.getByLabelText("Nhà cung ứng ưu tiên 2")).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Nhà cung ứng ưu tiên 2"), {
      target: { value: "supplier-2" },
    });
    fireEvent.change(screen.getByLabelText("Mức ưu tiên 2"), {
      target: { value: "7" },
    });
    expect(screen.getByLabelText("Mức ưu tiên 2")).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    expect(connected.replacePriorities).not.toHaveBeenCalled();
  });

  it("reviews complete current/resulting priority lists and submits the exact reviewed list once", async () => {
    const connected = createApi();
    await renderReady(connected);
    openPriorityEditor();
    const dialog = await openReview();
    expect(connected.replacePriorities).not.toHaveBeenCalled();
    expect(within(dialog).getByText("Hiện tại")).toBeVisible();
    expect(within(dialog).getByText("Sau thay đổi")).toBeVisible();
    expect(within(dialog).getAllByText("NCC Minh Tâm")).toHaveLength(2);
    expect(within(dialog).getByText("NCC 2")).toBeVisible();
    fireEvent.click(within(dialog).getByRole("button", { name: "Quay lại" }));
    expect(screen.getByLabelText("Nhà cung ứng ưu tiên 2")).toHaveValue(
      "supplier-2",
    );
    const freshDialog = await openReview();
    fireEvent.click(within(freshDialog).getByRole("button", { name: "Lưu" }));
    await waitFor(() =>
      expect(connected.replacePriorities).toHaveBeenCalledOnce(),
    );
    expect(connected.replacePriorities.mock.calls[0]![0]).toMatchObject({
      expected_version: 4,
      payload: {
        ingredient_id: "ingredient-1",
        priorities: [
          { supplier_id: "supplier-1", priority: 1 },
          { supplier_id: "supplier-2", priority: 2 },
        ],
      },
    });
  });

  it("keeps Ingredient lifecycle separate and calls it once only after consequence confirmation", async () => {
    const connected = createApi();
    await renderReady(connected);
    fireEvent.click(firstButton("Ngừng dùng"));
    expect(screen.getByLabelText("Xác nhận thay đổi trạng thái")).toBeVisible();
    expect(
      screen.getByText(/danh sách ưu tiên nhà cung ứng.*sẽ được gỡ/),
    ).toBeVisible();
    expect(
      screen.queryByRole("dialog", { name: "Xem thay đổi" }),
    ).not.toBeInTheDocument();
    expect(connected.setIngredientLifecycle).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận thay đổi" }));
    await waitFor(() =>
      expect(connected.setIngredientLifecycle).toHaveBeenCalledOnce(),
    );
  });

  it.each([
    ["Ingredient", "updateIngredient"],
    ["Supplier", "updateSupplier"],
    ["priority", "replacePriorities"],
  ] as const)(
    "invalidates %s Review on stale rejection and requires authoritative refresh",
    async (flow, method) => {
      const connected = createApi({ writes: { [method]: stale } });
      await renderReady(connected);
      if (flow === "Ingredient") editIngredientName("Gạo mới");
      else if (flow === "Supplier") editSupplierName("NCC mới");
      else openPriorityEditor();
      await saveReview();

      expect(
        await screen.findByText(
          /Dữ liệu chính thức đã được người khác cập nhật/,
        ),
      ).toBeVisible();
      expect(connected[method]).toHaveBeenCalledOnce();
      await waitFor(() =>
        expect(
          screen.queryByRole("dialog", { name: "Xem thay đổi" }),
        ).not.toBeInTheDocument(),
      );
      expect(
        screen.getByRole("button", { name: "Xem thay đổi" }),
      ).toBeDisabled();
      fireEvent.click(
        screen.getByRole("button", { name: "Tải lại dữ liệu chính thức" }),
      );
      await waitFor(() =>
        expect(connected.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2),
      );
      expect(
        screen.queryByRole("button", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument();
      expect(connected[method]).toHaveBeenCalledOnce();
    },
  );

  it.each([
    ["Ingredient create", "createIngredient"],
    ["Supplier update", "updateSupplier"],
    ["priority", "replacePriorities"],
  ] as const)(
    "locks all writes after unknown %s outcome and never retries",
    async (flow, method) => {
      const connected = createApi({ writes: { [method]: unknownOutcome } });
      await renderReady(connected);
      if (flow === "Ingredient create") fillIngredientCreate();
      else if (flow === "Supplier update") editSupplierName("NCC mới");
      else openPriorityEditor();
      await saveReview();

      expect(
        await screen.findByText(/Atlas chưa thể xác nhận lần lưu đã hoàn tất/),
      ).toBeVisible();
      expect(connected[method]).toHaveBeenCalledOnce();
      const createButton =
        flow === "Supplier update" ? "Tạo nhà cung ứng" : "Tạo nguyên liệu";
      expect(screen.getByRole("button", { name: createButton })).toBeDisabled();
      const otherTab =
        flow === "Supplier update" ? /Nguyên liệu/ : /Nhà cung ứng/;
      const otherCreate =
        flow === "Supplier update" ? "Tạo nguyên liệu" : "Tạo nhà cung ứng";
      fireEvent.click(screen.getByRole("tab", { name: otherTab }));
      expect(
        screen.getByText(/Atlas chưa thể xác nhận lần lưu đã hoàn tất/),
      ).toBeVisible();
      expect(screen.getByRole("button", { name: otherCreate })).toBeDisabled();
      fireEvent.click(
        screen.getByRole("button", { name: "Tải lại dữ liệu chính thức" }),
      );
      await waitFor(() =>
        expect(connected.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2),
      );
      expect(connected[method]).toHaveBeenCalledOnce();
      expect(
        screen.queryByRole("button", { name: "Xem thay đổi" }),
      ).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: otherCreate })).toBeEnabled();
    },
  );

  it.each([
    ["Ingredient", "updateIngredient"],
    ["Supplier", "updateSupplier"],
    ["priority", "replacePriorities"],
  ] as const)(
    "does not retry successful %s command when authoritative readback fails",
    async (flow, method) => {
      const connected = createApi({
        readResults: [
          success(masterData()),
          unknownOutcome,
          success(masterData()),
        ],
      });
      await renderReady(connected);
      if (flow === "Ingredient") editIngredientName("Gạo mới");
      else if (flow === "Supplier") editSupplierName("NCC mới");
      else openPriorityEditor();
      await saveReview();

      expect(
        await screen.findByText(
          /Thao tác đã được chấp nhận nhưng chưa tải lại được/,
        ),
      ).toBeVisible();
      expect(connected[method]).toHaveBeenCalledOnce();
      const createButton =
        flow === "Supplier" ? "Tạo nhà cung ứng" : "Tạo nguyên liệu";
      expect(screen.getByRole("button", { name: createButton })).toBeDisabled();
      fireEvent.click(
        screen.getByRole("button", { name: "Tải lại dữ liệu chính thức" }),
      );
      await waitFor(() =>
        expect(connected.getIngredientsAndSuppliers).toHaveBeenCalledTimes(3),
      );
      expect(connected[method]).toHaveBeenCalledOnce();
      expect(screen.getByRole("button", { name: createButton })).toBeEnabled();
    },
  );

  it.each([1280, 650])(
    "keeps the Review modal bounded without page overflow at %ipx",
    async (viewportWidth) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: viewportWidth,
      });
      await renderReady();
      editIngredientName("Gạo mới");
      const dialog = await openReview();
      const body = dialog.querySelector<HTMLElement>(".mantine-Modal-body");
      expect(dialog).toHaveStyle({ maxHeight: "86dvh", overflowX: "hidden" });
      expect(body).toHaveStyle({
        maxHeight: "calc(86dvh - 64px)",
        overflowX: "hidden",
      });
      expect(document.documentElement.scrollWidth).toBeLessThanOrEqual(
        viewportWidth,
      );
    },
  );
});
