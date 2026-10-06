import {
  Box,
  Button,
  Field,
  Flex,
  Heading,
  Input,
  Icon,
  Table,
  Text,
} from "@chakra-ui/react";
import { WarningCircle } from "@phosphor-icons/react";
import { useId, useState } from "react";
import { ingredientLabel, unitLabel } from "../bridges/dishRecipe";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import { parseQuantity } from "./recipeDraftModel";
import type { DishRecipeController } from "./useDishRecipeWorkbench";

export function BaseRecipeEditor({ c }: { c: DishRecipeController }) {
  const [search, setSearch] = useState("");
  const errorPrefix = useId();
  const draft = c.recipeDraft;
  if (!draft) return null;
  const locked =
    c.effective?.is_operationally_locked ||
    c.effective?.editable_state === "LOCKED_CHANGE_ORDER";
  const editable = c.canEdit && !c.review;
  const basisValid =
    /^\d+$/.test(draft.basis) &&
    Number.isSafeInteger(Number(draft.basis)) &&
    Number(draft.basis) > 0;
  const update = (id: string, patch: Partial<(typeof draft.lines)[number]>) =>
    c.setRecipeDraft({
      ...draft,
      lines: draft.lines.map((line) =>
        line.id === id ? { ...line, ...patch } : line,
      ),
    });
  const choices = c.catalog.ingredients
    .filter(
      (i) =>
        i.ingredient_status === "ACTIVE" &&
        !draft.lines.some((l) => l.ingredientId === i.ingredient_id) &&
        search.trim() &&
        foldVietnameseSearch(i.ingredient_name).includes(
          foldVietnameseSearch(search),
        ),
    )
    .slice(0, 12);
  return (
    <Box mt="md">
      <Flex justify="space-between" align="center" gap="sm" wrap="wrap">
        <Heading as="h3" textStyle="section">
          Công thức gốc
        </Heading>
        <Text textStyle="helper" color="fg.muted">
          {c.dirty
            ? "Đang chỉnh sửa · chưa lưu"
            : locked
              ? "Đã được sử dụng · chỉ đọc"
              : c.effective?.base_authoring.business_status === "AVAILABLE"
                ? "Sẵn sàng cho Lập nhu cầu"
                : draft.lines.length
                  ? "Cần xem lại và lưu"
                  : "Chưa có nội dung"}
        </Text>
      </Flex>
      {editable ? (
        <Field.Root mt="sm" invalid={!basisValid}>
          <Field.Label>Số suất áp dụng cho định lượng</Field.Label>
          <Input
            value={draft.basis}
            inputMode="numeric"
            maxW="var(--atlas-layout-basis-width, 160px)"
            onChange={(e) =>
              c.setRecipeDraft({ ...draft, basis: e.target.value })
            }
          />
          <Field.ErrorText>Nhập số suất nguyên dương.</Field.ErrorText>
        </Field.Root>
      ) : (
        <Text mt="sm">Số suất áp dụng cho định lượng: {draft.basis}</Text>
      )}
      <Box
        role="region"
        aria-label="Bảng công thức gốc"
        tabIndex={0}
        overflow="auto"
        mt="sm"
        borderYWidth="var(--atlas-layout-edge, 1px)"
        borderColor="border.subtle"
      >
        <Table.Root
          aria-label="Công thức gốc"
          minW="var(--atlas-layout-recipe-table-min, 650px)"
          w="full"
          tableLayout="fixed"
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-recipe-ingredient-width, 160px)" />
            <Table.Column w="var(--atlas-recipe-quantity-width, 110px)" />
            <Table.Column w="var(--atlas-recipe-unit-width, 140px)" />
            <Table.Column />
            {editable && (
              <Table.Column w="var(--atlas-recipe-action-width, 80px)" />
            )}
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row>
              {[
                "Nguyên liệu",
                "Định lượng",
                "Đơn vị",
                "Ghi chú",
                ...(editable ? ["Thao tác"] : []),
              ].map((label) => (
                <Table.ColumnHeader
                  key={label}
                  textAlign={label === "Định lượng" ? "right" : "left"}
                >
                  {label}
                </Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {draft.lines.map((line) => {
              const name = ingredientLabel(
                line.ingredientId,
                c.catalog.ingredients,
              );
              const ingredient = c.catalog.ingredients.find(
                (i) => i.ingredient_id === line.ingredientId,
              );
              const purchaseUnit = c.catalog.units.find(
                (u) =>
                  u.unit_id === ingredient?.purchase_unit_id &&
                  u.unit_status === "ACTIVE",
              );
              return (
                <Table.Row key={line.id}>
                  <Table.Cell overflowWrap="anywhere">{name}</Table.Cell>
                  <Table.Cell textAlign="right">
                    {editable ? (
                      <Input
                        aria-label={`Định lượng ${name}`}
                        aria-invalid={parseQuantity(line.quantity) === null}
                        aria-describedby={
                          parseQuantity(line.quantity) === null
                            ? `${errorPrefix}-${line.id}`
                            : undefined
                        }
                        value={line.quantity}
                        inputMode="decimal"
                        w="var(--atlas-layout-quantity-width, 86px)"
                        textAlign="right"
                        onChange={(e) =>
                          update(line.id, { quantity: e.target.value })
                        }
                      />
                    ) : (
                      line.quantity
                    )}
                    {editable && parseQuantity(line.quantity) === null && (
                      <Text
                        id={`${errorPrefix}-${line.id}`}
                        textStyle="helper"
                        color="status.danger"
                      >
                        Nhập định lượng hợp lệ.
                      </Text>
                    )}
                  </Table.Cell>
                  <Table.Cell>
                    {unitLabel(line.unitId, c.catalog.units)}
                    {editable && !purchaseUnit && (
                      <Text
                        role="alert"
                        textStyle="helper"
                        color="status.danger"
                        layerStyle="feedbackDanger"
                        p="xs"
                      >
                        <Icon asChild mr="xs">
                          <WarningCircle aria-hidden="true" />
                        </Icon>
                        Nguyên liệu chưa có đơn vị mua đang dùng. Hãy cập nhật
                        dữ liệu nguyên liệu trước khi lưu công thức.
                      </Text>
                    )}
                    {editable &&
                      purchaseUnit &&
                      line.unitId !== purchaseUnit.unit_id && (
                        <Text
                          role="alert"
                          textStyle="helper"
                          color="status.danger"
                          layerStyle="feedbackDanger"
                          p="xs"
                        >
                          <Icon asChild mr="xs">
                            <WarningCircle aria-hidden="true" />
                          </Icon>
                          Đơn vị đã lưu khác đơn vị mua hiện tại. Cần kiểm tra
                          dữ liệu công thức trước khi lưu.
                        </Text>
                      )}
                  </Table.Cell>
                  <Table.Cell>
                    {editable ? (
                      <Input
                        aria-label={`Ghi chú ${name}`}
                        value={line.note}
                        minW="var(--atlas-layout-note-min, 100px)"
                        onChange={(e) =>
                          update(line.id, { note: e.target.value })
                        }
                      />
                    ) : (
                      line.note || "—"
                    )}
                  </Table.Cell>
                  {editable && (
                    <Table.Cell>
                      <Button
                        size="sm"
                        variant="tertiary"
                        aria-label={`Bỏ ${name}`}
                        onClick={() =>
                          c.setRecipeDraft({
                            ...draft,
                            lines: draft.lines.filter((l) => l.id !== line.id),
                          })
                        }
                      >
                        Bỏ
                      </Button>
                    </Table.Cell>
                  )}
                </Table.Row>
              );
            })}
          </Table.Body>
        </Table.Root>
      </Box>
      {editable && (
        <>
          <Field.Root mt="sm">
            <Field.Label>Tìm nguyên liệu để thêm</Field.Label>
            <Input
              value={search}
              placeholder="Tìm nguyên liệu để thêm…"
              onChange={(e) => setSearch(e.target.value)}
            />
          </Field.Root>
          {search && (
            <Flex
              mt="xs"
              gap="xs"
              wrap="wrap"
              aria-label="Kết quả tìm nguyên liệu"
            >
              {choices.map((i) => (
                <Button
                  key={i.ingredient_id}
                  size="sm"
                  aria-label={`Thêm ${i.ingredient_name}`}
                  onClick={() => {
                    c.setRecipeDraft({
                      ...draft,
                      lines: [
                        ...draft.lines,
                        {
                          id: crypto.randomUUID(),
                          ingredientId: i.ingredient_id,
                          quantity: "1",
                          unitId: i.purchase_unit_id ?? "",
                          note: "",
                        },
                      ],
                    });
                    setSearch("");
                  }}
                >
                  {i.ingredient_name}
                </Button>
              ))}
              {!choices.length && (
                <Text textStyle="helper">
                  Không có nguyên liệu đang dùng phù hợp.
                </Text>
              )}
            </Flex>
          )}
          {!c.validDraft && (
            <Text mt="xs" color="status.danger" textStyle="helper">
              Cần 1–500 dòng, nguyên liệu không trùng, số lượng dương và đơn vị
              đang dùng.
            </Text>
          )}
        </>
      )}
    </Box>
  );
}
