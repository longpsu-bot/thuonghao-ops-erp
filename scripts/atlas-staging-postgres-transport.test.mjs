// @vitest-environment node
import { describe, it, expect } from "vitest";
import {
  executeAtlasStagingPostgres,
  validatedStagingPoolerUrl,
} from "./atlas-staging-postgres-transport.mjs";
const ref = "rnzxmxiiqgtdevzregff";
const target = { projectRef: ref, supabaseUrl: `https://${ref}.supabase.co` };
const pooler = `postgresql://postgres.${ref}@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres`;
const environment = {
  ATLAS_STAGING_DB_PASSWORD: "synthetic-db-secret",
  ATLAS_STAGING_CA_BUNDLE: "/tmp/ca.pem",
};
const readLinkedFile = (path) => (path.endsWith("project-ref") ? ref : pooler);
describe("large snapshot Postgres transport", () => {
  it("pins the project and session pooler, removes credentials and rejects query overrides", () => {
    expect(validatedStagingPoolerUrl(pooler, ref)).toContain(":5432/postgres");
    for (const uri of [
      pooler.replace(ref, "wrong"),
      pooler.replace("pooler.supabase.com", "evil.example"),
      pooler.replace(":5432", ":6543"),
      pooler + "?host=evil.example",
    ])
      expect(() => validatedStagingPoolerUrl(uri, ref)).toThrow(/POOLER/);
    expect(() =>
      validatedStagingPoolerUrl(pooler, "qnthofvccilhnefdcxnz"),
    ).toThrow(/STAGING/);
  });
  it("streams an over-limit SQL snapshot through stdin with strict TLS and no secret arguments", async () => {
    const sql = "select '" + "x".repeat(3 * 1024 * 1024) + "';";
    let call;
    const out = await executeAtlasStagingPostgres(target, sql, {
      environment,
      readLinkedFile,
      run: (command, args, opts) => {
        call = { command, args, opts };
        return {
          status: 0,
          stdout: '{"success":true,"status":"PREVIEW"}\n',
          stderr: "",
        };
      },
    });
    expect(JSON.parse(out)[0].result.success).toBe(true);
    expect(call.command).toBe("psql");
    expect(call.opts.input).toBe(sql);
    expect(call.opts.shell).toBe(false);
    expect(call.opts.env.PGSSLMODE).toBe("verify-full");
    expect(call.opts.env.PGSSLROOTCERT).toBe("/tmp/ca.pem");
    expect(call.opts.env.PGPASSWORD).toBe("synthetic-db-secret");
    expect(call.args).toContain("ON_ERROR_STOP=1");
    expect(call.args).toContain("VERBOSITY=sqlstate");
    expect(call.args).toContain("--no-password");
    expect(JSON.stringify(call.args)).not.toContain("synthetic-db-secret");
    expect(JSON.stringify(call.args)).not.toContain(sql);
    expect(call.opts.env.PGCONNECT_TIMEOUT).toBe("20");
    expect(call.opts.timeout).toBe(20 * 60 * 1000);
    expect(call.opts.maxBuffer).toBe(32 * 1024 * 1024);
  });
  it("refuses missing credentials, mismatched links and live OPS before executing psql", async () => {
    let calls = 0;
    const run = () => {
      calls++;
      return { status: 0, stdout: "{}" };
    };
    await expect(
      executeAtlasStagingPostgres(target, "select 1", {
        environment: {},
        readLinkedFile,
        run,
      }),
    ).rejects.toThrow(/CREDENTIAL/);
    await expect(
      executeAtlasStagingPostgres(target, "select 1", {
        environment,
        readLinkedFile: () => "wrong",
        run,
      }),
    ).rejects.toThrow(/LINK/);
    await expect(
      executeAtlasStagingPostgres(
        {
          projectRef: "qnthofvccilhnefdcxnz",
          supabaseUrl: "https://qnthofvccilhnefdcxnz.supabase.co",
        },
        "select 1",
        { environment, readLinkedFile, run },
      ),
    ).rejects.toThrow();
    expect(calls).toBe(0);
  });
  it("does not expose psql error text or retry an unknown execution outcome", async () => {
    let calls = 0;
    await expect(
      executeAtlasStagingPostgres(target, "select 1", {
        environment,
        readLinkedFile,
        run: () => {
          calls++;
          return {
            status: 1,
            stdout: "raw source",
            stderr: "synthetic-db-secret raw source",
          };
        },
      }),
    ).rejects.toThrow("STAGING_POSTGRES_EXECUTION_FAILED");
    expect(calls).toBe(1);
  });
});

