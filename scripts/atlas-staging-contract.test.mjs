import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  ATLAS_STAGING_GITHUB_ENVIRONMENT,
  ATLAS_STAGING_SECRET_NAMES,
  ATLAS_STAGING_VARIABLE_NAMES,
  LIVE_OPS_PROJECT_DENYLIST,
  redactAtlasStagingDiagnostic,
  validateAtlasStagingProtectedValues,
  validateAtlasStagingTarget,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";
import {
  deployAtlasStaging,
  planAtlasStagingDeployment,
} from "./deploy-atlas-staging.mjs";
import {
  planAtlasStagingVerification,
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
});
