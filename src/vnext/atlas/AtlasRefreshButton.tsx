import { Icon, IconButton } from "@chakra-ui/react";
import { ArrowClockwise } from "@phosphor-icons/react";
import { useEffect, useRef, useState } from "react";

export interface AtlasRefreshButtonProps {
  loading: boolean;
  disabled?: boolean;
  onClick: () => void;
}

export function AtlasRefreshButton({
  loading,
  disabled,
  onClick,
}: AtlasRefreshButtonProps) {
  const wasLoading = useRef(loading);
  const [complete, setComplete] = useState(false);
  useEffect(() => {
    const finished = wasLoading.current && !loading;
    wasLoading.current = loading;
    setComplete(finished);
    if (finished) {
      const timer = window.setTimeout(() => setComplete(false), 200);
      return () => window.clearTimeout(timer);
    }
  }, [loading]);

  return (
    <IconButton
      type="button"
      aria-label="Làm mới dữ liệu"
      title="Làm mới dữ liệu"
      aria-busy={loading}
      data-phase={loading ? "loading" : complete ? "complete" : "idle"}
      disabled={disabled || loading}
      onClick={onClick}
      variant="utility"
      w="compact"
      h="compact"
      minW="compact"
      flexShrink="0"
      p="var(--atlas-layout-zero, 0)"
      rounded="full"
      bg="bg.selected"
      color="fg.muted"
      _hover={{ bg: "bg.selected", color: "fg.primary" }}
      border="var(--atlas-layout-zero, 0)"
      animationStyle={complete && !loading ? "refreshComplete" : undefined}
    >
      <Icon
        asChild
        boxSize="18px"
        animationStyle={loading ? "refreshSpin" : undefined}
      >
        <ArrowClockwise aria-hidden="true" />
      </Icon>
    </IconButton>
  );
}
