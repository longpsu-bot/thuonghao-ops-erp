import { Box, Button, Text } from "@chakra-ui/react";
export function SchoolPxkCommandFeedback({
  lock,
  notice,
  readError,
  loading,
  onRecover,
}: {
  lock: "unknown" | "stale" | null;
  notice: string | null;
  readError: string | null;
  loading: boolean;
  onRecover: () => void;
}) {
  if (!notice && !readError && !lock) return null;
  return (
    <Box
      role={lock || readError ? "alert" : "status"}
      p="sm"
      mx="md"
      mt="sm"
      bg={lock ? "bg.warning" : readError ? "bg.danger" : "bg.success"}
    >
      <Text
        color={
          lock
            ? "status.warning"
            : readError
              ? "status.danger"
              : "status.success"
        }
      >
        {lock === "unknown"
          ? "Kết quả phát hành chưa được xác nhận."
          : (notice ?? readError)}
      </Text>
      {readError && notice && <Text textStyle="helper">{readError}</Text>}
      {(lock || readError) && (
        <Button mt="xs" size="sm" loading={loading} onClick={onRecover}>
          {lock === "unknown"
            ? "Tải lại để xác nhận"
            : lock === "stale"
              ? "Tải lại dữ liệu hiện tại"
              : "Thử tải lại dữ liệu"}
        </Button>
      )}
    </Box>
  );
}
