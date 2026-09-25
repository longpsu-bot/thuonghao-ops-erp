import { useEffect, useImperativeHandle, useRef } from "react";
import type { CSSProperties } from "react";
import type { AtlasModuleExitProps } from "../AtlasModuleExit";
import {
  Box,
  Button,
  Field,
  Grid,
  Input,
  NativeSelect,
  Tabs,
  Text,
} from "@chakra-ui/react";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import type { IngredientSupplierMasterDataApi } from "../bridges/ingredientSupplierMasterData";
import { IngredientCatalogue } from "./IngredientCatalogue";
import { IngredientDetail } from "./IngredientDetail";
import { IngredientLifecycleDialog } from "./IngredientLifecycleDialog";
import { IngredientPriorityEditor } from "./IngredientPriorityEditor";
import { MasterDataDirtyExitDialog } from "./MasterDataDirtyExitDialog";
import { MasterDataReview } from "./MasterDataReview";
import { SupplierCatalogue } from "./SupplierCatalogue";
import { SupplierDetail } from "./SupplierDetail";
import { useIngredientSupplierWorkbench } from "./useIngredientSupplierWorkbench";
import { AtlasTaskContext } from "../AtlasTaskContext";

export function IngredientSupplierWorkbench({
  authSubject,
  api,
  exitRef,
}: AtlasModuleExitProps & {
  authSubject: string | null;
  api: IngredientSupplierMasterDataApi;
}) {
  const c = useIngredientSupplierWorkbench({ authSubject, api });
  useImperativeHandle(exitRef, () => ({ requestExit: c.requestExit }));
  const detailOpen = Boolean(c.activeSurface || c.review);
  const detailKind = c.review?.kind ?? c.activeSurface?.kind;
  const detailId =
    c.selectedIngredient?.ingredient_id ??
    c.selectedSupplier?.supplier_id ??
    "create";
  const detailLabel =
    detailKind === "ingredient"
      ? c.review
        ? "Xem thay đổi nguyên liệu"
        : "Chi tiết nguyên liệu"
      : detailKind === "supplier"
        ? c.review
          ? "Xem thay đổi nhà cung ứng"
          : "Chi tiết nhà cung ứng"
        : detailKind === "priorities"
          ? c.review
            ? "Xem thay đổi ưu tiên nhà cung ứng"
            : "Ưu tiên nhà cung ứng"
          : null;
  const rowTrigger = useRef<HTMLButtonElement | null>(null);
  const wasDetailOpen = useRef(false);
  useEffect(() => {
    if (wasDetailOpen.current && !detailOpen) rowTrigger.current?.focus();
    wasDetailOpen.current = detailOpen;
  }, [detailOpen]);
  const statusLabel = {
    ALL: "Tất cả trạng thái",
    ACTIVE: "Đang dùng",
    INACTIVE: "Ngừng dùng",
    ARCHIVED: "Lưu trữ",
  }[c.ingredientStatus];
  return (
    <Box
      as="section"
      aria-label="Nguyên liệu và Nhà cung ứng"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: "var(--atlas-task-context-desktop-width, 196px) minmax(0, 1fr)",
        }}
      >
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh công việc dữ liệu gốc"
          moduleLabel="Nguyên liệu và Nhà cung ứng"
          jobLabel={c.job === "ingredients" ? "Nguyên liệu" : "Nhà cung ứng"}
          details={[
            {
              label: "Kết quả",
              value:
                c.job === "ingredients"
                  ? `${c.visibleIngredients.length} / ${c.ingredients.length}`
                  : `${c.visibleSuppliers.length} / ${c.suppliers.length}`,
            },
            ...(c.job === "ingredients"
              ? [{ label: "Trạng thái", value: statusLabel }]
              : []),
          ]}
        />
        <Box minW="var(--atlas-layout-zero, 0)" bg="bg.workbench">
          <Tabs.Root
            value={c.job}
            variant="line"
            activationMode="manual"
            onValueChange={({ value }) => {
              if (
                value !== c.job &&
                (value === "ingredients" || value === "suppliers")
              )
                c.requestJob(value);
            }}
          >
            <Box px="md" py="sm">
              <Tabs.List aria-label="Công việc dữ liệu gốc">
                <Tabs.Trigger value="ingredients">Nguyên liệu</Tabs.Trigger>
                <Tabs.Trigger value="suppliers">Nhà cung ứng</Tabs.Trigger>
              </Tabs.List>
            </Box>
            <Tabs.Content
              value={c.job}
              p="var(--atlas-layout-zero, 0)"
              _horizontal={{ pt: "var(--atlas-layout-zero, 0)" }}
            >
              {c.job === "ingredients" ? (
                <IngredientToolbar
                  c={c}
                  onCreate={() => {
                    rowTrigger.current = null;
                    c.requestIngredient("NEW");
                  }}
                />
              ) : (
                <SupplierToolbar c={c} />
              )}
              {(c.notice || c.error) && (
                <Box
                  px="md"
                  pt="sm"
                  role={c.lock || c.error ? "alert" : "status"}
                >
                  <Text
                    color={
                      c.lock
                        ? "status.warning"
                        : c.error
                          ? "status.danger"
                          : "status.success"
                    }
                  >
                    {c.notice ?? c.error}
                  </Text>
                  {(c.lock || c.error) && (
                    <Button
                      mt="xs"
                      size="sm"
                      loading={c.loading}
                      onClick={() => void c.refresh()}
                    >
                      {c.lock === "stale"
                        ? "Tải lại dữ liệu hiện tại"
                        : c.lock
                          ? "Tải lại để xác nhận"
                          : "Thử tải lại dữ liệu"}
                    </Button>
                  )}
                </Box>
              )}
              <Grid
                data-testid="ingredient-supplier-master-detail"
                data-detail-open={detailOpen || undefined}
                style={
                  {
                    "--atlas-attached-detail-width": "320px",
                  } as CSSProperties
                }
                mt="sm"
                templateColumns={{
                  base: "minmax(0, 1fr)",
                  lg: detailOpen
                    ? c.job === "ingredients"
                      ? "minmax(0, 1fr) var(--atlas-attached-detail-width)"
                      : "minmax(0, 62fr) minmax(320px, 38fr)"
                    : "minmax(0, 1fr)",
                }}
                minW="var(--atlas-layout-zero, 0)"
              >
                {c.job === "ingredients" ? (
                  <IngredientCatalogue
                    ingredients={c.visibleIngredients}
                    totalCount={c.ingredients.length}
                    selectedId={c.selectedIngredient?.ingredient_id}
                    onSelect={(id, trigger) => {
                      rowTrigger.current = trigger;
                      c.requestIngredient(id);
                    }}
                  />
                ) : (
                  <SupplierCatalogue
                    suppliers={c.visibleSuppliers}
                    selectedId={c.selectedSupplier?.supplier_id}
                    onSelect={c.requestSupplier}
                  />
                )}
                {detailLabel && (
                  <Box
                    key={`${c.job}:${c.review ? "review" : "detail"}:${detailKind}:${detailId}`}
                    role="region"
                    aria-label={detailLabel}
                    data-testid="master-detail-content"
                    data-detail-animation="true"
                    animationStyle="detailEnter"
                    minW="var(--atlas-layout-zero, 0)"
                  >
                    {c.review ? (
                      <MasterDataReview c={c} />
                    ) : (
                      <>
                        <IngredientDetail c={c} />
                        <SupplierDetail c={c} />
                        <IngredientPriorityEditor c={c} />
                      </>
                    )}
                  </Box>
                )}
              </Grid>
            </Tabs.Content>
          </Tabs.Root>
        </Box>
      </Grid>
      <IngredientLifecycleDialog c={c} />
      <MasterDataDirtyExitDialog
        open={c.discardOpen}
        onCancel={c.cancelDiscard}
        onDiscard={c.confirmDiscard}
        onExitComplete={c.completeDiscardTransition}
      />
    </Box>
  );
}

