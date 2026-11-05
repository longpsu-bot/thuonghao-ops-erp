// @vitest-environment node
import { describe, expect, it, vi } from "vitest";
import {
  buildWeekdaySyncPlan,
  extractWeekdaySource,
  runWeekdayDefaultSync,
} from "./sync-atlas-staging-weekday-defaults.mjs";

const target = "rnzxmxiiqgtdevzregff";
const environment = {
  ATLAS_STAGING_PROJECT_REF: target,
  VITE_SUPABASE_URL: `https://${target}.supabase.co`,
  VITE_ATLAS_ENVIRONMENT: "staging",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic_1234567890",
  ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: "synthetic-management-token",
  ATLAS_STAGING_TEST_EMAIL: "operator@example.invalid",
  ATLAS_STAGING_TEST_PASSWORD: "synthetic-password",
};
function fixture() {
  const source = Array.from({ length: 34 }, (_, index) => ({
    id: String(index + 1),
    is_active: true,
    default_students_weekday: [0, null, 2, null, 4],
    default_teachers_weekday: null,
  }));
  source.push({
    id: "54",
    is_active: true,
    default_students_weekday: null,
    default_teachers_weekday: null,
  });
  const schools = source.slice(0, 34).map((row) => ({
    school_id: `12345678-1234-4234-8234-${row.id.padStart(12, "0")}`,
    school_code: `v1-school-${row.id}`,
    school_status: "ACTIVE",
    version: 7,
    default_student_portions: 100,
    default_teacher_portions: 10,
    weekday_portion_defaults: {},
    school_name: "preserve-name",
  }));
  schools.push({
    ...schools[0],
    school_id: "12345678-1234-4234-8234-999999999999",
    school_code: "native-school",
  });
  return { source, schools };
}
const proof = {
  role_name: "supabase_read_only_user",
  superuser: false,
  create_role: false,
  create_db: false,
  has_select: true,
  has_non_select: false,
};
const response = (body, status = 200) => ({
  ok: status < 300,
  status,
  json: async () => structuredClone(body),
});
function network({
  drift = false,
  sourceDrift = false,
  failWrite = false,
  failReadback = false,
} = {}) {
  const { source, schools } = fixture();
  const writes = [];
  let reads = 0,
    sourceReads = 0,
    receipt;
  const fetchImpl = vi.fn(async (url, options) => {
    if (url.endsWith("/database/query/read-only")) {
      if (sourceDrift && ++sourceReads === 2)
        source[0].default_students_weekday[0] = 1;
      return response(
        [
          {
            snapshot: {
              source_project_ref: "qnthofvccilhnefdcxnz",
              source_access: proof,
              schools: source,
            },
          },
        ],
        201,
      );
    }
    if (url.endsWith("/auth/v1/token?grant_type=password"))
      return response({
        access_token: "synthetic-user-token",
        user: { id: "12345678-1234-4234-8234-000000000099" },
      });
    if (url.endsWith("/auth/v1/user"))
      return response({
        id: "12345678-1234-4234-8234-000000000099",
        email: environment.ATLAS_STAGING_TEST_EMAIL,
      });
    if (url.endsWith("/auth/v1/logout?scope=local")) return response(null, 204);
    if (url.endsWith("/rpc/get_school_master_data")) {
      reads++;
      if (drift && reads === 2) schools[0].version++;
      if (failReadback && writes.length)
        return response({ success: false }, 500);
      return response({ success: true, schools });
    }
    if (url.endsWith("/rpc/update_school_portion_defaults_bulk")) {
      writes.push(options.body);
      if (failWrite) throw Error("sensitive upstream body");
      const request = JSON.parse(options.body).request;
      if (!receipt) {
        for (const change of request.payload.changes) {
          const school = schools.find(
            (row) => row.school_id === change.school_id,
          );
          Object.assign(school, {
            weekday_portion_defaults: change.weekday_portion_defaults,
            version: school.version + 1,
          });
        }
        receipt = {
          success: true,
          command_id: request.command_id,
          correlation_id: request.correlation_id,
        };
      }
      return response(receipt);
    }
    throw Error("Unexpected endpoint");
  });
  return { fetchImpl, writes, schools, source };
}
const guards = () => ({
  verifyCheckout: vi.fn(),
  verifyCertification: vi.fn(),
});
const runOptions = (fetchImpl) => ({
  commitSha: "a".repeat(40),
  environment,
  fetchImpl,
  ...guards(),
});

