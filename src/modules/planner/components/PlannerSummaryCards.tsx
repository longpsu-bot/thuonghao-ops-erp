import type { DemandSource, RequirementLine } from "../types";
export function PlannerSummaryCards({
  sources,
  lines,
}: {
  sources: DemandSource[];
  lines: RequirementLine[];
}) {
  const cards = [
    ["Nguồn nhu cầu", sources.length],
    ["Dòng yêu cầu", lines.length],
    [
      "Có cảnh báo",
      lines.filter((x) => x.severity === "WARNING" || x.severity === "INFO")
        .length,
    ],
    [
      "Đang chặn",
      lines.filter(
        (x) => x.severity === "BLOCKING" || x.readiness === "BLOCKED",
      ).length,
    ],
    [
      "Thay thế / override",
      lines.filter((x) => x.hasSubstitution || x.hasOverride).length,
    ],
    [
      "Thiếu nhà cung cấp",
      lines.filter((x) => x.supplierStatus === "MISSING").length,
    ],
    ["Sẵn sàng mua hàng", lines.filter((x) => x.readiness === "READY").length],
  ];
  return (
    <section className="summary-grid" aria-label="Tóm tắt kế hoạch">
      {cards.map(([label, value]) => (
        <article key={label}>
          <span>{label}</span>
          <strong>{value}</strong>
        </article>
      ))}
    </section>
  );
}
