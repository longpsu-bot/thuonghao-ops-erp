import {
  Badge,
  Box,
  Button,
  Field,
  Flex,
  Grid,
  Heading,
  Icon,
  Input,
  NativeSelect,
  Separator,
  Stack,
  Table,
  Text,
} from "@chakra-ui/react";
import { Check, Info, Warning } from "@phosphor-icons/react";
import { useEffect, useRef, useState } from "react";
import { AtlasRefreshButton } from "./AtlasRefreshButton";

export type ReferenceScenario =
  "normal" | "blocker" | "empty" | "loading" | "unknown";

const rows = [
  {
    name: "Gạo thơm",
    school: "Tiểu học Nguyễn Du",
    quantity: "120,000000",
    unit: "kg",
    status: "Đã phân bổ",
    attention: false,
  },
  {
    name: "Thịt heo nạc",
    school: "Tiểu học Nguyễn Du",
    quantity: "48,500000",
    unit: "kg",
    status: "Chưa đủ phân bổ",
    attention: true,
  },
  {
    name: "Cà rốt Đà Lạt",
    school: "Mầm non Hoa Sen",
    quantity: "32,000000",
    unit: "kg",
    status: "Đã phân bổ",
    attention: false,
  },
  {
    name: "Rau cải ngọt",
    school: "Tiểu học Nguyễn Du",
    quantity: "25,750000",
    unit: "kg",
    status: "Đã phân bổ",
    attention: false,
  },
  {
    name: "Trứng gà",
    school: "Mầm non Hoa Sen",
    quantity: "360,000000",
    unit: "quả",
    status: "Đã phân bổ",
    attention: false,
  },
  {
    name: "Bí đỏ",
    school: "Tiểu học Nguyễn Du",
    quantity: "42,000000",
    unit: "kg",
    status: "Đã phân bổ",
    attention: false,
  },
  {
    name: "Dầu ăn đậu nành",
    school: "Mầm non Hoa Sen",
    quantity: "8,500000",
    unit: "lít",
    status: "Chờ phân bổ",
    attention: false,
  },
  {
    name: "Hành lá",
    school: "Tiểu học Nguyễn Du",
    quantity: "2,250000",
    unit: "kg",
    status: "Đã phân bổ",
    attention: false,
  },
];

