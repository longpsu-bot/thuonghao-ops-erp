// @vitest-environment node
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  buildIngredientNameCorrectionPayload,
  buildIngredientNameCorrectionSql,
  buildIngredientNameSourceSql,
  extractReviewedIngredientSnapshot,
  runIngredientNameCorrection,
} from "./correct-atlas-staging-ingredient-names.mjs";
import {
  canonicalMasterJson,
  checksumOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";

const target = "rnzxmxiiqgtdevzregff";
const expected = [
  ["931", "Chả giò", "Chả giò xốp Cholimex 2kg"],
  ["962", "Hẹ tươi", "Hẹ lá"],
  ["1040", "Thịt heo xay", "Thịt vai heo xay"],
  ["1041", "Thịt nạc vai", "Nạc vai heo"],
  ["1047", "Tôm thẻ", "Tôm thẻ size 60 - 70 con/kg"],
  ["1053", "Ức gà fillet (không da)", "Ức phi lê gà"],
  ["1067", "Sườn non heo chặt sẵn", "Sườn non heo chặt nhỏ"],
  ["1154", "Nạc lưng heo", "Nạc lưng heo (Miếng)"],
];

function snapshot() {
  const value = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "ops-v1-fixture",
    exported_at: "2026-10-27T00:00:00.000Z",
    extractor_version: "a".repeat(40),
    source_counts: { ingredients: 8 },
    records: {
      ingredients: expected.map(([legacy_id, , ingredient_name]) => ({
        legacy_id,
        ingredient_code: `v1-ingredient-${legacy_id}`,
        ingredient_name,
        ingredient_type_legacy_id: "1",
        ingredient_order_group_legacy_id: "1",
        purchase_unit_legacy_id: legacy_id === "1154" ? "Miếng" : "kg",
        order_step: legacy_id === "1154" ? "1" : "0.1",
        ingredient_status: "ACTIVE",
      })),
    },
    source_diagnostics: [],
  };
  return { ...value, snapshot_checksum: checksumOpsV1MasterSnapshot(value) };
}

const env = {
  ATLAS_STAGING_PROJECT_REF: target,
  VITE_SUPABASE_URL: `https://${target}.supabase.co`,
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-token",
};

