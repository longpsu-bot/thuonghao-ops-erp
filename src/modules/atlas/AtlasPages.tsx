import { useState, type ReactNode } from "react";
import { AttendanceWorkbench } from "../attendance/AttendanceWorkbench";
import { WeeklyMenuWorkbench } from "../weekly-menu/WeeklyMenuWorkbench";
import type { AtlasPage } from "./atlasConfig";
import {
  ActionBar,
  Chip,
  CompactTable,
  Panel,
  Recipient,
} from "./WorkbenchComponents";

const recipient = {
  name: "Trường Nguyễn Du",
  context: "Bếp trung tâm · Tuyến Bắc",
};
const affected = {
  name: "Trường Minh An",
  context: "Bếp Minh An · Tuyến Đông",
};

export function ControlBoardPage() {
  const queue = [
    ["Thực đơn có dòng lỗi", "2", "Nguồn kế hoạch"],
    ["Sĩ số chờ xác nhận", "8", "Nguồn kế hoạch"],
    ["Hàng đặt riêng chờ duyệt", "2", "Nguồn kế hoạch"],
    ["Pantry cần kiểm tra", "3", "Nguồn kế hoạch"],
    ["Nhu cầu chưa bàn giao Thu mua", "6", "Tổng hợp nhu cầu"],
    ["NCC chưa phân công / lệch", "5", "Mua hàng"],
    ["PO / phiếu chưa phát hành", "6", "Phát hành"],
    ["PO và phiếu xuất lệch", "3", "Phát hành"],
    ["NCC giao thiếu / trễ / sai", "4", "Nhập kho"],
  ];
  return (
    <>
      <div className="exception-grid">
        {queue.map(([label, count, owner]) => (
          <article key={label}>
            <span>{label}</span>
            <strong>{count}</strong>
            <small>Chủ sở hữu: {owner}</small>
          </article>
        ))}
      </div>
      <Panel
        title="Hàng đợi cần chú ý"
        description="Ngoại lệ được xếp theo rủi ro ảnh hưởng đơn vị nhận, bếp và tuyến."
        status={<Chip tone="danger">4 ảnh hưởng vận hành</Chip>}
      >
        <CompactTable
          headers={[
            "Ngoại lệ",
            "Trace ID",
            "Nguồn",
            "Đơn vị nhận / Điểm giao",
            "Đối tượng ảnh hưởng",
            "Trạng thái hiện tại",
            "Chủ xử lý",
            "Bước tiếp",
            "Tuổi ngoại lệ",
          ]}
        >
          <tr>
            <td>
              <Chip tone="danger">NCC giao thiếu</Chip>
            </td>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>Nhu cầu thực tế xác nhận</td>
            <td>
              <Recipient {...affected} />
            </td>
            <td>Gạo Jasmine · thiếu 10 kg</td>
            <td>
              <Chip tone="danger">Chờ bổ sung</Chip>
            </td>
            <td>Thu mua · Minh</td>
            <td>Chốt NCC bổ sung trước 05:15</td>
            <td>42 phút</td>
          </tr>
          <tr>
            <td>
              <Chip tone="warning">PO / phiếu xuất lệch</Chip>
            </td>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>Thực đơn</td>
            <td>
              <Recipient {...recipient} />
            </td>
            <td>Bí đỏ · PO 72 kg / PXK 75 kg</td>
            <td>
              <Chip tone="warning">Cần revision</Chip>
            </td>
            <td>Phát hành · Lan</td>
            <td>Mở lại PXK và phát hành lần 2</td>
            <td>18 phút</td>
          </tr>
        </CompactTable>
      </Panel>
    </>
  );
}

const sourceTabs = [
  "Thực đơn tuần",
  "Sĩ số / suất ăn",
  "Hàng đặt riêng",
  "Pantry / nhu cầu nội bộ",
  "Tóm tắt nguồn",
] as const;

