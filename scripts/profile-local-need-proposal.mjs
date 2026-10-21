import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

export function proposalProfiles(log) {
  const plans = [];
  for (const match of log.matchAll(
    /NOTICE:\s+duration:\s+([\d.]+) ms\s+plan:\s*/g,
  )) {
    const start = match.index + match[0].length;
    let depth = 0,
      quoted = false,
      escaped = false,
      end = start;
    for (; end < log.length; end++) {
      const char = log[end];
      if (quoted) {
        if (escaped) escaped = false;
        else if (char === "\\") escaped = true;
        else if (char === '"') quoted = false;
      } else if (char === '"') quoted = true;
      else if (char === "{") depth++;
      else if (char === "}" && --depth === 0) {
        end++;
        break;
      }
    }
    plans.push({ ms: Number(match[1]), ...JSON.parse(log.slice(start, end)) });
  }
  const proposals = plans.filter((p) =>
    /^\s*with (?:proposal_resolution|released_contributions)/.test(
      p["Query Text"],
    ),
  );
  assert(proposals.length > 0, "The executed proposal INSERT must be present");
  return proposals.map((proposal, index) => {
    let scans = 0,
      visits = 0;
    function walk(node) {
      if (node["Relation Name"] === "need_generation_release_snapshot_lines") {
        scans += node["Actual Loops"];
        visits +=
          node["Actual Loops"] *
          (node["Actual Rows"] + (node["Rows Removed by Filter"] ?? 0));
      }
      for (const child of node.Plans ?? []) walk(child);
    }
    walk(proposal.Plan);
    assert(scans > 0, "The proposal must actually read release membership");
    return {
      proposal_ms: proposal.ms,
      shared_hits: proposal.Plan["Shared Hit Blocks"],
      release_member_scans: scans,
      release_member_visits: visits,
      source_members: 304,
      retained_source_members: 304 * (index + 1),
    };
  });
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const [container, database, output] = process.argv.slice(2);
  assert.match(container ?? "", /^supabase_db_[\w-]+$/);
  assert.match(database ?? "", /^atlas_[\w]+$/);
  assert(output, "Supply a report path; raw plans remain beside it");
  let source = readFileSync(
    new URL(
      "../supabase/tests/need_generation_operational_scale.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const boundary = source.indexOf(
    "-- These checks run after a completed aggregate",
  );
  assert(boundary > 0);
  source = source.slice(0, boundary).replace(
    "begin;",
    `begin;
load 'auto_explain';
set local auto_explain.log_min_duration='5ms';
set local auto_explain.log_analyze=true;
set local auto_explain.log_buffers=true;
set local auto_explain.log_timing=false;
set local auto_explain.log_nested_statements=true;
set local auto_explain.log_level='notice';
set local auto_explain.log_format='json';`,
  );
  source +=
    "\nselect (count(*)=3 and bool_and(response->>'success'='true'))::text from ng_results where name in ('generate','sequential-21','sequential-22');\nrollback;";
  const result = spawnSync(
    "docker",
    [
      "exec",
      "-i",
      container,
      "psql",
      "-XqAt",
      "-v",
      "ON_ERROR_STOP=1",
      "-U",
      "supabase_admin",
      "-d",
      database,
    ],
    { input: source, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );
  writeFileSync(output + ".log", result.stderr + "\n" + result.stdout);
  assert.equal(result.status, 0, result.stderr.slice(-1000));
  assert.match(result.stdout, /(?:^|\n)true\s*$/);
  const report = proposalProfiles(result.stderr);
  assert.equal(report.length, 3, "Profile all three fresh generations");
  writeFileSync(output, JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report));
  // The fixture retains earlier days; bound by source history, never target × source.
  assert(
    report.every(
      (sample) => sample.release_member_scans <= sample.retained_source_members,
    ),
    "Proposal INSERT must not reopen membership for each target/source pair",
  );
}
