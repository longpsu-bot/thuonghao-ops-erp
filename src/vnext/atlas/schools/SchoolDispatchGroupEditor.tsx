import {
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Input,
  NativeSelect,
  Text,
} from "@chakra-ui/react";
import { useState } from "react";
import type { SchoolDefaultsController } from "./useSchoolDefaultsWorkbench";

export function SchoolDispatchGroupEditor({
  controller: c,
  disabled,
}: {
  controller: SchoolDefaultsController;
  disabled: boolean;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Box px="md" pb="sm">
      <Button
        variant="outline"
        size="sm"
        aria-expanded={open}
        aria-controls="school-dispatch-group-editor"
        onClick={() => setOpen((current) => !current)}
      >
        Quản lý nhóm Dispatch
      </Button>
      {open && (
        <Box
          id="school-dispatch-group-editor"
          mt="sm"
          p="md"
          bg="bg.toolbar"
          borderRadius="workbench"
        >
          <Heading as="h2" textStyle="section">
            Nhóm Dispatch
          </Heading>
          <Text textStyle="helper" color="fg.muted" mb="sm">
            Nhóm Dispatch được chọn tại từng trường. Ngừng hoạt động yêu cầu bỏ
            hoặc đổi các trường đang được gán.
          </Text>
          <Grid
            gap="sm"
            templateColumns={{
              base: "minmax(0, 1fr)",
              md: "repeat(3, minmax(0, 1fr))",
            }}
          >
            <Field.Root>
              <Field.Label>Nhóm Dispatch</Field.Label>
              <NativeSelect.Root disabled={disabled || c.dispatchGroupDirty}>
                <NativeSelect.Field
                  aria-label="Nhóm Dispatch"
                  value={c.dispatchGroupEditor.id}
                  onChange={(event) =>
                    c.selectDispatchGroup(event.target.value)
                  }
                >
                  <option value="">Tạo nhóm mới</option>
                  {c.dispatchGroups.map((group) => (
                    <option
                      key={group.dispatch_group_id}
                      value={group.dispatch_group_id}
                    >
                      {group.dispatch_group_name}
                      {group.active ? "" : " · Ngừng hoạt động"}
                    </option>
                  ))}
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
            </Field.Root>
            <Field.Root required>
              <Field.Label>Tên nhóm Dispatch</Field.Label>
              <Input
                aria-label="Tên nhóm Dispatch"
                maxLength={200}
                value={c.dispatchGroupEditor.name}
                disabled={disabled}
                onChange={(event) =>
                  c.editDispatchGroup("name", event.target.value)
                }
              />
            </Field.Root>
            <Field.Root>
              <Field.Label>Trạng thái nhóm Dispatch</Field.Label>
              <NativeSelect.Root disabled={disabled}>
                <NativeSelect.Field
                  aria-label="Trạng thái nhóm Dispatch"
                  value={c.dispatchGroupEditor.active ? "ACTIVE" : "INACTIVE"}
                  onChange={(event) =>
                    c.editDispatchGroup(
                      "active",
                      event.target.value === "ACTIVE",
                    )
                  }
                >
                  <option value="ACTIVE">Đang hoạt động</option>
                  <option value="INACTIVE">Ngừng hoạt động</option>
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
            </Field.Root>
          </Grid>
          <Flex gap="sm" mt="sm" wrap="wrap">
            <Button
              variant="businessPrimary"
              size="sm"
              disabled={
                disabled ||
                !c.dispatchGroupDirty ||
                !c.dispatchGroupEditor.name.trim()
              }
              onClick={() => void c.saveDispatchGroup()}
            >
              Lưu nhóm Dispatch
            </Button>
            {c.dispatchGroupDirty && (
              <Button
                size="sm"
                variant="outline"
                disabled={disabled}
                onClick={() => c.selectDispatchGroup(c.dispatchGroupEditor.id)}
              >
                Bỏ thay đổi nhóm Dispatch
              </Button>
            )}
          </Flex>
        </Box>
      )}
    </Box>
  );
}
