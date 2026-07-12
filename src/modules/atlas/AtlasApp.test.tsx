import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";
import { atlasPages, journeys } from "./atlasConfig";
import { workflowJourneys } from "./workflowFixtures";

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

  it.each(workflowJourneys)(
    "moves the $id fixture through its predefined local workflow stages",
    (journey) => {
      render(<AtlasApp />);
      const journeyCard = screen.getByText(journey.id).closest("article")!;
      fireEvent.click(
        within(journeyCard).getByRole("button", {
          name: "Mở hành trình mẫu",
        }),
      );

      expect(
        screen.getByText(`Hành trình đang chọn: ${journey.id}`),
      ).toBeInTheDocument();

      journey.stages.slice(1).forEach((stage) => {
        fireEvent.click(
          screen.getByRole("button", {
            name: "Mô phỏng hoàn tất và chuyển bàn giao",
          }),
        );
        expect(screen.getByText(`Giai đoạn hiện tại`)).toBeInTheDocument();
        expect(screen.getByRole("button", { name: stage.label })).toHaveClass(
          "active",
        );
      });

      expect(
        screen.getByRole("button", { name: "Đã đến QA mẫu" }),
      ).toBeDisabled();
    },
  );

  it("shows the wholesale mock blocker without preventing local prototype progress", () => {
    render(<AtlasApp />);
    const wholesaleCard = screen.getByText("WS-2026-0714").closest("article")!;
    fireEvent.click(
      within(wholesaleCard).getByRole("button", { name: "Mở hành trình mẫu" }),
    );
    fireEvent.click(
      screen.getByRole("button", {
        name: "Mô phỏng hoàn tất và chuyển bàn giao",
      }),
    );
    fireEvent.click(
      screen.getByRole("button", {
        name: "Mô phỏng hoàn tất và chuyển bàn giao",
      }),
    );
    expect(screen.getByText(/cần rà soát nhà cung cấp/i)).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", {
        name: "Mô phỏng hoàn tất và chuyển bàn giao",
      }),
    );
    expect(
      screen.getByRole("heading", { name: "Đơn mua hàng" }),
    ).toBeInTheDocument();
  });

  it("keeps warehouse receiving and preparation separate from outbound dispatch", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Đơn mua hàng" }));
    expect(
      screen.getByRole("heading", { name: "Đơn mua hàng" }),
    ).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Tiếp nhận và chuẩn bị kho" }),
    );
    expect(
      screen.getByRole("heading", { name: "Tiếp nhận và chuẩn bị kho" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Nhân viên kho")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Lập kế hoạch giao nhận" }),
    );
    expect(
      screen.getByRole("heading", { name: "Lập kế hoạch giao nhận" }),
    ).toBeInTheDocument();
  });

  it("resets local workflow progress when the prototype remounts", () => {
    const { unmount } = render(<AtlasApp />);
    const cateringCard = screen.getByText("CAT-0713-ND").closest("article")!;
    fireEvent.click(
      within(cateringCard).getByRole("button", { name: "Mở hành trình mẫu" }),
    );
    fireEvent.click(
      screen.getByRole("button", {
        name: "Mô phỏng hoàn tất và chuyển bàn giao",
      }),
    );
    expect(
      screen.getByRole("heading", { name: "Điểm danh và suất ăn" }),
    ).toBeInTheDocument();
    unmount();

    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Lập thực đơn" }));
    expect(
      screen.getByText("Nhu cầu catering mẫu: 620 suất"),
    ).toBeInTheDocument();
  });
});
