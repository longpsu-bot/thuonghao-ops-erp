import { Badge, Box, Button, Flex, Table, Text } from "@chakra-ui/react";
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
  unavailable,
  detailOpen,
}: {
  suppliers: SupplierMasterData[];
  selectedId?: string;
  unavailable?: boolean;
  detailOpen?: boolean;
  onSelect: (id: string, trigger: HTMLButtonElement) => void;
}) {
  type SortKey = "supplier" | "status" | "contact";
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  if (!suppliers.length && unavailable) return null;
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
    <Box minW="var(--atlas-layout-zero, 0)">
      <Flex
        px="md"
        py="xs"
        gap="xs"
        align="center"
        wrap="wrap"
        aria-label="Sắp xếp nhà cung ứng"
      >
        <Text textStyle="helper" color="fg.muted">
          Sắp xếp thêm:
        </Text>
        {(
          [
            ["status", "Trạng thái"],
            ["contact", "Người liên hệ"],
          ] as const
        ).map(([key, label]) => (
          <Button
            key={key}
            size="sm"
            variant="utility"
            aria-label={`Sắp xếp theo ${label}`}
            aria-pressed={sort.key === key}
            onClick={() => onSort(key)}
          >
            {label}
            {sort.key === key
              ? sort.direction === "ascending"
                ? " · Tăng dần"
                : " · Giảm dần"
              : ""}
          </Button>
        ))}
      </Flex>
      <AtlasTableViewport
        label="Bảng danh mục nhà cung ứng"
        maxH={{
          base: detailOpen
            ? "var(--atlas-supplier-list-selected-height, 35dvh)"
            : "var(--atlas-supplier-list-height, 60dvh)",
          lg: "var(--atlas-layout-catalog-height, calc(100dvh - 290px))",
        }}
      >
        <Table.Root
          aria-label="Danh mục nhà cung ứng"
          minW="var(--atlas-layout-zero, 0)"
          w="full"
          tableLayout="fixed"
          stickyHeader
        >
          <Table.ColumnGroup>
            <Table.Column />
            <Table.Column w="var(--atlas-supplier-action-width, 92px)" />
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row>
              <AtlasSortableColumnHeader
                label="Nhà cung ứng"
                columnKey="supplier"
                sort={sort}
                onSort={onSort}
              />
              <Table.ColumnHeader>Thao tác</Table.ColumnHeader>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {sortedSuppliers.map((item) => (
              <Table.Row
                key={item.supplier_id}
                aria-selected={item.supplier_id === selectedId}
              >
                <Table.Cell
                  position="relative"
                  overflowWrap="anywhere"
                  verticalAlign="top"
                >
                  {item.supplier_id === selectedId && (
                    <Box data-selection-indicator aria-hidden="true" />
                  )}
                  <Text fontWeight="semibold">{item.supplier_name}</Text>
                  <Badge my="xs" variant={status[item.supplier_status].variant}>
                    {status[item.supplier_status].label}
                  </Badge>
                  <Text textStyle="helper" color="fg.muted">
                    {item.contact_name || "Chưa có người liên hệ"}
                  </Text>
                  <Text textStyle="helper" color="fg.muted">
                    {item.contact_phone || "Chưa có số điện thoại"}
                  </Text>
                  <Text textStyle="helper" color="fg.muted">
                    {item.contact_email || "Chưa có email"}
                  </Text>
                </Table.Cell>
                <Table.Cell verticalAlign="top">
                  <Button
                    size="sm"
                    variant="tableAction"
                    aria-label={`Xem / sửa ${item.supplier_name}`}
                    onClick={(event) =>
                      onSelect(item.supplier_id, event.currentTarget)
                    }
                  >
                    Xem / sửa
                  </Button>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
    </Box>
  );
}
