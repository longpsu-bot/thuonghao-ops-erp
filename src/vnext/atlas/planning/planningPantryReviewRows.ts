import { viDate, type JsonValue } from "../bridges/planning";
import type { PlanningSourcesController } from "./usePlanningSources";
const record = (v: JsonValue | undefined) =>
  v && typeof v === "object" && !Array.isArray(v) ? v : null;
export function planningPantryReviewRows(
  c: Pick<PlanningSourcesController, "preview" | "pantryData">,
) {
  const preview = c.preview;
  if (!preview || !("new_lines" in preview.comparison)) return [];
  const school = (id: JsonValue | undefined) =>
    c.pantryData?.schools.find((s) => s.school_id === id)?.school_name ??
    "Trường chưa nhận diện";
  const value = (r: Record<string, JsonValue> | null) => {
    if (!r) return "—";
    const unit =
      c.pantryData?.ingredients.find((i) => i.ingredient_id === r.ingredient_id)
        ?.purchase_unit.unit_name ?? "";
    const purpose =
      c.pantryData?.purposes.find(
        (p) => p.pantry_need_purpose_id === r.pantry_need_purpose_id,
      )?.purpose_name_vi ?? "";
    return [
      `${r.requested_quantity ?? "—"} ${unit}`,
      purpose,
      r.note,
      r.source_request_reference,
    ]
      .filter(Boolean)
      .join(" · ");
  };
  // Comparison membership and before/after values come from the backend preview.
  const pairs = [
    ...preview.comparison.new_lines.map((r) => ({
      before: null,
      after: record(r),
      action: "Thêm",
    })),
    ...preview.comparison.changed_lines.map((r) => {
      const pair = record(r);
      return {
        before: record(pair?.before),
        after: record(pair?.after),
        action: "Đổi",
      };
    }),
    ...preview.comparison.omitted_lines.map((r) => ({
      before: record(r),
      after: null,
      action: "Bỏ",
    })),
  ];
  const rows = pairs.flatMap(({ before, after, action }) => {
    const row = after ?? before;
    if (!row) return [];
    return [
      {
        school: school(row.school_id),
        context: `${viDate(String(row.service_date ?? ""))} · ${c.pantryData?.ingredients.find((i) => i.ingredient_id === row.ingredient_id)?.ingredient_name ?? "Nguyên liệu"}`,
        before: value(before),
        after: value(after),
        action,
      },
    ];
  });
  if ("no_additions_confirmed" in preview) {
    const priorZero = c.pantryData?.batch?.no_additions_confirmed ?? false;
    if (priorZero !== preview.no_additions_confirmed)
      rows.push({
        school: "Toàn tuần",
        context: "Xác nhận bổ sung",
        before: priorZero ? "Không có bổ sung" : "Chưa xác nhận",
        after: preview.no_additions_confirmed
          ? "Không có bổ sung"
          : "Chưa xác nhận",
        action: "Đổi",
      });
    const label = {
      ADDITIVE: "Cộng với thực đơn",
      COMPLETE: "Danh sách đầy đủ",
    };
    for (const proposed of preview.school_date_modes) {
      const prior =
        c.pantryData?.batch?.school_date_modes.find(
          (m) =>
            m.school_id === proposed.school_id &&
            m.service_date === proposed.service_date,
        )?.direct_need_mode ?? "ADDITIVE";
      if (prior !== proposed.direct_need_mode)
        rows.push({
          school: school(proposed.school_id),
          context: `${viDate(proposed.service_date)} · Cách kết hợp`,
          before: label[prior],
          after: label[proposed.direct_need_mode],
          action: "Đổi",
        });
    }
  }
  return rows;
}
