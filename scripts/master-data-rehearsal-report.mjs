const text = (value) =>
  String(value ?? "—").replace(/[\r\n\u0000-\u001f]/g, " ");
const compare = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const issueLabel = (issue) =>
  [issue.code, issue.object_type ?? issue.entity, issue.legacy_id, issue.field]
    .filter((v) => v != null)
    .map(text)
    .join(" | ");
export function isReconciledMasterPreview(preview) {
  return (
    preview?.success === true &&
    Array.isArray(preview.actions) &&
    preview.actions.every((a) =>
      ["NO_CHANGE", "MISSING_FROM_SOURCE"].includes(a.action),
    )
  );
}
export function formatMasterDataRehearsalReport({
  mode = "preview",
  snapshot = {},
  preview = {},
  result,
  afterPreview,
} = {}) {
  const issues = [...(preview.issues ?? [])].sort((a, b) =>
    compare(issueLabel(a), issueLabel(b)),
  );
  const actions = preview.actions ?? [];
  const accepted =
    mode === "apply" &&
    result?.success === true &&
    isReconciledMasterPreview(afterPreview);
  const gate =
    preview.success !== true || (mode === "apply" && !accepted)
      ? "REJECTED"
      : accepted
        ? "REHEARSAL_ACCEPTED"
        : "NOT_APPLIED";
  const output = [
    "Atlas master-data rehearsal",
    mode === "preview"
      ? "Mode: PREVIEW — no business writes"
      : "Mode: APPLY — explicit local import",
    "",
    `Snapshot: ${text(snapshot.snapshot_id)}`,
    `Snapshot checksum: ${text(snapshot.snapshot_checksum)}`,
    `Plan checksum: ${text(preview.plan_checksum)}`,
    `Exported at: ${text(snapshot.exported_at)}`,
    `Extractor: ${text(snapshot.extractor_version)}`,
    "",
    "Source counts",
  ];
  for (const [entity, count] of Object.entries(
    snapshot.source_counts ?? {},
  ).sort(([a], [b]) => compare(a, b)))
    output.push(`  ${text(entity)}: ${text(count)}`);
  output.push("", "Actions");
  const counts = new Map();
  for (const a of actions) {
    const key = `${a.object_type} / ${a.action}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  for (const [key, count] of [...counts.entries()].sort(([a], [b]) =>
    compare(a, b),
  ))
    output.push(`  ${text(key)}: ${count}`);
  const blockerRows = issues.filter((issue) => issue.severity === "BLOCKER");
  const blockerCategories = new Map();
  for (const issue of blockerRows)
    blockerCategories.set(
      issue.code,
      (blockerCategories.get(issue.code) ?? 0) + 1,
    );
  output.push("", "Blocker categories");
  for (const [code, count] of [...blockerCategories.entries()].sort(
    ([a], [b]) => compare(a, b),
  ))
    output.push(`  ${text(code)}: ${count}`);
  for (const [title, rows] of [
    ["Blockers", blockerRows],
    ["Target drift", issues.filter((i) => i.code === "TARGET_DRIFT")],
    [
      "Missing roots",
      actions
        .filter((a) => a.action === "MISSING_FROM_SOURCE")
        .map((a) => ({ ...a, code: a.action })),
    ],
    [
      "Relationship removals",
      actions
        .filter(
          (a) =>
            a.action === "REMOVE_RELATIONSHIP" ||
            (a.object_type === "RECIPE_LINE_REVISION" &&
              a.values?.line_disposition === "REMOVED"),
        )
        .map((a) => ({ ...a, code: a.action })),
    ],
    [
      "Source-only fields",
      issues.filter((i) => i.code === "SOURCE_ONLY_UNMAPPED"),
    ],
  ]) {
    output.push("", `${title}: ${rows.length}`);
    const sortedRows = [...rows].sort((a, b) =>
      compare(issueLabel(a), issueLabel(b)),
    );
    const visibleRows =
      title === "Source-only fields" ? sortedRows.slice(0, 20) : sortedRows;
    for (const row of visibleRows) output.push(`  ${issueLabel(row)}`);
    if (
      title === "Source-only fields" &&
      sortedRows.length > visibleRows.length
    )
      output.push(
        `  … ${sortedRows.length - visibleRows.length} more source-only fields omitted from console output`,
      );
  }
  output.push("", "Units");
  for (const alias of [...(snapshot.unit_alias_evidence ?? [])].sort((a, b) =>
    compare(a.source_label, b.source_label),
  ))
    output.push(
      `  ${text(alias.source_label)} → ${text(alias.canonical_label)}`,
    );
  output.push(
    "",
    "Recipe/BOM: inspect source counts, planned identities and explicit blockers; no operational history is imported.",
  );
  if (result)
    output.push(
      `Apply status: ${text(result.status)}`,
      `Actor: ${text(result.operator_actor_id)}`,
      `Import batch: ${text(result.import_batch_id)}`,
    );
  output.push(`Gate: ${gate}`);
  output.push(
    "Hosted Staging/cutover authorization: NOT PROVIDED by this local runner.",
  );
  return `${output.join("\n")}\n`;
}
