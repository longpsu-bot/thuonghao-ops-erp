import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  Table,
  Text,
} from "@chakra-ui/react";
import {
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
  type Ref,
} from "react";
import type { RecipeAdjustmentApi } from "../bridges/recipeAdjustment";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import { RecipeDirtyExitDialog } from "./RecipeDialogs";
import { ChangeOrderEditor, ChangeSelect } from "./ChangeOrderEditor";
import { ChangeOrderReview, ChangeOrderCancel } from "./ChangeOrderDialogs";
import { ChangeOrderDetail } from "./ChangeOrderDetail";
import {
  actionLabels,
  ledgerRows,
  periodLabel,
  rowFacts,
  scopeLabels,
  temporalLabels,
} from "./changeOrderModel";
import {
  useChangeOrderWorkbench,
  type RecipeJobHandle,
} from "./useChangeOrderWorkbench";
export function ChangeOrderWorkbench(props: {
  authSubject: string | null;
  api: RecipeAdjustmentApi;
  initialDate?: string;
  exitRef?: Ref<RecipeJobHandle>;
}) {
  const c = useChangeOrderWorkbench(props);
  const [query, setQuery] = useState(""),
    [temporal, setTemporal] = useState("current"),
    [scope, setScope] = useState("");
  const detail = useRef<HTMLDivElement>(null),
    origin = useRef<HTMLButtonElement | null>(null),
    wasOpen = useRef(false);
  const open = Boolean(c.draft || c.selected),
    selectedKey = c.draft?.adjustmentId ?? c.selected?.adjustment_id;
  useImperativeHandle(props.exitRef, () => ({ requestExit: c.requestExit }));
  useEffect(() => {
    if (open) detail.current?.focus();
    else if (wasOpen.current) origin.current?.focus();
    wasOpen.current = open;
  }, [open, selectedKey]);
  const rows = ledgerRows(c.data, query, temporal, scope);
  return (
    <Box aria-label="Lệnh điều chỉnh" minW="var(--atlas-layout-zero, 0)">
      <Flex bg="bg.toolbar" px="md" py="sm" gap="sm" wrap="wrap" align="end">
        <Field.Root flex="var(--atlas-layout-search-grow, 1 1 180px)">
          <Field.Label>Tìm lệnh</Field.Label>
          <Input
            value={query}
            placeholder="Món, trường, nguyên liệu, lý do…"
            onChange={(e) => setQuery(e.target.value)}
          />
        </Field.Root>
        <Box w="var(--atlas-layout-state-width, 190px)">
          <ChangeSelect
            label="Tình trạng"
            value={temporal}
            onChange={setTemporal}
          >
            <option value="current">Cần chú ý / hiện hành</option>
            <option value="all">Tất cả</option>
            <option value="active">Đang hiệu lực</option>
            <option value="SCHEDULED">Sắp hiệu lực</option>
            <option value="EXPIRED">Đã kết thúc</option>
            <option value="CANCELLED">Đã hủy</option>
          </ChangeSelect>
        </Box>
        <Box w="var(--atlas-layout-scope-width, 210px)">
          <ChangeSelect label="Phạm vi" value={scope} onChange={setScope}>
            <option value="">Tất cả</option>
            {Object.entries(scopeLabels).map(([v, label]) => (
              <option key={v} value={v}>
                {label}
              </option>
            ))}
          </ChangeSelect>
        </Box>
        <AtlasRefreshButton
          loading={c.loading}
          disabled={c.refreshDisabled}
          onClick={c.refresh}
        />
        <Button
          variant="businessPrimary"
          disabled={!c.canAct || Boolean(c.preview) || Boolean(c.cancelTarget)}
          onClick={(e) => {
            origin.current = e.currentTarget;
            c.openCreate();
          }}
        >
          Tạo lệnh điều chỉnh
        </Button>
      </Flex>
      {c.message && (
        <Box px="md" py="sm" role={c.lock || !c.ready ? "alert" : "status"}>
          <Text color={c.lock ? "status.warning" : "fg.default"}>
            {c.message}
          </Text>
          {(c.lock || !c.ready) && (
            <Button
              mt="xs"
              loading={c.loading}
              disabled={c.busy}
              onClick={() => void c.recover()}
            >
              {c.lock === "unknown" || c.lock === "readback"
                ? "Tải lại để xác nhận"
                : "Tải lại dữ liệu hiện tại"}
            </Button>
          )}
        </Box>
      )}
      <Grid
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: open ? "minmax(0, 62fr) minmax(0, 38fr)" : "minmax(0, 1fr)",
        }}
        minW="var(--atlas-layout-zero, 0)"
      >
        <Box
          minW="var(--atlas-layout-zero, 0)"
          overflowX="auto"
          maxH={open ? "var(--atlas-layout-ledger-height, 65dvh)" : undefined}
        >
          <Table.Root
            size="sm"
            aria-label="Lệnh điều chỉnh"
            tableLayout="fixed"
            minW={{
              base: "var(--atlas-layout-ledger-width, 700px)",
              lg: "full",
            }}
            css={{
              "& th, & td": { whiteSpace: "normal", overflowWrap: "anywhere" },
            }}
          >
            <Table.Header>
              <Table.Row>
                {[
                  "Lệnh",
                  "Phạm vi",
                  "Đối tượng",
                  "Hiệu lực",
                  "Trạng thái",
                  "Thao tác",
                ].map((label) => (
                  <Table.ColumnHeader
                    key={label}
                    w={
                      label === "Thao tác"
                        ? "var(--atlas-layout-row-action, 58px)"
                        : undefined
                    }
                  >
                    {label}
                  </Table.ColumnHeader>
                ))}
              </Table.Row>
            </Table.Header>
            <Table.Body>
              {rows.map((row) => (
                <Table.Row
                  key={row.adjustment_id}
                  aria-selected={
                    c.selected?.adjustment_id === row.adjustment_id
                  }
                  bg={
                    c.selected?.adjustment_id === row.adjustment_id
                      ? "bg.selected"
                      : undefined
                  }
                >
                  <Table.Cell position="relative">
                    {c.selected?.adjustment_id === row.adjustment_id && (
                      <Box data-selection-indicator />
                    )}
                    {actionLabels[row.action_kind]}
                  </Table.Cell>
                  <Table.Cell>{scopeLabels[row.scope_kind]}</Table.Cell>
                  <Table.Cell>{rowFacts(row, c.data).join(" · ")}</Table.Cell>
                  <Table.Cell>
                    {periodLabel(
                      row.display_revision.effective_from,
                      row.display_revision.effective_to,
                    )}
                  </Table.Cell>
                  <Table.Cell>{temporalLabels[row.temporal_state]}</Table.Cell>
                  <Table.Cell>
                    <Button
                      variant="utility"
                      size="sm"
                      disabled={
                        !c.canAct ||
                        Boolean(c.preview) ||
                        Boolean(c.cancelTarget)
                      }
                      aria-label={`Xem lệnh ${actionLabels[row.action_kind]} ${rowFacts(row, c.data)[0] ?? ""}`}
                      onClick={(e) => {
                        origin.current = e.currentTarget;
                        c.select(row);
                      }}
                    >
                      Xem
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table.Body>
          </Table.Root>
          {c.ready && !rows.length && (
            <Text p="md" textStyle="helper" color="fg.muted">
              {c.data.operator_rows.length
                ? "Không có lệnh phù hợp bộ lọc."
                : "Chưa có lệnh điều chỉnh."}
            </Text>
          )}
        </Box>
        {open && (
          <Box
            ref={detail}
            tabIndex={-1}
            aria-label="Chi tiết lệnh"
            p="md"
            maxH={{
              lg: "var(--atlas-layout-detail-height, calc(100dvh - 280px))",
            }}
            overflowY="auto"
            borderLeftWidth="var(--atlas-layout-edge, 1px)"
            borderColor="border.subtle"
            minW="var(--atlas-layout-zero, 0)"
          >
            <Flex justify="space-between" align="center" gap="sm">
              <Heading as="h2" textStyle="section">
                {c.draft
                  ? c.editing
                    ? "Sửa lệnh"
                    : "Tạo lệnh điều chỉnh"
                  : "Chi tiết lệnh"}
              </Heading>
              <Button
                variant="utility"
                size="sm"
                aria-label="Đóng lệnh"
                disabled={c.busy || Boolean(c.lock)}
                onClick={c.close}
              >
                Đóng
              </Button>
            </Flex>
            {c.draft ? (
              <ChangeOrderEditor c={c} />
            ) : (
              <ChangeOrderDetail key={c.selected!.adjustment_id} c={c} />
            )}
          </Box>
        )}
      </Grid>
      <RecipeDirtyExitDialog c={c} />
      <ChangeOrderReview c={c} />
      {c.cancelTarget && (
        <ChangeOrderCancel key={c.cancelTarget.adjustment_id} c={c} />
      )}
    </Box>
  );
}