describe("bounded OPS v1 Ingredient-name correction", () => {
  it("keeps the hosted workflow manual, preview-first, and exact-main guarded", () => {
    const workflow = readFileSync(
      new URL(
        "../.github/workflows/atlas-staging-ingredient-name-forward-correction.yml",
        import.meta.url,
      ),
      "utf8",
    );
    expect(workflow).toMatch(/on:\s*\n\s*workflow_dispatch:/);
    expect(workflow).not.toMatch(
      /\n\s+(push|pull_request|schedule|release|workflow_run):/,
    );
    expect(workflow).toContain("default: false");
    expect(workflow).toContain("environment: atlas-staging");
    expect(workflow).toContain("contents: read");
    expect(workflow).toContain("ref: ${{ inputs.commit_sha }}");
    expect(workflow).toContain(
      "git fetch --no-tags origin main:refs/remotes/origin/main",
    );
    expect(workflow).toContain(
      'test "$(git rev-parse origin/main)" = "$REQUESTED_SHA"',
    );
    expect(workflow).toContain(
      'args+=(--apply --target-project-ref "$CONFIRMED_TARGET")',
    );
    expect(workflow).not.toMatch(/db reset|db push|production/i);
  });

  it("reads only the reviewed Ingredient rows through the read-only source endpoint", async () => {
    const sql = buildIngredientNameSourceSql();
    expect(sql).toContain(
      "from public.ingredients where id in (931,962,1040,1041,1047,1053,1067,1154)",
    );
    expect(sql).not.toMatch(
      /from public\.(schools|dishes|recipes|bill_of_materials)/,
    );
    const fetchImpl = vi.fn(async (url, options) => ({
      status: 201,
      json: async () => [
        {
          snapshot: {
            source_project_ref: "qnthofvccilhnefdcxnz",
            source_access: {
              role_name: "supabase_read_only_user",
              superuser: false,
              create_role: false,
              create_db: false,
              has_select: true,
              has_non_select: false,
            },
            ingredients: expected.map(([id, , name]) => ({
              id,
              name,
              purchase_unit: "kg",
              ingredient_type_id: "1",
              shopping_type_id: "1",
              order_step: "1.000000",
              is_active: true,
              archived_at: null,
            })),
          },
        },
      ],
    }));
    const extracted = await extractReviewedIngredientSnapshot({
      accessToken: "synthetic-token",
      fetchImpl,
    });
    expect(fetchImpl).toHaveBeenCalledOnce();
    expect(fetchImpl.mock.calls[0][0]).toMatch(/\/database\/query\/read-only$/);
    expect(JSON.parse(fetchImpl.mock.calls[0][1].body).query).toBe(sql);
    expect(extracted.records.ingredients).toHaveLength(8);
    expect(extracted.records.ingredients[0].order_step).toBe("1");
  });

  it("pins the eight reviewed identities, prior names and current v1 source names", () => {
    const payload = buildIngredientNameCorrectionPayload(snapshot());
    expect(
      payload.records.map((row) => [
        row.legacy_id,
        row.expected_before_name,
        row.expected_after_name,
      ]),
    ).toEqual(expected);
    for (const row of payload.records)
      expect(row.source_fingerprint).toBe(
        createHash("sha256")
          .update(canonicalMasterJson(row.source_record), "utf8")
          .digest("hex"),
      );
  });

  it("fails closed when a reviewed source identity is renamed again or missing", () => {
    const renamed = snapshot();
    renamed.records.ingredients[0].ingredient_name = "Tên chưa được duyệt";
    renamed.snapshot_checksum = checksumOpsV1MasterSnapshot(renamed);
    expect(() => buildIngredientNameCorrectionPayload(renamed)).toThrow(
      /SOURCE_SCOPE_DRIFT/,
    );

    const missing = snapshot();
    missing.records.ingredients.pop();
    missing.snapshot_checksum = checksumOpsV1MasterSnapshot(missing);
    expect(() => buildIngredientNameCorrectionPayload(missing)).toThrow(
      /SOURCE_SCOPE_DRIFT/,
    );
  });

  it("builds rollback-only preview SQL and requires the exact reviewed plan for apply", () => {
    const payload = buildIngredientNameCorrectionPayload(snapshot());
    const previewSql = buildIngredientNameCorrectionSql(payload, {
      targetProjectRef: target,
    });
    expect(previewSql).toContain("run_ingredient_name_forward_correction");
    expect(previewSql).toContain(", false, null,");
    expect(previewSql).not.toContain("Chả giò xốp Cholimex 2kg");
    expect(() =>
      buildIngredientNameCorrectionSql(payload, {
        targetProjectRef: target,
        apply: true,
      }),
    ).toThrow(/REVIEWED_PLAN_CHECKSUM_REQUIRED/);
  });

  it("previews once without writes and binds apply plus replay to the same payload", async () => {
    const payload = buildIngredientNameCorrectionPayload(snapshot());
    const plan = {
      success: true,
      status: "PREVIEW",
      plan_checksum: "b".repeat(64),
      correction_id: payload.correction_id,
      source_snapshot_checksum: snapshot().snapshot_checksum,
      update_count: 8,
      no_change_count: 0,
      report: expected.map(([legacy_id, before, after]) => ({
        legacy_id,
        current_name: before,
        proposed_name: after,
        action: "UPDATE",
      })),
    };
    const calls = [];
    const executeTarget = async (_target, sql) => {
      calls.push(sql);
      return JSON.stringify([
        {
          result:
            calls.length === 1
              ? plan
              : {
                  ...plan,
                  status: calls.length === 2 ? "APPLIED" : "REPLAYED",
                  reconciled: true,
                  operational_data_unchanged: true,
                  unrelated_master_facts_unchanged: true,
                  updated_count: 8,
                },
        },
      ]);
    };
    const verifyCheckout = vi.fn();
    const extractSnapshot = vi.fn(async () => snapshot());

    const preview = await runIngredientNameCorrection({
      commitSha: "a".repeat(40),
      environment: env,
      verifyCheckout,
      extractSnapshot,
      executeTarget,
    });
    expect(preview.status).toBe("PREVIEW");
    expect(calls).toHaveLength(1);

    calls.length = 0;
    const applied = await runIngredientNameCorrection({
      commitSha: "a".repeat(40),
      apply: true,
      targetConfirmation: target,
      environment: env,
      verifyCheckout,
      extractSnapshot,
      executeTarget,
    });
    expect(applied.status).toBe("APPLIED");
    expect(applied.replay_status).toBe("REPLAYED");
    expect(calls).toHaveLength(3);
    expect(calls[1]).toContain(plan.plan_checksum);
    expect(calls[2]).toContain(plan.plan_checksum);
  });
});
