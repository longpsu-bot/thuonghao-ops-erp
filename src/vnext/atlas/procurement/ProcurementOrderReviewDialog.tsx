import {
  Box,
  Button,
  Dialog,
  Flex,
  Portal,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useRef } from "react";
import { useAtlasPortalContainer } from "../AtlasVNextProvider";
import type { SchoolCateringPurchaseOrder } from "../bridges/procurement";

export type OrderReviewAction = "release" | "xlsx" | "pdf";
export type OrderReview = {
  action: OrderReviewAction;
  orders: SchoolCateringPurchaseOrder[];
  scopeLabel: string;
};

export function ProcurementOrderReviewDialog({
  review,
  changed,
  disabled,
  onClose,
  onConfirm,
  returnFocusEl,
}: {
  review: OrderReview | null;
  changed: boolean;
  disabled: boolean;
  onClose: () => void;
  onConfirm: () => void;
  returnFocusEl: () => HTMLElement | null;
}) {
  const back = useRef<HTMLButtonElement>(null);
  const portal = useAtlasPortalContainer();
  const release = review?.action === "release";
  const format = review?.action.toUpperCase();
  return (
    <Dialog.Root
      open={Boolean(review)}
      onOpenChange={({ open }) => {
        if (!open) onClose();
      }}
      initialFocusEl={() => back.current}
      finalFocusEl={returnFocusEl}
      placement="center"
      scrollBehavior="inside"
      motionPreset="none"
      lazyMount
      unmountOnExit
    >
      <Portal container={portal}>
        <Dialog.Backdrop
          bg="bg.navigation"
          opacity="var(--atlas-layout-backdrop-opacity, 0.45)"
        />
        <Dialog.Positioner p="md">
          <Dialog.Content
            bg="bg.workbench"
            color="fg.default"
            borderRadius="workbench"
          >
            {review && (
              <>
                <Dialog.Header>
                  <Stack gap="xs">
                    <Dialog.Title textStyle="section">
                      {release
                        ? "Đơn mua sẽ phát hành"
                        : `Đơn mua sẽ xuất ${format}`}
                    </Dialog.Title>
                    <Dialog.Description color="fg.secondary" textStyle="helper">
                      {review.scopeLabel}
                    </Dialog.Description>
                  </Stack>
                </Dialog.Header>
                <Dialog.Body>
                  <Stack
                    as="ul"
                    aria-label="Danh sách đơn mua"
                    gap="0"
                    listStyleType="none"
                    p="0"
                  >
                    {review.orders.map((order) => (
                      <Flex
                        as="li"
                        key={order.purchase_order_id}
                        gap="md"
                        justify="space-between"
                        py="sm"
                        borderBottomWidth="var(--atlas-layout-edge, 1px)"
                        borderColor="border.subtle"
                      >
                        <Box minW="0">
                          <Text textStyle="label" overflowWrap="anywhere">
                            {order.current_revision.supplier_name_snapshot ??
                              order.supplier.supplier_name}
                          </Text>
                          {order.document_number && (
                            <Text
                              textStyle="helper"
                              color="fg.secondary"
                              overflowWrap="anywhere"
                            >
                              {order.document_number}
                            </Text>
                          )}
                        </Box>
                        <Text
                          textStyle="helper"
                          color="fg.secondary"
                          whiteSpace="nowrap"
                        >
                          {order.service_date.split("-").reverse().join("/")}
                        </Text>
                      </Flex>
                    ))}
                  </Stack>
                  {changed && (
                    <Text role="alert" mt="sm" color="status.warning">
                      Thông tin đơn mua đã thay đổi. Hãy quay lại và kiểm tra
                      danh sách mới.
                    </Text>
                  )}
                </Dialog.Body>
                <Dialog.Footer flexWrap="wrap">
                  <Button ref={back} variant="secondary" onClick={onClose}>
                    Quay lại
                  </Button>
                  <Button
                    variant="businessPrimary"
                    disabled={disabled || changed}
                    onClick={onConfirm}
                    data-po-bulk-confirm={review.action}
                  >
                    {release ? "Phát hành" : `Xuất ${format}`}{" "}
                    {review.orders.length} đơn
                  </Button>
                </Dialog.Footer>
              </>
            )}
          </Dialog.Content>
        </Dialog.Positioner>
      </Portal>
    </Dialog.Root>
  );
}
