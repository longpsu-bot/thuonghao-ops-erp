const technicalUnitLabel = /^(?:v1-unit-|atlas[-_:]|unit[-_:])/i;
const unitUuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function humanUnitLabel(
  name: string | null | undefined,
  code: string | null | undefined,
): string | null {
  return (
    [name, code]
      .map((value) => value?.trim())
      .find(
        (value) =>
          value &&
          value !== "?" &&
          !technicalUnitLabel.test(value) &&
          !unitUuid.test(value) &&
          !/\p{Control}/u.test(value),
      ) ?? null
  );
}

export function operatorUnitLabel(
  name: string | null | undefined,
  code: string | null | undefined,
): string {
  return humanUnitLabel(name, code) ?? "Chưa có tên đơn vị";
}
