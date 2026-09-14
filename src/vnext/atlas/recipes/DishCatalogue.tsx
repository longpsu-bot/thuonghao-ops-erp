import { Box, Button, Table, Text } from "@chakra-ui/react";
import { useEffect, useState } from "react";
import type { DishRecipeController } from "./useDishRecipeWorkbench";
export const dishStatusLabel = {
  ACTIVE: "Đang dùng",
  INACTIVE: "Ngừng dùng",
  DRAFT: "Nháp",
};
export type DishBaseRecipeState = "LOCKED" | "EDITABLE" | "MISSING";
export function dishBaseRecipeState(
  c: DishRecipeController,
  dishId: string,
): DishBaseRecipeState {
  const latestByRecipe = new Map<
    string,
    (typeof c.catalog.recipe_versions)[number]
  >();
  for (const version of c.catalog.recipe_versions) {
    const current = latestByRecipe.get(version.recipe_id);
    if (!current || version.version_number > current.version_number)
      latestByRecipe.set(version.recipe_id, version);
  }
  const recipeIds = c.catalog.recipes
    .filter(
      (recipe) =>
        recipe.dish_id === dishId && recipe.recipe_status === "ACTIVE",
    )
    .map((recipe) => recipe.recipe_id);
  if (
    recipeIds.some(
      (recipeId) =>
        latestByRecipe.get(recipeId)?.recipe_version_status === "LOCKED",
    )
  )
    return "LOCKED";
  return recipeIds.length ? "EDITABLE" : "MISSING";
}
export function DishCatalogue({
  c,
  onSelect,
  compact,
}: {
  c: DishRecipeController;
  compact: boolean;
  onSelect: (id: string, button: HTMLButtonElement) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  useEffect(() => setExpanded(false), [c.context?.dishId, compact]);
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      {compact && c.context && (
        <Box display={{ base: "block", lg: "none" }} px="sm" py="xs">
          <Button
            variant="tertiary"
            size="sm"
            aria-expanded={expanded}
            onClick={() => setExpanded(!expanded)}
          >
            {expanded ? "Thu gọn danh sách món" : "Chọn món khác"}
          </Button>
        </Box>
      )}
      <Box
        overflow="auto"
        maxH={{
          base: compact
            ? "var(--atlas-layout-navigator-height, 24dvh)"
            : "var(--atlas-layout-catalog-height, 44dvh)",
          lg: compact
            ? "var(--atlas-layout-navigator-height, calc(100dvh - 440px))"
            : "var(--atlas-layout-catalog-height, calc(100dvh - 290px))",
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
            <Table.Header
              display={{
                base:
                  compact && c.context && !expanded
                    ? "none"
                    : "table-header-group",
                lg: "table-header-group",
              }}
            >
              <Table.Row>
                {(compact
                  ? ["Món", "Thao tác"]
                  : ["Món", "Loại món", "Trạng thái", "Công thức", "Thao tác"]
                ).map((label) => (
                  <Table.ColumnHeader key={label}>{label}</Table.ColumnHeader>
                ))}
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {c.visibleDishes.map((dish) => {
                const baseRecipeState = dishBaseRecipeState(c, dish.dish_id);
                const actionLabel =
                  baseRecipeState === "LOCKED"
                    ? "Xem công thức"
                    : "Sửa công thức";
                return (
                  <Table.Row
                    key={dish.dish_id}
                    aria-selected={dish.dish_id === c.context?.dishId}
                    display={{
                      base:
                        compact &&
                        c.context &&
                        !expanded &&
                        dish.dish_id !== c.context.dishId
                          ? "none"
                          : "table-row",
                      lg: "table-row",
                    }}
                  >
                    <Table.Cell position="relative">
                      {dish.dish_id === c.context?.dishId && (
                        <Box data-selection-indicator aria-hidden="true" />
                      )}
                      <Text fontWeight="semibold">{dish.dish_name}</Text>
                      {compact && (
                        <Text textStyle="helper" color="fg.muted">
                          {dish.dish_type_name ?? "Chưa phân loại"} ·{" "}
                          {dishStatusLabel[dish.dish_status]}
                        </Text>
                      )}
                    </Table.Cell>
                    {!compact && (
                      <>
                        <Table.Cell>
                          {dish.dish_type_name ?? "Chưa phân loại"}
                        </Table.Cell>
                        <Table.Cell>
                          {dishStatusLabel[dish.dish_status]}
                        </Table.Cell>
                      </>
                    )}
                    {!compact && (
                      <Table.Cell>
                        {baseRecipeState === "LOCKED" ? (
                          <>
                            <Text fontWeight="semibold">
                              🔒 Công thức gốc đã khóa
                            </Text>
                            <Text textStyle="helper" color="fg.muted">
                              Chỉnh qua Lệnh điều chỉnh
                            </Text>
                          </>
                        ) : (
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
                        )}
                      </Table.Cell>
                    )}
                    <Table.Cell>
                      <Button
                        size="sm"
                        variant="tertiary"
                        aria-label={`${actionLabel} ${dish.dish_name}`}
                        disabled={c.busy || Boolean(c.lock)}
                        onClick={(e) => {
                          onSelect(dish.dish_id, e.currentTarget);
                        }}
                      >
                        {compact ? "Chọn" : actionLabel}
                      </Button>
                    </Table.Cell>
                  </Table.Row>
                );
              })}
            </Table.Body>
          </Table.Root>
        )}
      </Box>
    </Box>
  );
}
