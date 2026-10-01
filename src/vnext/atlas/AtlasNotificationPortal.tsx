import { Box, CloseButton, Flex, Portal, Text } from "@chakra-ui/react";
import { useCallback, useEffect, useRef } from "react";
import { useAtlasPortalContainer } from "./AtlasVNextProvider";

export type AtlasNotificationMessage = {
  id: number;
  title: string;
  description: string;
};

export function AtlasNotificationPortal({
  message,
  onDismiss,
}: {
  message: AtlasNotificationMessage | null;
  onDismiss: () => void;
}) {
  const portalContainer = useAtlasPortalContainer();
  const remaining = useRef(7000);
  const startedAt = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const onDismissRef = useRef(onDismiss);
  onDismissRef.current = onDismiss;

  const stop = useCallback(() => {
    if (timer.current === null) return;
    clearTimeout(timer.current);
    timer.current = null;
    remaining.current = Math.max(
      0,
      remaining.current - (Date.now() - startedAt.current),
    );
  }, []);
  const start = useCallback(() => {
    if (!message || timer.current !== null) return;
    startedAt.current = Date.now();
    timer.current = setTimeout(() => onDismissRef.current(), remaining.current);
  }, [message?.id]);

  useEffect(() => {
    remaining.current = 7000;
    start();
    return stop;
  }, [message?.id, start, stop]);

  if (!message) return null;
  return (
    <Portal container={portalContainer}>
      <Box
        position="fixed"
        top={{
          base: "var(--atlas-notification-mobile-top, 104px)",
          lg: "var(--atlas-notification-desktop-top, 68px)",
        }}
        insetEnd={{ base: "sm", md: "md" }}
        zIndex="var(--atlas-layer-notification, 20)"
        w="var(--atlas-notification-width, min(360px, calc(100vw - 20px)))"
        maxW="var(--atlas-notification-max-width, calc(100vw - 20px))"
        bg="bg.workbench"
        color="fg.default"
        borderWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.default"
        borderRadius="control"
        boxShadow="notification"
        p="md"
        role="status"
        aria-live="polite"
        aria-label={`${message.title}. ${message.description}`}
        onPointerEnter={stop}
        onPointerLeave={start}
        onFocusCapture={stop}
        onBlurCapture={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node | null))
            start();
        }}
        animationStyle="detailEnter"
        _motionReduce={{ animation: "var(--atlas-layout-motion, none)" }}
      >
        <Flex align="start" justify="space-between" gap="sm">
          <Box minW="var(--atlas-layout-zero, 0)">
            <Text textStyle="label" color="fg.primary">
              {message.title}
            </Text>
            <Text mt="xs" textStyle="body">
              {message.description}
            </Text>
          </Box>
          <CloseButton
            size="sm"
            flexShrink="0"
            aria-label="Đóng thông báo"
            onClick={onDismiss}
          />
        </Flex>
      </Box>
    </Portal>
  );
}