function IngredientToolbar({
  c,
  onCreate,
}: {
  c: ReturnType<typeof useIngredientSupplierWorkbench>;
  onCreate: () => void;
}) {
  return (
    <Grid
      bg="bg.toolbar"
      p="md"
      gap="sm"
      alignItems="end"
      templateColumns={{
        base: "minmax(0, 1fr)",
        md: "minmax(220px, 1fr) minmax(150px, 220px) auto auto",
      }}
    >
      <Field.Root>
        <Field.Label>Tìm nguyên liệu</Field.Label>
        <Input
          aria-label="Tìm nguyên liệu"
          placeholder="Tên hoặc thông tin liên quan"
          value={c.ingredientQuery}
          onChange={(e) => c.setIngredientQuery(e.target.value)}
        />
      </Field.Root>
      <Field.Root>
        <Field.Label>Trạng thái</Field.Label>
        <NativeSelect.Root>
          <NativeSelect.Field
            aria-label="Trạng thái"
            value={c.ingredientStatus}
            onChange={(e) =>
              c.setIngredientStatus(e.target.value as typeof c.ingredientStatus)
            }
          >
            <option value="ALL">Tất cả</option>
            <option value="ACTIVE">Đang dùng</option>
            <option value="INACTIVE">Ngừng dùng</option>
            <option value="ARCHIVED">Lưu trữ</option>
          </NativeSelect.Field>
          <NativeSelect.Indicator />
        </NativeSelect.Root>
      </Field.Root>
      <AtlasRefreshButton
        loading={c.loading}
        disabled={!c.canRefresh}
        onClick={() => void c.refresh()}
      />
      <Button
        variant={c.activeSurface || c.review ? "secondary" : "businessPrimary"}
        disabled={Boolean(c.lock)}
        onClick={onCreate}
      >
        Tạo nguyên liệu
      </Button>
    </Grid>
  );
}
function SupplierToolbar({
  c,
}: {
  c: ReturnType<typeof useIngredientSupplierWorkbench>;
}) {
  return (
    <Grid
      bg="bg.toolbar"
      p="md"
      gap="sm"
      alignItems="end"
      templateColumns={{
        base: "minmax(0, 1fr)",
        md: "minmax(240px, 1fr) auto auto",
      }}
    >
      <Field.Root>
        <Field.Label>Tìm nhà cung ứng</Field.Label>
        <Input
          aria-label="Tìm nhà cung ứng"
          placeholder="Tên hoặc thông tin liên hệ"
          value={c.supplierQuery}
          onChange={(e) => c.setSupplierQuery(e.target.value)}
        />
      </Field.Root>
      <AtlasRefreshButton
        loading={c.loading}
        disabled={!c.canRefresh}
        onClick={() => void c.refresh()}
      />
      <Button
        variant={c.activeSurface || c.review ? "secondary" : "businessPrimary"}
        disabled={Boolean(c.lock)}
        onClick={() => c.requestSupplier("NEW")}
      >
        Tạo nhà cung ứng
      </Button>
    </Grid>
  );
}
