import { Box, Input, NativeSelect, Table, Text } from "@chakra-ui/react";
import { useId, useState } from "react";
import type { CSSProperties } from "react";
import { AtlasSortableColumnHeader } from "../AtlasSortableColumnHeader";
import { AtlasTableViewport } from "../AtlasTableViewport";
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
import { draftChanged, historicalQuantity } from "./confirmedNeedDraft";
import { parseExactQuantity } from "../procurement/procurementExactQuantity";
export function ConfirmedNeedTable({
  lines,
  drafts,
  errors,
  editable,
  compactEditing = false,
  onEdit,
}: {
  lines: ConfirmedNeedLine[];
  drafts: Record<string, ConfirmedNeedDraftLine>;
  errors: Record<string, string>;
  editable: boolean;
  compactEditing?: boolean;
  onEdit: (id: string, change: Partial<ConfirmedNeedDraftLine>) => void;
}) {
  type SortKey = "identity" | "proposal";
  const id = useId();
  const [sort, setSort] = useState<AtlasSortState<SortKey>>(atlasDefaultSort);
  const sortedLines = sortAtlasRows(lines, sort, {
    identity: (left, right) => {
      const ingredient = compareAtlasText(
        left.ingredient.name,
        right.ingredient.name,
      );
      return (
        ingredient ||
        compareAtlasText(
          `${left.school.name} ${left.delivery_location.name}`,
          `${right.school.name} ${right.delivery_location.name}`,
        )
      );
    },
    proposal: (left, right) =>
      compareAtlasBigInt(
        parseExactQuantity(left.proposed_confirmed_quantity),
        parseExactQuantity(right.proposed_confirmed_quantity),
      ),
  });
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
        // Native focus can leave a partially visible field clipped. Reveal only
        // its nearest horizontal edge within this table, without moving the page.
        if (bounds.left < visible.left)
          viewport.scrollLeft += bounds.left - visible.left;
        else if (bounds.right > visible.right)
          viewport.scrollLeft += bounds.right - visible.right;
      }}
      style={
        {
          "--atlas-confirmed-need-table-mobile-max-height": compactEditing
            ? "28dvh"
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
        minW="var(--atlas-layout-confirmed-need-table-min, 1040px)"
        w="var(--atlas-layout-confirmed-need-table-width, 1040px)"
        tableLayout="fixed"
      >
        <Table.ColumnGroup>
          <Table.Column w="var(--atlas-confirmed-identity-width, 260px)" />
          <Table.Column w="var(--atlas-confirmed-proposal-width, 150px)" />
          <Table.Column w="var(--atlas-confirmed-quantity-width, 180px)" />
          <Table.Column w="var(--atlas-confirmed-delta-width, 130px)" />
          <Table.Column w="var(--atlas-confirmed-reason-width, 320px)" />
        </Table.ColumnGroup>
        <Table.Header>
          <Table.Row zIndex="var(--atlas-layout-sticky-header-z, 3)">
            <AtlasSortableColumnHeader
              label="Nguyên liệu / nơi nhận"
              columnKey="identity"
              sort={sort}
              onSort={onSort}
              position={{ base: "static", xl: "sticky" }}
              left={{
                base: "var(--atlas-layout-auto, auto)",
                xl: "var(--atlas-layout-zero, 0)",
              }}
              zIndex="var(--atlas-layout-sticky-identity-header-z, 5)"
              bg="bg.toolbar"
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
                  minW="var(--atlas-layout-identity-width, 210px)"
                  position={{ base: "static", xl: "sticky" }}
                  left={{
                    base: "var(--atlas-layout-auto, auto)",
                    xl: "var(--atlas-layout-zero, 0)",
                  }}
                  style={{
                    zIndex: "var(--atlas-layout-sticky-identity-z, 2)",
                    background: "var(--atlas-colors-bg-workbench)",
                  }}
                >
                  <Text data-role="ingredient-name" fontWeight="semibold">
                    {line.ingredient.name}
                  </Text>
                  <Text
                    data-role="recipient"
                    textStyle="helper"
                    color="fg.muted"
                  >
                    {line.school.name} · {line.delivery_location.name}
                  </Text>
                  {attention && (
                    <Text textStyle="helper" color="status.warning">
                      ⚠{" "}
                      {confirmedNeedConfirmationStateLabel(
                        line.confirmation_state,
                      )}
                    </Text>
                  )}
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
                      {line.controlled_unit.code}
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
                      aria-describedby={
                        error || historical ? description : undefined
                      }
                      onChange={(e) =>
                        onEdit(line.confirmed_need_line_id, {
                          exact_quantity: e.target.value,
                          quantity_entered: true,
                        })
                      }
                    />
                    <Text textStyle="unitInline" color="fg.muted">
                      {line.controlled_unit.code}
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
                        {line.controlled_unit.code}
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
                    {showReasonChrome ? (
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
                    {showReasonChrome && (
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
