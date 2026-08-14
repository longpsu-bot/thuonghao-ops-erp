import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import type { MasterDataApi } from "../atlas/master-data/masterDataApi";
import {
  responseArray,
  resultMessage,
  schoolDefaultsBulkCommandRequest,
  type SchoolMasterData,
} from "../atlas/master-data/masterDataModel";

type LoadState =
  | { status: "idle" | "loading"; schools: SchoolMasterData[] }
  | { status: "ready"; schools: SchoolMasterData[] }
  | { status: "error"; schools: SchoolMasterData[]; message: string };

type SchoolDraft = {
  student: string;
  teacher: string;
};

type Notice = {
  tone: "success" | "warning" | "danger";
  message: string;
};

const MAX_PORTION_COUNT = 2_147_483_647;

function parsePortion(value: string) {
  const normalized = value.trim();
  if (!/^\d+$/.test(normalized)) return null;
  const parsed = Number(normalized);
  return Number.isSafeInteger(parsed) && parsed <= MAX_PORTION_COUNT
    ? parsed
    : null;
}

function matchesAuthoritative(draft: SchoolDraft, school: SchoolMasterData) {
  return (
    parsePortion(draft.student) === school.default_student_portions &&
    parsePortion(draft.teacher) === school.default_teacher_portions
  );
}

