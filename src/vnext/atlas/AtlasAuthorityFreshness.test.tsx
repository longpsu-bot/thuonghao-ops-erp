import { act, cleanup, renderHook } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import {
  useAtlasAuthorityFreshness,
  useAtlasAuthorityRefresh,
} from "./AtlasModuleExit";

afterEach(cleanup);

it("does not refresh an unchanged retained owner", () => {
  const refresh = vi.fn();
  const { rerender } = renderHook(
    ({ revision }) => {
      const freshness = useAtlasAuthorityFreshness(revision);
      useAtlasAuthorityRefresh(freshness, false, refresh);
    },
    { initialProps: { revision: 0 } },
  );
  rerender({ revision: 0 });
  expect(refresh).not.toHaveBeenCalled();
});

it("does not acknowledge a newer commit with an older in-flight read", () => {
  const { result, rerender } = renderHook(
    ({ revision }) => useAtlasAuthorityFreshness(revision),
    { initialProps: { revision: 0 } },
  );
  const original = result.current.capture();
  rerender({ revision: 1 });
  act(() => result.current.acknowledge(original));
  expect(result.current.stale).toBe(true);
  const updated = result.current.capture();
  rerender({ revision: 2 });
  act(() => result.current.acknowledge(updated));
  expect(result.current.stale).toBe(true);
  act(() => result.current.acknowledge(result.current.capture()));
  expect(result.current.stale).toBe(false);
});

it("queues invalidation without reading or retrying while an owner is protected", () => {
  const refresh = vi.fn();
  const { result, rerender } = renderHook(
    ({ revision, protectedOwner }) => {
      const freshness = useAtlasAuthorityFreshness(revision);
      useAtlasAuthorityRefresh(freshness, protectedOwner, refresh);
      return freshness;
    },
    { initialProps: { revision: 0, protectedOwner: true } },
  );
  rerender({ revision: 1, protectedOwner: true });
  rerender({ revision: 2, protectedOwner: true });
  expect(result.current.stale).toBe(true);
  expect(refresh).not.toHaveBeenCalled();
  rerender({ revision: 2, protectedOwner: false });
  expect(refresh).toHaveBeenCalledOnce();
});
