// @vitest-environment node
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { describe, it, expect, vi } from "vitest";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  runLocalMasterDataRehearsal,
  validateDisposableRehearsalTarget,
} from "./run-local-master-data-rehearsal.mjs";

const actor = "aa920000-0000-4000-8000-000000000001";
const planHash = "b".repeat(64);
function fixture() {
  const s = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_system: "OPS_V1",
    snapshot_id: "synthetic-local",
    exported_at: "2026-09-15T08:00:00Z",
    extractor_version: "test",
    records: {},
    source_counts: {},
    source_diagnostics: [],
  };
  return { ...s, snapshot_checksum: checksumOpsV1MasterSnapshot(s) };
}
const target = {
  workdir: "synthetic-disposable-workdir",
  projectId: "atlas-master-rehearsal-01",
};
function setup(test) {
  const dir = mkdtempSync(join(tmpdir(), "atlas-rehearsal-runner-test-"));
  const path = join(dir, "snapshot.json");
  writeFileSync(path, JSON.stringify(fixture()), "utf8");
  try {
    return test(path);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
const preview = {
  success: true,
  plan_checksum: planHash,
  actions: [{ object_type: "UNIT", legacy_id: "kg", action: "CREATE" }],
  issues: [],
};

describe("local-only rehearsal runner", () => {
  it("defaults to non-writing preview with no actor or apply command", () =>
    setup((file) => {
      const query = vi.fn(() => preview);
      const result = runLocalMasterDataRehearsal({
        file,
        checkTarget: () => target,
        executeSql: query,
      });
      expect(result.mode).toBe("preview");
      expect(query).toHaveBeenCalledTimes(1);
      expect(query.mock.calls[0][0]).toContain("preview_master_data_snapshot");
      expect(query.mock.calls[0][0]).not.toContain(
        "apply_master_data_snapshot",
      );
      expect(result.report).toContain("NOT_APPLIED");
    }));
  it("requires an explicit actor and exact reviewed plan hash for apply", () =>
    setup((file) => {
      const q = vi.fn();
      expect(() =>
        runLocalMasterDataRehearsal({
          file,
          apply: true,
          planChecksum: planHash,
          checkTarget: () => target,
          executeSql: q,
        }),
      ).toThrow(/ACTOR_REQUIRED/);
      expect(() =>
        runLocalMasterDataRehearsal({
          file,
          apply: true,
          actorId: actor,
          checkTarget: () => target,
          executeSql: q,
        }),
      ).toThrow(/PLAN_CHECKSUM_REQUIRED/);
      expect(q).not.toHaveBeenCalled();
    }));
  it("rejects unsafe actor input and a changed plan before apply", () =>
    setup((file) => {
      const q = vi.fn(() => preview);
      expect(() =>
        runLocalMasterDataRehearsal({
          file,
          apply: true,
          actorId: "';drop table x;",
          planChecksum: planHash,
          checkTarget: () => target,
          executeSql: q,
        }),
      ).toThrow(/ACTOR/);
      expect(() =>
        runLocalMasterDataRehearsal({
          file,
          apply: true,
          actorId: actor,
          planChecksum: "c".repeat(64),
          checkTarget: () => target,
          executeSql: q,
        }),
      ).toThrow(/PLAN_CHANGED/);
      expect(q).toHaveBeenCalledTimes(1);
    }));
  it("binds apply to the original file, Actor and reviewed plan, then verifies readback", () =>
    setup((file) => {
      const q = vi
        .fn()
        .mockReturnValueOnce(preview)
        .mockReturnValueOnce({
          success: true,
          status: "COMPLETED",
          operator_actor_id: actor,
        })
        .mockReturnValueOnce({
          success: true,
          actions: [{ action: "NO_CHANGE" }],
          issues: [],
        });
      const result = runLocalMasterDataRehearsal({
        file,
        apply: true,
        actorId: actor,
        planChecksum: planHash,
        checkTarget: () => target,
        executeSql: q,
      });
      expect(q).toHaveBeenCalledTimes(3);
      expect(q.mock.calls[1][0]).toContain("apply_master_data_snapshot");
      expect(q.mock.calls[1][0]).toContain(actor);
      expect(q.mock.calls[1][0]).toContain(planHash);
      expect(q.mock.calls[1][0]).toContain("decode(");
      expect(result.report).toContain("REHEARSAL_ACCEPTED");
    }));
  it("never applies a blocked preview or claims success on changed readback", () =>
    setup((file) => {
      const blocked = vi.fn(() => ({
        success: false,
        issues: [{ severity: "BLOCKER", code: "RECIPE_EMPTY" }],
      }));
      const result = runLocalMasterDataRehearsal({
        file,
        apply: true,
        actorId: actor,
        planChecksum: planHash,
        checkTarget: () => target,
        executeSql: blocked,
      });
      expect(blocked).toHaveBeenCalledTimes(1);
      expect(result.report).toContain("REJECTED");
      const drift = vi
        .fn()
        .mockReturnValueOnce(preview)
        .mockReturnValueOnce({ success: true, status: "COMPLETED" })
        .mockReturnValueOnce({
          success: true,
          actions: [{ action: "UPDATE" }],
        });
      expect(() =>
        runLocalMasterDataRehearsal({
          file,
          apply: true,
          actorId: actor,
          planChecksum: planHash,
          checkTarget: () => target,
          executeSql: drift,
        }),
      ).toThrow(/READBACK/);
    }));
  it("detects tampered immutable input before executing SQL", () =>
    setup((file) => {
      const s = fixture();
      s.snapshot_id = "tampered";
      writeFileSync(file, JSON.stringify(s), "utf8");
      const q = vi.fn();
      expect(() =>
        runLocalMasterDataRehearsal({
          file,
          checkTarget: () => target,
          executeSql: q,
        }),
      ).toThrow(/CHECKSUM/);
      expect(q).not.toHaveBeenCalled();
    }));
  it("requires explicit disposable configuration and loopback DB/API proof", () => {
    const status = {
      API_URL: "http://127.0.0.1:55321",
      DB_URL: "postgresql://postgres:synthetic@127.0.0.1:55322/postgres",
      ANON_KEY: "synthetic-browser-key",
    };
    const options = {
      environment: { SUPABASE_WORKDIR: "synthetic-workdir" },
      readConfig: () => 'project_id = "atlas-master-rehearsal-01"',
      readStatus: () => status,
    };
    expect(validateDisposableRehearsalTarget(options).projectId).toBe(
      "atlas-master-rehearsal-01",
    );
    expect(() =>
      validateDisposableRehearsalTarget({ ...options, environment: {} }),
    ).toThrow(/DISPOSABLE_WORKDIR/);
    expect(() =>
      validateDisposableRehearsalTarget({
        ...options,
        readConfig: () => 'project_id = "thuonghao-ops-erp"',
      }),
    ).toThrow(/DISPOSABLE_PROJECT/);
    expect(() =>
      validateDisposableRehearsalTarget({
        ...options,
        readStatus: () => ({
          ...status,
          API_URL: "https://rnzxmxiiqgtdevzregff.supabase.co",
        }),
      }),
    ).toThrow();
    expect(() =>
      validateDisposableRehearsalTarget({
        ...options,
        readStatus: () => ({
          ...status,
          DB_URL: "postgresql://postgres:synthetic@db.example.com/postgres",
        }),
      }),
    ).toThrow(/LOOPBACK_DATABASE/);
  });
});

describe("pinned Supabase CLI result decoding", () => {
  it("accepts the actual JSON-array result returned by the pinned local CLI", async () => {
    const { parseRehearsalQueryResult } =
      await import("./run-local-master-data-rehearsal.mjs");
    expect(
      parseRehearsalQueryResult(
        '[{"result":{"success":true,"probe":"synthetic"}}]',
      ),
    ).toEqual({ success: true, probe: "synthetic" });
  });
  it("rejects multirow, malformed and empty command results", async () => {
    const { parseRehearsalQueryResult } =
      await import("./run-local-master-data-rehearsal.mjs");
    for (const raw of [
      "[]",
      "not-json",
      '[{"result":true}]',
      '[{"result":{}},{"result":{}}]',
    ])
      expect(() => parseRehearsalQueryResult(raw)).toThrow(/RESPONSE_INVALID/);
  });
});
