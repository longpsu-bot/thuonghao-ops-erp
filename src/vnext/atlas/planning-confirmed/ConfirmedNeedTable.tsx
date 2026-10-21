import { Box, Input, NativeSelect, Table, Text } from "@chakra-ui/react";
import { useId, useState } from "react";
import type { CSSProperties } from "react";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import { AtlasTableViewport } from "../AtlasTableViewport";
import { AtlasQuantityContext } from "../AtlasQuantityContext";
import { compareCanonicalSchools } from "../canonicalSchoolOrder";
import {
  atlasDefaultSort,
  compareAtlasBigInt,
  compareAtlasText,
  nextAtlasSort,
  sortAtlasRows,
  type AtlasSortState,
} from "../atlasTableSort";
import {
  confirmedNeedConfirmationStateLabel,
  confirmedNeedInputDisplay,
  confirmedNeedReasonLabels,
  exactDecimalEqual,
  exactQuantityDisplay,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedQuantity,
  subtractExactDecimals,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
} from "../bridges/confirmedNeed";
import {
  confirmedNeedUnitLabel,
  draftChanged,
  historicalQuantity,
} from "./confirmedNeedDraft";
import { parseExactQuantity } from "../procurement/procurementExactQuantity";
export function ConfirmedNeedTable({
  lines,
  drafts,
  errors,
  editable,
  compactEditing = false,
  correctionReason,
  onEdit,
}: {
  lines: ConfirmedNeedLine[];
  drafts: Record<string, ConfirmedNeedDraftLine>;
  errors: Record<string, string>;
  editable: boolean;
  compactEditing?: boolean;
  correctionReason?: string;
  onEdit: (id: string, change: Partial<ConfirmedNeedDraftLine>) => void;
}) {
  type SortKey = "school" | "ingredient" | "proposal";
  const id = useId();
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const compareSchool = (left: ConfirmedNeedLine, right: ConfirmedNeedLine) =>
    compareCanonicalSchools(
      { school_id: left.school.id, school_name: left.school.name },
      { school_id: right.school.id, school_name: right.school.name },
    ) ||
    compareAtlasText(left.delivery_location.name, right.delivery_location.name);
  const comparators = {
    school: compareSchool,
    ingredient: (left, right) =>
      compareAtlasText(left.ingredient.name, right.ingredient.name),
    proposal: (left, right) =>
      compareAtlasBigInt(
        parseExactQuantity(left.proposed_confirmed_quantity),
        parseExactQuantity(right.proposed_confirmed_quantity),
      ),
  } satisfies Record<
    SortKey,
    (left: ConfirmedNeedLine, right: ConfirmedNeedLine) => number
  >;
  const sortedLines =
    sort.direction === "default" || sort.key === null
      ? [...lines].sort(
          (left, right) =>
            compareSchool(left, right) ||
            compareAtlasText(left.ingredient.name, right.ingredient.name) ||
            left.service_date.localeCompare(right.service_date),
        )
      : sortAtlasRows(lines, sort, comparators);
  const onSort = (key: SortKey) =>
    setSort((current) => nextAtlasSort(current, key));
  return (
    <AtlasTableViewport
      label="Bảng xác nhận nhu cầu"
      onFocusCapture={(event) => {
        const control = event.target;
        if (
          !(control instanceof HTMLElement) ||
          !control.matches("input, select")
        )
          return;
        const viewport = event.currentTarget;
        const visible = viewport.getBoundingClientRect();
        const bounds = control.getBoundingClientRect();
        const stickyIdentity = control
          .closest("[data-confirmed-need-line]")
          ?.querySelector<HTMLElement>('[data-field="identity"]');
        const usableLeft = control.closest('[data-field="identity"]')
          ? visible.left
          : Math.max(
              visible.left,
              stickyIdentity?.getBoundingClientRect().right ?? visible.left,
            );
        // Native focus can leave a partially visible field clipped. Reveal only
        // its nearest horizontal edge within this table, including space covered
        // by the frozen recipient cell, without moving the page.
        if (bounds.left < usableLeft)
          viewport.scrollLeft += bounds.left - usableLeft;
        else if (bounds.right > visible.right)
          viewport.scrollLeft += bounds.right - visible.right;
      }}
      style={
        {
          "--atlas-confirmed-need-table-mobile-max-height": compactEditing
            ? "max(280px, 40dvh)"
            : "var(--atlas-layout-table-mobile-height, 55dvh)",
        } as CSSProperties
      }
      maxH={{
        base: "var(--atlas-confirmed-need-table-mobile-max-height)",
        xl: "var(--atlas-layout-table-height, calc(100dvh - 425px))",
      }}
    >
      <Table.Root
        aria-label="Nhu cầu xác nhận"
        size="sm"
        stickyHeader
        style={
          {
            "--atlas-confirmed-need-header-height": "38px",
            "--atlas-confirmed-need-row-min-height": "46px",
          } as CSSProperties
        }
        minW="var(--atlas-layout-confirmed-need-table-min, 1120px)"
        w="full"
        tableLayout="fixed"
        css={{
          "@media(max-width:47.99rem)": {
            "& col:nth-of-type(4)": { width: "calc(100vw - 48px)" },
            "& td[data-field=identity], & th:first-of-type": {
              position: "static",
            },
          },
        }}
      >
        <Table.ColumnGroup>
          <Table.Column w="var(--atlas-confirmed-school-width, 220px)" />
          <Table.Column w="var(--atlas-confirmed-ingredient-width, 180px)" />
          <Table.Column w="var(--atlas-confirmed-proposal-width, 140px)" />
          <Table.Column w="var(--atlas-confirmed-quantity-width, 170px)" />
          <Table.Column w="var(--atlas-confirmed-delta-width, 110px)" />
          <Table.Column w="var(--atlas-confirmed-reason-width, 300px)" />
        </Table.ColumnGroup>
        <Table.Header>
          <Table.Row zIndex="var(--atlas-layout-sticky-header-z, 3)">
            <AtlasSortableColumnHeader
              label="Trường / nơi nhận"
              columnKey="school"
              sort={sort}
              onSort={onSort}
              position="sticky"
              left="var(--atlas-layout-zero, 0)"
              zIndex="var(--atlas-layout-sticky-identity-header-z, 5)"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            />
            <AtlasSortableColumnHeader
              label="Nguyên liệu"
              columnKey="ingredient"
              sort={sort}
              onSort={onSort}
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            />
            <AtlasSortableColumnHeader
              label="Đề xuất vận hành"
              columnKey="proposal"
              sort={sort}
              onSort={onSort}
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            />
            <Table.ColumnHeader
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            >
              Số lượng xác nhận
            </Table.ColumnHeader>
            <Table.ColumnHeader
              textAlign="end"
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            >
              Thay đổi
            </Table.ColumnHeader>
            <Table.ColumnHeader
              h="var(--atlas-confirmed-need-header-height)"
              py="var(--atlas-layout-zero, 0)"
            >
              Lý do / ghi chú
            </Table.ColumnHeader>
          </Table.Row>
        </Table.Header>
        <Table.Body>
          {sortedLines.map((line, index) => {
            const draft =
              drafts[line.confirmed_need_line_id] ??
              initialConfirmedNeedDraft(line);
            const changed = draftChanged(line, draft);
            const historical = historicalQuantity(line);
            const error = errors[line.confirmed_need_line_id];
            const description = `${id}-error-${index}`;
            const normalizedQuantity = normalizeConfirmedNeedQuantity(
              draft.exact_quantity,
            );
            const adjusted = Boolean(
              normalizedQuantity &&
              !exactDecimalEqual(
                normalizedQuantity,
                line.proposed_confirmed_quantity,
              ),
            );
            const delta =
              adjusted && normalizedQuantity
                ? subtractExactDecimals(
                    normalizedQuantity,
                    line.proposed_confirmed_quantity,
                  )
                : null;
            const attention = ["NEW", "CHANGED", "UNREVIEWED"].includes(
              line.confirmation_state,
            );
            const duplicateRecipient =
              line.school.name.trim() === line.delivery_location.name.trim();
            const showReasonChrome = Boolean(
              adjusted ||
              draft.reason_note ||
              draft.reason_code !== "PROPOSAL_ACCEPTED" ||
              (line.current_decision_id && changed),
            );
            return (
              <Table.Row
                key={line.confirmed_need_line_id}
                data-confirmed-need-line
                data-confirmed-need-line-id={line.confirmed_need_line_id}
                minH="var(--atlas-confirmed-need-row-min-height)"
              >
                <Table.Cell
                  data-field="identity"
                  minW="var(--atlas-layout-identity-width, 230px)"
                  position="sticky"
                  left="var(--atlas-layout-zero, 0)"
                  style={{
                    zIndex: "var(--atlas-layout-sticky-identity-z, 2)",
                    background: "var(--atlas-colors-bg-workbench)",
                  }}
                >
                  <Text data-role="recipient" fontWeight="semibold">
                    {line.school.name}
                  </Text>
                  <Text textStyle="helper" color="fg.muted">
                    {line.service_date.split("-").reverse().join("/")}
                  </Text>
                  {!duplicateRecipient && (
                    <Text
                      data-row-secondary=""
                      textStyle="helper"
                      color="fg.muted"
                    >
                      {line.delivery_location.name}
                    </Text>
                  )}
                  {attention && (
                    <Text textStyle="helper" color="status.warning">
                      ⚠{" "}
                      {confirmedNeedConfirmationStateLabel(
                        line.confirmation_state,
                      )}
                    </Text>
                  )}
                </Table.Cell>
                <Table.Cell data-field="ingredient">
                  <Text data-role="ingredient-name" fontWeight="medium">
                    {line.ingredient.name}
                  </Text>
                </Table.Cell>
                <Table.Cell
                  data-field="operational-proposal"
                  textAlign="end"
                  whiteSpace="nowrap"
                >
                  <Text textStyle="quantityInline">
                    {exactQuantityDisplay(line.proposed_confirmed_quantity)}{" "}
                    <Box
                      as="span"
                      textStyle="unitInline"
                      color="fg.muted"
                      ml="xs"
                    >
                      {confirmedNeedUnitLabel(line.controlled_unit)}
                    </Box>
                  </Text>
                </Table.Cell>
                <Table.Cell
                  data-field="confirmation"
                  data-adjustment-state={
                    error ? "invalid" : adjusted ? "valid" : "unchanged"
                  }
                  minW="var(--atlas-layout-quantity-width, 145px)"
                  style={{
                    background: error
                      ? "var(--atlas-colors-bg-danger)"
                      : adjusted
                        ? "var(--atlas-colors-bg-selected)"
                        : undefined,
                  }}
                >
                  <AtlasQuantityContext
                    id={`${id}-quantity-${line.confirmed_need_line_id}`}
                    recipient={line.school.name}
                    location={
                      duplicateRecipient
                        ? undefined
                        : line.delivery_location.name
                    }
                    ingredient={line.ingredient.name}
                    unit={confirmedNeedUnitLabel(line.controlled_unit)}
                    date={line.service_date}
                    source="Xác nhận nhu cầu"
                  />
                  <Text hideFrom="md" textStyle="helper" color="fg.muted">
                    Đề xuất:{" "}
                    {exactQuantityDisplay(line.proposed_confirmed_quantity)}{" "}
                    {confirmedNeedUnitLabel(line.controlled_unit)}
                  </Text>
                  <Text textStyle="helper" color="fg.muted" mb="xs">
                    {line.confirmed_quantity_after === null
                      ? "Chưa lưu"
                      : `Đã lưu: ${exactQuantityDisplay(line.confirmed_quantity_after)} ${confirmedNeedUnitLabel(line.controlled_unit)}`}
                  </Text>
                  <Box
                    display="grid"
                    gridTemplateColumns="minmax(0, 1fr) auto"
                    gap="xs"
                    alignItems="center"
                  >
                    <Input
                      aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                      inputMode="decimal"
                      textAlign="end"
                      value={
                        draft.quantity_entered
                          ? draft.exact_quantity
                          : confirmedNeedInputDisplay(draft.exact_quantity)
                      }
                      readOnly={historical}
                      disabled={!editable}
                      aria-invalid={Boolean(error)}
                      borderColor={
                        error
                          ? "status.danger"
                          : adjusted
                            ? "border.interactive"
                            : undefined
                      }
                      fontWeight={adjusted ? "semibold" : "medium"}
                      aria-describedby={`${id}-quantity-${line.confirmed_need_line_id}${error || historical ? ` ${description}` : ""}`}
                      onChange={(e) =>
                        onEdit(line.confirmed_need_line_id, {
                          exact_quantity: e.target.value,
                          quantity_entered: true,
                        })
                      }
                    />
                    <Text textStyle="unitInline" color="fg.muted">
                      {confirmedNeedUnitLabel(line.controlled_unit)}
                    </Text>
                  </Box>
                  {historical && (
                    <Text id={description} textStyle="helper" color="fg.muted">
                      Giữ nguyên độ chính xác gốc · chỉ đọc.
                    </Text>
                  )}
                </Table.Cell>
                <Table.Cell
                  data-field="delta"
                  textAlign="end"
                  whiteSpace="nowrap"
                >
                  {delta ? (
                    <Text textStyle="quantityInline" color="fg.primary">
                      {exactQuantityDisplay(delta)}{" "}
                      <Box
                        as="span"
                        textStyle="unitInline"
                        color="fg.primary"
                        ml="xs"
                      >
                        {confirmedNeedUnitLabel(line.controlled_unit)}
                      </Box>
                    </Text>
                  ) : (
                    "—"
                  )}
                </Table.Cell>
                <Table.Cell
                  data-field="reason"
                  minW="var(--atlas-layout-reason-width, 255px)"
                >
                  <Box display="grid" gap="xs">
                    {correctionReason !== undefined ? (
                      <Text textStyle="helper">
                        {changed
                          ? correctionReason || "Nhập lý do điều chỉnh ở trên."
                          : "Giữ nguyên dòng đã xác nhận."}
                      </Text>
                    ) : showReasonChrome ? (
                      <NativeSelect.Root disabled={!editable || historical}>
                        <NativeSelect.Field
                          aria-label={`Lý do ${line.ingredient.name}`}
                          value={draft.reason_code}
                          aria-invalid={Boolean(error)}
                          aria-describedby={error ? description : undefined}
                          onChange={(e) =>
                            onEdit(line.confirmed_need_line_id, {
                              reason_code: e.target
                                .value as ConfirmedNeedDraftLine["reason_code"],
                            })
                          }
                        >
                          {Object.entries(confirmedNeedReasonLabels).map(
                            ([code, label]) => (
                              <option value={code} key={code}>
                                {label}
                              </option>
                            ),
                          )}
                        </NativeSelect.Field>
                        <NativeSelect.Indicator />
                      </NativeSelect.Root>
                    ) : (
                      <Text textStyle="helper" color="fg.muted">
                        Theo đề xuất
                      </Text>
                    )}
                    {correctionReason === undefined && showReasonChrome && (
                      <Input
                        aria-label={`Ghi chú ${line.ingredient.name}`}
                        placeholder="Ghi chú điều chỉnh"
                        value={draft.reason_note}
                        disabled={!editable || historical}
                        aria-invalid={Boolean(error)}
                        aria-describedby={error ? description : undefined}
                        onChange={(e) =>
                          onEdit(line.confirmed_need_line_id, {
                            reason_note: e.target.value,
                          })
                        }
                      />
                    )}
                    {error && (
                      <Text
                        id={description}
                        textStyle="helper"
                        color="status.danger"
                      >
                        {error}
                      </Text>
                    )}
                  </Box>
                </Table.Cell>
              </Table.Row>
            );
          })}
        </Table.Body>
      </Table.Root>
      {!lines.length && (
        <Text p="md" color="fg.muted">
          Không có dòng phù hợp bộ lọc.
        </Text>
      )}
    </AtlasTableViewport>
  );
}
