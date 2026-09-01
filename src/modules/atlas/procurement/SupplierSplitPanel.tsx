import { useEffect, useMemo, useState } from "react";
import type {
  AllocationFamilyRow,
  SupplierSplitInput,
} from "./schoolCateringProcurementModel";

const SCALE = 1_000_000n;

function scaled(value: string) {
  const match = value.trim().match(/^(\d+)(?:\.(\d{0,6}))?$/);
  if (!match) return null;
  return BigInt(match[1]!) * SCALE + BigInt((match[2] ?? "").padEnd(6, "0"));
}

function displayScaled(value: bigint) {
  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const integer = absolute / SCALE;
  const fraction = String(absolute % SCALE)
    .padStart(6, "0")
    .replace(/0+$/, "");
  return `${negative ? "-" : ""}${integer}${fraction ? `.${fraction}` : ""}`;
}

function initialDraft(row: AllocationFamilyRow) {
  const proposal = row.rebalance_proposal ?? [];
  return Object.fromEntries(
    row.eligible_suppliers.map((supplier) => {
      const split = row.splits.find(
        (item) => item.supplier_id === supplier.supplier_id,
      );
      const proposed = proposal.find(
        (item) => item.supplier_id === supplier.supplier_id,
      );
      const recommended =
        row.recommendation?.supplier_id === supplier.supplier_id
          ? row.recommendation.allocated_quantity
          : "";
      return [
        supplier.supplier_id,
        proposed?.allocated_quantity ??
          split?.allocated_quantity ??
          recommended,
      ];
    }),
  );
}

export function SupplierSplitPanel({
  row,
  busy,
  mutationLocked,
  onSave,
}: {
  row: AllocationFamilyRow;
  busy: boolean;
  mutationLocked: boolean;
  onSave: (splits: SupplierSplitInput[]) => void;
}) {
  const [traceOpen, setTraceOpen] = useState(false);
  const [draft, setDraft] = useState<Record<string, string>>(() =>
    initialDraft(row),
  );
  useEffect(() => setDraft(initialDraft(row)), [row]);
  const total = useMemo(
    () =>
      Object.values(draft).reduce<bigint | null>((sum, value) => {
        const next = value ? scaled(value) : 0n;
        return sum === null || next === null ? null : sum + next;
      }, 0n),
    [draft],
  );
  const authoritativeTotal = scaled(String(row.family_quantity));
  const difference =
    total === null || authoritativeTotal === null
      ? null
      : authoritativeTotal - total;
  const ineligibleSplits = row.splits.filter(
    (split) =>
      !row.eligible_suppliers.some(
        (supplier) => supplier.supplier_id === split.supplier_id,
      ),
  );
  const canSave =
    !busy &&
    !mutationLocked &&
    difference === 0n &&
    Object.values(draft).some((value) => (scaled(value) ?? 0n) > 0n);

  return (
    <aside
      className="procurement-split-panel"
      role="region"
      aria-label={`Phân bổ ${row.ingredient_name}`}
    >
      <header>
        <div>
          <span>Allocation Family đã chọn</span>
          <h3>{row.ingredient_name}</h3>
          <p>
            {row.school_name ?? row.location_name} · {row.location_name}
          </p>
        </div>
        <strong>
          {displayScaled(authoritativeTotal ?? 0n)} {row.unit_code}
        </strong>
      </header>

      {row.rebalance_proposal && (
        <p className="procurement-inline-guidance">
          Atlas đề xuất giữ nguyên tỷ lệ trước đây. Hãy kiểm tra rồi lưu để xác
          nhận số lượng mới.
        </p>
      )}
      {ineligibleSplits.map((split) => (
        <p className="procurement-inline-danger" key={split.supplier_id}>
          {split.supplier_name} không còn phù hợp. Atlas không tự chuyển phần đã
          phân bổ sang nhà cung ứng khác.
        </p>
      ))}

      <div className="procurement-split-list">
        {row.eligible_suppliers.map((supplier) => {
          const current = row.splits.find(
            (split) => split.supplier_id === supplier.supplier_id,
          );
          return (
            <label key={supplier.supplier_id}>
              <span>
                <strong>{supplier.supplier_name}</strong>
                <small>
                  Ưu tiên {supplier.priority}
                  {current ? ` · tỷ lệ trước ${current.split_ratio}` : ""}
                </small>
              </span>
              <input
                inputMode="decimal"
                aria-label={`Phân bổ ${supplier.supplier_name}`}
                value={draft[supplier.supplier_id] ?? ""}
                onChange={(event) =>
                  setDraft((currentDraft) => ({
                    ...currentDraft,
                    [supplier.supplier_id]: event.target.value,
                  }))
                }
                disabled={busy || mutationLocked}
              />
              <span>{row.unit_code}</span>
            </label>
          );
        })}
      </div>

      <div className="procurement-running-total" aria-live="polite">
        <span>
          Tổng đang nhập:{" "}
          {total === null ? "Không hợp lệ" : displayScaled(total)}{" "}
          {row.unit_code}
        </span>
        <span>
          Chênh lệch:{" "}
          {difference === null ? "Không hợp lệ" : displayScaled(difference)}{" "}
          {row.unit_code}
        </span>
      </div>

      <button
        type="button"
        className="primary procurement-primary-action"
        disabled={!canSave}
        onClick={() =>
          onSave(
            row.eligible_suppliers.flatMap((supplier) => {
              const value = draft[supplier.supplier_id] ?? "";
              return (scaled(value) ?? 0n) > 0n
                ? [
                    {
                      supplier_id: supplier.supplier_id,
                      allocated_quantity: value,
                    },
                  ]
                : [];
            }),
          )
        }
      >
        Lưu phân bổ
      </button>

      <details className="procurement-trace" open={traceOpen}>
        <summary
          onClick={(event) => {
            event.preventDefault();
            setTraceOpen((current) => !current);
          }}
        >
          Dữ liệu truy vết
        </summary>
        {traceOpen && (
          <>
            <dl>
              <dt>Dấu vân tay nguồn</dt>
              <dd>{row.family.source_fingerprint}</dd>
              <dt>Family ID</dt>
              <dd>{row.family.family_id ?? "Chưa tạo"}</dd>
            </dl>
            <ul>
              {row.contributions.map((contribution) => (
                <li key={contribution.purchase_handoff_line_revision_id}>
                  {contribution.purchase_handoff_line_revision_id}
                </li>
              ))}
            </ul>
          </>
        )}
      </details>
    </aside>
  );
}
