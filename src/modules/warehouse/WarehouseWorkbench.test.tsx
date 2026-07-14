import "@testing-library/jest-dom/vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { WarehouseWorkbench } from "./WarehouseWorkbench";

describe("WarehouseWorkbench", () => {
  it("demonstrates the bounded command path from session start to stock creation", () => {
    render(<WarehouseWorkbench />);
    for (const action of [
      "Start receiving session",
      "Record sample receiving evidence",
      "Record shortage discrepancy",
      "Validate receiving session",
      "Release goods receipt",
      "Create controlled stock",
    ]) {
      fireEvent.click(screen.getByRole("button", { name: action }));
    }
    expect(
      screen.getByText(/Controlled stock created · 2 lots/),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/no supplier message, QA approval/),
    ).toBeInTheDocument();
  });
});
