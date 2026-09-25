import type {
  AtlasModuleExitHandle,
  AtlasModuleExitProps,
} from "../AtlasModuleExit";
import { foldVietnameseSearch as fold } from "../foldVietnameseSearch";
import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Input,
  NativeSelect,
  Tabs,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState, useImperativeHandle } from "react";
import type { CSSProperties } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
import { AtlasRefreshButton } from "../AtlasRefreshButton";
import {
  procurementOperatorMessages,
  type ProcurementSchoolOption,
} from "../bridges/procurement";
import { ProcurementAllocationTable } from "./ProcurementAllocationTable";
import { ProcurementCommandFeedback } from "./ProcurementCommandFeedback";
import {
  ProcurementOrdersStage,
  type ProcurementExport,
} from "./ProcurementOrdersStage";
import { ProcurementSchoolScope } from "./ProcurementSchoolScope";
import { ProcurementSupplierDetail } from "./ProcurementSupplierDetail";
import {
  useProcurementWorkbench,
  type ProcurementControllerProps,
} from "./useProcurementWorkbench";
import { atlasPrimaryTabList, atlasPrimaryTabTrigger } from "../AtlasTaskTabs";
import { AtlasTaskContext } from "../AtlasTaskContext";

export type ProcurementWorkbenchProps = ProcurementControllerProps &
  AtlasModuleExitProps & {
    schools?: ProcurementSchoolOption[];
    onExportXlsx?: ProcurementExport;
    onExportPdf?: ProcurementExport;
  };
