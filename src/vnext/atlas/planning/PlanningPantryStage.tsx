import {
  Box,
  Button,
  Checkbox,
  Field,
  Flex,
  Input,
  NativeSelect,
  Table,
  Text,
} from "@chakra-ui/react";
import { Fragment, useState } from "react";
import type { PlanningSourcesController } from "./usePlanningSources";
export function PlanningPantryStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [addSchool, setAddSchool] = useState("");
  const schools =
    c.pantryData?.schools.filter(
      (s) =>
        s.school_status === "ACTIVE" && visibleSchoolIds.includes(s.school_id),
    ) ?? [];
  const rows = c.pantryRows
    .map((r, index) => ({ r, index }))
    .filter(
      ({ r }) =>
        r.service_date === c.date && visibleSchoolIds.includes(r.school_id),
    );
  return (
    <>
      <Flex p="sm" gap="sm" wrap="wrap" align="center">
        <NativeSelect.Root
          disabled={!c.canEdit || c.noAdditions}
          w="var(--atlas-layout-add-school-width, 220px)"
        >
          <NativeSelect.Field
            aria-label="Trường thêm dòng"
            value={addSchool}
            onChange={(e) => setAddSchool(e.target.value)}
          >
            <option value="">Chọn trường thêm dòng</option>
            {schools.map((s) => (
              <option key={s.school_id} value={s.school_id}>
                {s.school_name}
              </option>
            ))}
          </NativeSelect.Field>
          <NativeSelect.Indicator />
        </NativeSelect.Root>
        <Button
          size="sm"
          disabled={
            !c.canEdit ||
            c.noAdditions ||
            !schools.some((s) => s.school_id === addSchool)
          }
          onClick={() => c.addPantryRow(addSchool)}
        >
          + Thêm dòng
        </Button>
        <Checkbox.Root
          checked={c.noAdditions}
          disabled={!c.canEdit || c.schoolIds.length > 0}
          onCheckedChange={(d) => c.requestNoAdditions(d.checked === true)}
        >
          <Checkbox.HiddenInput />
          <Checkbox.Control
            borderColor="border.default"
            _checked={{ bg: "action.primary.default", color: "fg.inverse" }}
          >
            <Checkbox.Indicator />
          </Checkbox.Control>
          <Checkbox.Label textStyle="helper">
            Xác nhận toàn tuần không có bổ sung
          </Checkbox.Label>
        </Checkbox.Root>
        {c.schoolIds.length > 0 && (
          <Text textStyle="helper" color="fg.muted">
            Chuyển về Tất cả trường để thay đổi xác nhận toàn tuần.
          </Text>
        )}
      </Flex>
      {c.pantryData?.catalog_issues.blockers.map((i, n) => (
        <Text key={n} role="alert" p="sm" color="status.danger">
          {i.message}
        </Text>
      ))}
      {c.pantryData?.catalog_issues.warnings.map((i, n) => (
        <Text key={n} p="sm" textStyle="helper" color="status.warning">
          {i.message}
        </Text>
      ))}
      {!rows.length && (
        <Text p="md" color="fg.muted">
          {c.noAdditions
            ? "Đã chọn xác nhận toàn tuần không có bổ sung."
            : "Chưa có dòng bổ sung trong ngày. Chưa xác nhận toàn tuần không có bổ sung."}
        </Text>
      )}
      <Box
        overflow="auto"
        maxH="var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
      >
        <Table.Root aria-label="Nguyên liệu bổ sung" size="sm" stickyHeader>
          <Table.Header>
            <Table.Row>
              {[
                "Nguyên liệu / Đơn vị",
                "Mục đích",
                "Số lượng",
                "Ghi chú",
                "Tham chiếu",
                "",
              ].map((name, i) => (
                <Table.ColumnHeader key={i}>{name}</Table.ColumnHeader>
              ))}
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {schools
              .filter((s) => rows.some(({ r }) => r.school_id === s.school_id))
              .map((s) => (
                <Fragment key={s.school_id}>
                  <Table.Row bg="bg.subtle">
                    <Table.Cell colSpan={6}>
                      <Flex align="center" gap="sm" wrap="wrap">
                        <Box>
                          <Text fontWeight="semibold">{s.school_name}</Text>
                          <Text textStyle="helper" color="fg.muted">
                            {s.default_delivery_location.location_name}
                          </Text>
                        </Box>
                        <NativeSelect.Root
                          disabled={!c.canEdit}
                          w="var(--atlas-layout-mode-width, 230px)"
                        >
                          <NativeSelect.Field
                            aria-label={`Cách kết hợp ${s.school_name}`}
                            value={
                              c.modes.find(
                                (m) =>
                                  m.school_id === s.school_id &&
                                  m.service_date === c.date,
                              )?.direct_need_mode ?? "ADDITIVE"
                            }
                            onChange={(e) =>
                              c.setMode(
                                s.school_id,
                                e.target.value === "COMPLETE"
                                  ? "COMPLETE"
                                  : "ADDITIVE",
                              )
                            }
                          >
                            <option value="ADDITIVE">Cộng với thực đơn</option>
                            <option value="COMPLETE">Danh sách đầy đủ</option>
                          </NativeSelect.Field>
                          <NativeSelect.Indicator />
                        </NativeSelect.Root>
                      </Flex>
                    </Table.Cell>
                  </Table.Row>
                  {rows
                    .filter(({ r }) => r.school_id === s.school_id)
                    .map(({ r, index }) => {
                      const errors = c.pantryRowErrors[index];
                      const purpose = c.pantryData?.purposes.find(
                        (p) =>
                          p.pantry_need_purpose_id === r.pantry_need_purpose_id,
                      );
                      const unit = c.pantryData?.ingredients.find(
                        (i) => i.ingredient_id === r.ingredient_id,
                      )?.purchase_unit.unit_name;
                      return (
                        <Table.Row key={r.source_row_reference || index}>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.ingredient}>
                              <NativeSelect.Root
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-ingredient-width, 180px)"
                              >
                                <NativeSelect.Field
                                  aria-label={`Nguyên liệu dòng ${index + 1}`}
                                  value={r.ingredient_id}
                                  onChange={(e) =>
                                    c.editPantryRow(index, {
                                      ingredient_id: e.target.value,
                                    })
                                  }
                                >
                                  <option value="">Chọn nguyên liệu</option>
                                  {c.pantryData?.ingredients
                                    .filter(
                                      (i) => i.ingredient_status === "ACTIVE",
                                    )
                                    .map((i) => (
                                      <option
                                        key={i.ingredient_id}
                                        value={i.ingredient_id}
                                      >
                                        {i.ingredient_name}
                                      </option>
                                    ))}
                                </NativeSelect.Field>
                                <NativeSelect.Indicator />
                              </NativeSelect.Root>
                              {unit && <Text textStyle="helper">{unit}</Text>}
                              <Field.ErrorText>
                                {errors.ingredient}
                              </Field.ErrorText>
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.purpose}>
                              <NativeSelect.Root
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-purpose-width, 170px)"
                              >
                                <NativeSelect.Field
                                  aria-label={`Mục đích dòng ${index + 1}`}
                                  value={r.pantry_need_purpose_id}
                                  onChange={(e) =>
                                    c.editPantryRow(index, {
                                      pantry_need_purpose_id: e.target.value,
                                    })
                                  }
                                >
                                  <option value="">Chọn mục đích</option>
                                  {c.pantryData?.purposes
                                    .filter(
                                      (p) => p.purpose_status === "ACTIVE",
                                    )
                                    .map((p) => (
                                      <option
                                        key={p.pantry_need_purpose_id}
                                        value={p.pantry_need_purpose_id}
                                      >
                                        {p.purpose_name_vi}
                                      </option>
                                    ))}
                                </NativeSelect.Field>
                                <NativeSelect.Indicator />
                              </NativeSelect.Root>
                              <Field.ErrorText>
                                {errors.purpose}
                              </Field.ErrorText>
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.quantity}>
                              <Input
                                aria-label={`Số lượng dòng ${index + 1}`}
                                inputMode="decimal"
                                value={r.requested_quantity}
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-quantity-width, 90px)"
                                onChange={(e) =>
                                  c.editPantryRow(index, {
                                    requested_quantity: e.target.value,
                                  })
                                }
                              />
                              <Field.ErrorText>
                                {errors.quantity}
                              </Field.ErrorText>
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.note}>
                              <Input
                                aria-label={`Ghi chú dòng ${index + 1}`}
                                value={r.note}
                                required={purpose?.note_rule === "REQUIRED"}
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-note-width, 150px)"
                                onChange={(e) =>
                                  c.editPantryRow(index, {
                                    note: e.target.value,
                                  })
                                }
                              />
                              <Field.ErrorText>{errors.note}</Field.ErrorText>
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Input
                              aria-label={`Tham chiếu dòng ${index + 1}`}
                              value={r.source_request_reference}
                              disabled={!c.canEdit}
                              minW="var(--atlas-layout-reference-width, 110px)"
                              onChange={(e) =>
                                c.editPantryRow(index, {
                                  source_request_reference: e.target.value,
                                })
                              }
                            />
                          </Table.Cell>
                          <Table.Cell>
                            <Button
                              variant="utility"
                              size="sm"
                              aria-label={`Bỏ dòng ${index + 1}`}
                              disabled={!c.canEdit}
                              onClick={() => c.removePantryRow(index)}
                            >
                              Bỏ
                            </Button>
                          </Table.Cell>
                        </Table.Row>
                      );
                    })}
                </Fragment>
              ))}
          </Table.Body>
        </Table.Root>
      </Box>
    </>
  );
}
