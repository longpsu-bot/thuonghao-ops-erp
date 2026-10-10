import { Box, Button, Icon, Text } from "@chakra-ui/react";
import { Warning, WarningCircle } from "@phosphor-icons/react";
export function ConfirmedNeedCommandFeedback({
  lock,
  notice,
  readError,
  busy,
  onRecover,
}: {
  lock: string | null;
  notice: string | null;
  readError: string | null;
  busy: boolean;
  onRecover: () => void;
}) {
  if (!lock && !notice && !readError) return null;
  return (
    <Box
      p="sm"
      mx="md"
      mb="sm"
      bg={!lock && !readError ? "bg.subtle" : undefined}
      layerStyle={
        readError ? "feedbackDanger" : lock ? "feedbackWarning" : undefined
      }
      aria-live="polite"
    >
      {lock === "unknown" && !notice && !readError && (
        <Text color="fg.primary">
          <Icon asChild mr="xs">
            <Warning aria-hidden="true" />
          </Icon>
          Chưa xác định được kết quả. Các thao tác ghi đang tạm khóa.
        </Text>
      )}
      {notice && notice !== readError && <Text role="status">{notice}</Text>}
      {readError && (
        <Text role="alert" color="status.danger">
          <Icon asChild mr="xs">
            <WarningCircle aria-hidden="true" />
          </Icon>
          {readError}
        </Text>
      )}
      {lock && (
        <Button mt="xs" disabled={busy} onClick={onRecover}>
          {lock === "unknown"
            ? "Tải lại để xác nhận"
            : "Tải lại dữ liệu hiện tại"}
        </Button>
      )}
    </Box>
  );
}
