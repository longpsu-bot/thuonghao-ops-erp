import { EnvironmentProvider, useDatePickerContext } from "@chakra-ui/react";
import { useId, useLayoutEffect, useMemo, useRef, type ReactNode } from "react";
import { useAtlasWorkbenchActive } from "./AtlasVNextProvider";

/** Pinned Zag 1.43.3 announcer adapter; re-audit on dependency upgrades. */
export function AtlasDateEnvironment({ children }: { children: ReactNode }) {
  const active = useAtlasWorkbenchActive();
  const activeRef = useRef(active);
  activeRef.current = active;
  const announcerRef = useRef<HTMLSpanElement>(null);
  const id = useId();
  const environment = useMemo(() => {
    // Zag 1.43.3 uses a shared body announcer for both DateInput and DatePicker.
    // Keep native document/body operations intact; scope only that live region.
    const body = new Proxy(document.body, {
      get(target, key) {
        if (key === "appendChild")
          return <T extends Node>(node: T): T => {
            if (
              node instanceof HTMLElement &&
              node.hasAttribute("data-live-announcer")
            ) {
              node.id = `atlas-date-announcer-${id}`;
              if (activeRef.current) announcerRef.current?.appendChild(node);
              return node;
            }
            return target.appendChild(node);
          };
        const value = Reflect.get(target, key, target);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });
    return new Proxy(document, {
      get(target, key) {
        if (key === "body") return body;
        if (key === "getElementById")
          return (requestedId: string) =>
            requestedId === "__live-region__" ||
            requestedId === "__live-region-debug__"
              ? (announcerRef.current?.querySelector<HTMLElement>(
                  "[data-live-announcer]",
                ) ?? null)
              : target.getElementById(requestedId);
        const value = Reflect.get(target, key, target);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });
  }, [id]);
  useLayoutEffect(() => {
    if (!active) announcerRef.current?.replaceChildren();
  }, [active]);
  return (
    <EnvironmentProvider value={environment}>
      {children}
      <span
        ref={announcerRef}
        data-atlas-date-announcer-root=""
        hidden={!active}
        inert={!active}
      />
    </EnvironmentProvider>
  );
}

export function AtlasDismissInactiveCalendar() {
  const active = useAtlasWorkbenchActive();
  const picker = useDatePickerContext();
  useLayoutEffect(() => {
    if (!active && picker.open) picker.setOpen(false);
  }, [active, picker]);
  return null;
}
