const SCALE = 1_000_000n;

/** Non-negative quantity input. Never round or coerce through Number. */
export function parseExactQuantity(value: string): bigint | null {
  const match = value.trim().match(/^(\d+)(?:\.(\d{0,6}))?$/);
  return match
    ? BigInt(match[1]!) * SCALE + BigInt((match[2] ?? "").padEnd(6, "0"))
    : null;
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

export function formatExactQuantityForOperator(
  value: string | bigint | null,
): string {
  const exact = typeof value === "string" ? parseExactQuantity(value) : value;
  if (exact === null) return "—";
  const absolute = exact < 0n ? -exact : exact;
  const fraction = String(absolute % SCALE)
    .padStart(6, "0")
    .replace(/0+$/, "");
  return `${exact < 0n ? "-" : ""}${absolute / SCALE}${fraction ? `,${fraction}` : ""}`;
}
