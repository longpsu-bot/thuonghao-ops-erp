import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type {
  AtlasRpcResult,
  IngredientSupplierMasterDataApi,
} from "../bridges/ingredientSupplierMasterData";
import { IngredientSupplierWorkbench } from "./IngredientSupplierWorkbench";
import { createIngredientSupplierReviewFixture } from "./ingredientSupplierReviewFixtures";

afterEach(cleanup);

const ingredients = [
  {
    ingredient_id: "ingredient-active",
    ingredient_code: "NL-BI-MAT",
    ingredient_name: "Bí mật",
    ingredient_status: "ACTIVE" as const,
    ingredient_type_id: "type-active",
    ingredient_type_name: "Rau củ",
    ingredient_order_group_id: "group-active",
    ingredient_order_group_name: "Hàng ngày",
    ingredient_type: "Rau củ",
    shopping_type: "Hàng ngày",
    purchase_unit_id: "unit-active",
    purchase_unit_code: "KG",
    purchase_unit_name: "Kilôgam",
    order_step: 0.5,
    version: 5,
    supplier_priorities: [
      {
        supplier_eligibility_id: "eligibility-old",
        supplier_id: "supplier-inactive",
        supplier_name: "NCC Đã nghỉ",
        priority: 1,
      },
    ],
  },
  {
    ingredient_id: "ingredient-inactive",
    ingredient_code: "NL-NGUNG",
    ingredient_name: "Nguyên liệu ngừng dùng",
    ingredient_status: "INACTIVE" as const,
    ingredient_type_id: "type-inactive",
    ingredient_type_name: "Loại cũ",
    ingredient_order_group_id: "group-inactive",
    ingredient_order_group_name: "Nhóm cũ",
    ingredient_type: "Loại cũ",
    shopping_type: "Nhóm cũ",
    purchase_unit_id: "unit-inactive",
    purchase_unit_code: "OLD",
    purchase_unit_name: "Đơn vị cũ",
    order_step: 1,
    version: 2,
    supplier_priorities: [],
  },
  {
    ingredient_id: "ingredient-archived",
    ingredient_code: "NL-LUU-TRU",
    ingredient_name: "Nguyên liệu lưu trữ",
    ingredient_status: "ARCHIVED" as const,
    ingredient_type_id: "type-active",
    ingredient_type_name: "Rau củ",
    ingredient_order_group_id: "group-active",
    ingredient_order_group_name: "Hàng ngày",
    ingredient_type: "Rau củ",
    shopping_type: "Hàng ngày",
    purchase_unit_id: "unit-active",
    purchase_unit_code: "KG",
    purchase_unit_name: "Kilôgam",
    order_step: 1,
    version: 8,
    supplier_priorities: [],
  },
];

function readResult(): AtlasRpcResult {
  return {
    kind: "success",
    response: {
      success: true,
      ingredients,
      suppliers: [
        {
          supplier_id: "supplier-active",
          supplier_code: "NCC-MINH-TAM",
          supplier_name: "NCC Minh Tâm",
          supplier_status: "ACTIVE",
          contact_name: "Minh Tâm",
          contact_phone: "0901",
          contact_email: "tam@example.test",
          version: 3,
        },
        {
          supplier_id: "supplier-inactive",
          supplier_code: "NCC-NGHI",
          supplier_name: "NCC Đã nghỉ",
          supplier_status: "INACTIVE",
          contact_name: null,
          contact_phone: null,
          contact_email: null,
          version: 2,
        },
        {
          supplier_id: "supplier-suspended",
          supplier_code: "NCC-TAM-DUNG",
          supplier_name: "NCC Tạm dừng",
          supplier_status: "SUSPENDED",
          contact_name: null,
          contact_phone: null,
          contact_email: null,
          version: 4,
        },
      ],
      units: [
        {
          unit_id: "unit-active",
          unit_code: "KG",
          unit_name: "Kilôgam",
          unit_status: "ACTIVE",
        },
        {
          unit_id: "unit-other",
          unit_code: "OTHER",
          unit_name: "Đơn vị khác",
          unit_status: "INACTIVE",
        },
      ],
      ingredient_types: [
        {
          ingredient_type_id: "type-active",
          ingredient_type_code: "VEG",
          ingredient_type_name: "Rau củ",
          display_order: 1,
          ingredient_type_status: "ACTIVE",
        },
        {
          ingredient_type_id: "type-other",
          ingredient_type_code: "OTHER",
          ingredient_type_name: "Loại khác",
          display_order: 3,
          ingredient_type_status: "INACTIVE",
        },
      ],
      ingredient_order_groups: [
        {
          ingredient_order_group_id: "group-active",
          ingredient_order_group_code: "DAILY",
          ingredient_order_group_name: "Hàng ngày",
          display_order: 1,
          ingredient_order_group_status: "ACTIVE",
        },
        {
          ingredient_order_group_id: "group-other",
          ingredient_order_group_code: "OTHER",
          ingredient_order_group_name: "Nhóm khác",
          display_order: 3,
          ingredient_order_group_status: "INACTIVE",
        },
      ],
    },
  };
}

