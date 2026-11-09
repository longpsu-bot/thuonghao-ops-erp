import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it, vi } from "vitest";
import {
  RECIPE3529,
  recipe3529Proposal,
  buildRecipe3529Plan,
  runRecipe3529Correction,
} from "./correct-atlas-staging-recipe3529.mjs";

const subject = "a1000000-0000-4000-8000-000000000001";
const commitSha = "a".repeat(40);
const environment = {
  ATLAS_STAGING_PROJECT_REF: "rnzxmxiiqgtdevzregff",
  VITE_ATLAS_ENVIRONMENT: "staging",
  VITE_SUPABASE_URL: "https://rnzxmxiiqgtdevzregff.supabase.co",
  VITE_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_recipe3529_test",
  ATLAS_STAGING_TEST_EMAIL: "operator@example.test",
  ATLAS_STAGING_TEST_PASSWORD: "test-only-password",
};
function resolution(type, date) {
  const second = type === RECIPE3529.type2;
  const selected = {
    dish_id: RECIPE3529.dish,
    school_type_id: type,
    school_type_code: second ? "v1-school-type-2" : "v1-school-type-1",
    recipe_id: second ? RECIPE3529.recipe : RECIPE3529.siblingRecipe,
    recipe_version_id: second ? RECIPE3529.version : RECIPE3529.siblingVersion,
    basis_portions: 100,
    selection_scope: "SCHOOL_TYPE",
  };
  return {
    status: "READY",
    as_of_date: date,
    dish_id: RECIPE3529.dish,
    school_type_id: type,
    school_id: null,
    historical: false,
    selected_recipe: selected,
    blockers: [],
    warnings: [],
    lines: RECIPE3529.otherIngredients
      .concat([[second ? RECIPE3529.beef : RECIPE3529.pork, 5.5]])
      .map(([ingredient, quantity], index) => ({
        base_recipe_line_id:
          index === 4 && second ? RECIPE3529.line : `${type}-${index}`,
        base_recipe_line_revision_id: `revision-${type}-${index}`,
        selected_dish_id: RECIPE3529.dish,
        selected_recipe_id: selected.recipe_id,
        selected_recipe_version_id: selected.recipe_version_id,
        basis_portions: 100,
        base_ingredient_id: ingredient,
        base_quantity_per_basis: quantity,
        base_unit_id: RECIPE3529.unit,
        base_disposition: "PRESENT",
        adjustment_line_id: null,
        final_ingredient_id: ingredient,
        final_quantity_per_basis: quantity,
        final_unit_id: RECIPE3529.unit,
        final_disposition: "PRESENT",
        source_layer: "RELEASED_RECIPE_VERSION",
        applied_adjustment_ids: [],
        applied_revision_ids: [],
        lineage: [],
      })),
  };
}
function contexts() {
  return [RECIPE3529.type1, RECIPE3529.type2].flatMap((type) =>
    ["2026-11-08", "2026-11-09"].map((date) => resolution(type, date)),
  );
}
function after(before, isPreview = true) {
  const result = structuredClone(before),
    p = recipe3529Proposal();
  const line = result.lines.find(
    (l) => l.base_recipe_line_id === RECIPE3529.line,
  );
  const values = (ingredient) => ({
    ingredient_id: ingredient,
    quantity_per_basis: 5.5,
    unit_id: RECIPE3529.unit,
    disposition: "PRESENT",
  });
  line.final_ingredient_id = RECIPE3529.pork;
  line.source_layer = "SYSTEM_DISH";
  line.applied_adjustment_ids.push(p.adjustment_id);
  line.applied_revision_ids.push(p.revision_id);
  line.lineage.push({
    adjustment_id: p.adjustment_id,
    revision_id: p.revision_id,
    revision_number: 1,
    scope_kind: "SYSTEM_DISH",
    action_kind: "REPLACE",
    before: values(RECIPE3529.beef),
    after: values(RECIPE3529.pork),
    reason_code: p.reason_code,
    reason_note: p.reason_note,
    effective_from: "2026-11-09",
    effective_to: null,
    is_preview: isPreview,
  });
  return result;
}
function preview(rows = contexts()) {
  const before = rows[3];
  return {
    as_of_date: "2026-11-09",
    dish_id: RECIPE3529.dish,
    school_type_id: RECIPE3529.type2,
    school_id: null,
    proposed_adjustment: recipe3529Proposal(),
    before,
    after: after(before),
    affected_line_count: 1,
    can_save: true,
    blockers: [],
    warnings: [],
  };
}
function plan(rows = contexts(), whatIf = preview(rows), actor = subject) {
  return buildRecipe3529Plan({
    contexts: rows,
    preview: whatIf,
    subject: actor,
    commitSha,
  });
}
function harness({
  mutateRead,
  mutatePreview,
  createFailure,
  mutateReceipt,
  logoutFailure = false,
  subjectMismatch = false,
  failCertification = false,
} = {}) {
  const calls = [],
    commands = [];
  let created = false,
    reads = 0;
  const reply = (data) => new Response(JSON.stringify(data), { status: 200 });
  const fetchImpl = vi.fn(async (url, options = {}) => {
    calls.push(url);
    if (url.includes("/token?"))
      return reply({
        access_token: "local-session-token",
        user: { id: subject },
      });
    if (url.endsWith("/user"))
      return reply({
        id: subjectMismatch ? RECIPE3529.dish : subject,
        email: environment.ATLAS_STAGING_TEST_EMAIL,
      });
    if (url.includes("/logout?"))
      return new Response(null, { status: logoutFailure ? 500 : 204 });
    expect(options.headers.apikey).toBe(
      environment.VITE_SUPABASE_PUBLISHABLE_KEY,
    );
    expect(options.headers.Authorization).toBe("Bearer local-session-token");
    expect(options.headers["Content-Profile"]).toBe("atlas_api");
    const { request } = JSON.parse(options.body);
    expect(request.requested_by_auth_subject).toBe(subject);
    if (url.endsWith("/resolve_system_effective_recipe_composition")) {
      expect(request.contract_version).toBe("RECIPE-EFFECTIVE.v1");
      const p = request.payload;
      let data = resolution(p.school_type_id, p.as_of_date);
      if (
        created &&
        p.school_type_id === RECIPE3529.type2 &&
        p.as_of_date === "2026-11-09"
      )
        data = after(data, false);
      return reply({
        success: true,
        resolution: mutateRead?.(data, ++reads) ?? data,
      });
    }
    if (url.endsWith("/preview_recipe_composition_adjustment")) {
      expect(request.payload.proposed_adjustment).toEqual(recipe3529Proposal());
      const data = preview();
      return reply(
        mutatePreview ? mutatePreview(data) : { success: true, preview: data },
      );
    }
    if (url.endsWith("/create_recipe_composition_adjustment")) {
      commands.push(request);
      if (createFailure) throw Error("connection dropped, outcome unknown");
      created = true;
      const receipt = {
        success: true,
        contract_version: "RMVP-02B.v1",
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        affected_aggregate_ids: {
          recipe_composition_adjustment_id: recipe3529Proposal().adjustment_id,
        },
        new_versions: { aggregate_version: 1 },
        emitted_event_ids: [subject],
        audit_event_ids: [subject],
      };
      return reply(mutateReceipt?.(receipt, commands.length) ?? receipt);
    }
    throw Error(`Unexpected request ${url}`);
  });
  return {
    calls,
    commands,
    options: {
      environment,
      commitSha,
      fetchImpl,
      verifyCheckout: vi.fn(),
      verifyCertification: vi.fn(() => {
        if (failCertification) throw Error("not certified");
      }),
    },
  };
}

