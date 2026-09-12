import { useEffect, useRef, useState } from "react";
import {
  adjustmentPreviewFromResult,
  adjustmentResultMessage,
  adjustmentWorkbenchFromResult,
  effectiveCompositionFromResult,
  effectiveTargetContextFromResult,
  emptyRecipeAdjustmentWorkbench,
  recipeAdjustmentCommandRequest,
  type AtlasRpcResult,
  type RecipeAdjustmentApi,
  type RecipeAdjustmentCommandRequest,
  type RecipeAdjustmentOperatorRecord,
  type RecipeAdjustmentPreview,
  type EffectiveCompositionResult,
  type EffectiveTargetContext,
  type RecipeAdjustmentWorkbenchData,
} from "../bridges/recipeAdjustment";
import {
  commandPayload,
  correctionDraft,
  impactContext,
  newChangeDraft,
  previewRequest,
  proposalFor,
  validChangeDraft,
  validDate,
  vietnamLocalDate,
  type ChangeDraft,
} from "./changeOrderModel";
export type RecipeJobHandle = { requestExit: (next: () => void) => void };
type PendingWrite = {
  subject: string;
  adjustmentId: string;
  revisionId: string;
  predecessor: string | null;
};
const unknownMessage = "Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.";
const staleMessage =
  "Lệnh đã được cập nhật ở nơi khác. Hãy tải lại dữ liệu hiện tại.";
