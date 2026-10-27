import { Box, Input, Popover, Portal, Stack, Text } from "@chakra-ui/react";
import {
  useEffect,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  useAtlasPortalContainer,
  useAtlasWorkbenchActive,
} from "../AtlasVNextProvider";
import type { PantryIngredient } from "../bridges/planning";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import {
  operatorMasterReference,
  operatorUnitLabel,
} from "../masterDataPresentation";

/** Query text is local presentation. Only an explicit result selection authors a UUID. */
export function PantryIngredientChooser({
  label,
  ingredients,
  value,
  disabled,
  invalid,
  onChange,
}: {
  label: string;
  ingredients: PantryIngredient[];
  value: string;
  disabled?: boolean;
  invalid?: boolean;
  onChange: (id: string) => void;
}) {
  const id = useId();
  const input = useRef<HTMLInputElement>(null);
  const previousValue = useRef(value);
  const portal = useAtlasPortalContainer();
  const activeWorkbench = useAtlasWorkbenchActive();
  const selected = ingredients.find((item) => item.ingredient_id === value);
  const [query, setQuery] = useState(selected?.ingredient_name ?? "");
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState<string | null>(null);
  const filtered = useMemo(() => {
    const search = foldVietnameseSearch(query.trim());
    return ingredients.filter((item) =>
      foldVietnameseSearch(
        `${item.ingredient_name} ${item.ingredient_code}`,
      ).includes(search),
    );
  }, [ingredients, query]);
  // Search always covers the entire catalog. Bound rendered suggestions so
  // opening the input does not mount hundreds of interactive rows at once.
  const matches = filtered.slice(0, 40);
  const isOpen = open && activeWorkbench && !disabled;
  useEffect(() => {
    if (previousValue.current === value) return;
    previousValue.current = value;
    setQuery(
      ingredients.find((item) => item.ingredient_id === value)
        ?.ingredient_name ?? "",
    );
    setOpen(false);
    setHighlight(null);
  }, [ingredients, value]);
  useLayoutEffect(() => {
    if (!activeWorkbench || disabled) {
      setOpen(false);
      setHighlight(null);
      setQuery(selected?.ingredient_name ?? "");
    }
  }, [activeWorkbench, disabled, selected?.ingredient_name]);
  useLayoutEffect(() => {
    if (isOpen && highlight)
      document
        .getElementById(`${id}-option-${highlight}`)
        ?.scrollIntoView?.({ block: "nearest" });
  }, [highlight, isOpen, id]);
  const close = () => {
    setOpen(false);
    setQuery(selected?.ingredient_name ?? "");
    setHighlight(null);
  };
  const choose = (item: PantryIngredient | undefined) => {
    if (!item || disabled || item.ingredient_status !== "ACTIVE") return;
    setQuery(item.ingredient_name);
    setOpen(false);
    setHighlight(null);
    onChange(item.ingredient_id);
  };
  const move = (direction: 1 | -1) => {
    setOpen(true);
    const current = matches.findIndex(
      (item) => item.ingredient_id === highlight,
    );
    const from = current < 0 && direction === -1 ? 0 : current;
    for (let offset = 1; offset <= matches.length; offset++) {
      const index =
        (from + direction * offset + matches.length) % matches.length;
      if (matches[index]?.ingredient_status === "ACTIVE") {
        setHighlight(matches[index]!.ingredient_id);
        return;
      }
    }
  };
  const highlighted = matches.find((item) => item.ingredient_id === highlight);
  return (
    <Popover.Root
      open={isOpen}
      onOpenChange={({ open: next }) => {
        if (!next) close();
      }}
      autoFocus={false}
      onInteractOutside={(event) => {
        if (event.target === input.current) event.preventDefault();
      }}
      positioning={{ placement: "bottom-start", sameWidth: true }}
      lazyMount
      unmountOnExit
    >
      <Popover.Anchor asChild>
        <Box minW="var(--atlas-layout-zero, 0)">
          <Input
            ref={input}
            role="combobox"
            aria-label={label}
            aria-autocomplete="list"
            aria-expanded={isOpen}
            aria-controls={`${id}-results`}
            aria-invalid={invalid}
            aria-activedescendant={
              isOpen && highlighted ? `${id}-option-${highlight}` : undefined
            }
            disabled={disabled}
            value={query}
            placeholder="Gõ tên hoặc mã nội bộ…"
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
                        (item) => item.ingredient_status === "ACTIVE",
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
            id={`${id}-results`}
            role="listbox"
            aria-label={label}
            bg="bg.workbench"
            color="fg.default"
            borderColor="border.strong"
            maxH="var(--atlas-pantry-ingredient-results-height, 280px)"
            overflowY="auto"
            maxW="var(--atlas-pantry-ingredient-results-width, calc(100vw - 24px))"
            p="xs"
          >
            {filtered.length > matches.length && (
              <Text role="status" p="sm" textStyle="helper" color="fg.muted">
                Hiển thị {matches.length} / {filtered.length} kết quả. Gõ thêm
                tên hoặc mã nội bộ để tìm chính xác.
              </Text>
            )}
            {!matches.length && (
              <Text role="status" p="sm">
                Không tìm thấy nguyên liệu phù hợp.
              </Text>
            )}
            <Stack gap="var(--atlas-layout-zero, 0)">
              {matches.map((item) => (
                <Box
                  key={item.ingredient_id}
                  id={`${id}-option-${item.ingredient_id}`}
                  role="option"
                  aria-selected={value === item.ingredient_id}
                  aria-disabled={item.ingredient_status !== "ACTIVE"}
                  tabIndex={-1}
                  bg={
                    highlight === item.ingredient_id
                      ? "bg.selected"
                      : "bg.workbench"
                  }
                  color={
                    item.ingredient_status === "ACTIVE"
                      ? "fg.default"
                      : "fg.disabled"
                  }
                  p="sm"
                  minH="var(--atlas-layout-mobile-target, 44px)"
                  cursor={
                    item.ingredient_status === "ACTIVE"
                      ? "var(--atlas-layout-interactive-cursor, pointer)"
                      : "var(--atlas-layout-disabled-cursor, not-allowed)"
                  }
                  onMouseDown={(event) => event.preventDefault()}
                  onPointerMove={() => setHighlight(item.ingredient_id)}
                  onClick={() => choose(item)}
                >
                  <Text fontWeight="medium">{item.ingredient_name}</Text>
                  <Text textStyle="helper" color="fg.muted">
                    {operatorUnitLabel(item.purchase_unit)}
                    {operatorMasterReference(item.ingredient_code)
                      ? ` · ${item.ingredient_code}`
                      : ""}
                    {item.ingredient_status === "ACTIVE"
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
