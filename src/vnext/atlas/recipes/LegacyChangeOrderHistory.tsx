import { Box, Button, Table, Text } from "@chakra-ui/react";
import { useState } from "react";
import type { LegacyRecipeChangeOrder } from "../bridges/recipeAdjustment";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import { actionLabels, scopeLabels } from "./changeOrderModel";

export function LegacyChangeOrderHistory({
  rows,
  query,
  scope = "",
}: {
  rows: LegacyRecipeChangeOrder[];
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
                        <Box as="details" mt="xs">
                          <Text
                            as="summary"
                            textStyle="helper"
                            cursor="var(--atlas-pointer, pointer)"
                          >
                            Thông tin nguồn
                          </Text>
                          <Text textStyle="helper">
                            {row.source_table} #{row.legacy_id}
                          </Text>
                          <Text textStyle="helper">
                            Nguồn ghi nhận tạo:{" "}
                            {row.source_created_at ?? "Không xác định"}
                          </Text>
                        </Box>
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
                            Loại trường nguồn: {row.source_school_type_id}
                          </Text>
                        )}
                        <Text textStyle="helper" color="fg.muted">
                          Mã nguồn #{row.legacy_id}
                        </Text>
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
                          ? "Nguồn active; chưa xác nhận hiệu lực Atlas"
                          : "Nguồn inactive; không rõ ngày hủy"}
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
