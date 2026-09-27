import { Box, type BoxProps } from "@chakra-ui/react";
import type { ReactNode } from "react";

export interface AtlasTableViewportProps extends Omit<BoxProps, "children"> {
  label: string;
  children: ReactNode;
}

export function AtlasTableViewport({
  label,
  children,
  ...props
}: AtlasTableViewportProps) {
  return (
    <Box
      role="region"
      aria-label={label}
      tabIndex={0}
      minW="var(--atlas-layout-zero, 0)"
      overflow="auto"
      {...props}
    >
      {children}
    </Box>
  );
}
