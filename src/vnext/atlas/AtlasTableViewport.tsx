import { Box, type BoxProps } from "@chakra-ui/react";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
  type UIEvent,
} from "react";

export interface AtlasTableViewportProps extends Omit<BoxProps, "children"> {
  label: string;
  children: ReactNode;
}

export function AtlasTableViewport({
  label,
  children,
  onScroll,
  ...props
}: AtlasTableViewportProps) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const [continuation, setContinuation] = useState({
    start: false,
    end: false,
  });
  const measureContinuation = useCallback(() => {
    const viewport = viewportRef.current;
    if (!viewport) return;
    const overflows = viewport.scrollWidth > viewport.clientWidth + 1;
    const next = {
      start: overflows && viewport.scrollLeft > 1,
      end:
        overflows &&
        viewport.scrollLeft + viewport.clientWidth < viewport.scrollWidth - 1,
    };
    setContinuation((current) =>
      current.start === next.start && current.end === next.end ? current : next,
    );
  }, []);

  useEffect(() => {
    measureContinuation();
  });

  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport) return;
    const observer =
      typeof ResizeObserver === "undefined"
        ? null
        : new ResizeObserver(measureContinuation);
    observer?.observe(viewport);
    if (viewport.firstElementChild)
      observer?.observe(viewport.firstElementChild);
    window.addEventListener("resize", measureContinuation);
    return () => {
      observer?.disconnect();
      window.removeEventListener("resize", measureContinuation);
    };
  }, [measureContinuation]);

  const handleScroll = (event: UIEvent<HTMLDivElement>) => {
    measureContinuation();
    onScroll?.(event);
  };

  return (
    <Box position="relative" minW="var(--atlas-layout-zero, 0)">
      <Box
        ref={viewportRef}
        role="region"
        aria-label={label}
        tabIndex={0}
        minW="var(--atlas-layout-zero, 0)"
        overflow="auto"
        onScroll={handleScroll}
        {...props}
      >
        {children}
      </Box>
      {continuation.start && (
        <Box
          data-testid="table-continuation-start"
          aria-hidden="true"
          pointerEvents="none"
          position="absolute"
          insetBlock="var(--atlas-layout-zero, 0)"
          left="var(--atlas-layout-zero, 0)"
          w="6"
          zIndex="var(--atlas-layout-sticky-header-z, 3)"
          style={{
            background:
              "linear-gradient(to left, transparent, var(--chakra-colors-bg-workbench))",
          }}
        />
      )}
      {continuation.end && (
        <Box
          data-testid="table-continuation-end"
          aria-hidden="true"
          pointerEvents="none"
          position="absolute"
          insetBlock="var(--atlas-layout-zero, 0)"
          right="var(--atlas-layout-zero, 0)"
          w="6"
          zIndex="var(--atlas-layout-sticky-header-z, 3)"
          style={{
            background:
              "linear-gradient(to right, transparent, var(--chakra-colors-bg-workbench))",
          }}
        />
      )}
    </Box>
  );
}
