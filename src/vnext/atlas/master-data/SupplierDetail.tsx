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
    if (c.activeSurface?.kind === "supplier")
      panel.current?.focus({ preventScroll: true });
  }, [c.activeSurface]);
  if (c.activeSurface?.kind !== "supplier") return null;
  const disabled = c.saving || c.loading || Boolean(c.lock);
  const creating = c.activeSurface.id === "NEW";
  const item = c.selectedSupplier;
  return (
    <Box
      as="aside"
      ref={panel}
      tabIndex={-1}
      aria-label="Chi tiết nhà cung ứng"
      bg="bg.workbench"
      minW="var(--atlas-layout-zero, 0)"
      minH="var(--atlas-layout-zero, 0)"
      maxH={{
        lg: "var(--atlas-layout-master-workplane-height, calc(100dvh - 340px))",
      }}
      overflow={{ lg: "hidden" }}
      display="flex"
      flexDirection="column"
    >
      <Flex
        px="md"
        py="sm"
        justify="space-between"
        gap="sm"
        align="start"
        borderBottomWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
        flexShrink="0"
      >
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
          variant="tertiary"
          aria-label="Đóng chi tiết"
          onClick={c.requestClose}
          minH={{
            base: "var(--atlas-layout-mobile-target, 44px)",
            lg: "compact",
          }}
        >
          Đóng
        </Button>
      </Flex>
      <Box
        p="md"
        display="grid"
        gap="sm"
        overflowY="auto"
        minH="var(--atlas-layout-zero, 0)"
        flex="1"
        alignItems="start"
        gridTemplateColumns={{
          base: "minmax(0, 1fr)",
          md: "repeat(2, minmax(0, 1fr))",
        }}
      >
        <Field.Root required invalid={!c.supplierDraft.supplierName.trim()}>
          <Field.Label>Tên nhà cung ứng</Field.Label>
          <Input
            required
            disabled={disabled}
            aria-invalid={!c.supplierDraft.supplierName.trim()}
            value={c.supplierDraft.supplierName}
            onChange={(e) => c.setSupplierField("supplierName", e.target.value)}
          />
        </Field.Root>
        <SupplierField
          label="Mã NCC trên chứng từ"
          value={c.supplierDraft.documentCode}
          onChange={(value) => c.setSupplierField("documentCode", value)}
          maxLength={200}
          disabled={disabled}
          helperText="Có thể để trống khi tạo nhà cung ứng. Cần bổ sung mã trước khi phát hành đơn mua hàng."
        />
        <SupplierField
          disabled={disabled}
          label="Người liên hệ"
          value={c.supplierDraft.contactName}
          onChange={(value) => c.setSupplierField("contactName", value)}
        />
        <SupplierField
          disabled={disabled}
          label="Điện thoại"
          value={c.supplierDraft.contactPhone}
          onChange={(value) => c.setSupplierField("contactPhone", value)}
        />
        <SupplierField
          disabled={disabled}
          label="Email"
          value={c.supplierDraft.contactEmail}
          onChange={(value) => c.setSupplierField("contactEmail", value)}
        />
      </Box>
      <Flex
        p="md"
        borderTopWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
        flexShrink="0"
      >
        <Button
          variant="businessPrimary"
          disabled={disabled || !c.supplierDirty || !c.supplierValid}
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
  helperText,
  maxLength,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  helperText?: string;
  maxLength?: number;
  disabled?: boolean;
}) {
  return (
    <Field.Root>
      <Field.Label>{label}</Field.Label>
      <Input
        aria-label={label}
        value={value}
        maxLength={maxLength}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value)}
      />
      {helperText && <Field.HelperText>{helperText}</Field.HelperText>}
    </Field.Root>
  );
}
