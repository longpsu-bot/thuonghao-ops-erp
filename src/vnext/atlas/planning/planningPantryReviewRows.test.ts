import { describe, expect, it } from "vitest";
import { planningPantryReviewRows } from "./planningPantryReviewRows";
import { pantryPreview, pantrySnapshot } from "./planningReviewFixtures";
describe("Pantry fact comparison", () => {
  it("counts the explicit whole-week confirmation as a meaningful change", () => {
    const rows = planningPantryReviewRows({
      preview: pantryPreview(),
      pantryData: pantrySnapshot(),
    });
    expect(rows).toEqual([
      expect.objectContaining({
        school: "Toàn tuần",
        before: "Chưa xác nhận",
        after: "Không có bổ sung",
      }),
    ]);
  });
  it("shows a School/date composition-mode change even without changed ingredient lines", () => {
    const preview = {
      ...pantryPreview(),
      no_additions_confirmed: false,
      school_date_modes: [
        {
          school_id: "school-0",
          service_date: "2026-09-07",
          direct_need_mode: "COMPLETE" as const,
        },
      ],
    };
    const rows = planningPantryReviewRows({
      preview,
      pantryData: pantrySnapshot(),
    });
    expect(rows).toEqual([
      expect.objectContaining({
        school: "Trường Nguyễn Du",
        before: "Cộng với thực đơn",
        after: "Danh sách đầy đủ",
      }),
    ]);
  });
});
