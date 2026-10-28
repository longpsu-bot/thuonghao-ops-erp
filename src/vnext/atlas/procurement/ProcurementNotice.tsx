import { Box, Flex, Icon, type FlexProps } from "@chakra-ui/react";
import { Warning, WarningCircle } from "@phosphor-icons/react";

/** Presentation only; callers retain the existing message and recovery behavior. */
export function ProcurementNotice({
  tone = "warning",
  children,
  ...props
}: FlexProps & { tone?: "warning" | "danger" }) {
  return (
    <Flex
      layerStyle={tone === "danger" ? "feedbackDanger" : "feedbackWarning"}
      align="start"
      gap="sm"
      p="sm"
      {...props}
    >
      <Icon asChild boxSize="5" flexShrink="0">
        {tone === "danger" ? (
          <WarningCircle aria-hidden="true" />
        ) : (
          <Warning aria-hidden="true" />
        )}
      </Icon>
      <Box minW="var(--atlas-layout-zero, 0)" flex="1" textStyle="body">
        {children}
      </Box>
    </Flex>
  );
}
