import { Box, Flex, Heading, Text } from "@chakra-ui/react";
import type { CSSProperties, ReactNode, Ref } from "react";

export type AtlasTaskContextDetail = {
  label: string;
  value: ReactNode;
};

export type AtlasTaskContextProps = {
  ariaLabel: string;
  moduleLabel: string;
  jobLabel: string;
  compactSummary: string;
  details?: AtlasTaskContextDetail[];
  headingRef?: Ref<HTMLHeadingElement>;
};

export function AtlasTaskContext({
  ariaLabel,
  moduleLabel,
  jobLabel,
  compactSummary,
  headingRef,
}: AtlasTaskContextProps) {
  const geometry = {
    "--atlas-task-context-desktop-min-height": "68px",
    "--atlas-task-context-desktop-target-height": "72px",
  } as CSSProperties;

  return (
    <Box
      as="header"
      role="region"
      aria-label={ariaLabel}
      style={geometry}
      bg="bg.context"
      borderBottomWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.default"
      flex="none"
      w="full"
      minH={{
        base: "var(--atlas-task-context-desktop-min-height)",
        lg: "var(--atlas-task-context-desktop-target-height)",
      }}
      px={{ base: "md", lg: "lg" }}
      py="xs"
    >
      <Flex
        minH="full"
        direction={{ base: "column", lg: "row" }}
        align={{ base: "flex-start", lg: "center" }}
        justify="space-between"
        gap={{ base: "xs", lg: "lg" }}
      >
        <Box minW="var(--atlas-layout-zero, 0)">
          <Text textStyle="helper" color="fg.muted">
            {moduleLabel}
          </Text>
          <Heading
            as="h1"
            ref={headingRef}
            tabIndex={-1}
            fontSize={{
              base: "var(--atlas-context-title-compact, 20px)",
              lg: "var(--atlas-context-title-desktop, 26px)",
            }}
            lineHeight="var(--atlas-context-title-line-height, 1.15)"
            fontWeight="var(--atlas-context-title-weight, 700)"
          >
            {jobLabel}
          </Heading>
        </Box>
        <Text
          textStyle="helper"
          color="fg.muted"
          textAlign={{ base: "left", lg: "right" }}
          whiteSpace={{ lg: "nowrap" }}
          aria-label={`Tóm tắt công việc: ${compactSummary}`}
        >
          {compactSummary}
        </Text>
      </Flex>
    </Box>
  );
}
