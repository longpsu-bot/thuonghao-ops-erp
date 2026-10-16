import { Badge, Box, Button, Flex, Table, Text } from "@chakra-ui/react";
import { useState } from "react";
import type { SupplierMasterData } from "../bridges/ingredientSupplierMasterData";
import {
  AtlasSortableColumnHeader,
  atlasNarrowSortableHeader,
} from "../AtlasSortableColumnHeader";
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
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: "var(--atlas-supplier-table-width, 860px)",
          }}
          w="full"
          tableLayout="fixed"
          stickyHeader
          size="sm"
          css={{
            "& th, & td": {
              paddingBlock: "var(--atlas-spacing-xs)",
              verticalAlign: "middle",
            },
            "@media(max-width: 47.99rem)": {
              "& colgroup": { display: "none" },
              "& tbody": { display: "block" },
              "& tbody tr": {
                display: "grid",
                gridTemplateColumns: "minmax(0, 1fr) auto",
                borderBottom: "1px solid var(--atlas-colors-border-subtle)",
              },
              "& td": { display: "block", border: "none" },
              "& td:first-of-type, & td:nth-of-type(3)": {
                gridColumn: "1 / -1",
              },
            },
          }}
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-supplier-name-width, 30%)" />
            <Table.Column w="var(--atlas-supplier-status-width, 20%)" />
            <Table.Column />
            <Table.Column />
            <Table.Column />
            <Table.Column w="var(--atlas-supplier-action-width, 96px)" />
          </Table.ColumnGroup>
          <Table.Header css={atlasNarrowSortableHeader}>
            <Table.Row>
              <AtlasSortableColumnHeader
                label="Nhà cung ứng"
                position={{ base: "static", md: "sticky" }}
                left="var(--atlas-layout-zero, 0)"
                bg="bg.toolbar"
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
              <Table.ColumnHeader
                position={{ base: "static", md: "sticky" }}
                right="var(--atlas-layout-zero, 0)"
                bg="bg.toolbar"
              >
                Thao tác
              </Table.ColumnHeader>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {sortedSuppliers.map((item) => (
              <Table.Row
                key={item.supplier_id}
                aria-selected={item.supplier_id === selectedId}
              >
                <Table.Cell
                  data-sticky-column=""
                  position={{ base: "relative", md: "sticky" }}
                  left="var(--atlas-layout-zero, 0)"
                  bg="bg.workbench"
                  zIndex="var(--atlas-layout-sticky-cell, 1)"
                  overflowWrap="anywhere"
                  verticalAlign="top"
                >
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
                <Table.Cell>
                  <Text color="fg.muted">
                    {item.contact_name || "Chưa có người liên hệ"}
                  </Text>
                </Table.Cell>
                <Table.Cell>
                  <Text color="fg.muted">
                    {item.contact_phone || "Chưa có số điện thoại"}
                  </Text>
                </Table.Cell>
                <Table.Cell overflowWrap="anywhere">
                  <Text color="fg.muted">
                    {item.contact_email || "Chưa có email"}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  data-sticky-column=""
                  position={{ base: "static", md: "sticky" }}
                  right="var(--atlas-layout-zero, 0)"
                  bg="bg.workbench"
                  zIndex="var(--atlas-layout-sticky-cell, 1)"
                >
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
