import type { AllocationFamilyRow } from "./schoolCateringProcurementModel";

const QUANTITY_SCALE = 1_000_000n;

const stateLabels: Record<AllocationFamilyRow["state"], string> = {
  UNALLOCATED: "Chưa phân bổ",
  BALANCED: "Đã đủ",
  STALE_REBALANCE_AVAILABLE: "Có thể cân bằng lại",
  NEEDS_REALLOCATION: "Cần phân bổ lại",
  BLOCKED: "Đang bị chặn",
};

function quantity(value: string | number) {
  const exact = scaledQuantity(String(value));
  return exact === null ? String(value) : displayQuantity(exact);
}

function scaledQuantity(value: string) {
  const match = value.trim().match(/^(-?)(\d+)(?:\.(\d{0,6}))?$/);
  if (!match) return null;
  const magnitude =
    BigInt(match[2]!) * QUANTITY_SCALE +
    BigInt((match[3] ?? "").padEnd(6, "0"));
  return match[1] === "-" ? -magnitude : magnitude;
}

function displayQuantity(value: bigint) {
  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const integer = absolute / QUANTITY_SCALE;
  const fraction = String(absolute % QUANTITY_SCALE)
    .padStart(6, "0")
    .replace(/0+$/, "");
  return `${negative ? "-" : ""}${integer}${fraction ? `.${fraction}` : ""}`;
}

function allocated(row: AllocationFamilyRow) {
  return row.splits.reduce<bigint>(
    (total, split) => total + (scaledQuantity(split.allocated_quantity) ?? 0n),
    0n,
  );
}

function supplierLabel(row: AllocationFamilyRow) {
  if (row.splits.length)
    return row.splits.map((split) => split.supplier_name).join(", ");
  if (!row.recommendation) return "—";
  const recommendedSupplier = row.eligible_suppliers.find(
    (supplier) => supplier.supplier_id === row.recommendation?.supplier_id,
  );
  return recommendedSupplier
    ? `${recommendedSupplier.supplier_name} · đề xuất`
    : "Có đề xuất";
}

export function AllocationFamilyTable({
  rows,
  selectedFamilyKey,
  selectedRecommendationKeys,
  onSelect,
  onToggleRecommendation,
}: {
  rows: AllocationFamilyRow[];
  selectedFamilyKey: string | null;
  selectedRecommendationKeys: Set<string>;
  onSelect: (row: AllocationFamilyRow, trigger: HTMLButtonElement) => void;
  onToggleRecommendation: (row: AllocationFamilyRow, selected: boolean) => void;
}) {
  return (
    <div className="procurement-family-table-scroll">
      <table
        className="procurement-family-table"
        aria-label="Allocation Family"
      >
        <thead>
          <tr>
            <th aria-label="Chọn đề xuất" />
            <th>Ngày giao</th>
            <th>Trường / điểm giao</th>
            <th>Nguyên liệu</th>
            <th>Nhu cầu</th>
            <th>Đã phân bổ</th>
            <th>Còn lại / chênh lệch</th>
            <th>NCC</th>
            <th>Trạng thái</th>
            <th aria-label="Thao tác phân bổ" />
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => {
            const key = row.family.source_fingerprint;
            const assigned = allocated(row);
            const authoritative = scaledQuantity(row.family_quantity) ?? 0n;
            const difference = authoritative - assigned;
            return (
              <tr
                key={key}
                className={selectedFamilyKey === key ? "selected" : undefined}
              >
                <td>
                  {row.allowed_actions.confirm_recommendation && (
                    <input
                      type="checkbox"
                      aria-label={`Chọn đề xuất ${row.ingredient_name}`}
                      checked={selectedRecommendationKeys.has(key)}
                      onChange={(event) =>
                        onToggleRecommendation(row, event.target.checked)
                      }
                    />
                  )}
                </td>
                <td>{row.service_date.split("-").reverse().join("/")}</td>
                <td>
                  <strong>{row.school_name ?? row.location_name}</strong>
                  <small>{row.location_name}</small>
                </td>
                <td>
                  <strong>{row.ingredient_name}</strong>
                  <small className="procurement-master-support">
                    {row.contribution_count} nguồn bàn giao
                  </small>
                </td>
                <td>
                  {quantity(row.family_quantity)} {row.unit_code}
                </td>
                <td>
                  {displayQuantity(assigned)} {row.unit_code}
                </td>
                <td>
                  {displayQuantity(difference)} {row.unit_code}
                </td>
                <td>{supplierLabel(row)}</td>
                <td>
                  <span
                    className={`procurement-state ${row.state.toLowerCase()}`}
                  >
                    {stateLabels[row.state]}
                  </span>
                </td>
                <td>
                  <button
                    type="button"
                    className="secondary procurement-allocation-action"
                    aria-expanded={selectedFamilyKey === key}
                    onClick={(event) => onSelect(row, event.currentTarget)}
                  >
                    {row.state === "BALANCED" ? "Xem phân bổ" : "Phân bổ NCC"}
                  </button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
