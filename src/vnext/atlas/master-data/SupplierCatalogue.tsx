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
    <Box
      data-testid="supplier-catalogue"
      data-selected-presentation={detailOpen ? "identity-rail" : undefined}
      display="block"
      css={
        detailOpen
          ? { "@media(max-width: 61.99rem)": { display: "none" } }
          : undefined
      }
      minW="var(--atlas-layout-zero, 0)"
    >
      <AtlasTableViewport
        label="Bảng danh mục nhà cung ứng"
        maxH={{
          base: "var(--atlas-supplier-list-height, 60dvh)",
          lg: "var(--atlas-layout-catalog-height, calc(100dvh - 290px))",
        }}
      >
        <Table.Root
          aria-label="Danh mục nhà cung ứng"
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: detailOpen
              ? "var(--atlas-layout-zero, 0)"
              : "var(--atlas-supplier-table-width, 860px)",
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
            <Table.Column
              w={
                detailOpen
                  ? "var(--atlas-master-rail-name-width, 48%)"
                  : "var(--atlas-supplier-name-width, 30%)"
              }
            />
            <Table.Column
              w={
                detailOpen
                  ? "var(--atlas-master-rail-status-width, 26%)"
                  : "var(--atlas-supplier-status-width, 20%)"
              }
            />
            <Table.Column
              display={{ lg: detailOpen ? "none" : "table-column" }}
            />
            <Table.Column
              display={{ lg: detailOpen ? "none" : "table-column" }}
            />
            <Table.Column
              display={{ lg: detailOpen ? "none" : "table-column" }}
            />
            <Table.Column
              w={
                detailOpen
                  ? "var(--atlas-master-rail-action-width, 26%)"
                  : "var(--atlas-supplier-action-width, 96px)"
              }
            />
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
                display={{ lg: detailOpen ? "none" : "table-cell" }}
                columnKey="contact"
                sort={sort}
                onSort={onSort}
              />
              <Table.ColumnHeader
                display={{ lg: detailOpen ? "none" : "table-cell" }}
              >
                Điện thoại
              </Table.ColumnHeader>
              <Table.ColumnHeader
                display={{ lg: detailOpen ? "none" : "table-cell" }}
              >
                Email
              </Table.ColumnHeader>
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
                  <Badge
                    variant={status[item.supplier_status].variant}
                    whiteSpace={detailOpen ? "normal" : undefined}
                  >
                    {status[item.supplier_status].label}
                  </Badge>
                </Table.Cell>
                <Table.Cell
                  display={{ lg: detailOpen ? "none" : "table-cell" }}
                >
                  <Text color="fg.muted">
                    {item.contact_name || "Chưa có người liên hệ"}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  display={{ lg: detailOpen ? "none" : "table-cell" }}
                >
                  <Text color="fg.muted">
                    {item.contact_phone || "Chưa có số điện thoại"}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  display={{ lg: detailOpen ? "none" : "table-cell" }}
                  overflowWrap="anywhere"
                >
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
                    aria-expanded={item.supplier_id === selectedId}
                    onClick={(event) =>
                      onSelect(item.supplier_id, event.currentTarget)
                    }
                  >
                    {detailOpen ? "Xem" : "Xem / sửa"}
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