const transport = (): AtlasRpcResult => ({
  kind: "transport_error",
  diagnostic: {
    code: "NETWORK_FAILURE",
    safeMessage: "Connection unavailable",
  },
});
async function invoke(call: () => Promise<AtlasRpcResult>) {
  try {
    return await call();
  } catch {
    return transport();
  }
}
function hasEvidence(
  data: RecipeAdjustmentWorkbenchData,
  pending: PendingWrite,
) {
  const row = data.operator_rows.find(
    (r) => r.adjustment_id === pending.adjustmentId,
  );
  const ids = new Set(
    row
      ? [row.current_revision_id, ...row.history.map((h) => h.revision_id)]
      : [],
  );
  return (
    ids.has(pending.revisionId) &&
    (!pending.predecessor || ids.has(pending.predecessor))
  );
}
export function useChangeOrderWorkbench({
  api,
  authSubject,
  initialDate,
}: {
  api: RecipeAdjustmentApi;
  authSubject: string | null;
  initialDate?: string;
}) {
  const identity = useRef({
    api,
    subject: authSubject,
    epoch: 0,
    active: true,
  });
  if (identity.current.api !== api || identity.current.subject !== authSubject)
    identity.current = {
      api,
      subject: authSubject,
      epoch: identity.current.epoch + 1,
      active: true,
    };
  const session = identity.current;
  const current = () =>
    identity.current === session &&
    session.active &&
    identity.current.subject === authSubject &&
    identity.current.api === api;
  const [data, setData] = useState(emptyRecipeAdjustmentWorkbench);
  const [owner, setOwner] = useState(authSubject);
  const [ready, setReady] = useState(false),
    [loading, setLoading] = useState(false),
    [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [lock, setLock] = useState<"unknown" | "stale" | "readback" | null>(
    null,
  );
  const [selected, setSelected] =
    useState<RecipeAdjustmentOperatorRecord | null>(null);
  const [draft, setDraft] = useState<ChangeDraft | null>(null);
  const [baseline, setBaseline] = useState("");
  const [editing, setEditing] = useState<RecipeAdjustmentOperatorRecord | null>(
    null,
  );
  const [targets, setTargets] = useState<EffectiveTargetContext | null>(null);
  const [targetLoading, setTargetLoading] = useState(false);
  const [preview, setPreview] = useState<RecipeAdjustmentPreview | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [inspection, setInspection] =
    useState<EffectiveCompositionResult | null>(null);
  const [inspectionSchool, setInspectionSchool] = useState("");
  const [inspectionLoading, setInspectionLoading] = useState(false);
  const [inspectionMessage, setInspectionMessage] = useState("");
  const [effective, setEffective] = useState<EffectiveCompositionResult | null>(
    null,
  );
  const [effectiveLoading, setEffectiveLoading] = useState(false);
  const [effectiveMessage, setEffectiveMessage] = useState("");
  const [cancelTarget, setCancelTarget] =
    useState<RecipeAdjustmentOperatorRecord | null>(null);
  const [discardOpen, setDiscardOpen] = useState(false);
  const pendingExit = useRef<(() => void) | null>(null),
    discardAccepted = useRef(false);
  const pendingWrite = useRef<PendingWrite | null>(null),
    commandBusy = useRef(false);
  const readId = useRef(0),
    draftId = useRef(0),
    targetId = useRef(0),
    previewId = useRef(0),
    inspectionId = useRef(0),
    effectiveId = useRef(0);
  const correlation = useRef(crypto.randomUUID());
  const snapshot = useRef<{
    draftId: number;
    draft: ChangeDraft;
    preview: RecipeAdjustmentPreview;
  } | null>(null);
  const dirty = Boolean(draft && JSON.stringify(draft) !== baseline);
  const canAct =
    current() &&
    owner === authSubject &&
    Boolean(authSubject) &&
    ready &&
    !loading &&
    !busy &&
    !lock &&
    !pendingWrite.current;
  function invalidateReview() {
    previewId.current++;
    inspectionId.current++;
    snapshot.current = null;
    setPreview(null);
    setPreviewLoading(false);
    setInspection(null);
    setInspectionSchool("");
    setInspectionMessage("");
    setInspectionLoading(false);
  }
  function resetEditor() {
    draftId.current++;
    targetId.current++;
    effectiveId.current++;
    setDraft(null);
    setEditing(null);
    setTargets(null);
    setTargetLoading(false);
    setCancelTarget(null);
    setEffective(null);
    setEffectiveMessage("");
    invalidateReview();
  }
  async function read(recovery = false) {
    if (!authSubject || !current()) return;
    const id = ++readId.current,
      date = initialDate ?? vietnamLocalDate();
    setLoading(true);
    setReady(false);
    const result = await invoke(() =>
      api.getOperatorWorkbench(authSubject, correlation.current, date),
    );
    if (!current() || id !== readId.current) return;
    setLoading(false);
    const next = adjustmentWorkbenchFromResult(result);
    if (!next || next.reference_date !== date) {
      setMessage(
        pendingWrite.current
          ? unknownMessage
          : "Không tải được dữ liệu lệnh hiện tại. Hãy tải lại dữ liệu.",
      );
      return;
    }
    setData(next);
    setOwner(authSubject);
    setReady(true);
    const pending = pendingWrite.current;
    if (pending) {
      if (pending.subject === authSubject && hasEvidence(next, pending)) {
        pendingWrite.current = null;
        setLock(null);
        commandBusy.current = false;
        setBusy(false);
        resetEditor();
        setSelected(
          next.operator_rows.find(
            (r) => r.adjustment_id === pending.adjustmentId,
          ) ?? null,
        );
        setMessage("Đã xác nhận lệnh từ dữ liệu hiện tại.");
      } else setMessage(unknownMessage);
    } else if (recovery) {
      setLock(null);
      resetEditor();
      setSelected(null);
      setMessage("");
    }
  }
  useEffect(() => {
    session.active = true;
    setOwner(authSubject);
    setData(emptyRecipeAdjustmentWorkbench());
    setReady(false);
    resetEditor();
    setSelected(null);
    setDiscardOpen(false);
    pendingExit.current = null;
    commandBusy.current = false;
    setBusy(false);
    setLock(pendingWrite.current ? "unknown" : null);
    setMessage("");
    if (authSubject) void read();
    else setMessage("Vui lòng đăng nhập để xem lệnh điều chỉnh.");
    return () => {
      session.active = false;
      readId.current++;
      targetId.current++;
      previewId.current++;
      inspectionId.current++;
      effectiveId.current++;
    };
    // The account/API pair owns this complete session. Pending write proof survives account changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authSubject, api]);
  useEffect(() => {
    if (initialDate || !data.reference_date) return;
    const timer = setInterval(() => {
      if (
        data.reference_date === vietnamLocalDate() ||
        !current() ||
        loading ||
        busy ||
        lock
      )
        return;
      if (dirty || preview || cancelTarget) {
        invalidateReview();
        setLock("stale");
        setMessage("Ngày làm việc đã thay đổi. Hãy tải lại dữ liệu hiện tại.");
      } else void read();
    }, 30000);
    return () => clearInterval(timer);
  });
  const context = draft ? impactContext(draft, data) : null;
  const targetContextKey =
    draft?.object === "recipe" &&
    context?.dishId &&
    context.schoolTypeId &&
    (context.system || context.schoolId)
      ? JSON.stringify([draft.effectiveFrom, context])
      : "";
  useEffect(() => {
    const id = ++targetId.current;
    setTargets(null);
    setTargetLoading(false);
    if (!draft || !context || !targetContextKey || !authSubject) return;
    const date = draft.effectiveFrom,
      c = context;
    setTargetLoading(true);
    void invoke(() =>
      api.getEffectiveTargetContext(
        authSubject,
        correlation.current,
        date,
        c.dishId,
        c.system
          ? { kind: "system", schoolTypeId: c.schoolTypeId }
          : { kind: "school", schoolId: c.schoolId },
      ),
    ).then((result) => {
      if (!current() || id !== targetId.current) return;
      const parsed = effectiveTargetContextFromResult(result);
      const matches =
        parsed?.as_of_date === date &&
        parsed.dish_id === c.dishId &&
        parsed.school_id === (c.system ? null : c.schoolId) &&
        parsed.school_type_id === c.schoolTypeId;
      setTargets(matches ? parsed : null);
      setTargetLoading(false);
      if (!matches)
        setMessage(
          "Chưa tải được thành phần hiệu lực đúng bối cảnh. Hãy kiểm tra mục tiêu.",
        );
    });
    return () => {
      targetId.current++;
    };
    // Exact context changes alone reload targets. Other material changes invalidate Preview, not target authority.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targetContextKey, authSubject, api]);
  function transition(next: () => void) {
    if (
      !current() ||
      busy ||
      commandBusy.current ||
      lock ||
      preview ||
      cancelTarget
    )
      return;
    if (dirty) {
      pendingExit.current = next;
      setDiscardOpen(true);
    } else {
      resetEditor();
      next();
    }
  }
  function openCreate() {
    if (canAct)
      transition(() => {
        setSelected(null);
        const d = newChangeDraft(initialDate ?? vietnamLocalDate());
        setDraft(d);
        setBaseline(JSON.stringify(d));
      });
  }
  function openCorrection(row: RecipeAdjustmentOperatorRecord) {
    if (!canAct || !row.can_correct) return;
    transition(() => {
      const d = correctionDraft(row);
      setDraft(d);
      setBaseline(JSON.stringify(d));
      setEditing(row);
      setSelected(null);
    });
  }
  function openCancel(row: RecipeAdjustmentOperatorRecord) {
    if (canAct && row.can_cancel)
      transition(() => {
        setSelected(row);
        setCancelTarget(row);
      });
  }
  function updateDraft(patch: Partial<ChangeDraft>) {
    if (!draft || !canAct || commandBusy.current) return;
    // Correcting a root cannot change its scope/action/stable target identity.
    if (editing)
      patch = Object.fromEntries(
        Object.entries(patch).filter(([k]) =>
          [
            "substituteId",
            "quantity",
            "replaceQuantity",
            "effectiveFrom",
            "effectiveTo",
            "reason",
            "previewSchoolId",
            "previewDishId",
          ].includes(k),
        ),
      ) as Partial<ChangeDraft>;
    draftId.current++;
    invalidateReview();
    setMessage("");
    setDraft({ ...draft, ...patch });
  }
  const canPreview = Boolean(
    canAct &&
    draft &&
    (!targetLoading || draft.action === "ADD") &&
    validChangeDraft(draft, data, targets, editing),
  );
  async function runPreview() {
    if (!canPreview || !draft || !authSubject || previewLoading) return;
    const id = ++previewId.current,
      material = draftId.current;
    const proposal = proposalFor(draft, data, targets, editing),
      request = previewRequest(draft, data, proposal, editing),
      ctx = impactContext(draft, data);
    setPreviewLoading(true);
    setMessage("");
    const result = await invoke(() =>
      api.preview(authSubject, correlation.current, request),
    );
    if (!current() || id !== previewId.current || material !== draftId.current)
      return;
    setPreviewLoading(false);
    const parsed = adjustmentPreviewFromResult(result);
    if (
      !parsed ||
      parsed.as_of_date !== draft.effectiveFrom ||
      parsed.dish_id !== ctx.dishId ||
      parsed.school_id !== (ctx.system ? null : ctx.schoolId) ||
      parsed.school_type_id !== (ctx.system ? ctx.schoolTypeId : null) ||
      parsed.before.school_type_id !== ctx.schoolTypeId ||
      parsed.after.school_type_id !== ctx.schoolTypeId ||
      JSON.stringify(parsed.proposed_adjustment) !== JSON.stringify(proposal)
    ) {
      setMessage(
        "Kết quả xem tác động không khớp bối cảnh đã gửi. Hãy kiểm tra và xem lại.",
      );
      return;
    }
    snapshot.current = {
      draftId: material,
      draft: structuredClone(draft),
      preview: parsed,
    };
    setPreview(parsed);
  }
  async function finishWrite(
    request: RecipeAdjustmentCommandRequest,
    method: "create" | "supersede" | "cancel",
  ) {
    if (!authSubject || !canAct || commandBusy.current) return;
    commandBusy.current = true;
    setBusy(true);
    const pending: PendingWrite = {
      subject: authSubject,
      adjustmentId: String(request.payload.adjustment_id),
      revisionId: String(request.payload.revision_id),
      predecessor:
        typeof request.payload.predecessor_revision_id === "string"
          ? request.payload.predecessor_revision_id
          : null,
    };
    pendingWrite.current = pending;
    const result = await invoke(() => api[method](request));
    if (!current() || pendingWrite.current !== pending) return;
    commandBusy.current = false;
    setBusy(false);
    if (result.kind === "transport_error") {
      setLock("unknown");
      setMessage(unknownMessage);
      invalidateReview();
      setCancelTarget(null);
      return;
    }
    if (result.kind === "success") {
      setLock("readback");
      invalidateReview();
      setCancelTarget(null);
      await read(true);
      return;
    }
    pendingWrite.current = null;
    invalidateReview();
    if (
      result.kind === "backend_error" &&
      (result.error.error_code === "STALE_VERSION" ||
        /predecessor/i.test(result.error.safe_message ?? ""))
    ) {
      setLock("stale");
      setMessage(staleMessage);
      setCancelTarget(null);
    } else {
      setLock(null);
      setMessage(adjustmentResultMessage(result));
    }
  }
  async function save() {
    const frozen = snapshot.current;
    if (
      !canAct ||
      !authSubject ||
      !frozen ||
      !frozen.preview.can_save ||
      frozen.preview.blockers.length ||
      frozen.draftId !== draftId.current ||
      commandBusy.current
    )
      return;
    const request = recipeAdjustmentCommandRequest(
      authSubject,
      correlation.current,
      editing?.version ?? 1,
      editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
      frozen.draft.reason.trim(),
      commandPayload(
        frozen.draft,
        data,
        frozen.preview.proposed_adjustment,
        editing,
      ),
    );
    await finishWrite(request, editing ? "supersede" : "create");
  }
  async function cancel(date: string, reason: string) {
    if (
      !canAct ||
      !authSubject ||
      !cancelTarget?.can_cancel ||
      !validDate(date) ||
      date < cancelTarget.command_revision.effective_from ||
      (cancelTarget.command_revision.effective_to &&
        date >= cancelTarget.command_revision.effective_to) ||
      !reason.trim()
    )
      return;
    await finishWrite(
      recipeAdjustmentCommandRequest(
        authSubject,
        correlation.current,
        cancelTarget.version,
        "RULE_CANCELLATION",
        reason.trim(),
        {
          adjustment_id: cancelTarget.adjustment_id,
          predecessor_revision_id: cancelTarget.current_revision_id,
          revision_id: crypto.randomUUID(),
          effective_from: date,
        },
      ),
      "cancel",
    );
  }
  async function inspectSchool(schoolId: string) {
    const frozen = snapshot.current;
    const school = data.schools.find(
      (s) =>
        s.school_id === schoolId &&
        s.school_type_id === preview?.school_type_id &&
        s.school_status === "ACTIVE",
    );
    const id = ++inspectionId.current;
    setInspection(null);
    setInspectionSchool(schoolId);
    setInspectionMessage("");
    setInspectionLoading(false);
    if (
      !current() ||
      !authSubject ||
      !frozen ||
      !preview ||
      preview.school_id !== null ||
      !school ||
      lock
    )
      return;
    setInspectionLoading(true);
    const result = await invoke(() =>
      api.resolve(authSubject, correlation.current, {
        as_of_date: preview.as_of_date,
        dish_id: preview.dish_id,
        school_id: schoolId,
      }),
    );
    if (
      !current() ||
      id !== inspectionId.current ||
      snapshot.current !== frozen
    )
      return;
    const parsed = effectiveCompositionFromResult(result);
    setInspectionLoading(false);
    if (
      parsed?.as_of_date === preview.as_of_date &&
      parsed.dish_id === preview.dish_id &&
      parsed.school_id === schoolId &&
      parsed.school_type_id === preview.school_type_id
    )
      setInspection(parsed);
    else setInspectionMessage("Chưa tải được công thức tại trường đã chọn.");
  }
  async function inspectEffective(
    dishId: string,
    schoolId: string,
    schoolTypeId: string,
  ) {
    if (!authSubject || !current() || !selected) return;
    const id = ++effectiveId.current,
      date = initialDate ?? vietnamLocalDate();
    setEffective(null);
    setEffectiveLoading(true);
    setEffectiveMessage("");
    const result = await invoke(() =>
      schoolId
        ? api.resolve(authSubject, correlation.current, {
            as_of_date: date,
            dish_id: dishId,
            school_id: schoolId,
          })
        : api.resolveSystem(
            authSubject,
            correlation.current,
            date,
            dishId,
            schoolTypeId,
          ),
    );
    if (!current() || id !== effectiveId.current) return;
    const parsed = effectiveCompositionFromResult(result);
    setEffectiveLoading(false);
    if (
      parsed?.as_of_date === date &&
      parsed.dish_id === dishId &&
      parsed.school_id === (schoolId || null) &&
      parsed.school_type_id === schoolTypeId
    )
      setEffective(parsed);
    else setEffectiveMessage("Chưa tải được công thức hiệu lực đúng bối cảnh.");
  }
  return {
    data: owner === authSubject ? data : emptyRecipeAdjustmentWorkbench(),
    ready,
    loading,
    busy,
    message,
    lock,
    canAct,
    selected,
    draft,
    editing,
    targets,
    targetLoading,
    preview,
    previewLoading,
    dirty,
    canPreview,
    inspection,
    inspectionSchool,
    inspectionLoading,
    inspectionMessage,
    inspectSchool,
    effective,
    effectiveLoading,
    effectiveMessage,
    inspectEffective,
    clearEffective: () => {
      effectiveId.current++;
      setEffective(null);
      setEffectiveLoading(false);
      setEffectiveMessage("");
    },
    cancelTarget,
    cancel,
    openCancel,
    closeCancel: () => {
      if (!busy && !lock) setCancelTarget(null);
    },
    openCreate,
    openCorrection,
    updateDraft,
    runPreview,
    save,
    backToEdit: () => {
      if (!busy && !lock) invalidateReview();
    },
    select: (row: RecipeAdjustmentOperatorRecord) => {
      if (canAct) transition(() => setSelected(row));
    },
    close: () => transition(() => setSelected(null)),
    requestExit: transition,
    refreshDisabled:
      !canAct ||
      dirty ||
      Boolean(preview) ||
      Boolean(cancelTarget) ||
      previewLoading,
    refresh: () =>
      transition(() => {
        setSelected(null);
        void read(true);
      }),
    recover: () => {
      if (!commandBusy.current) return read(true);
      return Promise.resolve();
    },
    discardOpen,
    cancelDiscard: () => {
      pendingExit.current = null;
      discardAccepted.current = false;
      setDiscardOpen(false);
    },
    confirmDiscard: () => {
      discardAccepted.current = true;
      setDiscardOpen(false);
    },
    completeDiscardTransition: () => {
      const next = pendingExit.current;
      pendingExit.current = null;
      if (discardAccepted.current && next) {
        resetEditor();
        next();
      }
      discardAccepted.current = false;
    },
  };
}
export type ChangeOrderController = ReturnType<typeof useChangeOrderWorkbench>;