describe("bounded Staging weekday defaults sync", () => {
  it("maps explicit zero and null fallback without importing School54 or changing defaults", () => {
    const { source, schools } = fixture();
    const plan = buildWeekdaySyncPlan(source, schools);
    expect(plan.configured_count).toBe(34);
    expect(plan.changes).toHaveLength(34);
    expect(plan.changes[0]).toEqual({
      school_id: schools[0].school_id,
      expected_version: 7,
      default_student_portions: 100,
      default_teacher_portions: 10,
      weekday_portion_defaults: {
        1: { student_portions: 0 },
        3: { student_portions: 2 },
        5: { student_portions: 4 },
      },
    });
  });
  it.each(
    [
      [0],
      [0, null, 2, null, 4, 5],
      "{0,NULL,2,NULL,4}",
      [0, null, -1, null, 4],
      [0, null, 1.5, null, 4],
      [0, null, "2", null, 4],
      [0, null, 2147483648, null, 4],
    ].map((invalid) => [invalid]),
  )("rejects malformed or invalid source arrays %j", (invalid) => {
    const { source, schools } = fixture();
    source[0].default_students_weekday = invalid;
    expect(() => buildWeekdaySyncPlan(source, schools)).toThrow(
      "SOURCE_ARRAY_INVALID",
    );
  });
  it.each(["missing", "duplicate", "inactive", "source-inactive", "count"])(
    "blocks %s configured references",
    (kind) => {
      const { source, schools } = fixture();
      if (kind === "missing") schools.shift();
      if (kind === "duplicate")
        schools.push({
          ...schools[0],
          school_id: "12345678-1234-4234-8234-999999999998",
        });
      if (kind === "inactive") schools[0].school_status = "INACTIVE";
      if (kind === "source-inactive") source[0].is_active = false;
      if (kind === "count") (source.pop(), source.pop());
      expect(() => buildWeekdaySyncPlan(source, schools)).toThrow();
    },
  );
  it("binds the stable plan to source, UUID, version and existing defaults", () => {
    const { source, schools } = fixture();
    const before = buildWeekdaySyncPlan(source, schools).plan_checksum;
    expect(
      buildWeekdaySyncPlan([...source].reverse(), [...schools].reverse())
        .plan_checksum,
    ).toBe(before);
    for (const field of [
      "school_id",
      "version",
      "default_student_portions",
      "default_teacher_portions",
    ]) {
      const changed = structuredClone(schools);
      changed[0][field] =
        typeof changed[0][field] === "number"
          ? changed[0][field] + 1
          : "12345678-1234-4234-8234-999999999997";
      expect(buildWeekdaySyncPlan(source, changed).plan_checksum).not.toBe(
        before,
      );
    }
  });
  it("uses a fixed read-only source endpoint and validates actual privilege proof", async () => {
    const mocked = network();
    await extractWeekdaySource({
      accessToken: "synthetic",
      fetchImpl: mocked.fetchImpl,
    });
    expect(mocked.fetchImpl.mock.calls[0][0]).toBe(
      "https://api.supabase.com/v1/projects/qnthofvccilhnefdcxnz/database/query/read-only",
    );
    const query = JSON.parse(mocked.fetchImpl.mock.calls[0][1].body).query;
    expect(query).toMatch(/pg_roles/);
    expect(query).toMatch(/has_any_column_privilege/);
    await expect(
      extractWeekdaySource({
        accessToken: "synthetic",
        fetchImpl: async () =>
          response(
            [
              {
                snapshot: {
                  source_project_ref: "qnthofvccilhnefdcxnz",
                  source_access: { ...proof, has_non_select: true },
                  schools: [],
                },
              },
            ],
            201,
          ),
      }),
    ).rejects.toThrow("READ_ONLY_PROOF");
  });
  it("preview authenticates and signs out, verifies exact-head guards, and makes zero command writes", async () => {
    const mocked = network(),
      options = runOptions(mocked.fetchImpl);
    const result = await runWeekdayDefaultSync(options);
    expect(result.status).toBe("PREVIEW");
    expect(result.update_count).toBe(34);
    expect(mocked.writes).toEqual([]);
    expect(options.verifyCheckout).toHaveBeenCalled();
    expect(options.verifyCertification).toHaveBeenCalledWith(
      expect.objectContaining({ certificationMode: "github" }),
    );
    expect(mocked.fetchImpl.mock.calls.at(-1)[0]).toMatch(
      /auth\/v1\/logout\?scope=local$/,
    );
    expect(JSON.stringify(result)).not.toMatch(
      /school_id|student_portions|password|synthetic|preserve-name/,
    );
  });
  it("signs out only its own session", async () => {
    const mocked = network();
    await runWeekdayDefaultSync(runOptions(mocked.fetchImpl));
    expect(mocked.fetchImpl.mock.calls.at(-1)[0]).toMatch(
      /auth\/v1\/logout\?scope=local$/,
    );
  });
  it("only applies reviewed checksum with exact same-request replay and complete readback", async () => {
    const preview = await runWeekdayDefaultSync(
      runOptions(network().fetchImpl),
    );
    const mocked = network();
    const unrelated = structuredClone(mocked.schools.at(-1));
    const result = await runWeekdayDefaultSync({
      ...runOptions(mocked.fetchImpl),
      apply: true,
      planChecksum: preview.plan_checksum,
      targetConfirmation: target,
    });
    expect(result.status).toBe("APPLIED");
    expect(result.replay_verified).toBe(true);
    expect(mocked.writes).toHaveLength(2);
    expect(mocked.writes[0]).toBe(mocked.writes[1]);
    expect(mocked.schools.at(-1)).toEqual(unrelated);
    expect(mocked.schools[0].default_student_portions).toBe(100);
    const command = JSON.parse(mocked.writes[0]).request;
    expect(command.requested_by_auth_subject).toBe(
      "12345678-1234-4234-8234-000000000099",
    );
    expect(command.contract_version).toBe("RMVP-01.v2");
    expect(command.payload.changes).toHaveLength(34);
  });
  it("an already matching fresh plan makes zero command calls", async () => {
    const mocked = network();
    const initial = buildWeekdaySyncPlan(mocked.source, mocked.schools);
    for (const change of initial.changes)
      mocked.schools.find(
        (school) => school.school_id === change.school_id,
      ).weekday_portion_defaults = change.weekday_portion_defaults;
    const result = await runWeekdayDefaultSync({
      ...runOptions(mocked.fetchImpl),
      apply: true,
      targetConfirmation: target,
      planChecksum: buildWeekdaySyncPlan(mocked.source, mocked.schools)
        .plan_checksum,
    });
    expect(result.status).toBe("NO_CHANGE");
    expect(mocked.writes).toHaveLength(0);
  });
  it("source drift between preview and command prevents writes", async () => {
    const mocked = network({ sourceDrift: true });
    await expect(
      runWeekdayDefaultSync({
        ...runOptions(mocked.fetchImpl),
        apply: true,
        targetConfirmation: target,
        planChecksum: buildWeekdaySyncPlan(mocked.source, mocked.schools)
          .plan_checksum,
      }),
    ).rejects.toThrow("FRESH_PLAN_DRIFT");
    expect(mocked.writes).toHaveLength(0);
  });
  it("readback failure reports failure after known success without another command retry", async () => {
    const mocked = network({ failReadback: true });
    await expect(
      runWeekdayDefaultSync({
        ...runOptions(mocked.fetchImpl),
        apply: true,
        targetConfirmation: target,
        planChecksum: buildWeekdaySyncPlan(mocked.source, mocked.schools)
          .plan_checksum,
      }),
    ).rejects.toThrow("AUTHENTICATED_SCHOOL_READ_FAILED");
    expect(mocked.writes).toHaveLength(2);
    expect(mocked.fetchImpl.mock.calls.at(-1)[0]).toMatch(
      /logout\?scope=local$/,
    );
  });
  it("missing credentials and failed exact-head guards stop before network access", async () => {
    const fetchImpl = vi.fn();
    await expect(
      runWeekdayDefaultSync({
        ...runOptions(fetchImpl),
        environment: { ...environment, ATLAS_STAGING_TEST_PASSWORD: "" },
      }),
    ).rejects.toThrow("protected values");
    await expect(
      runWeekdayDefaultSync({
        ...runOptions(fetchImpl),
        verifyCheckout: () => {
          throw Error("main mismatch");
        },
      }),
    ).rejects.toThrow("main mismatch");
    await expect(
      runWeekdayDefaultSync({
        ...runOptions(fetchImpl),
        verifyCertification: () => {
          throw Error("CI failed");
        },
      }),
    ).rejects.toThrow("CI failed");
    expect(fetchImpl).not.toHaveBeenCalled();
  });
  it.each([
    "missing-checksum",
    "stale-plan",
    "wrong-target",
    "drift",
    "certification",
  ])("rejects %s before any command write", async (kind) => {
    const mocked = network({ drift: kind === "drift" }),
      options = {
        ...runOptions(mocked.fetchImpl),
        apply: true,
        planChecksum: buildWeekdaySyncPlan(fixture().source, fixture().schools)
          .plan_checksum,
        targetConfirmation: target,
      };
    if (kind === "missing-checksum") options.planChecksum = undefined;
    if (kind === "stale-plan") options.planChecksum = "b".repeat(64);
    if (kind === "wrong-target")
      options.targetConfirmation = "qnthofvccilhnefdcxnz";
    if (kind === "certification")
      options.verifyCertification = async () => {
        throw Error("certification failed");
      };
    await expect(runWeekdayDefaultSync(options)).rejects.toThrow();
    expect(mocked.writes).toHaveLength(0);
  });
  it("never retries an unknown command outcome and still signs out", async () => {
    const mocked = network({ failWrite: true });
    await expect(
      runWeekdayDefaultSync({
        ...runOptions(mocked.fetchImpl),
        apply: true,
        targetConfirmation: target,
        planChecksum: buildWeekdaySyncPlan(fixture().source, fixture().schools)
          .plan_checksum,
      }),
    ).rejects.toThrow("OUTCOME_UNKNOWN");
    expect(mocked.writes).toHaveLength(1);
    expect(mocked.fetchImpl.mock.calls.at(-1)[0]).toMatch(
      /logout\?scope=local$/,
    );
  });
});
