import { useCallback, useEffect, useRef, useState } from "react";
import {
  pantryResultMessage,
  weeklyPantryFromResult,
  type AtlasRpcResult,
  type PantryApi,
  type PantryWorkbenchData,
  type PlanningCorrectionImpact,
  type WeeklyPantryProjection,
  type WeeklyPantryRule,
} from "../bridges/planning";
import { normalizeConfirmedNeedQuantity } from "../bridges/confirmedNeed";

type RuleDraft = {
  school_id: string;
  ingredient_id: string;
  rate: string;
  stop: boolean;
  existing: boolean;
};
type ReviewedRule = {
  projection: WeeklyPantryProjection | null;
  menuToken: string;
  version: number;
  unitId: string;
};
const unavailable: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: {
    code: "NETWORK_FAILURE",
    safeMessage: "Không thể kết nối Atlas.",
  },
};
const messages: Record<string, string> = {
  STALE_VERSION:
    "Thực đơn, đơn vị mua hoặc định mức đã thay đổi. Tải lại trước khi tiếp tục.",
  VALIDATION_FAILED:
    "Kiểm tra trường, nguyên liệu và định mức. Tổng lượng bảy ngày phải nằm trong giới hạn cho phép.",
  PLANNING_RELEASE_CORRECTION_REQUIRED:
    "Nhu cầu đã phát hành. Mở luồng hiệu chỉnh cho ngày nhận bị ảnh hưởng trước khi lưu định mức.",
  LEGACY_RANGE_CORRECTION_REQUIRED:
    "Cần xử lý hiệu chỉnh kỳ nhu cầu cũ trước khi lưu định mức.",
  BLOCKED_BY_PURCHASE_HANDOFF:
    "Ngày nhận đã bàn giao mua hàng. Hãy xử lý chứng từ liên quan.",
  BLOCKED_BY_DOWNSTREAM_COMMITMENT:
    "Ngày nhận đã có chứng từ cam kết. Hãy xử lý chứng từ liên quan.",
  CAPABILITY_DENIED: "Bạn không có quyền cập nhật định mức.",
};
const failure = (r: AtlasRpcResult) =>
  r.kind === "backend_error"
    ? (messages[r.error.error_code] ?? pantryResultMessage(r))
    : pantryResultMessage(r);

