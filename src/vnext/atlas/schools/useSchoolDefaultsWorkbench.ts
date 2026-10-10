import type { AtlasModuleExitProps } from "../AtlasModuleExit";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  commandRequest,
  type CookingGroupMasterData,
  type MasterDataCommandRequest,
  responseArray,
  resultMessage,
  schoolDefaultsBulkCommandRequest,
  type AtlasRpcResult,
  type SchoolMasterData,
  type SchoolMasterDataApi,
} from "../bridges/schoolMasterData";
import {
  applySchoolDraftEdit,
  countInvalidDraftSchools,
  createSchoolDefaultsReview,
  filterAndOrderSchools,
  reconcileSchoolDrafts,
  type SchoolDefaultsDrafts,
} from "./schoolDefaultsModel";

type LoadState = {
  loading: boolean;
  schools: SchoolMasterData[];
  error: string | null;
};

export type SchoolDefaultsLock = "stale" | "unknown" | "readback" | null;

export type SchoolDefaultsWorkbenchProps = AtlasModuleExitProps & {
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
  const [saving, setSaving] = useState(false);
  const [lock, setLock] = useState<SchoolDefaultsLock>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const cookingSupported = Boolean(
    api.getCookingGroups && api.upsertCookingGroup && api.setSchoolCookingGroup,
  );
  const [cookingGroups, setCookingGroups] = useState<CookingGroupMasterData[]>(
    [],
  );
  const [cookingDrafts, setCookingDrafts] = useState<Record<string, string>>(
    {},
  );
  const [groupEditor, setGroupEditor] = useState({
    id: "",
    name: "",
    active: true,
  });
  const [groupDirty, setGroupDirty] = useState(false);
  const pendingGroup = useRef<{
    editor: typeof groupEditor;
    request: MasterDataCommandRequest;
    groupId: string | null;
    confirmed: boolean;
  } | null>(null);
  const requestGeneration = useRef(0);
  const [pendingExit, setPendingExit] = useState<{ next: () => void } | null>(
    null,
  );

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
      if (cookingSupported && api.getCookingGroups) {
        const groupResult = await api.getCookingGroups(
          authSubject,
          correlationId,
        );
        if (generation !== requestGeneration.current) return false;
        const groups = responseArray<CookingGroupMasterData>(
          groupResult,
          "cooking_groups",
        );
        if (!groups) {
          setLoad((current) => ({
            ...current,
            loading: false,
            error: resultMessage(groupResult),
          }));
          if (purpose === "readback") {
            setLock("readback");
            setNotice(
              "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức.",
            );
          }
          return false;
        }
        setCookingGroups(groups);
        const pending = pendingGroup.current;
        if (
          pending &&
          groups.some(
            (group) =>
              group.cooking_group_id === pending.groupId &&
              (pending.confirmed ||
                (group.cooking_group_name === pending.editor.name.trim() &&
                  group.active === pending.editor.active)),
          )
        ) {
          setGroupDirty(false);
          setGroupEditor({ id: "", name: "", active: true });
          pendingGroup.current = null;
        }
      }
      setLoad({ loading: false, schools, error: null });
      setDrafts((current) => reconcileSchoolDrafts(current, schools));
      setCookingDrafts((current) =>
        Object.fromEntries(
          Object.entries(current).filter(([id, groupId]) => {
            const school = schools.find((row) => row.school_id === id);
            return school && (school.cooking_group_id ?? "") !== groupId;
          }),
        ),
      );
      if (pendingGroup.current) {
        setLock(pendingGroup.current.groupId ? "readback" : "unknown");
        setNotice(
          pendingGroup.current.groupId
            ? "Đã gửi lệnh lưu nhưng chưa tải lại được dữ liệu chính thức."
            : "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.",
        );
        return false;
      }
      setLock(null);
      if (purpose === "routine" || purpose === "recovery") {
        setNotice(
          "Đã tải lại dữ liệu chính thức. Kiểm tra các thay đổi chưa lưu trước khi lưu.",
        );
      }
      return true;
    },
    [api, authSubject, correlationId, cookingSupported],
  );

  useEffect(() => {
    requestGeneration.current += 1;
    setLoad({ loading: false, schools: [], error: null });
    setDrafts({});
    setCookingDrafts({});
    setCookingGroups([]);
    setGroupEditor({ id: "", name: "", active: true });
    setGroupDirty(false);
    pendingGroup.current = null;
    setLock(null);
    setNotice(null);
    setSaving(false);
    setQuery("");
    setSchoolType("ALL");
    setPendingExit(null);
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
  const portionDirtyCount = Object.keys(drafts).length;
  const dirtyCount =
    new Set([...Object.keys(drafts), ...Object.keys(cookingDrafts)]).size +
    Number(groupDirty);
  const visibleSchoolIds = new Set(
    visibleSchools.map((school) => school.school_id),
  );
  const hiddenDirtyCount = [
    ...new Set([...Object.keys(drafts), ...Object.keys(cookingDrafts)]),
  ].filter((id) => !visibleSchoolIds.has(id)).length;

  const edit = (
    school: SchoolMasterData,
    field: "student" | "teacher",
    value: string,
  ) => {
    setNotice(null);
    setDrafts((current) => applySchoolDraftEdit(current, school, field, value));
  };

  const save = async () => {
    const changes = createSchoolDefaultsReview(load.schools, drafts);
    if (
      !authSubject ||
      !changes?.length ||
      invalidDraftCount > 0 ||
      saving ||
      lock
    )
      return;
    const payload = changes.map((row) => ({
      school_id: row.school_id,
      expected_version: row.expected_version,
      default_student_portions: row.new_student_portions,
      default_teacher_portions: row.new_teacher_portions,
    }));
    setSaving(true);
    setNotice(null);
    const saveGeneration = requestGeneration.current;
    const result: AtlasRpcResult = await api.updateSchoolDefaultsBulk(
      schoolDefaultsBulkCommandRequest(authSubject, correlationId, payload),
    );
    if (saveGeneration !== requestGeneration.current) return;
    if (result.kind === "transport_error") {
      setSaving(false);
      setLock("unknown");
      setNotice("Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.");
      return;
    }
    if (result.kind === "success") {
      const current = await readAuthority("readback");
      setSaving(false);
      if (current) setNotice(`Đã cập nhật ${payload.length} trường.`);
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

  const saveCooking = async (
    kind: "school" | "group",
    school?: SchoolMasterData,
  ) => {
    if (
      !authSubject ||
      !cookingSupported ||
      saving ||
      load.loading ||
      load.error ||
      lock
    )
      return;
    if (
      kind === "school" &&
      (!school || !Object.hasOwn(cookingDrafts, school.school_id))
    )
      return;
    if (kind === "group" && (!groupDirty || !groupEditor.name.trim())) return;
    const group = cookingGroups.find(
      (row) => row.cooking_group_id === groupEditor.id,
    );
    const reason =
      kind === "school" ? "SCHOOL_COOKING_GROUP_SET" : "COOKING_GROUP_SAVED";
    const request = commandRequest(
      authSubject,
      correlationId,
      kind === "school" ? school!.version : (group?.version ?? 1),
      reason,
      kind === "school"
        ? {
            school_id: school!.school_id,
            cooking_group_id: cookingDrafts[school!.school_id] || null,
          }
        : {
            cooking_group_id: groupEditor.id || null,
            cooking_group_name: groupEditor.name.trim(),
            active: groupEditor.active,
          },
    );
    setSaving(true);
    setNotice(null);
    const generation = requestGeneration.current;
    if (kind === "group")
      pendingGroup.current = {
        editor: { ...groupEditor },
        request,
        groupId: groupEditor.id || null,
        confirmed: false,
      };
    const result =
      kind === "school"
        ? await api.setSchoolCookingGroup!(request)
        : await api.upsertCookingGroup!(request);
    if (generation !== requestGeneration.current) return;
    if (result.kind === "transport_error") {
      setSaving(false);
      setLock("unknown");
      setNotice("Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.");
      return;
    }
    if (result.kind === "success") {
      if (kind === "group" && pendingGroup.current) {
        const groupId =
          result.response.affected_aggregate_ids?.cooking_group_id;
        if (typeof groupId === "string") pendingGroup.current.groupId = groupId;
        pendingGroup.current.confirmed = true;
      }
      const current = await readAuthority("readback");
      if (generation + 1 !== requestGeneration.current) return;
      setSaving(false);
      if (current) {
        if (kind === "group") {
          setGroupDirty(false);
          setGroupEditor({ id: "", name: "", active: true });
          pendingGroup.current = null;
        }
        setNotice("Đã cập nhật và tải lại dữ liệu.");
      }
      return;
    }
    setSaving(false);
    pendingGroup.current = null;
    if (
      result.kind === "backend_error" &&
      result.error.error_code === "STALE_VERSION"
    )
      setLock("stale");
    setNotice(resultMessage(result));
  };

  const refresh = async () => {
    const pending = pendingGroup.current;
    if (pending && !pending.groupId) {
      if (!api.upsertCookingGroup || saving || load.loading) return false;
      setSaving(true);
      const generation = requestGeneration.current;
      const result = await api.upsertCookingGroup(pending.request);
      if (generation !== requestGeneration.current) return false;
      if (result.kind !== "success") {
        setSaving(false);
        setLock("unknown");
        setNotice(
          result.kind === "transport_error"
            ? "Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa."
            : resultMessage(result),
        );
        return false;
      }
      const groupId = result.response.affected_aggregate_ids?.cooking_group_id;
      if (typeof groupId !== "string") {
        setSaving(false);
        setLock("unknown");
        setNotice("Atlas chưa thể xác nhận lần lưu đã hoàn tất hay chưa.");
        return false;
      }
      pending.groupId = groupId;
      pending.confirmed = true;
      const current = await readAuthority("recovery");
      if (generation + 1 !== requestGeneration.current) return false;
      setSaving(false);
      return current;
    }
    return readAuthority(lock ? "recovery" : "routine");
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
    portionDirtyCount,
    cookingSupported,
    cookingGroups,
    cookingDrafts,
    groupEditor,
    groupDirty,
    confirmGroupSave: Boolean(
      pendingGroup.current && !pendingGroup.current.groupId,
    ),
    selectGroup: (id: string) => {
      pendingGroup.current = null;
      const group = cookingGroups.find((row) => row.cooking_group_id === id);
      setGroupEditor({
        id,
        name: group?.cooking_group_name ?? "",
        active: group?.active ?? true,
      });
      setGroupDirty(false);
    },
    editGroup: (field: "name" | "active", value: string | boolean) => {
      pendingGroup.current = null;
      const next = { ...groupEditor, [field]: value };
      const group = cookingGroups.find(
        (row) => row.cooking_group_id === next.id,
      );
      setGroupEditor(next);
      setGroupDirty(
        next.name !== (group?.cooking_group_name ?? "") ||
          next.active !== (group?.active ?? true),
      );
    },
    editCooking: (school: SchoolMasterData, value: string) => {
      setCookingDrafts((current) => {
        const next = { ...current };
        if (value === (school.cooking_group_id ?? ""))
          delete next[school.school_id];
        else next[school.school_id] = value;
        return next;
      });
      setNotice(null);
    },
    saveSchoolCooking: (school: SchoolMasterData) =>
      saveCooking("school", school),
    saveGroup: () => saveCooking("group"),
    exitPending: pendingExit !== null,
    requestExit: (next: () => void) => {
      if (saving || load.loading || lock) return;
      if (dirtyCount) setPendingExit({ next });
      else next();
    },
    cancelExit: () => setPendingExit(null),
    discardExit: () => {
      if (!pendingExit || saving || lock) return;
      const { next } = pendingExit;
      setPendingExit(null);
      setDrafts({});
      setCookingDrafts({});
      setGroupDirty(false);
      setGroupEditor({ id: "", name: "", active: true });
      pendingGroup.current = null;
      next();
    },
    invalidDraftCount,
    hiddenDirtyCount,
    saving,
    lock,
    notice,
    edit,
    refresh,
    save,
  };
}

export type SchoolDefaultsController = ReturnType<
  typeof useSchoolDefaultsWorkbench
>;
