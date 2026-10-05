import { Box, Flex, Heading, Text } from "@chakra-ui/react";
import type { ReactNode, Ref } from "react";

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
  return (
    <Box
      as="header"
      role="region"
      aria-label={ariaLabel}
      bg="bg.context"
      borderBottomWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.default"
      flex="none"
      w="full"
      minH="var(--atlas-task-context-min-height, 56px)"
      px={{ base: "sm", lg: "md" }}
      py="sm"
    >
      <Flex
        minH="full"
        direction={{ base: "column", lg: "row" }}
        align={{ base: "flex-start", lg: "center" }}
        justify="space-between"
        gap={{ base: "xs", lg: "lg" }}
      >
        <Box minW="var(--atlas-layout-zero, 0)">
          <Heading
            as="h1"
            ref={headingRef}
            tabIndex={-1}
            textStyle="workbenchTitle"
            aria-description={moduleLabel}
          >
            {jobLabel}
          </Heading>
        </Box>
        <Text
          textStyle="table"
          fontWeight="medium"
          color="fg.primary"
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
