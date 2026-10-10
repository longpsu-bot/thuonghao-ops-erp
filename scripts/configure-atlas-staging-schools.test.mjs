// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import { readdirSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { ownerSchoolIdentityExpectations } from "./atlas-document-school-configuration.mjs";
import {
  parseSchoolConfigurationArguments,
  runAtlasStagingSchoolConfiguration,
} from "./configure-atlas-staging-schools.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
function fixture() {
  const state = {
    schools: ownerSchoolIdentityExpectations.map(([id, name], index) => ({
      school_id: randomUUID(),
      school_code: `v1-school-${id}`,
      school_name: name,
      school_status: "ACTIVE",
      display_order: index,
      version: 4,
      cooking_location_id: null,
      cooking_location_name: null,
      cooking_location_kind: null,
      cooking_location_host_school_id: null,
      cooking_group_id: null,
      cooking_group_name: null,
      dispatch_group_id: null,
      dispatch_group_name: null,
    })),
    cooking_groups: [],
    dispatch_groups: [],
  };
  const mappings = state.schools.map((s) => ({
    source_system: "OPS_V1",
    object_type: "SCHOOL",
    legacy_id: s.school_code.slice(10),
    school_id: s.school_id,
  }));
  const versions = readdirSync(
    new URL("../supabase/migrations/", import.meta.url),
  )
    .filter((f) => /^\d{14}_.+\.sql$/.test(f))
    .map((f) => f.slice(0, 14))
    .sort();
  const calls = [];
  const subject = randomUUID();
  const commands = [];
  const environment = {
    ATLAS_STAGING_PROJECT_REF: STAGING,
    VITE_SUPABASE_URL: `https://${STAGING}.supabase.co`,
    ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "protected-management-token",
    VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_fixture",
    ATLAS_STAGING_TEST_EMAIL: "fixture@example.test",
    ATLAS_STAGING_TEST_PASSWORD: "protected-password",
  };
  const fetchImpl = vi.fn(async (url, options) => {
    calls.push({ url, options });
    if (url.includes("/auth/"))
      return {
        ok: true,
        json: async () => ({
          access_token: "auth-issued-token",
          user: { id: subject },
        }),
      };
    const name = url.split("/").at(-1);
    const request = JSON.parse(options.body).request;
    if (name.startsWith("get_")) {
      const key = {
        get_school_master_data: "schools",
        get_cooking_groups: "cooking_groups",
        get_dispatch_groups: "dispatch_groups",
      }[name];
      return {
        ok: true,
        json: async () => ({
          success: true,
          contract_version: "RMVP-01.v1",
          [key]: structuredClone(state[key]),
        }),
      };
    }
    commands.push({ name, request });
    const cooking = name.includes("cooking");
    const prefix = cooking ? "cooking" : "dispatch";
    let id, version;
    if (name.startsWith("upsert_")) {
      id = randomUUID();
      version = 1;
      state[`${prefix}_groups`].push({
        ...request.payload,
        [`${prefix}_group_id`]: id,
        version,
      });
    } else {
      const school = state.schools.find(
        (s) => s.school_id === request.payload.school_id,
      );
      expect(request.expected_version).toBe(school.version);
      id = school.school_id;
      const groupId = request.payload[`${prefix}_group_id`];
      const group = state[`${prefix}_groups`].find(
        (g) => g[`${prefix}_group_id`] === groupId,
      );
      school[`${prefix}_group_id`] = groupId;
      school[`${prefix}_group_name`] = group?.[`${prefix}_group_name`] ?? null;
      if (cooking)
        Object.assign(school, {
          cooking_location_id: groupId,
          cooking_location_name: group?.cooking_group_name ?? null,
          cooking_location_kind: group?.location_kind ?? null,
          cooking_location_host_school_id: group?.host_school_id ?? null,
        });
      version = ++school.version;
    }
    return {
      ok: true,
      json: async () => ({
        success: true,
        contract_version: "RMVP-01.v1",
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        affected_aggregate_ids: {
          [name.startsWith("upsert_") ? `${prefix}_group_id` : "school_id"]: id,
        },
        new_versions: { aggregate_version: version },
      }),
    };
  });
  const executeTarget = vi.fn(async (_target, sql) => [
    {
      result: sql.includes("schema_migrations")
        ? { versions }
        : { mappings: structuredClone(mappings) },
    },
  ]);
  const options = {
    environment,
    commitSha: "a".repeat(40),
    verifyCheckout: vi.fn(),
    executeTarget,
    fetchImpl,
  };
  return {
    state,
    mappings,
    versions,
    calls,
    commands,
    subject,
    options,
    environment,
  };
}

