import { useEffect, useRef, useState, type KeyboardEvent } from "react";
import { Box, Button } from "@chakra-ui/react";
import {
  ArrowLeft,
  ArrowRight,
  CaretDown,
  Check,
  DownloadSimple,
  MagnifyingGlass,
  Warning,
  X,
  CalendarDots,
  UsersThree,
  Package,
  CheckSquareOffset,
  FlowArrow,
  ShoppingCart,
  Truck,
  Scales,
  Buildings,
  Basket,
  Storefront,
  CookingPot,
  NotePencil,
} from "@phosphor-icons/react";
import { AtlasVNextProvider } from "../../atlas/AtlasVNextProvider";
// Registry labels/icons mirrored for isolated navigation study, not mounted owners.
const atlasWorkbenches = [
  { id: "planning", label: "Thực đơn", icon: CalendarDots },
  { id: "attendance", label: "Sĩ số", icon: UsersThree },
  { id: "pantry", label: "Hàng đặt riêng", icon: Package },
  { id: "confirmed-need", label: "Xác nhận nhu cầu", icon: CheckSquareOffset },
  { id: "procurement", label: "Phân bổ NCC", icon: FlowArrow },
  { id: "purchase-orders", label: "Đơn mua", icon: ShoppingCart },
  { id: "pxk", label: "Phiếu xuất kho", icon: Truck },
  {
    id: "reconciliation",
    label: "Đối chiếu PO / Phiếu xuất kho",
    icon: Scales,
  },
  { id: "schools", label: "Trường học", icon: Buildings },
  { id: "ingredients", label: "Nguyên liệu", icon: Basket },
  { id: "suppliers", label: "Nhà cung ứng", icon: Storefront },
  { id: "recipes", label: "Công thức", icon: CookingPot },
  { id: "change-orders", label: "Lệnh điều chỉnh", icon: NotePencil },
];
import "./art-direction.css";

