import {
  Box,
  Button,
  Drawer,
  Flex,
  Heading,
  Icon,
  Stack,
  Text,
} from "@chakra-ui/react";
import {
  Buildings,
  ClipboardText,
  CookingPot,
  List,
  Package,
  Scales,
  ShoppingCart,
  Truck,
  X,
} from "@phosphor-icons/react";
import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import { formatVietnamBusinessDate } from "./businessDate";

const navigation = [
  { id: "schools", label: "Trường học", icon: Buildings, group: "Dữ liệu gốc" },
  {
    id: "ingredients-suppliers",
    label: "Nguyên liệu và Nhà cung ứng",
    icon: Package,
  },
  { id: "recipes", label: "Công thức", icon: CookingPot },
  {
    id: "planning",
    label: "Lập nhu cầu",
    icon: ClipboardText,
    group: "Công việc hằng ngày",
  },
  { id: "procurement", label: "Kế hoạch mua hàng", icon: ShoppingCart },
  { id: "pxk", label: "Phiếu xuất kho", icon: Truck },
  {
    id: "reconciliation",
    label: "Đối chiếu PO / Phiếu xuất kho",
    icon: Scales,
  },
] as const;

export type AtlasVNextModuleId = (typeof navigation)[number]["id"];

function RailTooltip({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Box
      position="relative"
      onPointerEnter={() => setOpen(true)}
      onPointerLeave={() => setOpen(false)}
      onFocusCapture={() => setOpen(true)}
      onBlurCapture={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null))
          setOpen(false);
      }}
    >
      {children}
      {open && (
        <Box
          role="tooltip"
          position="absolute"
          style={{
            left: "calc(100% + var(--atlas-spacing-xs))",
            top: "50%",
          }}
          transform="translateY(-50%)"
          zIndex="tooltip"
          px="sm"
          py="xs"
          borderRadius="control"
          bg="bg.navigation"
          color="fg.inverse"
          borderWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.subtle"
          textStyle="helper"
          fontWeight="semibold"
          whiteSpace="nowrap"
          pointerEvents="none"
        >
          {label}
        </Box>
      )}
    </Box>
  );
}

