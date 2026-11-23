import { Box, Button, Table, Text } from "@chakra-ui/react";
import { useState } from "react";
import type {
  AdjustmentReference,
  LegacyRecipeChangeOrder,
} from "../bridges/recipeAdjustment";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import { actionLabels, scopeLabels } from "./changeOrderModel";

export function LegacyChangeOrderHistory({
  rows,
  schoolTypes,
  query,
  scope = "",
}: {
  rows: LegacyRecipeChangeOrder[];
  schoolTypes: AdjustmentReference[];
  query: string;
  scope?: string;
}) {
  const [open, setOpen] = useState(false);
  const [limit, setLimit] = useState(25);
  const term = foldVietnameseSearch(query);
  const matches = rows.filter(
    (row) =>
      (!scope || row.scope_kind === scope) &&
      foldVietnameseSearch(
        [
          row.dish_name,
          row.school_name,
          row.ingredient_name,
          row.substitute_name,
          row.note,
          row.legacy_id,
        ].join(" "),
      ).includes(term),
  );
  if (!rows.length) return null;
  return (
    <Box asChild mt="md" px="md">
      <details onToggle={(event) => setOpen(event.currentTarget.open)}>
        <Text
          as="summary"
          cursor="var(--atlas-pointer, pointer)"
          fontWeight="medium"
        >
          Lịch sử OPS v1 · {matches.length}/{rows.length}
        </Text>
        {open && (
          <Box py="sm">
            <Text textStyle="helper" color="fg.muted" mb="sm">
              Bản ghi nguồn để tra cứu, không tự áp dụng vào công thức. Chưa có
              đủ bằng chứng về người phát hành và ngày hủy.
            </Text>
            <AtlasTableViewport
              label="Lịch sử điều chỉnh OPS v1"
              maxH="var(--atlas-legacy-history-height, 60dvh)"
            >
              <Table.Root
                size="sm"
                minW="var(--atlas-legacy-history-table-width, 640px)"
              >
                <Table.Header>
                  <Table.Row>
                    <Table.ColumnHeader>Ngày hiệu lực nguồn</Table.ColumnHeader>
                    <Table.ColumnHeader>
                      Phạm vi và điều chỉnh
                    </Table.ColumnHeader>
                    <Table.ColumnHeader>Nội dung nguồn</Table.ColumnHeader>
                    <Table.ColumnHeader>Trạng thái nguồn</Table.ColumnHeader>
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {matches.slice(0, limit).map((row) => (
                    <Table.Row key={`${row.source_table}:${row.legacy_id}`}>
                      <Table.Cell verticalAlign="top">
                        {row.effective_from ?? "Không xác định"}
                        {row.source_created_at && (
                          <Text textStyle="helper" color="fg.muted">
                            Ngày ghi nhận: {row.source_created_at}
                          </Text>
                        )}
                      </Table.Cell>
                      <Table.Cell verticalAlign="top">
                        <Text>
                          {row.dish_name ??
                            row.school_name ??
                            scopeLabels[row.scope_kind]}
                        </Text>
                        <Text textStyle="helper">
                          {actionLabels[row.action]} ·{" "}
                          {row.school_name ?? scopeLabels[row.scope_kind]}
                        </Text>
                        {row.source_school_type_id && (
                          <Text textStyle="helper">
                            Loại trường:{" "}
                            {schoolTypes.find(
                              (type) =>
                                type.school_type_code ===
                                `v1-school-type-${row.source_school_type_id}`,
                            )?.school_type_name ?? "Chưa xác định"}
                          </Text>
                        )}
                      </Table.Cell>
                      <Table.Cell verticalAlign="top">
                        <Text>
                          {row.ingredient_name ?? "Không xác định nguyên liệu"}
                          {row.substitute_name
                            ? ` → ${row.substitute_name}`
                            : ""}
                          {row.quantity !== null
                            ? ` · ${row.quantity} ${row.unit_name ?? ""}`
                            : ""}
                        </Text>
                        {row.note && <Text textStyle="helper">{row.note}</Text>}
                      </Table.Cell>
                      <Table.Cell verticalAlign="top">
                        {row.source_active
                          ? "Đang áp dụng trong OPS v1. Chưa xác nhận hiệu lực trong Atlas."
                          : "Đã ngừng áp dụng trong OPS v1. Chưa rõ ngày hủy."}
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table.Body>
              </Table.Root>
            </AtlasTableViewport>
            {!matches.length && (
              <Text textStyle="helper" py="sm">
                Không có bản ghi nguồn phù hợp.
              </Text>
            )}
            {matches.length > limit && (
              <Button
                mt="sm"
                variant="secondary"
                onClick={() => setLimit(limit + 25)}
              >
                Xem thêm lịch sử
              </Button>
            )}
          </Box>
        )}
      </details>
    </Box>
  );
}
