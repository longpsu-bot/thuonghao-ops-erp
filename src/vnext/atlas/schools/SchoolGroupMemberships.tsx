import {
  Box,
  Button,
  Field,
  Flex,
  Input,
  NativeSelect,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useState } from "react";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import type { SchoolDefaultsController } from "./useSchoolDefaultsWorkbench";

/** Presentation over the existing one-School assignment commands. No bulk transaction. */
export function SchoolGroupMemberships({
  controller: c,
  kind,
  disabled,
}: {
  controller: SchoolDefaultsController;
  kind: "cooking" | "dispatch";
  disabled: boolean;
}) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("GROUP");
  const cooking = kind === "cooking";
  const title = cooking ? "Nấu tại" : "Nhóm phiếu xuất kho";
  const groupId = cooking ? c.groupEditor.id : c.dispatchGroupEditor.id;
  const groups = cooking
    ? c.cookingGroups.map((g) => ({
        id: g.cooking_group_id,
        name: g.cooking_group_name,
        active: g.active,
        eligible:
          !!g.location_kind &&
          (g.location_kind !== "SCHOOL" || !!g.host_school_id),
      }))
    : c.dispatchGroups.map((g) => ({
        id: g.dispatch_group_id,
        name: g.dispatch_group_name,
        active: g.active,
        eligible: true,
      }));
  const group = groups.find((g) => g.id === groupId);
  const drafts = cooking ? c.cookingDrafts : c.dispatchDrafts;
  const savedId = (school: (typeof c.schools)[number]) =>
    (cooking ? school.cooking_group_id : school.dispatch_group_id) ?? "";
  const effectiveId = (school: (typeof c.schools)[number]) =>
    drafts[school.school_id] ?? savedId(school);
  const members = c.schools.filter((s) => savedId(s) === groupId);
  const proposed = c.schools.filter((s) => effectiveId(s) === groupId);
  const unassigned = c.schools.filter((s) => !effectiveId(s));
  const search = foldVietnameseSearch(query.trim());
  const visible = c.schools.filter((s) => {
    if (search)
      return foldVietnameseSearch(
        `${s.school_name} ${s.school_code} ${s.delivery_location_name}`,
      ).includes(search);
    if (filter === "UNASSIGNED") return !effectiveId(s);
    if (filter === "ALL") return true;
    return effectiveId(s) === groupId || Object.hasOwn(drafts, s.school_id);
  });
  const edit = cooking ? c.editCooking : c.editDispatch;
  const save = cooking ? c.saveSchoolCooking : c.saveSchoolDispatch;
  if (!group)
    return (
      <Text textStyle="helper" color="fg.muted" px="md" pb="md">
        Chọn một nhóm đã lưu để xem và gán trường.
      </Text>
    );
  return (
    <Box
      p="md"
      borderTopWidth="var(--atlas-layout-edge, 1px)"
      borderColor="border.subtle"
    >
      <Text textStyle="section" as="h2">
        Trường thuộc {group.name}
      </Text>
      <Text textStyle="helper" color="fg.muted" mt="xs">
        {members.length} trường đã lưu · {proposed.length} sau thay đổi ·{" "}
        {unassigned.length} trường chưa gán · {Object.keys(drafts).length} thay
        đổi chưa lưu
      </Text>
      <Flex gap="sm" my="sm" wrap="wrap" align="end">
        <Field.Root flex="1" minW="var(--atlas-group-search-min, 200px)">
          <Field.Label>Tìm trường để gán</Field.Label>
          <Input
            aria-label={`Tìm trường — ${title}`}
            placeholder="Tên trường, mã hoặc điểm giao…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </Field.Root>
        <Field.Root
          w={{ base: "full", md: "var(--atlas-group-filter-width, 230px)" }}
        >
          <Field.Label>Danh sách trường</Field.Label>
          <NativeSelect.Root>
            <NativeSelect.Field
              aria-label={`Danh sách trường — ${title}`}
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
            >
              <option value="GROUP">Trong nhóm và đang chỉnh sửa</option>
              <option value="UNASSIGNED">Chưa gán ({unassigned.length})</option>
              <option value="ALL">Tất cả trường ({c.schools.length})</option>
            </NativeSelect.Field>
            <NativeSelect.Indicator />
          </NativeSelect.Root>
        </Field.Root>
      </Flex>
      <Text textStyle="helper" color="fg.muted" mb="sm">
        Tìm trường hoặc chọn Chưa gán để thêm thành viên. Xem thay đổi và lưu
        từng trường; các lần lưu độc lập.
      </Text>
      <Stack
        gap="var(--atlas-layout-zero, 0)"
        maxH="var(--atlas-group-members-max-height, 45dvh)"
        overflowY="auto"
        aria-label={`Thành viên — ${title}`}
      >
        {!visible.length && (
          <Text role="status" p="sm">
            Không có trường phù hợp. Chọn Chưa gán hoặc tìm tên trường.
          </Text>
        )}
        {visible.map((school) => {
          const dirty = Object.hasOwn(drafts, school.school_id);
          const before =
            groups.find((g) => g.id === savedId(school))?.name ?? "Chưa gán";
          const after =
            groups.find((g) => g.id === effectiveId(school))?.name ??
            "Chưa gán";
          return (
            <Flex
              key={school.school_id}
              gap="sm"
              py="sm"
              wrap="wrap"
              align="end"
              borderBottomWidth="var(--atlas-layout-edge, 1px)"
              borderColor="border.subtle"
            >
              <Box flex="1" minW="var(--atlas-group-school-min, 220px)">
                <Text fontWeight="semibold">{school.school_name}</Text>
                <Text textStyle="helper" color="fg.muted">
                  {school.delivery_location_name}
                </Text>
                {dirty && (
                  <Text textStyle="helper" color="fg.primary">
                    Đã lưu: {before} → Sau thay đổi: {after}
                  </Text>
                )}
              </Box>
              <Field.Root
                w={{
                  base: "full",
                  md: "var(--atlas-group-assignment-width, 250px)",
                }}
              >
                <Field.Label>{title}</Field.Label>
                <NativeSelect.Root
                  disabled={disabled || school.school_status !== "ACTIVE"}
                  size="sm"
                >
                  <NativeSelect.Field
                    aria-label={`${title} — ${school.school_name}`}
                    value={effectiveId(school)}
                    onChange={(e) => edit(school, e.target.value)}
                  >
                    <option value="">Không gán</option>
                    {groups
                      .filter((g) => g.active || g.id === savedId(school))
                      .map((g) => (
                        <option
                          key={g.id}
                          value={g.id}
                          disabled={!g.active || !g.eligible}
                        >
                          {g.name}
                          {!g.active
                            ? " · Ngừng hoạt động"
                            : !g.eligible
                              ? " · Cần đối soát nơi nấu"
                              : ""}
                        </option>
                      ))}
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
              </Field.Root>
              {dirty && (
                <Flex gap="xs">
                  <Button
                    size="sm"
                    variant="businessPrimary"
                    disabled={disabled || Boolean(c.lock)}
                    aria-label={`Lưu ${title} — ${school.school_name}`}
                    onClick={() => void save(school)}
                  >
                    Lưu trường này
                  </Button>
                  <Button
                    size="sm"
                    variant="tertiary"
                    disabled={disabled}
                    aria-label={`Hoàn tác ${title} — ${school.school_name}`}
                    onClick={() => edit(school, savedId(school))}
                  >
                    Hoàn tác
                  </Button>
                </Flex>
              )}
            </Flex>
          );
        })}
      </Stack>
      <Box
        mt="md"
        p="sm"
        bg="bg.subtle"
        aria-label={
          cooking ? "Xem trước nơi nấu" : "Xem trước nhóm phiếu xuất kho"
        }
      >
        <Text fontWeight="semibold">
          {cooking ? "Nơi nấu dự kiến" : "Nhóm phiếu mới dự kiến"}:{" "}
          {(cooking ? c.groupEditor.name : c.dispatchGroupEditor.name) ||
            group.name}
        </Text>
        {(cooking ? c.groupDirty : c.dispatchGroupDirty) && (
          <Text textStyle="helper" color="status.warning">
            Thông tin nhóm chưa lưu. Lưu thông tin nhóm riêng; lưu từng trường
            chỉ thay đổi thành viên của nhóm đã lưu.
          </Text>
        )}
        {cooking && (
          <Text textStyle="helper">
            {c.groupEditor.location_kind === "COMPANY"
              ? "Bếp Công ty Thượng Hảo"
              : `Bếp đặt tại ${c.schools.find((s) => s.school_id === c.groupEditor.host_school_id)?.school_name ?? "Chưa xác định"}`}
          </Text>
        )}
        <Text textStyle="helper">
          Trường:{" "}
          {proposed.map((s) => s.school_name).join("; ") || "Chưa có trường"}.
        </Text>
        <Text textStyle="helper" color="fg.muted">
          {cooking
            ? "Nơi nấu không quyết định nhóm phiếu xuất kho. Mỗi trường vẫn giữ nhu cầu riêng."
            : "Đóng gói theo nhóm, ngày, nguyên liệu, đơn vị và ghi chú trên phiếu phát hành; vẫn giữ từng trường đóng góp."}{" "}
          Phiếu đã phát hành giữ nguyên thông tin cũ.
        </Text>
      </Box>
    </Box>
  );
}
