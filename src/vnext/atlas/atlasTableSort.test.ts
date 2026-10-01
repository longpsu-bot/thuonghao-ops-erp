import { describe, expect, it } from "vitest";
import {
  atlasDefaultSort,
  compareAtlasBigInt,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
} from "./atlasTableSort";

type Row = { id: string; label: string; exact: bigint };
type Key = "label" | "exact";

const comparators = {
  label: (left: Row, right: Row) => compareAtlasText(left.label, right.label),
  exact: (left: Row, right: Row) => compareAtlasBigInt(left.exact, right.exact),
} satisfies Record<Key, (left: Row, right: Row) => number>;

describe("Atlas table sorting", () => {
  it("cycles one column from business order through ascending and descending", () => {
    const ascending = nextAtlasSort(atlasDefaultSort, "label");
    expect(ascending).toEqual({ key: "label", direction: "ascending" });
    const descending = nextAtlasSort(ascending, "label");
    expect(descending).toEqual({ key: "label", direction: "descending" });
    expect(nextAtlasSort(descending, "label")).toEqual(atlasDefaultSort);
    expect(nextAtlasSort(descending, "exact")).toEqual({
      key: "exact",
      direction: "ascending",
    });
  });

  it("uses Vietnamese numeric text order, keeps ties stable, and never mutates source rows", () => {
    const rows: Row[] = [
      { id: "b", label: "Trường 10", exact: 2n },
      { id: "a", label: "Trường 2", exact: 1n },
      { id: "a-tie", label: "Trường 2", exact: 3n },
    ];
    const sourceOrder = [...rows];

    expect(
      sortAtlasRows(
        rows,
        { key: "label", direction: "ascending" },
        comparators,
      ).map((row) => row.id),
    ).toEqual(["a", "a-tie", "b"]);
    expect(rows).toEqual(sourceOrder);
    expect(sortAtlasRows(rows, atlasDefaultSort, comparators)).not.toBe(rows);
  });

  it("compares exact quantities beyond Number precision as bigint", () => {
    const rows: Row[] = [
      { id: "larger", label: "B", exact: 9_007_199_254_740_993n },
      { id: "smaller", label: "A", exact: 9_007_199_254_740_992n },
    ];
    expect(
      sortAtlasRows(
        rows,
        { key: "exact", direction: "ascending" },
        comparators,
      ).map((row) => row.id),
    ).toEqual(["smaller", "larger"]);
  });
});
