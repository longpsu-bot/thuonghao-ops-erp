import { Button, Dialog, Text } from "@chakra-ui/react";
import { useRef } from "react";
import type { IngredientSupplierWorkbenchController } from "./useIngredientSupplierWorkbench";

export function IngredientLifecycleDialog({
  c,
}: {
  c: IngredientSupplierWorkbenchController;
}) {
  const cancel = useRef<HTMLButtonElement>(null);
  if (c.activeSurface?.kind !== "lifecycle" || !c.selectedIngredient)
    return null;
  const status = c.activeSurface.status;
  const title =
    status === "INACTIVE"
      ? "Ngừng dùng nguyên liệu?"
      : status === "ARCHIVED"
        ? "Lưu trữ nguyên liệu?"
        : "Kích hoạt nguyên liệu?";
  return (
    <Dialog.Root
      open
      initialFocusEl={() => cancel.current}
      placement="center"
      onOpenChange={({ open }) =>
        !open && c.openIngredient(c.selectedIngredient!.ingredient_id)
      }
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
            <Dialog.Title>{title}</Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            {status === "INACTIVE" && (
              <>
                <Text>
                  Nguyên liệu vẫn được giữ lại nhưng không còn dùng trong vận
                  hành.
                </Text>
                <Text mt="sm" color="status.warning">
                  Các ưu tiên nhà cung ứng hiện tại sẽ được gỡ.
                </Text>
                <Text mt="xs">
                  Kích hoạt lại sau này không tự động khôi phục các ưu tiên cũ.
                </Text>
              </>
            )}
            {status === "ARCHIVED" && (
              <>
                <Text>
                  Thông tin được giữ lại để truy xuất. Nguyên liệu lưu trữ không
                  thể sửa hoặc kích hoạt lại.
                </Text>
                <Text mt="sm" color="status.warning">
                  Các ưu tiên nhà cung ứng hiện tại sẽ được gỡ.
                </Text>
              </>
            )}
            {status === "ACTIVE" && (
              <Text>
                Nguyên liệu sẽ trở lại trạng thái đang dùng. Hãy thiết lập ưu
                tiên nhà cung ứng mới nếu cần.
              </Text>
            )}
          </Dialog.Body>
          <Dialog.Footer flexWrap="wrap">
            <Button
              ref={cancel}
              onClick={() =>
                c.openIngredient(c.selectedIngredient!.ingredient_id)
              }
            >
              Hủy
            </Button>
            <Button
              variant={status === "ACTIVE" ? "businessPrimary" : "destructive"}
              loading={c.saving}
              onClick={() => void c.confirmLifecycle()}
            >
              Xác nhận
            </Button>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