describe("safe PostgreSQL failure classification", () => {
  it.each([
    ["ERROR:  57014\n", "STAGING_POSTGRES_SQLSTATE_57014"],
    ["FATAL:  53300\n", "STAGING_POSTGRES_SQLSTATE_53300"],
    ["psql:<stdin>:12: ERROR:  42P01\n", "STAGING_POSTGRES_SQLSTATE_42P01"],
    [
      "ERROR:  23505: synthetic-db-secret raw source\nDETAIL: private SQL",
      "STAGING_POSTGRES_SQLSTATE_23505",
    ],
    [
      "psql: error: connection to server failed: timeout expired",
      "STAGING_POSTGRES_CONNECTION_TIMED_OUT",
    ],
    [
      "psql: error: server closed the connection unexpectedly",
      "STAGING_POSTGRES_CONNECTION_CLOSED",
    ],
    [
      "psql: error: connection failed: FATAL: sorry, too many clients already",
      "STAGING_POSTGRES_TOO_MANY_CLIENTS",
    ],
    ["ERROR:  abcde\n", "STAGING_POSTGRES_EXECUTION_FAILED"],
    ["ERROR:  123456\n", "STAGING_POSTGRES_EXECUTION_FAILED"],
    ["DETAIL: source value ERROR:  57014", "STAGING_POSTGRES_EXECUTION_FAILED"],
    ["synthetic-db-secret raw source", "STAGING_POSTGRES_EXECUTION_FAILED"],
  ])("returns only the safe code for %s", async (stderr, code) => {
    let calls = 0;
    const outcome = await executeAtlasStagingPostgres(
      target,
      "select 'private SQL'",
      {
        environment,
        readLinkedFile,
        run: () => {
          calls++;
          return { status: 1, stderr, stdout: "private source payload" };
        },
      },
    ).catch((error) => error);
    expect(outcome).toBeInstanceOf(Error);
    expect(outcome.message).toBe(code);
    expect(outcome.cause).toBeUndefined();
    expect(outcome.message).not.toMatch(
      /synthetic-db-secret|private|raw source/,
    );
    expect(calls).toBe(1);
  });

  it("keeps process timeout precedence over a server SQLSTATE", async () => {
    await expect(
      executeAtlasStagingPostgres(target, "select 1", {
        environment,
        readLinkedFile,
        run: () => ({
          status: null,
          error: { code: "ETIMEDOUT" },
          stderr: "ERROR:  57014",
        }),
      }),
    ).rejects.toThrow("STAGING_POSTGRES_EXECUTION_TIMED_OUT");
  });
});

