import { Box, Button, Table, Text } from "@chakra-ui/react";
import type { DishRecipeController } from "./useDishRecipeWorkbench";
export const dishStatusLabel = {
  ACTIVE: "Đang dùng",
  INACTIVE: "Ngừng dùng",
  DRAFT: "Nháp",
};
export function DishCatalogue({
  c,
  onSelect,
}: {
  c: DishRecipeController;
  onSelect: (id: string, button: HTMLButtonElement) => void;
}) {
  return (
    <Box
      minW="var(--atlas-layout-zero, 0)"
      overflow="auto"
      maxH={{
        base: "var(--atlas-layout-catalog-height, 44dvh)",
        lg: "var(--atlas-layout-catalog-height, calc(100dvh - 290px))",
      }}
    >
      {!c.visibleDishes.length ? (
        <Text p="md">
          {c.catalog.dishes.length
            ? "Không có món phù hợp bộ lọc."
            : "Chưa có món. Tạo món mới để bắt đầu."}
        </Text>
      ) : (
        <Table.Root aria-label="Danh mục món" stickyHeader>
          <Table.Header>
            <Table.Row>
              {(c.context
                ? ["Món", "Công thức", "Thao tác"]
                : ["Món", "Loại món", "Trạng thái", "Công thức", "Thao tác"]
              ).map((label) => (
                <Table.ColumnHeader key={label}>{label}</Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {c.visibleDishes.map((dish) => (
              <Table.Row
                key={dish.dish_id}
                aria-selected={dish.dish_id === c.context?.dishId}
              >
                <Table.Cell position="relative">
                  {dish.dish_id === c.context?.dishId && (
                    <Box data-selection-indicator aria-hidden="true" />
                  )}
                  <Text fontWeight="semibold">{dish.dish_name}</Text>
                  {c.context && (
                    <Text textStyle="helper" color="fg.muted">
                      {dish.dish_type_name ?? "Chưa phân loại"} ·{" "}
                      {dishStatusLabel[dish.dish_status]}
                    </Text>
                  )}
                </Table.Cell>
                {!c.context && (
                  <>
                    <Table.Cell>
                      {dish.dish_type_name ?? "Chưa phân loại"}
                    </Table.Cell>
                    <Table.Cell>{dishStatusLabel[dish.dish_status]}</Table.Cell>
                  </>
                )}
                <Table.Cell>
                  <Text textStyle="helper">
                    {c.scopes
                      .filter((s) =>
                        c.catalog.recipes.some(
                          (r) =>
                            r.dish_id === dish.dish_id &&
                            r.school_type_id === s.school_type_id,
                        ),
                      )
                      .map((s) => s.school_type_name)
                      .join(" · ") || "Chưa có"}
                  </Text>
                </Table.Cell>
                <Table.Cell>
                  <Button
                    size="sm"
                    variant="utility"
                    aria-label={`Xem công thức ${dish.dish_name}`}
                    disabled={c.busy || Boolean(c.lock)}
                    onClick={(e) => onSelect(dish.dish_id, e.currentTarget)}
                  >
                    Xem công thức
                  </Button>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table.Root>
      )}
    </Box>
  );
}
