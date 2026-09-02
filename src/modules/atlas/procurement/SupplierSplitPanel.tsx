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
  return Object.fromEntries(
    row.splits.flatMap((split) =>
      row.eligible_suppliers.some(
        (supplier) => supplier.supplier_id === split.supplier_id,
      )
        ? [[split.supplier_id, split.allocated_quantity]]
        : [],
    ),
  );
}

function initialParticipantIds(row: AllocationFamilyRow) {
  return row.splits.flatMap((split) =>
    row.eligible_suppliers.some(
      (supplier) => supplier.supplier_id === split.supplier_id,
    )
      ? [split.supplier_id]
      : [],
  );
}

const allocationDisabledReasonLabels: Record<string, string> = {
  NO_ELIGIBLE_SUPPLIER: "Chưa có nhà cung ứng phù hợp để lưu phân bổ.",
  NO_PRIORITIZED_SUPPLIER: "Chưa có nhà cung ứng ưu tiên để đề xuất phân bổ.",
  AMBIGUOUS_SUPPLIER_PRIORITY:
    "Có nhiều nhà cung ứng cùng mức ưu tiên; cần chọn thủ công.",
  SOURCE_CHANGED: "Phân bổ cần cập nhật theo nhu cầu mới trước khi lưu.",
  SUPPLIER_INELIGIBLE: "Có nhà cung ứng không còn phù hợp; cần phân bổ lại.",
};

