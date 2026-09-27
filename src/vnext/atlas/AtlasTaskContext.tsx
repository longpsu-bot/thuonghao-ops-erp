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
  details = [],
  headingRef,
}: AtlasTaskContextProps) {
  const geometry = {
    "--atlas-task-context-desktop-width": "196px",
    "--atlas-task-context-compact-height": "88px",
  } as CSSProperties;

  return (
    <Box
      as="aside"
      aria-label={ariaLabel}
      style={geometry}
      bg="bg.context"
      borderRightWidth={{
        base: "var(--atlas-layout-zero, 0)",
        lg: "var(--atlas-layout-edge, 1px)",
      }}
      borderBottomWidth={{
        base: "var(--atlas-layout-edge, 1px)",
        lg: "var(--atlas-layout-zero, 0)",
      }}
      borderColor="border.default"
      flex="none"
      w={{ base: "full", lg: "var(--atlas-task-context-desktop-width)" }}
      h={{
        base: "var(--atlas-task-context-compact-height)",
        lg: "var(--atlas-layout-auto, auto)",
      }}
      minH={{
        base: "var(--atlas-task-context-compact-height)",
        lg: "full",
      }}
      overflow="hidden"
      px="md"
      py={{ base: "xs", lg: "lg" }}
    >
      <Flex h="full" direction="column" justify="center" gap="xs">
        <Text textStyle="helper" color="fg.muted">
          {moduleLabel}
        </Text>
        <Heading
          as="h1"
          ref={headingRef}
          tabIndex={-1}
          fontSize={{
            base: "var(--atlas-context-title-compact, 20px)",
            lg: "var(--atlas-context-title-desktop, 24px)",
          }}
          lineHeight="var(--atlas-context-title-line-height, 1.2)"
          fontWeight="var(--atlas-context-title-weight, 650)"
        >
          {jobLabel}
        </Heading>
        <Text
          display={{ base: "block", lg: "none" }}
          textStyle="helper"
          color="fg.muted"
          lineClamp="1"
          aria-label={`Tóm tắt công việc: ${compactSummary}`}
        >
          {compactSummary}
        </Text>
        {details.length > 0 && (
          <Flex
            display={{ base: "none", lg: "flex" }}
            direction="column"
            gap="md"
            mt="md"
            minW="var(--atlas-layout-zero, 0)"
          >
            {details.map((detail) => (
              <Box key={detail.label} minW="var(--atlas-layout-zero, 0)">
                <Text textStyle="helper" color="fg.muted">
                  {detail.label}
                </Text>
                <Text mt="xs" textStyle="body" fontWeight="semibold">
                  {detail.value}
                </Text>
              </Box>
            ))}
          </Flex>
        )}
      </Flex>
    </Box>
  );
}
