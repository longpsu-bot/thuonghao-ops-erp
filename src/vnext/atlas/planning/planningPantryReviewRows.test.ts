import { describe, expect, it } from "vitest";
import { planningPantryReviewRows } from "./planningPantryReviewRows";
import { pantryPreview, pantrySnapshot } from "./planningReviewFixtures";
describe("Pantry fact comparison", () => {
  it.each([
    ["planning_identified_supplement", "Nguồn bổ sung đã chụp", "Bổ sung"],
    [
      "school_requested_supplement",
      "Đặt theo yêu cầu nhà trường",
      "Hàng đặt riêng",
    ],
    ["direct_entry_unspecified", "Trực tiếp lịch sử", "Trực tiếp lịch sử"],
  ])(
    "labels %s by stable source code without rewriting comparison facts",
    (code, savedName, label) => {
      const pantryData = pantrySnapshot();
      const before = {
        school_id: pantryData.schools[0]!.school_id,
        service_date: "2026-09-07",
        ingredient_id: pantryData.ingredients[0]!.ingredient_id,
        pantry_need_purpose_id: "captured-purpose",
        purpose_code: code,
        purpose_name_vi: savedName,
        requested_quantity: "3",
      };
      const after = { ...before, requested_quantity: "4" };
      const preview = {
        ...pantryPreview(),
        no_additions_confirmed: false,
        comparison: {
          ...pantryPreview().comparison,
          new_lines: [],
          changed_lines: [{ before, after }],
          omitted_lines: [],
        },
      };
      const original = structuredClone(preview);
      const rows = planningPantryReviewRows({ preview, pantryData });
      expect(rows).toEqual([
        expect.objectContaining({
          before: `3 kg · ${label}`,
          after: `4 kg · ${label}`,
        }),
      ]);
      expect(preview).toEqual(original);
    },
  );
  it("counts the explicit whole-week confirmation as a meaningful change", () => {
    const rows = planningPantryReviewRows({
      preview: pantryPreview(),
      pantryData: pantrySnapshot(),
    });
    expect(rows).toEqual([
      expect.objectContaining({
        school: "Toàn tuần",
        before: "Chưa xác nhận",
        after: "Không có hàng đặt riêng",
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
