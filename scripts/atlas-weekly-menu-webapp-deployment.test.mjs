// @vitest-environment node
import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import {
  buildWeeklyMenuSourceSql,
  verifyWeeklyMenuShadow,
} from "./deploy-atlas-weekly-menu-webapp.mjs";
const project = "rnzxmxiiqgtdevzregff";
const sourceId = "a1000000-0000-4000-8000-000000000001";
const school = {
  school_id: "a1000000-0000-4000-8000-000000000011",
  school_code: "s1",
  school_name: "School A",
  school_status: "ACTIVE",
};
const type = {
  dish_type_id: "a1000000-0000-4000-8000-000000000022",
  dish_type_code: "soup",
  dish_type_name: "Món canh",
  source_header_aliases: [],
  dish_type_status: "ACTIVE",
  display_order: 1,
};
const dish = {
  dish_id: "a1000000-0000-4000-8000-000000000033",
  dish_code: "d1",
  dish_name: "Soup",
  dish_status: "ACTIVE",
  dish_type_id: type.dish_type_id,
};
const wb = {
  schools: [school],
  dishes: [dish],
  dish_types: [type],
  weekly_menu: null,
  attendance: null,
};
const env = {
  ATLAS_STAGING_PROJECT_REF: project,
  VITE_SUPABASE_URL: `https://${project}.supabase.co`,
  VITE_SUPABASE_PUBLISHABLE_KEY: "public",
  ATLAS_STAGING_TEST_EMAIL: "fixture@test.example",
  ATLAS_STAGING_TEST_PASSWORD: "synthetic-password",
};
describe("bounded source configuration and read-only shadow", () => {
  it("allows only exact Staging and a safe approved spreadsheet identifier", () => {
    expect(() =>
      buildWeeklyMenuSourceSql("qnthofvccilhnefdcxnz", "fixture-spreadsheet"),
    ).toThrow();
    expect(() =>
      buildWeeklyMenuSourceSql(project, "bad';drop table"),
    ).toThrow();
    const sql = buildWeeklyMenuSourceSql(project, "fixture-spreadsheet");
    expect(sql).toContain("weekly_menu_google_sources");
    expect(sql).toContain("SOURCE_IDENTITY_CONFLICT");
    expect(sql).not.toMatch(
      /delete|truncate|weekly_menu_lines|save_weekly_menu/i,
    );
  });
  it("uses auth, configured Edge fetch, the real parser and only non-writing RPCs", async () => {
    const calls = [];
    const result = await verifyWeeklyMenuShadow({
      environment: env,
      sourceId,
      weekStart: "2026-09-21",
      fetchImpl: async (url, init) => {
        calls.push(url);
        const body = JSON.parse(String(init?.body ?? "{}"));
        if (url.includes("/auth/v1/token"))
          return Response.json({
            access_token: "test-atlas-user-token",
            user: { id: "a1000000-0000-4000-8000-000000000044" },
          });
        if (url.endsWith("/get_planning_inputs_workbench"))
          return Response.json({ success: true, workbench: wb });
        if (url.includes("/functions/v1/"))
          return Response.json({
            success: true,
            source: {
              source_name: "Fixture",
              sheet_name: "Tuần 21-09-2026",
              range: "'Tuần 21-09-2026'!A3:I500",
            },
            rows: [
              ["Tên trường", "Thứ", "Ngày", "Món canh"],
              ["School A", "Hai", "2026-09-21", "Soup"],
            ],
          });
        if (url.endsWith("/preview_weekly_menu_import")) {
          expect(body.request.payload.rows[0].dish_id).toBe(dish.dish_id);
          return Response.json({
            success: true,
            preview: {
              can_save: true,
              canonical_rows: body.request.payload.rows,
              source_signature: "checksum",
              issues: { blockers: [], warnings: [] },
            },
          });
        }
        throw new Error("unexpected endpoint");
      },
    });
    expect(result.status).toBe("GOOGLE_WEEKLY_MENU_SHADOW_READ_PASS");
    expect(result.menu_unchanged).toBe(true);
    expect(result.assignment_count).toBe(1);
    expect(calls).toHaveLength(5);
    expect(calls.every((x) => !/save_|approve_|generate_/.test(x))).toBe(true);
  });

  it("reports actual backend issue envelopes without hiding source blockers", async () => {
    const result = await verifyWeeklyMenuShadow({
      environment: env,
      sourceId,
      weekStart: "2026-09-21",
      fetchImpl: async (url) => {
        if (url.includes("/auth/v1/token"))
          return Response.json({
            access_token: "test-token",
            user: { id: "a1000000-0000-4000-8000-000000000044" },
          });
        if (url.endsWith("/get_planning_inputs_workbench"))
          return Response.json({ success: true, workbench: wb });
        if (url.includes("/functions/v1/"))
          return Response.json({
            success: true,
            source: { source_name: "Fixture", sheet_name: "Tuần 21-09-2026" },
            rows: [
              ["Tên trường", "Ngày", "Món canh"],
              ["School A", "2026-09-21", "Missing dish"],
            ],
          });
        return Response.json({
          success: true,
          preview: {
            can_save: false,
            issues: { blockers: [{ code: "DISH_UNRESOLVED" }], warnings: [] },
          },
        });
      },
    });
    expect(result.status).toBe("GOOGLE_WEEKLY_MENU_SHADOW_READ_BLOCKED");
    expect(result.preview_blockers).toEqual([{ code: "DISH_UNRESOLVED" }]);
    expect(result.save_calls).toBe(0);
  });

  it.each([
    undefined,
    {},
    { blockers: null, warnings: [] },
    { blockers: [], warnings: null },
  ])(
    "rejects malformed preview issues rather than assuming none: %o",
    async (issues) => {
      await expect(
        verifyWeeklyMenuShadow({
          environment: env,
          sourceId,
          weekStart: "2026-09-21",
          fetchImpl: async (url) => {
            if (url.includes("/auth/v1/token"))
              return Response.json({
                access_token: "test-token",
                user: { id: "a1000000-0000-4000-8000-000000000044" },
              });
            if (url.endsWith("/get_planning_inputs_workbench"))
              return Response.json({ success: true, workbench: wb });
            if (url.includes("/functions/v1/"))
              return Response.json({
                success: true,
                source: {
                  source_name: "Fixture",
                  sheet_name: "Tuần 21-09-2026",
                },
                rows: [
                  ["Tên trường", "Ngày", "Món canh"],
                  ["School A", "2026-09-21", "Soup"],
                ],
              });
            return Response.json({
              success: true,
              preview: { can_save: true, issues },
            });
          },
        }),
      ).rejects.toThrow("SHADOW_PREVIEW_ENVELOPE_INVALID");
    },
  );
  it("retains warning evidence and never reports pass with backend blockers", async () => {
    const result = await verifyWeeklyMenuShadow({
      environment: env,
      sourceId,
      weekStart: "2026-09-21",
      fetchImpl: async (url) => {
        if (url.includes("/auth/v1/token"))
          return Response.json({
            access_token: "test-token",
            user: { id: "a1000000-0000-4000-8000-000000000044" },
          });
        if (url.endsWith("/get_planning_inputs_workbench"))
          return Response.json({ success: true, workbench: wb });
        if (url.includes("/functions/v1/"))
          return Response.json({
            success: true,
            source: { source_name: "Fixture", sheet_name: "Tuần 21-09-2026" },
            rows: [
              ["Tên trường", "Ngày", "Món canh"],
              ["School A", "2026-09-21", "Soup"],
            ],
          });
        return Response.json({
          success: true,
          preview: {
            can_save: true,
            issues: {
              blockers: [{ code: "CONFLICT" }],
              warnings: [{ code: "NOTE" }],
            },
          },
        });
      },
    });
    expect(result.status).toBe("GOOGLE_WEEKLY_MENU_SHADOW_READ_BLOCKED");
    expect(result.preview_warnings).toEqual([{ code: "NOTE" }]);
  });
  it("manual deployment stays exact-main, protected and does not run menu commands", () => {
    const workflow = readFileSync(
      new URL(
        "../.github/workflows/atlas-weekly-menu-webapp.yml",
        import.meta.url,
      ),
      "utf8",
    );
    expect(workflow).toContain("workflow_dispatch:");
    expect(workflow).toContain("environment: atlas-staging");
    expect(workflow).toContain("refs/heads/main");
    expect(workflow).toContain("origin/main");
    expect(workflow).not.toContain("upload-artifact");
    expect(workflow).not.toContain("db reset");
    expect(workflow).not.toContain("--no-verify-jwt");
  });
});
