/** Presentation only: preserve every significant digit of the backend string. */
export function schoolPxkQuantity(value: string) {
  const [integer, fraction = ""] = value.split(".");
  const significant = fraction.replace(/0+$/, "");
  return significant ? `${integer},${significant}` : integer!;
}
