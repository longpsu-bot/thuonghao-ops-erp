import { act, renderHook, waitFor, cleanup } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useChangeOrderWorkbench } from "./useChangeOrderWorkbench";
import {
  changeDate,
  createChangeOrderFixture,
  type ChangeOrderScenario,
} from "./changeOrderReviewFixtures";
import { fixtureError, fixtureSuccess } from "./recipeReviewFixtures";
import type { AtlasRpcResult } from "../bridges/recipeAdjustment";
afterEach(cleanup);
async function setup(scenario: ChangeOrderScenario = "ACTIVE") {
  const f = createChangeOrderFixture(scenario);
  const hook = renderHook(
    ({ subject }) =>
      useChangeOrderWorkbench({
        api: f.api,
        authSubject: subject,
        initialDate: changeDate,
      }),
    { initialProps: { subject: "operator" as string | null } },
  );
  await waitFor(() => expect(hook.result.current.ready).toBe(true));
  return { ...f, ...hook };
}
async function prepare(c: Awaited<ReturnType<typeof setup>>) {
  act(() => c.result.current.openCreate());
  act(() =>
    c.result.current.updateDraft({
      dishId: "dish-0",
      schoolTypeId: "scope-0",
      action: "REPLACE",
      substituteId: "ingredient-3",
      reason: "Thay nguyên liệu",
    }),
  );
  await waitFor(() =>
    expect(c.result.current.targets?.effective_lines.length).toBe(2),
  );
  act(() =>
    c.result.current.updateDraft({ targetKey: "RECIPE_LINE:base-line" }),
  );
  await act(() => c.result.current.runPreview());
  expect(c.result.current.preview?.can_save).toBe(true);
}
describe("Change Order authoritative controller", () => {
  it("uses operator date and target reads then freezes exact Preview before a single Create/readback", async () => {
    const c = await setup();
    await prepare(c);
    const p = c.calls.find((x) => x.name === "preview")!.payload as Record<
      string,
      unknown
    >;
    expect(p).not.toHaveProperty("school_id");
    expect(c.calls.some((x) => x.name === "create")).toBe(false);
    const proposal = p.proposed_adjustment as Record<string, unknown>;
    await act(async () => {
      const first = c.result.current.save();
      const second = c.result.current.save();
      await Promise.all([first, second]);
    });
    expect(c.calls.filter((x) => x.name === "create")).toHaveLength(1);
    const request = c.calls.find((x) => x.name === "create")!.payload as {
      payload: Record<string, unknown>;
      expected_version: number;
    };
    expect(request.payload).toMatchObject({
      revision_id: proposal.revision_id,
      adjustment_id: proposal.adjustment_id,
      preview_school_type_id: "scope-0",
    });
    expect(request.payload).not.toHaveProperty("preview_school_id");
    expect(c.calls.at(-1)?.name).toBe("read");
    expect(c.result.current.lock).toBeNull();
    expect(
      c.result.current.selected?.history.some(
        (h) => h.revision_id === proposal.revision_id,
      ),
    ).toBe(true);
  });
  it.each(["UNKNOWN_CREATE", "UNKNOWN_SUPERSEDE", "UNKNOWN_CANCEL"] as const)(
    "%s locks all writes and recovers with revision proof using reads only",
    async (scenario) => {
      const c = await setup(scenario);
      if (scenario === "UNKNOWN_CREATE") {
        await prepare(c);
        await act(() => c.result.current.save());
      } else if (scenario === "UNKNOWN_SUPERSEDE") {
        act(() => c.result.current.openCorrection(c.data.operator_rows[0]));
        await waitFor(() => expect(c.result.current.targets).not.toBeNull());
        await act(() => c.result.current.runPreview());
        await act(() => c.result.current.save());
      } else {
        act(() => c.result.current.openCancel(c.data.operator_rows[0]));
        await act(() =>
          c.result.current.cancel(changeDate, "Không còn áp dụng"),
        );
      }
      expect(c.result.current.lock).toBe("unknown");
      expect(c.result.current.message).toBe(
        "Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.",
      );
      const writes = c.calls.filter((x) =>
        ["create", "supersede", "cancel"].includes(x.name),
      );
      expect(writes).toHaveLength(1);
      await act(async () => {
        await c.result.current.save();
        await c.result.current.cancel(changeDate, "lặp lại");
      });
      await act(() => c.result.current.recover());
      expect(c.result.current.lock).toBeNull();
      expect(
        c.calls.filter((x) =>
          ["create", "supersede", "cancel"].includes(x.name),
        ),
      ).toHaveLength(1);
    },
  );
  it("does not infer failure when recovery lacks the expected revision", async () => {
    const c = await setup("UNKNOWN_CREATE");
    await prepare(c);
    const old = structuredClone(c.data);
    await act(() => c.result.current.save());
    c.api.getOperatorWorkbench = async () => fixtureSuccess({ workbench: old });
    await act(() => c.result.current.recover());
    expect(c.result.current.lock).toBe("unknown");
  });
  it("correction preserves command revision, predecessor/version and system identity", async () => {
    const c = await setup();
    const row = c.data.operator_rows[0];
    act(() => c.result.current.openCorrection(row));
    expect(c.result.current.draft?.reason).toBe(
      row.command_revision.reason_note,
    );
    await waitFor(() => expect(c.result.current.targets).not.toBeNull());
    await act(() => c.result.current.runPreview());
    expect(c.calls.find((x) => x.name === "preview")?.payload).toMatchObject({
      replaces_adjustment_id: "order-existing",
    });
    await act(() => c.result.current.save());
    const r = c.calls.find((x) => x.name === "supersede")!.payload as {
      expected_version: number;
      payload: Record<string, unknown>;
    };
    expect(r.expected_version).toBe(3);
    expect(r.payload).toMatchObject({
      predecessor_revision_id: "revision-existing",
      preview_school_type_id: "scope-0",
    });
    expect(r.payload).not.toHaveProperty("preview_school_id");
    expect(c.result.current.selected?.history.at(-1)?.business_event_kind).toBe(
      "CORRECTED",
    );
  });
  it("backend can_correct/can_cancel ceilings prevent commands even through controller entrypoints", async () => {
    const c = await setup();
    const row = {
      ...c.data.operator_rows[0],
      can_correct: false,
      can_cancel: false,
    };
    act(() => {
      c.result.current.openCorrection(row);
      c.result.current.openCancel(row);
    });
    expect(c.result.current.draft).toBeNull();
    expect(c.result.current.cancelTarget).toBeNull();
  });
  it("STALE closes Review and requires fresh read then new Preview; denial keeps the draft editable", async () => {
    const c = await setup("STALE");
    await prepare(c);
    await act(() => c.result.current.save());
    expect(c.result.current.lock).toBe("stale");
    expect(c.result.current.preview).toBeNull();
    await act(() => c.result.current.recover());
    expect(c.result.current.lock).toBeNull();
    await act(() => c.result.current.save());
    expect(c.calls.filter((x) => x.name === "create")).toHaveLength(1);
    c.api.create = async () => fixtureError("CAPABILITY_DENIED");
    await prepare(c);
    await act(() => c.result.current.save());
    expect(c.result.current.lock).toBeNull();
    expect(c.result.current.draft).not.toBeNull();
    expect(c.result.current.preview).toBeNull();
  });
  it("dirty transitions cancel without changing draft then discard and run intended transition", async () => {
    const c = await setup();
    await prepare(c);
    act(() => c.result.current.backToEdit());
    const draft = c.result.current.draft;
    const exit = vi.fn();
    act(() => c.result.current.requestExit(exit));
    expect(c.result.current.discardOpen).toBe(true);
    act(() => c.result.current.cancelDiscard());
    expect(c.result.current.draft).toEqual(draft);
    expect(exit).not.toHaveBeenCalled();
    act(() => c.result.current.requestExit(exit));
    act(() => c.result.current.confirmDiscard());
    act(() => c.result.current.completeDiscardTransition());
    expect(c.result.current.draft).toBeNull();
    expect(exit).toHaveBeenCalledOnce();
  });
  it("invalidates a late Preview after material draft changes and ignores old auth targets", async () => {
    const c = await setup();
    await prepare(c);
    act(() => c.result.current.backToEdit());
    let complete!: (r: AtlasRpcResult) => void;
    const original = c.api.preview;
    let response!: AtlasRpcResult;
    c.api.preview = async (...args) => {
      response = await original(...args);
      return new Promise((resolve) => {
        complete = resolve;
      });
    };
    let running!: Promise<void>;
    act(() => {
      running = c.result.current.runPreview();
    });
    await waitFor(() => expect(complete).toBeTypeOf("function"));
    act(() => c.result.current.updateDraft({ reason: "Changed" }));
    await act(async () => {
      complete(response);
      await running;
    });
    expect(c.result.current.preview).toBeNull();
    c.rerender({ subject: "another" });
    await waitFor(() => expect(c.result.current.ready).toBe(true));
    expect(c.result.current.draft).toBeNull();
  });
  it("matching School inspection is read-only and cannot alter the frozen system payload", async () => {
    const c = await setup();
    await prepare(c);
    const preview = c.result.current.preview;
    await act(() => c.result.current.inspectSchool("school-2"));
    expect(c.calls.some((x) => x.name === "resolve")).toBe(false);
    await act(() => c.result.current.inspectSchool("school-0"));
    expect(c.result.current.inspection?.school_id).toBe("school-0");
    expect(c.result.current.preview).toEqual(preview);
    await act(() => c.result.current.save());
    const r = c.calls.find((x) => x.name === "create")!.payload as {
      payload: Record<string, unknown>;
    };
    expect(r.payload).not.toHaveProperty("preview_school_id");
  });
});