function reconcileDrafts(
  drafts: Record<string, SchoolDraft>,
  schools: SchoolMasterData[],
) {
  return Object.fromEntries(
    Object.entries(drafts).filter(([schoolId, draft]) => {
      const school = schools.find((item) => item.school_id === schoolId);
      return school ? !matchesAuthoritative(draft, school) : false;
    }),
  );
}

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
  const [drafts, setDrafts] = useState<Record<string, SchoolDraft>>({});
  const [saving, setSaving] = useState(false);
  const [mutationLocked, setMutationLocked] = useState(false);
  const [notice, setNotice] = useState<Notice | null>(null);
  const requestGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const refresh = useCallback(
    async ({ clearDrafts = false }: { clearDrafts?: boolean } = {}) => {
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
      setDrafts((current) =>
        clearDrafts ? {} : reconcileDrafts(current, schools),
      );
      setMutationLocked(false);
      return true;
    },
    [api, authSubject, correlationId],
  );

  useEffect(() => {
    requestGeneration.current += 1;
    setNotice(null);
    setDrafts({});
    setMutationLocked(false);
    if (authSubject) void refresh({ clearDrafts: true });
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

  const invalidDraftCount = Object.values(drafts).filter(
    (draft) =>
      parsePortion(draft.student) === null ||
      parsePortion(draft.teacher) === null,
  ).length;
  const dirtyCount = Object.keys(drafts).length;

  const draftFor = (school: SchoolMasterData): SchoolDraft =>
    drafts[school.school_id] ?? {
      student: String(school.default_student_portions),
      teacher: String(school.default_teacher_portions),
    };

  const edit = (
    school: SchoolMasterData,
    field: keyof SchoolDraft,
    value: string,
  ) => {
    setNotice(null);
    setDrafts((current) => {
      const nextDraft = {
        ...(current[school.school_id] ?? {
          student: String(school.default_student_portions),
          teacher: String(school.default_teacher_portions),
        }),
        [field]: value,
      };
      if (matchesAuthoritative(nextDraft, school)) {
        const next = { ...current };
        delete next[school.school_id];
        return next;
      }
      return { ...current, [school.school_id]: nextDraft };
    });
  };

  const discard = () => {
    setDrafts({});
    setNotice(null);
  };

  const reloadForReview = async () => {
    setNotice(null);
    const refreshed = await refresh();
    if (refreshed) {
      setNotice({
        tone: "warning",
        message:
          "Đã tải lại dữ liệu chính thức. Hãy kiểm tra các thay đổi còn lại trước khi lưu.",
      });
    }
  };

  const save = async () => {
    if (
      !api ||
      !authSubject ||
      saving ||
      mutationLocked ||
      dirtyCount === 0 ||
      invalidDraftCount > 0
    )
      return;

    const changes = Object.entries(drafts).flatMap(([schoolId, draft]) => {
      const school = load.schools.find((item) => item.school_id === schoolId);
      const student = parsePortion(draft.student);
      const teacher = parsePortion(draft.teacher);
      if (!school || student === null || teacher === null) return [];
      return [
        {
          school_id: school.school_id,
          expected_version: school.version,
          default_student_portions: student,
          default_teacher_portions: teacher,
        },
      ];
    });

    if (changes.length !== dirtyCount) return;
    setSaving(true);
    setNotice(null);
    const result = await api.updateSchoolDefaultsBulk(
      schoolDefaultsBulkCommandRequest(authSubject, correlationId, changes),
    );
    setSaving(false);

    if (result.kind === "transport_error") {
      setMutationLocked(true);
      setNotice({
        tone: "danger",
        message:
          "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa. Hãy tải lại dữ liệu chính thức trước khi lưu tiếp.",
      });
      return;
    }

    if (result.kind === "success") {
      const refreshed = await refresh({ clearDrafts: true });
      if (refreshed) {
        setNotice({
          tone: "success",
          message: `Đã cập nhật ${changes.length} trường và tải lại dữ liệu chính thức.`,
        });
      } else {
        setMutationLocked(true);
        setNotice({
          tone: "warning",
          message:
            "Đã lưu nhưng chưa tải lại được dữ liệu chính thức. Hãy tải lại trước khi tiếp tục.",
        });
      }
      return;
    }

    setNotice({
      tone: result.kind === "backend_error" ? "warning" : "danger",
      message:
        result.kind === "backend_error" &&
        result.error.error_code === "STALE_VERSION"
          ? "Một hoặc nhiều trường đã được người khác cập nhật. Không có trường nào được lưu; hãy tải lại và kiểm tra thay đổi."
          : resultMessage(result),
    });
  };

  const authMessage =
    authState.status === "session_expired"
      ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục."
      : "Đăng nhập để xem và cập nhật dữ liệu trường học.";

  return (
    <Panel
      title="Sĩ số mặc định"
      description="Tìm trường, sửa trực tiếp sĩ số học sinh và giáo viên, rồi lưu tất cả thay đổi một lần."
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
            <button
              type="button"
              disabled={saving || load.status === "loading"}
              onClick={() => void reloadForReview()}
            >
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
              <button type="button" onClick={() => void reloadForReview()}>
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

          {schools.length > 0 && (
            <div className="master-data-table-scroll school-defaults-table">
              <CompactTable
                headers={[
                  "Trường",
                  "Loại trường",
                  "Điểm giao",
                  "Học sinh mặc định",
                  "Giáo viên mặc định",
                ]}
              >
                {schools.map((school) => {
                  const draft = draftFor(school);
                  const studentInvalid = parsePortion(draft.student) === null;
                  const teacherInvalid = parsePortion(draft.teacher) === null;
                  const dirty = Boolean(drafts[school.school_id]);
                  return (
                    <tr
                      key={school.school_id}
                      className={dirty ? "school-default-dirty" : undefined}
                    >
                      <td>
                        <b>{school.school_name}</b>
                        <small>
                          {school.school_code} · {school.customer_name}
                        </small>
                      </td>
                      <td>{school.school_type_name ?? "Chưa phân loại"}</td>
                      <td>
                        {school.delivery_location_name}
                        <small>{school.delivery_address}</small>
                      </td>
                      <td>
                        <input
                          className="school-default-input"
                          type="number"
                          inputMode="numeric"
                          min="0"
                          step="1"
                          aria-label={`Học sinh mặc định — ${school.school_name}`}
                          aria-invalid={studentInvalid}
                          disabled={saving || mutationLocked}
                          value={draft.student}
                          onChange={(event) =>
                            edit(school, "student", event.target.value)
                          }
                        />
                        {studentInvalid && (
                          <small className="school-default-error">
                            Nhập số nguyên không âm.
                          </small>
                        )}
                      </td>
                      <td>
                        <input
                          className="school-default-input"
                          type="number"
                          inputMode="numeric"
                          min="0"
                          step="1"
                          aria-label={`Giáo viên mặc định — ${school.school_name}`}
                          aria-invalid={teacherInvalid}
                          disabled={saving || mutationLocked}
                          value={draft.teacher}
                          onChange={(event) =>
                            edit(school, "teacher", event.target.value)
                          }
                        />
                        {teacherInvalid && (
                          <small className="school-default-error">
                            Nhập số nguyên không âm.
                          </small>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </CompactTable>
            </div>
          )}

          <div className="school-defaults-savebar" aria-live="polite">
            <p>
              {dirtyCount > 0
                ? `${dirtyCount} trường đã thay đổi`
                : "Chưa có thay đổi"}
              {invalidDraftCount > 0 &&
                ` · ${invalidDraftCount} trường cần kiểm tra`}
            </p>
            <div className="workbench-actions">
              <button
                type="button"
                disabled={saving || mutationLocked || dirtyCount === 0}
                onClick={discard}
              >
                Hủy thay đổi
              </button>
              <button
                type="button"
                className="primary"
                disabled={
                  saving ||
                  mutationLocked ||
                  dirtyCount === 0 ||
                  invalidDraftCount > 0
                }
                onClick={() => void save()}
              >
                {saving ? "Đang lưu…" : "Lưu"}
              </button>
            </div>
          </div>

          {notice && (
            <div
              className={`operator-notice ${notice.tone}`}
              role={notice.tone === "danger" ? "alert" : "status"}
            >
              <p>{notice.message}</p>
              {mutationLocked && (
                <button type="button" onClick={() => void reloadForReview()}>
                  Tải lại dữ liệu chính thức
                </button>
              )}
            </div>
          )}
        </>
      )}
    </Panel>
  );
}
