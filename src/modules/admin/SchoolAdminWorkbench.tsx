import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import type { MasterDataApi } from "../atlas/master-data/masterDataApi";
import {
  commandRequest,
  responseArray,
  resultMessage,
  type SchoolMasterData,
} from "../atlas/master-data/masterDataModel";

type LoadState =
  | { status: "idle" | "loading"; schools: SchoolMasterData[] }
  | { status: "ready"; schools: SchoolMasterData[] }
  | { status: "error"; schools: SchoolMasterData[]; message: string };

export function SchoolAdminWorkbench({
  authState,
  api,
  mode = "connected",
}: {
  authState: AtlasAuthState;
  api?: MasterDataApi;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [load, setLoad] = useState<LoadState>({
    status: "idle",
    schools: [],
  });
  const [query, setQuery] = useState("");
  const [schoolType, setSchoolType] = useState("ALL");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [studentPortions, setStudentPortions] = useState("");
  const [teacherPortions, setTeacherPortions] = useState("");
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const requestGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return false;
    const generation = ++requestGeneration.current;
    setLoad((current) => ({
      status: "loading",
      schools: current.schools,
    }));
    const result = await api.getSchools(authSubject, correlationId);
    if (generation !== requestGeneration.current) return false;
    const schools = responseArray<SchoolMasterData>(result, "schools");
    if (!schools) {
      setLoad((current) => ({
        status: "error",
        schools: current.schools,
        message: resultMessage(result),
      }));
      return false;
    }
    setLoad({ status: "ready", schools });
    return true;
  }, [api, authSubject, correlationId]);

  useEffect(() => {
    requestGeneration.current += 1;
    setNotice(null);
    setSelectedId(null);
    if (authSubject) void refresh();
    else setLoad({ status: "idle", schools: [] });
  }, [authSubject, refresh]);

  const schoolTypes = useMemo(
    () =>
      Array.from(
        new Set(
          load.schools.flatMap((school) =>
            school.school_type_name ? [school.school_type_name] : [],
          ),
        ),
      ).sort((a, b) => a.localeCompare(b, "vi")),
    [load.schools],
  );

  const schools = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("vi");
    return load.schools.filter(
      (school) =>
        (schoolType === "ALL" || school.school_type_name === schoolType) &&
        (!normalized ||
          [
            school.school_name,
            school.school_code,
            school.school_type_name,
            school.customer_name,
            school.delivery_location_name,
          ].some((value) =>
            (value ?? "").toLocaleLowerCase("vi").includes(normalized),
          )),
    );
  }, [load.schools, query, schoolType]);

  const selected = load.schools.find(
    (school) => school.school_id === selectedId,
  );

  const beginEdit = (school: SchoolMasterData) => {
    setSelectedId(school.school_id);
    setStudentPortions(String(school.default_student_portions));
    setTeacherPortions(String(school.default_teacher_portions));
    setNotice(null);
  };

  const save = async () => {
    if (!api || !authSubject || !selected) return;
    const student = Number(studentPortions);
    const teacher = Number(teacherPortions);
    if (
      !Number.isInteger(student) ||
      !Number.isInteger(teacher) ||
      student < 0 ||
      teacher < 0
    ) {
      setNotice("Số suất mặc định phải là số nguyên không âm.");
      return;
    }
    setSaving(true);
    const result = await api.updateSchoolDefaults(
      commandRequest(
        authSubject,
        correlationId,
        selected.version,
        "SCHOOL_PORTION_DEFAULTS_UPDATE",
        {
          school_id: selected.school_id,
          default_student_portions: student,
          default_teacher_portions: teacher,
        },
      ),
    );
    setSaving(false);
    setNotice(resultMessage(result));
    if (result.kind === "success") {
      await refresh();
      setSelectedId(null);
    }
  };

  const authMessage =
    authState.status === "session_expired"
      ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục."
      : "Đăng nhập để xem và cập nhật dữ liệu trường học.";

  return (
    <Panel
      title="Danh sách trường học"
      description="Tìm kiếm, kiểm tra bối cảnh giao hàng và cập nhật sĩ số mặc định."
      status={
        <Chip tone={authSubject && load.status !== "error" ? "ok" : "warning"}>
          {authSubject
            ? mode === "review"
              ? "Dữ liệu xem thử"
              : "Đã kết nối"
            : "Cần đăng nhập"}
        </Chip>
      }
    >
      {!authSubject ? (
        <p className="operator-notice warning">{authMessage}</p>
      ) : (
        <>
          <div className="master-data-toolbar schools-toolbar">
            <label className="evidence-field">
              Tìm trường
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Tên, mã, loại trường hoặc điểm giao"
              />
            </label>
            <label className="evidence-field">
              Loại trường
              <select
                value={schoolType}
                onChange={(event) => setSchoolType(event.target.value)}
              >
                <option value="ALL">Tất cả</option>
                {schoolTypes.map((type) => (
                  <option value={type} key={type}>
                    {type}
                  </option>
                ))}
              </select>
            </label>
            <button type="button" onClick={() => void refresh()}>
              Tải lại
            </button>
          </div>

          <div className="master-data-summary" aria-label="Tổng hợp trường học">
            <span>
              <b>{load.schools.length}</b> trường
            </span>
            <span>
              <b>
                {
                  load.schools.filter(
                    (school) => school.school_status === "ACTIVE",
                  ).length
                }
              </b>{" "}
              đang hoạt động
            </span>
            <span>
              <b>{schools.length}</b> kết quả đang hiển thị
            </span>
          </div>

          {load.status === "loading" && load.schools.length === 0 && (
            <p role="status" className="empty">
              Đang tải dữ liệu trường học…
            </p>
          )}
          {load.status === "error" && (
            <div className="command-outcome danger" role="alert">
              <p>{load.message}</p>
              <button type="button" onClick={() => void refresh()}>
                Thử lại
              </button>
            </div>
          )}
          {load.status === "ready" && load.schools.length === 0 && (
            <p className="empty">Chưa có trường học.</p>
          )}
          {load.schools.length > 0 && schools.length === 0 && (
            <p className="empty">Không có trường phù hợp bộ lọc.</p>
          )}

          <div
            className={`master-data-workspace ${selected ? "with-detail" : ""}`}
          >
            {schools.length > 0 && (
              <div className="master-data-table-scroll">
                <CompactTable
                  headers={[
                    "Trường",
                    "Loại / thứ tự",
                    "Bối cảnh giao hàng",
                    "Hợp đồng",
                    "Suất HS / GV",
                    "Thao tác",
                  ]}
                >
                  {schools.map((school) => (
                    <tr
                      key={school.school_id}
                      className={
                        school.school_id === selectedId ? "selected-row" : ""
                      }
                    >
                      <td>
                        <b>{school.school_name}</b>
                        <small>
                          {school.school_code} · {school.customer_name}
                        </small>
                      </td>
                      <td>
                        {school.school_type_name ?? "Chưa phân loại"}
                        <small>Thứ tự: {school.display_order}</small>
                      </td>
                      <td>
                        {school.delivery_location_name}
                        <small>{school.delivery_address}</small>
                        <small>
                          {school.delivery_instructions ??
                            "Không có ghi chú giao"}
                        </small>
                      </td>
                      <td>{school.contract_context ?? "Chưa có thông tin"}</td>
                      <td>
                        {school.default_student_portions} /{" "}
                        {school.default_teacher_portions}
                      </td>
                      <td>
                        <button
                          type="button"
                          className="inline-action"
                          onClick={() => beginEdit(school)}
                        >
                          Xem và sửa
                        </button>
                      </td>
                    </tr>
                  ))}
                </CompactTable>
              </div>
            )}

            {selected && (
              <aside
                className="master-data-detail"
                aria-label="Sửa số suất mặc định"
              >
                <div className="master-data-detail-heading">
                  <div>
                    <span>{selected.school_code}</span>
                    <h3>{selected.school_name}</h3>
                  </div>
                  <button
                    type="button"
                    aria-label="Đóng"
                    onClick={() => setSelectedId(null)}
                  >
                    ×
                  </button>
                </div>
                <dl className="master-data-detail-list">
                  <div>
                    <dt>Loại trường</dt>
                    <dd>{selected.school_type_name ?? "Chưa phân loại"}</dd>
                  </div>
                  <div>
                    <dt>Điểm giao</dt>
                    <dd>{selected.delivery_location_name}</dd>
                  </div>
                  <div>
                    <dt>Địa chỉ</dt>
                    <dd>{selected.delivery_address}</dd>
                  </div>
                  <div>
                    <dt>Hợp đồng</dt>
                    <dd>{selected.contract_context ?? "Chưa có thông tin"}</dd>
                  </div>
                </dl>
                <div className="master-data-detail-form">
                  <h4>Sĩ số mặc định</h4>
                  <label className="evidence-field">
                    Suất học sinh mặc định
                    <input
                      type="number"
                      min="0"
                      step="1"
                      value={studentPortions}
                      onChange={(event) =>
                        setStudentPortions(event.target.value)
                      }
                    />
                  </label>
                  <label className="evidence-field">
                    Suất giáo viên mặc định
                    <input
                      type="number"
                      min="0"
                      step="1"
                      value={teacherPortions}
                      onChange={(event) =>
                        setTeacherPortions(event.target.value)
                      }
                    />
                  </label>
                </div>
                <div className="workbench-actions">
                  <button
                    type="button"
                    className="primary"
                    disabled={saving}
                    onClick={() => void save()}
                  >
                    {saving ? "Đang lưu…" : "Lưu thay đổi"}
                  </button>
                  <button type="button" onClick={() => setSelectedId(null)}>
                    Hủy
                  </button>
                </div>
              </aside>
            )}
          </div>

          {notice && (
            <p
              className={
                notice.includes("không") ||
                notice.includes("thay đổi") ||
                notice.includes("hết")
                  ? "operator-notice warning"
                  : "operator-notice success"
              }
              role="status"
            >
              {notice}
            </p>
          )}
        </>
      )}
    </Panel>
  );
}