describe("owner-confirmed Recipe3529 correction", () => {
  it("binds the explicit owner decision, exact proposal, contexts, subject and code", () => {
    const p = recipe3529Proposal();
    expect(p.scope_kind).toBe("SYSTEM_DISH");
    expect(p.substitute_ingredient_id).toBe(
      "1edd7b1a-c5c9-00aa-2132-635144259d32",
    );
    expect(p.quantity_per_basis).toBeNull();
    expect(p.unit_id).toBeNull();
    expect(p.source_evidence.source_kind).toBe("ATLAS_OPERATOR");
    expect(p.source_evidence.owner_confirmation).toBe("thịt heo xay nha");
    expect(p.reason_note.normalize("NFC")).toBe(p.reason_note);
    expect(plan().plan_checksum).toMatch(/^[a-f0-9]{64}$/);
    expect(plan(undefined, undefined, RECIPE3529.dish).plan_checksum).not.toBe(
      plan().plan_checksum,
    );
  });
  it.each([
    [
      "wrong type",
      (r) => {
        r[3].school_type_id = RECIPE3529.type1;
      },
    ],
    [
      "wrong line",
      (r) => {
        r[3].lines[4].base_recipe_line_id = subject;
      },
    ],
    [
      "wrong ingredient",
      (r) => {
        r[3].lines[4].final_ingredient_id = RECIPE3529.pork;
      },
    ],
    [
      "wrong quantity",
      (r) => {
        r[3].lines[4].final_quantity_per_basis = 6;
      },
    ],
    [
      "wrong Unit",
      (r) => {
        r[3].lines[0].final_unit_id = subject;
      },
    ],
    [
      "not ready",
      (r) => {
        r[3].status = "BLOCKED";
      },
    ],
    [
      "wrong released version",
      (r) => {
        r[3].selected_recipe.recipe_version_id = subject;
      },
    ],
    [
      "changed sibling",
      (r) => {
        r[1].lines[4].final_ingredient_id = RECIPE3529.beef;
      },
    ],
    [
      "duplicate line",
      (r) => {
        r[3].lines[0].base_recipe_line_id = RECIPE3529.line;
      },
    ],
  ])("rejects %s before any command", (_, change) => {
    const rows = contexts();
    change(rows);
    expect(() => plan(rows, preview())).toThrow(/RECIPE3529_/);
  });
  it.each([
    [
      "substitute",
      (p) => {
        p.proposed_adjustment.substitute_ingredient_id = RECIPE3529.beef;
      },
    ],
    [
      "target",
      (p) => {
        p.dish_id = subject;
      },
    ],
    [
      "School context",
      (p) => {
        p.school_id = subject;
      },
    ],
    [
      "extra proposal field",
      (p) => {
        p.proposed_adjustment.unreviewed = true;
      },
    ],
    [
      "blocked preview",
      (p) => {
        p.can_save = false;
      },
    ],
    [
      "wrong delta",
      (p) => {
        p.after.lines[0].final_quantity_per_basis = 3;
      },
    ],
    [
      "missing lineage",
      (p) => {
        p.after.lines[4].lineage = [];
      },
    ],
  ])("rejects preview %s", (_, change) => {
    const whatIf = preview();
    change(whatIf);
    expect(() => plan(contexts(), whatIf)).toThrow(/RECIPE3529_/);
  });
  it("Preview has no command and closes the real-user session", async () => {
    const h = harness();
    const result = await runRecipe3529Correction(h.options);
    expect(result.status).toBe("PREVIEW");
    expect(h.commands).toHaveLength(0);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it("applies once, replays the exact request and reads back all four contexts", async () => {
    const h = harness();
    const result = await runRecipe3529Correction({
      ...h.options,
      apply: true,
      planChecksum: plan().plan_checksum,
      targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
    });
    expect(result.status).toBe("APPLIED");
    expect(result.replay_verified && result.readback_verified).toBe(true);
    expect(h.commands).toHaveLength(2);
    expect(h.commands[1]).toEqual(h.commands[0]);
    expect(h.commands[0].payload.preview_school_type_id).toBe(RECIPE3529.type2);
    expect(h.commands[0].payload.target_recipe_line_id).toBe(RECIPE3529.line);
    expect(h.options.verifyCertification).toHaveBeenCalledTimes(2);
    expect(
      h.calls.filter((c) =>
        c.endsWith("/resolve_system_effective_recipe_composition"),
      ),
    ).toHaveLength(12);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it.each([
    ["stale reviewed checksum", {}, "b".repeat(64)],
    [
      "fresh context drift",
      {
        mutateRead: (r, n) => {
          if (n > 4) r.warnings.push({ code: "CHANGED" });
          return r;
        },
      },
    ],
    [
      "missing write permission",
      {
        mutatePreview: () => ({
          success: false,
          error_code: "CAPABILITY_DENIED",
        }),
      },
    ],
    ["subject mismatch", { subjectMismatch: true }],
  ])("blocks %s and logs out without Create", async (_, config, checksum) => {
    const h = harness(config);
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: checksum ?? plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow();
    expect(h.commands).toHaveLength(0);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it("never retries an unknown Create outcome and still logs out", async () => {
    const h = harness({ createFailure: true });
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow("APPLY_OUTCOME_UNKNOWN");
    expect(h.commands).toHaveLength(1);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it.each([
    ["Type1", 9],
    ["prior-date Type2", 11],
    ["current Type2 base fact", 12],
  ])("detects post-Create %s readback drift", async (_, readNumber) => {
    const h = harness({
      mutateRead: (r, n) => {
        if (n === readNumber) r.lines[0].base_quantity_per_basis = 99;
        return r;
      },
    });
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow("READBACK_DRIFT");
    expect(h.commands).toHaveLength(2);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it("rejects a malformed success receipt without replaying it", async () => {
    const h = harness({
      mutateReceipt: (r) => ({ ...r, new_versions: { aggregate_version: 2 } }),
    });
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow("APPLY_RECEIPT_INVALID");
    expect(h.commands).toHaveLength(1);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it("reports an explicit command rejection distinctly from an unknown transport outcome", async () => {
    const h = harness({
      mutateReceipt: () => ({ success: false, error_code: "CONFLICT" }),
    });
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow("COMMAND_REJECTED");
    expect(h.commands).toHaveLength(1);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it("detects replay drift and closes the session", async () => {
    const h = harness({
      mutateReceipt: (r, n) =>
        n === 2 ? { ...r, audit_event_ids: [RECIPE3529.dish] } : r,
    });
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow("REPLAY_DRIFT");
    expect(h.commands).toHaveLength(2);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it("does not report Preview success when logout fails", async () => {
    const h = harness({ logoutFailure: true });
    await expect(runRecipe3529Correction(h.options)).rejects.toThrow(
      "AUTH_SIGNOUT_FAILED",
    );
    expect(h.commands).toHaveLength(0);
  });
  it("preserves the original uncertain-outcome error when logout also fails", async () => {
    const h = harness({ createFailure: true, logoutFailure: true });
    await expect(
      runRecipe3529Correction({
        ...h.options,
        apply: true,
        planChecksum: plan().plan_checksum,
        targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF,
      }),
    ).rejects.toThrow("APPLY_OUTCOME_UNKNOWN");
    expect(h.commands).toHaveLength(1);
    expect(h.calls.at(-1)).toContain("/logout?scope=local");
  });
  it.each([
    { apply: true },
    { apply: true, planChecksum: "b".repeat(64), targetConfirmation: "wrong" },
    { planChecksum: "b".repeat(64) },
    { targetConfirmation: environment.ATLAS_STAGING_PROJECT_REF },
  ])(
    "rejects missing or mixed apply-only review inputs before auth",
    async (inputs) => {
      const h = harness();
      await expect(
        runRecipe3529Correction({ ...h.options, ...inputs }),
      ).rejects.toThrow("REVIEWED_APPLY_INPUTS_REQUIRED");
      expect(h.calls).toHaveLength(0);
    },
  );
  it.each([
    { ATLAS_STAGING_PROJECT_REF: "wrong" },
    { VITE_ATLAS_ENVIRONMENT: "production" },
    { VITE_SUPABASE_URL: "https://wrong.supabase.co" },
    { VITE_SUPABASE_PUBLISHABLE_KEY: "sb_secret_do-not-use" },
  ])("rejects unsafe target/key configuration before login", async (patch) => {
    const h = harness();
    await expect(
      runRecipe3529Correction({
        ...h.options,
        environment: { ...environment, ...patch },
      }),
    ).rejects.toThrow();
    expect(h.calls).toHaveLength(0);
  });
  it("requires exact certification before authenticating", async () => {
    const h = harness({ failCertification: true });
    await expect(runRecipe3529Correction(h.options)).rejects.toThrow(
      "not certified",
    );
    expect(h.calls).toHaveLength(0);
  });
  it("workflow verifies executed exact-head certification before install and test-user secret loading", () => {
    const workflow = readFileSync(
      resolve(".github/workflows/atlas-staging-recipe3529.yml"),
      "utf8",
    );
    expect(workflow.indexOf("await verifyExactHeadCertification")).toBeLessThan(
      workflow.indexOf("pnpm install"),
    );
    expect(workflow.indexOf("await verifyExactHeadCertification")).toBeLessThan(
      workflow.indexOf("secrets.ATLAS_STAGING_TEST_PASSWORD"),
    );
    expect(workflow).not.toMatch(/DB_PASSWORD|ACCESS_TOKEN|service.role/i);
    expect(workflow).toContain("environment: atlas-staging");
    expect(workflow).toContain('test "$GITHUB_REF" = "refs/heads/main"');
  });
});
