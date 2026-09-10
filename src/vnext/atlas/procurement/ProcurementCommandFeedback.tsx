import { Box, Button, Text } from "@chakra-ui/react";
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
  return (
    <Box
      role={success ? "status" : "alert"}
      bg={success ? "bg.success" : "bg.warning"}
      color={success ? "status.success" : "status.warning"}
      p="sm"
      borderRadius="control"
      mx="md"
      my="sm"
    >
      <Text>
        {!success && "⚠ "}
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
