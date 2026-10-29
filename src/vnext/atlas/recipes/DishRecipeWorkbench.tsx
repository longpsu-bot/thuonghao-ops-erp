import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import {
  useEffect,
  useRef,
  useImperativeHandle,
  useState,
  type Ref,
} from "react";
import type { RecipeJobHandle } from "./useChangeOrderWorkbench";
import {
  useAtlasWorkbenchStatus,
  type AtlasModuleExitProps,
} from "../AtlasModuleExit";
import { AtlasDateInput } from "../AtlasDateInput";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { AtlasWorkbar, AtlasWorkbarActions } from "../AtlasWorkbar";
import { AtlasTaskContext } from "../AtlasTaskContext";
import { useAtlasWorkbenchActive } from "../AtlasVNextProvider";
import {
  focusFirstCompactFilter,
  preserveCompactFilterFocusOrder,
} from "../compactFilterFocus";
import type { DishRecipeApi } from "../bridges/dishRecipe";
import { BaseRecipeEditor } from "./BaseRecipeEditor";
import { DishCatalogue, dishStatusLabel } from "./DishCatalogue";
import { DishEditor } from "./DishEditor";
import { EffectiveRecipeView } from "./EffectiveRecipeView";
import { RecipeDirtyExitDialog, RecipeUtilityDialog } from "./RecipeDialogs";
import { RecipeReview } from "./RecipeReview";
import { useDishRecipeWorkbench } from "./useDishRecipeWorkbench";

function resetOwnerReadingPosition(node: HTMLElement | null) {
  let owner = node?.parentElement ?? null;
  while (owner) {
    const overflow = window.getComputedStyle(owner).overflowY;
    if (
      /(auto|scroll)/.test(overflow) &&
      owner.scrollHeight > owner.clientHeight
    ) {
      owner.scrollTop = 0;
      owner.scrollLeft = 0;
      return;
    }
    owner = owner.parentElement;
  }
}