// Additional currentness regressions use deferred boundary responses, never hosted writes.
describe("Change Order delayed authority and failure boundaries", () => {
  it("keeps a successful command locked until readback proves its revision", async () => {
    const c = await setup();
    await prepare(c);
    const before = structuredClone(c.data);
    c.api.getOperatorWorkbench = async () =>
      fixtureSuccess({ workbench: before });
    await act(() => c.result.current.save());
    expect(c.result.current.lock).toBe("readback");
    expect(c.result.current.preview).toBeNull();
    await act(() => c.result.current.recover());
    expect(c.result.current.lock).toBe("readback");
    expect(c.calls.filter((x) => x.name === "create")).toHaveLength(1);
  });
  it("closes Cancel after success so failed readback can be recovered without resending", async () => {
    const c = await setup();
    act(() => c.result.current.openCancel(c.data.operator_rows[0]));
    c.api.getOperatorWorkbench = async () => fixtureError("CAPABILITY_DENIED");
    await act(() => c.result.current.cancel(changeDate, "Không còn áp dụng"));
    expect(c.result.current.lock).toBe("readback");
    expect(c.result.current.cancelTarget).toBeNull();
    expect(c.result.current.canAct).toBe(false);
    await act(() => c.result.current.recover());
    expect(c.result.current.lock).toBe("readback");
    expect(c.calls.filter((x) => x.name === "cancel")).toHaveLength(1);
  });
  it("keeps unknown lock after failed recovery", async () => {
    const c = await setup("FAILED_UNKNOWN_RECOVERY");
    await prepare(c);
    await act(() => c.result.current.save());
    await act(() => c.result.current.recover());
    expect(c.result.current.lock).toBe("unknown");
    expect(c.result.current.ready).toBe(false);
    expect(c.calls.filter((x) => x.name === "create")).toHaveLength(1);
  });
  it("rejects mismatched Preview context and proposal", async () => {
    const c = await setup();
    await prepare(c);
    act(() => c.result.current.backToEdit());
    const original = c.api.preview;
    c.api.preview = async (...args) => {
      const r = await original(...args);
      if (r.kind === "success")
        (r.response.preview as Record<string, unknown>).proposed_adjustment =
          {};
      return r;
    };
    await act(() => c.result.current.runPreview());
    expect(c.result.current.preview).toBeNull();
    await act(() => c.result.current.save());
    expect(c.calls.some((x) => x.name === "create")).toBe(false);
  });
  it("ignores late target responses after changing Dish", async () => {
    const c = await setup();
    let finish!: (r: AtlasRpcResult) => void;
    const original = c.api.getEffectiveTargetContext;
    let response!: AtlasRpcResult;
    c.api.getEffectiveTargetContext = async (...args) => {
      const r = await original(...args);
      if (args[3] === "dish-0") {
        response = r;
        return new Promise((resolve) => {
          finish = resolve;
        });
      }
      return r;
    };
    act(() => c.result.current.openCreate());
    act(() =>
      c.result.current.updateDraft({
        dishId: "dish-0",
        schoolTypeId: "scope-0",
      }),
    );
    await waitFor(() => expect(finish).toBeTypeOf("function"));
    act(() => c.result.current.updateDraft({ dishId: "dish-1" }));
    await waitFor(() =>
      expect(c.result.current.targets?.dish_id).toBe("dish-1"),
    );
    await act(async () => finish(response));
    expect(c.result.current.targets?.dish_id).toBe("dish-1");
  });
  it("ignores obsolete School inspection and does not revive Review after editing", async () => {
    const c = await setup();
    await prepare(c);
    let finish!: (r: AtlasRpcResult) => void;
    const original = c.api.resolve;
    let response!: AtlasRpcResult;
    c.api.resolve = async (...args) => {
      response = await original(...args);
      return new Promise((resolve) => {
        finish = resolve;
      });
    };
    let pending!: Promise<void>;
    act(() => {
      pending = c.result.current.inspectSchool("school-0");
    });
    await waitFor(() => expect(finish).toBeTypeOf("function"));
    act(() => c.result.current.backToEdit());
    await act(async () => {
      finish(response);
      await pending;
    });
    expect(c.result.current.inspection).toBeNull();
    expect(c.result.current.preview).toBeNull();
  });
  it("retains an old account's uncertain mutation without adopting its late response", async () => {
    const c = await setup();
    await prepare(c);
    let finish!: (r: AtlasRpcResult) => void;
    c.api.create = async () =>
      new Promise((resolve) => {
        finish = resolve;
      });
    let pending!: Promise<void>;
    act(() => {
      pending = c.result.current.save();
    });
    c.rerender({ subject: "another" });
    await waitFor(() => expect(c.result.current.ready).toBe(true));
    await act(async () => {
      finish(fixtureSuccess());
      await pending;
    });
    expect(c.result.current.lock).toBe("unknown");
    expect(c.result.current.draft).toBeNull();
    expect(c.result.current.selected).toBeNull();
  });
  it("correction retains a fixed historical target even when the current PRESENT set no longer includes it", async () => {
    const c = await setup();
    const original = c.api.getEffectiveTargetContext;
    c.api.getEffectiveTargetContext = async (...args) => {
      const r = await original(...args);
      if (r.kind === "success")
        (r.response.target_context as Record<string, unknown>).effective_lines =
          [];
      return r;
    };
    act(() => c.result.current.openCorrection(c.data.operator_rows[0]));
    await waitFor(() => expect(c.result.current.targets).not.toBeNull());
    expect(c.result.current.canPreview).toBe(true);
    await act(() => c.result.current.runPreview());
    expect(
      c.result.current.preview?.proposed_adjustment.target_recipe_line_id,
    ).toBe("base-line");
  });
});

it("invalidates late effective inspection when its inspection context is cleared", async () => {
  const c = await setup();
  act(() => c.result.current.select(c.data.operator_rows[0]));
  const original = c.api.resolveSystem;
  let finish!: (r: AtlasRpcResult) => void;
  let response!: AtlasRpcResult;
  c.api.resolveSystem = async (...args) => {
    response = await original(...args);
    return new Promise((resolve) => {
      finish = resolve;
    });
  };
  let pending!: Promise<void>;
  act(() => {
    pending = c.result.current.inspectEffective("dish-0", "", "scope-0");
  });
  await waitFor(() => expect(finish).toBeTypeOf("function"));
  act(() => c.result.current.clearEffective());
  await act(async () => {
    finish(response);
    await pending;
  });
  expect(c.result.current.effective).toBeNull();
  expect(c.result.current.effectiveLoading).toBe(false);
});
