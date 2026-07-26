import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../atlas/connection/authSession";
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

const data = {
  ingredients: [
    {
      ingredient_id: "ingredient-1",
      ingredient_code: "rice",
      ingredient_name: "Gạo Jasmine",
      ingredient_status: "ACTIVE",
      ingredient_type: "Lương thực",
      shopping_type: "Mua theo kế hoạch",
      purchase_unit_id: "unit-kg",
      purchase_unit_code: "kg",
      purchase_unit_name: "Kilôgam",
      order_step: 5,
      version: 1,
      supplier_priorities: [
        {
          supplier_eligibility_id: "eligibility-1",
          supplier_id: "supplier-1",
          supplier_name: "NCC Minh Tâm",
          priority: 1,
        },
      ],
    },
  ],
  suppliers: [
    {
      supplier_id: "supplier-1",
      supplier_code: "minh-tam",
      supplier_name: "NCC Minh Tâm",
      supplier_status: "ACTIVE",
      contact_name: "Nguyễn Minh",
      contact_phone: "0900000001",
      contact_email: "minh@example.invalid",
      version: 1,
    },
    {
      supplier_id: "supplier-2",
      supplier_code: "an-phu",
      supplier_name: "NCC An Phú",
      supplier_status: "ACTIVE",
      contact_name: null,
      contact_phone: null,
      contact_email: null,
      version: 1,
    },
  ],
  units: [
    {
      unit_id: "unit-kg",
      unit_code: "kg",
      unit_name: "Kilôgam",
      unit_status: "ACTIVE",
    },
  ],
};

function success(extra: Record<string, unknown>) {
  return {
    kind: "success",
    response: { success: true, ...extra },
  } as const;
}

function api() {
  return {
    getIngredientsAndSuppliers: vi.fn().mockResolvedValue(success(data)),
    createIngredient: vi
      .fn()
      .mockResolvedValue(
        success({ safe_operator_message: "Ingredient created." }),
      ),
    updateIngredient: vi
      .fn()
      .mockResolvedValue(
        success({ safe_operator_message: "Ingredient saved." }),
      ),
    setIngredientLifecycle: vi
      .fn()
      .mockResolvedValue(
        success({ safe_operator_message: "Lifecycle saved." }),
      ),
    createSupplier: vi
      .fn()
      .mockResolvedValue(
        success({ safe_operator_message: "Supplier created." }),
      ),
    updateSupplier: vi
      .fn()
      .mockResolvedValue(success({ safe_operator_message: "Supplier saved." })),
    replacePriorities: vi.fn().mockResolvedValue(
      success({
        safe_operator_message: "Ingredient supplier priorities replaced.",
      }),
    ),
  } as unknown as MasterDataApi;
}

describe("connected Ingredients & Suppliers master data", () => {
  it("loads searchable authoritative rows and submits a complete ingredient create", async () => {
    const connectedApi = api();
    render(
      <IngredientSupplierAdminWorkbench
        authState={authState}
        api={connectedApi}
      />,
    );
    expect(await screen.findByText("Gạo Jasmine")).toBeInTheDocument();
    expect(screen.getByText("NCC Minh Tâm")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng 2" }));
    expect(screen.getByText("Nguyễn Minh")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Nguyên liệu 1" }));

    fireEvent.change(screen.getByLabelText("Trạng thái"), {
      target: { value: "INACTIVE" },
    });
    expect(
      screen.getByText("Không có nguyên liệu phù hợp bộ lọc."),
    ).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Trạng thái"), {
      target: { value: "ALL" },
    });

    fireEvent.click(screen.getByRole("button", { name: "Tạo nguyên liệu" }));
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));
    expect(screen.getByText(/Điền đủ mã, tên/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Mã nguyên liệu"), {
      target: { value: "pumpkin" },
    });
    fireEvent.change(screen.getByLabelText("Tên nguyên liệu"), {
      target: { value: "Bí đỏ" },
    });
    fireEvent.change(screen.getByLabelText("Đơn vị mua"), {
      target: { value: "unit-kg" },
    });
    fireEvent.change(screen.getByLabelText("Loại nguyên liệu"), {
      target: { value: "Rau củ" },
    });
    fireEvent.change(screen.getByLabelText("Cách mua"), {
      target: { value: "Mua theo kế hoạch" },
    });
    fireEvent.change(screen.getByLabelText("Bước đặt hàng"), {
      target: { value: "2" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));

    await waitFor(() =>
      expect(connectedApi.createIngredient).toHaveBeenCalledOnce(),
    );
    expect(connectedApi.createIngredient).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 1,
        requested_by_auth_subject: authSubject,
        payload: {
          ingredient_code: "pumpkin",
          ingredient_name: "Bí đỏ",
          purchase_unit_id: "unit-kg",
          ingredient_type: "Rau củ",
          shopping_type: "Mua theo kế hoạch",
          order_step: 2,
        },
      }),
    );
    await waitFor(() =>
      expect(connectedApi.getIngredientsAndSuppliers).toHaveBeenCalledTimes(2),
    );
  });

  it("replaces the full priority list with unique supplier/rank entries", async () => {
    const connectedApi = api();
    render(
      <IngredientSupplierAdminWorkbench
        authState={authState}
        api={connectedApi}
      />,
    );
    expect(await screen.findByText("Gạo Jasmine")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Ưu tiên" }));
    fireEvent.click(screen.getByRole("button", { name: "Thêm nhà cung ứng" }));
    fireEvent.click(
      screen.getByRole("button", {
        name: "Lưu thứ tự ưu tiên",
      }),
    );
    await waitFor(() =>
      expect(connectedApi.replacePriorities).toHaveBeenCalledOnce(),
    );
    expect(connectedApi.replacePriorities).toHaveBeenCalledWith(
      expect.objectContaining({
        expected_version: 1,
        payload: {
          ingredient_id: "ingredient-1",
          priorities: [
            { supplier_id: "supplier-1", priority: 1 },
            { supplier_id: "supplier-2", priority: 2 },
          ],
        },
      }),
    );
  });

  it("shows permission-safe backend errors without stale local success", async () => {
    const connectedApi = api();
    connectedApi.updateSupplier = vi.fn().mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "CAPABILITY_DENIED",
        safe_message: "Denied safely.",
      },
    });
    render(
      <IngredientSupplierAdminWorkbench
        authState={authState}
        api={connectedApi}
      />,
    );
    expect(await screen.findByText("NCC Minh Tâm")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng 2" }));
    fireEvent.click(
      screen.getAllByRole("button", { name: "Xem và sửa" }).at(-1)!,
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));
    expect(
      await screen.findByText("Bạn không có quyền thực hiện thao tác này."),
    ).toBeInTheDocument();
    expect(connectedApi.getIngredientsAndSuppliers).toHaveBeenCalledOnce();
  });
});
