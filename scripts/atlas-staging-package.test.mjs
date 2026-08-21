import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  IDENTITY_CAPABILITY_CODES,
  buildFoundationPackageSql,
  buildFoundationVerificationSql,
  buildIdentityPackageSql,
  buildIdentityVerificationSql,
  installAtlasStagingPackage,
  planAtlasStagingPackage,
  readAtlasStagingPackage,
  reconcileManagedAuthUser,
  validatePackageManifest,
  verifyPackageCheckout,
} from "./install-atlas-staging-package.mjs";

const approvedRef = "rnzxmxiiqgtdevzregff";
const commitSha = "b".repeat(40);

function environment(overrides = {}) {
  return {
    ATLAS_STAGING_PROJECT_REF: approvedRef,
    VITE_ATLAS_ENVIRONMENT: "staging",
    VITE_SUPABASE_URL: `https://${approvedRef}.supabase.co`,
    VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_atlas_staging_package_test",
    ATLAS_STAGING_TEST_EMAIL: "atlas.staging@example.test",
    ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-access-token",
    ATLAS_STAGING_DB_PASSWORD: "synthetic-database-password",
    ATLAS_STAGING_TEST_PASSWORD: "synthetic-test-password",
    ATLAS_STAGING_SUPABASE_SECRET_KEY:
      "sb_secret_synthetic_atlas_staging_package_test_value",
    ...overrides,
  };
}

