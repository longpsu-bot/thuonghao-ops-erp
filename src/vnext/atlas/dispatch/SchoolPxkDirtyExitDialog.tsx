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
  return (
    <Dialog.Root
      open={open}
      onOpenChange={(d) => {
        if (!d.open) onCancel();
      }}
      initialFocusEl={() => cancel.current}
      finalFocusEl={finalFocusEl}
      placement="center"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
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
