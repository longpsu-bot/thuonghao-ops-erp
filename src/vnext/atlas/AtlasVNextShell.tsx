import {
  Box,
  Button,
  Flex,
  Drawer,
  Heading,
  Icon,
  Stack,
  Text,
} from "@chakra-ui/react";
import {
  List,
  Package,
  ClipboardText,
  Buildings,
  CookingPot,
  Truck,
  Scales,
  ShoppingCart,
  X,
} from "@phosphor-icons/react";
import { formatVietnamBusinessDate } from "./businessDate";
import { useEffect, useId, useRef, useState, type ReactNode } from "react";

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
  const menuId = useId();
  const [desktop, setDesktop] = useState(
    () => window.matchMedia?.("(min-width: 64rem)").matches ?? false,
  );
  useEffect(() => {
    const media = window.matchMedia?.("(min-width: 64rem)");
    if (!media) return;
    const update = () => {
      setDesktop(media.matches);
      if (media.matches) setMenuOpen(false);
    };
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const closeMenu = () => {
    setMenuOpen(false);
    toggleRef.current?.focus();
  };

  const sidebar = (
    <Stack
      position={{ lg: "sticky" }}
      top="var(--atlas-layout-zero, 0)"
      minH={{ lg: "var(--atlas-layout-viewport-height, 100dvh)" }}
      p="md"
      gap="lg"
    >
      <Box px="sm" pt="sm" hideBelow="lg">
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
                onClick={() => {
                  onNavigate?.(id);
                  if (menuOpen) closeMenu();
                }}
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
      <Flex
        hideFrom="lg"
        p="sm"
        bg="bg.navigation"
        color="fg.inverse"
        align="center"
        justify="space-between"
      >
        <Text textStyle="brandCompact">Atlas</Text>
        <Button
          ref={toggleRef}
          variant="utility"
          color="fg.inverse"
          aria-label="Mở điều hướng"
          aria-expanded={menuOpen}
          aria-controls={menuId}
          _focusVisible={{ outlineColor: "focus.inverse" }}
          onClick={() => setMenuOpen(!menuOpen)}
        >
          <Icon asChild boxSize="20px">
            {menuOpen ? <X /> : <List />}
          </Icon>
          Danh mục
        </Button>
      </Flex>
      {desktop || !onNavigate ? (
        <Box
          as="aside"
          w={{ base: "full", lg: "var(--atlas-layout-sidebar-width, 224px)" }}
          flexShrink="0"
          bg="bg.navigation"
          color="fg.inverse"
          display={{ base: menuOpen ? "block" : "none", lg: "block" }}
        >
          {sidebar}
        </Box>
      ) : (
        <Drawer.Root
          open={menuOpen}
          onOpenChange={({ open }) => {
            if (!open) closeMenu();
          }}
          placement="start"
          finalFocusEl={() => toggleRef.current}
          lazyMount
          unmountOnExit
        >
          <Drawer.Backdrop style={{ animation: "none" }} />
          <Drawer.Positioner>
            <Drawer.Content
              style={{ animation: "none" }}
              bg="bg.navigation"
              color="fg.inverse"
              maxW="var(--atlas-layout-mobile-nav-width, 300px)"
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
                {sidebar}
              </Drawer.Body>
            </Drawer.Content>
          </Drawer.Positioner>
        </Drawer.Root>
      )}
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
