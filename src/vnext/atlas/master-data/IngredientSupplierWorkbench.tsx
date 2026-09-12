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

export function IngredientSupplierWorkbench({
  authSubject,
  api,
}: {
  authSubject: string | null;
  api: IngredientSupplierMasterDataApi;
}) {
  const c = useIngredientSupplierWorkbench({ authSubject, api });
  const detailOpen = Boolean(c.activeSurface || c.review);
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
      <Box p="md">
        <Text textStyle="helper" color="fg.muted">
          Nguyên liệu và Nhà cung ứng
        </Text>
        <Flex
          mt="xs"
          gap="xs"
          role="tablist"
          aria-label="Công việc dữ liệu gốc"
        >
          <Button
            role="tab"
            aria-selected={c.job === "ingredients"}
            variant={c.job === "ingredients" ? "businessPrimary" : "utility"}
            onClick={() => c.requestJob("ingredients")}
          >
            Nguyên liệu
          </Button>
          <Button
            role="tab"
            aria-selected={c.job === "suppliers"}
            variant={c.job === "suppliers" ? "businessPrimary" : "utility"}
            onClick={() => c.requestJob("suppliers")}
          >
            Nhà cung ứng
          </Button>
        </Flex>
        <Heading as="h1" textStyle="workbenchTitle" mt="sm">
          {c.job === "ingredients" ? "Nguyên liệu" : "Nhà cung ứng"}
        </Heading>
      </Box>
      {c.job === "ingredients" ? (
        <IngredientToolbar c={c} />
      ) : (
        <SupplierToolbar c={c} />
      )}
      {(c.notice || c.error) && (
        <Box px="md" pt="sm" role={c.lock || c.error ? "alert" : "status"}>
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
        mt="sm"
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: detailOpen
            ? "minmax(0, 62fr) minmax(320px, 38fr)"
            : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
      >
        {c.job === "ingredients" ? (
          <IngredientCatalogue
            ingredients={c.visibleIngredients}
            selectedId={c.selectedIngredient?.ingredient_id}
            onSelect={c.requestIngredient}
          />
        ) : (
          <SupplierCatalogue
            suppliers={c.visibleSuppliers}
            selectedId={c.selectedSupplier?.supplier_id}
            onSelect={c.requestSupplier}
          />
        )}
        {c.review ? (
          <MasterDataReview c={c} />
        ) : (
          <>
            <IngredientDetail c={c} />
            <SupplierDetail c={c} />
            <IngredientPriorityEditor c={c} />
          </>
        )}
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
        variant="businessPrimary"
        disabled={Boolean(c.lock)}
        onClick={() => c.requestIngredient("NEW")}
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
        variant="businessPrimary"
        disabled={Boolean(c.lock)}
        onClick={() => c.requestSupplier("NEW")}
      >
        Tạo nhà cung ứng
      </Button>
    </Grid>
  );
}
