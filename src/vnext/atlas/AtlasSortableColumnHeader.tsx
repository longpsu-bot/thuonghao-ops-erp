import {
  Button,
  Icon,
  Table,
  type TableColumnHeaderProps,
} from "@chakra-ui/react";
import { CaretDown, CaretUp, CaretUpDown } from "@phosphor-icons/react";
import type { AtlasSortState } from "./atlasTableSort";

export function AtlasSortableColumnHeader<Key extends string>({
  label,
  columnKey,
  sort,
  onSort,
  textAlign = "start",
  ...props
}: Omit<TableColumnHeaderProps, "aria-sort"> & {
  label: string;
  columnKey: Key;
  sort: AtlasSortState<Key>;
  onSort: (key: Key) => void;
}) {
  const direction = sort.key === columnKey ? sort.direction : "default";
  const SortIcon =
    direction === "ascending"
      ? CaretUp
      : direction === "descending"
        ? CaretDown
        : CaretUpDown;

  return (
    <Table.ColumnHeader
      aria-sort={direction === "default" ? "none" : direction}
      textAlign={textAlign}
      {...props}
    >
      <Button
        type="button"
        variant="utility"
        size="sm"
        minH="var(--atlas-layout-zero, 0)"
        h="var(--atlas-layout-auto, auto)"
        minW="var(--atlas-layout-zero, 0)"
        w="full"
        px="var(--atlas-layout-zero, 0)"
        py="xs"
        justifyContent={textAlign === "end" ? "flex-end" : "flex-start"}
        gap="xs"
        color="fg.default"
        aria-label={`Sắp xếp theo ${label}`}
        onClick={() => onSort(columnKey)}
      >
        {label}
        <Icon asChild boxSize="14px" color="fg.muted" aria-hidden="true">
          <SortIcon weight="bold" />
        </Icon>
      </Button>
    </Table.ColumnHeader>
  );
}
