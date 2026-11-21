// Emits read-only PostgreSQL probes. Execute through the existing v1 SQL connector.
// No credentials, writes, temporary objects, confirmation RPCs or new dependencies.
import { before, after } from "./patch.mjs";

const baseline = process.argv.includes("--baseline");
function bind(source, selected) {
  return source
    .replaceAll(/{{\s*PO_datepicker\.value\.start\s*}}/g, "'2026-11-02'")
    .replaceAll(/{{\s*PO_datepicker\.value\.end\s*}}/g, "'2026-11-06'")
    .replaceAll(
      /{{\s*JSON\.stringify\(selSchoolMulti\.value \|\| \[\]\)\s*}}/g,
      `'${JSON.stringify(selected)}'`,
    )
    .replaceAll(
      /{{\s*selSchoolMulti\.value\s*}}/g,
      `ARRAY[${selected.join(",")}]::bigint[]`,
    )
    .replace(/;\s*$/, "");
}

const probes = [];
for (const name of Object.keys(before)) {
  const dispatch = name.startsWith("q_dispatch");
  const grouped = name.includes("grouped");
  const labels = grouped
    ? ["entity_name", ...(dispatch ? ["group_name_xlsx"] : [])]
    : ["school_name", ...(dispatch ? ["school_full_name"] : [])];
  const id = grouped ? "entity_numeric_id" : "school_id";
  const schoolOnly = grouped ? "body->>'entity_type'='school' AND " : "";
  const target = `${schoolOnly}(body->>'${id}')::bigint IN (8,9)`;
  for (const selected of dispatch ? [[], [8], [9], [8, 9]] : [[]]) {
    const wanted = [8, 9].filter(
      (school) => !selected.length || selected.includes(school),
    );
    const candidate = (baseline ? before : after)[name];
    const expected = labels
      .flatMap((field) =>
        wanted.map((school) => {
          const label = `${field === "school_full_name" ? "TRƯỜNG " : ""}TIỂU HỌC BÌNH MỸ - ${school === 8 ? "BÌNH DƯƠNG" : "CỦ CHI"}`;
          const targetSchool = `${schoolOnly}(body->>'${id}')::bigint=${school}`;
          return `(count(*) FILTER (WHERE ${targetSchool}) > 0 AND count(*) FILTER (WHERE ${targetSchool} AND body->>'${field}' IS DISTINCT FROM '${label}') = 0)`;
        }),
      )
      .join(" AND ");
    probes.push({
      name,
      selected,
      sql: `WITH old_rows AS (${bind(before[name], selected)}),
new_rows AS (${bind(candidate, selected)}),
b AS (SELECT row_number() OVER () n,to_jsonb(x) body FROM old_rows x),
a AS (SELECT row_number() OVER () n,to_jsonb(x) body FROM new_rows x),
delta AS ((SELECT body - ARRAY[${labels.map((x) => `'${x}'`).join(",")}] FROM a EXCEPT ALL SELECT body - ARRAY[${labels.map((x) => `'${x}'`).join(",")}] FROM b)
UNION ALL (SELECT body - ARRAY[${labels.map((x) => `'${x}'`).join(",")}] FROM b EXCEPT ALL SELECT body - ARRAY[${labels.map((x) => `'${x}'`).join(",")}] FROM a)),
unrelated AS ((SELECT body FROM a WHERE NOT (${target}) EXCEPT ALL SELECT body FROM b WHERE NOT (${target}))
UNION ALL (SELECT body FROM b WHERE NOT (${target}) EXCEPT ALL SELECT body FROM a WHERE NOT (${target})))
SELECT '${name}' query, '${JSON.stringify(selected)}' selected,
(SELECT count(*) FROM a) row_count,
(SELECT count(*) FROM delta) non_label_deltas,
(SELECT count(*) FROM unrelated) unrelated_deltas,
(SELECT ${expected} FROM a) labels_pass,
(SELECT jsonb_agg(body - ARRAY[${labels.map((x) => `'${x}'`).join(",")}] ORDER BY n) FROM a)
IS NOT DISTINCT FROM (SELECT jsonb_agg(body - ARRAY[${labels.map((x) => `'${x}'`).join(",")}] ORDER BY n) FROM b) order_pass,
(SELECT jsonb_agg(DISTINCT jsonb_build_object('id',body->>'${id}'${labels.map((x) => `,'${x}',body->>'${x}'`).join("")})) FROM a WHERE ${target}) target_labels;`,
    });
  }
}
console.log(JSON.stringify(probes));
