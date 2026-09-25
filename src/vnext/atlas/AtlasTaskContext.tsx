import { Box, Flex, Heading, Text } from "@chakra-ui/react";
import type { CSSProperties, ReactNode, Ref } from "react";

type ContextDetail = {
  label: string;
  value: ReactNode;
};

export function AtlasTaskContext({
  ariaLabel,
  moduleLabel,
  jobLabel,
  details = [],
  headingRef,
}: {
  ariaLabel: string;
  moduleLabel: string;
  jobLabel: string;
  details?: ContextDetail[];
  headingRef?: Ref<HTMLHeadingElement>;
}) {
  const geometry = {
    "--atlas-task-context-desktop-width": "196px",
    "--atlas-task-context-mobile-height": "88px",
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
        base: "var(--atlas-task-context-mobile-height)",
        lg: "var(--atlas-layout-auto, auto)",
      }}
      minH={{ base: "var(--atlas-task-context-mobile-height)", lg: "full" }}
      overflow="hidden"
      px={{ base: "md", lg: "md" }}
      py={{ base: "sm", lg: "lg" }}
    >
      <Flex
        h="full"
        direction={{ base: "row", lg: "column" }}
        align={{ base: "center", lg: "stretch" }}
        gap={{ base: "md", lg: "lg" }}
      >
        <Box
          minW="var(--atlas-layout-zero, 0)"
          flex={{ base: "1", lg: "none" }}
        >
          <Text textStyle="helper" color="fg.muted">
            {moduleLabel}
          </Text>
          <Heading
            as="h1"
            ref={headingRef}
            tabIndex={-1}
            mt="xs"
            fontSize={{
              base: "var(--atlas-context-title-mobile, 20px)",
              lg: "var(--atlas-context-title-desktop, 24px)",
            }}
            lineHeight="var(--atlas-context-title-line-height, 1.2)"
            fontWeight="var(--atlas-context-title-weight, 650)"
          >
            {jobLabel}
          </Heading>
        </Box>
        {details.length > 0 && (
          <Flex
            direction="column"
            gap={{ base: "xs", lg: "md" }}
            minW="var(--atlas-layout-zero, 0)"
            flex={{ base: "none", lg: "1" }}
            align={{ base: "center", lg: "stretch" }}
          >
            {details.map((detail) => (
              <Box key={detail.label} minW="var(--atlas-layout-zero, 0)">
                <Text
                  display={{ base: "none", lg: "block" }}
                  textStyle="helper"
                  color="fg.muted"
                >
                  {detail.label}
                </Text>
                <Text
                  mt={{ base: "var(--atlas-layout-zero, 0)", lg: "xs" }}
                  fontSize={{
                    base: "var(--atlas-context-summary-mobile, 12px)",
                    lg: "var(--atlas-context-summary-desktop, 14px)",
                  }}
                  fontWeight="semibold"
                  lineClamp="1"
                  aria-label={`${detail.label}: ${typeof detail.value === "string" ? detail.value : ""}`}
                >
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
