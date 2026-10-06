import { Box, Button, Icon, Text } from "@chakra-ui/react";
import { CheckCircle, Warning, WarningCircle } from "@phosphor-icons/react";
import type { ProcurementFeedback } from "./useProcurementWorkbench";

export function ProcurementCommandFeedback({
  feedback,
  busy,
  onReload,
  onRetry,
}: {
  feedback: ProcurementFeedback;
  busy: boolean;
  onReload: () => void;
  onRetry: () => void;
}) {
  const success = feedback.kind === "success";
  const blocked = feedback.kind === "blocked";
  return (
    <Box
      role={success ? "status" : "alert"}
      layerStyle={
        success
          ? "feedbackSuccess"
          : blocked
            ? "feedbackDanger"
            : "feedbackWarning"
      }
      p="sm"
      borderRadius="control"
      mx="md"
      my="sm"
    >
      <Text>
        <Icon asChild mr="xs">
          {success ? (
            <CheckCircle aria-hidden="true" />
          ) : blocked ? (
            <WarningCircle aria-hidden="true" />
          ) : (
            <Warning aria-hidden="true" />
          )}
        </Icon>
        {feedback.message}
      </Text>
      {feedback.messages.map((message) => (
        <Text key={message}>{message}</Text>
      ))}
      {(feedback.kind === "unknown" || feedback.kind === "stale") && (
        <Button mt="sm" size="sm" disabled={busy} onClick={onReload}>
          {feedback.kind === "unknown"
            ? "Tải lại để xác nhận"
            : "Tải lại dữ liệu hiện tại"}
        </Button>
      )}
      {feedback.kind === "retryable" && (
        <Button mt="sm" size="sm" disabled={busy} onClick={onRetry}>
          Thử lại thao tác
        </Button>
      )}
    </Box>
  );
}