function createApi() {
  const success: AtlasRpcResult = {
    kind: "success",
    response: { success: true },
  };
  return {
    getIngredientsAndSuppliers: vi.fn().mockResolvedValue(readResult()),
    createIngredient: vi.fn().mockResolvedValue(success),
    updateIngredient: vi.fn().mockResolvedValue(success),
    setIngredientLifecycle: vi.fn().mockResolvedValue(success),
    createSupplier: vi.fn().mockResolvedValue(success),
    updateSupplier: vi.fn().mockResolvedValue(success),
    replacePriorities: vi.fn().mockResolvedValue(success),
  } satisfies IngredientSupplierMasterDataApi;
}

function renderWorkbench(api: IngredientSupplierMasterDataApi = createApi()) {
  render(
    <AtlasVNextProvider>
      <IngredientSupplierWorkbench authSubject="operator-1" api={api} />
    </AtlasVNextProvider>,
  );
  return api;
}

async function ready() {
  await screen.findByRole("heading", { level: 1, name: "Nguyên liệu" });
  await screen.findByText("Bí mật");
}

describe("IngredientSupplierWorkbench", () => {
  it("renders a dense Ingredient catalogue and searches hidden codes without displaying them", async () => {
    const api = renderWorkbench();
    await ready();
    expect(
      screen.getByRole("table", { name: "Danh mục nguyên liệu" }),
    ).toBeInTheDocument();
    expect(screen.queryByText("NL-BI-MAT")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Tìm nguyên liệu"), {
      target: { value: "nl-bi-mat" },
    });
    expect(screen.getByText("Bí mật")).toBeInTheDocument();
    expect(
      screen.queryByText("Nguyên liệu ngừng dùng"),
    ).not.toBeInTheDocument();
    expect(api.getIngredientsAndSuppliers).toHaveBeenCalledTimes(1);
  });

  it("creates an Ingredient from business fields only and offers active catalogues", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(screen.getByRole("button", { name: "Tạo nguyên liệu" }));
    const detail = screen.getByRole("complementary", {
      name: "Chi tiết nguyên liệu",
    });
    expect(within(detail).getByLabelText("Tên nguyên liệu")).toBeRequired();
    expect(
      within(detail).queryByLabelText(/mã nguyên liệu/i),
    ).not.toBeInTheDocument();
    expect(
      within(detail).getByRole("option", { name: "Rau củ" }),
    ).toBeInTheDocument();
    expect(
      within(detail).queryByRole("option", { name: /Loại khác/ }),
    ).not.toBeInTheDocument();
  });

  it("preserves only the current inactive catalogues while editing an existing Ingredient", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem / sửa Nguyên liệu ngừng dùng" }),
    );
    const detail = screen.getByRole("complementary", {
      name: "Chi tiết nguyên liệu",
    });
    expect(
      within(detail).getByRole("option", { name: "Loại cũ · ngừng dùng" }),
    ).toBeInTheDocument();
    expect(
      within(detail).queryByRole("option", { name: /Loại khác/ }),
    ).not.toBeInTheDocument();
    expect(
      within(detail).getByRole("option", { name: "Nhóm cũ · ngừng dùng" }),
    ).toBeInTheDocument();
    expect(
      within(detail).getByRole("option", { name: "Đơn vị cũ · ngừng dùng" }),
    ).toBeInTheDocument();
  });

  it("shows safe lifecycle actions and consequence copy while archived Ingredients remain view-only", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(screen.getByRole("button", { name: "Xem / sửa Bí mật" }));
    fireEvent.click(screen.getByRole("button", { name: "Ngừng dùng" }));
    expect(
      await screen.findByRole("dialog", { name: "Ngừng dùng nguyên liệu?" }),
    ).toHaveTextContent("Các ưu tiên nhà cung ứng hiện tại sẽ được gỡ.");
    fireEvent.click(screen.getByRole("button", { name: "Hủy" }));
    fireEvent.click(screen.getByRole("button", { name: "Đóng chi tiết" }));
    fireEvent.click(
      screen.getByRole("button", { name: "Xem Nguyên liệu lưu trữ" }),
    );
    expect(
      screen.getByText("Nguyên liệu đã lưu trữ chỉ có thể xem."),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Kích hoạt|Ngừng dùng|Lưu trữ/ }),
    ).not.toBeInTheDocument();
  });

  it("keeps inactive authoritative priority visible and blocks Review until removed", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(screen.getByRole("button", { name: "Xem / sửa Bí mật" }));
    fireEvent.click(screen.getByRole("button", { name: "Ưu tiên NCC" }));
    const editor = screen.getByRole("complementary", {
      name: "Ưu tiên nhà cung ứng",
    });
    expect(editor).toHaveTextContent("Hướng dẫn thứ tự lựa chọn khi mua hàng.");
    expect(editor).not.toHaveTextContent(/phân bổ|cam kết|đơn mua hàng/i);
    expect(within(editor).getByText("Ngừng hợp tác")).toBeInTheDocument();
    expect(
      within(editor).getByRole("button", { name: "Xem thay đổi" }),
    ).toBeDisabled();
    fireEvent.click(
      within(editor).getByRole("button", { name: "Gỡ NCC Đã nghỉ" }),
    );
    expect(
      within(editor).getByRole("button", { name: "Xem thay đổi" }),
    ).toBeEnabled();
  });

  it("shows Supplier status as read-only context without lifecycle controls", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    expect(
      screen.getByRole("heading", { level: 1, name: "Nhà cung ứng" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Đang hợp tác")).toBeInTheDocument();
    expect(screen.getByText("Ngừng hợp tác")).toBeInTheDocument();
    expect(screen.getByText("Tạm dừng")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem / sửa NCC Tạm dừng" }),
    );
    const detail = screen.getByRole("complementary", {
      name: "Chi tiết nhà cung ứng",
    });
    expect(within(detail).getByText("Tạm dừng")).toBeInTheDocument();
    expect(
      within(detail).queryByRole("button", {
        name: /Kích hoạt|Ngừng hợp tác|Tạm dừng/,
      }),
    ).not.toBeInTheDocument();
    expect(
      within(detail).queryByLabelText(/mã nhà cung ứng/i),
    ).not.toBeInTheDocument();
  });

  it("protects a dirty draft before job switching and preserves it when cancellation is chosen", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(screen.getByRole("button", { name: "Xem / sửa Bí mật" }));
    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: "Bí đỏ" },
    });
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeDisabled();
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    const dialog = await screen.findByRole("dialog", {
      name: "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(screen.getByLabelText("Tên nguyên liệu")).toHaveValue("Bí đỏ");
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    fireEvent.click(
      within(await screen.findByRole("dialog")).getByRole("button", {
        name: "Bỏ thay đổi",
      }),
    );
    await waitFor(() =>
      expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
        "Nhà cung ứng",
      ),
    );
  });

  it("moves a valid dirty Ingredient into an attached frozen Before/After Review", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(screen.getByRole("button", { name: "Xem / sửa Bí mật" }));
    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: "Bí đỏ" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    const review = screen.getByRole("complementary", {
      name: "Xem thay đổi nguyên liệu",
    });
    expect(review).toHaveFocus();
    expect(review).toHaveTextContent("Bí mật");
    expect(review).toHaveTextContent("Bí đỏ");
    expect(
      within(review).getByRole("button", { name: "Lưu nguyên liệu" }),
    ).toBeEnabled();
  });

  it("renders all 360 fixture Ingredients inside the dense scrolling catalogue", async () => {
    renderWorkbench(
      createIngredientSupplierReviewFixture("INGREDIENTS_DENSE_360"),
    );
    expect(
      await screen.findByText("Nguyên liệu sơ chế 360"),
    ).toBeInTheDocument();
    expect(screen.getAllByRole("row")).toHaveLength(361);
  });

  it("offers only activation and archival for an inactive Ingredient", async () => {
    renderWorkbench();
    await ready();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem / sửa Nguyên liệu ngừng dùng" }),
    );
    expect(screen.getByRole("button", { name: "Kích hoạt" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Lưu trữ" })).toBeEnabled();
    expect(
      screen.queryByRole("button", { name: "Ngừng dùng" }),
    ).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Kích hoạt" }));
    const dialog = await screen.findByRole("dialog", {
      name: "Kích hoạt nguyên liệu?",
    });
    expect(dialog).toHaveTextContent(
      "thiết lập ưu tiên nhà cung ứng mới nếu cần",
    );
    expect(dialog).not.toHaveTextContent("khôi phục các ưu tiên cũ");
  });

  it("shows concise duplicate Supplier and rank validation in the priority editor", async () => {
    const api = createApi();
    const base = readResult();
    if (base.kind !== "success") throw new Error("fixture must be successful");
    api.getIngredientsAndSuppliers.mockResolvedValue({
      kind: "success",
      response: {
        ...base.response,
        suppliers: [
          ...(base.response.suppliers as unknown[]),
          {
            supplier_id: "supplier-active-2",
            supplier_code: "NCC-ACTIVE-2",
            supplier_name: "NCC Hoàng Dung",
            supplier_status: "ACTIVE",
            contact_name: null,
            contact_phone: null,
            contact_email: null,
            version: 1,
          },
        ],
      },
    });
    renderWorkbench(api);
    await ready();
    fireEvent.click(screen.getByRole("button", { name: "Xem / sửa Bí mật" }));
    fireEvent.click(screen.getByRole("button", { name: "Ưu tiên NCC" }));
    const editor = screen.getByRole("complementary", {
      name: "Ưu tiên nhà cung ứng",
    });
    fireEvent.click(
      within(editor).getByRole("button", { name: "+ Thêm nhà cung ứng" }),
    );
    fireEvent.click(
      within(editor).getByRole("button", { name: "+ Thêm nhà cung ứng" }),
    );
    const supplierSelects =
      within(editor).getAllByLabelText(/Nhà cung ứng ưu tiên/);
    fireEvent.change(supplierSelects[2]!, {
      target: { value: "supplier-active" },
    });
    expect(
      within(editor).getByText("Mỗi nhà cung ứng chỉ được chọn một lần."),
    ).toBeInTheDocument();
    const ranks = within(editor).getAllByLabelText(/Mức ưu tiên/);
    fireEvent.change(ranks[2]!, { target: { value: "1" } });
    expect(
      within(editor).getByText("Mỗi mức ưu tiên chỉ được dùng một lần."),
    ).toBeInTheDocument();
    expect(
      within(editor).getByRole("button", { name: "Xem thay đổi" }),
    ).toBeDisabled();
  });
});
