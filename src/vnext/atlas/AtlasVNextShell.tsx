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

export function AtlasVNextShell({ children }: { children: ReactNode }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuId = useId();
  const toggleRef = useRef<HTMLButtonElement>(null);
  const closeMenu = () => {
    setMenuOpen(false);
    toggleRef.current?.focus();
  };

  return (
    <Flex
      minH="100dvh"
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
        <Text fontWeight="650" fontSize="20px">
          Atlas
        </Text>
        <Button
          ref={toggleRef}
          variant="utility"
          color="fg.inverse"
          aria-label="Mở điều hướng"
          aria-expanded={menuOpen}
          aria-controls={menuId}
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
        w={{ base: "full", lg: "224px" }}
        flexShrink="0"
        bg="bg.navigation"
        color="fg.inverse"
        display={{ base: menuOpen ? "block" : "none", lg: "block" }}
      >
        <Stack
          position={{ lg: "sticky" }}
          top="0"
          minH={{ lg: "100dvh" }}
          p="md"
          gap="lg"
        >
          <Box px="sm" pt="sm" hideBelow="lg">
            <Heading fontSize="28px" fontWeight="650">
              Atlas
            </Heading>
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
                  h="auto"
                  minH="44px"
                  px="sm"
                  py="sm"
                  my="2px"
                  variant="utility"
                  color="fg.inverse"
                  justifyContent="flex-start"
                  textAlign="left"
                  whiteSpace="normal"
                  fontSize="13px"
                  fontWeight={label === "Kế hoạch mua hàng" ? "600" : "400"}
                  bg={
                    label === "Kế hoạch mua hàng"
                      ? "bg.navigationHover"
                      : "transparent"
                  }
                  borderLeftWidth="3px"
                  borderLeftColor={
                    label === "Kế hoạch mua hàng"
                      ? "border.accent"
                      : "transparent"
                  }
                  aria-current={
                    label === "Kế hoạch mua hàng" ? "page" : undefined
                  }
                  _hover={{ bg: "bg.navigationHover", color: "fg.inverse" }}
                  _focusVisible={{ outlineColor: "focus.inverse" }}
                  onClick={closeMenu}
                >
                  <Icon asChild flexShrink="0" boxSize="18px">
                    <NavIcon />
                  </Icon>
                  {label}
                </Button>
              </Box>
            ))}
          </Box>
          <Text mt="auto" px="sm" textStyle="helper" color="fg.navMuted">
            Bản tham chiếu · Dữ liệu minh họa
          </Text>
        </Stack>
      </Box>
      <Box flex="1" minW="0">
        <Flex
          as="header"
          minH="52px"
          px={{ base: "md", lg: "lg" }}
          py="sm"
          bg="bg.workbench"
          borderBottomWidth="1px"
          borderColor="border.subtle"
          justify="space-between"
          gap="md"
          wrap="wrap"
        >
          <Text color="fg.primary" fontWeight="600">
            Vận hành trường học
          </Text>
          <Text textStyle="helper" color="fg.muted">
            Thứ năm, 10/09/2026
          </Text>
        </Flex>
        <Box as="main" minW="0" p={{ base: "sm", md: "md", xl: "lg" }}>
          {children}
        </Box>
      </Box>
    </Flex>
  );
}
