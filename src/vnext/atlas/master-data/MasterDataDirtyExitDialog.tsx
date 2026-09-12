import { Button, Dialog } from "@chakra-ui/react";
import { useRef } from "react";

export function MasterDataDirtyExitDialog({
  open,
  onCancel,
  onDiscard,
  onExitComplete,
}: {
  open: boolean;
  onCancel: () => void;
  onDiscard: () => void;
  onExitComplete: () => void;
}) {
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Dialog.Root
      open={open}
      initialFocusEl={() => cancel.current}
      onOpenChange={({ open: next }) => !next && onCancel()}
      onExitComplete={onExitComplete}
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
              Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Footer flexWrap="wrap">
            <Button ref={cancel} onClick={onCancel}>
              Tiếp tục chỉnh sửa
            </Button>
            <Button variant="destructive" onClick={onDiscard}>
              Bỏ thay đổi
            </Button>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
