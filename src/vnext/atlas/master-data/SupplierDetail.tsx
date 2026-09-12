import {
  Badge,
  Box,
  Button,
  Field,
  Flex,
  Heading,
  Input,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import type { IngredientSupplierWorkbenchController } from "./useIngredientSupplierWorkbench";

const status = {
  ACTIVE: ["Đang hợp tác", "success"],
  INACTIVE: ["Ngừng hợp tác", "warning"],
  SUSPENDED: ["Tạm dừng", "danger"],
} as const;
export function SupplierDetail({
  c,
}: {
  c: IngredientSupplierWorkbenchController;
}) {
  const panel = useRef<HTMLElement>(null);
  useEffect(() => {
    if (c.activeSurface?.kind === "supplier") panel.current?.focus();
  }, [c.activeSurface]);
  if (c.activeSurface?.kind !== "supplier") return null;
  const creating = c.activeSurface.id === "NEW";
  const item = c.selectedSupplier;
  return (
    <Box
      as="aside"
      ref={panel}
      tabIndex={-1}
      aria-label="Chi tiết nhà cung ứng"
      bg="bg.subtle"
      borderLeftWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      display="flex"
      flexDirection="column"
    >
      <Flex p="md" justify="space-between" gap="sm" align="start">
        <Box>
          <Text textStyle="helper" color="fg.muted">
            Nhà cung ứng
          </Text>
          <Heading as="h2" textStyle="section">
            {creating ? "Tạo nhà cung ứng" : item?.supplier_name}
          </Heading>
          {item && (
            <Badge mt="xs" variant={status[item.supplier_status][1]}>
              {status[item.supplier_status][0]}
            </Badge>
          )}
        </Box>
        <Button
          size="sm"
          variant="utility"
          aria-label="Đóng chi tiết"
          onClick={c.requestClose}
        >
          Đóng
        </Button>
      </Flex>
      <Box px="md" pb="md" display="grid" gap="sm">
        <Field.Root required invalid={!c.supplierDraft.supplierName.trim()}>
          <Field.Label>Tên nhà cung ứng</Field.Label>
          <Input
            required
            aria-invalid={!c.supplierDraft.supplierName.trim()}
            value={c.supplierDraft.supplierName}
            onChange={(e) => c.setSupplierField("supplierName", e.target.value)}
          />
        </Field.Root>
        <SupplierField
          label="Người liên hệ"
          value={c.supplierDraft.contactName}
          onChange={(value) => c.setSupplierField("contactName", value)}
        />
        <SupplierField
          label="Điện thoại"
          value={c.supplierDraft.contactPhone}
          onChange={(value) => c.setSupplierField("contactPhone", value)}
        />
        <SupplierField
          label="Email"
          value={c.supplierDraft.contactEmail}
          onChange={(value) => c.setSupplierField("contactEmail", value)}
        />
      </Box>
      <Flex mt="var(--atlas-layout-auto, auto)" p="md">
        <Button
          variant="businessPrimary"
          disabled={!c.supplierDirty || !c.supplierValid || Boolean(c.lock)}
          onClick={c.openSupplierReview}
        >
          Xem thay đổi
        </Button>
      </Flex>
    </Box>
  );
}
function SupplierField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <Field.Root>
      <Field.Label>{label}</Field.Label>
      <Input
        aria-label={label}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </Field.Root>
  );
}
