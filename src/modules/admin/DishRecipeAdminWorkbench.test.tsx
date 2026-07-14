import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { DishRecipeAdminWorkbench } from "./DishRecipeAdminWorkbench";

afterEach(cleanup);

describe("Dishes & Recipes Admin workbench", () => {
  it("shows every recipe decision in one consolidated operator surface", () => {
    render(<DishRecipeAdminWorkbench />);
    expect(
      screen.getByLabelText("Dishes and recipes administration summary"),
    ).toBeInTheDocument();
    expect(screen.getByText("Dish identity")).toBeInTheDocument();
    expect(screen.getByText("Versions & lock state")).toBeInTheDocument();
    expect(screen.getByText("BOM lines")).toBeInTheDocument();
    expect(screen.getByText("School-type variants")).toBeInTheDocument();
    expect(screen.getByText("Change & review evidence")).toBeInTheDocument();
    expect(screen.getByText("Blockers & warnings")).toBeInTheDocument();
    expect(
      screen.getByText("Downstream references & boundary"),
    ).toBeInTheDocument();
    expect(screen.getAllByText("LOCKED").length).toBeGreaterThan(0);
    expect(screen.getByText(/QA approval: no/)).toBeInTheDocument();
    expect(screen.queryByText(/Retool layer/i)).not.toBeInTheDocument();
  });

  it("gates validation, release, and correction through explicit commands", () => {
    render(<DishRecipeAdminWorkbench />);
    const validate = screen.getByRole("button", {
      name: "Validate recipe version",
    });
    const release = screen.getByRole("button", {
      name: "Release for Planning",
    });
    expect(validate).toBeEnabled();
    expect(release).toBeDisabled();
    fireEvent.click(validate);
    expect(
      screen.getByText(/validated with Admin review evidence/),
    ).toBeInTheDocument();
    expect(release).toBeEnabled();
    fireEvent.click(release);
    expect(
      screen.getByText(/prior operational facts were preserved/),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Recipe version"), {
      target: { value: "recipe-pumpkin-v1" },
    });
    const correction = screen.getByRole("button", {
      name: "Create correction version",
    });
    expect(correction).toBeEnabled();
    fireEvent.click(correction);
    expect(
      screen.getByText(/released or locked source remains unchanged/),
    ).toBeInTheDocument();
  });

  it("states the Admin and downstream immutability boundaries", () => {
    render(<DishRecipeAdminWorkbench />);
    expect(
      screen.getByText(/never rewrites prior Planning, Need Generation/),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/recipe approval is not QA or Production approval/),
    ).toBeInTheDocument();
  });
});
