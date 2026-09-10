import { Button, Dialog } from "@chakra-ui/react";
export function PlanningDirtyExitDialog({
  open,
  wholeWeek,
  onCancel,
  onDiscard,
}: {
  open: boolean;
  wholeWeek: boolean;
  onCancel: () => void;
  onDiscard: () => void;
}) {
  return (
    <Dialog.Root
      open={open}
      onOpenChange={(d) => {
        if (!d.open) onCancel();
      }}
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
              {wholeWeek
                ? "Bỏ các dòng bổ sung của toàn tuần?"
                : "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?"}
            </Dialog.Title>
          </Dialog.Header>
          {wholeWeek && (
            <Dialog.Body>
              Xác nhận toàn tuần không có bổ sung sẽ bỏ các dòng đang có.
            </Dialog.Body>
          )}
          <Dialog.Footer flexWrap="wrap">
            <Button onClick={onCancel}>Tiếp tục chỉnh sửa</Button>
            <Button variant="destructive" onClick={onDiscard}>
              Bỏ thay đổi
            </Button>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
