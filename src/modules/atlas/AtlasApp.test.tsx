import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";
import { atlasPages, journeys } from "./atlasConfig";

afterEach(cleanup);

const workflowGroups = new Set(["Lập kế hoạch", "Mua hàng", "Thực hiện"]);
const operationalWorkflowPages = atlasPages.filter((page) =>
  workflowGroups.has(page.group),
);
const nonOperationalPages = atlasPages.filter(
  (page) => page.group === "Dữ liệu danh mục" || page.group === "Quản trị",
);

describe("AtlasApp", () => {
  it.each(atlasPages)(
    "shows and activates the configured destination: $id",
    (page) => {
      render(<AtlasApp />);

      const navigationControl = screen.getByRole("button", {
        name: page.label,
      });
      expect(navigationControl).toBeVisible();

      fireEvent.click(navigationControl);
      expect(navigationControl).toHaveClass("active");

      if (page.id === "requirement-review") {
        expect(
          screen.getByText("Lập kế hoạch · Rà soát nhu cầu nguyên liệu"),
        ).toBeInTheDocument();
      } else {
        expect(
          screen.getByRole("heading", { name: page.label }),
        ).toBeInTheDocument();
      }
    },
  );

  it("keeps requirement review separate from supplier allocation", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Rà soát nhu cầu nguyên liệu" }),
    );
    expect(
      screen.getByText("Lập kế hoạch · Rà soát nhu cầu nguyên liệu"),
    ).toBeInTheDocument();
    expect(screen.queryByText("Theo nhà cung cấp")).not.toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: "Phân bổ nhà cung cấp" }),
    );
    expect(
      screen.getByRole("heading", { name: "Phân bổ nhà cung cấp" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Nhân viên mua hàng")).toBeInTheDocument();
  });

  it("shows stable catering and wholesale journey identities on operations home", () => {
    render(<AtlasApp />);
    journeys.forEach((journey) => {
      expect(screen.getByText(journey.id)).toBeInTheDocument();
    });
  });

  it.each(operationalWorkflowPages)(
    "shows journey context on the $id operational placeholder",
    (page) => {
      render(<AtlasApp />);
      fireEvent.click(screen.getByRole("button", { name: page.label }));

      journeys.forEach((journey) => {
        expect(
          screen.getAllByText(new RegExp(journey.id)).length,
        ).toBeGreaterThan(0);
      });
    },
  );

  it.each(nonOperationalPages)(
    "does not show journey context on the $id non-operational page",
    (page) => {
      render(<AtlasApp />);
      fireEvent.click(screen.getByRole("button", { name: page.label }));

      expect(
        screen.queryByLabelText("Ngữ cảnh hành trình mẫu"),
      ).not.toBeInTheDocument();
      journeys.forEach((journey) => {
        expect(
          screen.queryByText(new RegExp(journey.id)),
        ).not.toBeInTheDocument();
      });
    },
  );

  it("renders placeholder primary actions as disabled prototype controls", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Tổng quan nhu cầu" }));

    expect(
      screen.getByRole("button", {
        name: "Rà soát nguồn thiếu · thao tác dự kiến (prototype)",
      }),
    ).toBeDisabled();
  });
});