// DESIGN PROTOTYPE ONLY. Synthetic, local state; no API client or business write.
type View = "ledger" | "journal" | "rail";
type State = "populated" | "busy" | "empty" | "blocked";
type Order = {
  id: string;
  supplier: string;
  category: string;
  status: "draft" | "released";
  evidenceMissing?: boolean;
  number: string;
  items: {
    name: string;
    qty: string;
    unit: string;
    schools: { name: string; qty: string; location: string }[];
    note?: string;
  }[];
};
const orders: Order[] = [
  {
    id: "anphu",
    supplier: "Thực phẩm An Phú",
    category: "Thịt, trứng",
    status: "draft",
    number: "Bản nháp · Chưa cấp số",
    items: [
      {
        name: "Thịt heo nạc",
        qty: "42,5",
        unit: "kg",
        note: "Giao trước 6 giờ 30; chia riêng từng bếp.",
        schools: [
          {
            name: "Trường Tiểu học Nguyễn Du",
            qty: "24,5",
            location: "Bếp Nguyễn Du",
          },
          {
            name: "Trường Mầm non Hoa Sen",
            qty: "18",
            location: "Bếp Hoa Sen",
          },
        ],
      },
      {
        name: "Trứng gà",
        qty: "360",
        unit: "quả",
        schools: [
          {
            name: "Trường Tiểu học Nguyễn Du",
            qty: "240",
            location: "Bếp Nguyễn Du",
          },
          {
            name: "Trường Mầm non Hoa Sen",
            qty: "120",
            location: "Bếp Hoa Sen",
          },
        ],
      },
      {
        name: "Thịt gà phi lê",
        qty: "28",
        unit: "kg",
        schools: [
          { name: "Trường Tiểu học Lê Lợi", qty: "28", location: "Bếp Lê Lợi" },
        ],
      },
    ],
  },
  {
    id: "dalat",
    supplier: "Rau sạch Đà Lạt",
    category: "Rau, củ",
    status: "released",
    number: "PO-20261012-DALAT",
    items: [
      {
        name: "Cải ngọt",
        qty: "32",
        unit: "kg",
        schools: [
          {
            name: "Trường Tiểu học Nguyễn Du",
            qty: "20",
            location: "Bếp Nguyễn Du",
          },
          {
            name: "Trường Mầm non Hoa Sen",
            qty: "12",
            location: "Bếp Hoa Sen",
          },
        ],
      },
      {
        name: "Cà rốt",
        qty: "18,5",
        unit: "kg",
        schools: [
          {
            name: "Trường Tiểu học Lê Lợi",
            qty: "18,5",
            location: "Bếp Lê Lợi",
          },
        ],
      },
    ],
  },
  {
    id: "minhtam",
    supplier: "Lương thực Minh Tâm",
    category: "Gạo, gia vị",
    status: "released",
    number: "PO-20261012-MINHTAM",
    items: [
      {
        name: "Gạo thơm",
        qty: "125",
        unit: "kg",
        schools: [
          {
            name: "Trường Tiểu học Nguyễn Du",
            qty: "65",
            location: "Bếp Nguyễn Du",
          },
          { name: "Trường Tiểu học Lê Lợi", qty: "60", location: "Bếp Lê Lợi" },
        ],
      },
      {
        name: "Dầu ăn",
        qty: "12",
        unit: "lít",
        schools: [
          {
            name: "Trường Mầm non Hoa Sen",
            qty: "12",
            location: "Bếp Hoa Sen",
          },
        ],
      },
    ],
  },
  {
    id: "bienxanh",
    supplier: "Hải sản Biển Xanh",
    category: "Cá, hải sản",
    status: "draft",
    evidenceMissing: true,
    number: "Bản nháp · Chưa cấp số",
    items: [
      {
        name: "Cá basa phi lê",
        qty: "36",
        unit: "kg",
        schools: [
          { name: "Trường Tiểu học Lê Lợi", qty: "22", location: "Bếp Lê Lợi" },
          {
            name: "Trường Mầm non Hoa Sen",
            qty: "14",
            location: "Bếp Hoa Sen",
          },
        ],
      },
    ],
  },
];
const views: { id: View; name: string; description: string }[] = [
  {
    id: "ledger",
    name: "A · Sổ đơn song song",
    description: "Quét danh sách gọn, đối chiếu ngay bên cạnh.",
  },
  {
    id: "journal",
    name: "B · Hồ sơ theo nhà cung ứng",
    description: "Đọc mỗi đơn liền mạch; mở chi tiết ngay trong luồng.",
  },
  {
    id: "rail",
    name: "C · Bàn làm việc theo NCC",
    description:
      "Chọn nhà cung ứng ở thanh bên, dành phần lớn diện tích cho đơn.",
  },
];
function Status({ released }: { released: boolean }) {
  return (
    <span className={`order-status ${released ? "released" : "draft"}`}>
      <span />
      {released ? "Đã phát hành" : "Bản nháp"}
    </span>
  );
}
function schoolNames(order: Order) {
  if (order.evidenceMissing) return [];
  return [...new Set(order.items.flatMap((i) => i.schools.map((s) => s.name)))];
}

