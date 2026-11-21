import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const before = JSON.parse(
  readFileSync(new URL("before.json", import.meta.url), "utf8"),
);

function replaceExactly(source, needle, replacement, count = 1) {
  if (source.split(needle).length - 1 !== count) {
    throw new Error("OPS_V1_LABEL_SOURCE_MISMATCH");
  }
  return source.replaceAll(needle, replacement);
}

const labelCase = (alias, fallback, prefix = "") =>
  `CASE ${alias}.id WHEN 8 THEN '${prefix}TIỂU HỌC BÌNH MỸ - BÌNH DƯƠNG' WHEN 9 THEN '${prefix}TIỂU HỌC BÌNH MỸ - CỦ CHI' ELSE ${fallback} END`;

export const after = Object.fromEntries(
  Object.entries(before).map(([name, source]) => {
    let patched;
    if (name.startsWith("q_po_grouped_")) {
      patched = replaceExactly(
        source,
        "CASE WHEN s.id IN (47,48,49,50,53) THEN regexp_replace",
        "CASE WHEN s.id = 8 THEN 'TIỂU HỌC BÌNH MỸ - BÌNH DƯƠNG' WHEN s.id = 9 THEN 'TIỂU HỌC BÌNH MỸ - CỦ CHI' WHEN s.id IN (47,48,49,50,53) THEN regexp_replace",
      );
    } else if (name === "q_dispatch_lines_grouped") {
      patched = replaceExactly(
        source,
        "g.name,NULLIF(s.school_full_name,'')",
        `g.name,${labelCase("s", "NULL::text")},NULLIF(s.school_full_name,'')`,
        2,
      );
    } else if (name === "q_dispatch_lines") {
      patched = replaceExactly(
        source,
        "s.name                  AS school_name",
        `${labelCase("s", "s.name")} AS school_name`,
      );
      patched = replaceExactly(
        patched,
        "s.school_full_name      AS school_full_name",
        `${labelCase("s", "s.school_full_name", "TRƯỜNG ")} AS school_full_name`,
      );
    } else if (name === "q_po_school_breakdown_from_po") {
      patched = replaceExactly(
        source,
        "sch.name          as school_name",
        `${labelCase("sch", "sch.name")} as school_name`,
      );
    } else {
      throw new Error(`Unexpected query: ${name}`);
    }
    return [name, patched];
  }),
);

export function guardedReplacement(name, current, rollback = false) {
  if (
    !Object.hasOwn(before, name) ||
    current !== (rollback ? after : before)[name]
  ) {
    throw new Error("OPS_V1_LABEL_SOURCE_MISMATCH");
  }
  return (rollback ? before : after)[name];
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  writeFileSync(
    new URL("after.json", import.meta.url),
    `${JSON.stringify(after, null, 2)}\n`,
  );
  console.log("Generated six guarded Retool SELECT replacements.");
}