export function DishRecipeWorkbench(
  props: AtlasModuleExitProps & {
    authSubject: string | null;
    api: DishRecipeApi;
    initialDate?: string;
    embedded?: boolean;
    exitRef?: Ref<RecipeJobHandle>;
    onOpenChangeOrders?: () => void;
  },
) {
  const c = useDishRecipeWorkbench(props);
  const active = useAtlasWorkbenchActive();
  useAtlasWorkbenchStatus(props.onWorkspaceStatus, {
    unsaved: c.dirty || c.utilityDirty,
    blocked: Boolean(
      c.loading ||
      c.busy ||
      c.lock ||
      c.review ||
      c.discardOpen ||
      ["copy", "import", "lifecycle"].includes(c.surface ?? ""),
    ),
    attention: c.lock ? (c.notice ?? undefined) : (c.error ?? undefined),
  });
  useImperativeHandle(props.exitRef, () => ({
    requestExit: (next) => {
      if (
        !c.review &&
        !c.loading &&
        !["copy", "import", "lifecycle"].includes(c.surface ?? "")
      )
        c.transition({ kind: "job", continue: next });
    },
  }));
  const workspace = useRef<HTMLDivElement>(null),
    origin = useRef<HTMLButtonElement | null>(null);
  const catalogue = useRef<HTMLDivElement>(null);
  const originDishId = useRef<string | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const compactFilters = useRef<HTMLDivElement>(null);
  const compactFilterTrigger = useRef<HTMLButtonElement>(null);
  const compactFilterOnward = useRef<HTMLDivElement>(null);
  const open = Boolean(c.context || c.surface === "create");
  const modal = ["copy", "import", "lifecycle"].includes(c.surface ?? "");
  const selectionKey =
    c.context?.dishId ?? (c.surface === "create" ? "create" : null);
  const wasOpen = useRef(false);
  const activeSelection = useRef<string | null>(null);
  const wasReview = useRef(false);
  useEffect(() => {
    if (!active || modal) return;
    if (open) {
      if (selectionKey !== activeSelection.current) {
        activeSelection.current = selectionKey;
        workspace.current?.focus({ preventScroll: true });
        resetOwnerReadingPosition(workspace.current);
      }
    } else if (wasOpen.current) {
      const trigger = origin.current?.isConnected
        ? origin.current
        : Array.from(
            catalogue.current?.querySelectorAll<HTMLButtonElement>(
              "button[data-dish-select]",
            ) ?? [],
          ).find(
            (button) => button.dataset.dishSelect === originDishId.current,
          );
      trigger?.focus();
      activeSelection.current = null;
    }
    wasOpen.current = open;
  }, [active, modal, open, selectionKey]);
  useEffect(() => {
    if (!active || modal) return;
    if (c.review && !wasReview.current) {
      workspace.current?.focus({ preventScroll: true });
      resetOwnerReadingPosition(workspace.current);
    }
    wasReview.current = c.review;
  }, [active, c.review, modal]);
  useEffect(() => {
    if (filtersOpen) focusFirstCompactFilter(compactFilters.current);
  }, [filtersOpen]);
  const operationallyLocked =
    c.effective?.is_operationally_locked ||
    c.effective?.editable_state === "LOCKED_CHANGE_ORDER";
  const canOpenChangeOrders = Boolean(
    operationallyLocked &&
    c.effective?.allowed_actions.includes("CREATE_CHANGE_ORDER") &&
    props.onOpenChangeOrders,
  );
  const catalogueToolbar = (
    <AtlasWorkbar
      display="grid"
      px={{ base: "sm", md: "md" }}
      py="sm"
      gap="sm"
      bg="bg.toolbar"
      aria-label="Bộ lọc công thức"
      alignItems="end"
      templateColumns={
        open
          ? "minmax(0, 1fr)"
          : {
              base: "minmax(0, 1fr) auto",
              md: "minmax(180px, 1fr) minmax(280px, 310px) auto",
            }
      }
    >
      <Field.Root
        minW="var(--atlas-layout-zero, 0)"
        gridRow={open ? "auto" : { base: "1", md: "auto" }}
      >
        <Field.Label display={{ base: "none", md: "block" }}>
          Tìm món
        </Field.Label>
        <Input
          aria-label="Tìm món"
          value={c.query}
          placeholder="Tên món, loại món, nguyên liệu…"
          onChange={(e) => c.setQuery(e.target.value)}
        />
      </Field.Root>
      <Grid
        ref={compactFilters}
        id="recipe-filters"
        display={{ base: filtersOpen ? "grid" : "none", md: "grid" }}
        gridColumn={open ? "1" : { base: "1 / -1", md: "auto" }}
        gridRow={open ? "auto" : { base: "3", md: "auto" }}
        templateColumns="repeat(2, minmax(0, 1fr))"
        gap="sm"
        minW="var(--atlas-layout-zero, 0)"
        onKeyDown={(event) => {
          if (filtersOpen)
            preserveCompactFilterFocusOrder(
              event,
              compactFilters.current,
              compactFilterTrigger.current,
              compactFilterOnward.current,
            );
        }}
      >
        <Field.Root minW="var(--atlas-layout-zero, 0)">
          <Field.Label>Trạng thái</Field.Label>
          <NativeSelect.Root minW="var(--atlas-layout-zero, 0)">
            <NativeSelect.Field
              value={c.statusFilter}
              onChange={(e) => c.setStatusFilter(e.target.value)}
            >
              <option value="ALL">Tất cả</option>
              {Object.entries(dishStatusLabel).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
        <Field.Root minW="var(--atlas-layout-zero, 0)">
          <Field.Label>Loại món</Field.Label>
          <NativeSelect.Root minW="var(--atlas-layout-zero, 0)">
            <NativeSelect.Field
              value={c.typeFilter}
              onChange={(e) => c.setTypeFilter(e.target.value)}
            >
              <option value="">Tất cả</option>
              {c.catalog.dish_types.map((t) => (
                <option key={t.dish_type_id} value={t.dish_type_id}>
                  {t.dish_type_name}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
      </Grid>
      <Button
        ref={compactFilterTrigger}
        display={{ base: "inline-flex", md: "none" }}
        gridColumn="2"
        gridRow="1"
        variant="secondary"
        minH="var(--atlas-layout-mobile-target, 44px)"
        aria-expanded={filtersOpen}
        aria-controls="recipe-filters"
        onClick={() => setFiltersOpen((value) => !value)}
      >
        Bộ lọc
      </Button>
      <Text
        display={{ base: filtersOpen ? "none" : "block", md: "none" }}
        gridColumn="1 / -1"
        gridRow="2"
        textStyle="helper"
        color="fg.muted"
      >
        Trạng thái:{" "}
        {c.statusFilter === "ALL" ? "Tất cả" : dishStatusLabel[c.statusFilter]}{" "}
        · Loại món:{" "}
        {c.typeFilter
          ? (c.catalog.dish_types.find(
              (type) => type.dish_type_id === c.typeFilter,
            )?.dish_type_name ?? "Không xác định")
          : "Tất cả"}
      </Text>
      <AtlasWorkbarActions
        ref={compactFilterOnward}
        gridColumn={open ? "1" : { base: "1 / -1", md: "auto" }}
        gridRow={open ? "auto" : { base: filtersOpen ? "4" : "3", md: "auto" }}
        justifyContent={{ base: "flex-start", md: "flex-end" }}
        flexWrap="wrap"
        minW="var(--atlas-layout-zero, 0)"
      >
        <AtlasRefreshButton
          loading={c.loading}
          disabled={c.refreshDisabled}
          onClick={() => c.transition({ kind: "refresh" })}
        />
        <Button
          variant="secondary"
          disabled={!c.canCommand}
          onClick={() => c.transition({ kind: "import" })}
        >
          Nhập từ Excel
        </Button>
        <Button
          variant={open ? "secondary" : "businessPrimary"}
          disabled={!c.canCommand}
          onClick={() => c.transition({ kind: "create" })}
        >
          Tạo món mới
        </Button>
      </AtlasWorkbarActions>
    </AtlasWorkbar>
  );
  const feedback = !modal && (c.notice || c.error) && (
    <Box py="sm" role={c.lock || c.error ? "alert" : "status"}>
      <Text
        color={
          c.lock ? "status.warning" : c.error ? "status.danger" : "fg.default"
        }
      >
        {c.notice ?? c.error}
      </Text>
      {(c.lock || c.error) && (
        <Button mt="xs" loading={c.loading} onClick={() => void c.recover()}>
          {c.lock === "stale"
            ? "Tải lại dữ liệu hiện tại"
            : c.lock
              ? "Tải lại để xác nhận"
              : "Thử tải lại dữ liệu"}
        </Button>
      )}
    </Box>
  );
  return (
    <Box
      as="section"
      aria-label="Công thức"
      bg="bg.workbench"
      borderRadius="workbench"
      minW="var(--atlas-layout-zero, 0)"
    >
      {!props.embedded && (
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh công thức"
          moduleLabel="Công thức"
          jobLabel="Công thức"
          compactSummary={
            open
              ? (c.dish?.dish_name ?? "Tạo món mới")
              : `${c.visibleDishes.length} món · ${c.date}`
          }
        />
      )}
      {!open && catalogueToolbar}
      {!open && <Box px="md">{feedback}</Box>}
      <Flex px="md" py="xs" justify="space-between" align="center">
        {!c.loading && !c.error && (
          <Text textStyle="helper" color="fg.muted">
            {c.visibleDishes.length} món
          </Text>
        )}
      </Flex>
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          xl: open ? "320px minmax(0, 1fr)" : "minmax(0, 1fr)",
        }}
        gap={open ? "md" : "var(--atlas-layout-zero, 0)"}
        p={open ? "sm" : "var(--atlas-layout-zero, 0)"}
        minW="var(--atlas-layout-zero, 0)"
      >
        <Box
          ref={catalogue}
          display={{ base: open ? "none" : "block", xl: "block" }}
          minW="var(--atlas-layout-zero, 0)"
        >
          <DishCatalogue
            c={c}
            compact={open}
            toolbar={catalogueToolbar}
            onSelect={(id, button) => {
              origin.current = button;
              originDishId.current = id;
              c.transition({ kind: "select", dishId: id });
            }}
          />
        </Box>
        {open && (
          <Box
            ref={workspace}
            tabIndex={-1}
            aria-label="Không gian công thức"
            p="md"
            minW="var(--atlas-layout-zero, 0)"
            borderRadius="workbench"
          >
            <Flex
              justify="space-between"
              align="flex-start"
              gap="sm"
              pb="sm"
              borderBottomWidth="var(--atlas-layout-edge, 1px)"
              borderColor="border.subtle"
            >
              {!c.dishDraft && (
                <Box minW="var(--atlas-layout-zero, 0)">
                  <Heading as="h2" textStyle="section" overflowWrap="anywhere">
                    {c.dish?.dish_name}
                  </Heading>
                  <Flex
                    gap="sm"
                    mt="xs"
                    wrap="wrap"
                    color="fg.muted"
                    textStyle="helper"
                  >
                    <Text>{c.dish?.dish_type_name ?? "Chưa phân loại"}</Text>
                    <Text>{c.dish && dishStatusLabel[c.dish.dish_status]}</Text>
                  </Flex>
                </Box>
              )}
              <Flex gap="xs" wrap="wrap" justify="flex-end">
                {c.dishDraft && c.surface === "create" && (
                  <Button
                    display={{ base: "inline-flex", xl: "none" }}
                    variant="secondary"
                    size="sm"
                    disabled={!c.canCommand}
                    onClick={() => c.transition({ kind: "import" })}
                  >
                    Nhập từ Excel
                  </Button>
                )}
                <Button
                  variant="tertiary"
                  size="sm"
                  flexShrink="var(--atlas-layout-zero, 0)"
                  aria-label="Đóng công thức"
                  disabled={c.busy || Boolean(c.lock)}
                  onClick={() => c.transition({ kind: "close" })}
                >
                  Đóng
                </Button>
              </Flex>
            </Flex>
            {!c.dishDraft && (
              <Flex gap="xs" wrap="wrap" mt="sm" justify="flex-end">
                <Button
                  size="sm"
                  variant="tertiary"
                  disabled={!c.canCommand}
                  onClick={() => c.transition({ kind: "edit" })}
                >
                  Sửa thông tin món
                </Button>
                {c.canCopy && (
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => c.transition({ kind: "copy" })}
                  >
                    Sao chép công thức
                  </Button>
                )}
              </Flex>
            )}
            {c.dishDraft ? (
              <>
                {feedback}
                <DishEditor c={c} />
              </>
            ) : (
              <>
                <Flex
                  mt="sm"
                  p="sm"
                  bg="bg.toolbar"
                  gap="sm"
                  wrap="wrap"
                  align="flex-end"
                >
                  <Field.Root w="var(--atlas-layout-context-width, 160px)">
                    <Field.Label>Loại công thức</Field.Label>
                    <NativeSelect.Root disabled={c.busy || Boolean(c.lock)}>
                      <NativeSelect.Field
                        value={c.context?.schoolTypeId ?? ""}
                        onChange={(e) =>
                          c.transition({
                            kind: "scope",
                            schoolTypeId: e.target.value,
                          })
                        }
                      >
                        {c.scopes.map((s) => (
                          <option
                            key={s.school_type_id}
                            value={s.school_type_id}
                          >
                            {s.school_type_name}
                          </option>
                        ))}
                      </NativeSelect.Field>
                      <NativeSelect.Indicator />
                    </NativeSelect.Root>
                  </Field.Root>
                  <Box w="var(--atlas-layout-context-width, 180px)">
                    <AtlasDateInput
                      label="Ngày áp dụng"
                      value={c.date}
                      disabled={c.busy || Boolean(c.lock)}
                      onValueChange={(date) =>
                        c.transition({ kind: "date", date })
                      }
                    />
                  </Box>
                </Flex>
                {feedback}
                {operationallyLocked && (
                  <Box mt="sm">
                    <Text>
                      Công thức này đã được sử dụng trong vận hành. Công thức
                      gốc chỉ đọc; thay đổi tiếp theo được thực hiện bằng Lệnh
                      điều chỉnh.
                    </Text>
                    {canOpenChangeOrders && (
                      <Button
                        mt="sm"
                        variant="secondary"
                        onClick={() => props.onOpenChangeOrders?.()}
                      >
                        Tạo lệnh điều chỉnh
                      </Button>
                    )}
                  </Box>
                )}
                {c.loading && (
                  <Text mt="sm" role="status">
                    Đang tải công thức…
                  </Text>
                )}
                {c.review ? (
                  <RecipeReview c={c} />
                ) : (
                  <BaseRecipeEditor
                    key={`${c.context?.dishId}-${c.context?.schoolTypeId}`}
                    c={c}
                  />
                )}
                <EffectiveRecipeView effective={c.effective} />
                {c.recipeDraft && (c.review || c.canEdit) && (
                  <Flex
                    as="footer"
                    position="sticky"
                    bottom="var(--atlas-layout-zero, 0)"
                    bg="bg.workbench"
                    zIndex="var(--atlas-layout-footer-layer, 2)"
                    mt="md"
                    pt="md"
                    borderTopWidth="var(--atlas-layout-edge, 1px)"
                    borderColor="border.subtle"
                    gap="sm"
                    wrap="wrap"
                    justify="flex-end"
                  >
                    {c.review ? (
                      <>
                        <Button
                          disabled={c.busy || Boolean(c.lock)}
                          onClick={c.backToRecipe}
                        >
                          Quay lại
                        </Button>
                        <Button
                          variant="businessPrimary"
                          loading={c.busy}
                          disabled={!c.canEdit || !c.validDraft}
                          onClick={() => void c.saveRecipe()}
                        >
                          Lưu công thức
                        </Button>
                      </>
                    ) : (
                      <Button
                        variant="businessPrimary"
                        disabled={!c.validDraft}
                        onClick={c.reviewRecipe}
                      >
                        Xem thay đổi
                      </Button>
                    )}
                  </Flex>
                )}
              </>
            )}
          </Box>
        )}
      </Grid>
      <RecipeDirtyExitDialog c={c} />
      <RecipeUtilityDialog key={`${props.authSubject}-${c.surface}`} c={c} />
    </Box>
  );
}
