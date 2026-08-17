import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  ATLAS_STAGING_GITHUB_ENVIRONMENT,
  ATLAS_STAGING_SECRET_NAMES,
  ATLAS_STAGING_VARIABLE_NAMES,
  LIVE_OPS_PROJECT_DENYLIST,
  ensureAtlasApiExposure,
  redactAtlasStagingDiagnostic,
  validateAtlasStagingProtectedValues,
  validateAtlasStagingTarget,
  verifyAtlasApiExposure,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";
import {
  deployAtlasStaging,
  planAtlasStagingDeployment,
} from "./deploy-atlas-staging.mjs";
import {
  assertAnonymousAuthorizationDenial,
  assertExactMigrationHistory,
  catalogVerificationSql,
  migrationVersionsFromFilenames,
  parseMigrationHistoryEvidence,
  planAtlasStagingVerification,
  readCatalogAuthority,
  verifyAtlasStaging,
} from "./verify-atlas-staging.mjs";

const stagingRef = "abcdefghijklmnopqrst";
const commitSha = "a".repeat(40);

function environment(overrides = {}) {
  return {
    ATLAS_STAGING_PROJECT_REF: stagingRef,
    VITE_ATLAS_ENVIRONMENT: "staging",
    VITE_SUPABASE_URL: `https://${stagingRef}.supabase.co`,
    VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_atlas_staging_test_value",
    ATLAS_STAGING_TEST_EMAIL: "atlas.staging@example.test",
    ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-access-token",
    ATLAS_STAGING_DB_PASSWORD: "synthetic-database-password",
    ATLAS_STAGING_TEST_PASSWORD: "synthetic-test-password",
    GITHUB_REPOSITORY: "longpsu-bot/thuonghao-ops-erp",
    GITHUB_TOKEN: "synthetic-github-token",
    ...overrides,
  };
}

