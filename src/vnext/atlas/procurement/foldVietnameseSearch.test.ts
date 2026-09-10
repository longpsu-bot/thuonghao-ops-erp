import { expect, it } from "vitest";
import { foldVietnameseSearch } from "./foldVietnameseSearch";
it.each([
  ["Nguyễn Du", "nguyen"],
  ["Trần Phú", "tran"],
  ["Đặng", "DANG"],
  ["Nguyễn Du", "NGUYỄN"],
])("matches %s with %s", (name, query) => {
  expect(foldVietnameseSearch(name).includes(foldVietnameseSearch(query))).toBe(
    true,
  );
});
