import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Tabs,
  Text,
} from "@chakra-ui/react";
import { useEffect, useRef, useState } from "react";
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

export type ProcurementWorkbenchProps = ProcurementControllerProps & {
  schools?: ProcurementSchoolOption[];
  onExportXlsx?: ProcurementExport;
  onExportPdf?: ProcurementExport;
};
function fold(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[đĐ]/g, "d")
    .toLocaleLowerCase("vi");
}
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
  return (
    <Box
      as="section"
      aria-label="Kế hoạch mua hàng"
      bg="bg.workbench"
      borderRadius="workbench"
      borderWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Tabs.Root
        value={controller.stage}
        onValueChange={({ value }) => {
          setSelectedKey(null);
          setSearch("");
          controller.changeStage(value === "orders" ? "orders" : "allocation");
        }}
        variant="line"
      >
        <Flex
          px="md"
          py="md"
          justify="space-between"
          gap="sm"
          wrap="wrap"
          align="end"
        >
          <Box>
            <Text textStyle="helper" color="fg.muted">
              Kế hoạch mua hàng
            </Text>
            <Heading
              as="h1"
              textStyle="workbenchTitle"
              tabIndex={-1}
              ref={heading}
            >
              {controller.stage === "allocation"
                ? "Phân bổ nhà cung ứng"
                : "Đơn mua"}
            </Heading>
          </Box>
          <Tabs.List
            aria-label="Công việc mua hàng"
            borderColor="border.subtle"
          >
            <Tabs.Trigger
              value="allocation"
              color="fg.muted"
              _selected={{ color: "fg.primary", bg: "bg.selected" }}
              _before={{ bg: "border.accent" }}
            >
              Phân bổ NCC
            </Tabs.Trigger>
            <Tabs.Trigger
              value="orders"
              color="fg.muted"
              _selected={{ color: "fg.primary", bg: "bg.selected" }}
              _before={{ bg: "border.accent" }}
            >
              Đơn mua
            </Tabs.Trigger>
          </Tabs.List>
        </Flex>
        <Grid
          role="group"
          aria-label="Phạm vi mua hàng"
          bg="bg.toolbar"
          p="md"
          gap="sm"
          alignItems="end"
          templateColumns={{
            base: "minmax(0, 1fr)",
            md: "repeat(2, minmax(0, 1fr))",
            xl:
              controller.stage === "allocation"
                ? "minmax(155px, 0.9fr) minmax(170px, 1.2fr) minmax(160px, 1fr) minmax(145px, 0.9fr) auto"
                : "minmax(155px, 0.8fr) minmax(200px, 2fr) auto",
          }}
        >
          <AtlasDateInput
            label="Ngày phục vụ"
            value={controller.date}
            onValueChange={(value) => {
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
                disabled={controller.loading}
                onApply={(ids) => {
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
            <Field.Root>
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
            disabled={controller.busy || controller.locked || Boolean(selected)}
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
        {controller.readError && controller.feedback?.kind !== "unknown" && (
          <Box role="alert" p="md">
            <Text color="status.warning">⚠ {controller.readError}</Text>
            <Button
              mt="sm"
              disabled={controller.loading}
              onClick={() => void controller.reload()}
            >
              Tải lại dữ liệu hiện tại
            </Button>
          </Box>
        )}
        {controller.loading && (
          <Text role="status" px="md" py="sm" color="fg.muted">
            Đang tải dữ liệu…
          </Text>
        )}
        <Tabs.Content value={controller.stage} p="var(--atlas-layout-zero, 0)">
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
                  {rows.filter((row) => row.state !== "BALANCED").length} · Đã
                  đủ {rows.filter((row) => row.state === "BALANCED").length}
                </Text>
                {canPrepare && (
                  <Button
                    variant="businessPrimary"
                    onClick={() => void controller.prepare(Boolean(selected))}
                  >
                    Tiếp tục lên đơn
                  </Button>
                )}
                {!selected && !preparation?.ready && preparation && (
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
                minW="var(--atlas-layout-zero, 0)"
                templateColumns={{
                  base: "minmax(0, 1fr)",
                  xl: selected
                    ? "minmax(0, 62fr) minmax(320px, 38fr)"
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
                    key={`${selected.family.source_fingerprint}:${controller.revision}`}
                    row={selected}
                    disabled={commandDisabled}
                    onSave={(splits) => void controller.save(selected, splits)}
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
  );
}
