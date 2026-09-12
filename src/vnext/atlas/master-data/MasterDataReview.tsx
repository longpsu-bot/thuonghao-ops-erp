import { Box, Button, Flex, Heading, Table, Text } from "@chakra-ui/react";
import { useEffect, useRef } from "react";
import type { SupplierMasterData } from "../bridges/ingredientSupplierMasterData";
import { formatVietnameseDecimal } from "./ingredientSupplierModel";
import type {
  IngredientSupplierWorkbenchController,
  WorkbenchReview,
} from "./useIngredientSupplierWorkbench";

export function MasterDataReview({
  c,
}: {
  c: IngredientSupplierWorkbenchController;
}) {
  const panel = useRef<HTMLElement>(null);
  useEffect(() => panel.current?.focus(), []);
  if (!c.review) return null;
  const review = c.review;
  const name =
    review.kind === "ingredient"
      ? "Xem thay đổi nguyên liệu"
      : review.kind === "supplier"
        ? "Xem thay đổi nhà cung ứng"
        : "Xem thay đổi ưu tiên";
  const reviewedName =
    review.kind === "priorities"
      ? review.ingredientName
      : review.mode === "create"
        ? "Mới"
        : review.kind === "ingredient"
          ? review.after.ingredientName
          : review.after.supplierName;
  return (
    <Box
      as="aside"
      ref={panel}
      tabIndex={-1}
      aria-label={name}
      bg="bg.subtle"
      borderLeftWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      display="flex"
      flexDirection="column"
    >
      <Flex p="md" justify="space-between" align="start" gap="sm">
        <Box>
          <Text textStyle="helper" color="fg.muted">
            Xem thay đổi
          </Text>
          <Heading as="h2" textStyle="section">
            {reviewedName}
          </Heading>
        </Box>
        <Button size="sm" variant="utility" onClick={c.closeReview}>
          Quay lại chỉnh sửa
        </Button>
      </Flex>
      <Box
        px="md"
        overflow="auto"
        maxH="var(--atlas-layout-review-height, calc(100dvh - 390px))"
      >
        {review.kind === "ingredient" && (
          <IngredientReviewTable review={review} c={c} />
        )}
        {review.kind === "supplier" && <SupplierReviewTable review={review} />}
        {review.kind === "priorities" && (
          <PriorityReviewTable review={review} suppliers={c.suppliers} />
        )}
      </Box>
      <Flex mt="var(--atlas-layout-auto, auto)" p="md" justify="end">
        <Button
          variant="businessPrimary"
          loading={c.saving}
          disabled={Boolean(c.lock)}
          onClick={() => void c.saveReview()}
        >
          {review.kind === "ingredient"
            ? "Lưu nguyên liệu"
            : review.kind === "supplier"
              ? "Lưu nhà cung ứng"
              : "Lưu ưu tiên"}
        </Button>
      </Flex>
    </Box>
  );
}

function Comparison({
  rows,
  creating,
}: {
  rows: { label: string; before?: string; after: string }[];
  creating: boolean;
}) {
  return (
    <Table.Root aria-label="So sánh trước và sau">
      <Table.Header>
        <Table.Row>
          <Table.ColumnHeader>Thông tin</Table.ColumnHeader>
          {!creating && <Table.ColumnHeader>Trước</Table.ColumnHeader>}
          <Table.ColumnHeader>{creating ? "Mới" : "Sau"}</Table.ColumnHeader>
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {rows.map((row) => (
          <Table.Row key={row.label}>
            <Table.Cell fontWeight="semibold">{row.label}</Table.Cell>
            {!creating && <Table.Cell>{row.before || "—"}</Table.Cell>}
            <Table.Cell>{row.after || "—"}</Table.Cell>
          </Table.Row>
        ))}
      </Table.Body>
    </Table.Root>
  );
}
function IngredientReviewTable({
  review,
  c,
}: {
  review: Extract<WorkbenchReview, { kind: "ingredient" }>;
  c: IngredientSupplierWorkbenchController;
}) {
  const unit = (id: string) =>
    c.units.find((item) => item.unit_id === id)?.unit_name ?? "—";
  const type = (id: string) =>
    c.ingredientTypes.find((item) => item.ingredient_type_id === id)
      ?.ingredient_type_name ??
    c.selectedIngredient?.ingredient_type_name ??
    "—";
  const group = (id: string) =>
    c.ingredientOrderGroups.find(
      (item) => item.ingredient_order_group_id === id,
    )?.ingredient_order_group_name ??
    c.selectedIngredient?.ingredient_order_group_name ??
    "—";
  return (
    <Comparison
      creating={!review.before}
      rows={[
        {
          label: "Tên",
          before: review.before?.ingredientName,
          after: review.after.ingredientName,
        },
        {
          label: "Đơn vị mua",
          before: review.before
            ? unit(review.before.purchaseUnitId)
            : undefined,
          after: unit(review.after.purchaseUnitId),
        },
        {
          label: "Loại nguyên liệu",
          before: review.before
            ? type(review.before.ingredientTypeId)
            : undefined,
          after: type(review.after.ingredientTypeId),
        },
        {
          label: "Nhóm đặt hàng",
          before: review.before
            ? group(review.before.ingredientOrderGroupId)
            : undefined,
          after: group(review.after.ingredientOrderGroupId),
        },
        {
          label: "Mức làm tròn",
          before: review.before
            ? formatVietnameseDecimal(Number(review.before.orderStep))
            : undefined,
          after: formatVietnameseDecimal(review.after.orderStepValue),
        },
      ]}
    />
  );
}
function SupplierReviewTable({
  review,
}: {
  review: Extract<WorkbenchReview, { kind: "supplier" }>;
}) {
  return (
    <Comparison
      creating={!review.before}
      rows={[
        {
          label: "Tên nhà cung ứng",
          before: review.before?.supplierName,
          after: review.after.supplierName,
        },
        {
          label: "Người liên hệ",
          before: review.before?.contactName,
          after: review.after.contactName,
        },
        {
          label: "Điện thoại",
          before: review.before?.contactPhone,
          after: review.after.contactPhone,
        },
        {
          label: "Email",
          before: review.before?.contactEmail,
          after: review.after.contactEmail,
        },
      ]}
    />
  );
}
function PriorityReviewTable({
  review,
  suppliers,
}: {
  review: Extract<WorkbenchReview, { kind: "priorities" }>;
  suppliers: SupplierMasterData[];
}) {
  const label = (supplierId: string, priority: number) =>
    `${priority} · ${suppliers.find((item) => item.supplier_id === supplierId)?.supplier_name ?? "Nhà cung ứng"}`;
  return (
    <Flex gap="md" direction={{ base: "column", md: "row" }}>
      <PriorityList
        title="Trước"
        rows={review.before.map((item) =>
          label(item.supplierId, item.priority),
        )}
      />
      <PriorityList
        title="Sau"
        rows={review.after.map((item) => label(item.supplierId, item.priority))}
      />
    </Flex>
  );
}
function PriorityList({ title, rows }: { title: string; rows: string[] }) {
  return (
    <Box flex="1">
      <Heading as="h3" textStyle="label">
        {title}
      </Heading>
      {rows.length ? (
        rows.map((row) => (
          <Text key={row} mt="xs">
            {row}
          </Text>
        ))
      ) : (
        <Text mt="xs" color="fg.muted">
          Không có ưu tiên
        </Text>
      )}
    </Box>
  );
}
