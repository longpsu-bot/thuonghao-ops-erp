import { Box, Button, Flex, Grid, Heading, Text } from "@chakra-ui/react";
import { useState } from "react";
import type { ChangeOrderController } from "./useChangeOrderWorkbench";
import {
  actionLabels,
  periodLabel,
  scopeLabels,
  targetIngredientId,
  temporalLabels,
} from "./changeOrderModel";
import { ChangeComposition } from "./ChangeOrderDialogs";
import { ChangeSelect } from "./ChangeOrderEditor";
export function ChangeOrderDetail({ c }: { c: ChangeOrderController }) {
  const row = c.selected!,
    r = row.content_revision;
  const [dishId, setDishId] = useState(row.dish_id ?? ""),
    [schoolId, setSchoolId] = useState(row.school_id ?? "");
  const type =
    row.school_type_id ??
    c.data.schools.find((s) => s.school_id === schoolId)?.school_type_id ??
    "";
  const target = c.data.recipe_lines.find(
    (l) => l.recipe_line_id === row.target_recipe_line_id,
  );
  const ingredient = c.data.ingredients.find(
    (i) => i.ingredient_id === targetIngredientId(row, c.data),
  );
  const priorAdd = c.data.operator_rows.find(
    (source) =>
      source.action_kind === "ADD" &&
      source.adjustment_line_id === row.adjustment_line_id,
  );
  const unit = c.data.units.find(
    (u) =>
      u.unit_id ===
      (r.unit_id ?? target?.unit_id ?? priorAdd?.content_revision.unit_id),
  )?.unit_name;
  const facts = [
    ["Món", c.data.dishes.find((d) => d.dish_id === row.dish_id)?.dish_name],
    [
      "Trường",
      c.data.schools.find((s) => s.school_id === row.school_id)?.school_name,
    ],
    [
      "Loại công thức",
      c.data.school_types.find((s) => s.school_type_id === type)
        ?.school_type_name,
    ],
    [
      row.action_kind === "ADD" ? "Nguyên liệu thêm" : "Thành phần hiện tại",
      ingredient?.ingredient_name ?? "Thành phần của lệnh đã chọn",
    ],
    [
      "Nguyên liệu thay thế",
      c.data.ingredients.find(
        (i) => i.ingredient_id === r.substitute_ingredient_id,
      )?.ingredient_name,
    ],
    ["Đơn vị", unit],
  ];
  const events = {
    CREATED: "Tạo lệnh",
    CORRECTED: "Điều chỉnh lệnh",
    CANCELLED: "Hủy lệnh",
  };
  return (
    <Box maxW="4xl">
      <Flex align="baseline" justify="space-between" gap="sm" wrap="wrap">
        <Heading as="h3" textStyle="section">
          {actionLabels[row.action_kind]}
        </Heading>
        <Text textStyle="label" color="fg.secondary">
          {temporalLabels[row.temporal_state]}
        </Text>
      </Flex>
      <Text textStyle="body" color="fg.muted" mt="xs">
        {scopeLabels[row.scope_kind]}
      </Text>
      <Grid
        as="dl"
        templateColumns={{
          base: "minmax(0, 8rem) minmax(0, 1fr)",
          md: "minmax(0, 10rem) minmax(0, 1fr)",
        }}
        columnGap="md"
        rowGap="sm"
        mt="md"
        alignItems="baseline"
      >
        {facts
          .filter(([, value]) => value)
          .map(([label, value]) => (
            <Box key={label} display="contents">
              <Text as="dt" textStyle="label" color="fg.muted">
                {label}
              </Text>
              <Text
                as="dd"
                textStyle="body"
                fontWeight="medium"
                overflowWrap="anywhere"
              >
                {value}
              </Text>
            </Box>
          ))}
        {r.quantity_per_basis !== null && (
          <>
            <Text as="dt" textStyle="label" color="fg.muted">
              Định lượng
            </Text>
            <Text as="dd" textStyle="quantityInline">
              {r.quantity_per_basis.toLocaleString("vi-VN", {
                maximumFractionDigits: 6,
              })}{" "}
              {unit ?? ""}
            </Text>
          </>
        )}
      </Grid>
      <Box mt="md">
        <Text textStyle="label" color="fg.muted">
          Hiệu lực
        </Text>
        <Text textStyle="body" mt="xs">
          {periodLabel(r.effective_from, r.effective_to)}
        </Text>
      </Box>
      <Box mt="md">
        <Text textStyle="label" color="fg.muted">
          Lý do điều chỉnh
        </Text>
        <Text
          textStyle="body"
          mt="xs"
          maxW="prose"
          whiteSpace="pre-wrap"
          overflowWrap="anywhere"
        >
          {r.reason_note}
        </Text>
      </Box>
      <Flex mt="md" gap="md" wrap="wrap">
        {row.can_correct && (
          <Button
            variant="businessPrimary"
            onClick={() => c.openCorrection(row)}
            disabled={!c.canAct}
          >
            Sửa lệnh
          </Button>
        )}
        {row.can_cancel && (
          <Button
            variant="tertiary"
            color="status.danger"
            _hover={{
              bg: "bg.danger",
              color: "status.danger",
              borderColor: "border.danger",
            }}
            _active={{ bg: "bg.danger" }}
            onClick={() => c.openCancel(row)}
            disabled={!c.canAct}
          >
            Hủy lệnh
          </Button>
        )}
      </Flex>
      <Heading as="h3" textStyle="section" mt="lg" mb="sm">
        Lịch sử lệnh
      </Heading>
      <Box as="ol" pl="md">
        {row.history.map((h) => (
          <Box as="li" key={h.revision_id} mb="md">
            <Text fontWeight="medium">{events[h.business_event_kind]}</Text>
            <Text textStyle="helper" color="fg.muted">
              {periodLabel(h.effective_from, h.effective_to)}
            </Text>
            <Text
              textStyle="body"
              maxW="prose"
              whiteSpace="pre-wrap"
              overflowWrap="anywhere"
            >
              {h.reason_note}
            </Text>
            <Text textStyle="helper" color="fg.muted">
              {h.issuance_kind === "LEGACY_UNATTRIBUTED"
                ? "Dữ liệu cũ · không lưu người phát hành"
                : `${h.issued_by_actor_name} · ${new Intl.DateTimeFormat("vi-VN", { dateStyle: "short", timeStyle: "short", timeZone: "Asia/Ho_Chi_Minh" }).format(new Date(h.issued_at!))}`}
            </Text>
          </Box>
        ))}
      </Box>
      <Box as="details" mt="md">
        <Text
          as="summary"
          cursor="var(--atlas-pointer, pointer)"
          fontWeight="medium"
        >
          Xem công thức hiệu lực
        </Text>
        <Box mt="sm">
          {!row.dish_id && (
            <ChangeSelect
              label="Món kiểm tra"
              value={dishId}
              onChange={(value) => {
                c.clearEffective();
                setDishId(value);
              }}
            >
              <option value="">Chọn món</option>
              {c.data.dishes.map((d) => (
                <option key={d.dish_id} value={d.dish_id}>
                  {d.dish_name}
                </option>
              ))}
            </ChangeSelect>
          )}
          {!row.school_id && row.scope_kind !== "SYSTEM_DISH" && (
            <ChangeSelect
              label="Trường kiểm tra"
              value={schoolId}
              onChange={(value) => {
                c.clearEffective();
                setSchoolId(value);
              }}
            >
              <option value="">Chọn trường</option>
              {c.data.schools.map((s) => (
                <option key={s.school_id} value={s.school_id}>
                  {s.school_name}
                </option>
              ))}
            </ChangeSelect>
          )}
          <Button
            mt="sm"
            variant="secondary"
            loading={c.effectiveLoading}
            disabled={!dishId || !type}
            onClick={() => void c.inspectEffective(dishId, schoolId, type)}
          >
            Tải công thức hiệu lực
          </Button>
          {c.effectiveMessage && <Text role="alert">{c.effectiveMessage}</Text>}
          {c.effective && (
            <ChangeComposition
              title="Công thức hiệu lực"
              value={c.effective}
              data={c.data}
            />
          )}
        </Box>
      </Box>
    </Box>
  );
}