export function useWeeklyPantryRules({
  active,
  week,
  subject,
  api,
  catalog,
  editable,
  onCommitted,
}: {
  active: boolean;
  week: string;
  subject: string;
  api: Pick<PantryApi, "weeklyRules" | "saveWeeklyRule" | "prepareCorrection">;
  catalog: PantryWorkbenchData | null;
  editable: boolean;
  onCommitted?: () => void;
}) {
  const [data, setData] =
    useState<ReturnType<typeof weeklyPantryFromResult>>(null);
  const [draft, setDraft] = useState<RuleDraft | null>(null);
  const [reviewed, setReviewed] = useState<ReviewedRule | null>(null);
  const [busy, setBusy] = useState(false);
  const [uncertain, setUncertain] = useState(false);
  const [reloadNeeded, setReloadNeeded] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [impacts, setImpacts] = useState<
    PlanningCorrectionImpact["date_impacts"]
  >([]);
  const generation = useRef(0);
  const writing = useRef(false);
  const cancel = () => {
    setDraft(null);
    setReviewed(null);
    setError("");
    setNotice("");
    setImpacts([]);
  };
  const read = useCallback(async () => {
    const serial = ++generation.current;
    setBusy(true);
    setError("");
    const result = await api
      .weeklyRules(subject, week)
      .catch(() => unavailable);
    if (serial !== generation.current) return false;
    const latest = weeklyPantryFromResult(result);
    setData(latest);
    setReloadNeeded(!latest);
    setBusy(false);
    if (!latest)
      setError("Không tải được định mức của tuần này. Hãy tải lại định mức.");
    return !!latest;
  }, [api, week, subject]);
  useEffect(() => {
    cancel();
    setData(null);
    setUncertain(false);
    setReloadNeeded(false);
    setBusy(false);
    if (active && catalog) void read();
    return () => {
      ++generation.current;
    };
  }, [active, catalog, read]);

  const current = data?.rules.find(
    (r) =>
      r.school_id === draft?.school_id &&
      r.ingredient_id === draft?.ingredient_id,
  );
  const ingredient = catalog?.ingredients.find(
    (i) => i.ingredient_id === draft?.ingredient_id,
  );
  const rate = normalizeConfirmedNeedQuantity(draft?.rate ?? "");
  const validRate = !!rate && /[1-9]/.test(rate);
  const canEdit =
    editable && !!data?.can_manage && !busy && !reloadNeeded && !uncertain;
  const canPreview =
    canEdit &&
    !!draft?.school_id &&
    (draft.stop
      ? !!current?.enabled
      : validRate && ingredient?.ingredient_status === "ACTIVE");
  const start = (school: string, rule?: WeeklyPantryRule, stop = false) => {
    if (!canEdit || draft) return;
    setError("");
    setNotice("");
    setDraft({
      school_id: school,
      ingredient_id: rule?.ingredient_id ?? "",
      rate: rule?.quantity_per_day ?? "",
      stop,
      existing: !!rule,
    });
  };
  const edit = (
    patch: Partial<Pick<RuleDraft, "school_id" | "ingredient_id" | "rate">>,
  ) => {
    if (!canEdit || !draft) return;
    setDraft({ ...draft, ...patch });
    setReviewed(null);
    setError("");
    setImpacts([]);
  };
  const preview = async () => {
    if (!draft || !canPreview || writing.current || !data) return;
    writing.current = true;
    setBusy(true);
    setError("");
    setImpacts([]);
    setReviewed(null);
    const serial = generation.current;
    try {
      const result = await api
        .weeklyRules(
          subject,
          week,
          draft.stop
            ? undefined
            : { school_id: draft.school_id, quantity_per_day: rate! },
        )
        .catch(() => unavailable);
      if (serial !== generation.current) return;
      const latest = weeklyPantryFromResult(result);
      const entry = latest?.rules.find(
        (r) =>
          r.school_id === draft.school_id &&
          r.ingredient_id === draft.ingredient_id,
      );
      if (
        !latest ||
        (!draft.stop &&
          (!latest.preview || latest.preview.school_id !== draft.school_id))
      ) {
        setError(
          result.kind === "backend_error"
            ? failure(result)
            : "Không đọc được lượng dự kiến. Hãy xem lại định mức.",
        );
        return;
      }
      if (
        data.menu_token !== latest.menu_token ||
        (entry?.version ?? 0) !== (current?.version ?? 0) ||
        !latest.can_manage
      ) {
        setError(messages.STALE_VERSION);
        setReloadNeeded(true);
        return;
      }
      setReviewed({
        projection: draft.stop ? (entry ?? null) : latest.preview,
        menuToken: latest.menu_token,
        version: entry?.version ?? 0,
        unitId: draft.stop
          ? current!.unit_id
          : ingredient!.purchase_unit.unit_id,
      });
    } finally {
      writing.current = false;
      if (generation.current === serial) setBusy(false);
    }
  };
  const save = async () => {
    if (!draft || !reviewed || !canPreview || writing.current) return;
    writing.current = true;
    setBusy(true);
    setError("");
    try {
      const result = await api
        .saveWeeklyRule(subject, reviewed.version, {
          week_start: week,
          school_id: draft.school_id,
          ingredient_id: draft.ingredient_id,
          expected_menu_token: reviewed.menuToken,
          expected_unit_id: reviewed.unitId,
          enabled: !draft.stop,
          ...(draft.stop ? {} : { quantity_per_day: rate! }),
        })
        .catch(() => unavailable);
      setReviewed(null);
      if (result.kind !== "success") {
        setError(failure(result));
        if (
          result.kind === "backend_error" &&
          result.error.blocking_references
        ) {
          const dates = result.error.blocking_references.filter(
            (ref) =>
              ref &&
              typeof ref === "object" &&
              !Array.isArray(ref) &&
              typeof ref.service_date === "string" &&
              typeof ref.operator_message === "string" &&
              Array.isArray(ref.chains),
          );
          setImpacts(
            dates as unknown as PlanningCorrectionImpact["date_impacts"],
          );
        }
        if (result.kind === "transport_error") setUncertain(true);
        if (
          result.kind === "backend_error" &&
          ["STALE_VERSION", "RETRYABLE_CONCURRENCY_FAILURE"].includes(
            result.error.error_code,
          )
        )
          setReloadNeeded(true);
        return;
      }
      setDraft(null);
      onCommitted?.();
      const loaded = await read();
      setNotice(
        loaded
          ? "Đã lưu định mức theo tuần."
          : "Đã lưu định mức. Tải lại để kiểm tra lượng của tuần.",
      );
    } finally {
      writing.current = false;
      setBusy(false);
    }
  };
  const correction = impacts.flatMap((d) =>
    [
      "PLANNING_RELEASE_CORRECTION_REQUIRED",
      "LEGACY_RANGE_CORRECTION_REQUIRED",
    ].includes(d.correction_policy)
      ? d.chains.filter(
          (chain) =>
            chain.confirmed_need_batch_id && chain.need_generation_run_id,
        )
      : [],
  )[0];
  const prepareCorrection = async () => {
    if (!canEdit || !correction || writing.current) return;
    writing.current = true;
    setBusy(true);
    setError("");
    try {
      const result = await api
        .prepareCorrection(
          subject,
          crypto.randomUUID(),
          correction,
          "Hiệu chỉnh nhu cầu do thay đổi định mức hàng đặt riêng theo tuần.",
        )
        .catch(() => unavailable);
      setImpacts([]);
      if (result.kind === "success") {
        onCommitted?.();
        setNotice(
          "Đã mở hiệu chỉnh. Xem lại lượng dự kiến trước khi lưu định mức.",
        );
      } else {
        setError(failure(result));
        setReloadNeeded(true);
        if (result.kind === "transport_error") setUncertain(true);
      }
    } finally {
      writing.current = false;
      setBusy(false);
    }
  };
  const recover = async () => {
    if (writing.current || busy) return;
    if (await read()) {
      cancel();
      setUncertain(false);
      if (uncertain) onCommitted?.();
    }
  };
  return {
    data,
    draft,
    reviewed,
    current,
    ingredient,
    canEdit,
    canPreview,
    validRate,
    busy,
    uncertain,
    reloadNeeded,
    error,
    notice,
    impacts,
    correction,
    prepareCorrection,
    dirty: !!draft,
    start,
    edit,
    preview,
    save,
    cancel,
    recover,
  };
}
