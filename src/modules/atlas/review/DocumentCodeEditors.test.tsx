import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../../../vnext/atlas/AtlasVNextProvider";
import { IngredientSupplierWorkbench } from "../../../vnext/atlas/master-data/IngredientSupplierWorkbench";
import { createReviewMasterDataApi } from "./reviewMasterDataApi";
import {
  responseArray,
  type IngredientMasterData,
  type SupplierMasterData,
  type AtlasRpcResult,
} from "../../../vnext/atlas/bridges/ingredientSupplierMasterData";

afterEach(cleanup);
async function setup() {
  const api = createReviewMasterDataApi();
  const read = api.getIngredientsAndSuppliers.bind(api);
  api.getIngredientsAndSuppliers = async (subject, correlation) => {
    const result = await read(subject, correlation);
    if (result.kind !== "success") return result;
    return {
      ...result,
      response: {
        ...result.response,
        ingredients: responseArray<IngredientMasterData>(
          result,
          "ingredients",
        )!.slice(0, 1),
        suppliers: responseArray<SupplierMasterData>(
          result,
          "suppliers",
        )!.slice(0, 1),
      },
    };
  };
  const catalog = await api.getIngredientsAndSuppliers("operator", "review");
  const ingredient = responseArray<IngredientMasterData>(
    catalog,
    "ingredients",
  )![0]!;
  const supplier = responseArray<SupplierMasterData>(catalog, "suppliers")![0]!;
  const report = vi.fn();
  render(
    <AtlasVNextProvider>
      <IngredientSupplierWorkbench
        authSubject="operator"
        api={api}
        onWorkspaceStatus={report}
      />
    </AtlasVNextProvider>,
  );
  await screen.findByRole("button", {
    name: `Xem / sửa ${ingredient.ingredient_name}`,
  });
  return { api, ingredient, supplier, report };
}
it("authors an explicit Ingredient document code separately from its technical identity and reviews it before save", async () => {
  const { api, ingredient, report } = await setup();
  fireEvent.click(
    screen.getByRole("button", {
      name: `Xem / sửa ${ingredient.ingredient_name}`,
    }),
  );
  const field = screen.getByLabelText("Mã hàng trên chứng từ");
  expect(field).toHaveValue("");
  fireEvent.change(field, { target: { value: " 1082 " } });
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true }),
  );
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  const review = screen.getByRole("complementary", {
    name: "Xem thay đổi nguyên liệu",
  });
  expect(within(review).getByText("Mã hàng trên chứng từ")).toBeInTheDocument();
  expect(within(review).getByText("1082")).toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Lưu nguyên liệu" }));
  await waitFor(() =>
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    ),
  );
  const rows = responseArray<IngredientMasterData>(
    await api.getIngredientsAndSuppliers("operator", "review"),
    "ingredients",
  )!;
  expect(
    rows.find((item) => item.ingredient_id === ingredient.ingredient_id),
  ).toMatchObject({
    document_code: "1082",
    ingredient_code: ingredient.ingredient_code,
    version: ingredient.version + 1,
  });
});
it("authors and explicitly clears a Supplier document code without changing its technical code", async () => {
  const { api, supplier } = await setup();
  const update = vi.spyOn(api, "updateSupplier");
  fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
  fireEvent.click(
    await screen.findByRole("button", {
      name: `Xem / sửa ${supplier.supplier_name}`,
    }),
  );
  fireEvent.change(screen.getByLabelText("Mã NCC trên chứng từ"), {
    target: { value: "53" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  fireEvent.click(screen.getByRole("button", { name: "Lưu nhà cung ứng" }));
  await waitFor(() => expect(update).toHaveBeenCalledOnce());
  await screen.findByText("Đã lưu và tải lại dữ liệu chính thức.");
  fireEvent.click(
    screen.getByRole("button", { name: `Xem / sửa ${supplier.supplier_name}` }),
  );
  expect(screen.getByLabelText("Mã NCC trên chứng từ")).toHaveValue("53");
  fireEvent.change(screen.getByLabelText("Mã NCC trên chứng từ"), {
    target: { value: " " },
  });
  fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
  fireEvent.click(screen.getByRole("button", { name: "Lưu nhà cung ứng" }));
  await waitFor(() => expect(update).toHaveBeenCalledTimes(2));
  expect(update.mock.calls[1]![0]).toMatchObject({
    expected_version: supplier.version + 1,
    payload: { document_code: null },
  });
  const rows = responseArray<SupplierMasterData>(
    await api.getIngredientsAndSuppliers("operator", "review"),
    "suppliers",
  )!;
  expect(
    rows.find((item) => item.supplier_id === supplier.supplier_id),
  ).toMatchObject({
    document_code: null,
    supplier_code: supplier.supplier_code,
  });
});
it.each(["ingredient", "supplier"] as const)(
  "disables the %s document code throughout a pending command and readback",
  async (kind) => {
    const { api, ingredient, supplier } = await setup();
    const catalog = await api.getIngredientsAndSuppliers("operator", "review");
    let resolveCommand!: (value: AtlasRpcResult) => void;
    let resolveReadback!: (value: AtlasRpcResult) => void;
    const command = new Promise<AtlasRpcResult>((resolve) => {
      resolveCommand = resolve;
    });
    const readback = new Promise<AtlasRpcResult>((resolve) => {
      resolveReadback = resolve;
    });
    const write = vi
      .spyOn(api, kind === "ingredient" ? "updateIngredient" : "updateSupplier")
      .mockReturnValueOnce(command);
    const read = vi
      .spyOn(api, "getIngredientsAndSuppliers")
      .mockReturnValueOnce(readback);
    if (kind === "supplier")
      fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    fireEvent.click(
      await screen.findByRole("button", {
        name: `Xem / sửa ${kind === "ingredient" ? ingredient.ingredient_name : supplier.supplier_name}`,
      }),
    );
    const label =
      kind === "ingredient" ? "Mã hàng trên chứng từ" : "Mã NCC trên chứng từ";
    const field = screen.getByLabelText(label);
    fireEvent.change(field, { target: { value: "1082" } });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(
      screen.getByRole("button", {
        name: kind === "ingredient" ? "Lưu nguyên liệu" : "Lưu nhà cung ứng",
      }),
    );
    await waitFor(() => expect(write).toHaveBeenCalledOnce());
    expect(screen.queryByLabelText(label)).not.toBeInTheDocument();
    resolveCommand({ kind: "success", response: { success: true } });
    await waitFor(() => expect(read).toHaveBeenCalledOnce());
    expect(await screen.findByLabelText(label)).toBeDisabled();
    expect(screen.getByLabelText(label)).toHaveValue("1082");
    resolveReadback(catalog);
    await screen.findByText("Đã lưu và tải lại dữ liệu chính thức.");
  },
);
it.each(["ingredient", "supplier"] as const)(
  "retains the %s document code behind the existing uncertain-save lock",
  async (kind) => {
    const { api, ingredient, supplier } = await setup();
    vi.spyOn(
      api,
      kind === "ingredient" ? "updateIngredient" : "updateSupplier",
    ).mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
    });
    if (kind === "supplier")
      fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    fireEvent.click(
      await screen.findByRole("button", {
        name: `Xem / sửa ${kind === "ingredient" ? ingredient.ingredient_name : supplier.supplier_name}`,
      }),
    );
    const label =
      kind === "ingredient" ? "Mã hàng trên chứng từ" : "Mã NCC trên chứng từ";
    fireEvent.change(screen.getByLabelText(label), {
      target: { value: "1082" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(
      screen.getByRole("button", {
        name: kind === "ingredient" ? "Lưu nguyên liệu" : "Lưu nhà cung ứng",
      }),
    );
    await screen.findByText(
      "Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.",
    );
    expect(screen.getByLabelText(label)).toHaveValue("1082");
    expect(screen.getByLabelText(label)).toBeDisabled();
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
  },
);
