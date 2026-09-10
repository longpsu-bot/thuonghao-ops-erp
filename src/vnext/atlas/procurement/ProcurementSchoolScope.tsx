import { foldVietnameseSearch } from "./foldVietnameseSearch";
import {
  Box,
  Button,
  Checkbox,
  Flex,
  Input,
  Popover,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useRef, useState } from "react";
import type { ProcurementSchoolOption } from "../bridges/procurement";

export function ProcurementSchoolScope({
  schools,
  value,
  disabled,
  onApply,
}: {
  schools: ProcurementSchoolOption[];
  value: string[];
  disabled?: boolean;
  onApply: (ids: string[]) => void;
}) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<string[]>([]);
  const [search, setSearch] = useState("");
  const trigger = useRef<HTMLButtonElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const label =
    value.length === 0
      ? "Tất cả trường"
      : value.length === 1
        ? (schools.find((school) => school.school_id === value[0])
            ?.school_name ?? "1 trường")
        : `${value.length} trường`;
  const close = () => {
    setOpen(false);
    trigger.current?.focus();
  };
  return (
    <Popover.Root
      open={open}
      onOpenChange={({ open: next }) => {
        if (next) {
          setDraft(
            value.length ? value : schools.map((school) => school.school_id),
          );
          setSearch("");
        }
        setOpen(next);
      }}
      initialFocusEl={() => searchInput.current}
      positioning={{ placement: "bottom-start" }}
      lazyMount
      unmountOnExit
    >
      <Popover.Trigger asChild>
        <Button
          ref={trigger}
          disabled={disabled}
          w="full"
          justifyContent="space-between"
          textAlign="left"
          title={label}
        >
          <Text truncate>{label}</Text>
          <Box as="span" aria-hidden="true">
            ⌄
          </Box>
        </Button>
      </Popover.Trigger>
      <Popover.Positioner>
        <Popover.Content
          aria-label="Trường / điểm giao"
          bg="bg.workbench"
          color="fg.default"
          borderColor="border.default"
          borderRadius="workbench"
          boxShadow="var(--atlas-layout-shadow, none)"
          w="var(--atlas-layout-school-width, min(360px, calc(100vw - 32px)))"
          animation="var(--atlas-layout-motion, none)"
        >
          <Popover.Body>
            <Stack gap="sm">
              <Flex align="center" justify="space-between">
                <Popover.Title fontWeight="semibold">
                  Trường / điểm giao
                </Popover.Title>
                <Button
                  size="sm"
                  variant="utility"
                  aria-label="Đóng bộ chọn trường"
                  onClick={close}
                >
                  Đóng
                </Button>
              </Flex>
              <Input
                ref={searchInput}
                aria-label="Tìm trường"
                placeholder="Tìm tên trường"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
              />
              <Flex gap="xs" wrap="wrap">
                <Button
                  size="sm"
                  onClick={() =>
                    setDraft(schools.map((school) => school.school_id))
                  }
                >
                  Chọn tất cả
                </Button>
                <Button
                  size="sm"
                  variant="utility"
                  onClick={() => setDraft([])}
                >
                  Bỏ chọn tất cả
                </Button>
              </Flex>
              <Text textStyle="helper" color="fg.muted">
                Đã chọn {draft.length} / {schools.length} trường
              </Text>
              <Stack
                maxH="var(--atlas-layout-school-list-height, 260px)"
                overflowY="auto"
                gap="xs"
              >
                {schools
                  .filter((school) =>
                    foldVietnameseSearch(school.school_name).includes(
                      foldVietnameseSearch(search),
                    ),
                  )
                  .map((school) => (
                    <Checkbox.Root
                      key={school.school_id}
                      checked={draft.includes(school.school_id)}
                      onCheckedChange={({ checked }) =>
                        setDraft((ids) =>
                          checked
                            ? [...ids, school.school_id]
                            : ids.filter((id) => id !== school.school_id),
                        )
                      }
                    >
                      <Checkbox.HiddenInput />
                      <Checkbox.Control
                        borderColor="border.default"
                        borderRadius="control"
                        _checked={{
                          bg: "action.primary.default",
                          color: "fg.inverse",
                          borderColor: "action.primary.default",
                        }}
                      >
                        <Checkbox.Indicator />
                      </Checkbox.Control>
                      <Checkbox.Label textStyle="body">
                        {school.school_name}
                      </Checkbox.Label>
                    </Checkbox.Root>
                  ))}
              </Stack>
              {!draft.length && (
                <Text color="status.warning" textStyle="helper">
                  Chọn ít nhất một trường để áp dụng.
                </Text>
              )}
              <Button
                variant="businessPrimary"
                disabled={!draft.length}
                onClick={() => {
                  onApply(
                    draft.length === schools.length ? [] : [...draft].sort(),
                  );
                  close();
                }}
              >
                Áp dụng
              </Button>
            </Stack>
          </Popover.Body>
        </Popover.Content>
      </Popover.Positioner>
    </Popover.Root>
  );
}
