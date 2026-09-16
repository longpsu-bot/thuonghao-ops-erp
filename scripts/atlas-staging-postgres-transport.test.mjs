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
    expect(call.args).toContain("--no-password");
    expect(JSON.stringify(call.args)).not.toContain("synthetic-db-secret");
    expect(JSON.stringify(call.args)).not.toContain(sql);
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
