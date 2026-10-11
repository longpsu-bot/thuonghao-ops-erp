import {
  Box,
  Flex,
  type BoxProps,
  type FlexProps,
  type GridProps,
} from "@chakra-ui/react";
import type { RefAttributes } from "react";

type WorkbarProps = FlexProps &
  Pick<GridProps, "templateColumns"> &
  RefAttributes<HTMLDivElement>;

export const atlasWorkbarControlHeight = {
  base: "var(--atlas-layout-mobile-target, 44px)",
  lg: "control",
} as const;

/** Presentation only: labeled fields and grouped actions share a control baseline. */
export function AtlasWorkbar({ templateColumns, ...props }: WorkbarProps) {
  return (
    <Flex
      role="group"
      data-atlas-workbar=""
      alignItems="flex-end"
      flexWrap="wrap"
      gridTemplateColumns={templateColumns}
      gap="sm"
      minW="var(--atlas-layout-zero, 0)"
      css={{
        "& input:not([type=hidden]):not([type=checkbox]), & select, & [data-scope=date-input][data-part=segment-group], & button:not([data-scope=date-picker])":
          {
            height: atlasWorkbarControlHeight,
            minHeight: atlasWorkbarControlHeight,
          },
      }}
      {...props}
    />
  );
}

export function AtlasWorkbarField(
  props: BoxProps & RefAttributes<HTMLDivElement>,
) {
  return (
    <Box
      data-atlas-workbar-field=""
      minW="var(--atlas-layout-zero, 0)"
      {...props}
    />
  );
}

export function AtlasWorkbarActions(
  props: FlexProps & RefAttributes<HTMLDivElement>,
) {
  return (
    <Flex
      data-atlas-workbar-actions=""
      alignSelf="flex-end"
      alignItems="center"
      flexWrap="wrap"
      gap="sm"
      flexShrink="0"
      {...props}
    />
  );
}
