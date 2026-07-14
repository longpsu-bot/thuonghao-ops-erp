import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { SchoolAdminWorkbench } from "./SchoolAdminWorkbench";

afterEach(cleanup);
describe("School Admin workbench", () => {
  it("keeps master-data changes behind explicit commands", () => {
    render(<SchoolAdminWorkbench />);
    expect(
      screen.getByLabelText("School administration summary"),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("columnheader", { name: "School" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Review school details" }),
    );
    expect(screen.getAllByRole("row")).toHaveLength(3);
    fireEvent.click(
      screen.getByRole("button", { name: "Set school display order" }),
    );
    expect(
      screen.getByText(/Display-order change recorded/),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Set school status" }));
    expect(
      screen.getByText(/reactivated with explicit status evidence/),
    ).toBeInTheDocument();
  });
  it("states that Admin does not rewrite Planning facts", () => {
    render(<SchoolAdminWorkbench />);
    expect(
      screen.getByText(/does not rewrite Planning facts/),
    ).toBeInTheDocument();
  });
});
