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
import { SchoolGroupMemberships } from "./SchoolGroupMemberships";

export function SchoolDispatchGroupEditor({
  controller: c,
  disabled,
  embedded = false,
}: {
  controller: SchoolDefaultsController;
  disabled: boolean;
  embedded?: boolean;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Box px="md" pb="sm">
      {!embedded && (
        <Button
          variant="outline"
          size="sm"
          aria-expanded={open}
          aria-controls="school-dispatch-group-editor"
          onClick={() => setOpen((current) => !current)}
        >
          Quản lý nhóm phiếu xuất kho
        </Button>
      )}
      {(embedded || open) && (
        <Box
          id="school-dispatch-group-editor"
          mt="sm"
          p="md"
          bg="bg.toolbar"
          borderRadius="workbench"
        >
          <Heading as="h2" textStyle="section">
            Nhóm phiếu xuất kho
          </Heading>
          <Text textStyle="helper" color="fg.muted" mb="sm">
            Chọn nhóm để xem các trường đóng góp vào cách đóng gói phiếu. Nhóm
            phiếu không thay đổi nơi nấu.
          </Text>
          <Grid
            gap="sm"
            templateColumns={{
              base: "minmax(0, 1fr)",
              md: "repeat(3, minmax(0, 1fr))",
            }}
          >
            <Field.Root>
              <Field.Label>Nhóm phiếu xuất kho</Field.Label>
              <NativeSelect.Root disabled={disabled || c.dispatchGroupDirty}>
                <NativeSelect.Field
                  aria-label="Nhóm phiếu xuất kho"
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
                      {` · ${c.schools.filter((s) => s.dispatch_group_id === group.dispatch_group_id).length} trường`}
                      {group.active ? "" : " · Ngừng hoạt động"}
                    </option>
                  ))}
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
            </Field.Root>
            <Field.Root required>
              <Field.Label>Tên nhóm phiếu xuất kho</Field.Label>
              <Input
                aria-label="Tên nhóm phiếu xuất kho"
                maxLength={200}
                value={c.dispatchGroupEditor.name}
                disabled={disabled}
                onChange={(event) =>
                  c.editDispatchGroup("name", event.target.value)
                }
              />
            </Field.Root>
            <Field.Root>
              <Field.Label>Trạng thái nhóm phiếu xuất kho</Field.Label>
              <NativeSelect.Root disabled={disabled}>
                <NativeSelect.Field
                  aria-label="Trạng thái nhóm phiếu xuất kho"
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
              Lưu nhóm phiếu xuất kho
            </Button>
            {c.dispatchGroupDirty && (
              <Button
                size="sm"
                variant="outline"
                disabled={disabled}
                onClick={() => c.selectDispatchGroup(c.dispatchGroupEditor.id)}
              >
                Bỏ thay đổi nhóm phiếu xuất kho
              </Button>
            )}
          </Flex>
        </Box>
      )}
      {embedded && (
        <SchoolGroupMemberships
          controller={c}
          kind="dispatch"
          disabled={disabled}
        />
      )}
    </Box>
  );
}
