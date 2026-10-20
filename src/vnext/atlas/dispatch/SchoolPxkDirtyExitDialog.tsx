import { Button, Dialog } from "@chakra-ui/react";
import { useRef } from "react";
export function SchoolPxkDirtyExitDialog({
  open,
  onCancel,
  onDiscard,
  finalFocusEl,
}: {
  open: boolean;
  onCancel: () => void;
  onDiscard: () => void;
  finalFocusEl: () => HTMLElement | null;
}) {
  const cancel = useRef<HTMLButtonElement>(null);
  const content = useRef<HTMLDivElement>(null);
  return (
    <Dialog.Root
      open={open}
      onOpenChange={(d) => {
        if (!d.open) onCancel();
      }}
      initialFocusEl={() => cancel.current}
      finalFocusEl={finalFocusEl}
      // Quick Cancel can close before the focus trap activates. Resolve the
      // destination after exit, including a remounted calendar trigger.
      onExitComplete={() => {
        const target = finalFocusEl();
        const active = document.activeElement;
        if (
          target?.isConnected &&
          !target.closest('[hidden], [inert], [aria-hidden="true"]') &&
          (!active ||
            active === document.body ||
            content.current?.contains(active))
        )
          target.focus();
      }}
      placement="center"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          ref={content}
          bg="bg.workbench"
          color="fg.default"
          borderRadius="workbench"
          mx="md"
        >
          <Dialog.Header>
            <Dialog.Title>
              Có ghi chú chưa phát hành. Bỏ ghi chú và tiếp tục?
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Footer flexWrap="wrap">
            <Button ref={cancel} onClick={onCancel}>
              Tiếp tục chỉnh sửa
            </Button>
            <Button variant="destructive" onClick={onDiscard}>
              Bỏ ghi chú
            </Button>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
