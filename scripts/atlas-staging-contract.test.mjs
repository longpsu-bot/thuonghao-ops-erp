import { existsSync, readdirSync, readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  APPROVED_ATLAS_STAGING_PROJECT_REF,
  ATLAS_STAGING_CERTIFICATION_MODES,
  ATLAS_STAGING_GITHUB_ENVIRONMENT,
  ATLAS_STAGING_IDENTITY_SECRET_NAMES,
  ATLAS_STAGING_SECRET_NAMES,
  ATLAS_STAGING_VARIABLE_NAMES,
  LIVE_OPS_PROJECT_DENYLIST,
  defaultCommandRunner,
  ensureAtlasApiExposure,
  executeAtlasStagingManagementSql,
  localCertificationEnvironment,
  nativeSupabaseCliInvocation,
  redactAtlasStagingDiagnostic,
  repositorySupabaseCliInvocation,
  requireAtlasStagingCertificationMode,
  validateAtlasStagingProtectedValues,
  validateAtlasStagingPackageProtectedValues,
  validateAtlasStagingTarget,
  verifyAtlasApiExposure,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";
import {
  FRONTEND_CERTIFICATION_COMMANDS,
  certifyFrontend,
} from "./certify-frontend.mjs";
import {
  SUPABASE_FULL_INTEGRATION_COMMANDS,
  captureLocalSupabaseFailureDiagnostics,
  certifySupabaseFullIntegration,
} from "./certify-supabase-full-integration.mjs";
import {
  deployAtlasStaging,
  inspectPinnedSupabaseCli,
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

const stagingRef = APPROVED_ATLAS_STAGING_PROJECT_REF;
const commitSha = "a".repeat(40);
const stagingIdentity = JSON.parse(
  readFileSync("supabase/packages/atlas-staging-identity.v1.json", "utf8"),
);
const managedStagingRole = stagingIdentity.role;

function applicationRoleStateAccepted(applicationRoles, { platformOnly }) {
  if (applicationRoles.length === 0) return platformOnly;
  return (
    applicationRoles.length === 1 &&
    applicationRoles[0].role_id === managedStagingRole.role_id &&
    applicationRoles[0].role_code === managedStagingRole.role_code &&
    applicationRoles[0].role_status === "ACTIVE"
  );
}

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

function semanticSupabaseArgs(command, args) {
  return command === "pnpm" && args[0] === "exec" && args[1] === "supabase"
    ? args.slice(2)
    : args;
}

function exactHeadRunCommand({
  head = commitSha,
  ancestor = true,
  worktree = "",
  fetchStatuses = [0, 0],
} = {}) {
  let fetchCount = 0;
  return vi.fn((_command, args) => {
    if (args[0] === "fetch") {
      const status = fetchStatuses[fetchCount] ?? 0;
      fetchCount += 1;
      return { status, stdout: "", stderr: status ? "fetch failed" : "" };
    }
    if (args[0] === "rev-parse") {
      return { status: 0, stdout: `${head}\n`, stderr: "" };
    }
    if (args[0] === "merge-base") {
      return { status: ancestor ? 0 : 1, stdout: "", stderr: "" };
    }
    if (args[0] === "status") {
      return { status: 0, stdout: worktree, stderr: "" };
    }
    return { status: 0, stdout: "", stderr: "" };
  });
}

describe("Atlas staging safety contract", () => {
  it("keeps verifier and installer off the CLI linked-query transport", () => {
    for (const path of [
      "scripts/verify-atlas-staging.mjs",
      "scripts/install-atlas-staging-package.mjs",
    ]) {
      const source = readFileSync(path, "utf8");
      expect(source).not.toContain("supabase link");
      expect(source).not.toContain('"link"');
      expect(source).not.toContain("--linked");
      expect(source).not.toContain("localSupabaseCliPath");
    }
  });

  it("posts SQL to the exact approved Management API endpoint", async () => {
    const accessToken = "synthetic-access-token";
    const target = validateAtlasStagingPackageProtectedValues({
      ...environment({
        ATLAS_STAGING_PROJECT_REF: APPROVED_ATLAS_STAGING_PROJECT_REF,
        VITE_SUPABASE_URL: `https://${APPROVED_ATLAS_STAGING_PROJECT_REF}.supabase.co`,
      }),
      ATLAS_STAGING_DB_PASSWORD: undefined,
    });
    const fetchImpl = vi.fn(async () => ({
      status: 201,
      async text() {
        return '[{"result":"safe"}]';
      },
    }));
    const statement = "select current_database();";

    await expect(
      executeAtlasStagingManagementSql(target, statement, fetchImpl),
    ).resolves.toBe('[{"result":"safe"}]');

    expect(fetchImpl).toHaveBeenCalledOnce();
    const [url, options] = fetchImpl.mock.calls[0];
    expect(url).toBe(
      `https://api.supabase.com/v1/projects/${APPROVED_ATLAS_STAGING_PROJECT_REF}/database/query`,
    );
    expect(options).toMatchObject({
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    });
    expect(JSON.parse(options.body)).toEqual({ query: statement });
  });

  it("reports only a safe Management API status category", async () => {
    const accessToken = "synthetic-access-token-never-surface";
    const statement = "select protected_catalog_value from private_relation;";
    const protectedBody = "protected server response body never surface";
    const target = {
      projectRef: APPROVED_ATLAS_STAGING_PROJECT_REF,
      supabaseUrl: `https://${APPROVED_ATLAS_STAGING_PROJECT_REF}.supabase.co`,
      accessToken,
    };
    const readBody = vi.fn(async () => protectedBody);
    let failure;
    try {
      await executeAtlasStagingManagementSql(target, statement, async () => ({
        status: 403,
        text: readBody,
      }));
    } catch (error) {
      failure = error;
    }
    expect(failure).toBeInstanceOf(Error);
    expect(failure.message).toMatch(/failed safely/i);
    expect(failure.message).toContain("HTTP 403");
    expect(failure.message).not.toContain(accessToken);
    expect(failure.message).not.toContain(statement);
    expect(failure.message).not.toContain(protectedBody);
    expect(failure.message).not.toContain(target.projectRef);
    expect(failure.message).not.toContain(target.supabaseUrl);
    expect(readBody).not.toHaveBeenCalled();
  });

  it("rejects live OPS before issuing a Management API query", async () => {
    const fetchImpl = vi.fn();
    await expect(
      executeAtlasStagingManagementSql(
        {
          projectRef: "qnthofvccilhnefdcxnz",
          supabaseUrl: "https://qnthofvccilhnefdcxnz.supabase.co",
          accessToken: "synthetic-access-token",
        },
        "select 1;",
        fetchImpl,
      ),
    ).rejects.toThrow(/forbidden/i);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

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
    expect(APPROVED_ATLAS_STAGING_PROJECT_REF).toBe("rnzxmxiiqgtdevzregff");
    expect(ATLAS_STAGING_IDENTITY_SECRET_NAMES).toEqual([
      "ATLAS_STAGING_SUPABASE_SECRET_KEY",
    ]);
  });

  it("qualifies package installation to the one approved project", () => {
    const packageEnvironment = environment({
      ATLAS_STAGING_PROJECT_REF: APPROVED_ATLAS_STAGING_PROJECT_REF,
      VITE_SUPABASE_URL: `https://${APPROVED_ATLAS_STAGING_PROJECT_REF}.supabase.co`,
      ATLAS_STAGING_DB_PASSWORD: undefined,
      ATLAS_STAGING_SUPABASE_SECRET_KEY:
        "sb_secret_synthetic_atlas_staging_contract_test",
    });
    expect(
      validateAtlasStagingPackageProtectedValues(packageEnvironment, {
        identity: true,
      }).projectRef,
    ).toBe(APPROVED_ATLAS_STAGING_PROJECT_REF);
    expect(() =>
      validateAtlasStagingPackageProtectedValues(
        environment({
          ATLAS_STAGING_PROJECT_REF: "abcdefghijklmnopqrst",
          VITE_SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co",
        }),
      ),
    ).toThrow(/approved Atlas Staging/i);
  });

  it("omits DB password from verifier/package validation but retains it for deployment", () => {
    const withoutDatabasePassword = environment({
      ATLAS_STAGING_PROJECT_REF: APPROVED_ATLAS_STAGING_PROJECT_REF,
      VITE_SUPABASE_URL: `https://${APPROVED_ATLAS_STAGING_PROJECT_REF}.supabase.co`,
      ATLAS_STAGING_DB_PASSWORD: undefined,
    });
    const verifierPlan = planAtlasStagingVerification(withoutDatabasePassword);
    const packageTarget = validateAtlasStagingPackageProtectedValues(
      withoutDatabasePassword,
    );
    expect(verifierPlan.target).not.toHaveProperty("databasePassword");
    expect(packageTarget).not.toHaveProperty("databasePassword");
    expect(() => planAtlasStagingDeployment(withoutDatabasePassword)).toThrow(
      /ATLAS_STAGING_DB_PASSWORD/,
    );
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

  it("constructs local certification environments from an explicit safe allowlist", () => {
    const safeEnvironment = localCertificationEnvironment({
      Path: "C:\\Windows\\System32",
      USERPROFILE: "C:\\Users\\atlas",
      SystemRoot: "C:\\Windows",
      TEMP: "C:\\Temp",
      APPDATA: "C:\\Users\\atlas\\AppData\\Roaming",
      LOCALAPPDATA: "C:\\Users\\atlas\\AppData\\Local",
      PNPM_HOME: "C:\\pnpm",
      DOCKER_CONTEXT: "desktop-linux",
      LANG: "en_US.UTF-8",
      LC_ALL: "en_US.UTF-8",
      GITHUB_TOKEN: "github-token",
      GH_TOKEN: "gh-token",
      NPM_TOKEN: "npm-token",
      DATABASE_URL: "postgresql://user:password@example.test/database",
      SUPABASE_ACCESS_TOKEN: "supabase-access-token",
      SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
      ATLAS_STAGING_DB_PASSWORD: "staging-password",
      AWS_ACCESS_KEY_ID: "aws-access-key",
      AWS_SECRET_ACCESS_KEY: "aws-secret-key",
      AZURE_CLIENT_SECRET: "azure-secret",
      GOOGLE_APPLICATION_CREDENTIALS: "C:\\credential.json",
    });
    expect(safeEnvironment).toMatchObject({
      Path: "C:\\Windows\\System32",
      USERPROFILE: "C:\\Users\\atlas",
      SystemRoot: "C:\\Windows",
      TEMP: "C:\\Temp",
      APPDATA: "C:\\Users\\atlas\\AppData\\Roaming",
      LOCALAPPDATA: "C:\\Users\\atlas\\AppData\\Local",
      PNPM_HOME: "C:\\pnpm",
      DOCKER_CONTEXT: "desktop-linux",
      LANG: "en_US.UTF-8",
      LC_ALL: "en_US.UTF-8",
      SUPABASE_TELEMETRY_DISABLED: "1",
    });
    for (const name of [
      "GITHUB_TOKEN",
      "GH_TOKEN",
      "NPM_TOKEN",
      "DATABASE_URL",
      "SUPABASE_ACCESS_TOKEN",
      "SUPABASE_SERVICE_ROLE_KEY",
      "ATLAS_STAGING_DB_PASSWORD",
      "AWS_ACCESS_KEY_ID",
      "AWS_SECRET_ACCESS_KEY",
      "AZURE_CLIENT_SECRET",
      "GOOGLE_APPLICATION_CREDENTIALS",
    ]) {
      expect(safeEnvironment).not.toHaveProperty(name);
    }
  });

  it("admits exactly explicit github or local certification", () => {
    expect(ATLAS_STAGING_CERTIFICATION_MODES).toEqual(["github", "local"]);
    expect(requireAtlasStagingCertificationMode("github")).toBe("github");
    expect(requireAtlasStagingCertificationMode("local")).toBe("local");
    for (const value of [undefined, "", "skip", "none", "uncertified"]) {
      expect(() => requireAtlasStagingCertificationMode(value)).toThrow(
        /explicitly selected/i,
      );
    }
    const deploymentSource = readFileSync(
      "scripts/deploy-atlas-staging.mjs",
      "utf8",
    );
    expect(deploymentSource).not.toMatch(/skip.certification/i);
  });

  it("requires exact-head main membership and both exact job certifications", async () => {
    const runCommand = vi.fn((_command, args) => {
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
        certificationMode: "github",
        environment: environment(),
        runCommand,
        fetchImpl,
      }),
    ).resolves.toBe(commitSha);
    expect(runCommand).toHaveBeenCalledTimes(8);
    expect(
      runCommand.mock.calls.every(
        ([command, _args, options]) =>
          command === "git" && options.shell === false,
      ),
    ).toBe(true);
    expect(runCommand.mock.calls.map(([_command, args]) => args)).toEqual([
      ["cat-file", "-e", `${commitSha}^{commit}`],
      ["rev-parse", "HEAD"],
      ["merge-base", "--is-ancestor", commitSha, "origin/main"],
      ["status", "--porcelain"],
      ["cat-file", "-e", `${commitSha}^{commit}`],
      ["rev-parse", "HEAD"],
      ["merge-base", "--is-ancestor", commitSha, "origin/main"],
      ["status", "--porcelain"],
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
        certificationMode: "github",
        environment: environment(),
        runCommand,
        fetchImpl,
      }),
    ).rejects.toThrow(/certification is missing/i);
  });

  it("fails closed when exact-head workflow evidence is missing", async () => {
    const runCommand = (_command, args) => ({
      status: 0,
      stdout: args[0] === "rev-parse" ? `${commitSha}\n` : "",
      stderr: "",
    });
    const fetchImpl = async (url) => ({
      ok: true,
      async json() {
        return url.includes("/runs?") ? { workflow_runs: [] } : { jobs: [] };
      },
    });
    await expect(
      verifyExactHeadCertification({
        commitSha,
        certificationMode: "github",
        environment: environment(),
        runCommand,
        fetchImpl,
      }),
    ).rejects.toThrow(/certification is missing/i);
  });

  it("keeps GitHub mode dependent on built-in workflow context", async () => {
    const runFrontendCertification = vi.fn();
    const runSupabaseCertification = vi.fn();
    await expect(
      verifyExactHeadCertification({
        commitSha,
        certificationMode: "github",
        environment: environment({
          GITHUB_REPOSITORY: undefined,
          GITHUB_TOKEN: undefined,
        }),
        runCommand: exactHeadRunCommand(),
        runFrontendCertification,
        runSupabaseCertification,
      }),
    ).rejects.toThrow(/built-in workflow context/i);
    expect(runFrontendCertification).not.toHaveBeenCalled();
    expect(runSupabaseCertification).not.toHaveBeenCalled();
  });

  it.each([
    ["wrong HEAD", { head: "b".repeat(40) }, /exact commit/i],
    ["commit outside origin/main", { ancestor: false }, /not contained/i],
    ["dirty worktree", { worktree: " M protected-file\n" }, /not clean/i],
  ])(
    "rejects local certification for %s before either suite runs",
    async (_label, gitState, expectedError) => {
      const runFrontendCertification = vi.fn();
      const runSupabaseCertification = vi.fn();
      await expect(
        verifyExactHeadCertification({
          commitSha,
          certificationMode: "local",
          environment: environment(),
          runCommand: exactHeadRunCommand(gitState),
          runFrontendCertification,
          runSupabaseCertification,
        }),
      ).rejects.toThrow(expectedError);
      expect(runFrontendCertification).not.toHaveBeenCalled();
      expect(runSupabaseCertification).not.toHaveBeenCalled();
    },
  );

  it("runs local frontend then Supabase certification and revalidates exact HEAD", async () => {
    const order = [];
    const runCommand = exactHeadRunCommand();
    const certificationEnvironments = [];
    await expect(
      verifyExactHeadCertification({
        commitSha,
        certificationMode: "local",
        environment: environment(),
        runCommand,
        runFrontendCertification: vi.fn(async ({ environment }) => {
          order.push("frontend");
          certificationEnvironments.push(environment);
        }),
        runSupabaseCertification: vi.fn(async ({ environment }) => {
          order.push("supabase");
          certificationEnvironments.push(environment);
        }),
      }),
    ).resolves.toBe(commitSha);
    expect(order).toEqual(["frontend", "supabase"]);
    expect(runCommand).toHaveBeenCalledTimes(10);
    expect(
      runCommand.mock.calls.filter(([_command, args]) => args[0] === "fetch"),
    ).toEqual([
      [
        "git",
        ["fetch", "--no-tags", "origin", "main:refs/remotes/origin/main"],
        expect.objectContaining({ shell: false }),
      ],
      [
        "git",
        ["fetch", "--no-tags", "origin", "main:refs/remotes/origin/main"],
        expect.objectContaining({ shell: false }),
      ],
    ]);
    for (const certificationEnvironment of certificationEnvironments) {
      expect(certificationEnvironment).not.toHaveProperty("GITHUB_TOKEN");
      expect(certificationEnvironment).not.toHaveProperty(
        "ATLAS_STAGING_DB_PASSWORD",
      );
      expect(certificationEnvironment).not.toHaveProperty(
        "ATLAS_STAGING_SUPABASE_ACCESS_TOKEN",
      );
      expect(certificationEnvironment).not.toHaveProperty(
        "VITE_SUPABASE_PUBLISHABLE_KEY",
      );
      expect(certificationEnvironment.SUPABASE_TELEMETRY_DISABLED).toBe("1");
    }
  });

  it.each([
    ["first", [1, 0], 0],
    ["second", [0, 1], 1],
  ])(
    "fails closed when the %s local origin/main fetch fails",
    async (_label, fetchStatuses, expectedSuiteCount) => {
      const runFrontendCertification = vi.fn();
      const runSupabaseCertification = vi.fn();
      await expect(
        verifyExactHeadCertification({
          commitSha,
          certificationMode: "local",
          environment: environment(),
          runCommand: exactHeadRunCommand({ fetchStatuses }),
          runFrontendCertification,
          runSupabaseCertification,
        }),
      ).rejects.toThrow(/origin\/main cannot be fetched/i);
      expect(runFrontendCertification).toHaveBeenCalledTimes(
        expectedSuiteCount,
      );
      expect(runSupabaseCertification).toHaveBeenCalledTimes(
        expectedSuiteCount,
      );
    },
  );

  it("does not fall back to local suites when GitHub evidence fails", async () => {
    const runFrontendCertification = vi.fn();
    const runSupabaseCertification = vi.fn();
    await expect(
      verifyExactHeadCertification({
        commitSha,
        certificationMode: "github",
        environment: environment(),
        runCommand: exactHeadRunCommand(),
        fetchImpl: async (url) => ({
          ok: true,
          async json() {
            return url.includes("/runs?")
              ? { workflow_runs: [] }
              : { jobs: [] };
          },
        }),
        runFrontendCertification,
        runSupabaseCertification,
      }),
    ).rejects.toThrow(/certification is missing/i);
    expect(runFrontendCertification).not.toHaveBeenCalled();
    expect(runSupabaseCertification).not.toHaveBeenCalled();
  });

  it.skipIf(process.platform !== "win32")(
    "passes Windows Git commit-object syntax through the native runner",
    () => {
      const cwd = process.cwd();
      const head = defaultCommandRunner("git", ["rev-parse", "HEAD"], {
        cwd,
        shell: false,
      });
      expect(head.status).toBe(0);

      const result = defaultCommandRunner(
        "git",
        ["cat-file", "-e", `${head.stdout.trim()}^{commit}`],
        { cwd, shell: false },
      );
      expect(result.status).toBe(0);
    },
  );

  it("constructs a Windows-safe pinned Supabase invocation with discrete arguments", () => {
    const args = [
      "db",
      "push",
      "--password",
      "protected value with spaces & metacharacters",
    ];
    const invocation = nativeSupabaseCliInvocation(
      "C:\\Repository With Spaces\\node_modules\\@supabase\\cli-windows-x64\\bin\\supabase.exe",
      args,
    );

    expect(invocation.command).toBe(
      "C:\\Repository With Spaces\\node_modules\\@supabase\\cli-windows-x64\\bin\\supabase.exe",
    );
    expect(invocation.args).toEqual(args);
    expect(invocation.args).not.toBe(args);
    expect(invocation.shell).toBe(false);
  });

  it.skipIf(process.platform !== "win32")(
    "resolves the native Windows executable from version-matched pinned packages",
    () => {
      const invocation = repositorySupabaseCliInvocation(["--version"], {
        cwd: process.cwd(),
      });
      expect(invocation.command).toMatch(
        /@supabase\+cli-windows-x64@2\.111\.0[\\/]node_modules[\\/]@supabase[\\/]cli-windows-x64[\\/]bin[\\/]supabase\.exe$/i,
      );
      expect(invocation).toMatchObject({
        args: ["--version"],
        shell: false,
      });
    },
  );

  it("keeps non-Windows pinned Supabase invocation unchanged", () => {
    expect(
      repositorySupabaseCliInvocation(["stop", "--no-backup"], {
        cwd: "unused path with spaces",
        platform: "linux",
        architecture: "x64",
      }),
    ).toEqual({
      command: "pnpm",
      args: ["exec", "supabase", "stop", "--no-backup"],
      shell: false,
    });
  });
});

describe("Atlas staging dry-run and workflow", () => {
  it("shares the substantive frontend authority in repository order", () => {
    expect(FRONTEND_CERTIFICATION_COMMANDS).toEqual([
      ["install", "--frozen-lockfile"],
      ["format"],
      ["typecheck"],
      ["test"],
      ["build"],
    ]);
    const runCommand = vi.fn((_command, args) => ({
      status: args[0] === "typecheck" ? 1 : 0,
      stdout: "",
      stderr: "",
    }));
    expect(() => certifyFrontend({ runCommand })).toThrow(/typecheck/i);
    expect(runCommand.mock.calls.map(([_command, args]) => args)).toEqual([
      ["install", "--frozen-lockfile"],
      ["format"],
      ["typecheck"],
    ]);
  });

  it("captures bounded redacted Supabase diagnostics before cleanup without replacing the primary failure", () => {
    const calls = [];
    const warning = vi.spyOn(console, "warn").mockImplementation(() => {});
    const expectedVersion = JSON.parse(
      readFileSync(`${process.cwd()}/package.json`, "utf8"),
    ).devDependencies.supabase;
    const runCommand = vi.fn((command, args) => {
      const semanticArgs = semanticSupabaseArgs(command, args);
      calls.push(semanticArgs.join(" "));
      if (semanticArgs.at(-1) === "--help") {
        return {
          status: 0,
          stdout: "--exclude --local --no-seed --file --no-backup",
          stderr: "",
        };
      }
      if (semanticArgs.at(-1) === "--version") {
        return { status: 0, stdout: `${expectedVersion}\n`, stderr: "" };
      }
      if (semanticArgs.includes("reset")) {
        return {
          status: 1,
          stdout: "",
          stderr: "primary certification failure",
        };
      }
      if (semanticArgs[0] === "stop") {
        throw new Error("secondary cleanup failure");
      }
      if (command === "docker" && args[0] === "ps") {
        return {
          status: 0,
          stdout: "supabase_db_thuonghao-ops-erp\n",
          stderr: "",
        };
      }
      if (command === "docker" && args[0] === "logs") {
        return {
          status: 0,
          stdout:
            "postgresql://user:password@database.test/db Bearer synthetic-bearer password=synthetic-password sb_secret_synthetic\n",
          stderr: "",
        };
      }
      return { status: 0, stdout: "", stderr: "" };
    });
    expect(() => certifySupabaseFullIntegration({ runCommand })).toThrow(
      /primary certification failure/i,
    );
    const resetIndex = calls.findIndex((call) => call.includes("db reset"));
    const diagnosticIndex = calls.findIndex((call) =>
      call.startsWith("version "),
    );
    const stopIndex = calls.indexOf("stop --no-backup");
    expect(diagnosticIndex).toBeGreaterThan(resetIndex);
    expect(stopIndex).toBeGreaterThan(diagnosticIndex);
    expect(calls).toContain("stop --no-backup");
    const stopCall = runCommand.mock.calls.find(
      ([command, args]) => semanticSupabaseArgs(command, args)[0] === "stop",
    );
    expect(stopCall?.[2]).toMatchObject({ shell: false });
    if (process.platform === "win32") {
      expect(stopCall?.[0]).toMatch(/[\\/]bin[\\/]supabase\.exe$/i);
    }
    expect(
      calls.some(
        (call) => call.startsWith("test db ") && !call.endsWith("--help"),
      ),
    ).toBe(false);
    expect(calls).toContain("logs --tail 160 supabase_db_thuonghao-ops-erp");
    expect(
      runCommand.mock.calls
        .filter(([command]) => command === "docker")
        .every(([_command, _args, options]) => options.timeout === 10_000),
    ).toBe(true);
    expect(warning.mock.calls.flat().join("\n")).not.toMatch(
      /synthetic-bearer|synthetic-password|sb_secret_synthetic|postgresql:\/\/user:password/i,
    );
    warning.mockRestore();
  });

  it("fails certification when final cleanup alone fails and redacts protected values", () => {
    const protectedValue = "cleanup-protected-value-never-surface";
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    const runCommand = vi.fn((command, args) => {
      const semanticArgs = semanticSupabaseArgs(command, args);
      if (semanticArgs.at(-1) === "--help") {
        return {
          status: 0,
          stdout: "--exclude --local --no-seed --file --no-backup",
          stderr: "",
        };
      }
      if (semanticArgs.at(-1) === "--version") {
        return {
          status: 0,
          stdout: "2.111.0\n",
          stderr: "",
        };
      }
      if (semanticArgs[0] === "stop") {
        return {
          status: 1,
          stdout: "",
          stderr: `cleanup failed ${protectedValue}`,
        };
      }
      return { status: 0, stdout: "", stderr: "" };
    });

    let failure;
    try {
      certifySupabaseFullIntegration({
        environment: { ATLAS_STAGING_DB_PASSWORD: protectedValue },
        runCommand,
      });
    } catch (error) {
      failure = error;
    }
    expect(failure).toBeInstanceOf(Error);
    expect(failure.message).toMatch(/local Supabase cleanup/i);
    expect(failure.message).not.toContain(protectedValue);
    expect(failure.message).toContain("[REDACTED]");
    log.mockRestore();
  });

  it("keeps diagnostic collection failure subordinate to the certification failure", () => {
    const warning = vi.spyOn(console, "warn").mockImplementation(() => {});
    const runCommand = vi.fn((_command, args) => {
      if (args[0] === "version") throw new Error("diagnostics unavailable");
      return { status: 0, stdout: "", stderr: "" };
    });
    expect(() =>
      captureLocalSupabaseFailureDiagnostics({ runCommand }),
    ).not.toThrow();
    warning.mockRestore();
  });

  it("makes both workflows call the shared repository certification entrypoints", () => {
    const frontendWorkflow = readFileSync(
      ".github/workflows/frontend-ci.yml",
      "utf8",
    );
    expect(frontendWorkflow).toContain("pnpm certify:frontend");
    expect(frontendWorkflow).not.toContain("run: pnpm format");
    expect(frontendWorkflow).not.toContain("run: pnpm typecheck");
    expect(frontendWorkflow).not.toContain("run: pnpm test");
    expect(frontendWorkflow).not.toContain("run: pnpm build");

    const supabaseWorkflow = readFileSync(
      ".github/workflows/supabase-integration.yml",
      "utf8",
    );
    const fullIntegration = supabaseWorkflow.slice(
      supabaseWorkflow.indexOf("  full-integration:"),
    );
    expect(fullIntegration).toContain("pnpm certify:supabase:full-integration");
    expect(fullIntegration).not.toContain("supabase test db");
    expect(SUPABASE_FULL_INTEGRATION_COMMANDS).toHaveLength(76);
    expect(
      SUPABASE_FULL_INTEGRATION_COMMANDS.some(({ args }) =>
        args.includes(
          "supabase/tests/pa_05g_backend_end_to_end_acceptance.sql",
        ),
      ),
    ).toBe(true);
    expect(
      SUPABASE_FULL_INTEGRATION_COMMANDS.some(({ args }) =>
        args.includes("local:planning-contract-01:verify"),
      ),
    ).toBe(true);
  });

  it("uses the pinned Supabase CLI without a command shell and stays native on Windows", () => {
    const expectedVersion = JSON.parse(
      readFileSync(`${process.cwd()}/package.json`, "utf8"),
    ).devDependencies.supabase;
    const runCommand = vi.fn((command, args) => {
      const semanticArgs = semanticSupabaseArgs(command, args);
      return {
        status: 0,
        stdout:
          semanticArgs[0] === "--version"
            ? `${expectedVersion}\n`
            : "--project-ref --password --db-url --dry-run --output --agent",
        stderr: "",
      };
    });

    expect(
      inspectPinnedSupabaseCli({
        cwd: process.cwd(),
        environment: {},
        runCommand,
      }),
    ).toBe(expectedVersion);
    expect(
      runCommand.mock.calls.every(
        ([_command, _args, options]) => options.shell === false,
      ),
    ).toBe(true);
    if (process.platform === "win32") {
      expect(runCommand.mock.calls[0][0]).toMatch(
        /@supabase\+cli-windows-x64@2\.111\.0[\\/].*[\\/]bin[\\/]supabase\.exe$/i,
      );
    }
  });

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
        certificationMode: "github",
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

  it("keeps protected deployment fixed to the approved Atlas Staging target", () => {
    expect(() =>
      planAtlasStagingDeployment(
        environment({
          ATLAS_STAGING_PROJECT_REF: "abcdefghijklmnopqrst",
          VITE_SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co",
        }),
      ),
    ).toThrow(/approved Atlas Staging/i);
  });

  it("fails closed when deployment omits the certification selector", async () => {
    await expect(
      deployAtlasStaging({
        commitSha,
        environment: environment(),
        dryRun: true,
      }),
    ).rejects.toThrow(/explicitly selected/i);
  });

  it.each([
    ["frontend", true, false],
    ["Supabase", false, true],
  ])(
    "blocks every hosted mutation when local %s certification fails",
    async (_label, failFrontend, failSupabase) => {
      const runCommand = exactHeadRunCommand();
      const runFrontendCertification = vi.fn(async () => {
        if (failFrontend) throw new Error("frontend failed");
      });
      const runSupabaseCertification = vi.fn(async () => {
        if (failSupabase) throw new Error("Supabase failed");
      });
      const fetchImpl = vi.fn();
      const verifyHosted = vi.fn();

      await expect(
        deployAtlasStaging({
          commitSha,
          certificationMode: "local",
          environment: environment(),
          runCommand,
          fetchImpl,
          verifyHosted,
          runFrontendCertification,
          runSupabaseCertification,
        }),
      ).rejects.toThrow(/failed/i);
      expect(
        runCommand.mock.calls.some(
          ([command, args]) =>
            semanticSupabaseArgs(command, args)[0] === "link",
        ),
      ).toBe(false);
      expect(fetchImpl).not.toHaveBeenCalled();
      expect(verifyHosted).not.toHaveBeenCalled();
      if (failFrontend) expect(runSupabaseCertification).not.toHaveBeenCalled();
    },
  );

  it("blocks every hosted mutation when final local freshness verification fails", async () => {
    const runCommand = exactHeadRunCommand({ fetchStatuses: [0, 1] });
    const fetchImpl = vi.fn();
    const verifyHosted = vi.fn();
    await expect(
      deployAtlasStaging({
        commitSha,
        certificationMode: "local",
        environment: environment(),
        runCommand,
        fetchImpl,
        verifyHosted,
        runFrontendCertification: vi.fn(async () => {}),
        runSupabaseCertification: vi.fn(async () => {}),
      }),
    ).rejects.toThrow(/origin\/main cannot be fetched/i);
    expect(
      runCommand.mock.calls.some(
        ([command, args]) => semanticSupabaseArgs(command, args)[0] === "link",
      ),
    ).toBe(false);
    expect(fetchImpl).not.toHaveBeenCalled();
    expect(verifyHosted).not.toHaveBeenCalled();
  });

  it("returns from both local suites directly into protected deployment", async () => {
    const order = [];
    const expectedVersion = JSON.parse(
      readFileSync(`${process.cwd()}/package.json`, "utf8"),
    ).devDependencies.supabase;
    const runCommand = vi.fn((command, args) => {
      const semanticArgs = semanticSupabaseArgs(command, args);
      if (command === "git") {
        if (args[0] === "rev-parse") {
          return { status: 0, stdout: `${commitSha}\n`, stderr: "" };
        }
        return { status: 0, stdout: "", stderr: "" };
      }
      if (semanticArgs[0] === "--version") {
        return { status: 0, stdout: `${expectedVersion}\n`, stderr: "" };
      }
      if (semanticArgs.at(-1) === "--help") {
        return {
          status: 0,
          stdout:
            "--project-ref --password --db-url --dry-run --output --agent",
          stderr: "",
        };
      }
      if (semanticArgs[0] === "link") order.push("hosted-link");
      if (semanticArgs[0] === "db" && semanticArgs[1] === "push") {
        order.push("hosted-push");
      }
      return { status: 0, stdout: "", stderr: "" };
    });
    const fetchImpl = vi.fn(async () => {
      order.push("hosted-exposure-read");
      return {
        ok: true,
        async json() {
          return { db_schema: "public,atlas_api" };
        },
      };
    });

    await expect(
      deployAtlasStaging({
        commitSha,
        certificationMode: "local",
        environment: environment(),
        runCommand,
        fetchImpl,
        runFrontendCertification: vi.fn(async () => order.push("frontend")),
        runSupabaseCertification: vi.fn(async () => order.push("supabase")),
        verifyHosted: vi.fn(async () => order.push("hosted-verify")),
      }),
    ).resolves.toMatchObject({ status: "deployed" });
    expect(order).toEqual([
      "frontend",
      "supabase",
      "hosted-link",
      "hosted-push",
      "hosted-exposure-read",
      "hosted-verify",
    ]);
    const hostedCliCalls = runCommand.mock.calls.filter(([command, args]) => {
      const semanticArgs = semanticSupabaseArgs(command, args);
      return (
        !semanticArgs.includes("--help") &&
        (semanticArgs[0] === "link" ||
          (semanticArgs[0] === "db" && semanticArgs[1] === "push"))
      );
    });
    expect(hostedCliCalls).toHaveLength(2);
    expect(
      hostedCliCalls.every(
        ([_command, _args, options]) => options.shell === false,
      ),
    ).toBe(true);
    if (process.platform === "win32") {
      expect(
        hostedCliCalls.every(([command]) =>
          /[\\/]bin[\\/]supabase\.exe$/i.test(command),
        ),
      ).toBe(true);
    }
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

  it("keeps Identity installation manual, protected, exact-head, and package-owned", () => {
    const workflowPath = ".github/workflows/atlas-staging-identity-install.yml";
    expect(existsSync(workflowPath)).toBe(true);
    if (!existsSync(workflowPath)) return;

    const workflow = readFileSync(workflowPath, "utf8");
    const lines = workflow.split(/\r?\n/).map((line) => line.trim());
    const dryRunCommand =
      'run: pnpm atlas:staging:identity:install -- --commit-sha "${{ inputs.commit_sha }}" --dry-run';
    const installCommand =
      'run: pnpm atlas:staging:identity:install -- --commit-sha "${{ inputs.commit_sha }}"';
    const verifyCommand = "run: pnpm atlas:staging:verify";

    expect(workflow).toMatch(/on:\s*\n\s*workflow_dispatch:/);
    expect(workflow).not.toMatch(/\n\s+(push|pull_request|schedule|release):/);
    expect(workflow).toMatch(
      /workflow_dispatch:\s*\n\s*inputs:\s*\n\s*commit_sha:\s*\n(?:\s+.*\n)*?\s+required: true/,
    );
    expect(workflow).toMatch(
      /commit_sha:\s*\n\s+description: Exact full merged-main SHA/,
    );
    expect(workflow).toContain("environment: atlas-staging");
    expect(workflow).toMatch(/permissions:\s*\n\s+contents: read\s*\n/);
    expect(workflow).not.toMatch(/permissions:[\s\S]*\bwrite\b/);
    expect(workflow).toContain("ref: ${{ inputs.commit_sha }}");
    expect(workflow).toContain("fetch-depth: 0");
    expect(workflow).toContain(
      "git fetch --no-tags origin main:refs/remotes/origin/main",
    );
    expect(workflow).toContain("version: 11.7.0");
    expect(workflow).toContain("node-version: 24");
    expect(workflow).toContain("pnpm install --frozen-lockfile");

    const dryRunIndex = lines.indexOf(dryRunCommand);
    const installIndex = lines.indexOf(installCommand);
    const verifyIndex = lines.indexOf(verifyCommand);
    expect(dryRunIndex).toBeGreaterThan(-1);
    expect(installIndex).toBeGreaterThan(dryRunIndex);
    expect(verifyIndex).toBeGreaterThan(installIndex);
    expect(lines.filter((line) => line === installCommand)).toHaveLength(1);

    for (const variableName of [
      "ATLAS_STAGING_PROJECT_REF",
      "VITE_ATLAS_ENVIRONMENT",
      "VITE_SUPABASE_URL",
      "VITE_SUPABASE_PUBLISHABLE_KEY",
      "ATLAS_STAGING_TEST_EMAIL",
    ]) {
      expect(workflow).toContain(
        `${variableName}: \${{ vars.${variableName} }}`,
      );
    }
    for (const secretName of [
      "ATLAS_STAGING_SUPABASE_ACCESS_TOKEN",
      "ATLAS_STAGING_TEST_PASSWORD",
      "ATLAS_STAGING_SUPABASE_SECRET_KEY",
    ]) {
      expect(workflow).toContain(
        `${secretName}: \${{ secrets.${secretName} }}`,
      );
    }
    expect(workflow).not.toContain("ATLAS_STAGING_DB_PASSWORD");
    expect(workflow).not.toContain("supabase db push");
    expect(workflow).not.toContain("atlas:staging:deploy");
    expect(workflow).not.toContain("atlas:staging:foundation:install");
    expect(workflow).not.toMatch(
      /qnthofvccilhnefdcxnz|live[ -]ops|production/i,
    );
    expect(workflow).not.toMatch(/\bpsql\b|supabase db query|\.sql\b/i);
    expect(workflow).not.toContain("install-atlas-staging-package.mjs");
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
      ".github/workflows/atlas-staging-identity-install.yml",
      "scripts/atlas-staging-contract.mjs",
      "scripts/atlas-staging-contract.test.mjs",
      "scripts/deploy-atlas-staging.mjs",
      "scripts/certify-frontend.mjs",
      "scripts/certify-supabase-full-integration.mjs",
      "scripts/verify-atlas-staging.mjs",
      "scripts/install-atlas-staging-package.mjs",
      "scripts/install-local-foundation-need-generation-contract.mjs",
      "scripts/certify-local-atlas-staging-packages.mjs",
      "scripts/atlas-staging-package.test.mjs",
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
  it("keeps platform-only verification package-aware without requiring package or Auth checks", async () => {
    const sqlCalls = [];
    const migrationVersions = readdirSync("supabase/migrations")
      .filter((name) => name.endsWith(".sql"))
      .map((name) => name.slice(0, 14))
      .sort();
    const endpoint = `https://api.supabase.com/v1/projects/${APPROVED_ATLAS_STAGING_PROJECT_REF}/database/query`;
    const fetchImpl = vi.fn(async (url, options = {}) => {
      if (url === endpoint) {
        const statement = JSON.parse(options.body).query;
        sqlCalls.push(statement);
        const result = statement.includes("ATLAS_MIGRATION_HISTORY=")
          ? `ATLAS_MIGRATION_HISTORY=${JSON.stringify({
              versions: migrationVersions,
              row_count: migrationVersions.length,
            })}`
          : "safe";
        return {
          ok: true,
          status: 201,
          async text() {
            return JSON.stringify([{ result }]);
          },
        };
      }
      return {
        ok: true,
        status: 200,
        async json() {
          return String(url).includes("/postgrest")
            ? { db_schema: "public,atlas_api" }
            : {};
        },
      };
    });
    const createClientFactory = vi.fn(() => ({
      schema: () => ({
        rpc: () => ({
          retry: async () => ({
            error: {
              code: "42501",
              message: "permission denied for schema atlas_api",
            },
          }),
        }),
      }),
    }));

    await expect(
      verifyAtlasStaging({
        environment: environment({ ATLAS_STAGING_DB_PASSWORD: undefined }),
        fetchImpl,
        createClientFactory,
        platformOnly: true,
      }),
    ).resolves.toEqual({ status: "verified", phase: "platform" });

    expect(sqlCalls).toHaveLength(2);
    expect(sqlCalls[1]).toContain(managedStagingRole.role_id);
    expect(sqlCalls[1]).toContain(managedStagingRole.role_code);
    expect(sqlCalls[1]).toContain("role_status = 'ACTIVE'");
    expect(sqlCalls[1]).not.toContain("ATLAS_STAGING_IDENTITY");
    expect(sqlCalls[1]).not.toContain("ATLAS_STAGING_FOUNDATION");
    expect(createClientFactory).toHaveBeenCalledOnce();
  });

  it("posts every verifier SQL statement to the approved Management API endpoint", async () => {
    const sqlCalls = [];
    const migrationVersions = readdirSync("supabase/migrations")
      .filter((name) => name.endsWith(".sql"))
      .map((name) => name.slice(0, 14))
      .sort();
    const runCommand = vi.fn();
    const endpoint = `https://api.supabase.com/v1/projects/${APPROVED_ATLAS_STAGING_PROJECT_REF}/database/query`;
    const fetchImpl = vi.fn(async (url, options = {}) => {
      if (url === endpoint) {
        const body = JSON.parse(options.body);
        sqlCalls.push({ url, options, statement: body.query });
        const result = body.query.includes("ATLAS_MIGRATION_HISTORY=")
          ? `ATLAS_MIGRATION_HISTORY=${JSON.stringify({
              versions: migrationVersions,
              row_count: migrationVersions.length,
            })}`
          : "safe";
        return {
          ok: true,
          status: 201,
          async text() {
            return JSON.stringify([{ result }]);
          },
        };
      }
      return {
        ok: true,
        status: 200,
        async json() {
          return String(url).includes("/postgrest")
            ? { db_schema: "public,atlas_api" }
            : {};
        },
      };
    });
    const authSubject = "11111111-1111-4111-8111-111111111111";
    let clientCount = 0;
    const createClientFactory = vi.fn(() => {
      clientCount += 1;
      if (clientCount === 1) {
        return {
          schema: () => ({
            rpc: () => ({
              retry: async () => ({
                error: {
                  code: "42501",
                  message: "permission denied for schema atlas_api",
                },
              }),
            }),
          }),
        };
      }
      return {
        auth: {
          signInWithPassword: async () => ({
            data: { session: { user: { id: authSubject } } },
            error: null,
          }),
          signOut: async () => ({ error: null }),
          getSession: async () => ({
            data: { session: null },
            error: null,
          }),
        },
        schema: () => ({
          rpc: () => ({
            retry: async () => ({
              data: { success: true, schools: [{}] },
              error: null,
            }),
          }),
        }),
      };
    });

    await expect(
      verifyAtlasStaging({
        environment: environment({
          ATLAS_STAGING_PROJECT_REF: APPROVED_ATLAS_STAGING_PROJECT_REF,
          VITE_SUPABASE_URL: `https://${APPROVED_ATLAS_STAGING_PROJECT_REF}.supabase.co`,
          ATLAS_STAGING_DB_PASSWORD: undefined,
        }),
        runCommand,
        fetchImpl,
        createClientFactory,
      }),
    ).resolves.toEqual({ status: "verified", phase: "acceptance" });

    expect(runCommand).not.toHaveBeenCalled();
    expect(sqlCalls).toHaveLength(4);
    for (const { url, options, statement } of sqlCalls) {
      expect(url).toBe(endpoint);
      expect(options.method).toBe("POST");
      expect(options.headers.Authorization).toBe(
        "Bearer synthetic-access-token",
      );
      expect(JSON.parse(options.body)).toEqual({ query: statement });
    }
    expect(sqlCalls.map(({ statement }) => statement)).toEqual([
      expect.stringContaining("ATLAS_MIGRATION_HISTORY="),
      expect.stringContaining("ATLAS_CATALOG_SCHEMA_MISMATCH"),
      expect.stringContaining("ATLAS_STAGING_IDENTITY"),
      expect.stringContaining("ATLAS_ACTIVE_ACTOR_MAPPING_MISMATCH"),
    ]);
    expect(sqlCalls[2].statement).toContain("ATLAS_STAGING_FOUNDATION");
    expect(sqlCalls[1].statement).toContain(managedStagingRole.role_id);
    expect(sqlCalls[1].statement).toContain(managedStagingRole.role_code);
    expect(sqlCalls[1].statement).toContain(
      "(select count(*) from atlas_core.roles) <> 1",
    );
  });

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
    ).toThrow(/Management API JSON response/i);
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
    expect(authority.apiSignatures).toHaveLength(96);
    expect(authority.apiOwners).toHaveLength(96);
    expect(authority.policyCount).toBe(631);
    expect(authority.policyDigest).toBe("574fed4f090d1fb9605b17f3c9ba8e88");
  });

  it.each([
    ["zero application roles", [], true],
    [
      "the governed active application role",
      [
        {
          role_id: managedStagingRole.role_id,
          role_code: managedStagingRole.role_code,
          role_status: "ACTIVE",
        },
      ],
      true,
    ],
    [
      "an unexpected application role",
      [
        {
          role_id: "b2020000-0000-4000-8000-000000000003",
          role_code: "unexpected_role",
          role_status: "ACTIVE",
        },
      ],
      false,
    ],
    [
      "multiple application roles",
      [
        {
          role_id: managedStagingRole.role_id,
          role_code: managedStagingRole.role_code,
          role_status: "ACTIVE",
        },
        {
          role_id: "b2020000-0000-4000-8000-000000000003",
          role_code: "additional_role",
          role_status: "ACTIVE",
        },
      ],
      false,
    ],
    [
      "the inactive governed application role",
      [
        {
          role_id: managedStagingRole.role_id,
          role_code: managedStagingRole.role_code,
          role_status: "INACTIVE",
        },
      ],
      false,
    ],
  ])("models platform-only + %s", (_label, roles, accepted) => {
    expect(applicationRoleStateAccepted(roles, { platformOnly: true })).toBe(
      accepted,
    );
  });

  it("makes only the exact managed role optional in platform-only catalog SQL", () => {
    const platformSql = catalogVerificationSql(readCatalogAuthority(), {
      managedApplicationRole: managedStagingRole,
      allowMissingManagedApplicationRole: true,
    });
    expect(platformSql).toContain(
      "(select count(*) from atlas_core.roles) > 1",
    );
    expect(platformSql).toContain(
      "(select count(*) from atlas_core.roles) = 1 and not exists",
    );
    expect(platformSql).toContain(
      `role_id = '${managedStagingRole.role_id}'::uuid`,
    );
    expect(platformSql).toContain(
      `role_code = '${managedStagingRole.role_code}'`,
    );
    expect(platformSql).toContain("role_status = 'ACTIVE'");

    const fullSql = catalogVerificationSql(readCatalogAuthority(), {
      managedApplicationRole: managedStagingRole,
    });
    expect(fullSql).toContain("(select count(*) from atlas_core.roles) <> 1");
    expect(applicationRoleStateAccepted([], { platformOnly: false })).toBe(
      false,
    );
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
    expect(sql).toContain("normal_policy_count <> 631");
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
    [631, 1, true],
    [631, 0, false],
    [631, 2, false],
    [630, 1, false],
    [632, 1, false],
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