describe("bounded authenticated School configuration", () => {
  it("accepts only the bounded CLI flags and requires each flag value", () => {
    expect(
      parseSchoolConfigurationArguments(["--commit-sha", "a".repeat(40)]),
    ).toMatchObject({ apply: false });
    expect(
      parseSchoolConfigurationArguments([
        "--apply",
        "--target-project-ref",
        STAGING,
      ]),
    ).toMatchObject({ apply: true, targetConfirmation: STAGING });
    for (const args of [
      ["--commit-sha"],
      ["--target-project-ref", "--apply"],
      ["--sql", "insert"],
      ["--apply", "--apply"],
    ])
      expect(() => parseSchoolConfigurationArguments(args)).toThrow(
        "ARGUMENT_INVALID",
      );
  });
  it("rejects privileged API keys before any network call", async () => {
    const f = fixture();
    f.environment.VITE_SUPABASE_PUBLISHABLE_KEY = "sb_secret_fixture";
    await expect(runAtlasStagingSchoolConfiguration(f.options)).rejects.toThrow(
      "PUBLISHABLE_KEY_REQUIRED",
    );
    expect(f.options.fetchImpl).not.toHaveBeenCalled();
  });
  it("does not proceed if exact main verification fails", async () => {
    const f = fixture();
    f.options.verifyCheckout = vi.fn(() => {
      throw new Error("checkout moved");
    });
    await expect(runAtlasStagingSchoolConfiguration(f.options)).rejects.toThrow(
      "checkout moved",
    );
    expect(f.options.executeTarget).not.toHaveBeenCalled();
  });
  it("requires reconciliation of Owner display order without writing it", async () => {
    const f = fixture();
    [f.state.schools[0].display_order, f.state.schools[1].display_order] = [
      f.state.schools[1].display_order,
      f.state.schools[0].display_order,
    ];
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow("DISPLAY_ORDER");
    expect(f.commands).toHaveLength(0);
  });
  it("previews with real Auth headers and no commands or SQL writes", async () => {
    const f = fixture();
    const out = await runAtlasStagingSchoolConfiguration(f.options);
    expect(out.status).toBe("SCHOOL_CONFIGURATION_PREVIEW");
    expect(f.commands).toHaveLength(0);
    expect(f.options.verifyCheckout).toHaveBeenCalledWith(
      expect.objectContaining({ commitSha: f.options.commitSha }),
    );
    expect(
      f.options.executeTarget.mock.calls.every(
        ([, sql]) => !/insert|update|delete|set_config/i.test(sql),
      ),
    ).toBe(true);
    expect(f.calls[0].url).toContain("/auth/v1/token?grant_type=password");
    for (const { options } of f.calls.slice(1)) {
      expect(options.headers.Authorization).toBe("Bearer auth-issued-token");
      expect(options.headers["Content-Profile"]).toBe("atlas_api");
      expect(JSON.parse(options.body).request.requested_by_auth_subject).toBe(
        f.subject,
      );
    }
    expect(JSON.stringify(out)).not.toMatch(
      /protected-password|auth-issued-token|fixture@example/,
    );
  });
  it.each([
    "VITE_SUPABASE_PUBLISHABLE_KEY",
    "ATLAS_STAGING_TEST_EMAIL",
    "ATLAS_STAGING_TEST_PASSWORD",
  ])("requires protected %s before network", async (key) => {
    const f = fixture();
    delete f.environment[key];
    await expect(runAtlasStagingSchoolConfiguration(f.options)).rejects.toThrow(
      "CREDENTIAL",
    );
    expect(f.options.fetchImpl).not.toHaveBeenCalled();
  });
  it("requires exact target apply confirmation", async () => {
    const f = fixture();
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: "other",
      }),
    ).rejects.toThrow("target confirmation");
    expect(f.commands).toHaveLength(0);
  });
  it.each(["missing", "extra", "duplicate", "substituted"])(
    "rejects %s migration parity before Auth",
    async (type) => {
      const f = fixture();
      if (type === "missing") f.versions.pop();
      if (type === "extra") f.versions.push("20261011111111");
      if (type === "duplicate") f.versions[0] = f.versions[1];
      if (type === "substituted") f.versions[0] = "20200101000000";
      await expect(
        runAtlasStagingSchoolConfiguration(f.options),
      ).rejects.toThrow("MIGRATION");
      expect(f.options.fetchImpl).not.toHaveBeenCalled();
    },
  );
  it("refuses name-based resolution when the typed mapping is missing", async () => {
    const f = fixture();
    f.mappings.pop();
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow("SCHOOL_MASTER_RECONCILIATION_REQUIRED");
    expect(f.commands).toHaveLength(0);
  });
  it("plans every preflight before any mutation and rejects later group conflict", async () => {
    const f = fixture();
    f.state.dispatch_groups.push({
      dispatch_group_id: randomUUID(),
      dispatch_group_name: "CHUYÊN HÙNG VƯƠNG",
      active: false,
      version: 1,
    });
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow("GROUP_CONFLICT");
    expect(f.commands).toHaveLength(0);
  });
  it("applies cooking then independent Dispatch commands with fresh versions and authoritative readback", async () => {
    const f = fixture();
    const out = await runAtlasStagingSchoolConfiguration({
      ...f.options,
      apply: true,
      targetConfirmation: STAGING,
    });
    expect(out.status).toBe("SCHOOL_CONFIGURATION_VERIFIED");
    expect(f.commands).toHaveLength(21);
    expect(
      f.commands.slice(0, 8).every((c) => c.name.includes("cooking")),
    ).toBe(true);
    expect(f.commands.slice(8).every((c) => c.name.includes("dispatch"))).toBe(
      true,
    );
    for (const { request } of f.commands) {
      expect(request.command_id).toMatch(/^[0-9a-f-]{36}$/);
      expect(request.idempotency_key).toMatch(/^[0-9a-f-]{36}$/);
      expect(request.requested_by_auth_subject).toBe(f.subject);
      expect(request.reason_code).toMatch(
        /^(COOKING_GROUP_SAVED|SCHOOL_COOKING_GROUP_SET|DISPATCH_GROUP_SAVED|SCHOOL_DISPATCH_GROUP_SET)$/,
      );
    }
    const school = (id) =>
      out.schools.find((s) => s.school_code === `v1-school-${id}`);
    expect(school("14")).toMatchObject({
      cooking_location_name: "PHẠM VĂN CỘI",
      dispatch_group_id: null,
    });
    expect(school("53")).toMatchObject({
      cooking_location_name: "Công ty Thượng Hảo",
      cooking_location_kind: "COMPANY",
      cooking_location_host_school_id: null,
      dispatch_group_name: "CHUYÊN HÙNG VƯƠNG",
    });
    expect(school("28").dispatch_group_id).toBeNull();
    expect(school("47").cooking_location_id).toBeNull();
    expect(new Set(f.commands.map((c) => c.request.idempotency_key)).size).toBe(
      21,
    );
    expect(
      f.calls.filter((c) => c.url.endsWith("get_school_master_data")).length,
    ).toBeGreaterThan(42);
  });
  it("reuses only exact canonical groups and does not rewrite configured facts", async () => {
    const f = fixture();
    await runAtlasStagingSchoolConfiguration({
      ...f.options,
      apply: true,
      targetConfirmation: STAGING,
    });
    f.commands.length = 0;
    await runAtlasStagingSchoolConfiguration({
      ...f.options,
      apply: true,
      targetConfirmation: STAGING,
    });
    expect(f.commands).toHaveLength(0);
  });
  it("stops after an uncertain command outcome without retrying or exposing transport secrets", async () => {
    const f = fixture();
    const real = f.options.fetchImpl;
    f.options.fetchImpl = vi.fn(async (url, options) => {
      if (url.endsWith("upsert_cooking_group"))
        throw new Error("protected-password auth-issued-token");
      return real(url, options);
    });
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow(
      /^SCHOOL_COMMAND_OUTCOME_UNCERTAIN:upsert_cooking_group:[0-9a-f-]{36}:[0-9a-f-]{36}:[0-9a-f-]{36}$/,
    );
    expect(
      f.options.fetchImpl.mock.calls.filter(([url]) =>
        url.endsWith("upsert_cooking_group"),
      ),
    ).toHaveLength(1);
  });
  it.each([
    "duplicate",
    "kind",
    "host",
    "partial-membership",
    "outside-member",
  ])(
    "preflights and rejects %s group conflict with zero writes",
    async (problem) => {
      const f = fixture();
      await runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      });
      f.commands.length = 0;
      const group = f.state.cooking_groups[0];
      if (problem === "duplicate")
        f.state.cooking_groups.push({
          ...group,
          cooking_group_id: randomUUID(),
        });
      if (problem === "kind" || problem === "host") {
        if (problem === "kind") group.location_kind = null;
        group.host_school_id =
          problem === "kind" ? null : f.state.schools[0].school_id;
        for (const s of f.state.schools.filter(
          (s) => s.cooking_group_id === group.cooking_group_id,
        )) {
          s.cooking_location_kind = group.location_kind;
          s.cooking_location_host_school_id = group.host_school_id;
        }
      }
      if (problem === "partial-membership") {
        const s = f.state.schools.find((s) => s.school_code === "v1-school-14");
        Object.assign(s, {
          cooking_group_id: null,
          cooking_group_name: null,
          cooking_location_id: null,
          cooking_location_name: null,
          cooking_location_kind: null,
          cooking_location_host_school_id: null,
        });
      }
      if (problem === "outside-member") {
        const s = f.state.schools.find((s) => s.school_code === "v1-school-52");
        Object.assign(s, {
          cooking_group_id: group.cooking_group_id,
          cooking_group_name: group.cooking_group_name,
          cooking_location_id: group.cooking_group_id,
          cooking_location_name: group.cooking_group_name,
          cooking_location_kind: group.location_kind,
          cooking_location_host_school_id: group.host_school_id,
        });
      }
      await expect(
        runAtlasStagingSchoolConfiguration({
          ...f.options,
          apply: true,
          targetConfirmation: STAGING,
        }),
      ).rejects.toThrow("GROUP_CONFLICT");
      expect(f.commands).toHaveLength(0);
    },
  );
  it("preserves other School assignments, including existing cooking for other HV Schools", async () => {
    const f = fixture();
    const id = randomUUID();
    const host = f.state.schools[0].school_id;
    f.state.cooking_groups.push({
      cooking_group_id: id,
      cooking_group_name: "Unrelated kitchen",
      active: true,
      version: 7,
      location_kind: "SCHOOL",
      host_school_id: host,
    });
    const school = f.state.schools.find(
      (s) => s.school_code === "v1-school-47",
    );
    Object.assign(school, {
      cooking_group_id: id,
      cooking_group_name: "Unrelated kitchen",
      cooking_location_id: id,
      cooking_location_name: "Unrelated kitchen",
      cooking_location_kind: "SCHOOL",
      cooking_location_host_school_id: host,
    });
    const out = await runAtlasStagingSchoolConfiguration({
      ...f.options,
      apply: true,
      targetConfirmation: STAGING,
    });
    expect(
      out.schools.find((s) => s.school_id === school.school_id),
    ).toMatchObject({
      cooking_location_id: id,
      dispatch_group_name: "CHUYÊN HÙNG VƯƠNG",
    });
    expect(
      f.state.cooking_groups.find((g) => g.cooking_group_id === id).version,
    ).toBe(7);
  });
  it("detects cross-relationship corruption immediately after a Dispatch command", async () => {
    const f = fixture();
    const real = f.options.fetchImpl;
    f.options.fetchImpl = async (url, options) => {
      const response = await real(url, options);
      if (url.endsWith("set_school_dispatch_group")) {
        const school = f.state.schools.find(
          (s) =>
            s.school_id === JSON.parse(options.body).request.payload.school_id,
        );
        Object.assign(school, {
          cooking_group_id: null,
          cooking_group_name: null,
          cooking_location_id: null,
          cooking_location_name: null,
          cooking_location_kind: null,
          cooking_location_host_school_id: null,
        });
      }
      return response;
    };
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow("READBACK_FAILED:set_school_dispatch_group");
    expect(
      f.commands.filter((c) => c.name === "set_school_dispatch_group"),
    ).toHaveLength(1);
  });
  it("stops before a command when authoritative School or group versions changed", async () => {
    const f = fixture();
    const real = f.options.fetchImpl;
    let schoolReads = 0;
    f.options.fetchImpl = async (url, options) => {
      if (url.endsWith("get_school_master_data") && ++schoolReads === 2)
        f.state.schools[0].version++;
      return real(url, options);
    };
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow("STATE_CHANGED_BEFORE_COMMAND");
    expect(f.commands).toHaveLength(0);
  });
  it("clears only the explicit independent example and PH3 with current School versions", async () => {
    const f = fixture();
    const group = {
      dispatch_group_id: randomUUID(),
      dispatch_group_name: "Prior independent route",
      active: true,
      version: 2,
    };
    f.state.dispatch_groups.push(group);
    for (const id of ["14", "28", "52"])
      Object.assign(
        f.state.schools.find((s) => s.school_code === `v1-school-${id}`),
        {
          dispatch_group_id: group.dispatch_group_id,
          dispatch_group_name: group.dispatch_group_name,
        },
      );
    const out = await runAtlasStagingSchoolConfiguration({
      ...f.options,
      apply: true,
      targetConfirmation: STAGING,
    });
    for (const id of ["14", "28"])
      expect(
        out.schools.find((s) => s.school_code === `v1-school-${id}`)
          .dispatch_group_id,
      ).toBeNull();
    expect(
      out.schools.find((s) => s.school_code === "v1-school-52")
        .dispatch_group_id,
    ).toBe(group.dispatch_group_id);
    expect(
      f.commands.filter(
        (c) =>
          c.name === "set_school_dispatch_group" &&
          c.request.payload.dispatch_group_id === null,
      ),
    ).toHaveLength(2);
  });
  it("treats malformed success as uncertain and emits command identity before dispatch", async () => {
    const f = fixture();
    const real = f.options.fetchImpl;
    const identities = [];
    f.options.onCommand = (identity) => identities.push(identity);
    f.options.fetchImpl = async (url, options) => {
      if (url.endsWith("upsert_cooking_group")) {
        expect(identities).toHaveLength(1);
        return {
          ok: true,
          json: async () => ({
            success: true,
            contract_version: "RMVP-01.v1",
            command_id: randomUUID(),
          }),
        };
      }
      return real(url, options);
    };
    await expect(
      runAtlasStagingSchoolConfiguration({
        ...f.options,
        apply: true,
        targetConfirmation: STAGING,
      }),
    ).rejects.toThrow("COMMAND_OUTCOME_UNCERTAIN");
    expect(identities[0]).toMatchObject({
      function_name: "upsert_cooking_group",
    });
    expect(Object.keys(identities[0])).toEqual([
      "function_name",
      "command_id",
      "correlation_id",
      "idempotency_key",
    ]);
  });
});