export function PlanningSourcesPage() {
  const [tab, setTab] = useState<(typeof sourceTabs)[number]>(sourceTabs[0]);
  const sourceStatus = (
    <div className="trace-filter">
      <b>Nguồn dữ liệu:</b> Google Sheet tuần / prototype fixture · Lần cập nhật
      nguồn: 13/07 17:30 · 18 dòng hợp lệ · 2 dòng lỗi ·{" "}
      <Chip tone="warning">Cần kiểm tra</Chip>
    </div>
  );
  const content: Record<(typeof sourceTabs)[number], ReactNode> = {
    "Thực đơn tuần": <WeeklyMenuWorkbench />,
    "Sĩ số / suất ăn": <AttendanceWorkbench />,
    "Hàng đặt riêng": (
      <CompactTable
        headers={[
          "Trace ID",
          "Ngày",
          "Người / bộ phận yêu cầu",
          "Đơn vị nhận / Điểm giao",
          "Nguyên liệu",
          "Số lượng yêu cầu",
          "Lý do yêu cầu",
          "Ưu tiên",
          "Trạng thái duyệt",
          "Người xác nhận",
        ]}
      >
        <tr>
          <td>OPS-2026-0714-MA-GAO-001</td>
          <td>14/07/2026</td>
          <td>Quân · Bếp Minh An</td>
          <td>Bếp Minh An · Tuyến Đông</td>
          <td>Gạo Jasmine</td>
          <td>250 kg</td>
          <td>Bổ sung suất đặt riêng</td>
          <td>Cao</td>
          <td>
            <Chip tone="warning">Chờ duyệt</Chip>
          </td>
          <td>—</td>
        </tr>
      </CompactTable>
    ),
    "Pantry / nhu cầu nội bộ": (
      <>
        <p className="supporting-copy">
          Pantry ở đây chỉ là nguồn kế hoạch; không phải hạch toán tồn kho.
        </p>
        <CompactTable
          headers={[
            "Trace ID",
            "Ngày",
            "Bộ phận / trường",
            "Mục đích sử dụng",
            "Nguyên liệu",
            "Tồn hiện có / trạng thái pantry",
            "Cần bổ sung",
            "Tần suất / lịch pantry",
            "Trạng thái",
            "Người xác nhận",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-PN-DAU-001</td>
            <td>14/07/2026</td>
            <td>Bếp trung tâm</td>
            <td>Vật tư nấu ăn</td>
            <td>Dầu ăn</td>
            <td>Cần kiểm tra</td>
            <td>20 lít</td>
            <td>Thứ ba hằng tuần</td>
            <td>
              <Chip tone="warning">Chờ rà soát</Chip>
            </td>
            <td>Mai · Kho</td>
          </tr>
        </CompactTable>
      </>
    ),
    "Tóm tắt nguồn": (
      <div className="exception-grid">
        {[
          ["Thực đơn tuần", "18 hợp lệ · 2 lỗi", "Đã xác nhận"],
          ["Sĩ số / suất ăn", "3 thay đổi", "1 chờ xác nhận"],
          ["Hàng đặt riêng", "2 yêu cầu", "1 chờ duyệt"],
          ["Pantry / nhu cầu nội bộ", "1 đến hạn", "1 chờ rà soát"],
        ].map(([label, value, status]) => (
          <article key={label}>
            <span>{label}</span>
            <strong>{value}</strong>
            <small>{status}</small>
          </article>
        ))}
      </div>
    ),
  };
  return (
    <>
      <Panel
        title="Nguồn tạo nhu cầu"
        description="Trả lời: vì sao các nhu cầu nguyên liệu này tồn tại?"
        status={<Chip tone="warning">4 nguồn cần xử lý</Chip>}
      >
        <div
          className="workbench-actions"
          role="tablist"
          aria-label="Nguồn kế hoạch"
        >
          {sourceTabs.map((item) => (
            <button
              key={item}
              className={item === tab ? "primary" : ""}
              role="tab"
              aria-selected={item === tab}
              onClick={() => setTab(item)}
            >
              {item}
            </button>
          ))}
        </div>
        {sourceStatus}
        {content[tab]}
      </Panel>
    </>
  );
}
export function RequirementPlanningPage() {
  return (
    <>
      <Panel
        title="Tổng hợp & xác nhận nhu cầu"
        description="Tất cả nguồn kế hoạch → công thức / định lượng → nhu cầu tính toán → nhu cầu thực tế xác nhận."
        status={<Chip tone="warning">8 chờ xác nhận</Chip>}
      >
        <div className="trace-filter" aria-label="Bộ lọc nguồn nhu cầu">
          <b>Hàng đợi nguồn:</b>
          <Chip tone="warning">Hàng đặt riêng · 2 cần xác nhận</Chip>
          <span>
            Hiển thị cùng nhu cầu thực đơn, không tạo trang vận hành riêng.
          </span>
        </div>
        <CompactTable
          headers={[
            "Trace ID",
            "Nguồn",
            "Ngày",
            "Đơn vị nhận / Điểm giao",
            "Món",
            "Nguyên liệu",
            "ĐVT",
            "Tính toán",
            "Thực tế",
            "Chênh lệch",
            "Trạng thái",
            "Lý do / ghi chú",
            "Bàn giao Thu mua",
            "Người nhập thực tế",
            "Người xác nhận",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>Thực đơn · Sĩ số</td>
            <td>14/07/2026</td>
            <td>
              <Recipient {...recipient} />
            </td>
            <td>Canh bí đỏ</td>
            <td>Bí đỏ</td>
            <td>kg</td>
            <td>75</td>
            <td>72</td>
            <td>-3</td>
            <td>
              <Chip tone="warning">Đã điều chỉnh</Chip>
            </td>
            <td>Giảm theo số suất thực tế</td>
            <td>
              <Chip tone="ok">Đã bàn giao</Chip>
            </td>
            <td>Hà · Bếp trung tâm</td>
            <td>Lan · Điều hành</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>Hàng đặt riêng</td>
            <td>14/07/2026</td>
            <td>
              <Recipient {...affected} />
            </td>
            <td>Cơm</td>
            <td>Gạo Jasmine</td>
            <td>kg</td>
            <td>250</td>
            <td>
              <button className="inline-action">Nhập nhu cầu</button>
            </td>
            <td>—</td>
            <td>
              <Chip tone="danger">Chưa nhập thực tế</Chip>
            </td>
            <td>Chờ bếp xác nhận</td>
            <td>
              <Chip tone="warning">Chưa bàn giao</Chip>
            </td>
            <td>Quân · Bếp Minh An</td>
            <td>—</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-PN-DAU-001</td>
            <td>Pantry / nhu cầu nội bộ</td>
            <td>14/07/2026</td>
            <td>Bếp trung tâm · Tuyến Bắc</td>
            <td>Pantry</td>
            <td>Dầu ăn</td>
            <td>lít</td>
            <td>20</td>
            <td>20</td>
            <td>0</td>
            <td>
              <Chip tone="warning">Chờ rà soát</Chip>
            </td>
            <td>Bổ sung vật tư nấu ăn theo lịch pantry</td>
            <td>
              <Chip tone="warning">Chưa bàn giao</Chip>
            </td>
            <td>Mai · Kho</td>
            <td>—</td>
          </tr>
        </CompactTable>
      </Panel>
      <Panel
        title="Vì sao có nhu cầu này?"
        description="Giải thích dòng đang chọn theo nguồn, định lượng và xác nhận; chỉ minh hoạ cục bộ."
        status={<Chip tone="ok">OPS-2026-0714-ND-BIDO-001</Chip>}
      >
        <div className="recipe-grid">
          <article>
            <b>Món / trường / ngày</b>
            <strong>Canh bí đỏ · Trường Nguyễn Du · 14/07/2026</strong>
            <small>Thực đơn tuần · sĩ số thực tế 320 suất</small>
          </article>
          <article>
            <b>Công thức / định lượng</b>
            <strong>Bí đỏ · 0,225 kg/suất</strong>
            <small>Nhu cầu tính toán: 75 kg</small>
          </article>
          <article>
            <b>Điều chỉnh / nhu cầu cuối</b>
            <strong>-3 kg → 72 kg</strong>
            <small>Lan · Điều hành xác nhận</small>
          </article>
        </div>
        <div className="recipe-grid">
          <article>
            <b>Hàng đặt riêng · OPS-2026-0714-MA-GAO-001</b>
            <strong>Gạo Jasmine · 250 kg</strong>
            <small>
              Người yêu cầu: Quân · Bếp Minh An. Lý do: bổ sung suất đặt riêng.
              Trạng thái: chờ xác nhận. Nhu cầu cuối: 250 kg.
            </small>
          </article>
          <article>
            <b>Pantry / nhu cầu nội bộ · OPS-2026-0714-PN-DAU-001</b>
            <strong>Dầu ăn · 20 lít</strong>
            <small>
              Đơn vị phụ trách: Bếp trung tâm. Mục đích: vật tư nấu ăn theo lịch
              pantry. Trạng thái: chờ rà soát. Nhu cầu cuối: 20 lít.
            </small>
          </article>
        </div>
      </Panel>
      <ActionBar
        actions={[
          "Nhập nhu cầu thực tế",
          "Lưu số lượng",
          "Xác nhận nhu cầu",
          "Mở lại để điều chỉnh",
          "Xem lịch sử / lý do điều chỉnh",
        ]}
      />
    </>
  );
}
export function PurchasePlanningPage() {
  return (
    <>
      <Panel
        title="Hàng đợi phân bổ NCC"
        description="Một nhu cầu đã xác nhận có thể chia nhiều NCC, phân công một phần, hoặc dùng NCC dự phòng."
        status={<Chip tone="danger">1 chưa phân công</Chip>}
      >
        <CompactTable
          headers={[
            "Trace ID",
            "Nguyên liệu",
            "Đơn vị nhận / Điểm giao",
            "Nhu cầu đã xác nhận",
            "Phân bổ NCC",
            "Còn lại",
            "NCC",
            "Vai trò",
            "Trạng thái",
            "Ghi chú giao hàng",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>Gạo Jasmine</td>
            <td>
              <Recipient {...affected} />
            </td>
            <td>250 kg</td>
            <td>150 kg</td>
            <td>100 kg</td>
            <td>Thành Công Foods</td>
            <td>Chính</td>
            <td>
              <Chip tone="warning">Phân công một phần</Chip>
            </td>
            <td>Giao 05:30 · đợt chính</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>Gạo Jasmine</td>
            <td>
              <Recipient {...affected} />
            </td>
            <td>250 kg</td>
            <td>100 kg</td>
            <td>0 kg</td>
            <td>Nam Việt Supply</td>
            <td>Bổ sung</td>
            <td>
              <Chip tone="ok">Đã phân công đủ</Chip>
            </td>
            <td>Giao 05:45 · bù phần còn lại</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>Bí đỏ</td>
            <td>
              <Recipient {...recipient} />
            </td>
            <td>72 kg</td>
            <td>0 kg</td>
            <td>72 kg</td>
            <td>—</td>
            <td>Dự phòng</td>
            <td>
              <Chip tone="danger">Chưa phân công</Chip>
            </td>
            <td>Chờ NCC dự phòng</td>
          </tr>
        </CompactTable>
      </Panel>
      <ActionBar
        actions={[
          "Tự phân công NCC mặc định",
          "Chia NCC",
          "Cân bằng số lượng",
          "Xóa dòng NCC",
          "Lưu phân công",
          "Chuẩn bị PO",
        ]}
      />
    </>
  );
}
export function DocumentReleasePage() {
  const tabs = [
    "Đơn đặt NCC / PO",
    "Phiếu xuất kho",
    "Phiếu nhận hàng",
    "Đối chiếu chứng từ",
  ] as const;
  const [tab, setTab] = useState<(typeof tabs)[number]>(tabs[0]);
  const body: Record<(typeof tabs)[number], ReactNode> = {
    "Đơn đặt NCC / PO": (
      <Panel
        title="Đơn đặt NCC / PO"
        description="Chế độ xuất: Tất cả / Theo NCC / Theo nhóm đi chợ. Dữ liệu xuất: theo dòng đang lọc."
        status={<Chip tone="warning">Sẵn sàng phát hành</Chip>}
      >
        <CompactTable
          headers={[
            "Trace ID",
            "NCC",
            "PO",
            "Nhu cầu xác nhận",
            "SL PO",
            "Chế độ xuất",
            "Dữ liệu xuất",
            "Trạng thái file",
            "Trạng thái phát hành",
            "Phiên bản",
            "Người phát hành",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>Thành Công Foods</td>
            <td>PO-0714-008</td>
            <td>250 kg</td>
            <td>150 kg</td>
            <td>Theo NCC</td>
            <td>Theo dòng đang lọc</td>
            <td>Đã tạo bản nháp</td>
            <td>
              <Chip tone="warning">Sẵn sàng phát hành</Chip>
            </td>
            <td>Lần 1</td>
            <td>Lan</td>
          </tr>
        </CompactTable>
        <ActionBar
          actions={["Xem trước PO", "Xuất PO", "Phát hành PO", "Mở lại PO"]}
        />
      </Panel>
    ),
    "Phiếu xuất kho": (
      <Panel
        title="Phiếu xuất kho"
        description="Phiếu xuất được đối chiếu với nhu cầu xác nhận và PO trước phát hành."
      >
        <CompactTable
          headers={[
            "Trace ID",
            "Phiếu xuất kho",
            "Đơn vị nhận / Điểm giao",
            "Nguyên liệu",
            "SL cần xuất",
            "SL theo PO",
            "Delta",
            "Trạng thái phát hành",
            "Phiên bản",
            "Người phát hành",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>PXK-0714-ND</td>
            <td>Trường Nguyễn Du · Bếp trung tâm</td>
            <td>Bí đỏ</td>
            <td>72 kg</td>
            <td>72 kg</td>
            <td>0</td>
            <td>
              <Chip tone="ok">Đã phát hành</Chip>
            </td>
            <td>Lần 1</td>
            <td>Lan</td>
          </tr>
        </CompactTable>
        <ActionBar
          actions={[
            "Xem trước phiếu xuất",
            "Xuất / in phiếu xuất",
            "Phát hành phiếu xuất",
            "Mở lại phiếu xuất",
          ]}
        />
      </Panel>
    ),
    "Phiếu nhận hàng": (
      <Panel
        title="Phiếu nhận hàng"
        description="Biểu mẫu kiểm tra trước khi nhận hàng tại kho; không phải kết quả nhận thực tế. Kết quả thực tế nằm ở Nhập kho & xử lý chênh lệch."
      >
        <CompactTable
          headers={[
            "Trace ID",
            "Phiếu nhận hàng",
            "NCC",
            "PO",
            "Nguyên liệu",
            "SL dự kiến nhận",
            "Khung giờ nhận",
            "Người nhận dự kiến",
            "Trạng thái biểu mẫu",
            "Người phát hành",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>PNH-0714-008</td>
            <td>Thành Công Foods</td>
            <td>PO-0714-008</td>
            <td>Gạo Jasmine</td>
            <td>150 kg</td>
            <td>05:30–05:45</td>
            <td>Mai · Kho</td>
            <td>
              <Chip tone="warning">Bản nháp</Chip>
            </td>
            <td>Lan</td>
          </tr>
        </CompactTable>
        <ActionBar
          actions={[
            "Xem trước phiếu nhận",
            "Xuất / in phiếu nhận",
            "Phát hành phiếu nhận",
          ]}
        />
      </Panel>
    ),
    "Đối chiếu chứng từ": (
      <Panel
        title="Đối chiếu chứng từ"
        description="Nhu cầu xác nhận → PO → phiếu xuất → dự kiến nhận; các dòng lệch cần điều chỉnh hoặc mở lại."
      >
        <CompactTable
          headers={[
            "Trace ID",
            "Nhu cầu xác nhận",
            "SL PO",
            "SL Phiếu xuất",
            "SL dự kiến nhận",
            "Delta",
            "Trạng thái đối chiếu",
            "Lý do điều chỉnh / mở lại",
            "Phiên bản",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>250 kg</td>
            <td>250 kg</td>
            <td>240 kg</td>
            <td>250 kg</td>
            <td>-10 kg</td>
            <td>
              <Chip tone="danger">Lệch số lượng</Chip>
            </td>
            <td>Cần điều chỉnh phiếu xuất</td>
            <td>Lần 1</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>72 kg</td>
            <td>72 kg</td>
            <td>72 kg</td>
            <td>72 kg</td>
            <td>0</td>
            <td>
              <Chip tone="ok">Khớp</Chip>
            </td>
            <td>—</td>
            <td>Lần 1</td>
          </tr>
        </CompactTable>
      </Panel>
    ),
  };
  return (
    <>
      <div
        className="workbench-actions"
        role="tablist"
        aria-label="Không gian phát hành chứng từ"
      >
        {tabs.map((item) => (
          <button
            key={item}
            className={item === tab ? "primary" : ""}
            role="tab"
            aria-selected={item === tab}
            onClick={() => setTab(item)}
          >
            {item}
          </button>
        ))}
      </div>
      {body[tab]}
    </>
  );
}
export function WarehouseReceivingPage() {
  return (
    <>
      <Panel
        title="Kết quả nhận hàng theo NCC"
        description="Ghi nhận thực nhận, ngoại lệ, ảnh hưởng phía sau và hành động tiếp theo."
        status={<Chip tone="danger">2 cần xử lý</Chip>}
      >
        <CompactTable
          headers={[
            "Trace ID",
            "NCC / PO / Phân bổ",
            "Nguyên liệu",
            "Đơn vị nhận / Điểm giao",
            "Dự kiến",
            "Thực nhận",
            "Ngoại lệ",
            "Ảnh hưởng phía sau",
            "Bước tiếp",
            "Trạng thái bằng chứng",
            "Chủ xử lý",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>
              Thành Công Foods
              <br />
              <small>PO-0714-008 · PB-NCC-021</small>
            </td>
            <td>Gạo Jasmine</td>
            <td>
              <Recipient {...affected} />
            </td>
            <td>250 kg</td>
            <td>240 kg</td>
            <td>
              <Chip tone="danger">Thiếu hàng</Chip>
            </td>
            <td>Thiếu cho bếp Minh An 10 kg</td>
            <td>Thu mua · cần bổ sung</td>
            <td>
              <Chip tone="warning">Ảnh giao hàng chờ tải</Chip>
            </td>
            <td>Thu mua · Minh</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>
              An Phú Produce
              <br />
              <small>PO-0714-006 · PB-NCC-018</small>
            </td>
            <td>Bí đỏ</td>
            <td>
              <Recipient {...recipient} />
            </td>
            <td>72 kg</td>
            <td>72 kg</td>
            <td>
              <Chip tone="ok">Nhận đủ</Chip>
            </td>
            <td>Không ảnh hưởng</td>
            <td>Hoàn tất</td>
            <td>
              <Chip tone="ok">Đủ ảnh / ký nhận</Chip>
            </td>
            <td>Điều hành · Lan</td>
          </tr>
        </CompactTable>
      </Panel>
      <ActionBar
        actions={[
          "Ghi nhận thực nhận",
          "Ghi nhận chênh lệch",
          "Đánh dấu cần bổ sung",
          "Đánh dấu cần thay thế",
          "Báo Thu mua / BGĐ",
          "Đính kèm bằng chứng",
        ]}
      />
    </>
  );
}
export function SupportingPage({ page }: { page: AtlasPage }) {
  const recipe = page.id === "recipe-governance";
  return (
    <Panel
      title={page.label}
      description="Dữ liệu hỗ trợ và quản trị; không phải một bước vận hành hằng ngày."
      status={<Chip>Supporting / governance</Chip>}
    >
      {recipe ? (
        <div className="recipe-grid">
          <article>
            <b>Món / công thức</b>
            <strong>Canh bí đỏ · BOM hiện hành v3</strong>
            <small>Phạm vi: Trường Nguyễn Du · đang hiệu lực</small>
          </article>
          <article>
            <b>Đề xuất thay đổi</b>
            <strong>Điều chỉnh số lượng bí đỏ</strong>
            <small>Hiệu lực 21/07/2026 · xem trước ảnh hưởng</small>
          </article>
          <article>
            <b>Lịch sử</b>
            <strong>v2 → v3</strong>
            <small>Thay thế hành lá bằng ngò rí</small>
          </article>
        </div>
      ) : (
        <p className="supporting-copy">
          Đối tượng: {page.object}. Bàn giao: {page.handoff}. Prototype không
          thay đổi dữ liệu thực tế.
        </p>
      )}
    </Panel>
  );
}
