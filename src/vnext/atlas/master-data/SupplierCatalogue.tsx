import { Badge, Box, Button, Table, Text } from "@chakra-ui/react";
import { useState } from "react";
import type { SupplierMasterData } from "../bridges/ingredientSupplierMasterData";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import { AtlasTableViewport } from "../AtlasTableViewport";
import {
  atlasDefaultSort,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";

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
  type SortKey = "supplier" | "status" | "contact";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  if (!suppliers.length)
    return <Text p="md">Không có nhà cung ứng phù hợp tìm kiếm.</Text>;
  const sortedSuppliers = sortAtlasRows(suppliers, sort, {
    supplier: (left, right) =>
      compareAtlasText(left.supplier_name, right.supplier_name),
    status: (left, right) =>
      compareAtlasText(left.supplier_status, right.supplier_status),
    contact: (left, right) =>
      compareAtlasText(left.contact_name, right.contact_name),
  });
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <AtlasTableViewport
      label="Bảng danh mục nhà cung ứng"
      maxH="var(--atlas-layout-catalog-height, calc(100dvh - 290px))"
    >
      <Table.Root
        aria-label="Danh mục nhà cung ứng"
        minW="var(--atlas-layout-supplier-table-min, 1040px)"
        w="var(--atlas-layout-supplier-table-width, 1040px)"
        tableLayout="fixed"
        stickyHeader
      >
        <Table.ColumnGroup>
          <Table.Column w="var(--atlas-supplier-identity-width, 220px)" />
          <Table.Column w="var(--atlas-supplier-state-width, 140px)" />
          <Table.Column w="var(--atlas-supplier-contact-width, 170px)" />
          <Table.Column w="var(--atlas-supplier-phone-width, 150px)" />
          <Table.Column w="var(--atlas-supplier-email-width, 250px)" />
          <Table.Column w="var(--atlas-supplier-action-width, 110px)" />
        </Table.ColumnGroup>
        <Table.Header>
          <Table.Row>
            <AtlasSortableColumnHeader
              label="Nhà cung ứng"
              columnKey="supplier"
              sort={sort}
              onSort={onSort}
            />
            <AtlasSortableColumnHeader
              label="Trạng thái"
              columnKey="status"
              sort={sort}
              onSort={onSort}
            />
            <AtlasSortableColumnHeader
              label="Người liên hệ"
              columnKey="contact"
              sort={sort}
              onSort={onSort}
            />
            <Table.ColumnHeader>Điện thoại</Table.ColumnHeader>
            <Table.ColumnHeader>Email</Table.ColumnHeader>
            <Table.ColumnHeader>Thao tác</Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {sortedSuppliers.map((item) => (
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
                  variant="tableAction"
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
    </AtlasTableViewport>
  );
}
