import { Badge, Box, Button, Table, Text } from "@chakra-ui/react";
import type { SupplierMasterData } from "../bridges/ingredientSupplierMasterData";

const status = {
  ACTIVE: { label: "Đang hợp tác", variant: "success" as const },
  INACTIVE: { label: "Ngừng hợp tác", variant: "warning" as const },
  SUSPENDED: { label: "Tạm dừng", variant: "danger" as const },
};

export function SupplierCatalogue({
  suppliers,
  selectedId,
  onSelect,
}: {
  suppliers: SupplierMasterData[];
  selectedId?: string;
  onSelect: (id: string) => void;
}) {
  if (!suppliers.length)
    return <Text p="md">Không có nhà cung ứng phù hợp tìm kiếm.</Text>;
  return (
    <Box
      overflow="auto"
      maxH="var(--atlas-layout-catalog-height, calc(100dvh - 290px))"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Table.Root
        aria-label="Danh mục nhà cung ứng"
        minW="var(--atlas-layout-supplier-table-min, 760px)"
        stickyHeader
      >
        <Table.Header>
          <Table.Row>
            <Table.ColumnHeader>Nhà cung ứng</Table.ColumnHeader>
            <Table.ColumnHeader>Trạng thái</Table.ColumnHeader>
            <Table.ColumnHeader>Người liên hệ</Table.ColumnHeader>
            <Table.ColumnHeader>Điện thoại</Table.ColumnHeader>
            <Table.ColumnHeader>Email</Table.ColumnHeader>
            <Table.ColumnHeader>Thao tác</Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {suppliers.map((item) => (
            <Table.Row
              key={item.supplier_id}
              aria-selected={item.supplier_id === selectedId}
            >
              <Table.Cell position="relative">
                {item.supplier_id === selectedId && (
                  <Box data-selection-indicator aria-hidden="true" />
                )}
                <Text fontWeight="semibold">{item.supplier_name}</Text>
              </Table.Cell>
              <Table.Cell>
                <Badge variant={status[item.supplier_status].variant}>
                  {status[item.supplier_status].label}
                </Badge>
              </Table.Cell>
              <Table.Cell>{item.contact_name || "—"}</Table.Cell>
              <Table.Cell>{item.contact_phone || "—"}</Table.Cell>
              <Table.Cell>{item.contact_email || "—"}</Table.Cell>
              <Table.Cell>
                <Button
                  size="sm"
                  variant="utility"
                  aria-label={`Xem / sửa ${item.supplier_name}`}
                  onClick={() => onSelect(item.supplier_id)}
                >
                  Xem / sửa
                </Button>
              </Table.Cell>
            </Table.Row>
          ))}
        </Table.Body>
      </Table.Root>
    </Box>
  );
}
