import {
  Box,
  Button,
  Field,
  Flex,
  Icon,
  Input,
  Stack,
  Text,
} from "@chakra-ui/react";
import { CaretDown, Circle, List, UserCircle, X } from "@phosphor-icons/react";
import {
  useEffect,
  useId,
  useRef,
  useState,
  type KeyboardEvent,
  type ReactNode,
} from "react";
import {
  atlasWorkbenches,
  type AtlasWorkbenchDefinition,
  type AtlasWorkbenchId,
} from "./AtlasWorkbenchRegistry";
import type { AtlasWorkbenchStatus } from "./AtlasModuleExit";
import { foldVietnameseSearch } from "./foldVietnameseSearch";
import { formatVietnamBusinessDate } from "./businessDate";

export type AtlasVNextModuleId = AtlasWorkbenchId;
type Destination = Pick<
  AtlasWorkbenchDefinition,
  "id" | "label" | "icon" | "group"
>;

export function AtlasVNextShell({
  children,
  activeModule = "procurement",
  openIds,
  statuses = {},
  onNavigate,
  onClose,
  mode = "reference",
  now = new Date(),
  userLabel,
  environmentLabel,
  onSignOut,
  prefix: suppliedPrefix,
  destinations = atlasWorkbenches,
}: {
  children: ReactNode;
  activeModule?: AtlasWorkbenchId | null;
  openIds?: readonly AtlasWorkbenchId[];
  statuses?: Partial<Record<AtlasWorkbenchId, AtlasWorkbenchStatus>>;
  onNavigate?: (id: AtlasWorkbenchId) => boolean | void;
  onClose?: (id: AtlasWorkbenchId) => void;
  mode?: "reference" | "connected";
  now?: Date;
  userLabel?: string;
  environmentLabel?: string;
  onSignOut?: () => void;
  prefix?: string;
  /** Capacity fixtures may supply descriptors; the production registry remains fixed. */
  destinations?: readonly Destination[];
}) {
  const ownId = useId();
  const prefix = suppliedPrefix ?? ownId;
  const ids = openIds ?? (activeModule ? [activeModule] : []);
  const [menu, setMenu] = useState<"launcher" | "open" | "account" | null>(
    null,
  );
  const [search, setSearch] = useState("");
  const [desktop, setDesktop] = useState(
    () => window.matchMedia?.("(min-width: 64rem)").matches ?? false,
  );
  const utilities = useRef<HTMLDivElement>(null);
  const openSwitcher = useRef<HTMLDivElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const strip = useRef<HTMLDivElement>(null);
  const tabBoxes = useRef(new Map<string, HTMLDivElement>());
  const label = (id: AtlasWorkbenchId) =>
    destinations.find((w) => w.id === id)?.label ?? id;
  const activeLabel = activeModule
    ? label(activeModule)
    : "Chưa mở bàn làm việc";
  const marker = (id: AtlasWorkbenchId) =>
    statuses[id]?.unsaved
      ? "Chưa lưu"
      : (statuses[id]?.attention ??
        (statuses[id]?.blocked ? "Cần giải quyết" : ""));
  const closeMenu = (restore = true) => {
    setMenu(null);
    if (restore) trigger.current?.focus();
  };
  const toggle = (next: typeof menu, button: HTMLButtonElement) => {
    trigger.current = button;
    setSearch("");
    setMenu(menu === next ? null : next);
  };
  const select = (id: AtlasWorkbenchId) => {
    if (onNavigate?.(id) === false) return;
    if (menu) closeMenu();
  };
  useEffect(() => {
    const media = window.matchMedia?.("(min-width: 64rem)");
    if (!media) return;
    const update = () => {
      setDesktop(media.matches);
      setMenu(null);
    };
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);
  useEffect(() => {
    if (!menu) return;
    if (menu === "launcher") searchInput.current?.focus();
    const dismiss = (event: PointerEvent) => {
      if (
        !utilities.current?.contains(event.target as Node) &&
        !openSwitcher.current?.contains(event.target as Node)
      )
        closeMenu(false);
    };
    document.addEventListener("pointerdown", dismiss);
    return () => document.removeEventListener("pointerdown", dismiss);
  }, [menu]);
  useEffect(() => {
    if (!activeModule || !desktop) return;
    const item = tabBoxes.current.get(activeModule),
      viewport = strip.current;
    if (!item || !viewport) return;
    const left = item.offsetLeft,
      right = left + item.offsetWidth;
    if (left < viewport.scrollLeft) viewport.scrollLeft = left;
    else if (right > viewport.scrollLeft + viewport.clientWidth)
      viewport.scrollLeft = right - viewport.clientWidth;
  }, [activeModule, ids.length, desktop]);
  const menuKeys = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Escape") {
      event.preventDefault();
      closeMenu();
      return;
    }
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;
    const buttons = Array.from(
      event.currentTarget.querySelectorAll<HTMLButtonElement>(
        "button[data-destination]",
      ),
    );
    if (!buttons.length) return;
    const current = buttons.indexOf(
      document.activeElement as HTMLButtonElement,
    );
    const index =
      event.key === "Home"
        ? 0
        : event.key === "End"
          ? buttons.length - 1
          : event.key === "ArrowDown"
            ? (current + 1) % buttons.length
            : current < 0
              ? buttons.length - 1
              : (current - 1 + buttons.length) % buttons.length;
    event.preventDefault();
    buttons[index]?.focus();
  };
  const tabKeys = (
    event: KeyboardEvent<HTMLButtonElement>,
    id: AtlasWorkbenchId,
  ) => {
    if (event.key === "Delete") {
      event.preventDefault();
      onClose?.(id);
      return;
    }
    if (event.key === "Tab" && !event.shiftKey) {
      const panel = document.getElementById(`${prefix}-panel-${id}`);
      if (panel) {
        event.preventDefault();
        panel.focus();
      }
      return;
    }
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    const current = ids.indexOf(id);
    const index =
      event.key === "Home"
        ? 0
        : event.key === "End"
          ? ids.length - 1
          : event.key === "ArrowRight"
            ? (current + 1) % ids.length
            : (current - 1 + ids.length) % ids.length;
    const next = ids[index];
    event.preventDefault();
    if (next && onNavigate?.(next) !== false)
      document.getElementById(`${prefix}-tab-${next}`)?.focus();
  };
  const matches = destinations.filter((w) =>
    foldVietnameseSearch(w.label).includes(foldVietnameseSearch(search.trim())),
  );
  const popup = {
    position: "absolute",
    top: "var(--atlas-workspace-popup-top, 100%)",
    zIndex: "dropdown",
    bg: "bg.workbench",
    color: "fg.default",
    borderWidth: "var(--atlas-layout-edge, 1px)",
    borderColor: "border.default",
    borderRadius: "workbench",
    boxShadow: "md",
    p: "sm",
    w: "var(--atlas-workspace-launcher-width, min(440px, calc(100vw - 20px)))",
    maxH: "var(--atlas-workspace-menu-height, calc(100dvh - 120px))",
    overflowY: "auto",
  } as const;
  return (
    <Flex
      h="var(--atlas-layout-viewport-height, 100dvh)"
      direction="column"
      bg="bg.workspace"
      minW="var(--atlas-layout-zero, 0)"
    >
      <Flex
        as="header"
        ref={utilities}
        position="relative"
        minH="var(--atlas-workspace-utility-height, 52px)"
        px="sm"
        gap="sm"
        align="center"
        bg="bg.navigation"
        color="fg.inverse"
        onKeyDown={(event) => {
          if (event.key === "Escape" && menu) {
            event.preventDefault();
            closeMenu();
          }
        }}
        onBlurCapture={(event) => {
          if (
            menu &&
            event.relatedTarget &&
            !event.currentTarget.contains(event.relatedTarget as Node)
          )
            closeMenu(false);
        }}
      >
        <Button
          id={`${prefix}-launcher`}
          variant="utility"
          color="fg.inverse"
          minH="var(--atlas-layout-mobile-target, 44px)"
          minW="var(--atlas-layout-mobile-target, 44px)"
          p="sm"
          aria-label="Bàn làm việc"
          title="Bàn làm việc"
          aria-haspopup="dialog"
          aria-expanded={menu === "launcher"}
          aria-controls={`${prefix}-launcher-menu`}
          _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
          _focusVisible={{ outlineColor: "focus.inverse" }}
          onClick={(event) => toggle("launcher", event.currentTarget)}
        >
          <List size={22} aria-hidden="true" />
        </Button>
        <Text textStyle="brandCompact" flexShrink="0" color="fg.navBrand">
          ATLAS
        </Text>
        <Flex
          flex="1"
          justify="flex-end"
          align="center"
          gap="sm"
          minW="var(--atlas-layout-zero, 0)"
        >
          {desktop && (
            <Text textStyle="helper" color="fg.navMuted">
              Hôm nay:{" "}
              {formatVietnamBusinessDate(now).replace(/^Hôm nay: /, "")}
            </Text>
          )}
          <Button
            variant="utility"
            color="fg.inverse"
            minH="var(--atlas-layout-mobile-target, 44px)"
            minW="var(--atlas-layout-mobile-target, 44px)"
            p="sm"
            aria-label="Tài khoản và môi trường"
            aria-haspopup="dialog"
            aria-expanded={menu === "account"}
            aria-controls={`${prefix}-account-menu`}
            _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
            _focusVisible={{ outlineColor: "focus.inverse" }}
            onClick={(event) => toggle("account", event.currentTarget)}
          >
            <UserCircle size={22} aria-hidden="true" />
            {desktop && "Tài khoản"}
            <CaretDown aria-hidden="true" />
          </Button>
        </Flex>
        {menu === "launcher" && (
          <Box
            {...popup}
            left="sm"
            id={`${prefix}-launcher-menu`}
            role="dialog"
            aria-label="Bàn làm việc"
            onKeyDown={menuKeys}
          >
            <Text fontWeight="semibold" px="sm" pb="sm">
              Bàn làm việc
            </Text>
            <Field.Root mb="sm">
              <Field.Label>Tìm bàn làm việc</Field.Label>
              <Input
                ref={searchInput}
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Tên công việc…"
              />
            </Field.Root>
            {(["CÔNG VIỆC HẰNG NGÀY", "DỮ LIỆU & CẤU HÌNH"] as const).map(
              (group) => {
                const items = matches.filter((w) => w.group === group);
                return (
                  items.length > 0 && (
                    <Box key={group} mb="sm">
                      <Text textStyle="helper" color="fg.muted" px="sm" py="xs">
                        {group}
                      </Text>
                      <Stack gap="xs">
                        {items.map(
                          ({ id, label: name, icon: WorkbenchIcon }) => (
                            <Button
                              key={id}
                              data-destination=""
                              variant="utility"
                              justifyContent="flex-start"
                              textAlign="left"
                              h="var(--atlas-layout-auto, auto)"
                              minH="var(--atlas-layout-mobile-target, 44px)"
                              whiteSpace="normal"
                              aria-label={name}
                              aria-current={
                                id === activeModule ? "page" : undefined
                              }
                              onClick={() => select(id)}
                            >
                              <Icon asChild flexShrink="0" boxSize="20px">
                                <WorkbenchIcon
                                  data-testid={
                                    id === "procurement"
                                      ? "procurement-nav-icon"
                                      : undefined
                                  }
                                  data-icon={
                                    id === "procurement"
                                      ? "shopping-cart"
                                      : undefined
                                  }
                                />
                              </Icon>
                              <Text flex="1">{name}</Text>
                              {ids.includes(id) && (
                                <Text textStyle="helper" color="fg.muted">
                                  Đang mở
                                </Text>
                              )}
                            </Button>
                          ),
                        )}
                      </Stack>
                    </Box>
                  )
                );
              },
            )}
            {!matches.length && (
              <Text role="status" p="sm">
                Không tìm thấy bàn làm việc. Thử tên công việc khác.
              </Text>
            )}
          </Box>
        )}
        {menu === "account" && (
          <Box
            {...popup}
            right="sm"
            id={`${prefix}-account-menu`}
            role="dialog"
            aria-label="Tài khoản và môi trường"
          >
            <Text
              textStyle="body"
              fontWeight="semibold"
              overflowWrap="anywhere"
            >
              {userLabel ?? "Atlas"}
            </Text>
            <Text
              textStyle="helper"
              color="fg.muted"
              mt="xs"
              overflowWrap="anywhere"
            >
              {mode === "reference"
                ? "Bản tham chiếu · Dữ liệu minh họa"
                : `Môi trường · ${environmentLabel ?? "Atlas"}`}
            </Text>
            {onSignOut && (
              <Button
                variant="secondary"
                mt="md"
                onClick={() => {
                  closeMenu();
                  onSignOut();
                }}
              >
                Đăng xuất
              </Button>
            )}
          </Box>
        )}
      </Flex>
      {desktop ? (
        <Box
          ref={strip}
          role="tablist"
          aria-label="Bàn làm việc đang mở"
          overflowX="auto"
          minW="var(--atlas-layout-zero, 0)"
          maxW="full"
          position="relative"
          bg="bg.toolbar"
          px="sm"
          pt="xs"
        >
          <Flex
            w="var(--atlas-workspace-tab-content-width, max-content)"
            minW="full"
            gap="xs"
          >
            {ids.map((id) => (
              <Flex
                key={id}
                ref={(node) => {
                  if (node) tabBoxes.current.set(id, node);
                  else tabBoxes.current.delete(id);
                }}
                align="center"
                bg={id === activeModule ? "bg.workbench" : "transparent"}
                borderTopRadius="workbench"
                borderBottomWidth="var(--atlas-workspace-selected-edge, 3px)"
                borderBottomColor={
                  id === activeModule ? "border.accent" : "transparent"
                }
              >
                <Button
                  id={`${prefix}-tab-${id}`}
                  role="tab"
                  aria-selected={id === activeModule}
                  aria-controls={`${prefix}-panel-${id}`}
                  aria-description={
                    marker(id) || "Nhấn Delete để đóng bàn làm việc"
                  }
                  aria-keyshortcuts="Delete"
                  tabIndex={id === activeModule ? 0 : -1}
                  variant="utility"
                  color={id === activeModule ? "fg.default" : "fg.secondary"}
                  fontWeight={id === activeModule ? "semibold" : "normal"}
                  borderRadius="var(--atlas-layout-zero, 0)"
                  onClick={() => select(id)}
                  onKeyDown={(event) => tabKeys(event, id)}
                >
                  {label(id)}
                  {marker(id) && (
                    <Box
                      as="span"
                      aria-label={marker(id)}
                      color={
                        statuses[id]?.unsaved || statuses[id]?.attention
                          ? "fg.attention"
                          : "status.danger"
                      }
                      title={marker(id)}
                    >
                      <Icon
                        asChild
                        boxSize="var(--atlas-workspace-marker-size, 6px)"
                      >
                        <Circle weight="fill" aria-hidden="true" />
                      </Icon>
                    </Box>
                  )}
                </Button>
                <Button
                  variant="utility"
                  aria-label={`Đóng ${label(id)}`}
                  title={`Đóng ${label(id)}`}
                  tabIndex={-1}
                  minW="compact"
                  h="compact"
                  p="xs"
                  onClick={() => onClose?.(id)}
                >
                  <X size={16} aria-hidden="true" />
                </Button>
              </Flex>
            ))}
          </Flex>
        </Box>
      ) : (
        <Box
          position="relative"
          bg="bg.toolbar"
          px="sm"
          py="xs"
          ref={openSwitcher}
        >
          <Button
            id={`${prefix}-open-trigger`}
            variant="secondary"
            w="full"
            justifyContent="space-between"
            minH="var(--atlas-layout-mobile-target, 44px)"
            h="var(--atlas-layout-auto, auto)"
            py="sm"
            whiteSpace="normal"
            textAlign="left"
            aria-haspopup="dialog"
            aria-expanded={menu === "open"}
            onClick={(event) => toggle("open", event.currentTarget)}
          >
            <Text flex="1">
              Đang mở: {activeLabel}
              {activeModule && marker(activeModule)
                ? ` — ${marker(activeModule)}`
                : ""}
            </Text>
            <CaretDown aria-hidden="true" />
          </Button>
          {menu === "open" && (
            <Box
              {...popup}
              left="sm"
              role="dialog"
              aria-label="Bàn làm việc đang mở"
              onKeyDown={menuKeys}
            >
              <Stack gap="xs">
                {ids.map((id) => (
                  <Flex key={id} gap="xs" align="center">
                    <Button
                      data-destination=""
                      flex="1"
                      variant={id === activeModule ? "secondary" : "utility"}
                      minH="var(--atlas-layout-mobile-target, 44px)"
                      h="var(--atlas-layout-auto, auto)"
                      py="sm"
                      whiteSpace="normal"
                      textAlign="left"
                      justifyContent="flex-start"
                      aria-current={id === activeModule ? "page" : undefined}
                      onClick={() => select(id)}
                    >
                      {label(id)}
                      {marker(id) ? ` — ${marker(id)}` : ""}
                    </Button>
                    <Button
                      variant="utility"
                      aria-label={`Đóng ${label(id)}`}
                      minH="var(--atlas-layout-mobile-target, 44px)"
                      minW="var(--atlas-layout-mobile-target, 44px)"
                      onClick={() => {
                        closeMenu(false);
                        onClose?.(id);
                      }}
                    >
                      <X aria-hidden="true" />
                    </Button>
                  </Flex>
                ))}
                {!ids.length && <Text>Chưa có bàn làm việc đang mở.</Text>}
              </Stack>
            </Box>
          )}
        </Box>
      )}
      <Box
        as="main"
        display="flex"
        flexDirection="column"
        minH="var(--atlas-layout-zero, 0)"
        overflow="auto"
        minW="var(--atlas-layout-zero, 0)"
        flex="1"
        p="sm"
      >
        {children}
      </Box>
    </Flex>
  );
}