export function ArtDirectionReview() {
  const params = new URLSearchParams(location.search);
  const [view, setView] = useState<View>(
    (["ledger", "journal", "rail"].includes(params.get("view") ?? "")
      ? params.get("view")
      : "ledger") as View,
  );
  const [state, setState] = useState<State>(
    (["busy", "empty", "blocked"].includes(params.get("state") ?? "")
      ? params.get("state")
      : "populated") as State,
  );
  const [open, setOpen] = useState(atlasWorkbenches.map((w) => w.id));
  const [active, setActive] = useState("purchase-orders");
  const [selected, setSelected] = useState("anphu");
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("all");
  const [checked, setChecked] = useState<string[]>([]);
  const [notice, setNotice] = useState("");
  const [dialog, setDialog] = useState<{
    kind: "close" | "release";
    id: string;
  } | null>(null);
  const [dirtyResolved, setDirtyResolved] = useState(false);
  const tabRefs = useRef(new Map<string, HTMLButtonElement>());
  const restoreRef = useRef<HTMLButtonElement | null>(null);
  useEffect(() => {
    tabRefs.current
      .get(active)
      ?.scrollIntoView?.({ block: "nearest", inline: "nearest" });
  }, [active]);
  const busy = state === "busy";
  const isReleased = (o: Order) => o.status === "released";
  const visible =
    state === "empty"
      ? []
      : orders.filter(
          (o) =>
            `${o.supplier} ${o.number} ${o.items.map((i) => i.name).join(" ")} ${schoolNames(o).join(" ")}`
              .toLocaleLowerCase("vi")
              .includes(query.toLocaleLowerCase("vi")) &&
            (status === "all" || (status === "released") === isReleased(o)),
        );
  const current =
    visible.find((o) => o.id === selected) ?? visible[0] ?? orders[0];
  function close(id: string, trigger: HTMLButtonElement) {
    if (busy || id === "confirmed-need") {
      setNotice("Cần giải quyết công việc đang xử lý trước khi đóng.");
      return;
    }
    if (id === "pantry" && !dirtyResolved) {
      restoreRef.current = trigger;
      setDialog({ kind: "close", id });
      return;
    }
    const remaining = open.filter((v) => v !== id);
    setOpen(remaining);
    if (active === id) setActive(remaining[0] ?? "purchase-orders");
    tabRefs.current
      .get(
        remaining[Math.max(0, open.indexOf(id as (typeof open)[number]) - 1)],
      )
      ?.focus();
  }
  function tabKey(e: KeyboardEvent, id: string) {
    const index = open.indexOf(id as (typeof open)[number]);
    if (["ArrowRight", "ArrowLeft", "Home", "End"].includes(e.key)) {
      e.preventDefault();
      const next =
        e.key === "Home"
          ? open[0]
          : e.key === "End"
            ? open.at(-1)!
            : open[
                (index + (e.key === "ArrowRight" ? 1 : -1) + open.length) %
                  open.length
              ];
      tabRefs.current.get(next)?.focus();
    }
    if (e.key === "Delete") close(id, e.currentTarget as HTMLButtonElement);
  }
  function action(order: Order, trigger: HTMLButtonElement) {
    restoreRef.current = trigger;
    setDialog({ kind: "release", id: order.id });
  }
  function dismiss() {
    setDialog(null);
    requestAnimationFrame(() => {
      if (restoreRef.current?.isConnected) restoreRef.current.focus();
      else tabRefs.current.get(active)?.focus();
    });
  }
  function confirm() {
    if (!dialog) return;
    if (dialog.kind === "close") {
      setDirtyResolved(true);
      setOpen(open.filter((id) => id !== dialog.id));
      setNotice("Đã bỏ thay đổi mô phỏng của Hàng đặt riêng.");
    } else {
      setNotice(
        "Đã kết thúc xem thử bước xác nhận. Trạng thái và số đơn giả lập giữ nguyên; không phát hành hoặc gửi dữ liệu.",
      );
    }
    dismiss();
  }
  function select(id: string) {
    setSelected(id);
    setNotice("");
  }
  function summary(order: Order) {
    return (
      <>
        <strong>{order.supplier}</strong>
        <span className="secondary">
          {order.category} · {order.items.length} nguyên liệu
        </span>
      </>
    );
  }
  function detail(order: Order) {
    const issued = isReleased(order);
    return (
      <section
        className="order-detail"
        aria-label={`Chi tiết ${order.supplier}`}
      >
        <div className="detail-top">
          <div>
            <div className="doc-reference">
              {issued
                ? order.status === "released"
                  ? order.number
                  : `PO-20261012-${order.id.toUpperCase()}`
                : "Bản nháp · Chưa cấp số"}
            </div>
            <h2>{order.supplier}</h2>
            <p>
              Giao ngày <strong>12/10/2026</strong> ·{" "}
              {order.evidenceMissing
                ? "Chưa đủ dữ liệu trường nhận"
                : `${schoolNames(order).length} trường`}
            </p>
          </div>
          <Status released={issued} />
        </div>
        <div className="detail-actions">
          {!issued && (
            <Button
              variant="businessPrimary"
              disabled={busy || state === "blocked" || order.evidenceMissing}
              onClick={(e) => action(order, e.currentTarget)}
            >
              {busy ? "Đang xử lý…" : "Phát hành cho NCC"}
              <ArrowRight size={17} />
            </Button>
          )}
          <Button
            variant="secondary"
            disabled={!issued || busy}
            onClick={() =>
              setNotice(
                "Đã mô phỏng xuất bản đã phát hành. Không tạo tệp thật.",
              )
            }
          >
            <DownloadSimple size={17} />
            Xuất Excel / PDF
          </Button>
        </div>
        {!issued && (
          <p className="document-help">
            Bản nháp để kiểm tra. Chỉ phát hành mới xác nhận đơn với nhà cung
            ứng; xuất tệp không phát hành đơn.
          </p>
        )}
        <div className="line-heading">
          <h3>Nguyên liệu và nơi nhận</h3>
          <span>{order.items.length} dòng</span>
        </div>
        <div className="detail-lines">
          {order.evidenceMissing && (
            <div className="notice warning" role="status">
              Chưa có bằng chứng đầy đủ về trường nhận của bản nháp này. Không
              suy ra trường từ địa điểm giao; chưa thể phát hành.
            </div>
          )}
          {order.items.map((item) => (
            <section className="ingredient" key={item.name}>
              <div className="ingredient-total">
                <strong>{item.name}</strong>
                <span>
                  <b>{item.qty}</b> {item.unit}
                </span>
              </div>
              {!order.evidenceMissing &&
                item.schools.map((s) => (
                  <div className="school-line" key={s.name}>
                    <div>
                      {s.name}
                      <small>{s.location}</small>
                    </div>
                    <span>
                      {s.qty} {item.unit}
                    </span>
                  </div>
                ))}
              {item.note && (
                <p className="supplier-note">Ghi chú cho NCC: {item.note}</p>
              )}
            </section>
          ))}
        </div>
        <p className="history-note">
          {issued
            ? "Nội dung đã phát hành được giữ nguyên trong lịch sử."
            : "Kiểm tra số lượng, nơi nhận và ghi chú trước khi phát hành từng đơn."}
        </p>
      </section>
    );
  }
  return (
    <AtlasVNextProvider>
      <Box
        className={`art-review variant-${view}`}
        bg="bg.workbench"
        color="fg.default"
      >
        <aside className="review-tools" aria-label="Điều khiển bản mẫu">
          <strong>Bản mẫu D2</strong>
          <div className="alternatives">
            {views.map((v) => (
              <button
                key={v.id}
                aria-pressed={view === v.id}
                onClick={() => {
                  setView(v.id);
                  history.replaceState(
                    null,
                    "",
                    `?view=${v.id}&state=${state}`,
                  );
                }}
              >
                {v.name}
              </button>
            ))}
          </div>
          <label>
            Trạng thái{" "}
            <select
              aria-label="Trạng thái bản mẫu"
              value={state}
              onChange={(e) => {
                setState(e.target.value as State);
                setNotice("");
              }}
            >
              <option value="populated">Có dữ liệu</option>
              <option value="busy">Đang xử lý</option>
              <option value="empty">Chưa có đơn</option>
              <option value="blocked">Chưa đủ điều kiện</option>
            </select>
          </label>
          <span className="prototype-note">
            Dữ liệu giả lập · Không kết nối hệ thống
          </span>
        </aside>
        <header className="app-header">
          <span className="atlas-brand">
            atlas<span>Thương Hảo</span>
          </span>
          <button
            className="launch"
            disabled={busy}
            onClick={() => {
              setOpen(atlasWorkbenches.map((w) => w.id));
              setNotice("Đã mở lại đủ 13 không gian trong bản mẫu.");
            }}
          >
            Chức năng <CaretDown size={16} />
          </button>
          <span className="header-date">Thứ Hai, 12/10/2026</span>
          <span className="operator">Ngọc Anh · Mua hàng</span>
        </header>
        <nav className="workspace-tabs" aria-label="Không gian đang mở">
          <div className="tabs-scroll" role="tablist" aria-label="13 công việc">
            {atlasWorkbenches
              .filter((w) => open.includes(w.id))
              .map((w) => (
                <div
                  key={w.id}
                  className={`workspace-tab ${active === w.id ? "active" : ""}`}
                >
                  <button
                    role="tab"
                    aria-selected={active === w.id}
                    aria-controls="workspace-panel"
                    id={`tab-${w.id}`}
                    tabIndex={active === w.id ? 0 : -1}
                    ref={(el) => {
                      if (el) tabRefs.current.set(w.id, el);
                    }}
                    onKeyDown={(e) => tabKey(e, w.id)}
                    disabled={busy}
                    onClick={() => setActive(w.id)}
                  >
                    <w.icon size={17} />
                    <span>{w.label}</span>
                    {w.id === "pantry" && !dirtyResolved && (
                      <span
                        className="dirty-dot"
                        title="Chưa lưu"
                        aria-label="Chưa lưu"
                      />
                    )}
                    {w.id === "confirmed-need" && (
                      <Warning size={14} aria-label="Cần giải quyết" />
                    )}
                  </button>
                  <button
                    className="close-tab"
                    aria-label={`Đóng ${w.label}`}
                    disabled={busy}
                    onClick={(e) => close(w.id, e.currentTarget)}
                  >
                    <X size={13} />
                  </button>
                </div>
              ))}
          </div>
          <div className="tab-overflow-controls">
            <button
              aria-label="Cuộn tab sang trái"
              onClick={() =>
                document
                  .querySelector(".tabs-scroll")
                  ?.scrollBy({ left: -260, behavior: "smooth" })
              }
            >
              <ArrowLeft size={17} />
            </button>
            <button
              aria-label="Cuộn tab sang phải"
              onClick={() =>
                document
                  .querySelector(".tabs-scroll")
                  ?.scrollBy({ left: 260, behavior: "smooth" })
              }
            >
              <ArrowRight size={17} />
            </button>
          </div>
        </nav>
        <main
          id="workspace-panel"
          role="tabpanel"
          aria-labelledby={`tab-${active}`}
        >
          {active !== "purchase-orders" ? (
            <section className="workspace-placeholder">
              <h1>{atlasWorkbenches.find((w) => w.id === active)?.label}</h1>
              <p>
                Không gian này được giữ trong bản mẫu để thử chuyển tab, đóng và
                dấu trạng thái. Luồng dữ liệu chi tiết nằm ở Đơn mua.
              </p>
              <Button
                variant="businessPrimary"
                onClick={() => setActive("purchase-orders")}
              >
                Trở lại Đơn mua
              </Button>
            </section>
          ) : (
            <>
              <div className="workbench-heading">
                <div>
                  <h1>Đơn mua</h1>
                  <p>Kiểm tra và phát hành từng đơn cho nhà cung ứng.</p>
                </div>
                <div className="scope">
                  <label>
                    Ngày giao
                    <input
                      type="text"
                      value="12/10/2026 — 12/10/2026"
                      readOnly
                      aria-label="Khoảng ngày giao"
                    />
                  </label>
                  <Button
                    variant="secondary"
                    disabled={busy}
                    onClick={() =>
                      setNotice(
                        "Dữ liệu giả lập đã được làm mới; phạm vi ngày giữ nguyên.",
                      )
                    }
                  >
                    Làm mới
                  </Button>
                </div>
              </div>
              <div className="workbench-filters">
                <label className="search">
                  <MagnifyingGlass size={18} />
                  <input
                    aria-label="Tìm đơn mua"
                    placeholder="Tìm nhà cung ứng, số đơn, nguyên liệu, trường…"
                    value={query}
                    disabled={busy}
                    onChange={(e) => setQuery(e.target.value)}
                  />
                </label>
                <select
                  aria-label="Lọc trạng thái đơn"
                  value={status}
                  disabled={busy}
                  onChange={(e) => setStatus(e.target.value)}
                >
                  <option value="all">Tất cả trạng thái</option>
                  <option value="draft">Bản nháp</option>
                  <option value="released">Đã phát hành</option>
                </select>
                <span className="result-count">
                  {visible.length} đơn · 12/10/2026
                </span>
              </div>
              {state === "blocked" && (
                <div className="notice warning" role="status">
                  <Warning size={20} />
                  <div>
                    <strong>Chưa thể phát hành</strong>
                    <p>
                      Nhu cầu hoặc phân bổ chưa đủ điều kiện. Kiểm tra nguồn
                      hiện tại trước khi tiếp tục; đơn đã phát hành vẫn được giữ
                      trong lịch sử.
                    </p>
                  </div>
                  <button
                    onClick={() => {
                      setActive("procurement");
                      setNotice("Đã mở không gian Phân bổ NCC mô phỏng.");
                    }}
                  >
                    Xem phân bổ <ArrowRight size={16} />
                  </button>
                </div>
              )}
              {notice && (
                <div className="notice" role="status">
                  <Check size={18} />
                  <span>{notice}</span>
                  <button
                    aria-label="Đóng thông báo"
                    onClick={() => setNotice("")}
                  >
                    <X size={16} />
                  </button>
                </div>
              )}
              {busy && (
                <div className="notice" role="status">
                  Đang xử lý đơn. Giữ nguyên phạm vi và chờ kết quả; đây là
                  trạng thái mô phỏng.
                </div>
              )}
              {checked.length > 0 && (
                <div className="bulk-bar">
                  <strong>Đã chọn {checked.length} đơn</strong>
                  <Button
                    variant="secondary"
                    disabled={busy}
                    onClick={() =>
                      setNotice(
                        "Đã mô phỏng xuất các đơn đã phát hành được chọn. Không phát hành hàng loạt.",
                      )
                    }
                  >
                    Xuất các đơn đã chọn
                  </Button>
                  <button onClick={() => setChecked([])}>Bỏ chọn</button>
                  <span>Chỉ chọn bản đã phát hành để xuất.</span>
                </div>
              )}
              {visible.length === 0 ? (
                <section className="empty">
                  <h2>
                    {query || status !== "all"
                      ? "Không có đơn khớp bộ lọc"
                      : "Chưa có đơn mua trong ngày này"}
                  </h2>
                  <p>
                    {query || status !== "all"
                      ? "Thử bỏ bớt bộ lọc để xem lại các đơn trong phạm vi ngày đã chọn."
                      : "Sau khi xác nhận nhu cầu và phân bổ, chuẩn bị mua hàng để tạo bản nháp. Chưa có đơn không có nghĩa là nhu cầu bằng không."}
                  </p>
                  <Button
                    variant="secondary"
                    onClick={() => {
                      setQuery("");
                      setStatus("all");
                      if (state === "empty" && !query && status === "all")
                        setActive("procurement");
                    }}
                  >
                    {query || status !== "all"
                      ? "Xóa bộ lọc"
                      : "Xem phân bổ NCC"}
                  </Button>
                </section>
              ) : (
                <div className="order-workplane">
                  {view === "ledger" && (
                    <>
                      <section
                        className="supplier-ledger"
                        aria-label="Danh sách đơn"
                      >
                        <div className="list-caption">
                          <strong>Nhà cung ứng</strong>
                          <span>Ngày giao · Trạng thái</span>
                        </div>
                        {visible.map((o) => (
                          <div
                            className={`ledger-row ${current.id === o.id ? "selected" : ""}`}
                            key={o.id}
                          >
                            <input
                              type="checkbox"
                              aria-label={`Chọn xuất ${o.supplier}`}
                              checked={checked.includes(o.id)}
                              disabled={!isReleased(o) || busy}
                              onChange={(e) =>
                                setChecked(
                                  e.target.checked
                                    ? [...checked, o.id]
                                    : checked.filter((id) => id !== o.id),
                                )
                              }
                            />
                            <button
                              onClick={() => select(o.id)}
                              aria-pressed={current.id === o.id}
                            >
                              <div className="supplier-identity">
                                {summary(o)}
                              </div>
                              <Status released={isReleased(o)} />
                              <span className="secondary row-document">
                                {o.number}
                              </span>
                              <span className="secondary">
                                12/10 ·{" "}
                                {o.evidenceMissing
                                  ? "Thiếu dữ liệu trường"
                                  : `${schoolNames(o).length} trường`}
                              </span>
                            </button>
                          </div>
                        ))}
                      </section>
                      {detail(current)}
                    </>
                  )}
                  {view === "journal" && (
                    <section
                      className="order-journal"
                      aria-label="Hồ sơ đơn mua"
                    >
                      {visible.map((o) => (
                        <article
                          key={o.id}
                          className={
                            current.id === o.id
                              ? "journal-order selected"
                              : "journal-order"
                          }
                        >
                          <button
                            className="journal-summary"
                            aria-expanded={current.id === o.id}
                            onClick={() => select(o.id)}
                          >
                            <span className="supplier-identity">
                              {summary(o)}
                            </span>
                            <span className="secondary">
                              12/10/2026 ·{" "}
                              {o.evidenceMissing
                                ? "Thiếu dữ liệu trường"
                                : `${schoolNames(o).length} trường`}
                            </span>
                            <Status released={isReleased(o)} />
                            <CaretDown size={18} />
                          </button>
                          {current.id === o.id && detail(o)}
                        </article>
                      ))}
                    </section>
                  )}
                  {view === "rail" && (
                    <>
                      <aside
                        className="supplier-rail"
                        aria-label="Chọn nhà cung ứng"
                      >
                        <h2>
                          Nhà cung ứng <span>{visible.length}</span>
                        </h2>
                        {visible.map((o) => (
                          <button
                            key={o.id}
                            className={current.id === o.id ? "selected" : ""}
                            onClick={() => select(o.id)}
                            aria-pressed={current.id === o.id}
                          >
                            {summary(o)}
                            <Status released={isReleased(o)} />
                          </button>
                        ))}
                      </aside>
                      {detail(current)}
                    </>
                  )}
                </div>
              )}
            </>
          )}
        </main>
        <footer className="prototype-footer">
          {views.find((v) => v.id === view)!.description}{" "}
          <span>Bản mẫu tương tác · Chờ chọn hướng thiết kế</span>
        </footer>
        {dialog && (
          <div className="dialog-scrim">
            <section
              role="dialog"
              aria-modal="true"
              aria-labelledby="dialog-title"
              className="prototype-dialog"
              onKeyDown={(e) => {
                if (e.key === "Escape") dismiss();
                if (e.key === "Tab") {
                  const buttons = e.currentTarget.querySelectorAll("button");
                  if (
                    (!e.shiftKey &&
                      document.activeElement === buttons[buttons.length - 1]) ||
                    (e.shiftKey && document.activeElement === buttons[0])
                  ) {
                    e.preventDefault();
                    (e.shiftKey
                      ? buttons[buttons.length - 1]
                      : buttons[0]
                    ).focus();
                  }
                }
              }}
            >
              <h2 id="dialog-title">
                {dialog.kind === "close"
                  ? "Bỏ thay đổi chưa lưu?"
                  : `Phát hành đơn ${orders.find((o) => o.id === dialog.id)!.supplier}?`}
              </h2>
              <p>
                {dialog.kind === "close"
                  ? "Hủy để trở lại công việc và giữ nguyên dữ liệu đang nhập. Bỏ thay đổi chỉ đóng Hàng đặt riêng."
                  : "Ngày giao 12/10/2026. Đây là thao tác mô phỏng cho một đơn; không gửi đến nhà cung ứng, không tạo dữ liệu thật."}
              </p>
              <div>
                <Button autoFocus variant="secondary" onClick={dismiss}>
                  Hủy
                </Button>
                <Button variant="businessPrimary" onClick={confirm}>
                  {dialog.kind === "close" ? "Bỏ thay đổi" : "Kết thúc xem thử"}
                </Button>
              </div>
            </section>
          </div>
        )}
      </Box>
    </AtlasVNextProvider>
  );
}
