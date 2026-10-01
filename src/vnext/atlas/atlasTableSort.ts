export type AtlasSortDirection = "default" | "ascending" | "descending";

export type AtlasSortState<Key extends string> = {
  key: Key | null;
  direction: AtlasSortDirection;
};

export const atlasDefaultSort = {
  key: null,
  direction: "default",
} as const satisfies AtlasSortState<string>;

const vietnameseCollator = new Intl.Collator("vi", {
  sensitivity: "base",
  numeric: true,
});

export function compareAtlasText(
  left: string | null | undefined,
  right: string | null | undefined,
) {
  return vietnameseCollator.compare(left ?? "", right ?? "");
}

export function compareAtlasNumber(left: number, right: number) {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function compareAtlasBigInt(left: bigint | null, right: bigint | null) {
  if (left === right) return 0;
  if (left === null) return 1;
  if (right === null) return -1;
  return left < right ? -1 : 1;
}

export function nextAtlasSort<Key extends string>(
  current: AtlasSortState<Key>,
  key: Key,
): AtlasSortState<Key> {
  if (current.key !== key || current.direction === "default")
    return { key, direction: "ascending" };
  if (current.direction === "ascending")
    return { key, direction: "descending" };
  return { key: null, direction: "default" };
}

export function sortAtlasRows<Row, Key extends string>(
  rows: readonly Row[],
  sort: AtlasSortState<Key>,
  comparators: Record<Key, (left: Row, right: Row) => number>,
) {
  const projection = rows.map((row, originalIndex) => ({ row, originalIndex }));
  if (sort.direction === "default" || sort.key === null)
    return projection.map(({ row }) => row);

  const direction = sort.direction === "ascending" ? 1 : -1;
  return projection
    .sort((left, right) => {
      const result = comparators[sort.key!](left.row, right.row) * direction;
      return result || left.originalIndex - right.originalIndex;
    })
    .map(({ row }) => row);
}
