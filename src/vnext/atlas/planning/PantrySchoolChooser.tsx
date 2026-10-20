import { Box, Input, Popover, Portal, Stack, Text } from "@chakra-ui/react";
import {
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type RefObject,
} from "react";
import {
  useAtlasPortalContainer,
  useAtlasWorkbenchActive,
} from "../AtlasVNextProvider";
import type { PantrySchool } from "../bridges/planning";
import { foldVietnameseSearch } from "../foldVietnameseSearch";

/** Add-time target only: typing cannot reassign existing Pantry lines. */
export function PantrySchoolChooser({
  schools,
  value,
  disabled,
  onChange,
  inputRef,
}: {
  schools: PantrySchool[];
  value: string;
  disabled?: boolean;
  onChange: (id: string) => void;
  inputRef: RefObject<HTMLInputElement | null>;
}) {
  const id = useId();
  const portal = useAtlasPortalContainer();
  const active = useAtlasWorkbenchActive();
  const previousValue = useRef(value);
  const selected = schools.find((school) => school.school_id === value);
  const [query, setQuery] = useState(selected?.school_name ?? "");
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState<string | null>(null);
  const search = foldVietnameseSearch(query.trim());
  const filtered = schools.filter((school) =>
    foldVietnameseSearch(
      `${school.school_name} ${school.school_code}`,
    ).includes(search),
  );
  const matches = filtered.slice(0, 40);
  const isOpen = open && active && !disabled;
  const close = () => {
    setOpen(false);
    setHighlight(null);
    setQuery(selected?.school_name ?? "");
  };
  useEffect(() => {
    if (previousValue.current === value) return;
    previousValue.current = value;
    setQuery(selected?.school_name ?? "");
    setOpen(false);
    setHighlight(null);
  }, [value, selected?.school_name]);
  useLayoutEffect(() => {
    if (!active || disabled) {
      setOpen(false);
      setHighlight(null);
      setQuery(selected?.school_name ?? "");
    }
  }, [active, disabled, selected?.school_name]);
  useLayoutEffect(() => {
    if (isOpen && highlight)
      document
        .getElementById(`${id}-school-${highlight}`)
        ?.scrollIntoView?.({ block: "nearest" });
  }, [isOpen, highlight, id]);
  const choose = (school: PantrySchool | undefined) => {
    if (!school || disabled || school.school_status !== "ACTIVE") return;
    setQuery(school.school_name);
    setOpen(false);
    setHighlight(null);
    onChange(school.school_id);
  };
  const move = (direction: 1 | -1) => {
    setOpen(true);
    const current = matches.findIndex(
      (school) => school.school_id === highlight,
    );
    const from = current < 0 && direction === -1 ? 0 : current;
    for (let offset = 1; offset <= matches.length; offset++) {
      const index =
        (from + direction * offset + matches.length) % matches.length;
      if (matches[index]?.school_status === "ACTIVE") {
        setHighlight(matches[index]!.school_id);
        return;
      }
    }
  };
  const highlighted = matches.find((school) => school.school_id === highlight);
  return (
    <Popover.Root
      open={isOpen}
      autoFocus={false}
      onOpenChange={({ open: next }) => {
        if (!next) close();
      }}
      onInteractOutside={(event) => {
        if (event.target === inputRef.current) event.preventDefault();
      }}
      positioning={{ placement: "bottom-start", sameWidth: true }}
      lazyMount
      unmountOnExit
    >
      <Popover.Anchor asChild>
        <Box
          w={{
            base: "full",
            md: "var(--atlas-layout-add-school-width, 220px)",
          }}
          minW="var(--atlas-layout-zero, 0)"
        >
          <Input
            ref={inputRef}
            role="combobox"
            aria-label="Trường cần thêm hàng"
            aria-autocomplete="list"
            aria-expanded={isOpen}
            aria-controls={`${id}-schools`}
            aria-activedescendant={
              isOpen && highlighted ? `${id}-school-${highlight}` : undefined
            }
            disabled={disabled}
            value={query}
            placeholder="Tìm trường cần thêm hàng…"
            onFocus={() => {
              setQuery("");
              setOpen(true);
              setHighlight(null);
            }}
            onClick={() => {
              if (!open) {
                setQuery("");
                setOpen(true);
                setHighlight(null);
              }
            }}
            onBlur={close}
            onChange={(event) => {
              setQuery(event.target.value);
              setOpen(true);
              setHighlight(null);
            }}
            onKeyDown={(event) => {
              if (event.key === "ArrowDown" || event.key === "ArrowUp") {
                event.preventDefault();
                move(event.key === "ArrowDown" ? 1 : -1);
              } else if (event.key === "Enter" && isOpen) {
                event.preventDefault();
                choose(
                  highlight === null
                    ? matches.find(
                        (school) => school.school_status === "ACTIVE",
                      )
                    : highlighted,
                );
              } else if (event.key === "Escape" && isOpen) {
                event.preventDefault();
                event.stopPropagation();
                close();
              } else if (event.key === "Tab") close();
            }}
          />
        </Box>
      </Popover.Anchor>
      <Portal container={portal}>
        <Popover.Positioner>
          <Popover.Content
            id={`${id}-schools`}
            role="listbox"
            aria-label="Trường cần thêm hàng"
            bg="bg.workbench"
            color="fg.default"
            borderColor="border.strong"
            maxH="var(--atlas-layout-school-list-height, 260px)"
            overflowY="auto"
            maxW="var(--atlas-layout-school-max-width, calc(100vw - 32px))"
            p="xs"
          >
            {filtered.length > matches.length && (
              <Text role="status" p="sm" textStyle="helper" color="fg.muted">
                Hiển thị {matches.length} / {filtered.length} trường. Gõ thêm
                tên hoặc mã nội bộ.
              </Text>
            )}
            {!matches.length && (
              <Text role="status" p="sm">
                Không tìm thấy trường phù hợp.
              </Text>
            )}
            <Stack gap="var(--atlas-layout-zero, 0)">
              {matches.map((school) => (
                <Box
                  key={school.school_id}
                  id={`${id}-school-${school.school_id}`}
                  role="option"
                  aria-selected={value === school.school_id}
                  aria-disabled={school.school_status !== "ACTIVE"}
                  tabIndex={-1}
                  bg={
                    highlight === school.school_id
                      ? "bg.selected"
                      : "bg.workbench"
                  }
                  color={
                    school.school_status === "ACTIVE"
                      ? "fg.default"
                      : "fg.disabled"
                  }
                  p="sm"
                  minH="var(--atlas-layout-mobile-target, 44px)"
                  cursor="var(--atlas-layout-interactive-cursor, pointer)"
                  onPointerDown={(event) => event.preventDefault()}
                  onPointerMove={() => setHighlight(school.school_id)}
                  onClick={() => choose(school)}
                >
                  <Text fontWeight="medium">{school.school_name}</Text>
                  <Text textStyle="helper" color="fg.muted">
                    {school.default_delivery_location.location_name} ·{" "}
                    {school.school_code}
                    {school.school_status === "ACTIVE"
                      ? ""
                      : " · Ngừng hoạt động"}
                  </Text>
                </Box>
              ))}
            </Stack>
          </Popover.Content>
        </Popover.Positioner>
      </Portal>
    </Popover.Root>
  );
}
