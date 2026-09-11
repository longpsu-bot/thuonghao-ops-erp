import { Box, Button, Text } from "@chakra-ui/react";
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
      bg={lock ? "bg.warning" : "bg.subtle"}
      aria-live="polite"
    >
      {lock === "unknown" && (
        <Text color="fg.primary">
          Chưa xác định được kết quả. Các thao tác ghi đang tạm khóa.
        </Text>
      )}
      {notice && <Text role="status">{notice}</Text>}
      {readError && (
        <Text role="alert" color="status.danger">
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
