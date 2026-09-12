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
import { useEffect, useRef, useImperativeHandle, type Ref } from "react";
import type { RecipeJobHandle } from "./useChangeOrderWorkbench";
import { AtlasDateInput } from "../AtlasDateInput";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import type { DishRecipeApi } from "../bridges/dishRecipe";
import { BaseRecipeEditor } from "./BaseRecipeEditor";
import { DishCatalogue, dishStatusLabel } from "./DishCatalogue";
import { DishEditor } from "./DishEditor";
import { EffectiveRecipeView } from "./EffectiveRecipeView";
import { RecipeDirtyExitDialog, RecipeUtilityDialog } from "./RecipeDialogs";
import { RecipeReview } from "./RecipeReview";
import { useDishRecipeWorkbench } from "./useDishRecipeWorkbench";

export function DishRecipeWorkbench(props: {
  authSubject: string | null;
  api: DishRecipeApi;
  initialDate?: string;
  embedded?: boolean;
  exitRef?: Ref<RecipeJobHandle>;
}) {
  const c = useDishRecipeWorkbench(props);
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
  const open = Boolean(c.context || c.surface === "create");
  const wasOpen = useRef(false);
  useEffect(() => {
    if (open) workspace.current?.focus();
    else if (wasOpen.current) origin.current?.focus();
    wasOpen.current = open;
  }, [open, c.context?.dishId, c.surface]);
  const modal = ["copy", "import", "lifecycle"].includes(c.surface ?? "");
  const operationallyLocked =
    c.effective?.is_operationally_locked ||
    c.effective?.editable_state === "LOCKED_CHANGE_ORDER";
  const catalogueToolbar = (
    <Flex
      display={{ base: open ? "none" : "flex", lg: "flex" }}
      px="md"
      py="sm"
      bg="bg.toolbar"
      gap="sm"
      align="flex-end"
      wrap="wrap"
    >
      <Field.Root flex="var(--atlas-layout-search-grow, 1 1 200px)">
        <Field.Label>Tìm món</Field.Label>
        <Input
          value={c.query}
          placeholder="Tên món, loại món, nguyên liệu…"
          onChange={(e) => c.setQuery(e.target.value)}
        />
      </Field.Root>
      <Field.Root
        w={
          open
            ? "var(--atlas-layout-compact-filter, 119px)"
            : "var(--atlas-layout-filter-width, 140px)"
        }
      >
        <Field.Label>Trạng thái</Field.Label>
        <NativeSelect.Root>
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
      <Field.Root
        w={
          open
            ? "var(--atlas-layout-compact-filter, 119px)"
            : "var(--atlas-layout-filter-width, 160px)"
        }
      >
        <Field.Label>Loại món</Field.Label>
        <NativeSelect.Root>
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
      <AtlasRefreshButton
        loading={c.loading}
        disabled={c.refreshDisabled}
        onClick={() => c.transition({ kind: "refresh" })}
      />
      <Button
        variant="businessPrimary"
        disabled={!c.canCommand}
        onClick={() => c.transition({ kind: "create" })}
      >
        Tạo món mới
      </Button>
    </Flex>
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
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      {!props.embedded && (
        <Box px="md" py="sm">
          <Heading as="h1" textStyle="workbenchTitle">
            Công thức
          </Heading>
        </Box>
      )}
      {!open && catalogueToolbar}
      {!open && <Box px="md">{feedback}</Box>}
      <Flex px="md" py="xs" justify="space-between" align="center">
        <Text textStyle="helper" color="fg.muted">
          {c.visibleDishes.length} món
        </Text>
        <Button
          variant="utility"
          size="sm"
          disabled={!c.canCommand}
          onClick={() => c.transition({ kind: "import" })}
        >
          Nhập workbook
        </Button>
      </Flex>
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: open ? "minmax(260px, 290px) minmax(0, 1fr)" : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
      >
        <Box minW="var(--atlas-layout-zero, 0)">
          {open && catalogueToolbar}
          <DishCatalogue
            c={c}
            compact={open}
            onSelect={(id, button) => {
              origin.current = button;
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
            borderLeftWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.subtle"
          >
            <Flex justify="space-between" align="center" gap="sm">
              {!c.dishDraft && (
                <Box>
                  <Heading as="h2" textStyle="section">
                    {c.dish?.dish_name}
                  </Heading>
                  <Flex gap="sm" mt="xs" color="fg.muted" textStyle="helper">
                    <Text>{c.dish?.dish_type_name ?? "Chưa phân loại"}</Text>
                    <Text>{c.dish && dishStatusLabel[c.dish.dish_status]}</Text>
                  </Flex>
                </Box>
              )}
              <Button
                variant="utility"
                size="sm"
                aria-label="Đóng công thức"
                disabled={c.busy || Boolean(c.lock)}
                onClick={() => c.transition({ kind: "close" })}
              >
                Đóng
              </Button>
            </Flex>
            {c.dishDraft ? (
              <>
                {feedback}
                <DishEditor c={c} />
              </>
            ) : (
              <>
                <Flex mt="sm" gap="sm" wrap="wrap" align="flex-end">
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
                  <Flex
                    gap="xs"
                    wrap="wrap"
                    ml={{
                      base: "var(--atlas-layout-zero, 0)",
                      lg: "var(--atlas-layout-utility-margin, auto)",
                    }}
                  >
                    <Button
                      size="sm"
                      variant="utility"
                      disabled={!c.canCommand}
                      onClick={() => c.transition({ kind: "edit" })}
                    >
                      Sửa thông tin món
                    </Button>
                    {c.canCopy && (
                      <Button
                        size="sm"
                        variant="utility"
                        onClick={() => c.transition({ kind: "copy" })}
                      >
                        Sao chép công thức
                      </Button>
                    )}
                  </Flex>
                </Flex>
                {feedback}
                {operationallyLocked && (
                  <Box mt="sm">
                    <Text>
                      Món này đã được sử dụng trong vận hành. Thành phần gốc
                      không thể sửa trực tiếp.
                    </Text>
                    <Text textStyle="helper" color="fg.muted" mt="xs">
                      Thay đổi tiếp theo được thực hiện trong Lệnh điều chỉnh.
                    </Text>
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
                  <Flex mt="md" gap="sm" wrap="wrap" justify="flex-end">
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
