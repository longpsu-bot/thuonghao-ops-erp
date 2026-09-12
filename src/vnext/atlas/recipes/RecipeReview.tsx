import { Box, Heading, Table, Text } from "@chakra-ui/react";
import { ingredientLabel, unitLabel } from "../bridges/dishRecipe";
import { recipeDraftFor } from "./recipeDraftModel";
import type { DishRecipeController } from "./useDishRecipeWorkbench";
export function RecipeReview({ c }: { c: DishRecipeController }) {
  if (!c.recipeDraft) return null;
  const before = c.reviewBase ? recipeDraftFor(c.reviewBase) : null;
  const after = c.recipeDraft;
  const ids = [
    ...new Set([
      ...(before?.lines ?? []).map((l) => l.id),
      ...after.lines.map((l) => l.id),
    ]),
  ];
  return (
    <Box mt="md">
      <Heading as="h3" textStyle="section">
        Xem thay đổi
      </Heading>
      <Text mt="sm">
        Số suất: {before?.basis ?? "—"} → {after.basis}
      </Text>
      <Box overflow="auto" mt="sm">
        <Table.Root aria-label="Thay đổi công thức">
          <Table.Header>
            <Table.Row>
              <Table.ColumnHeader>Nguyên liệu</Table.ColumnHeader>
              <Table.ColumnHeader>Thay đổi</Table.ColumnHeader>
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {ids.map((id) => {
              const old = before?.lines.find((l) => l.id === id),
                next = after.lines.find((l) => l.id === id),
                line = next ?? old!;
              const facts = [
                !old ? "Thêm" : !next ? "Bỏ" : "",
                old && next && old.quantity !== next.quantity
                  ? `Định lượng: ${old.quantity} → ${next.quantity}`
                  : "",
                old && next && old.unitId !== next.unitId
                  ? `Đơn vị: ${unitLabel(old.unitId, c.catalog.units)} → ${unitLabel(next.unitId, c.catalog.units)}`
                  : "",
                old && next && old.note !== next.note
                  ? `Ghi chú: ${old.note || "—"} → ${next.note || "—"}`
                  : "",
              ].filter(Boolean);
              return (
                <Table.Row key={id}>
                  <Table.Cell>
                    {ingredientLabel(line.ingredientId, c.catalog.ingredients)}
                  </Table.Cell>
                  <Table.Cell>
                    {facts.join(" · ") || "Giữ nguyên"}
                    {(!old || !next) &&
                      ` · ${line.quantity} ${unitLabel(line.unitId, c.catalog.units)}${line.note ? ` · ${line.note}` : ""}`}
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </Box>
    </Box>
  );
}
