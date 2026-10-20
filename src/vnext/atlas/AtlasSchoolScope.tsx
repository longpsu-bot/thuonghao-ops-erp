import { foldVietnameseSearch } from "./foldVietnameseSearch";
import {
  compareCanonicalSchools,
  type CanonicalSchoolOrder,
} from "./canonicalSchoolOrder";
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
import { useLayoutEffect, useRef, useState } from "react";
import { useAtlasWorkbenchActive } from "./AtlasVNextProvider";
type AtlasSchoolOption = CanonicalSchoolOrder;

export function AtlasSchoolScope({
  schools,
  value,
  disabled,
  onApply,
}: {
  schools: AtlasSchoolOption[];
  value: string[];
  disabled?: boolean;
  onApply: (ids: string[]) => void;
}) {
  const [open, setOpen] = useState(false);
  const active = useAtlasWorkbenchActive();
  useLayoutEffect(() => {
    if (!active) setOpen(false);
  }, [active]);
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
  const filtered = schools
    .filter((school) =>
      foldVietnameseSearch(school.school_name).includes(
        foldVietnameseSearch(search),
      ),
    )
    .sort(compareCanonicalSchools);
  return (
    <Popover.Root
      open={active && open}
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
          maxW="var(--atlas-layout-school-max-width, calc(100vw - 32px))"
          animation="var(--atlas-layout-motion, none)"
          overflow="hidden"
        >
          <Popover.Body
            display="flex"
            minH="var(--atlas-layout-zero, 0)"
            overflowY="auto"
          >
            <Stack gap="sm" flex="1" minH="var(--atlas-layout-zero, 0)">
              <Flex align="center" justify="space-between" flexShrink="0">
                <Popover.Title fontWeight="semibold">
                  Trường / điểm giao
                </Popover.Title>
                <Button
                  size="sm"
                  variant="tertiary"
                  aria-label="Đóng bộ chọn trường"
                  onClick={close}
                >
                  Đóng
                </Button>
              </Flex>
              <Input
                flexShrink="0"
                ref={searchInput}
                aria-label="Tìm trường"
                placeholder="Tìm tên trường"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
              />
              <Flex gap="xs" wrap="wrap" flexShrink="0">
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
                  variant="tertiary"
                  onClick={() => setDraft([])}
                >
                  Bỏ chọn tất cả
                </Button>
              </Flex>
              <Text textStyle="helper" color="fg.muted" flexShrink="0">
                Đã chọn {draft.length} / {schools.length} trường
              </Text>
              <Stack
                flex="1"
                minH="var(--atlas-layout-mobile-target, 44px)"
                maxH="var(--atlas-layout-school-list-height, 260px)"
                overflowY="auto"
                gap="xs"
              >
                {!filtered.length && (
                  <Text role="status" color="fg.muted">
                    Không tìm thấy trường phù hợp.
                  </Text>
                )}
                {filtered.map((school) => (
                  <Checkbox.Root
                    key={school.school_id}
                    flexShrink="0"
                    w="full"
                    alignItems="center"
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
                    <Checkbox.Control flexShrink="0">
                      <Checkbox.Indicator />
                    </Checkbox.Control>
                    <Checkbox.Label
                      textStyle="body"
                      whiteSpace="normal"
                      overflowWrap="anywhere"
                    >
                      {school.school_name}
                    </Checkbox.Label>
                  </Checkbox.Root>
                ))}
              </Stack>
              {!draft.length && (
                <Text color="status.warning" textStyle="helper" flexShrink="0">
                  Chọn ít nhất một trường để áp dụng.
                </Text>
              )}
            </Stack>
          </Popover.Body>
          <Popover.Footer flexShrink="0" pt="var(--atlas-layout-zero, 0)">
            <Button
              w="full"
              variant="secondary"
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
          </Popover.Footer>
        </Popover.Content>
      </Popover.Positioner>
    </Popover.Root>
  );
}
