import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { PlanningCorrectionImpactPanel } from "./PlanningCorrectionImpactPanel";
import type {
  PlanningCorrectionChain,
  PlanningCorrectionImpact,
} from "./planningCorrectionApi";

afterEach(cleanup);

function chain(
  id: string,
  start: string,
  end: string,
  status = "DRAFT_REVIEW",
): PlanningCorrectionChain {
  return {
    need_generation_run_id: id,
    need_generation_run_version: 1,
    run_status: "RELEASED_FOR_CONFIRMATION",
    period_start: start,
    period_end: end,
    is_legacy_range: start !== end,
    confirmed_need_batch_id: `batch-${id}`,
    confirmed_need_batch_version: 1,
    confirmed_need_status: status,
    planning_release_occurred: status === "RELEASED_FOR_PURCHASE_HANDOFF",
    active_purchase_handoff_exists: false,
    later_downstream_commitment_exists: false,
  };
}

function impact(
  overrides: Partial<PlanningCorrectionImpact> = {},
): PlanningCorrectionImpact {
  const released = chain(
    "released",
    "2026-08-17",
    "2026-08-17",
    "RELEASED_FOR_PURCHASE_HANDOFF",
  );
  return {
    source_kind: "PANTRY",
    material_change: true,
    affected_service_dates: ["2026-08-17"],
    save_allowed: false,
    save_blocker_code: "PLANNING_RELEASE_CORRECTION_REQUIRED",
    date_impacts: [
      {
        service_date: "2026-08-17",
        need_state: "GENERATED",
        confirmed_need_state: "RELEASED_FOR_PURCHASE_HANDOFF",
        planning_release_occurred: true,
        purchase_handoff_exists: false,
        later_downstream_commitment_exists: false,
        legacy_overlap_exists: false,
        correction_policy: "PLANNING_RELEASE_CORRECTION_REQUIRED",
        safe_to_save: false,
        next_required_action: "PREPARE_PLANNING_CORRECTION",
        operator_message:
          "Nhu cầu đã được Kế hoạch cam kết; hãy mở lại cam kết trước khi lưu.",
        chains: [released],
      },
    ],
    ...overrides,
  };
}

describe("Planning correction impact operator panel", () => {
  it("shows the exact affected date and explicit released/no-Handoff action", () => {
    const onPrepare = vi.fn();
    render(
      <PlanningCorrectionImpactPanel
        impact={impact()}
        busy={false}
        onPrepare={onPrepare}
      />,
    );

    expect(screen.getByText("17/08/2026")).toBeVisible();
    expect(screen.queryByText("18/08/2026")).not.toBeInTheDocument();
    expect(screen.getByText(/hãy mở lại cam kết trước khi lưu/i)).toBeVisible();
    const action = screen.getByRole("button", {
      name: "Mở lại cam kết Kế hoạch",
    });
    expect(action).toBeEnabled();
    fireEvent.click(action);
    expect(onPrepare).toHaveBeenCalledTimes(1);
    expect(onPrepare).toHaveBeenCalledWith(
      expect.objectContaining({ need_generation_run_id: "released" }),
    );
    expect(
      screen.getByText("PLANNING_RELEASE_CORRECTION_REQUIRED"),
    ).not.toBeVisible();
  });

  it("shows both complete legacy commitments and never triggers generation", () => {
    const onPrepare = vi.fn();
    const first = chain("legacy-a", "2026-08-17", "2026-08-21");
    const second = chain("legacy-b", "2026-08-17", "2026-08-23");
    const legacy = impact({
      save_blocker_code: "LEGACY_RANGE_CORRECTION_REQUIRED",
      date_impacts: [
        {
          ...impact().date_impacts[0]!,
          confirmed_need_state: "MULTIPLE_CHAINS",
          legacy_overlap_exists: true,
          correction_policy: "LEGACY_RANGE_CORRECTION_REQUIRED",
          next_required_action: "RETIRE_LEGACY_RANGE",
          operator_message:
            "Ngày này thuộc Nhu cầu nhiều ngày cũ; cần xử lý toàn bộ khoảng trước khi lưu.",
          chains: [first, second],
        },
      ],
    });

    render(
      <PlanningCorrectionImpactPanel
        impact={legacy}
        busy={false}
        onPrepare={onPrepare}
      />,
    );

    expect(screen.getByText(/17\/08\/2026–21\/08\/2026/)).toBeVisible();
    expect(screen.getByText(/17\/08\/2026–23\/08\/2026/)).toBeVisible();
    expect(
      screen.getAllByRole("button", { name: "Đưa Nhu cầu cũ về lịch sử" }),
    ).toHaveLength(2);
    expect(onPrepare).not.toHaveBeenCalled();
    expect(
      screen.queryByRole("button", { name: /tạo nhu cầu/i }),
    ).not.toBeInTheDocument();
  });

  it("renders Handoff and later commitments as consequence-first blockers", () => {
    const blocked = impact({
      save_blocker_code: "BLOCKED_BY_DOWNSTREAM_COMMITMENT",
      date_impacts: [
        {
          ...impact().date_impacts[0]!,
          purchase_handoff_exists: true,
          later_downstream_commitment_exists: true,
          correction_policy: "BLOCKED_BY_DOWNSTREAM_COMMITMENT",
          next_required_action: "START_DOWNSTREAM_CORRECTION",
          operator_message:
            "Nhu cầu ngày này đã có cam kết vận hành phía sau; cần quy trình hiệu chỉnh riêng.",
          chains: [],
        },
      ],
    });

    render(
      <PlanningCorrectionImpactPanel
        impact={blocked}
        busy={false}
        onPrepare={vi.fn()}
      />,
    );

    expect(screen.getByText(/đã có cam kết vận hành phía sau/i)).toBeVisible();
    expect(screen.getByText(/Chưa thể lưu nguồn/)).toBeVisible();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(
      screen.getByText("BLOCKED_BY_DOWNSTREAM_COMMITMENT"),
    ).not.toBeVisible();
  });
});