describe("allowlisted PostgreSQL phase diagnostics", () => {
  const stderr = [
    "CATCHUP_CLIENT_SCRIPT_BEGIN",
    "CATCHUP_CLIENT_SETTINGS_DONE",
    "CATCHUP_CLIENT_HELPERS_DONE",
    "CATCHUP_CLIENT_QUERY_BEGIN",
    "NOTICE:  PZ001",
    "psql:<stdin>:123: NOTICE:  PZ002",
    "NOTICE:  PZ003",
    "NOTICE:  PZ004",
    "NOTICE:  PZ005",
    "NOTICE:  PZ006",
    "CATCHUP_CLIENT_QUERY_DONE",
  ].join("\r\n");
  const expected = [
    "CATCHUP_CLIENT_SCRIPT_BEGIN",
    "CATCHUP_CLIENT_SETTINGS_DONE",
    "CATCHUP_CLIENT_HELPERS_DONE",
    "CATCHUP_CLIENT_QUERY_BEGIN",
    "CATCHUP_SERVER_ENTRY",
    "CATCHUP_SERVER_SOURCE_CHECKED",
    "CATCHUP_SERVER_RECIPE_PLAN_DONE",
    "CATCHUP_SERVER_PROTECTED_DONE",
    "CATCHUP_SERVER_MAPPING_HASH_DONE",
    "CATCHUP_SERVER_PLAN_HASH_DONE",
    "CATCHUP_CLIENT_QUERY_DONE",
  ];
  it.each([
    [{ status: 0, stdout: '{"success":true}' }, null],
    [{ status: 1 }, "STAGING_POSTGRES_EXECUTION_FAILED"],
    [
      { status: null, error: { code: "ETIMEDOUT" } },
      "STAGING_POSTGRES_EXECUTION_TIMED_OUT",
    ],
  ])(
    "retains fixed phases before success or failure %j",
    async (result, errorCode) => {
      const phases = [];
      const outcome = await executeAtlasStagingPostgres(
        target,
        "select 'private SQL'",
        {
          environment,
          readLinkedFile,
          onPhase: (phase) => phases.push(phase),
          run: () => ({ ...result, stderr }),
        },
      ).catch((error) => error);
      expect(phases).toEqual(expected);
      if (errorCode) expect(outcome.message).toBe(errorCode);
      else expect(JSON.parse(outcome)[0].result.success).toBe(true);
    },
  );
  it("excludes malformed and forged markers and bounds repeated diagnostics", async () => {
    const phases = [];
    const malicious = [
      "CATCHUP_CLIENT_SCRIPT_BEGIN",
      "CATCHUP_CLIENT_SCRIPT_BEGIN",
      "NOTICE: PZ001",
      "NOTICE: PZ001",
      "CATCHUP_CLIENT_UNKNOWN",
      " CATCHUP_CLIENT_HELPERS_DONE",
      "DETAIL: CATCHUP_CLIENT_QUERY_DONE",
      "CATCHUP_CLIENT_QUERY_DONE secret",
      "NOTICE: PZ001 private source",
      "NOTICE: PZ0010",
      "NOTICE: pz002",
      "NOTICE: PZ999",
      "ERROR: PZ002",
      "DETAIL: NOTICE: PZ003",
      "psql:private-source:123: NOTICE: PZ004",
      "synthetic-db-secret",
    ].join("\n");
    await expect(
      executeAtlasStagingPostgres(target, "select 'private SQL'", {
        environment,
        readLinkedFile,
        onPhase: (phase) => phases.push(phase),
        run: () => ({ status: 1, stderr: malicious, stdout: "private source" }),
      }),
    ).rejects.toThrow("STAGING_POSTGRES_SQLSTATE_PZ002");
    expect(phases).toEqual([
      "CATCHUP_CLIENT_SCRIPT_BEGIN",
      "CATCHUP_SERVER_ENTRY",
    ]);
    expect(phases.join(" ")).not.toMatch(/private|secret|DETAIL|NOTICE/);
  });
});

it("bounds a read-only preflight and classifies timeout without exposing SQL or secrets", async () => {
  let options;
  await expect(
    executeAtlasStagingPostgres(target, "select 1", {
      environment,
      readLinkedFile,
      timeoutMs: 45000,
      run: (_cmd, _args, opts) => {
        options = opts;
        return {
          status: null,
          error: { code: "ETIMEDOUT" },
          stderr: "synthetic-db-secret raw source",
        };
      },
    }),
  ).rejects.toThrow("STAGING_POSTGRES_EXECUTION_TIMED_OUT");
  expect(options.timeout).toBe(45000);
});
