import {
  Box,
  Button,
  Flex,
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
  X,
} from "@phosphor-icons/react";
import { useId, useRef, useState, type ReactNode } from "react";

const navigation = [
  { label: "Trường học", icon: Buildings, group: "Dữ liệu gốc" },
  { label: "Nguyên liệu và Nhà cung ứng", icon: Package },
  { label: "Công thức", icon: CookingPot },
  { label: "Lập nhu cầu", icon: ClipboardText, group: "Công việc hằng ngày" },
  { label: "Kế hoạch mua hàng", icon: Package },
  { label: "Phiếu xuất kho", icon: Truck },
  { label: "Đối chiếu PO / Phiếu xuất kho", icon: Scales },
];

export function AtlasVNextShell({
  children,
  activeModule = "Kế hoạch mua hàng",
}: {
  children: ReactNode;
  activeModule?:
    | "Trường học"
    | "Kế hoạch mua hàng"
    | "Lập nhu cầu"
    | "Phiếu xuất kho"
    | "Đối chiếu PO / Phiếu xuất kho";
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuId = useId();
  const toggleRef = useRef<HTMLButtonElement>(null);
  const closeMenu = () => {
    setMenuOpen(false);
    toggleRef.current?.focus();
  };

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
      <Box
        as="aside"
        w={{ base: "full", lg: "var(--atlas-layout-sidebar-width, 224px)" }}
        flexShrink="0"
        bg="bg.navigation"
        color="fg.inverse"
        display={{ base: menuOpen ? "block" : "none", lg: "block" }}
      >
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
            {navigation.map(({ label, icon: NavIcon, group }) => (
              <Box key={label}>
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
                  fontWeight={label === activeModule ? "semibold" : "normal"}
                  bg={
                    label === activeModule
                      ? "bg.navigationHover"
                      : "transparent"
                  }
                  borderLeftWidth="var(--atlas-layout-rail, 3px)"
                  borderLeftColor={
                    label === activeModule ? "border.accent" : "transparent"
                  }
                  aria-current={label === activeModule ? "page" : undefined}
                  _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
                  _focusVisible={{ outlineColor: "focus.inverse" }}
                  onClick={closeMenu}
                >
                  <Icon asChild flexShrink="0" boxSize="18px">
                    <NavIcon
                      weight={label === activeModule ? "bold" : "regular"}
                    />
                  </Icon>
                  {label}
                </Button>
              </Box>
            ))}
          </Box>
          <Text
            mt="var(--atlas-layout-auto, auto)"
            px="sm"
            textStyle="helper"
            color="fg.navMuted"
          >
            Bản tham chiếu · Dữ liệu minh họa
          </Text>
        </Stack>
      </Box>
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
          <Text color="fg.primary" fontWeight="semibold">
            Vận hành trường học
          </Text>
          <Text textStyle="helper" color="fg.muted">
            Thứ năm, 10/09/2026
          </Text>
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