describe("Atlas Staging packages", () => {
  it("freezes the exact minimal Identity and Foundation manifests", () => {
    const identity = readAtlasStagingPackage("identity");
    const foundation = readAtlasStagingPackage("foundation");
    expect(
      identity.role.capabilities.map((item) => item.capability_code),
    ).toEqual(IDENTITY_CAPABILITY_CODES);
    expect(identity.scopes).toEqual([
      expect.objectContaining({ scope_kind: "GLOBAL" }),
    ]);
    expect(foundation.pantry_purposes.map((item) => item.purpose_code)).toEqual(
      ["school_requested_supplement", "planning_identified_supplement"],
    );
    expect(foundation.unit).toMatchObject({
      unit_code: "kg",
      dimension_code: "MASS",
    });
    expect(foundation.planning_quantity_policy.planning_step).toBe("0.010000");
  });

  it("contains secret names but no credential values in either manifest", () => {
    for (const path of [
      "supabase/packages/atlas-staging-identity.v1.json",
      "supabase/packages/atlas-staging-foundation.v1.json",
    ]) {
      const source = readFileSync(path, "utf8");
      expect(source).not.toMatch(/sb_secret_|service_role|eyJ[A-Za-z0-9_-]+\./);
      expect(source).not.toMatch(/"(?:password|token|secret)"\s*:/i);
    }
  });

  it("rejects capability expansion, extra Pantry purposes, and target drift", () => {
    const identity = structuredClone(readAtlasStagingPackage("identity"));
    identity.role.capabilities[0].capability_code =
      "master_data.recipes.import";
    expect(() => validatePackageManifest("identity", identity)).toThrow(
      /minimal set/i,
    );

    const foundation = structuredClone(readAtlasStagingPackage("foundation"));
    foundation.pantry_purposes.push(foundation.pantry_purposes[0]);
    expect(() => validatePackageManifest("foundation", foundation)).toThrow(
      /exactly the two/i,
    );
    expect(() =>
      planAtlasStagingPackage({
        kind: "foundation",
        environment: environment({
          ATLAS_STAGING_PROJECT_REF: "abcdefghijklmnopqrst",
          VITE_SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co",
        }),
      }),
    ).toThrow(/approved Atlas Staging/i);
  });

  it.each([
    {
      ATLAS_STAGING_PROJECT_REF: "qnthofvccilhnefdcxnz",
      VITE_SUPABASE_URL: "https://qnthofvccilhnefdcxnz.supabase.co",
    },
    {
      VITE_SUPABASE_URL: "http://127.0.0.1:54321",
    },
    {
      ATLAS_STAGING_PROJECT_REF: "malformed",
      VITE_SUPABASE_URL: "https://malformed.supabase.co",
    },
  ])("rejects live OPS, local, and malformed package targets", (overrides) => {
    expect(() =>
      planAtlasStagingPackage({
        kind: "foundation",
        environment: environment(overrides),
      }),
    ).toThrow();
  });

  it("builds insert-only, fail-closed Identity reconciliation and verification SQL", () => {
    const manifest = readAtlasStagingPackage("identity");
    const sql = buildIdentityPackageSql(manifest);
    const verification = buildIdentityVerificationSql(manifest);
    for (const capability of IDENTITY_CAPABILITY_CODES) {
      expect(sql).toContain(capability);
    }
    expect(sql).toContain("ATLAS_STAGING_IDENTITY_EXACT_STATE_MISMATCH");
    expect(sql).not.toMatch(/insert into atlas_core\.capabilities/i);
    expect(sql).not.toMatch(/\b(delete|truncate|update)\b/i);
    expect(verification).toContain(
      "ATLAS_STAGING_IDENTITY_CAPABILITY_VERIFICATION_MISMATCH",
    );
  });

  it("builds bounded Foundation reconciliation without rehearsal facts", () => {
    const manifest = readAtlasStagingPackage("foundation");
    const sql = buildFoundationPackageSql(manifest);
    const verification = buildFoundationVerificationSql(manifest);
    expect(sql).toContain("atlas_admin.customers");
    expect(sql).toContain("atlas_admin.schools");
    expect(sql).toContain("atlas_planning.pantry_need_purposes");
    expect(sql).toContain("atlas_planning.planning_quantity_policy_revisions");
    expect(sql).not.toMatch(/\b(delete|truncate)\b/i);
    expect(sql.match(/\bupdate\b/gi)).toHaveLength(1);
    expect(sql).toMatch(
      /insert into atlas_planning\.planning_quantity_policy_revisions[\s\S]+?'DRAFT'/i,
    );
    expect(sql).toMatch(
      /update atlas_planning\.planning_quantity_policy_revisions\s+set policy_revision_status = 'ACTIVE'/i,
    );
    expect(sql).not.toMatch(
      /insert into atlas_admin\.(ingredients|suppliers|dishes|recipes)/i,
    );
    expect(sql).not.toMatch(
      /insert into atlas_planning\.(weekly_menus|attendance_batches|pantry_need_batches|need_generation_runs|confirmed_need_batches)/i,
    );
    expect(verification).toContain(
      "ATLAS_STAGING_FOUNDATION_VERIFICATION_MISMATCH",
    );
  });

  it("reconciles the deterministic Auth user on first install and replay", async () => {
    const manifest = readAtlasStagingPackage("identity");
    const createUser = vi.fn(async (attributes) => ({
      data: { user: { id: attributes.id } },
      error: null,
    }));
    const updateUserById = vi.fn(async (id) => ({
      data: { user: { id } },
      error: null,
    }));
    let users = [];
    const factory = () => ({
      auth: {
        admin: {
          listUsers: vi.fn(async () => ({ data: { users }, error: null })),
          createUser,
          updateUserById,
        },
      },
    });
    const inputs = {
      manifest,
      email: "atlas.staging@example.test",
      password: "synthetic-test-password",
      supabaseUrl: `https://${approvedRef}.supabase.co`,
      secretKey: "sb_secret_synthetic_test_value",
      createClientFactory: factory,
    };
    await expect(reconcileManagedAuthUser(inputs)).resolves.toMatchObject({
      replay: false,
    });
    users = [
      {
        id: manifest.auth_user.auth_subject_id,
        email: "atlas.staging@example.test",
      },
    ];
    await expect(reconcileManagedAuthUser(inputs)).resolves.toMatchObject({
      replay: true,
    });
    expect(createUser).toHaveBeenCalledOnce();
    expect(updateUserById).toHaveBeenCalledOnce();
  });

  it("fails closed on an Auth natural-key conflict", async () => {
    const manifest = readAtlasStagingPackage("identity");
    const factory = () => ({
      auth: {
        admin: {
          listUsers: vi.fn(async () => ({
            data: {
              users: [
                {
                  id: "c0000000-0000-4000-8000-000000000001",
                  email: "atlas.staging@example.test",
                },
              ],
            },
            error: null,
          })),
        },
      },
    });
    await expect(
      reconcileManagedAuthUser({
        manifest,
        email: "atlas.staging@example.test",
        password: "synthetic-test-password",
        supabaseUrl: `https://${approvedRef}.supabase.co`,
        secretKey: "sb_secret_synthetic_test_value",
        createClientFactory: factory,
      }),
    ).rejects.toThrow(/conflicts/i);
  });

  it("requires exact merged-main checkout and a clean tree", () => {
    const successfulRunner = vi.fn((_command, args) => {
      if (args[0] === "rev-parse")
        return { status: 0, stdout: `${commitSha}\n` };
      return { status: 0, stdout: "" };
    });
    expect(
      verifyPackageCheckout({ commitSha, runCommand: successfulRunner }),
    ).toBe(commitSha);
    const dirtyRunner = vi.fn((_command, args) => {
      if (args[0] === "rev-parse")
        return { status: 0, stdout: `${commitSha}\n` };
      if (args[0] === "status")
        return { status: 0, stdout: " M package.json\n" };
      return { status: 0, stdout: "" };
    });
    expect(() =>
      verifyPackageCheckout({ commitSha, runCommand: dirtyRunner }),
    ).toThrow(/not clean/i);
  });

  it("dry-runs without process, Auth, or network execution", async () => {
    const runCommand = vi.fn();
    const createClientFactory = vi.fn();
    await expect(
      installAtlasStagingPackage({
        kind: "identity",
        commitSha,
        environment: environment(),
        runCommand,
        createClientFactory,
        dryRun: true,
      }),
    ).resolves.toMatchObject({
      status: "dry-run",
      plan: {
        packageName: "atlas-staging-identity",
        mutatesHostedState: true,
        deploysMigrations: false,
        installsRehearsalFacts: false,
      },
    });
    expect(runCommand).not.toHaveBeenCalled();
    expect(createClientFactory).not.toHaveBeenCalled();
  });

  it("executes reconciliation and verification as separate Management API queries", async () => {
    const managementSql = [];
    const runCommand = vi.fn((_command, args) => {
      return {
        status: 0,
        stdout: args[0] === "rev-parse" ? `${commitSha}\n` : "",
      };
    });
    const endpoint = `https://api.supabase.com/v1/projects/${approvedRef}/database/query`;
    const fetchImpl = vi.fn(async (url, options) => {
      managementSql.push(JSON.parse(options.body).query);
      return {
        status: 201,
        async text() {
          return "[]";
        },
      };
    });
    await expect(
      installAtlasStagingPackage({
        kind: "foundation",
        commitSha,
        environment: environment({ ATLAS_STAGING_DB_PASSWORD: undefined }),
        runCommand,
        fetchImpl,
      }),
    ).resolves.toMatchObject({ status: "installed" });
    expect(fetchImpl).toHaveBeenCalledTimes(2);
    for (const [url, options] of fetchImpl.mock.calls) {
      expect(url).toBe(endpoint);
      expect(options.method).toBe("POST");
      expect(options.headers.Authorization).toBe(
        "Bearer synthetic-access-token",
      );
    }
    expect(managementSql[0]).toContain("$atlas_staging_foundation$");
    expect(managementSql[1]).toContain("$atlas_staging_foundation_verify$");
    expect(
      runCommand.mock.calls.some(
        ([command, args]) =>
          command.includes("supabase") ||
          args.includes("link") ||
          args.includes("--linked"),
      ),
    ).toBe(false);
  });
});
