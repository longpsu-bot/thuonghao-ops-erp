import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Modal } from "@mantine/core";
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

type SchoolDefaultsReview = {
  school_id: string;
  expected_version: number;
  current_student_portions: number;
  new_student_portions: number;
  current_teacher_portions: number;
  new_teacher_portions: number;
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
  const [reviewSnapshot, setReviewSnapshot] = useState<
    SchoolDefaultsReview[] | null
  >(null);
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
      setReviewSnapshot(null);
      setMutationLocked(false);
      return true;
    },
    [api, authSubject, correlationId],
  );

  useEffect(() => {
    requestGeneration.current += 1;
    setNotice(null);
    setDrafts({});
    setReviewSnapshot(null);
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
    setReviewSnapshot(null);
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
    setReviewSnapshot(null);
    setNotice(null);
  };

  const reloadForReview = async () => {
    setNotice(null);
    setReviewSnapshot(null);
    const refreshed = await refresh();
    if (refreshed) {
      setNotice({
        tone: "warning",
        message:
          "Đã tải lại dữ liệu chính thức. Hãy kiểm tra các thay đổi còn lại trước khi lưu.",
      });
    }
  };

  const openReview = () => {
    if (saving || mutationLocked || dirtyCount === 0 || invalidDraftCount > 0)
      return;

    const snapshot = load.schools.flatMap((school) => {
      const draft = drafts[school.school_id];
      if (!draft) return [];
      const student = parsePortion(draft.student);
      const teacher = parsePortion(draft.teacher);
      if (student === null || teacher === null) return [];
      return [
        {
          school_id: school.school_id,
          expected_version: school.version,
          current_student_portions: school.default_student_portions,
          new_student_portions: student,
          current_teacher_portions: school.default_teacher_portions,
          new_teacher_portions: teacher,
        },
      ];
    });

    if (snapshot.length !== dirtyCount) return;
    setReviewSnapshot(snapshot);
  };

  const closeReview = () => {
    if (!saving) setReviewSnapshot(null);
  };

  const saveReviewed = async () => {
    if (
      !api ||
      !authSubject ||
      saving ||
      mutationLocked ||
      !reviewSnapshot ||
      reviewSnapshot.length === 0
    )
      return;

    const reviewedChanges = reviewSnapshot.map((change) => ({
      school_id: change.school_id,
      expected_version: change.expected_version,
      default_student_portions: change.new_student_portions,
      default_teacher_portions: change.new_teacher_portions,
    }));
    setSaving(true);
    setNotice(null);
    const result = await api.updateSchoolDefaultsBulk(
      schoolDefaultsBulkCommandRequest(
        authSubject,
        correlationId,
        reviewedChanges,
      ),
    );
    setSaving(false);

    if (result.kind === "transport_error") {
      setReviewSnapshot(null);
      setMutationLocked(true);
      setNotice({
        tone: "danger",
        message:
          "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa. Hãy tải lại dữ liệu chính thức trước khi lưu tiếp.",
      });
      return;
    }

    if (result.kind === "success") {
      setReviewSnapshot(null);
      const refreshed = await refresh({ clearDrafts: true });
      if (refreshed) {
        setNotice({
          tone: "success",
          message: `Đã cập nhật ${reviewedChanges.length} trường và tải lại dữ liệu chính thức.`,
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

    setReviewSnapshot(null);
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
      description="Tìm trường, sửa trực tiếp sĩ số học sinh và giáo viên, xem lại thay đổi, rồi lưu một lần."
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
                onClick={openReview}
              >
                Xem thay đổi
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

          <Modal
            opened={reviewSnapshot !== null}
            onClose={closeReview}
            title="Xem thay đổi"
            size="900px"
            centered
            xOffset="20px"
            yOffset="20px"
            closeOnClickOutside={!saving}
            closeOnEscape={!saving}
            withCloseButton={!saving}
            styles={{
              content: { maxHeight: "86dvh", overflowX: "hidden" },
              body: {
                maxHeight: "calc(86dvh - 64px)",
                overflowY: "auto",
                overflowX: "hidden",
              },
            }}
          >
            <p className="school-default-review-intro">
              Kiểm tra các giá trị sẽ được lưu cho tất cả trường đã thay đổi.
            </p>
            <table className="school-default-review-table">
              <thead>
                <tr>
                  <th>Trường</th>
                  <th>Học sinh hiện tại</th>
                  <th>Học sinh sau</th>
                  <th>Giáo viên hiện tại</th>
                  <th>Giáo viên sau</th>
                </tr>
              </thead>
              <tbody>
                {(reviewSnapshot ?? []).map((change) => {
                  const school = load.schools.find(
                    (item) => item.school_id === change.school_id,
                  );
                  const studentChanged =
                    change.current_student_portions !==
                    change.new_student_portions;
                  const teacherChanged =
                    change.current_teacher_portions !==
                    change.new_teacher_portions;
                  return (
                    <tr key={change.school_id}>
                      <td data-label="Trường">
                        <b>{school?.school_name ?? "Trường học"}</b>
                        {school?.school_code && (
                          <small>{school.school_code}</small>
                        )}
                      </td>
                      <td data-label="Học sinh hiện tại">
                        {change.current_student_portions}
                      </td>
                      <td
                        data-label="Học sinh sau"
                        className={
                          studentChanged
                            ? "school-default-review-after changed"
                            : "school-default-review-after unchanged"
                        }
                      >
                        {change.new_student_portions}
                      </td>
                      <td data-label="Giáo viên hiện tại">
                        {change.current_teacher_portions}
                      </td>
                      <td
                        data-label="Giáo viên sau"
                        className={
                          teacherChanged
                            ? "school-default-review-after changed"
                            : "school-default-review-after unchanged"
                        }
                      >
                        {change.new_teacher_portions}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            <div className="workbench-actions school-default-review-actions">
              <button type="button" disabled={saving} onClick={closeReview}>
                Quay lại
              </button>
              <button
                type="button"
                className="primary"
                disabled={saving || mutationLocked || !reviewSnapshot?.length}
                onClick={() => void saveReviewed()}
              >
                {saving ? "Đang lưu…" : "Lưu"}
              </button>
            </div>
          </Modal>
        </>
      )}
    </Panel>
  );
}
