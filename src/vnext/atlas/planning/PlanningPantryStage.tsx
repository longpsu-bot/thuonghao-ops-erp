import {
  Box,
  Button,
  Checkbox,
  Field,
  Flex,
  Input,
  IconButton,
  NativeSelect,
  Table,
  Text,
} from "@chakra-ui/react";
import { Fragment, useId, useRef, useState } from "react";
import { Trash } from "@phosphor-icons/react";
import { PantryIngredientChooser } from "./PantryIngredientChooser";
import { AtlasQuantityContext } from "../AtlasQuantityContext";
import type { PlanningSourcesController } from "./usePlanningSources";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { pantryIssueCopy } from "./pantryIssueCopy";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";

function PantryFeedback({
  error,
  helper,
}: {
  error?: string;
  helper?: string;
}) {
  return (
    <Box
      data-pantry-feedback=""
      minH="var(--atlas-layout-pantry-feedback, 18px)"
    >
      {error ? (
        <Field.ErrorText>{error}</Field.ErrorText>
      ) : helper ? (
        <Text textStyle="helper" color="fg.muted">
          {helper}
        </Text>
      ) : null}
    </Box>
  );
}

export function PlanningPantryStage({
  c,
  visibleSchoolIds,
}: {
  c: PlanningSourcesController;
  visibleSchoolIds: string[];
}) {
  const [addSchool, setAddSchool] = useState("");
  const quantityContextId = useId();
  const addButton = useRef<HTMLButtonElement>(null);
  const addSchoolInput = useRef<HTMLSelectElement>(null);
  const schoolOrder = new Map(
    c.schools.map((school, index) => [school.school_id, index]),
  );
  const schools = (c.pantryData?.schools ?? [])
    .filter(
      (s) =>
        s.school_status === "ACTIVE" && visibleSchoolIds.includes(s.school_id),
    )
    .sort(compareCanonicalSchools);
  const rows = c.pantryRows
    .map((r, index) => ({ r, index }))
    .filter(
      ({ r }) =>
        r.service_date === c.date && visibleSchoolIds.includes(r.school_id),
    )
    .sort(
      (a, b) =>
        (schoolOrder.get(a.r.school_id) ?? Infinity) -
        (schoolOrder.get(b.r.school_id) ?? Infinity),
    );
  const automaticSchool =
    c.schoolIds.length === 1
      ? schools.find((s) => s.school_id === c.schoolIds[0])
      : undefined;
  const targetSchoolId =
    automaticSchool?.school_id ??
    (schools.some((s) => s.school_id === addSchool) ? addSchool : "");
  return (
    <>
      <Flex p="sm" gap="sm" wrap="wrap" align="center">
        {automaticSchool ? (
          <Box>
            <Text fontWeight="semibold">
              Thêm cho {automaticSchool.school_name}
            </Text>
            <Text textStyle="helper" color="fg.muted">
              {automaticSchool.default_delivery_location.location_name}
            </Text>
          </Box>
        ) : (
          <NativeSelect.Root
            disabled={!c.canEdit || c.noAdditions}
            w="var(--atlas-layout-add-school-width, 220px)"
          >
            <NativeSelect.Field
              ref={addSchoolInput}
              aria-label="Trường cần thêm hàng"
              value={targetSchoolId}
              onChange={(e) => setAddSchool(e.target.value)}
            >
              <option value="">Chọn trường cần thêm hàng</option>
              {schools.map((s) => (
                <option key={s.school_id} value={s.school_id}>
                  {s.school_name}
                </option>
              ))}
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        )}
        <Button
          ref={addButton}
          size="sm"
          disabled={!c.canEdit || c.noAdditions || !targetSchoolId}
          onClick={() => c.addPantryRow(targetSchoolId)}
        >
          + Thêm dòng
        </Button>
        <Checkbox.Root
          checked={c.noAdditions}
          disabled={!c.canEdit || c.schoolIds.length > 0}
          onCheckedChange={(d) => c.requestNoAdditions(d.checked === true)}
        >
          <Checkbox.HiddenInput />
          <Checkbox.Control>
            <Checkbox.Indicator />
          </Checkbox.Control>
          <Checkbox.Label>
            Xác nhận cả tuần không có hàng đặt riêng
          </Checkbox.Label>
        </Checkbox.Root>
        {c.schoolIds.length > 0 && (
          <Text textStyle="helper" color="fg.muted">
            Chọn Tất cả trường để thay đổi xác nhận cho cả tuần.
          </Text>
        )}
      </Flex>
      {c.dirty && rows.length < c.pantryRows.length && (
        <Text role="status" px="sm" textStyle="helper" color="fg.muted">
          {c.pantryRows.length - rows.length} dòng ngoài bộ lọc vẫn được giữ để
          lưu.
        </Text>
      )}
      {c.pantryData?.catalog_issues.blockers.map((i, n) => (
        <Text key={n} role="alert" p="sm" color="status.danger">
          {pantryIssueCopy(i)}
        </Text>
      ))}
      {c.pantryData?.catalog_issues.warnings.map((i, n) => (
        <Text key={n} p="sm" textStyle="helper" color="status.warning">
          {pantryIssueCopy(i)}
        </Text>
      ))}
      {!rows.length && (
        <Text p="md" color="fg.muted">
          {!visibleSchoolIds.length
            ? "Không có trường phù hợp bộ lọc."
            : c.pantryRows.some((row) => row.service_date === c.date)
              ? "Không có hàng đặt riêng khớp bộ lọc trong ngày này."
              : c.noAdditions
                ? "Đã chọn xác nhận không có hàng đặt riêng trong cả tuần."
                : "Chưa có hàng đặt riêng trong ngày này. Chưa xác nhận cả tuần không có hàng đặt riêng."}
        </Text>
      )}
      <AtlasTableViewport
        label="Bảng hàng đặt riêng"
        maxH="var(--atlas-layout-planning-table-height, max(240px, calc(100dvh - 480px)))"
      >
        <Table.Root
          aria-label="Hàng đặt riêng"
          tableLayout="fixed"
          w="full"
          minW={{
            base: "var(--atlas-layout-zero, 0)",
            md: "var(--atlas-pantry-table-width, 1156px)",
          }}
          size="sm"
          stickyHeader
          css={{
            "@media(max-width:47.99rem)": {
              "& colgroup": { display: "none" },
              "& thead": {
                position: "absolute",
                width: "1px",
                height: "1px",
                overflow: "hidden",
                clip: "rect(0, 0, 0, 0)",
                whiteSpace: "nowrap",
              },
              "& tbody": { display: "block" },
              "& tr": {
                display: "grid",
                gridTemplateColumns: "minmax(0, 1fr) auto",
                borderBottom: "1px solid var(--atlas-colors-border-subtle)",
              },
              "& td": { display: "block", minWidth: 0, border: 0 },
              "& td:not(:last-child)": { gridColumn: "1 / -1" },
              "& tr[data-pantry-line] td:first-of-type": { display: "none" },
              "& td[data-pantry-quantity]": { gridColumn: "1 / -1" },
            },
          }}
        >
          <Table.ColumnGroup>
            <Table.Column w="var(--atlas-pantry-school-column, 210px)" />
            <Table.Column w="var(--atlas-pantry-ingredient-column, 210px)" />
            <Table.Column w="var(--atlas-pantry-quantity-column, 130px)" />
            <Table.Column w="var(--atlas-pantry-note-column, 190px)" />
            <Table.Column w="var(--atlas-pantry-reference-column, 130px)" />
            <Table.Column w="var(--atlas-pantry-action-column, 96px)" />
          </Table.ColumnGroup>
          <Table.Header>
            <Table.Row>
              {[
                "Trường / điểm giao",
                "Nguyên liệu / Đơn vị",
                "Số lượng",
                "Ghi chú / Lý do",
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
                      const ingredient = c.pantryData?.ingredients.find(
                        (i) => i.ingredient_id === r.ingredient_id,
                      );
                      const unit = ingredient?.purchase_unit.unit_name;
                      const saved = c.pantryData?.batch?.active_lines.find(
                        (line) =>
                          line.source_row_reference === r.source_row_reference,
                      );
                      const selectedSchool = c.pantryData?.schools.find(
                        (school) => school.school_id === r.school_id,
                      );
                      return (
                        <Table.Row
                          key={r.source_row_reference || index}
                          data-pantry-line=""
                        >
                          <Table.Cell>
                            <Text fontWeight="medium">
                              {selectedSchool?.school_name}
                            </Text>
                            <PantryFeedback
                              helper={
                                selectedSchool?.default_delivery_location
                                  .location_name
                              }
                            />
                            <Text textStyle="helper" color="fg.muted">
                              {r.service_date.split("-").reverse().join("/")}
                            </Text>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root invalid={!!errors.ingredient}>
                              <Field.Label hideFrom="md">
                                Nguyên liệu
                              </Field.Label>
                              <PantryIngredientChooser
                                label={`Nguyên liệu dòng ${index + 1}`}
                                ingredients={c.pantryData?.ingredients ?? []}
                                value={r.ingredient_id}
                                disabled={!c.canEdit}
                                invalid={!!errors.ingredient}
                                onChange={(ingredient_id) =>
                                  c.editPantryRow(index, { ingredient_id })
                                }
                              />
                              <PantryFeedback
                                error={errors.ingredient}
                                helper={unit}
                              />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell data-pantry-quantity="">
                            <AtlasQuantityContext
                              id={`${quantityContextId}-${r.source_row_reference}`}
                              recipient={selectedSchool?.school_name}
                              location={
                                selectedSchool?.default_delivery_location
                                  .location_name
                              }
                              ingredient={
                                ingredient?.ingredient_name ??
                                "Chọn nguyên liệu"
                              }
                              date={r.service_date}
                              unit={ingredient?.purchase_unit.unit_code}
                              source="Hàng đặt riêng"
                            />
                            <Text textStyle="helper" color="fg.muted" mb="xs">
                              {saved
                                ? `Đã lưu${saved.ingredient_id !== r.ingredient_id ? ` ${saved.ingredient_name}` : ""}: ${saved.requested_quantity} ${saved.unit_code}`
                                : "Dòng mới · chưa lưu"}
                            </Text>
                            <Field.Root invalid={!!errors.quantity}>
                              <Field.Label hideFrom="md">
                                Số lượng đang nhập
                              </Field.Label>
                              <Flex gap="xs" align="center">
                                <Input
                                  aria-label={`Số lượng dòng ${index + 1}`}
                                  aria-describedby={`${quantityContextId}-${r.source_row_reference}`}
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
                                <Text textStyle="unitInline">
                                  {ingredient?.purchase_unit.unit_code}
                                </Text>
                              </Flex>
                              <PantryFeedback error={errors.quantity} />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root>
                              <Field.Label hideFrom="md">
                                Ghi chú / Lý do
                              </Field.Label>
                              <Input
                                aria-label={`Ghi chú dòng ${index + 1}`}
                                value={r.note}
                                disabled={!c.canEdit}
                                minW="var(--atlas-layout-note-width, 150px)"
                                onChange={(e) =>
                                  c.editPantryRow(index, {
                                    note: e.target.value,
                                  })
                                }
                              />
                              <PantryFeedback helper="Không bắt buộc." />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <Field.Root>
                              <Field.Label hideFrom="md">
                                Tham chiếu
                              </Field.Label>
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
                              <PantryFeedback />
                            </Field.Root>
                          </Table.Cell>
                          <Table.Cell>
                            <IconButton
                              variant="tertiary"
                              size="sm"
                              aria-label={`Xóa dòng ${index + 1}${ingredient ? ` · ${ingredient.ingredient_name}` : ""}`}
                              title={`Xóa dòng ${index + 1}`}
                              disabled={!c.canEdit}
                              onClick={() => {
                                c.removePantryRow(index);
                                if (
                                  addButton.current &&
                                  !addButton.current.disabled
                                )
                                  addButton.current.focus();
                                else addSchoolInput.current?.focus();
                              }}
                            >
                              <Trash aria-hidden="true" />
                            </IconButton>
                          </Table.Cell>
                        </Table.Row>
                      );
                    })}
                </Fragment>
              ))}
          </Table.Body>
        </Table.Root>
      </AtlasTableViewport>
    </>
  );
}
