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

export function SchoolCookingGroupEditor({
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
          aria-controls="school-cooking-group-editor"
          onClick={() => setOpen((current) => !current)}
        >
          Quản lý nơi nấu
        </Button>
      )}
      {(embedded || open) && (
        <Box
          id="school-cooking-group-editor"
          mt="sm"
          p="md"
          bg="bg.toolbar"
          borderRadius="workbench"
        >
          <Heading as="h2" textStyle="section">
            Nơi nấu
          </Heading>
          <Text textStyle="helper" color="fg.muted" mb="sm">
            Chọn nơi nấu để quản lý trường thành viên. Nơi đặt bếp và nhóm phiếu
            xuất kho được quản lý riêng.
          </Text>
          <Grid
            gap="sm"
            templateColumns={{
              base: "minmax(0, 1fr)",
              md: "repeat(3, minmax(0, 1fr))",
            }}
          >
            <Field.Root disabled={disabled || c.groupDirty}>
              <Field.Label>Nơi nấu</Field.Label>
              <NativeSelect.Root disabled={disabled || c.groupDirty}>
                <NativeSelect.Field
                  aria-label="Nơi nấu"
                  value={c.groupEditor.id}
                  onChange={(event) => c.selectGroup(event.target.value)}
                >
                  <option value="">Tạo nhóm mới</option>
                  {c.cookingGroups.map((group) => (
                    <option
                      key={group.cooking_group_id}
                      value={group.cooking_group_id}
                    >
                      {group.cooking_group_name}
                      {` · ${c.schools.filter((s) => s.cooking_group_id === group.cooking_group_id).length} trường`}
                      {group.active ? "" : " · Ngừng hoạt động"}
                    </option>
                  ))}
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
            </Field.Root>
            <Field.Root required>
              <Field.Label>Tên nơi nấu</Field.Label>
              <Input
                aria-label="Tên nơi nấu"
                maxLength={200}
                value={c.groupEditor.name}
                disabled={disabled || c.groupEditor.location_kind === "COMPANY"}
                onChange={(event) => c.editGroup("name", event.target.value)}
              />
            </Field.Root>
            <Field.Root disabled={disabled}>
              <Field.Label>Trạng thái nơi nấu</Field.Label>
              <NativeSelect.Root disabled={disabled}>
                <NativeSelect.Field
                  aria-label="Trạng thái nơi nấu"
                  value={c.groupEditor.active ? "ACTIVE" : "INACTIVE"}
                  onChange={(event) =>
                    c.editGroup("active", event.target.value === "ACTIVE")
                  }
                >
                  <option value="ACTIVE">Đang hoạt động</option>
                  <option value="INACTIVE">Ngừng hoạt động</option>
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
            </Field.Root>
            <Field.Root required disabled={disabled}>
              <Field.Label>Loại nơi nấu</Field.Label>
              <NativeSelect.Root disabled={disabled}>
                <NativeSelect.Field
                  aria-label="Loại nơi nấu"
                  value={c.groupEditor.location_kind}
                  onChange={(event) =>
                    c.editGroup("location_kind", event.target.value)
                  }
                >
                  <option value="">Chưa xác định</option>
                  <option value="SCHOOL">Trường học</option>
                  <option value="COMPANY">Công ty Thượng Hảo</option>
                </NativeSelect.Field>
                <NativeSelect.Indicator />
              </NativeSelect.Root>
            </Field.Root>
            {c.groupEditor.location_kind === "SCHOOL" && (
              <Field.Root required disabled={disabled}>
                <Field.Label>Trường đặt bếp</Field.Label>
                <NativeSelect.Root disabled={disabled}>
                  <NativeSelect.Field
                    aria-label="Trường đặt bếp"
                    value={c.groupEditor.host_school_id}
                    onChange={(event) =>
                      c.editGroup("host_school_id", event.target.value)
                    }
                  >
                    <option value="">Chọn trường đặt bếp</option>
                    {c.schools
                      .filter(
                        (school) =>
                          school.school_status === "ACTIVE" ||
                          school.school_id === c.groupEditor.host_school_id,
                      )
                      .map((school) => (
                        <option key={school.school_id} value={school.school_id}>
                          {school.school_name}
                        </option>
                      ))}
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
              </Field.Root>
            )}
          </Grid>
          <Flex gap="sm" mt="sm" wrap="wrap">
            <Button
              variant="businessPrimary"
              size="sm"
              disabled={
                disabled ||
                !c.groupDirty ||
                !c.groupEditor.name.trim() ||
                !c.groupEditor.location_kind ||
                (c.groupEditor.location_kind === "SCHOOL" &&
                  !c.groupEditor.host_school_id)
              }
              onClick={() => void c.saveGroup()}
            >
              Lưu nơi nấu
            </Button>
            {c.groupDirty && (
              <Button
                size="sm"
                variant="outline"
                disabled={disabled}
                onClick={() => c.selectGroup(c.groupEditor.id)}
              >
                Bỏ thay đổi nơi nấu
              </Button>
            )}
          </Flex>
        </Box>
      )}
      {embedded && (
        <SchoolGroupMemberships
          controller={c}
          kind="cooking"
          disabled={disabled}
        />
      )}
    </Box>
  );
}
