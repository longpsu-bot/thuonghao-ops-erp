import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { WarehouseStockReleaseWorkbench } from "./WarehouseStockReleaseWorkbench";

const commandPath = [
  "Create stock reservation",
  "Validate stock reservation",
  "Release reservation to pick",
  "Create pick list",
  "Validate pick list",
  "Start picking",
  "Record pick line",
  "Mark pick list ready for release",
  "Create Warehouse release",
  "Validate Warehouse release",
  "Record Warehouse handoff evidence",
  "Release goods from Warehouse custody",
  "Post release stock movement",
];

afterEach(cleanup);

describe("WarehouseStockReleaseWorkbench", () => {
  it("keeps each transition gated behind its Warehouse command", () => {
    render(<WarehouseStockReleaseWorkbench />);
    expect(screen.getAllByRole("button")).toHaveLength(1);
    for (const command of commandPath) {
      const button = screen.getByRole("button", { name: command });
      expect(button).toBeInTheDocument();
      fireEvent.click(button);
    }
    expect(screen.queryAllByRole("button")).toHaveLength(0);
    expect(screen.getByText("Stock reduction posted")).toBeInTheDocument();
    expect(screen.getByText("-10")).toBeInTheDocument();
  });

  it("states that Warehouse release is not destination delivery", () => {
    render(<WarehouseStockReleaseWorkbench />);
    expect(
      screen.getByText(/does not confirm destination delivery/),
    ).toBeInTheDocument();
    expect(screen.getByText(/no Dispatch operation/)).toBeInTheDocument();
  });
});
