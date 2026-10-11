export type AtlasOperatorDateRange = { start: string; end: string };
export const UI_MAX_RANGE_DAYS = 7;

/** UI read-scope limit only; backend range contracts are unchanged. */
export function operatorDateRangeError({
  start,
  end,
}: AtlasOperatorDateRange): string | null {
  const day = (value: string) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return NaN;
    const date = new Date(`${value}T00:00:00Z`);
    return Number.isNaN(date.valueOf()) ||
      date.toISOString().slice(0, 10) !== value
      ? NaN
      : date.valueOf();
  };
  const first = day(start);
  const last = day(end);
  if (!Number.isFinite(first) || !Number.isFinite(last))
    return "Chọn ngày hợp lệ.";
  if (last < first) return "Ngày kết thúc phải từ ngày bắt đầu.";
  if ((last - first) / 86_400_000 >= UI_MAX_RANGE_DAYS)
    return "Chọn tối đa 7 ngày.";
  return null;
}
