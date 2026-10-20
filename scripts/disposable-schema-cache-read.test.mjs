// @vitest-environment node
import { expect, test, vi } from "vitest";
import { readAfterSchemaCacheStarts } from "./disposable-schema-cache-read.mjs";

const warming = { status: 503, error: { code: "PGRST002" }, data: null };
const boundedUntil = async (attempt, label) => {
  for (let i = 0; i < 3; i++) {
    const result = await attempt();
    if (result) return result;
  }
  throw new Error(label);
};
test("only retries the read while the disposable schema cache starts", async () => {
  const ready = { status: 200, error: null, data: { success: true } };
  const read = vi.fn().mockResolvedValueOnce(warming).mockResolvedValue(ready);
  expect(await readAfterSchemaCacheStarts(read, boundedUntil)).toBe(ready);
  expect(read).toHaveBeenCalledTimes(2);
});
test.each([
  { status: 403, error: { code: "42501" } },
  { status: 503, error: { code: "PGRST001" } },
  { status: 500, error: { code: "PGRST002" } },
  { status: 200, error: null, data: { success: false } },
])("returns every other failure unchanged: %j", async (response) => {
  const read = vi.fn().mockResolvedValue(response);
  expect(await readAfterSchemaCacheStarts(read, boundedUntil)).toBe(response);
  expect(read).toHaveBeenCalledTimes(1);
});
test("persistent schema-cache failure still exhausts the existing caller bound", async () => {
  const read = vi.fn().mockResolvedValue(warming);
  await expect(readAfterSchemaCacheStarts(read, boundedUntil)).rejects.toThrow(
    "INITIAL_SCHEMA_CACHE_READY",
  );
  expect(read).toHaveBeenCalledTimes(3);
});
