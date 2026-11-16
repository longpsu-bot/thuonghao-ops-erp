import { Box, Flex, Heading, Icon, Text } from "@chakra-ui/react";
import type { ReactNode, Ref } from "react";
import { useAtlasWorkbenchIcon } from "./AtlasVNextProvider";

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
  const WorkbenchIcon = useAtlasWorkbenchIcon();
  return (
    <Box
      as="header"
      role="region"
      aria-label={ariaLabel}
      bg="bg.workbench"
      borderBottomWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
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
        <Flex minW="var(--atlas-layout-zero, 0)" align="center" gap="sm">
          {WorkbenchIcon && (
            <Flex
              aria-hidden="true"
              display={{ base: "none", lg: "flex" }}
              align="center"
              justify="center"
              boxSize="compact"
              flexShrink="0"
              borderRadius="control"
              bg="bg.context"
              color="fg.brand"
            >
              <Icon asChild boxSize="var(--atlas-workspace-icon-size, 20px)">
                <WorkbenchIcon weight="duotone" />
              </Icon>
            </Flex>
          )}
          <Heading
            as="h1"
            ref={headingRef}
            tabIndex={-1}
            textStyle="workbenchTitle"
            color="fg.brand"
            overflowWrap="anywhere"
            aria-description={moduleLabel}
          >
            {jobLabel}
          </Heading>
        </Flex>
        <Text
          textStyle="label"
          fontWeight="normal"
          color="fg.secondary"
          textAlign={{ base: "left", lg: "right" }}
          ps={{ lg: "md" }}
          borderInlineStartWidth={{ lg: "var(--atlas-layout-edge, 1px)" }}
          borderColor="border.subtle"
          overflowWrap="anywhere"
          aria-label={`Tóm tắt công việc: ${compactSummary}`}
        >
          {compactSummary}
        </Text>
      </Flex>
    </Box>
  );
}
