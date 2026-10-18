import { describe, expect, it, vi } from "vitest";
import { createPantryApi, pantryCompletionRequest } from "./pantryApi";
import { pantryRowsForWrite, type PantryDraftRow } from "./pantryModel";

describe("B1 authored source contract", () => {
  const row: PantryDraftRow = {
    service_date: "2026-10-19",
    school_id: "school-a",
    ingredient_id: "rice",
    pantry_need_purpose_id: "planning-purpose",
    requested_quantity: "5.000001",
    note: " ",
    source_request_reference: "request-planning",
    source_row_reference: "row-planning",
  };

  it("retains distinct authored and legacy Purpose identities and exact facts", () => {
    const rows = pantryRowsForWrite([
      row,
      {
        ...row,
        pantry_need_purpose_id: "school-purpose",
        requested_quantity: "3",
        source_row_reference: "row-school",
      },
      {
        ...row,
        pantry_need_purpose_id: "legacy-neutral",
        source_row_reference: "row-legacy",
      },
    ]);
    expect(rows).toEqual([
      { ...row, note: null },
      {
        ...row,
        pantry_need_purpose_id: "school-purpose",
        requested_quantity: "3",
        source_row_reference: "row-school",
        note: null,
      },
      {
        ...row,
        pantry_need_purpose_id: "legacy-neutral",
        source_row_reference: "row-legacy",
        note: null,
      },
    ]);
  });

  it("uses the same v3 authored-purpose payload for preview, impact and Save", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: { success: true } });
    const api = createPantryApi({ invoke });
    const payload = {
      week_start: "2026-10-19",
      no_additions_confirmed: false,
      source_signature: "a".repeat(64),
      expected_source_signature: null,
      rows: pantryRowsForWrite([row]),
      school_date_modes: [
        {
          school_id: row.school_id,
          service_date: row.service_date,
          direct_need_mode: "COMPLETE" as const,
        },
      ],
    };
    await api.preview(
      "actor",
      "correlation",
      payload.week_start,
      false,
      payload.rows,
      payload.school_date_modes,
    );
    await api.getCorrectionImpact("actor", "correlation", "PANTRY", payload);
    await api.saveCompleted(
      pantryCompletionRequest("actor", "correlation", 1, payload),
    );
    expect(invoke.mock.calls[0][1]).toMatchObject({
      contract_version: "PANTRY-02.v3",
      payload: { rows: payload.rows },
    });
    expect(invoke.mock.calls[1][1].payload.source_payload).toEqual(payload);
    expect(invoke.mock.calls[2][1]).toMatchObject({
      contract_version: "PANTRY-02.v3",
      payload,
    });
  });

  it("keeps an explicit v4 compatibility path for the legacy workbench", async () => {
    const invoke = vi
      .fn()
      .mockResolvedValue({ kind: "success", response: { success: true } });
    const api = createPantryApi({ invoke });
    const payload = {
      week_start: "2026-10-19",
      no_additions_confirmed: false,
      source_signature: "a".repeat(64),
      expected_source_signature: null,
      rows: pantryRowsForWrite([row], "PANTRY-02.v4"),
      school_date_modes: [],
    };
    await api.preview(
      "actor",
      "correlation",
      payload.week_start,
      false,
      payload.rows,
      [],
      undefined,
      "PANTRY-02.v4",
    );
    await api.getCorrectionImpact(
      "actor",
      "correlation",
      "PANTRY",
      payload,
      "PANTRY-02.v4",
    );
    const command = pantryCompletionRequest(
      "actor",
      "correlation",
      1,
      payload,
      undefined,
      "PANTRY-02.v4",
    );
    expect(payload.rows[0]).not.toHaveProperty("pantry_need_purpose_id");
    expect(invoke.mock.calls[0][1]).toMatchObject({
      contract_version: "PANTRY-02.v4",
    });
    expect(invoke.mock.calls[1][1].payload.source_payload).toEqual({
      ...payload,
      source_contract_version: "PANTRY-02.v4",
    });
    expect(command.contract_version).toBe("PANTRY-02.v4");
  });
});