export function AtlasVNextShell({
  children,
  activeModule = "procurement",
  onNavigate,
  mode = "reference",
  now = new Date(),
  userLabel,
  environmentLabel,
  onSignOut,
}: {
  children: ReactNode;
  activeModule?: AtlasVNextModuleId;
  onNavigate?: (module: AtlasVNextModuleId) => void;
  mode?: "reference" | "connected";
  now?: Date;
  userLabel?: string;
  environmentLabel?: string;
  onSignOut?: () => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [desktop, setDesktop] = useState(
    () => window.matchMedia?.("(min-width: 64rem)").matches ?? false,
  );
  const menuId = useId();
  const lastTrigger = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    const media = window.matchMedia?.("(min-width: 64rem)");
    if (!media) return;
    const update = () => {
      setDesktop(media.matches);
      setMenuOpen(false);
    };
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  const openMenu = (trigger: HTMLButtonElement) => {
    lastTrigger.current = trigger;
    setMenuOpen(true);
  };
  const closeMenu = () => setMenuOpen(false);
  const navigate = (id: AtlasVNextModuleId, fromDrawer = false) => {
    onNavigate?.(id);
    if (fromDrawer) closeMenu();
  };

  const fullMenu = (
    <Stack minH="full" p="md" gap="lg">
      <Box px="sm" pt="sm">
        <Heading textStyle="brand">Atlas</Heading>
        <Text textStyle="helper" color="fg.navMuted" mt="xs">
          Thượng Hảo · Điều hành cung ứng
        </Text>
      </Box>
      <Box
        as="nav"
        id={menuId}
        aria-label="Điều hướng Atlas"
        onKeyDown={(event) => {
          if (event.key === "Escape") closeMenu();
        }}
      >
        {navigation.map((item) => {
          const { id, label, icon: NavIcon } = item;
          const group = "group" in item ? item.group : undefined;
          return (
            <Box key={id}>
              {group && (
                <Text
                  textStyle="helper"
                  color="fg.navMuted"
                  mt="md"
                  mb="xs"
                  px="sm"
                >
                  {group}
                </Text>
              )}
              <Button
                w="full"
                h="var(--atlas-layout-auto, auto)"
                minH="var(--atlas-layout-nav-height, 44px)"
                px="sm"
                py="sm"
                my="0.5"
                variant="utility"
                color="fg.inverse"
                justifyContent="flex-start"
                textAlign="left"
                whiteSpace="normal"
                textStyle="table"
                fontWeight={id === activeModule ? "semibold" : "normal"}
                bg={id === activeModule ? "bg.navigationHover" : "transparent"}
                borderLeftWidth="var(--atlas-layout-rail, 3px)"
                borderLeftColor={
                  id === activeModule ? "border.accent" : "transparent"
                }
                aria-current={id === activeModule ? "page" : undefined}
                _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
                _focusVisible={{ outlineColor: "focus.inverse" }}
                onClick={() => navigate(id, true)}
              >
                <Icon asChild flexShrink="0" boxSize="18px">
                  <NavIcon
                    weight={id === activeModule ? "bold" : "regular"}
                    data-testid={
                      id === "procurement" ? "procurement-nav-icon" : undefined
                    }
                    data-icon={
                      id === "procurement" ? "shopping-cart" : undefined
                    }
                  />
                </Icon>
                {label}
              </Button>
            </Box>
          );
        })}
      </Box>
      <Text
        mt="var(--atlas-layout-auto, auto)"
        px="sm"
        textStyle="helper"
        color="fg.navMuted"
      >
        {mode === "reference"
          ? "Bản tham chiếu · Dữ liệu minh họa"
          : environmentLabel
            ? `Môi trường · ${environmentLabel}`
            : "Atlas"}
      </Text>
    </Stack>
  );

  return (
    <Flex
      minH="var(--atlas-layout-viewport-height, 100dvh)"
      direction={{ base: "column", lg: "row" }}
      bg="bg.workspace"
    >
      {!desktop && (
        <Flex
          p="sm"
          bg="bg.navigation"
          color="fg.inverse"
          align="center"
          justify="space-between"
        >
          <Text textStyle="brandCompact">Atlas</Text>
          <Button
            variant="utility"
            color="fg.inverse"
            aria-label="Mở điều hướng Atlas"
            aria-expanded={menuOpen}
            aria-controls={menuId}
            _focusVisible={{ outlineColor: "focus.inverse" }}
            onClick={(event) =>
              menuOpen ? closeMenu() : openMenu(event.currentTarget)
            }
          >
            <Icon asChild boxSize="20px">
              {menuOpen ? <X /> : <List />}
            </Icon>
            Danh mục
          </Button>
        </Flex>
      )}

      {desktop && (
        <Flex
          as="aside"
          aria-label="Điều hướng nhanh Atlas"
          position="sticky"
          top="var(--atlas-layout-zero, 0)"
          w="var(--atlas-layout-nav-rail-width, 72px)"
          h="var(--atlas-layout-viewport-height, 100dvh)"
          flexShrink="0"
          direction="column"
          align="center"
          bg="bg.navigation"
          color="fg.inverse"
          py="sm"
          gap="sm"
        >
          <Flex
            minH="var(--atlas-layout-nav-brand-height, 58px)"
            align="center"
            justify="center"
            aria-label="Atlas"
          >
            <Text textStyle="brandCompact">A</Text>
          </Flex>
          <RailTooltip label="Mở điều hướng Atlas">
            <Button
              variant="utility"
              color="fg.inverse"
              w="var(--atlas-layout-mobile-target, 44px)"
              h="var(--atlas-layout-mobile-target, 44px)"
              minW="var(--atlas-layout-mobile-target, 44px)"
              p="var(--atlas-layout-zero, 0)"
              aria-label="Mở điều hướng Atlas"
              aria-expanded={menuOpen}
              aria-controls={menuId}
              _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
              _focusVisible={{ outlineColor: "focus.inverse" }}
              onClick={(event) => openMenu(event.currentTarget)}
            >
              <List size={20} />
            </Button>
          </RailTooltip>
          <Stack
            as="nav"
            aria-label="Điều hướng mô-đun Atlas"
            gap="xs"
            align="center"
          >
            {navigation.map(({ id, label, icon: NavIcon }) => (
              <RailTooltip key={id} label={label}>
                <Button
                  variant="utility"
                  color="fg.inverse"
                  w="var(--atlas-layout-mobile-target, 44px)"
                  h="var(--atlas-layout-mobile-target, 44px)"
                  minW="var(--atlas-layout-mobile-target, 44px)"
                  p="var(--atlas-layout-zero, 0)"
                  aria-label={label}
                  aria-current={id === activeModule ? "page" : undefined}
                  bg={
                    id === activeModule ? "bg.navigationHover" : "transparent"
                  }
                  borderLeftWidth="var(--atlas-layout-rail, 3px)"
                  borderLeftColor={
                    id === activeModule ? "border.accent" : "transparent"
                  }
                  _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
                  _focusVisible={{ outlineColor: "focus.inverse" }}
                  onClick={() => navigate(id)}
                >
                  <NavIcon
                    size={20}
                    weight={id === activeModule ? "bold" : "regular"}
                    data-testid={
                      id === "procurement" ? "procurement-nav-icon" : undefined
                    }
                    data-icon={
                      id === "procurement" ? "shopping-cart" : undefined
                    }
                  />
                </Button>
              </RailTooltip>
            ))}
          </Stack>
        </Flex>
      )}

      <Drawer.Root
        open={menuOpen}
        onOpenChange={({ open }) => {
          if (!open) closeMenu();
        }}
        placement="start"
        finalFocusEl={() => lastTrigger.current}
        lazyMount
        unmountOnExit
      >
        <Drawer.Backdrop style={{ animation: "none" }} />
        <Drawer.Positioner>
          <Drawer.Content
            style={{ animation: "none" }}
            bg="bg.navigation"
            color="fg.inverse"
            w="var(--atlas-layout-nav-drawer-width, 272px)"
            maxW="var(--atlas-layout-mobile-nav-width, calc(100vw - 32px))"
          >
            <Drawer.Header>
              <Drawer.Title>Điều hướng Atlas</Drawer.Title>
              <Button
                variant="utility"
                color="fg.inverse"
                onClick={closeMenu}
                aria-label="Đóng điều hướng"
              >
                <X />
              </Button>
            </Drawer.Header>
            <Drawer.Body p="var(--atlas-layout-zero, 0)">
              {fullMenu}
            </Drawer.Body>
          </Drawer.Content>
        </Drawer.Positioner>
      </Drawer.Root>

      <Box flex="1" minW="var(--atlas-layout-zero, 0)">
        <Flex
          as="header"
          minH="var(--atlas-layout-header-height, 52px)"
          px={{ base: "md", lg: "lg" }}
          py="sm"
          bg="bg.workbench"
          borderBottomWidth="var(--atlas-layout-edge, 1px)"
          borderColor="border.subtle"
          justify="space-between"
          gap="md"
          wrap="wrap"
        >
          <Text textStyle="helper" color="fg.muted">
            {mode === "reference"
              ? "Hôm nay: 10/09/2026"
              : formatVietnamBusinessDate(now)}
          </Text>
          {mode === "connected" && (
            <Flex align="center" gap="sm" wrap="wrap">
              <Text textStyle="helper">{userLabel}</Text>
              {onSignOut && (
                <Button variant="utility" onClick={onSignOut}>
                  Đăng xuất
                </Button>
              )}
            </Flex>
          )}
        </Flex>
        <Box
          as="main"
          minW="var(--atlas-layout-zero, 0)"
          p={{ base: "sm", md: "md", xl: "lg" }}
        >
          {children}
        </Box>
      </Box>
    </Flex>
  );
}