export function ProcurementWorkbench(props: ProcurementWorkbenchProps) {
  const controller = useProcurementWorkbench(props);
  const [search, setSearch] = useState("");
  const [exception, setException] = useState("");
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [catalogue, setCatalogue] = useState<ProcurementSchoolOption[]>(
    props.schools ?? [],
  );
  const rowTrigger = useRef<HTMLButtonElement | null>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const previousStage = useRef(controller.stage);
  useEffect(() => {
    if (previousStage.current !== controller.stage) {
      setSelectedKey(null);
      heading.current?.focus();
    }
    previousStage.current = controller.stage;
  }, [controller.stage]);
  useEffect(() => {
    if (props.schools) {
      setCatalogue(props.schools);
      return;
    }
    if (controller.allocation && !controller.schoolIds.length)
      setCatalogue(
        Array.from(
          new Map(
            controller.allocation.rows.flatMap((row) =>
              (
                row.schools ??
                (row.school_id && row.school_name
                  ? [{ school_id: row.school_id, school_name: row.school_name }]
                  : [])
              ).map((school) => [school.school_id, school]),
            ),
          ).values(),
        ).sort((a, b) => a.school_name.localeCompare(b.school_name, "vi")),
      );
  }, [props.schools, controller.allocation, controller.schoolIds]);
  const selected = controller.allocation?.rows.find(
    (row) => row.family.source_fingerprint === selectedKey,
  );
  const rows = controller.allocation?.rows ?? [];
  const visible = rows.filter((row) => {
    if (exception === "unallocated" && row.state !== "UNALLOCATED")
      return false;
    if (
      exception === "needs_update" &&
      !["STALE_REBALANCE_AVAILABLE", "NEEDS_REALLOCATION"].includes(row.state)
    )
      return false;
    if (exception === "blocked" && row.state !== "BLOCKED") return false;
    return fold(
      [
        row.ingredient_name,
        row.school_name,
        ...(row.schools?.map((school) => school.school_name) ?? []),
        row.location_name,
        ...row.splits.map((split) => split.supplier_name),
        ...row.eligible_suppliers.map((supplier) => supplier.supplier_name),
      ].join(" "),
    ).includes(fold(search.trim()));
  });
  const detailExit = useRef<AtlasModuleExitHandle>(null);
  useImperativeHandle(props.exitRef, () => ({
    requestExit: (next) => {
      if (controller.busy || controller.locked) return;
      if (selected) detailExit.current?.requestExit(next);
      else next();
    },
  }));
  const closeDetail = () => {
    setSelectedKey(null);
    rowTrigger.current?.focus();
  };
  const preparation = controller.allocation?.preparation;
  const commandDisabled =
    controller.locked || controller.busy || controller.loading;
  const canPrepare =
    preparation?.ready && preparation.allowed && !selected && !commandDisabled;
  const sourceMessages = procurementOperatorMessages(
    [
      ...(controller.allocation?.warnings ?? []),
      ...(controller.allocation?.blockers ?? []),
    ],
    "Có điều kiện cần kiểm tra trước khi tiếp tục.",
  );
  const [year, month, day] = controller.date.split("-");
  const scopeSummary = controller.schoolIds.length
    ? controller.schoolIds.length === 1
      ? (catalogue.find(
          (school) => school.school_id === controller.schoolIds[0],
        )?.school_name ?? "1 trường")
      : `${controller.schoolIds.length} trường`
    : "Tất cả trường";
  return (
    <Box
      as="section"
      aria-label="Kế hoạch mua hàng"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
      minH={{
        base: "var(--atlas-layout-workbench-mobile-height, calc(100dvh - 132px))",
        lg: "var(--atlas-layout-workbench-height, calc(100dvh - 100px))",
      }}
    >
      <Grid
        style={
          {
            minHeight:
              "var(--atlas-procurement-station-height, var(--atlas-layout-workbench-height, calc(100dvh - 100px)))",
          } as CSSProperties
        }
        css={{
          "--atlas-procurement-station-height": {
            base: "var(--atlas-layout-workbench-mobile-height, calc(100dvh - 132px))",
            lg: "var(--atlas-layout-workbench-height, calc(100dvh - 100px))",
          },
        }}
        templateColumns={{
          base: "minmax(0, 1fr)",
          lg: "var(--atlas-task-context-desktop-width, 196px) minmax(0, 1fr)",
        }}
      >
        <AtlasTaskContext
          ariaLabel="Ngữ cảnh công việc mua hàng"
          moduleLabel="Kế hoạch mua hàng"
          jobLabel={
            controller.stage === "allocation"
              ? "Phân bổ nhà cung ứng"
              : "Đơn mua"
          }
          headingRef={heading}
          details={[
            {
              label: "Ngày phục vụ",
              value: [day, month, year].filter(Boolean).join("/"),
            },
            ...(controller.stage === "allocation"
              ? [{ label: "Trường / điểm giao", value: scopeSummary }]
              : []),
          ]}
        />
        <Box minW="var(--atlas-layout-zero, 0)" bg="bg.workbench">
          <Tabs.Root
            value={controller.stage}
            onValueChange={({ value }) => {
              if (selected) return;
              setSelectedKey(null);
              setSearch("");
              controller.changeStage(
                value === "orders" ? "orders" : "allocation",
              );
            }}
            variant="line"
          >
            <Box px="md" py="sm">
              <Tabs.List
                aria-label="Công việc mua hàng"
                {...atlasPrimaryTabList}
              >
                <Tabs.Trigger
                  value="allocation"
                  disabled={
                    Boolean(selected) && controller.stage !== "allocation"
                  }
                  {...atlasPrimaryTabTrigger}
                >
                  Phân bổ NCC
                </Tabs.Trigger>
                <Tabs.Trigger
                  value="orders"
                  disabled={Boolean(selected) && controller.stage !== "orders"}
                  {...atlasPrimaryTabTrigger}
                >
                  Đơn mua
                </Tabs.Trigger>
              </Tabs.List>
            </Box>
            <Grid
              role="group"
              aria-label="Phạm vi mua hàng"
              bg="bg.toolbar"
              p={{ base: "sm", md: "md" }}
              gap="sm"
              alignItems="end"
              templateColumns={{
                base: "minmax(0, 1fr)",
                md: "repeat(2, minmax(0, 1fr))",
                xl:
                  controller.stage === "allocation"
                    ? "minmax(145px, 0.8fr) minmax(160px, 1.1fr) minmax(150px, 1fr) minmax(135px, 0.8fr) auto"
                    : "minmax(155px, 0.8fr) minmax(200px, 2fr) auto",
              }}
            >
              <AtlasDateInput
                disabled={Boolean(selected)}
                label="Ngày phục vụ"
                value={controller.date}
                onValueChange={(value) => {
                  if (selected) return;
                  setSelectedKey(null);
                  controller.changeDate(value);
                }}
              />
              {controller.stage === "allocation" && (
                <Box>
                  <Text textStyle="label" mb="xs">
                    Trường / điểm giao
                  </Text>
                  <ProcurementSchoolScope
                    schools={catalogue}
                    value={controller.schoolIds}
                    disabled={controller.loading || Boolean(selected)}
                    onApply={(ids) => {
                      if (selected) return;
                      setSelectedKey(null);
                      controller.changeSchools(ids);
                    }}
                  />
                </Box>
              )}
              <Field.Root>
                <Field.Label>Tìm kiếm</Field.Label>
                <Input
                  aria-label="Tìm kiếm"
                  placeholder="Nguyên liệu, trường, nhà cung ứng"
                  value={search}
                  disabled={Boolean(selected)}
                  onChange={(event) => setSearch(event.target.value)}
                />
              </Field.Root>
              {controller.stage === "allocation" && (
                <Field.Root disabled={Boolean(selected)}>
                  <Field.Label>Ngoại lệ</Field.Label>
                  <NativeSelect.Root disabled={Boolean(selected)}>
                    <NativeSelect.Field
                      aria-label="Ngoại lệ"
                      value={exception}
                      onChange={(event) => setException(event.target.value)}
                    >
                      <option value="">Tất cả</option>
                      <option value="unallocated">Chưa phân bổ</option>
                      <option value="needs_update">Cần cập nhật</option>
                      <option value="blocked">Bị chặn</option>
                    </NativeSelect.Field>
                    <NativeSelect.Indicator />
                  </NativeSelect.Root>
                </Field.Root>
              )}
              <AtlasRefreshButton
                loading={controller.loading}
                disabled={
                  controller.busy || controller.locked || Boolean(selected)
                }
                onClick={() => void controller.reload()}
              />
            </Grid>
            {controller.feedback && (
              <ProcurementCommandFeedback
                feedback={controller.feedback}
                busy={controller.busy || controller.loading}
                onReload={() => void controller.reload()}
                onRetry={() => void controller.retry()}
              />
            )}
            {controller.readError && (
              <Box role="alert" p="md">
                <Text color="status.warning">
                  ⚠ Không tải được dữ liệu hiện tại: {controller.readError}
                </Text>
                {controller.feedback?.kind !== "unknown" && (
                  <Button
                    mt="sm"
                    disabled={controller.loading}
                    onClick={() => void controller.reload()}
                  >
                    Tải lại dữ liệu hiện tại
                  </Button>
                )}
              </Box>
            )}
            {controller.loading && (
              <Text role="status" px="md" py="sm" color="fg.muted">
                Đang tải dữ liệu…
              </Text>
            )}
            <Tabs.Content
              value={controller.stage}
              p="var(--atlas-layout-zero, 0)"
            >
              {controller.stage === "allocation" ? (
                <>
                  <Flex
                    px="md"
                    py="sm"
                    align="center"
                    justify="space-between"
                    gap="sm"
                    wrap="wrap"
                  >
                    <Text textStyle="helper" color="fg.muted">
                      Cần xử lý{" "}
                      {rows.filter((row) => row.state !== "BALANCED").length} ·
                      Đã đủ{" "}
                      {rows.filter((row) => row.state === "BALANCED").length}
                    </Text>
                    {canPrepare && (
                      <Button
                        variant="businessPrimary"
                        onClick={() =>
                          void controller.prepare(Boolean(selected))
                        }
                      >
                        Tiếp tục lên đơn
                      </Button>
                    )}
                    {!selected &&
                      !(preparation?.ready && preparation.allowed) &&
                      preparation && (
                        <Text textStyle="helper" color="status.warning">
                          {procurementOperatorMessages(
                            preparation.blockers,
                            "Hoàn tất phân bổ trước khi lên đơn.",
                          ).join(" ")}
                        </Text>
                      )}
                  </Flex>
                  {sourceMessages.map((message) => (
                    <Text px="md" pb="sm" key={message} color="status.warning">
                      ⚠ {message}
                    </Text>
                  ))}
                  <Grid
                    data-testid="procurement-master-detail"
                    style={
                      {
                        "--atlas-attached-detail-width": "320px",
                      } as CSSProperties
                    }
                    minW="var(--atlas-layout-zero, 0)"
                    templateColumns={{
                      base: "minmax(0, 1fr)",
                      lg: selected
                        ? "minmax(0, 1fr) var(--atlas-attached-detail-width)"
                        : "minmax(0, 1fr)",
                    }}
                  >
                    <ProcurementAllocationTable
                      rows={visible}
                      selectedKey={selected ? selectedKey : null}
                      disabled={controller.loading || controller.busy}
                      onSelect={(row, trigger) => {
                        rowTrigger.current = trigger;
                        setSelectedKey(row.family.source_fingerprint);
                      }}
                    />
                    {selected && (
                      <ProcurementSupplierDetail
                        exitRef={detailExit}
                        key={`${selected.family.source_fingerprint}:${controller.revision}`}
                        row={selected}
                        disabled={commandDisabled}
                        onSave={(splits) =>
                          void controller.save(selected, splits)
                        }
                        onClose={closeDetail}
                      />
                    )}
                  </Grid>
                </>
              ) : (
                <ProcurementOrdersStage
                  data={controller.orders}
                  disabled={commandDisabled}
                  search={search}
                  onAction={(order) => void controller.orderAction(order)}
                  onExportXlsx={props.onExportXlsx}
                  onExportPdf={props.onExportPdf}
                />
              )}
            </Tabs.Content>
          </Tabs.Root>
        </Box>
      </Grid>
    </Box>
  );
}
