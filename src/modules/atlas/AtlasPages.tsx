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
    ["Nhu cầu chưa nhập thực tế", "12", "Lập nhu cầu"],
    ["Nhu cầu chờ xác nhận", "8", "Lập nhu cầu"],
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
export function RequirementPlanningPage() {
  return (
    <>
      <Panel
        title="Dòng nhu cầu thực tế"
        description="Nhu cầu tính toán → nhu cầu thực tế → chênh lệch → xác nhận → bàn giao mua hàng."
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
            "Ngày",
            "Đơn vị nhận / Điểm giao",
            "Món",
            "Nguyên liệu",
            "ĐVT",
            "Tính toán",
            "Thực tế",
            "Chênh lệch",
            "Nguồn",
            "Trạng thái",
            "Lý do / ghi chú",
            "Bàn giao Thu mua",
            "Người nhập thực tế",
            "Người xác nhận",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
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
            <td>Thực đơn</td>
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
            <td>Hàng đặt riêng</td>
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
        </CompactTable>
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
  const cards = [
    [
      "Đơn đặt nhà cung cấp / PO Release",
      "Ready to release",
      "Gạo Jasmine · 150 kg · giao 05:30",
      "Có thể chỉnh phân bổ, giờ giao và ghi chú trước phát hành.",
    ],
    [
      "Phiếu xuất kho / Dispatch Order Release",
      "Draft",
      "PXK-0714-ND · Bí đỏ · 72 kg",
      "Chờ rà soát điểm giao và số lượng xuất.",
    ],
    [
      "Đối chiếu PO và Phiếu xuất kho",
      "MISMATCH",
      "Nhu cầu 250 kg · PO 250 kg · phiếu 240 kg",
      "Lệch -10 kg; cần revision trước phát hành lại.",
    ],
  ];
  return (
    <>
      <div className="release-grid">
        {cards.map(([title, status, value, detail]) => (
          <Panel
            key={title}
            title={title}
            status={
              <Chip tone={status === "MISMATCH" ? "danger" : "warning"}>
                {status}
              </Chip>
            }
          >
            <ul className="release-list">
              <li>{value}</li>
              <li>{detail}</li>
              <li>Trạng thái in / xuất: prototype</li>
            </ul>
          </Panel>
        ))}
      </div>
      <Panel
        title="Đối chiếu phát hành theo Trace ID"
        description="Kiểm tra nhu cầu đã xác nhận, PO và Phiếu xuất kho trước khi bàn giao nhập kho."
      >
        <CompactTable
          headers={[
            "Trace ID",
            "PO",
            "Phiếu xuất kho",
            "Nhu cầu xác nhận",
            "SL PO",
            "SL Phiếu xuất",
            "Delta",
            "Trạng thái phát hành",
            "Lý do revision / mở lại",
            "Phiên bản",
          ]}
        >
          <tr>
            <td>OPS-2026-0714-MA-GAO-001</td>
            <td>PO-0714-008</td>
            <td>PXK-0714-MA</td>
            <td>250 kg</td>
            <td>250 kg</td>
            <td>240 kg</td>
            <td>-10 kg</td>
            <td>
              <Chip tone="danger">Needs revision</Chip>
            </td>
            <td>Thiếu 10 kg so với PO; mở lại để bổ sung</td>
            <td>Lần phát hành 1</td>
          </tr>
          <tr>
            <td>OPS-2026-0714-ND-BIDO-001</td>
            <td>PO-0714-006</td>
            <td>PXK-0714-ND</td>
            <td>72 kg</td>
            <td>72 kg</td>
            <td>75 kg</td>
            <td>+3 kg</td>
            <td>
              <Chip tone="warning">Reopened</Chip>
            </td>
            <td>Điều chỉnh PXK theo điểm giao</td>
            <td>Lần phát hành 1</td>
          </tr>
        </CompactTable>
      </Panel>
      <ActionBar
        actions={[
          "Phát hành PO",
          "Phát hành Phiếu xuất kho",
          "Xuất file / in",
          "Mở lại để điều chỉnh",
          "Xem chênh lệch",
          "Ghi chú lý do phát hành lại",
        ]}
      />
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