export function AtlasDesignLanguageReference({
  scenario: initialScenario = "normal",
}: {
  scenario?: ReferenceScenario;
}) {
  const [scenario, setScenario] = useState(initialScenario);
  const [search, setSearch] = useState("");
  const [school, setSchool] = useState("");
  const [status, setStatus] = useState("");
  const [date, setDate] = useState("2026-09-10");
  const [selectedName, setSelectedName] = useState<string | null>("Gạo thơm");
  const [loading, setLoading] = useState(false);
  const [feedback, setFeedback] = useState("");
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(timer.current), []);
  const visible =
    scenario === "empty"
      ? []
      : rows.filter(
          (row) =>
            `${row.name} ${row.school}`
              .toLocaleLowerCase("vi")
              .includes(search.toLocaleLowerCase("vi")) &&
            (!school || row.school === school) &&
            (!status ||
              (status === "attention" ? row.attention : !row.attention)),
        );
  const selected = visible.find((row) => row.name === selectedName);
  const busy = loading || scenario === "loading";
  const blocked = scenario === "unknown" || scenario === "blocker" || busy;
  const refresh = () => {
    setLoading(true);
    setFeedback("");
    clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      setLoading(false);
      setFeedback("Đã làm mới dữ liệu minh họa.");
    }, 1200);
  };

  return (
    <Stack gap="md" minW="0">
      <Box
        as="section"
        bg="bg.workbench"
        borderRadius="workbench"
        minW="0"
        overflow="hidden"
        borderWidth="1px"
        borderColor="border.default"
        aria-labelledby="vnext-workbench-title"
      >
        <Box p="lg" pb="md">
          <Heading
            id="vnext-workbench-title"
            as="h1"
            textStyle="workbenchTitle"
            color="fg.primary"
          >
            Kế hoạch mua hàng
          </Heading>
          <Text mt="xs" color="fg.muted">
            Rà soát nguyên liệu và phân bổ nhà cung ứng cho bữa ăn ngày{" "}
            {date.split("-").reverse().join("/")}.
          </Text>
        </Box>
        <Grid
          role="group"
          aria-label="Phạm vi mua hàng"
          bg="bg.toolbar"
          px={{ base: "md", md: "lg" }}
          py="md"
          gap="sm"
          alignItems="end"
          templateColumns={{
            base: "minmax(0, 1fr)",
            md: "160px minmax(180px, 1fr) minmax(180px, 1.2fr)",
            xl: "154px minmax(180px, 1fr) minmax(180px, 1.2fr) 160px 36px",
          }}
        >
          <Field.Root>
            <Field.Label>Ngày phục vụ</Field.Label>
            <Input
              aria-label="Ngày phục vụ"
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </Field.Root>
          <Field.Root>
            <Field.Label>Trường</Field.Label>
            <NativeSelect.Root>
              <NativeSelect.Field
                aria-label="Trường"
                value={school}
                onChange={(e) => setSchool(e.target.value)}
              >
                <option value="">Tất cả trường</option>
                <option>Tiểu học Nguyễn Du</option>
                <option>Mầm non Hoa Sen</option>
              </NativeSelect.Field>
              <NativeSelect.Indicator />
            </NativeSelect.Root>
          </Field.Root>
          <Field.Root>
            <Field.Label>Tìm kiếm</Field.Label>
            <Input
              aria-label="Tìm kiếm"
              type="search"
              placeholder="Tìm nguyên liệu, trường học…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </Field.Root>
          <Field.Root>
            <Field.Label>Trạng thái</Field.Label>
            <NativeSelect.Root>
              <NativeSelect.Field
                aria-label="Trạng thái"
                value={status}
                onChange={(e) => setStatus(e.target.value)}
              >
                <option value="">Tất cả trạng thái</option>
                <option value="attention">Cần xử lý</option>
                <option value="normal">Không có cảnh báo</option>
              </NativeSelect.Field>
              <NativeSelect.Indicator />
            </NativeSelect.Root>
          </Field.Root>
          <Flex h="control" align="center">
            <AtlasRefreshButton loading={busy} onClick={refresh} />
          </Flex>
        </Grid>
        {scenario === "blocker" || scenario === "unknown" ? (
          <Flex
            role="alert"
            bg={scenario === "unknown" ? "bg.danger" : "bg.warning"}
            color={scenario === "unknown" ? "status.danger" : "status.warning"}
            gap="sm"
            px="lg"
            py="sm"
            align="start"
          >
            <Icon asChild boxSize="20px" flexShrink="0">
              <Warning />
            </Icon>
            <Box>
              <Text fontWeight="600">
                {scenario === "unknown"
                  ? "Chưa xác định kết quả lưu"
                  : "Chưa thể lập đơn mua hàng"}
              </Text>
              <Text>
                {scenario === "unknown"
                  ? "Kiểm tra dữ liệu hiện hành trước khi lưu lại. Không gửi lặp thao tác."
                  : "Thịt heo nạc chưa được phân bổ đủ. Kiểm tra số lượng còn thiếu trước khi tiếp tục."}
              </Text>
            </Box>
          </Flex>
        ) : (
          <Flex px="lg" py="sm" gap="xs" align="center" color="status.info">
            <Icon asChild boxSize="16px">
              <Info />
            </Icon>
            <Text textStyle="helper">
              Số lượng theo nhu cầu đã lưu. Phân bổ không làm thay đổi nhu cầu
              của trường.
            </Text>
          </Flex>
        )}
        <Grid
          templateColumns={{
            base: "minmax(0, 1fr)",
            xl: selected ? "minmax(0, 1fr) 300px" : "minmax(0, 1fr)",
          }}
          minW="0"
        >
          <Box minW="0">
            <Flex px="lg" py="sm" justify="space-between" align="center">
              <Heading as="h2" textStyle="section">
                Nguyên liệu cần mua
              </Heading>
              <Text textStyle="helper" color="fg.muted">
                {visible.length} nguyên liệu
              </Text>
            </Flex>
            <Table.ScrollArea
              maxW="full"
              tabIndex={0}
              aria-label="Bảng nguyên liệu, cuộn ngang khi cần"
            >
              <Table.Root minW="650px" aria-label="Nguyên liệu cần mua">
                <Table.Header>
                  <Table.Row>
                    {[
                      "Nguyên liệu",
                      "Trường / điểm giao",
                      "Số lượng",
                      "Đơn vị",
                      "Trạng thái",
                      "Thao tác",
                    ].map((header) => (
                      <Table.ColumnHeader
                        key={header}
                        textAlign={header === "Số lượng" ? "end" : "start"}
                      >
                        {header}
                      </Table.ColumnHeader>
                    ))}
                  </Table.Row>
                </Table.Header>
                <Table.Body>
                  {visible.map((row) => (
                    <Table.Row
                      key={row.name}
                      aria-selected={row.name === selected?.name}
                      bg={
                        row.name === selected?.name
                          ? "bg.selected"
                          : row.attention
                            ? "bg.warning"
                            : undefined
                      }
                      _hover={{
                        bg:
                          row.name === selected?.name
                            ? "bg.selected"
                            : "bg.subtle",
                      }}
                    >
                      <Table.Cell minW="138px">
                        <Text fontWeight="600">{row.name}</Text>
                        {row.name === selected?.name && (
                          <Flex
                            color="fg.primary"
                            align="center"
                            gap="2px"
                            textStyle="helper"
                          >
                            <Icon asChild boxSize="12px">
                              <Check />
                            </Icon>
                            Đang chọn
                          </Flex>
                        )}
                      </Table.Cell>
                      <Table.Cell minW="138px">
                        {row.school}
                        <Text textStyle="helper" color="fg.muted">
                          Bếp ăn bán trú
                        </Text>
                      </Table.Cell>
                      <Table.Cell
                        textAlign="end"
                        whiteSpace="nowrap"
                        fontVariantNumeric="tabular-nums"
                      >
                        {row.quantity}
                      </Table.Cell>
                      <Table.Cell>{row.unit}</Table.Cell>
                      <Table.Cell minW="110px">
                        {row.attention ? (
                          <Text color="status.warning" fontWeight="600">
                            ⚠ {row.status}
                          </Text>
                        ) : (
                          <Text color="fg.muted">{row.status}</Text>
                        )}
                      </Table.Cell>
                      <Table.Cell>
                        <Button
                          variant="utility"
                          size="sm"
                          aria-label={`Phân bổ ${row.name}`}
                          onClick={() => {
                            setSelectedName(row.name);
                            setFeedback("");
                          }}
                        >
                          Phân bổ
                        </Button>
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table.Body>
              </Table.Root>
            </Table.ScrollArea>
            {visible.length === 0 && (
              <Box py="xl" px="lg">
                <Heading as="h3" textStyle="section">
                  Không có nguyên liệu phù hợp
                </Heading>
                <Text color="fg.muted" mt="xs">
                  Thử chọn trường khác hoặc xóa nội dung tìm kiếm.
                </Text>
              </Box>
            )}
            {busy && (
              <Text role="status" px="lg" py="sm" color="fg.muted">
                Đang tải dữ liệu…
              </Text>
            )}
            <Separator borderColor="border.subtle" />
            <Text px="lg" py="sm" textStyle="helper" color="fg.muted">
              Số lượng và đơn vị giữ nguyên theo từng nguyên liệu. Chọn một dòng
              để xem phân bổ.
            </Text>
          </Box>
          {selected && (
            <Stack
              key={selected.name}
              role="region"
              aria-label={`Phân bổ ${selected.name}`}
              bg="bg.subtle"
              borderLeftWidth={{ base: "0", xl: "1px" }}
              borderTopWidth={{ base: "1px", xl: "0" }}
              borderColor="border.subtle"
              p="md"
              gap="md"
              minW="0"
            >
              <Box>
                <Text textStyle="helper" color="fg.muted">
                  Phân bổ nhà cung ứng
                </Text>
                <Heading as="h2" textStyle="section" mt="xs">
                  {selected.name}
                </Heading>
                <Text color="fg.muted" mt="xs">
                  {selected.school}
                </Text>
              </Box>
              <Separator borderColor="border.default" />
              <Box>
                <Text textStyle="label">Số lượng cần mua</Text>
                <Text
                  fontSize="22px"
                  fontWeight="600"
                  color="fg.primary"
                  fontVariantNumeric="tabular-nums"
                >
                  {selected.quantity}{" "}
                  <Box as="span" textStyle="body" color="fg.muted">
                    {selected.unit}
                  </Box>
                </Text>
              </Box>
              <Field.Root>
                <Field.Label>Nhà cung ứng</Field.Label>
                <NativeSelect.Root>
                  <NativeSelect.Field
                    aria-label="Nhà cung ứng"
                    defaultValue="An Phú"
                  >
                    <option>An Phú</option>
                    <option>Bình Minh</option>
                  </NativeSelect.Field>
                  <NativeSelect.Indicator />
                </NativeSelect.Root>
              </Field.Root>
              <Field.Root>
                <Field.Label>Số lượng phân bổ ({selected.unit})</Field.Label>
                <Input
                  aria-label="Số lượng phân bổ"
                  inputMode="decimal"
                  defaultValue={selected.quantity}
                />
                <Field.HelperText>
                  Kiểm tra số lượng trước khi lưu.
                </Field.HelperText>
              </Field.Root>
              <Text textStyle="helper" color="fg.muted">
                Dữ liệu minh họa. Thao tác tại đây không tạo đơn mua hàng.
              </Text>
              <Flex mt="auto" pt="sm" gap="sm" wrap="wrap">
                <Button
                  variant="secondary"
                  onClick={() => setSelectedName(null)}
                >
                  Đóng
                </Button>
                <Button
                  variant="businessPrimary"
                  disabled={blocked}
                  onClick={() =>
                    setFeedback(
                      "Đã ghi nhận thao tác minh họa. Không có dữ liệu nghiệp vụ được lưu.",
                    )
                  }
                >
                  Lưu phân bổ
                </Button>
              </Flex>
            </Stack>
          )}
        </Grid>
        {feedback && (
          <Text role="status" px="lg" py="sm" color="status.info">
            {feedback}
          </Text>
        )}
      </Box>
      <Box px="xs">
        <Flex align="end" gap="md" wrap="wrap">
          <Field.Root width="240px">
            <Field.Label>Tình huống minh họa</Field.Label>
            <NativeSelect.Root>
              <NativeSelect.Field
                aria-label="Tình huống minh họa"
                value={scenario}
                onChange={(e) =>
                  setScenario(e.target.value as ReferenceScenario)
                }
              >
                <option value="normal">Thông tin thông thường</option>
                <option value="blocker">Cần xử lý trước khi tiếp tục</option>
                <option value="empty">Không có dữ liệu</option>
                <option value="loading">Đang tải dữ liệu</option>
                <option value="unknown">Chưa xác định kết quả</option>
              </NativeSelect.Field>
              <NativeSelect.Indicator />
            </NativeSelect.Root>
          </Field.Root>
          <Flex gap="xs" wrap="wrap" py="sm" aria-label="Quy ước trạng thái">
            <Badge variant="neutral">Chưa lưu</Badge>
            <Badge variant="success">Đã lưu</Badge>
            <Badge variant="warning">Cần xử lý</Badge>
            <Badge variant="danger">Bị chặn</Badge>
            <Badge variant="information">Thông tin</Badge>
          </Flex>
        </Flex>
        <Flex gap="sm" mt="md" align="center" wrap="wrap">
          <Text textStyle="helper" color="fg.muted">
            Thao tác bổ trợ:
          </Text>
          <Button
            variant="utility"
            size="sm"
            onClick={() =>
              setFeedback("Ví dụ xem chi tiết; không gọi dữ liệu bên ngoài.")
            }
          >
            Xem chi tiết
          </Button>
          <Button
            variant="destructive"
            size="sm"
            onClick={() =>
              setFeedback("Ví dụ thao tác xóa. Không có dữ liệu nào bị xóa.")
            }
          >
            Xóa dòng minh họa
          </Button>
        </Flex>
      </Box>
    </Stack>
  );
}
