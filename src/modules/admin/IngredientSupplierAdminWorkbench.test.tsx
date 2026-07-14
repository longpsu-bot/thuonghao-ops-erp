import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { IngredientSupplierAdminWorkbench } from "./IngredientSupplierAdminWorkbench";

afterEach(cleanup);

describe("Ingredients & Suppliers Admin workbench", () => {
  it("is decision-first and keeps master-data changes behind explicit commands", () => {
    render(<IngredientSupplierAdminWorkbench />);
    expect(
      screen.getByLabelText("Ingredients and suppliers administration summary"),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("columnheader", { name: "Ingredient" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Review master-data details" }),
    );
    expect(
      screen.getByRole("columnheader", { name: "Ingredient" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("columnheader", { name: "Supplier" }),
    ).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", {
        name: "Set ingredient-supplier eligibility",
      }),
    );
    expect(
      screen.getByText(/eligibility recorded with audit evidence/),
    ).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Set preferred supplier reference" }),
    );
    expect(
      screen.getByText(/no PO or supplier commitment was created/),
    ).toBeInTheDocument();
  });

  it("states the downstream-safe Admin boundary", () => {
    render(<IngredientSupplierAdminWorkbench />);
    expect(
      screen.getByText(
        /does not create supplier commitments or rewrite Planning/,
      ),
    ).toBeInTheDocument();
  });
});
