import { describe, expect, it, vi } from "vitest";
import { saveLocalConfirmedAllocations } from "./local-confirmed-supplier-allocation.mjs";

const subject = "b6000000-0000-0000-0000-000000000101";
const batch = "b6500000-0000-0000-0000-000000000050";
const workbench = {
  confirmed_need_batch_id: batch,
  service_period: { period_start: "2026-11-02", period_end: "2026-11-02" },
};
const row = {
  complete: true,
  state: "UNALLOCATED",
  family_quantity: "90071992547409.123456",
  service_date: "2026-11-02",
  delivery_location_id: subject,
  ingredient_id: subject,
  unit_id: subject,
  family: {
    version: 0,
    source_fingerprint: "exact-fingerprint",
    source_confirmed_need_batch_id: batch,
    source_confirmed_need_batch_version: 2,
  },
};

describe("local-only confirmed allocation prerequisites", () => {
  it("seeds only local eligibility and saves exact authoritative quantities via the public command", async () => {
    const seed = vi.fn();
    const invoke = vi
      .fn()
      .mockResolvedValueOnce({ rows: [row] })
      .mockResolvedValue({ success: true });
    await saveLocalConfirmedAllocations({}, subject, workbench, invoke, seed);
    expect(seed).toHaveBeenCalledOnce();
    expect(seed.mock.calls[0][0]).toMatch(
      /^do \$local_confirmed_allocation\$\s+begin\b/,
    );
    expect(seed.mock.calls[0][0]).toMatch(
      /end; \$local_confirmed_allocation\$;$/,
    );
    expect(seed.mock.calls[0][0]).not.toMatch(/[\r\n]/);
    expect(seed.mock.calls[0][0]).toContain("supplier_eligibilities");
    expect(seed.mock.calls[0][0]).not.toContain("allocation_family_revisions");
    expect(invoke.mock.calls[0][1]).toBe(
      "get_confirmed_supplier_allocation_workbench",
    );
    expect(invoke.mock.calls[1][1]).toBe("save_confirmed_supplier_allocation");
    expect(invoke.mock.calls[1][2]).toMatchObject({
      expected_version: 0,
      payload: {
        family: {
          expected_source_batch_id: batch,
          expected_source_batch_version: 2,
          expected_source_fingerprint: "exact-fingerprint",
        },
        splits: [
          {
            supplier_id: "c7100000-0000-4000-8000-000000000001",
            allocated_quantity: "90071992547409.123456",
          },
        ],
      },
    });
  });
  it("does not resave balanced or unrelated batch rows", async () => {
    const invoke = vi.fn().mockResolvedValue({
      rows: [
        { ...row, state: "BALANCED" },
        {
          ...row,
          family: { ...row.family, source_confirmed_need_batch_id: subject },
        },
      ],
    });
    await saveLocalConfirmedAllocations(
      {},
      subject,
      workbench,
      invoke,
      vi.fn(),
    );
    expect(invoke).toHaveBeenCalledOnce();
  });
  it("never substitutes a generated quantity for incomplete confirmed Need", async () => {
    const invoke = vi.fn().mockResolvedValue({
      rows: [{ ...row, complete: false, family_quantity: null }],
    });
    await expect(
      saveLocalConfirmedAllocations({}, subject, workbench, invoke, vi.fn()),
    ).rejects.toThrow("incomplete");
    expect(invoke).toHaveBeenCalledOnce();
  });
  it("rejects unsafe fixture identity before local SQL or RPC", async () => {
    const seed = vi.fn();
    const invoke = vi.fn();
    await expect(
      saveLocalConfirmedAllocations({}, "not-a-uuid", workbench, invoke, seed),
    ).rejects.toThrow("UUIDs");
    expect(seed).not.toHaveBeenCalled();
    expect(invoke).not.toHaveBeenCalled();
  });
});
