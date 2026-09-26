import { Box, Flex, Spinner, Text } from "@chakra-ui/react";
import { useEffect, useState } from "react";

export type AtlasOperation =
  | { status: "IDLE" }
  | { status: "RUNNING"; action: string; startedAt: number }
  | { status: "SUCCEEDED" | "UNKNOWN_OUTCOME"; message: string }
  | {
      status: "FAILED";
      message: string;
      failureKind?: "retryable" | "business";
    };

/** Presentation only: command identity, locks and readback belong to the caller. */
export function AtlasOperationStatus({
  operation,
}: {
  operation: AtlasOperation;
}) {
  const startedAt = operation.status === "RUNNING" ? operation.startedAt : null;
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    if (startedAt === null) return;
    setNow(Date.now());
    const timer = window.setInterval(() => setNow(Date.now()), 250);
    return () => window.clearInterval(timer);
  }, [startedAt]);
  const elapsed =
    startedAt === null ? 0 : Math.max(0, Math.floor((now - startedAt) / 1000));
  if (
    operation.status === "IDLE" ||
    (operation.status === "RUNNING" && elapsed < 2)
  )
    return null;
  return (
    <Box
      mx="md"
      mb="sm"
      p="sm"
      bg={
        operation.status === "FAILED" || operation.status === "UNKNOWN_OUTCOME"
          ? "bg.warning"
          : "bg.subtle"
      }
    >
      <Box role="status" aria-live="polite" aria-atomic="true">
        {operation.status === "RUNNING" ? (
          <>
            <Flex gap="sm" align="center">
              <Spinner size="sm" aria-hidden="true" />
              <Text>Đang xử lý… {operation.action}</Text>
            </Flex>
            {elapsed >= 15 && (
              <Text mt="xs">
                Tác vụ này có thể mất một chút thời gian. Vui lòng không gửi lại
                yêu cầu.
              </Text>
            )}
          </>
        ) : (
          <>
            <Text fontWeight="semibold">
              {operation.status === "SUCCEEDED"
                ? "✓ Hoàn tất"
                : operation.status === "UNKNOWN_OUTCOME"
                  ? "Chưa xác định kết quả"
                  : "Không thể hoàn tất"}
            </Text>
            <Text>{operation.message}</Text>
          </>
        )}
      </Box>
      {/* Visual ticking stays outside the live region; only state/stage changes announce. */}
      {operation.status === "RUNNING" && (
        <Text textStyle="helper" color="fg.muted" aria-live="off">
          Đã xử lý {elapsed} giây
        </Text>
      )}
    </Box>
  );
}
