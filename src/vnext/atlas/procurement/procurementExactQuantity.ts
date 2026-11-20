const SCALE = 1_000_000n;

/** Non-negative quantity input. Never round or coerce through Number. */
export function parseExactQuantity(value: string): bigint | null {
  const match = value.trim().match(/^(\d+)(?:[.,](\d{0,6}))?$/);
  return match
    ? BigInt(match[1]!) * SCALE + BigInt((match[2] ?? "").padEnd(6, "0"))
    : null;
}

/** Canonical six-place API quantity, without locale separators or rounding. */
export function serializeExactQuantity(value: string): string | null {
  const exact = parseExactQuantity(value);
  return exact === null
    ? null
    : `${exact / SCALE}.${String(exact % SCALE).padStart(6, "0")}`;
}

export function sumExactQuantities(values: string[]): bigint | null {
  let sum = 0n;
  for (const value of values) {
    const next = parseExactQuantity(value);
    if (next === null) return null;
    sum += next;
  }
  return sum;
}

/** Plan a share in the same millionths used by the allocation command. */
export function quantityFromPercent(
  need: bigint,
  input: string,
): bigint | null {
  const percent = parseExactQuantity(input);
  const hundred = 100n * SCALE;
  return percent === null || percent > hundred
    ? null
    : (need * percent + hundred / 2n) / hundred;
}

export function displayPercent(allocated: bigint | null, need: bigint): string {
  if (allocated === null || need === 0n) return "";
  return formatExactQuantityForOperator(
    (allocated * 100n * SCALE + need / 2n) / need,
    ".",
  );
}

export function formatExactQuantityForOperator(
  value: string | bigint | null,
  separator: "." | "," = ",",
): string {
  const exact = typeof value === "string" ? parseExactQuantity(value) : value;
  if (exact === null) return "—";
  const absolute = exact < 0n ? -exact : exact;
  const fraction = String(absolute % SCALE)
    .padStart(6, "0")
    .replace(/0+$/, "");
  return `${exact < 0n ? "-" : ""}${absolute / SCALE}${fraction ? `${separator}${fraction}` : ""}`;
}