function allocationDisabledReasonLabel(reason: string) {
  return (
    allocationDisabledReasonLabels[reason] ??
    "Máy chủ hiện không cho phép lưu phân bổ này."
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
  const [participantIds, setParticipantIds] = useState<string[]>(() =>
    initialParticipantIds(row),
  );
  const [operatorAddedIds, setOperatorAddedIds] = useState<Set<string>>(
    new Set(),
  );
  const [addingSupplier, setAddingSupplier] = useState(false);
  const [supplierToAdd, setSupplierToAdd] = useState("");
  const [draft, setDraft] = useState<Record<string, string>>(() =>
    initialDraft(row),
  );
  useEffect(() => {
    setDraft(initialDraft(row));
    setParticipantIds(initialParticipantIds(row));
    setOperatorAddedIds(new Set());
    setAddingSupplier(false);
    setSupplierToAdd("");
  }, [row]);
  const availableSuppliers = row.eligible_suppliers.filter(
    (supplier) => !participantIds.includes(supplier.supplier_id),
  );
  const participatingSuppliers = participantIds.flatMap((supplierId) => {
    const supplier = row.eligible_suppliers.find(
      (candidate) => candidate.supplier_id === supplierId,
    );
    return supplier ? [supplier] : [];
  });
  const total = useMemo(
    () =>
      participantIds.reduce<bigint | null>((sum, supplierId) => {
        const value = draft[supplierId] ?? "";
        const next = value ? scaled(value) : 0n;
        return sum === null || next === null ? null : sum + next;
      }, 0n),
    [draft, participantIds],
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
    row.allowed_actions.save_allocation &&
    !busy &&
    !mutationLocked &&
    difference === 0n &&
    participantIds.some(
      (supplierId) => (scaled(draft[supplierId] ?? "") ?? 0n) > 0n,
    );
  const backendDisabledMessages = row.allowed_actions.save_allocation
    ? []
    : Array.from(new Set([...row.blockers, ...row.disabled_reasons])).map(
        allocationDisabledReasonLabel,
      );

  return (
    <aside
      className="procurement-split-panel"
      role="region"
      aria-label={`Phân bổ ${row.ingredient_name}`}
    >
      <header>
        <div>
          <span>Nhu cầu đã chọn</span>
          <h3>{row.ingredient_name}</h3>
          <p>
            {row.school_name ?? row.location_name} · {row.location_name}
          </p>
        </div>
        <strong>
          {displayScaled(authoritativeTotal ?? 0n)} {row.unit_code}
        </strong>
      </header>

      {row.recommendation && (
        <section
          className="procurement-allocation-proposal"
          aria-label="Đề xuất nhà cung ứng"
        >
          <strong>Đề xuất</strong>
          <span>
            {row.eligible_suppliers.find(
              (supplier) =>
                supplier.supplier_id === row.recommendation?.supplier_id,
            )?.supplier_name ?? "Nhà cung ứng phù hợp"}{" "}
            ·{" "}
            {displayScaled(scaled(row.recommendation.allocated_quantity) ?? 0n)}{" "}
            {row.unit_code}
          </span>
          <button
            type="button"
            className="secondary"
            disabled={busy || mutationLocked}
            onClick={() => {
              const supplierId = row.recommendation!.supplier_id;
              setParticipantIds([supplierId]);
              setOperatorAddedIds(new Set([supplierId]));
              setDraft({
                [supplierId]: row.recommendation!.allocated_quantity,
              });
            }}
          >
            Dùng đề xuất
          </button>
        </section>
      )}
      {row.rebalance_proposal && (
        <section
          className="procurement-allocation-proposal"
          aria-label="Đề xuất cân bằng lại"
        >
          <strong>Đề xuất cân bằng lại</strong>
          <p>
            Phân bổ đã lưu vẫn được giữ nguyên cho đến khi bạn áp dụng và lưu đề
            xuất.
          </p>
          <ul>
            {row.rebalance_proposal.map((split) => (
              <li key={split.supplier_id}>
                {row.eligible_suppliers.find(
                  (supplier) => supplier.supplier_id === split.supplier_id,
                )?.supplier_name ?? split.supplier_id}
                : {displayScaled(scaled(split.allocated_quantity) ?? 0n)}{" "}
                {row.unit_code}
              </li>
            ))}
          </ul>
          <button
            type="button"
            className="secondary"
            disabled={busy || mutationLocked}
            onClick={() => {
              const proposal = row.rebalance_proposal ?? [];
              setParticipantIds(proposal.map((split) => split.supplier_id));
              setDraft(
                Object.fromEntries(
                  proposal.map((split) => [
                    split.supplier_id,
                    split.allocated_quantity,
                  ]),
                ),
              );
            }}
          >
            Áp dụng đề xuất
          </button>
        </section>
      )}
      {ineligibleSplits.map((split) => (
        <p className="procurement-inline-danger" key={split.supplier_id}>
          {split.supplier_name} không còn phù hợp (
          {displayScaled(scaled(split.allocated_quantity) ?? 0n)}{" "}
          {row.unit_code}). Atlas không tự chuyển phần đã phân bổ sang nhà cung
          ứng khác; cần chọn NCC thay thế thủ công.
        </p>
      ))}

      <div className="procurement-split-list">
        {participatingSuppliers.map((supplier) => {
          const current = row.splits.find(
            (split) => split.supplier_id === supplier.supplier_id,
          );
          return (
            <div className="procurement-split-row" key={supplier.supplier_id}>
              <span>
                <strong>{supplier.supplier_name}</strong>
                <small>
                  Ưu tiên {supplier.priority}
                  {current
                    ? ` · tỷ lệ đã lưu ${current.split_ratio} (tham khảo)`
                    : ""}
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
              {operatorAddedIds.has(supplier.supplier_id) && (
                <button
                  type="button"
                  className="secondary"
                  aria-label={`Xóa ${supplier.supplier_name}`}
                  disabled={busy || mutationLocked}
                  onClick={() => {
                    setParticipantIds((ids) =>
                      ids.filter((id) => id !== supplier.supplier_id),
                    );
                    setOperatorAddedIds((ids) => {
                      const next = new Set(ids);
                      next.delete(supplier.supplier_id);
                      return next;
                    });
                    setDraft((values) => {
                      const next = { ...values };
                      delete next[supplier.supplier_id];
                      return next;
                    });
                  }}
                >
                  Xóa
                </button>
              )}
            </div>
          );
        })}
        {participatingSuppliers.length === 0 && (
          <p className="procurement-empty">
            Chưa có nhà cung ứng trong bản nháp.
          </p>
        )}
      </div>

      <div className="procurement-add-supplier">
        <button
          type="button"
          className="secondary"
          disabled={availableSuppliers.length === 0 || busy || mutationLocked}
          onClick={() => {
            setAddingSupplier((current) => !current);
            setSupplierToAdd("");
          }}
        >
          + Thêm nhà cung ứng
        </button>
        {addingSupplier && availableSuppliers.length > 0 && (
          <div>
            <label>
              Nhà cung ứng đủ điều kiện
              <select
                value={supplierToAdd}
                onChange={(event) => setSupplierToAdd(event.target.value)}
              >
                <option value="">Chọn nhà cung ứng</option>
                {availableSuppliers.map((supplier) => (
                  <option
                    key={supplier.supplier_id}
                    value={supplier.supplier_id}
                  >
                    {supplier.supplier_name}
                  </option>
                ))}
              </select>
            </label>
            <button
              type="button"
              className="secondary"
              aria-label={`Thêm ${
                availableSuppliers.find(
                  (supplier) => supplier.supplier_id === supplierToAdd,
                )?.supplier_name ?? "nhà cung ứng"
              }`}
              disabled={!supplierToAdd || busy || mutationLocked}
              onClick={() => {
                setParticipantIds((ids) => [...ids, supplierToAdd]);
                setOperatorAddedIds((ids) => new Set(ids).add(supplierToAdd));
                setDraft((values) => ({ ...values, [supplierToAdd]: "" }));
                setAddingSupplier(false);
                setSupplierToAdd("");
              }}
            >
              Thêm
            </button>
          </div>
        )}
      </div>

      <div className="procurement-running-total" aria-live="polite">
        <span>
          Nhu cầu: {displayScaled(authoritativeTotal ?? 0n)} {row.unit_code}
        </span>
        <span>
          Đã phân bổ: {total === null ? "Không hợp lệ" : displayScaled(total)}{" "}
          {row.unit_code}
        </span>
        <span>
          Còn lại:{" "}
          {difference === null ? "Không hợp lệ" : displayScaled(difference)}{" "}
          {row.unit_code}
        </span>
      </div>

      {backendDisabledMessages.map((message) => (
        <p className="procurement-inline-danger" key={message}>
          {message}
        </p>
      ))}

      <button
        type="button"
        className="primary procurement-primary-action"
        disabled={!canSave}
        onClick={() =>
          onSave(
            participantIds.flatMap((supplierId) => {
              const value = draft[supplierId] ?? "";
              return (scaled(value) ?? 0n) > 0n
                ? [
                    {
                      supplier_id: supplierId,
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
