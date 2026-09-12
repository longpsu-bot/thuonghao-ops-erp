import {
  Box,
  Button,
  Dialog,
  Field,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useRef, useState } from "react";
import { AtlasDateInput } from "../AtlasDateInput";
import type { DishRecipeController } from "./useDishRecipeWorkbench";

export function RecipeDirtyExitDialog({
  c,
}: {
  c: Pick<
    DishRecipeController,
    | "discardOpen"
    | "cancelDiscard"
    | "confirmDiscard"
    | "completeDiscardTransition"
  >;
}) {
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Dialog.Root
      open={c.discardOpen}
      initialFocusEl={() => cancel.current}
      onOpenChange={({ open }) => !open && c.cancelDiscard()}
      onExitComplete={c.completeDiscardTransition}
      placement="center"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          bg="bg.workbench"
          color="fg.default"
          mx="md"
          borderRadius="workbench"
        >
          <Dialog.Header>
            <Dialog.Title>
              Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Footer flexWrap="wrap">
            <Button ref={cancel} onClick={c.cancelDiscard}>
              Tiếp tục chỉnh sửa
            </Button>
            <Button variant="destructive" onClick={c.confirmDiscard}>
              Bỏ thay đổi
            </Button>
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
export function RecipeUtilityDialog({ c }: { c: DishRecipeController }) {
  const [source, setSource] = useState("");
  const [date, setDate] = useState(c.date);
  const [reason, setReason] = useState("");
  const cancel = useRef<HTMLButtonElement>(null);
  const kind = c.surface;
  const title =
    kind === "copy"
      ? "Sao chép công thức"
      : kind === "import"
        ? "Nhập workbook"
        : c.dish?.dish_status === "ACTIVE"
          ? "Ngừng dùng món"
          : "Kích hoạt món";
  const close = () => {
    if (!c.busy && !c.lock)
      c.transition(
        c.context
          ? { kind: "select", dishId: c.context.dishId }
          : { kind: "close" },
      );
  };
  return (
    <Dialog.Root
      open={["copy", "import", "lifecycle"].includes(kind ?? "")}
      initialFocusEl={() => cancel.current}
      onOpenChange={({ open }) => !open && close()}
      placement="center"
      lazyMount
      unmountOnExit
    >
      <Dialog.Backdrop />
      <Dialog.Positioner>
        <Dialog.Content
          bg="bg.workbench"
          color="fg.default"
          mx="md"
          borderRadius="workbench"
          maxH="var(--atlas-layout-dialog-height, 90dvh)"
          overflow="auto"
        >
          <Dialog.Header>
            <Dialog.Title>{title}</Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            {kind === "lifecycle" && (
              <Text>
                {c.dish?.dish_name}. Các tham chiếu vận hành và lịch sử công
                thức được giữ nguyên.
              </Text>
            )}
            {kind === "copy" && (
              <>
                <Text textStyle="helper">
                  Sao chép cả hai loại công thức. Sau đó xem lại và lưu từng
                  loại để dùng cho Lập nhu cầu.
                </Text>
                <Field.Root mt="sm">
                  <Field.Label>Món nguồn</Field.Label>
                  <NativeSelect.Root disabled={!c.canCopy}>
                    <NativeSelect.Field
                      value={source}
                      onChange={(e) => setSource(e.target.value)}
                    >
                      <option value="">Chọn món nguồn</option>
                      {c.catalog.dishes
                        .filter(
                          (d) =>
                            d.dish_id !== c.dish?.dish_id &&
                            d.dish_status === "ACTIVE",
                        )
                        .map((d) => (
                          <option key={d.dish_id} value={d.dish_id}>
                            {d.dish_name}
                          </option>
                        ))}
                    </NativeSelect.Field>
                    <NativeSelect.Indicator />
                  </NativeSelect.Root>
                </Field.Root>
                <Box mt="sm">
                  <AtlasDateInput
                    label="Ngày chụp công thức nguồn"
                    value={date}
                    onValueChange={setDate}
                    disabled={!c.canCopy}
                  />
                </Box>
              </>
            )}
            {kind === "import" && (
              <>
                <Field.Root>
                  <Field.Label>Chọn workbook .xlsx</Field.Label>
                  <Input
                    type="file"
                    accept=".xlsx"
                    disabled={!c.canCommand}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) void c.parseWorkbook(file);
                    }}
                  />
                </Field.Root>
                {c.workbook && (
                  <Box mt="sm">
                    <Text>
                      Số món: {c.workbook.sourceCounts.dishes} · Số công thức:{" "}
                      {c.workbook.sourceCounts.recipes}
                    </Text>
                    <Text>
                      Số dòng nguyên liệu: {c.workbook.sourceCounts.recipeLines}{" "}
                      · Lỗi cần xử lý: {c.workbook.errors.length}
                    </Text>
                    <Text mt="sm">
                      Kết quả kiểm tra:{" "}
                      {c.workbook.errors.length
                        ? "Cần sửa workbook"
                        : "Hợp lệ để nhập"}
                    </Text>
                    {c.workbook.errors.map((error, i) => (
                      <Text mt="xs" color="status.danger" key={i}>
                        {error.startsWith(
                          "BOM có nhiều dòng cho cùng nguyên liệu trong phạm vi ",
                        )
                          ? "BOM có nhiều dòng cho cùng nguyên liệu trong một công thức. Hãy gộp hoặc bỏ dòng trùng."
                          : error}
                      </Text>
                    ))}
                    {c.workbook.warnings.map((warning, i) => (
                      <Text mt="xs" key={i}>
                        {warning}
                      </Text>
                    ))}
                    <Text textStyle="helper" mt="sm">
                      Công thức nhập cần được xem lại và lưu trước khi dùng cho
                      Lập nhu cầu.
                    </Text>
                  </Box>
                )}
              </>
            )}
            {(kind === "copy" || kind === "import") && (
              <Field.Root mt="sm">
                <Field.Label>
                  {kind === "copy" ? "Lý do sao chép" : "Lý do nhập workbook"}
                </Field.Label>
                <Input
                  value={reason}
                  disabled={!c.canCommand}
                  onChange={(e) => setReason(e.target.value)}
                />
              </Field.Root>
            )}
            {(c.notice || c.error) && (
              <Box role="status" mt="sm">
                <Text>{c.notice ?? c.error}</Text>
                {c.lock && (
                  <Button
                    mt="sm"
                    loading={c.loading}
                    onClick={() => void c.recover()}
                  >
                    {c.lock === "stale"
                      ? "Tải lại dữ liệu hiện tại"
                      : "Tải lại để xác nhận"}
                  </Button>
                )}
              </Box>
            )}
          </Dialog.Body>
          <Dialog.Footer flexWrap="wrap">
            <Button
              ref={cancel}
              disabled={c.busy || Boolean(c.lock)}
              onClick={close}
            >
              Đóng
            </Button>
            {kind === "lifecycle" ? (
              <Button
                variant="businessPrimary"
                loading={c.busy}
                disabled={!c.canCommand}
                onClick={() => void c.setLifecycle()}
              >
                {c.dish?.dish_status === "ACTIVE" ? "Ngừng dùng" : "Kích hoạt"}
              </Button>
            ) : kind === "copy" ? (
              <Button
                variant="businessPrimary"
                loading={c.busy}
                disabled={!c.canCopy || !source || !reason.trim()}
                onClick={() => void c.copyRecipes(source, date, reason)}
              >
                Xác nhận sao chép
              </Button>
            ) : (
              <Button
                variant="businessPrimary"
                loading={c.busy}
                disabled={
                  !c.canCommand ||
                  !reason.trim() ||
                  !c.workbook?.rows.length ||
                  Boolean(c.workbook.errors.length)
                }
                onClick={() => void c.applyImport(reason)}
              >
                Áp dụng workbook
              </Button>
            )}
          </Dialog.Footer>
        </Dialog.Content>
      </Dialog.Positioner>
    </Dialog.Root>
  );
}