describe("Atlas staging safety contract", () => {
  it("freezes the exact GitHub Environment and protected names", () => {
    expect(ATLAS_STAGING_GITHUB_ENVIRONMENT).toBe("atlas-staging");
    expect(ATLAS_STAGING_VARIABLE_NAMES).toEqual([
      "ATLAS_STAGING_PROJECT_REF",
      "VITE_ATLAS_ENVIRONMENT",
      "VITE_SUPABASE_URL",
      "VITE_SUPABASE_PUBLISHABLE_KEY",
      "ATLAS_STAGING_TEST_EMAIL",
    ]);
    expect(ATLAS_STAGING_SECRET_NAMES).toEqual([
      "ATLAS_STAGING_SUPABASE_ACCESS_TOKEN",
      "ATLAS_STAGING_DB_PASSWORD",
      "ATLAS_STAGING_TEST_PASSWORD",
    ]);
  });

  it("contains exactly the live OPS project denylist", () => {
    expect(LIVE_OPS_PROJECT_DENYLIST).toEqual(["qnthofvccilhnefdcxnz"]);
    expect(() =>
      validateAtlasStagingTarget(
        "qnthofvccilhnefdcxnz",
        "https://qnthofvccilhnefdcxnz.supabase.co",
      ),
    ).toThrow(/forbidden/i);
  });

  it("rejects a protected project-ref and URL mismatch", () => {
    expect(() =>
      validateAtlasStagingTarget(
        stagingRef,
        "https://zyxwvutsrqponmlkjihg.supabase.co",
      ),
    ).toThrow(/do not match/i);
  });

  it.each([undefined, "local", "production", "preview"])(
    "requires explicit staging mode instead of %s",
    (mode) => {
      expect(() =>
        validateAtlasStagingProtectedValues(
          environment({ VITE_ATLAS_ENVIRONMENT: mode }),
        ),
      ).toThrow();
    },
  );

  it("redacts keys, JWTs, database URLs, and supplied protected values", () => {
    const diagnostic = redactAtlasStagingDiagnostic(
      "postgresql://postgres:password@db.example.supabase.co:5432/postgres sb_secret_value eyJprivate Bearer token-value direct-secret",
      ["direct-secret"],
    );
    expect(diagnostic).not.toMatch(
      /password|sb_secret|eyJprivate|token-value|direct-secret/,
    );
    expect(diagnostic).toContain("REDACTED");
  });

  it("requires exact-head main membership and both exact job certifications", async () => {
    const commands = [];
    const runCommand = vi.fn((command, args) => {
      commands.push([command, ...args]);
      if (args[0] === "rev-parse")
        return { status: 0, stdout: `${commitSha}\n`, stderr: "" };
      return { status: 0, stdout: "", stderr: "" };
    });
    const fetchImpl = vi.fn(async (url) => ({
      ok: true,
      async json() {
        if (url.includes("/runs?")) {
          return {
            workflow_runs: [
              {
                id: url.includes("frontend-ci") ? 1 : 2,
                head_sha: commitSha,
                conclusion: "success",
              },
            ],
          };
        }
        return {
          jobs: [
            {
              name: url.includes("/runs/1/")
                ? "Format, typecheck, test, build"
                : "Supabase Full Integration",
              conclusion: "success",
            },
          ],
        };
      },
    }));

    await expect(
      verifyExactHeadCertification({
        commitSha,
        environment: environment(),
        runCommand,
        fetchImpl,
      }),
    ).resolves.toBe(commitSha);
    expect(commands).toContainEqual([
      "git",
      "merge-base",
      "--is-ancestor",
      commitSha,
      "origin/main",
    ]);
    expect(
      fetchImpl.mock.calls.some(([url]) => url.includes("frontend-ci.yml")),
    ).toBe(true);
    expect(
      fetchImpl.mock.calls.some(([url]) =>
        url.includes("supabase-integration.yml"),
      ),
    ).toBe(true);
  });

  it("fails closed when an exact-head required job is not successful", async () => {
    const runCommand = (command, args) => ({
      status: 0,
      stdout: args[0] === "rev-parse" ? `${commitSha}\n` : "",
      stderr: "",
    });
    const fetchImpl = async (url) => ({
      ok: true,
      async json() {
        return url.includes("/runs?")
          ? {
              workflow_runs: [
                { id: 1, head_sha: commitSha, conclusion: "success" },
              ],
            }
          : { jobs: [{ name: "wrong job", conclusion: "success" }] };
      },
    });
    await expect(
      verifyExactHeadCertification({
        commitSha,
        environment: environment(),
        runCommand,
        fetchImpl,
      }),
    ).rejects.toThrow(/certification is missing/i);
  });
});

