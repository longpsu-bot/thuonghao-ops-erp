import {
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
  type Ref,
} from "react";

export type AtlasPageTransitionHandle = {
  isActive: () => boolean;
  start: (commitNavigation: () => void) => void;
};

// Only authorized primary navigation enters this boundary. Domain workbenches
// retain ownership of every dirty/recovery decision before start is called.
export function AtlasPageTransition({
  children,
  ref,
}: {
  children: ReactNode;
  ref: Ref<AtlasPageTransitionHandle>;
}) {
  const surface = useRef<HTMLDivElement>(null);
  const [phase, setPhase] = useState<"idle" | "exiting" | "entering">("idle");
  const locked = useRef(false);
  const pending = useRef<(() => void) | null>(null);
  const focusPending = useRef(false);
  const reservedHeight = useRef(0);

  useImperativeHandle(ref, () => ({
    isActive: () => locked.current,
    start: (commitNavigation) => {
      if (locked.current) return;
      locked.current = true;
      focusPending.current = true;
      if (
        window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ||
        !surface.current?.animate
      ) {
        commitNavigation();
        return;
      }
      reservedHeight.current = surface.current.getBoundingClientRect().height;
      pending.current = commitNavigation;
      setPhase("exiting");
    },
  }));

  useLayoutEffect(() => {
    if (phase === "idle") return;
    const animation = surface.current!.animate(
      phase === "exiting"
        ? [{ opacity: 1 }, { opacity: 0 }]
        : [
            { opacity: 0, transform: "translateY(8px)" },
            { opacity: 1, transform: "translateY(0)" },
          ],
      {
        duration: phase === "exiting" ? 80 : 200,
        easing: "ease-out",
        fill: "both",
      },
    );
    animation.onfinish = () => {
      if (phase === "exiting") {
        pending.current?.();
        pending.current = null;
        setPhase("entering");
      } else setPhase("idle");
    };
    return () => {
      animation.onfinish = null;
      animation.cancel();
    };
  }, [phase]);

  useLayoutEffect(() => {
    // Preference changes also remove an already-running transition immediately.
    const media = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    const reduce = () => {
      if (!media?.matches || !locked.current) return;
      pending.current?.();
      pending.current = null;
      setPhase("idle");
    };
    media?.addEventListener("change", reduce);
    return () => media?.removeEventListener("change", reduce);
  }, []);

  useLayoutEffect(() => {
    if (phase !== "idle" || !focusPending.current) return;
    locked.current = false;
    focusPending.current = false;
    const heading = surface.current?.querySelector("h1");
    heading?.setAttribute("tabindex", "-1");
    heading?.focus({ preventScroll: true });
  });

  return (
    <div
      style={
        phase === "idle"
          ? undefined
          : { minHeight: reservedHeight.current, overflow: "clip" }
      }
    >
      <div ref={surface} data-atlas-page-phase={phase} inert={phase !== "idle"}>
        {children}
      </div>
    </div>
  );
}
