// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, it, expect, vi } from "vitest";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  runSchool54Backfill,
  school54ContentChecksum,
  buildSchool54Sql,
} from "./backfill-atlas-staging-school54.mjs";
const env = {
  ATLAS_STAGING_PROJECT_REF: "rnzxmxiiqgtdevzregff",
  VITE_SUPABASE_URL: "https://rnzxmxiiqgtdevzregff.supabase.co",
  VITE_ATLAS_ENVIRONMENT: "staging",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_12345678901234567890",
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "private-token",
  ATLAS_STAGING_DB_PASSWORD: "private-db-password",
  ATLAS_STAGING_TEST_EMAIL: "operator@example.invalid",
  ATLAS_STAGING_TEST_PASSWORD: "private-password",
};
function snapshot() {
  const s = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_project_ref: "qnthofvccilhnefdcxnz",
    source_system: "OPS_V1",
    snapshot_id: "technical-1",
    exported_at: "2026-11-05T00:00:00Z",
    extractor_version: "a".repeat(40),
    records: Object.fromEntries(
      [
        "customers",
        "delivery_locations",
        "dish_types",
        "dishes",
        "ingredient_order_groups",
        "ingredient_types",
        "ingredients",
        "recipe_lines",
        "recipes",
        "school_types",
        "schools",
        "supplier_eligibilities",
        "suppliers",
        "units",
      ].map((key) => [key, []]),
    ),
    source_access: {
      role_name: "supabase_read_only_user",
      bypass_rls: true,
      superuser: false,
      create_role: false,
      create_db: false,
      has_required_select: true,
      has_non_select_privilege: false,
    },
    source_counts: { schools: 1 },
    source_diagnostics: [],
  };
  s.complete_entities = Object.keys(s.records).sort();
  s.records.customers = [
    { legacy_id: "school:54:customer", customer_name: "School54 full name" },
  ];
  s.records.delivery_locations = [
    {
      legacy_id: "school:54:delivery-location",
      address_text: "Explicit source address",
    },
  ];
  s.records.schools = [
    {
      legacy_id: "54",
      school_type_legacy_id: "1",
      school_name: "TÂN AN HỘI (Mặn 2)",
    },
  ];
  s.records.school_types = [{ legacy_id: "1", school_type_name: "TIỂU HỌC" }];
  s.records.suppliers = [
    { legacy_id: "999", supplier_name: "Unselected supplier" },
  ];
  return { ...s, snapshot_checksum: checksumOpsV1MasterSnapshot(s) };
}
const base = () => ({
  commitSha: "a".repeat(40),
  environment: env,
  verifyCheckout: vi.fn(),
  verifyCertification: vi.fn(),
  extractSnapshot: async () => snapshot(),
  createReadSession: async () => ({ read: async () => [], signOut: vi.fn() }),
});
const result = (status) => ({
  success: true,
  status,
  plan_checksum: "b".repeat(64),
  content_checksum: school54ContentChecksum(snapshot()),
  reconciled: true,
  protected_unchanged: true,
  root_ids: { school_id: "school54" },
  school: {
    school_code: "v1-school-54",
    school_name: "TÂN AN HỘI (Mặn 2)",
    school_status: "ACTIVE",
    default_student_portions: 0,
    default_teacher_portions: 0,
    weekday_portion_defaults: {},
  },
});
describe("School54 bounded prerequisite", () => {
  it("binds source business content across technical extractions", () => {
    const a = snapshot(),
      b = {
        ...a,
        snapshot_id: "technical-2",
        exported_at: "2026-11-05T01:00:00Z",
      };
    b.snapshot_checksum = checksumOpsV1MasterSnapshot(b);
    expect(school54ContentChecksum(a)).toBe(school54ContentChecksum(b));
    b.records = structuredClone(b.records);
    b.records.schools[0].school_name = "Changed selected name";
    b.snapshot_checksum = checksumOpsV1MasterSnapshot(b);
    expect(school54ContentChecksum(a)).not.toBe(school54ContentChecksum(b));
  });
  it("unselected valid source changes retain the closed checksum", () => {
    const a = snapshot(),
      b = snapshot();
    b.records.suppliers[0].supplier_name = "Changed unrelated supplier";
    b.source_counts.suppliers = 10;
    b.snapshot_checksum = checksumOpsV1MasterSnapshot(b);
    expect(b.snapshot_checksum).not.toBe(a.snapshot_checksum);
    expect(school54ContentChecksum(b)).toBe(school54ContentChecksum(a));
  });
  it.each(["customers", "delivery_locations", "schools", "school_types"])(
    "selected %s facts change the closed checksum",
    (entity) => {
      const a = snapshot(),
        b = snapshot();
      b.records[entity][0].additional_normalized_fact = "Changed";
      b.snapshot_checksum = checksumOpsV1MasterSnapshot(b);
      expect(school54ContentChecksum(b)).not.toBe(school54ContentChecksum(a));
    },
  );
  it.each(["proof", "envelope", "identity"])(
    "still rejects invalid complete source %s before narrowing",
    (failure) => {
      const s = snapshot();
      if (failure === "proof") s.source_access.has_non_select_privilege = true;
      if (failure === "envelope") delete s.records.suppliers;
      if (failure === "identity")
        s.records.suppliers.push({ ...s.records.suppliers[0] });
      s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
      expect(() => school54ContentChecksum(s)).toThrow("SNAPSHOT");
    },
  );
  it("rejects invalid checksum before target", () => {
    expect(() =>
      school54ContentChecksum({ ...snapshot(), records: {} }),
    ).toThrow("SNAPSHOT");
  });
  it("does not touch source/target when certification fails", async () => {
    const extractSnapshot = vi.fn(),
      executeTarget = vi.fn();
    await expect(
      runSchool54Backfill({
        ...base(),
        verifyCertification: async () => {
          throw Error("NO_CERT");
        },
        extractSnapshot,
        executeTarget,
      }),
    ).rejects.toThrow("NO_CERT");
    expect(extractSnapshot).not.toHaveBeenCalled();
    expect(executeTarget).not.toHaveBeenCalled();
  });
  it("requires real authorized read before any SQL even with injected target", async () => {
    const executeTarget = vi.fn(),
      signOut = vi.fn();
    await expect(
      runSchool54Backfill({
        ...base(),
        executeTarget,
        createReadSession: async () => ({
          read: async () => {
            throw Error("DENIED");
          },
          signOut,
        }),
      }),
    ).rejects.toThrow("DENIED");
    expect(executeTarget).not.toHaveBeenCalled();
    expect(signOut).toHaveBeenCalledOnce();
  });
  it("previews by default and signs out", async () => {
    const executeTarget = vi.fn(async () =>
        JSON.stringify([{ result: result("PREVIEW") }]),
      ),
      signOut = vi.fn();
    const out = await runSchool54Backfill({
      ...base(),
      executeTarget,
      createReadSession: async () => ({ read: async () => [], signOut }),
    });
    expect(out.status).toBe("PREVIEW");
    expect(executeTarget).toHaveBeenCalledOnce();
    expect(signOut).toHaveBeenCalledOnce();
  });
  it("blocks a changed reviewed plan before write", async () => {
    const executeTarget = vi.fn(async () =>
      JSON.stringify([{ result: result("PREVIEW") }]),
    );
    await expect(
      runSchool54Backfill({
        ...base(),
        apply: true,
        planChecksum: "c".repeat(64),
        targetConfirmation: env.ATLAS_STAGING_PROJECT_REF,
        executeTarget,
      }),
    ).rejects.toThrow("REVIEWED_PLAN");
    expect(executeTarget).toHaveBeenCalledOnce();
  });
  it("rechecks main before apply; never retries uncertain apply", async () => {
    const executeTarget = vi
      .fn()
      .mockResolvedValueOnce(JSON.stringify([{ result: result("PREVIEW") }]))
      .mockRejectedValueOnce(Error("UNCERTAIN"));
    await expect(
      runSchool54Backfill({
        ...base(),
        apply: true,
        planChecksum: "b".repeat(64),
        targetConfirmation: env.ATLAS_STAGING_PROJECT_REF,
        executeTarget,
      }),
    ).rejects.toThrow("UNCERTAIN");
    expect(executeTarget).toHaveBeenCalledTimes(2);
  });
  it("replays known success, reads back, preserves others and cleans up", async () => {
    const order = [],
      signOut = vi.fn(async () => order.push("logout"));
    let calls = 0,
      reads = 0;
    const executeTarget = vi.fn(async () => {
      const status = ["PREVIEW", "APPLIED", "REPLAYED"][calls++];
      order.push(status);
      return JSON.stringify([{ result: result(status) }]);
    });
    const out = await runSchool54Backfill({
      ...base(),
      apply: true,
      planChecksum: "b".repeat(64),
      targetConfirmation: env.ATLAS_STAGING_PROJECT_REF,
      executeTarget,
      createReadSession: async () => ({
        read: async () => {
          order.push("read");
          return ++reads === 1
            ? []
            : [{ ...result("APPLIED").school, school_id: "school54" }];
        },
        signOut,
      }),
    });
    expect(out.replay_status).toBe("REPLAYED");
    expect(order).toEqual([
      "read",
      "PREVIEW",
      "APPLIED",
      "REPLAYED",
      "read",
      "logout",
    ]);
    expect(JSON.stringify(out)).not.toContain("private-");
  });
  it.each(["login", "user", "capability"])(
    "default auth blocks %s before SQL",
    async (failure) => {
      const executeTarget = vi.fn(),
        urls = [];
      const fetchImpl = vi.fn(async (url) => {
        urls.push(url);
        if (url.includes("/token"))
          return {
            ok: failure !== "login",
            json: async () => ({
              access_token: "session-token",
              user: { id: "actor" },
            }),
          };
        if (url.includes("/user"))
          return {
            ok: true,
            json: async () => ({
              id: failure === "user" ? "different" : "actor",
              email: env.ATLAS_STAGING_TEST_EMAIL,
            }),
          };
        if (url.includes("/logout")) return { ok: true };
        return { ok: true, json: async () => ({ success: false }) };
      });
      await expect(
        runSchool54Backfill({
          ...base(),
          createReadSession: undefined,
          fetchImpl,
          executeTarget,
        }),
      ).rejects.toThrow("AUTH_");
      expect(executeTarget).not.toHaveBeenCalled();
      expect(
        urls.filter((url) => url.includes("/logout?scope=local")),
      ).toHaveLength(failure === "login" ? 0 : 1);
    },
  );
  it("stale main after extraction prevents target access and still cleans up", async () => {
    const verifyCheckout = vi
        .fn()
        .mockResolvedValueOnce(undefined)
        .mockRejectedValueOnce(Error("STALE_MAIN")),
      signOut = vi.fn(),
      executeTarget = vi.fn();
    await expect(
      runSchool54Backfill({
        ...base(),
        verifyCheckout,
        executeTarget,
        createReadSession: async () => ({ read: async () => [], signOut }),
      }),
    ).rejects.toThrow("STALE_MAIN");
    expect(executeTarget).not.toHaveBeenCalled();
    expect(signOut).toHaveBeenCalledOnce();
  });
  it("cleanup cannot mask the primary apply error", async () => {
    const executeTarget = vi
      .fn()
      .mockResolvedValueOnce(JSON.stringify([{ result: result("PREVIEW") }]))
      .mockRejectedValueOnce(Error("PRIMARY"));
    await expect(
      runSchool54Backfill({
        ...base(),
        apply: true,
        planChecksum: "b".repeat(64),
        targetConfirmation: env.ATLAS_STAGING_PROJECT_REF,
        executeTarget,
        createReadSession: async () => ({
          read: async () => [],
          signOut: async () => {
            throw Error("CLEANUP");
          },
        }),
      }),
    ).rejects.toThrow("PRIMARY");
  });
  it("rejects authenticated post-write readback drift without retry", async () => {
    let calls = 0;
    const executeTarget = vi.fn(async () =>
        JSON.stringify([
          { result: result(["PREVIEW", "APPLIED", "REPLAYED"][calls++]) },
        ]),
      ),
      signOut = vi.fn();
    await expect(
      runSchool54Backfill({
        ...base(),
        apply: true,
        planChecksum: "b".repeat(64),
        targetConfirmation: env.ATLAS_STAGING_PROJECT_REF,
        executeTarget,
        createReadSession: async () => ({ read: async () => [], signOut }),
      }),
    ).rejects.toThrow("AUTH_READBACK_DRIFT");
    expect(executeTarget).toHaveBeenCalledTimes(3);
    expect(signOut).toHaveBeenCalledOnce();
  });
  it("uses manual exact-main gate before installation/secrets", () => {
    const w = readFileSync(
      ".github/workflows/atlas-staging-school54.yml",
      "utf8",
    );
    expect(w).toMatch(/on:\s*\n\s*workflow_dispatch:/);
    expect(w).not.toMatch(/\n\s+(push|pull_request|schedule):/);
    const gate = w.indexOf("- name: Verify exact current main");
    expect(gate).toBeGreaterThan(w.indexOf("actions/checkout"));
    expect(gate).toBeLessThan(w.indexOf("pnpm/action-setup"));
    expect(w.slice(0, gate)).not.toContain("secrets.");
    expect(w).toContain('test "$GITHUB_REF" = "refs/heads/main"');
    expect(w).toContain(
      'test "$(git rev-parse origin/main)" = "$REQUESTED_SHA"',
    );
    expect(w).toContain("GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}");
    expect(w).toContain("default: false");
  });
  it("enforces server-side read-only Preview and the shared master workflow lock", () => {
    expect(
      buildSchool54Sql(snapshot(), {
        targetProjectRef: env.ATLAS_STAGING_PROJECT_REF,
      }),
    ).toContain("begin read only;");
    expect(
      buildSchool54Sql(snapshot(), {
        targetProjectRef: env.ATLAS_STAGING_PROJECT_REF,
        apply: true,
        planChecksum: "b".repeat(64),
      }),
    ).toContain("begin;");
    expect(
      readFileSync(".github/workflows/atlas-staging-school54.yml", "utf8"),
    ).toContain("group: atlas-staging-master-data-load");
  });
  it("builds fixed-Staging SQL only with explicit exact plan for apply", () => {
    expect(() =>
      buildSchool54Sql(snapshot(), { targetProjectRef: "production" }),
    ).toThrow("STAGING");
    expect(() =>
      buildSchool54Sql(snapshot(), {
        targetProjectRef: env.ATLAS_STAGING_PROJECT_REF,
        apply: true,
      }),
    ).toThrow("REVIEWED_PLAN");
  });
});
