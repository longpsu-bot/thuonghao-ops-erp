import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  responseArray,
  resultMessage,
  schoolDefaultsBulkCommandRequest,
  type AtlasRpcResult,
  type SchoolMasterData,
  type SchoolMasterDataApi,
} from "../bridges/schoolMasterData";
import {
  applySchoolDraftEdit,
  countHiddenDraftSchools,
  countInvalidDraftSchools,
  createSchoolDefaultsReview,
  filterAndOrderSchools,
  reconcileSchoolDrafts,
  type SchoolDefaultsDrafts,
  type SchoolDefaultsReviewRow,
} from "./schoolDefaultsModel";

type LoadState = {
  loading: boolean;
  schools: SchoolMasterData[];
  error: string | null;
};

export type SchoolDefaultsLock = "stale" | "unknown" | "readback" | null;

export type SchoolDefaultsWorkbenchProps = {
  authSubject: string | null;
  api: SchoolMasterDataApi;
};

export function useSchoolDefaultsWorkbench({
  authSubject,
  api,
}: SchoolDefaultsWorkbenchProps) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [load, setLoad] = useState<LoadState>({
    loading: false,
    schools: [],
    error: null,
  });
  const [query, setQuery] = useState("");
  const [schoolType, setSchoolType] = useState("ALL");
  const [drafts, setDrafts] = useState<SchoolDefaultsDrafts>({});
  const [review, setReview] = useState<SchoolDefaultsReviewRow[] | null>(null);
  const [saving, setSaving] = useState(false);
  const [lock, setLock] = useState<SchoolDefaultsLock>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const requestGeneration = useRef(0);

  const readAuthority = useCallback(
    async (purpose: "initial" | "routine" | "recovery" | "readback") => {
      if (!authSubject) return false;
      const generation = ++requestGeneration.current;
      setLoad((current) => ({ ...current, loading: true, error: null }));
      const result = await api.getSchools(authSubject, correlationId);
      if (generation !== requestGeneration.current) return false;
      const schools = responseArray<SchoolMasterData>(result, "schools");
      if (!schools) {
        setLoad((current) => ({
          ...current,
          loading: false,
          error: resultMessage(result),
        }));
        if (purpose === "readback") {
          setLock("readback");
          setNotice(
            "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
          );
        }
        return false;
      }
      setLoad({ loading: false, schools, error: null });
      setDrafts((current) => reconcileSchoolDrafts(current, schools));
      setReview(null);
      setLock(null);
      if (purpose === "routine" || purpose === "recovery") {
        setNotice(
          "Đã tải lại dữ liệu chính thức. Kiểm tra các thay đổi chưa lưu trước khi lưu.",
        );
      }
      return true;
    },
    [api, authSubject, correlationId],
  );

  useEffect(() => {
    requestGeneration.current += 1;
    setLoad({ loading: false, schools: [], error: null });
    setDrafts({});
    setReview(null);
    setLock(null);
    setNotice(null);
    setSaving(false);
    setQuery("");
    setSchoolType("ALL");
    if (authSubject) void readAuthority("initial");
  }, [authSubject, readAuthority]);

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
  const visibleSchools = useMemo(
    () => filterAndOrderSchools(load.schools, query, schoolType),
    [load.schools, query, schoolType],
  );
  const invalidDraftCount = countInvalidDraftSchools(drafts);
  const dirtyCount = Object.keys(drafts).length;
  const hiddenDirtyCount = countHiddenDraftSchools(drafts, visibleSchools);

  const edit = (
    school: SchoolMasterData,
    field: "student" | "teacher",
    value: string,
  ) => {
    setNotice(null);
    setReview(null);
    setDrafts((current) => applySchoolDraftEdit(current, school, field, value));
  };

  const openReview = () => {
    if (saving || lock || !dirtyCount || invalidDraftCount) return;
    setReview(createSchoolDefaultsReview(load.schools, drafts));
  };

  const save = async () => {
    if (!authSubject || !review?.length || saving || lock) return;
    const reviewed = review;
    const changes = reviewed.map((row) => ({
      school_id: row.school_id,
      expected_version: row.expected_version,
      default_student_portions: row.new_student_portions,
      default_teacher_portions: row.new_teacher_portions,
    }));
    setSaving(true);
    setNotice(null);
    const saveGeneration = requestGeneration.current;
    const result: AtlasRpcResult = await api.updateSchoolDefaultsBulk(
      schoolDefaultsBulkCommandRequest(authSubject, correlationId, changes),
    );
    if (saveGeneration !== requestGeneration.current) return;
    setReview(null);
    if (result.kind === "transport_error") {
      setSaving(false);
      setLock("unknown");
      setNotice("Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.");
      return;
    }
    if (result.kind === "success") {
      const current = await readAuthority("readback");
      setSaving(false);
      if (current) setNotice(`Đã cập nhật ${changes.length} trường.`);
      return;
    }
    setSaving(false);
    if (
      result.kind === "backend_error" &&
      result.error.error_code === "STALE_VERSION"
    ) {
      setLock("stale");
      setNotice(
        "Một hoặc nhiều trường đã được cập nhật. Không có trường nào được lưu; hãy tải lại và kiểm tra thay đổi.",
      );
      return;
    }
    setNotice(resultMessage(result));
  };

  return {
    ...load,
    query,
    setQuery,
    schoolType,
    setSchoolType,
    schoolTypes,
    visibleSchools,
    drafts,
    dirtyCount,
    invalidDraftCount,
    hiddenDirtyCount,
    review,
    saving,
    lock,
    notice,
    edit,
    openReview,
    closeReview: () => !saving && setReview(null),
    refresh: () => readAuthority(lock ? "recovery" : "routine"),
    save,
  };
}

export type SchoolDefaultsController = ReturnType<
  typeof useSchoolDefaultsWorkbench
>;
