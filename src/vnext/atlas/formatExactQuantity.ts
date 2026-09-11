/** Presentation only: preserve every significant digit of the backend string. */
export function formatExactQuantity(value: string) {
  const [integer, fraction = ""] = value.split(".");
  const significant = fraction.replace(/0+$/, "");
  return significant ? `${integer},${significant}` : integer!;
}
/** Display the backend delta; never subtract or convert it to floating point. */
export function formatExactDelta(value: string) {
  if (/^-?0+(?:\.0+)?$/.test(value)) return "0";
  return `${value.startsWith("-") ? "" : "+"}${formatExactQuantity(value)}`;
}
