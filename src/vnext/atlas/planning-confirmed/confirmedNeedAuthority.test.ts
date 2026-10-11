import { expect, it } from "vitest";
import { preflightMessage } from "./confirmedNeedAuthority";
import { reviewPreflight } from "./confirmedNeedReviewFixtures";

it("translates the known missing Pantry approval code without changing its evidence", () => {
  const preflight = reviewPreflight();
  preflight.readiness_state = "BLOCKED";
  preflight.issues = [
    {
      issue_code: "MISSING_PANTRY_APPROVAL_SNAPSHOT",
      severity: "BLOCKING",
      input_type: "PANTRY",
      school_id: null,
      service_date: null,
      message:
        "No current approved Pantry batch overlaps the evaluated period.",
    },
  ];
  expect(preflightMessage(preflight)).toBe(
    "Chưa có dữ liệu Hàng đặt riêng đã xác nhận cho ngày này.",
  );
  expect(preflight.issues[0].message).toBe(
    "No current approved Pantry batch overlaps the evaluated period.",
  );
});

it("uses a concise operator fallback for an unfamiliar English preflight issue", () => {
  const preflight = reviewPreflight();
  preflight.readiness_state = "BLOCKED";
  preflight.issues = [
    {
      issue_code: "FUTURE_SOURCE_ISSUE",
      severity: "BLOCKING",
      input_type: "PANTRY",
      school_id: null,
      service_date: null,
      message: "Unexpected source state.",
    },
  ];
  expect(preflightMessage(preflight)).toBe(
    "Cần kiểm tra dữ liệu nguồn trước khi tạo nhu cầu.",
  );
});