describe("Atlas staging dry-run and workflow", () => {
  it("constructs deployment and verifier plans without mutation", async () => {
    const deployPlan = planAtlasStagingDeployment(environment());
    const verifyPlan = planAtlasStagingVerification(environment());
    expect(deployPlan.repositoryMigrationsOnly).toBe(true);
    expect(deployPlan.installsDataPackages).toBe(false);
    expect(deployPlan.deploysEdgeFunctions).toBe(false);
    expect(verifyPlan.networkWrites).toBe(false);
    expect(deployPlan.command.join(" ")).not.toContain(
      "synthetic-database-password",
    );
    expect(verifyPlan.commands.flat().join(" ")).not.toContain(
      "synthetic-database-password",
    );

    const runCommand = vi.fn();
    const fetchImpl = vi.fn();
    await expect(
      deployAtlasStaging({
        commitSha,
        environment: environment(),
        runCommand,
        fetchImpl,
        dryRun: true,
      }),
    ).resolves.toMatchObject({ status: "dry-run" });
    await expect(
      verifyAtlasStaging({
        environment: environment(),
        runCommand,
        fetchImpl,
        dryRun: true,
      }),
    ).resolves.toMatchObject({ networkWrites: false });
    expect(runCommand).not.toHaveBeenCalled();
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it("keeps the workflow manual, protected, and free of duplicate integration", () => {
    const workflow = readFileSync(
      ".github/workflows/atlas-staging-deploy.yml",
      "utf8",
    );
    expect(workflow).toMatch(/on:\s*\n\s*workflow_dispatch:/);
    expect(workflow).not.toMatch(/\n\s+(push|pull_request|schedule|release):/);
    expect(workflow).toContain("environment: atlas-staging");
    expect(workflow).toContain("contents: read");
    expect(workflow).toContain("actions: read");
    expect(workflow).toContain("checks: read");
    expect(workflow).not.toMatch(/permissions:[\s\S]*\bwrite\b/);
    expect(workflow).not.toContain("supabase start");
    expect(workflow).not.toContain("Supabase Full Integration");
    expect(workflow).not.toMatch(/production/i);
  });

  it("classifies every Atlas staging boundary script for Supabase certification", () => {
    const workflow = readFileSync(
      ".github/workflows/supabase-integration.yml",
      "utf8",
    );
    const pullRequestPaths = workflow.slice(
      workflow.indexOf("  pull_request:"),
      workflow.indexOf("\n  push:"),
    );
    const pushPaths = workflow.slice(
      workflow.indexOf("  push:"),
      workflow.indexOf("\n  workflow_dispatch:"),
    );
    const stagingBoundaryPaths = [
      "scripts/atlas-staging-contract.mjs",
      "scripts/atlas-staging-contract.test.mjs",
      "scripts/deploy-atlas-staging.mjs",
      "scripts/verify-atlas-staging.mjs",
    ];

    for (const eventPaths of [pullRequestPaths, pushPaths]) {
      const classifiedPaths = eventPaths
        .split(/\r?\n/)
        .map((line) => /^\s+- "([^"]+)"$/.exec(line)?.[1])
        .filter(Boolean);
      for (const path of stagingBoundaryPaths) {
        expect(classifiedPaths.filter((value) => value === path)).toHaveLength(
          1,
        );
      }
    }
  });
});

describe("Atlas staging hosted evidence", () => {
  it("preserves existing exposed schemas and adds atlas_api exactly once", async () => {
    let schemas = "public,graphql_public";
    const fetchImpl = vi.fn(async (_url, options = {}) => {
      if (options.method === "PATCH") {
        schemas = JSON.parse(options.body).db_schema;
        return {
          ok: true,
          async json() {
            return {};
          },
        };
      }
      return {
        ok: true,
        async json() {
          return { db_schema: schemas };
        },
      };
    });
    const target = validateAtlasStagingProtectedValues(environment());

    await expect(ensureAtlasApiExposure(target, fetchImpl)).resolves.toEqual([
      "public",
      "graphql_public",
      "atlas_api",
    ]);
    await expect(verifyAtlasApiExposure(target, fetchImpl)).resolves.toContain(
      "atlas_api",
    );
    await ensureAtlasApiExposure(target, fetchImpl);

    expect(
      fetchImpl.mock.calls.filter(([, options]) => options?.method === "PATCH"),
    ).toHaveLength(1);
    expect(schemas).toBe("public,graphql_public,atlas_api");
  });

  it("rejects missing atlas_api exposure", async () => {
    const target = validateAtlasStagingProtectedValues(environment());
    await expect(
      verifyAtlasApiExposure(target, async () => ({
        ok: true,
        async json() {
          return { db_schema: "public,graphql_public" };
        },
      })),
    ).rejects.toThrow(/not exposed/i);
  });

  it("parses marked machine-readable migration evidence", () => {
    const versions = ["20260101000000", "20260102000000"];
    const output = JSON.stringify({
      result: `ATLAS_MIGRATION_HISTORY=${JSON.stringify({ versions, row_count: 2 })}`,
    });
    expect(parseMigrationHistoryEvidence(output)).toEqual({
      versions,
      row_count: 2,
    });
    expect(() =>
      parseMigrationHistoryEvidence(
        "Local          │ Remote         │ Time\n20260101000000 │ 20260101000000 │ now",
      ),
    ).toThrow(/JSON output/i);
  });

  it.each([
    [
      ["20260101000000"],
      { versions: ["20260101000000", "20260102000000"], row_count: 2 },
    ],
    [
      ["20260101000000", "20260102000000"],
      { versions: ["20260101000000"], row_count: 1 },
    ],
    [
      ["20260101000000"],
      { versions: ["20260101000000", "20260101000000"], row_count: 2 },
    ],
    [["20260101000000"], { versions: ["bad-version"], row_count: 1 }],
    [["20260101000000"], { versions: ["20260101000000"], row_count: 2 }],
  ])(
    "rejects remote-only, local-only, duplicate, malformed, or incomplete migration evidence",
    (local, remote) => {
      expect(() => assertExactMigrationHistory(local, remote)).toThrow();
    },
  );

  it("rejects malformed and duplicate repository migration filenames", () => {
    expect(() => migrationVersionsFromFilenames(["bad.sql"])).toThrow(
      /malformed/i,
    );
    expect(() =>
      migrationVersionsFromFilenames([
        "20260101000000_one.sql",
        "20260101000000_two.sql",
      ]),
    ).toThrow(/duplicated/i);
  });

  it("loads exact catalog identity authority and CAT-22 policy digest", () => {
    const authority = readCatalogAuthority();
    expect(authority.schemas).toHaveLength(10);
    expect(authority.databaseRoles).toHaveLength(11);
    expect(authority.apiSignatures).toHaveLength(90);
    expect(authority.apiOwners).toHaveLength(90);
    expect(authority.policyCount).toBe(601);
    expect(authority.policyDigest).toBe("eb60e34add82c6c2a8cdd77be71f5598");
  });

  it("uses one normal CAT-22 policy catalog for both count and digest", () => {
    const authority = readCatalogAuthority();
    const sql = catalogVerificationSql(authority);
    const normalCatalog = sql.match(
      /with normal_policy_catalog as \(([\s\S]*?)\)\s*select count\(\*\), md5\(string_agg\(row_text,[\s\S]*?from normal_policy_catalog;/,
    );
    expect(normalCatalog).not.toBeNull();
    expect(normalCatalog?.[1]).toContain(
      "not (n.nspname = 'atlas_admin' and c.relname = 'units' and p.polname = 'rmvp_05_unit_lock')",
    );
    expect(sql).toContain("normal_policy_count <> 601");
    expect(sql).not.toContain("if (select count(*) from pg_policy");
    expect(sql).toContain("ATLAS_POLICY_COUNT_MISMATCH");
    expect(sql).toContain("ATLAS_POLICY_DIGEST_MISMATCH");
  });

  it("requires exactly one isolated RMVP-05 Unit lock policy", () => {
    const sql = catalogVerificationSql(readCatalogAuthority());
    expect(sql).toMatch(
      /where n\.nspname = 'atlas_admin'\s+and c\.relname = 'units'\s+and p\.polname = 'rmvp_05_unit_lock';/,
    );
    expect(sql).toContain("isolated_policy_count <> 1");
    expect(sql).toContain("ATLAS_ISOLATED_POLICY_MISMATCH");
  });

  it.each([
    [601, 1, true],
    [601, 0, false],
    [601, 2, false],
    [600, 1, false],
    [602, 1, false],
  ])(
    "models %i normal and %i isolated policies as accepted=%s",
    (normalPolicyCount, isolatedPolicyCount, accepted) => {
      const authority = readCatalogAuthority();
      expect(
        normalPolicyCount === authority.policyCount &&
          isolatedPolicyCount === 1,
      ).toBe(accepted);
    },
  );

  it("retains the unrelated fail-closed catalog checks", () => {
    const sql = catalogVerificationSql(readCatalogAuthority());
    expect(sql).toContain("ATLAS_API_SIGNATURE_MISMATCH");
    expect(sql).toContain("ATLAS_API_OWNER_MISMATCH");
    expect(sql).toContain(
      "p.proconfig is distinct from array['search_path=\"\"']",
    );
    expect(sql).not.toContain("ATLAS_API_FINGERPRINT_MISMATCH");
  });

  it("accepts only the expected anonymous authorization denial", () => {
    expect(() =>
      assertAnonymousAuthorizationDenial({
        code: "42501",
        message: "permission denied for schema atlas_api",
      }),
    ).not.toThrow();
    for (const error of [
      undefined,
      { code: "PGRST106", message: "schema not exposed" },
      { code: "PGRST202", message: "function missing" },
      { code: "PGRST002", message: "schema cache unavailable" },
      { message: "Failed to fetch" },
    ]) {
      expect(() => assertAnonymousAuthorizationDenial(error)).toThrow(
        /expected authorization denial/i,
      );
    }
  });
});
