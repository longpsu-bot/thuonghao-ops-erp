import { Box, Button, Table, Text } from "@chakra-ui/react";
import { useEffect, useRef, useState, type ReactNode } from "react";
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
  toolbar,
}: {
  c: DishRecipeController;
  compact: boolean;
  toolbar?: ReactNode;
  onSelect: (id: string, button: HTMLButtonElement) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const viewport = useRef<HTMLDivElement>(null);
  useEffect(() => setExpanded(false), [c.context?.dishId, compact]);
  useEffect(() => {
    if (!compact) return;
    const container = viewport.current;
    const selected = container?.querySelector<HTMLButtonElement>(
      'button[aria-pressed="true"]',
    );
    if (!container || !selected) return;
    const reveal = () => {
      const frame = container.getBoundingClientRect();
      const item = selected.getBoundingClientRect();
      if (item.top < frame.top) container.scrollTop += item.top - frame.top;
      else if (item.bottom > frame.bottom)
        container.scrollTop += item.bottom - frame.bottom;
    };
    reveal();
    // Table-to-list reflow and browser scroll anchoring settle after commit.
    const frame = window.requestAnimationFrame(reveal);
    const observer =
      typeof ResizeObserver === "undefined" ? null : new ResizeObserver(reveal);
    observer?.observe(container);
    if (container.firstElementChild)
      observer?.observe(container.firstElementChild);
    return () => {
      window.cancelAnimationFrame(frame);
      observer?.disconnect();
    };
  }, [compact, c.context?.dishId, c.visibleDishes, expanded]);
  return (
    <Box minW="var(--atlas-layout-zero, 0)">
      {compact && c.context && (
        <Box display={{ base: "block", xl: "none" }} px="sm" py="xs">
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
      {compact && (
        <Box display={{ base: expanded ? "block" : "none", xl: "block" }}>
          {toolbar}
        </Box>
      )}
      <Box
        ref={viewport}
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
        {c.loading && !c.visibleDishes.length ? (
          <Text p="md" role="status">
            Đang tải danh mục món…
          </Text>
        ) : compact ? (
          <Box
            as="ul"
            aria-label="Điều hướng món"
            m="var(--atlas-layout-zero, 0)"
            p="var(--atlas-layout-zero, 0)"
            listStyleType="none"
          >
            {!c.visibleDishes.length && (
              <Box as="li">
                <Text p="md">Không có món phù hợp bộ lọc.</Text>
              </Box>
            )}
            {c.visibleDishes.map((dish) => {
              const selected = dish.dish_id === c.context?.dishId;
              const action =
                dishBaseRecipeState(c, dish.dish_id) === "LOCKED"
                  ? "Xem"
                  : "Sửa";
              return (
                <Box
                  as="li"
                  key={dish.dish_id}
                  display={{
                    base: !expanded && !selected ? "none" : "block",
                    xl: "block",
                  }}
                >
                  <Button
                    variant="tertiary"
                    w="full"
                    h="var(--atlas-layout-content-height, auto)"
                    minH="control"
                    px="md"
                    py="sm"
                    justifyContent="flex-start"
                    textAlign="left"
                    whiteSpace="normal"
                    borderRadius="var(--atlas-layout-zero, 0)"
                    borderBottomWidth="var(--atlas-layout-edge, 1px)"
                    borderColor="border.subtle"
                    bg={selected ? "bg.selected" : "bg.workbench"}
                    aria-pressed={selected}
                    aria-label={`${action} công thức ${dish.dish_name}`}
                    data-dish-select={dish.dish_id}
                    disabled={c.busy || Boolean(c.lock)}
                    onClick={(event) =>
                      onSelect(dish.dish_id, event.currentTarget)
                    }
                  >
                    <Box
                      minW="var(--atlas-layout-zero, 0)"
                      borderLeftWidth="var(--atlas-layout-rail, 3px)"
                      borderColor={selected ? "border.accent" : "transparent"}
                      pl="sm"
                    >
                      <Text fontWeight="semibold" overflowWrap="anywhere">
                        {dish.dish_name}
                      </Text>
                      <Text
                        textStyle="helper"
                        color="fg.muted"
                        mt="xs"
                        overflowWrap="anywhere"
                      >
                        {dish.dish_type_name ?? "Chưa phân loại"} ·{" "}
                        {dishStatusLabel[dish.dish_status]}
                        {selected && " · Đang chọn"}
                      </Text>
                    </Box>
                  </Button>
                </Box>
              );
            })}
          </Box>
        ) : !c.visibleDishes.length ? (
          <Text p="md">
            {c.catalog.dishes.length
              ? "Không có món phù hợp bộ lọc."
              : "Chưa có món. Tạo món mới để bắt đầu."}
          </Text>
        ) : (
          <Table.Root
            aria-label="Danh mục món"
            stickyHeader
            tableLayout="fixed"
            w={
              compact
                ? "var(--atlas-dish-compact-table-width, 340px)"
                : "var(--atlas-dish-table-width, 870px)"
            }
            minW={
              compact
                ? "var(--atlas-dish-compact-table-width, 340px)"
                : "var(--atlas-dish-table-width, 870px)"
            }
          >
            <Table.ColumnGroup>
              <Table.Column w="var(--atlas-dish-identity-width, 220px)" />
              {!compact && (
                <>
                  <Table.Column w="var(--atlas-dish-type-width, 140px)" />
                  <Table.Column w="var(--atlas-dish-state-width, 130px)" />
                  <Table.Column w="var(--atlas-dish-recipe-width, 260px)" />
                </>
              )}
              <Table.Column w="var(--atlas-dish-action-width, 120px)" />
            </Table.ColumnGroup>
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
                        data-dish-select={dish.dish_id}
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
