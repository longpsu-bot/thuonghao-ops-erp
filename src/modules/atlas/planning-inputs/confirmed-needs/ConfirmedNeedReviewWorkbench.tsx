import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import { Chip, CompactTable, Panel } from "../../WorkbenchComponents";
import {
  confirmedNeedApprovalRequest,
  confirmedNeedCommandRequest,
  confirmedNeedPreviewRequest,
  confirmedNeedReleaseRequest,
  confirmedNeedValidationRequest,
  type ConfirmedNeedApi,
  type ConfirmedNeedApprovalRequest,
  type ConfirmedNeedCommandRequest,
  type ConfirmedNeedFilters,
  type ConfirmedNeedLineRequest,
  type ConfirmedNeedReleaseRequest,
} from "./confirmedNeedApi";
import {
  confirmedNeedLifecycleRequiresRefresh,
  confirmedNeedPreviewFromResult,
  confirmedNeedPreviewIsStale,
  confirmedNeedReadbackFromResult,
  confirmedNeedReasonLabel,
  confirmedNeedResultAllowsExactRetry,
  confirmedNeedResultIsStale,
  confirmedNeedResultMessage,
  confirmedNeedWorkbenchFromResult,
  exactDecimalEqual,
  exactQuantityDisplay,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedQuantity,
  subtractExactDecimals,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedIssue,
  type ConfirmedNeedLine,
  type ConfirmedNeedPreview,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";
import {
  applyConfirmedNeedWorkbookReview,
  assembleConfirmedNeedPages,
  confirmedNeedReasonOptions,
  downloadConfirmedNeedWorkbook,
  readConfirmedNeedWorkbook,
  reviewConfirmedNeedWorkbook,
  type ConfirmedNeedImportReview,
} from "./confirmedNeedWorkbook";

const emptyFilters: ConfirmedNeedFilters = {
  service_date: null,
  school_id: null,
  delivery_location_id: null,
  ingredient_id: null,
  decision_state: null,
};
const pageSize = 250;

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function lifecycleLabel(status?: string) {
  const labels: Record<string, string> = {
    DRAFT_REVIEW: "Đang xác nhận số lượng",
    REOPENED: "Đang hiệu chỉnh số lượng",
    VALIDATED: "Đã hoàn tất xác nhận",
    APPROVED: "Đã phê duyệt",
    RELEASED_FOR_PURCHASE_HANDOFF: "Đã phát hành sang bước lên đơn",
  };
  return status ? (labels[status] ?? "Trạng thái cần làm mới") : "Chưa tải";
}

function decisionLabel(kind: string | null) {
  if (kind === "UNCHANGED_PROPOSAL_ACCEPTED") return "Đã chấp nhận đề xuất";
  if (kind === "ADJUSTED_QUANTITY_CONFIRMED") return "Đã điều chỉnh";
  return "Chưa xác nhận";
}

function issueList(
  title: string,
  items: ConfirmedNeedIssue[],
  tone: "danger" | "warning",
) {
  if (!items.length) return null;
  return (
    <section className={`confirmed-need-issues ${tone}`} aria-label={title}>
      <strong>
        {title} ({items.length})
      </strong>
      <ul>
        {items.map((item, index) => (
          <li key={`${item.code}:${index}`}>{item.message ?? item.code}</li>
        ))}
      </ul>
    </section>
  );
}

export function confirmedNeedLineRequest(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
): ConfirmedNeedLineRequest {
  return {
    confirmed_need_line_id: line.confirmed_need_line_id,
    expected_current_revision_id: line.current_revision_id,
    expected_current_decision_id: line.current_decision_id,
    proposed_confirmed_quantity: draft.exact_quantity,
    reason_code: draft.reason_code,
    reason_note: draft.reason_note.trim() || null,
  };
}

function draftDiffersFromAuthority(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  const original = initialConfirmedNeedDraft(line);
  return (
    !exactDecimalEqual(original.exact_quantity, draft.exact_quantity) ||
    original.reason_code !== draft.reason_code ||
    original.reason_note.trim() !== draft.reason_note.trim()
  );
}

function localDraftError(
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) {
  if (!normalizeConfirmedNeedQuantity(draft.exact_quantity))
    return "SL xác nhận phải là số không âm, tối đa 14 chữ số nguyên và 6 chữ số thập phân.";
  const unchanged = exactDecimalEqual(
    draft.exact_quantity,
    line.proposed_confirmed_quantity,
  );
  if (unchanged && draft.reason_code !== "PROPOSAL_ACCEPTED")
    return "SL xác nhận bằng SL đề xuất nên cần chọn “Chấp nhận đề xuất”.";
  if (!unchanged && draft.reason_code === "PROPOSAL_ACCEPTED")
    return "SL xác nhận đã thay đổi nên cần chọn một lý do điều chỉnh.";
  if (
    ["OPERATIONAL_QUANTITY_ADJUSTMENT", "OTHER"].includes(draft.reason_code) &&
    !draft.reason_note.trim()
  )
    return "Lý do này cần ghi chú.";
  if (
    line.current_decision_id &&
    draftDiffersFromAuthority(line, draft) &&
    !draft.reason_note.trim()
  )
    return "Thay thế quyết định hiện tại cần ghi chú hiệu chỉnh.";
  if (unchanged && !line.current_decision_id && draft.reason_note.trim())
    return "Lần chấp nhận đề xuất đầu tiên không có ghi chú.";
  return null;
}

function authorityBindingsMatch(
  current: ConfirmedNeedWorkbenchData,
  fresh: ConfirmedNeedWorkbenchData,
) {
  if (
    current.confirmed_need_batch_id !== fresh.confirmed_need_batch_id ||
    current.batch_version !== fresh.batch_version ||
    current.pagination.total_lines !== fresh.pagination.total_lines
  )
    return false;
  const freshById = new Map(
    fresh.lines.map((line) => [line.confirmed_need_line_id, line]),
  );
  return current.lines.every((line) => {
    const next = freshById.get(line.confirmed_need_line_id);
    return (
      next?.current_revision_id === line.current_revision_id &&
      next.current_decision_id === line.current_decision_id
    );
  });
}

type ReadFullBatchResult =
  | { workbench: ConfirmedNeedWorkbenchData; error: null }
  | { workbench: null; error: string };

export function ConfirmedNeedReviewWorkbench({
  authState,
  api,
  initialBatchId,
  currentNeedResolution = initialBatchId ? "available" : "idle",
  onDirtyChange,
}: {
  authState: AtlasAuthState;
  api?: ConfirmedNeedApi;
  initialBatchId?: string | null;
  currentNeedResolution?:
    "idle" | "loading" | "available" | "missing" | "denied" | "error";
  mode?: "connected" | "review";
  onDirtyChange?: (dirty: boolean) => void;
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [batchId, setBatchId] = useState(initialBatchId ?? "");
  const [workbench, setWorkbench] = useState<ConfirmedNeedWorkbenchData | null>(
    null,
  );
  const [drafts, setDrafts] = useState<Record<string, ConfirmedNeedDraftLine>>(
    {},
  );
  const [preview, setPreview] = useState<ConfirmedNeedPreview | null>(null);
  const [previewLines, setPreviewLines] = useState<ConfirmedNeedLineRequest[]>(
    [],
  );
  const [pendingCommand, setPendingCommand] =
    useState<ConfirmedNeedCommandRequest | null>(null);
  const [importReview, setImportReview] =
    useState<ConfirmedNeedImportReview | null>(null);
  const [draftTouched, setDraftTouched] = useState(false);
  const [draftSource, setDraftSource] = useState<"direct" | "excel" | null>(
    null,
  );
  const [staleLocalDraft, setStaleLocalDraft] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [lifecycleConfirmation, setLifecycleConfirmation] = useState<
    "approval" | "release" | null
  >(null);
  const [lifecycleRefreshRequired, setLifecycleRefreshRequired] =
    useState(false);
  const [schoolFilter, setSchoolFilter] = useState("");
  const [serviceDateFilter, setServiceDateFilter] = useState("");
  const intentGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const invalidateIntent = useCallback((dropImportReview = false) => {
    const nextGeneration = ++intentGeneration.current;
    setPreview(null);
    setPreviewLines([]);
    setPendingCommand(null);
    setLifecycleConfirmation(null);
    if (dropImportReview) setImportReview(null);
    return nextGeneration;
  }, []);

  const unsafeLocalWork = Boolean(
    draftTouched ||
    importReview ||
    preview ||
    pendingCommand ||
    lifecycleConfirmation ||
    lifecycleRefreshRequired,
  );

  useEffect(
    () => onDirtyChange?.(unsafeLocalWork),
    [onDirtyChange, unsafeLocalWork],
  );

  useEffect(() => {
    if (!unsafeLocalWork) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [unsafeLocalWork]);

  const adopt = useCallback(
    (next: ConfirmedNeedWorkbenchData, preserveDraft = false) => {
      invalidateIntent(true);
      setWorkbench(next);
      setDrafts((current) =>
        Object.fromEntries(
          next.lines.map((line) => [
            line.confirmed_need_line_id,
            preserveDraft
              ? (current[line.confirmed_need_line_id] ??
                initialConfirmedNeedDraft(line))
              : initialConfirmedNeedDraft(line),
          ]),
        ),
      );
      setSchoolFilter((current) =>
        next.lines.some((line) => line.school.id === current) ? current : "",
      );
      setServiceDateFilter((current) =>
        next.lines.some((line) => line.service_date === current) ? current : "",
      );
      if (!preserveDraft) {
        setDraftTouched(false);
        setDraftSource(null);
        setStaleLocalDraft(false);
      }
    },
    [invalidateIntent],
  );

  const readFullBatch = useCallback(
    async (requestedBatchId: string): Promise<ReadFullBatchResult> => {
      if (!api || !authSubject || !requestedBatchId)
        return { workbench: null, error: "Chưa đủ thông tin để tải nhu cầu." };
      const pages: ConfirmedNeedWorkbenchData[] = [];
      let offset = 0;
      for (let pageNumber = 0; pageNumber < 10_000; pageNumber += 1) {
        const result = await api.getReview(
          authSubject,
          correlationId,
          requestedBatchId,
          emptyFilters,
          offset,
          pageSize,
        );
        const page = confirmedNeedWorkbenchFromResult(result);
        if (!page)
          return { workbench: null, error: confirmedNeedResultMessage(result) };
        pages.push(page);
        if (!page.pagination.has_more) break;
        if (!page.lines.length)
          return {
            workbench: null,
            error: "Không thể tải đủ toàn bộ nhu cầu. Hãy làm mới dữ liệu.",
          };
        offset += page.lines.length;
      }
      try {
        return { workbench: assembleConfirmedNeedPages(pages), error: null };
      } catch (error) {
        return {
          workbench: null,
          error:
            error instanceof Error
              ? error.message
              : "Không thể ghép toàn bộ nhu cầu.",
        };
      }
    },
    [api, authSubject, correlationId],
  );

  const loadReview = useCallback(
    async (requestedBatchId = batchId, preserveDraft = false) => {
      if (!api || !authSubject || !requestedBatchId) return false;
      const requestGeneration = invalidateIntent(!preserveDraft);
      setLoading(true);
      setNotice(null);
      const result = await readFullBatch(requestedBatchId);
      if (requestGeneration !== intentGeneration.current) {
        setLoading(false);
        return false;
      }
      setLoading(false);
      if (!result.workbench) {
        setNotice(result.error);
        return false;
      }
      setBatchId(requestedBatchId);
      setLifecycleRefreshRequired(false);
      adopt(result.workbench, preserveDraft);
      if (preserveDraft) setStaleLocalDraft(true);
      return true;
    },
    [api, authSubject, batchId, adopt, invalidateIntent, readFullBatch],
  );

  useEffect(() => {
    if (!initialBatchId || !authSubject) {
      if (!initialBatchId) {
        setBatchId("");
        setWorkbench(null);
      }
      return;
    }
    setBatchId(initialBatchId);
    void loadReview(initialBatchId);
  }, [authSubject, initialBatchId, loadReview]);

  const schools = useMemo(
    () =>
      Array.from(
        new Map(
          (workbench?.lines ?? []).map((line) => [line.school.id, line.school]),
        ).values(),
      ).sort((left, right) => left.name.localeCompare(right.name, "vi")),
    [workbench],
  );
  const serviceDates = useMemo(
    () =>
      Array.from(
        new Set((workbench?.lines ?? []).map((line) => line.service_date)),
      ).sort(),
    [workbench],
  );
  const visibleLines = useMemo(
    () =>
      (workbench?.lines ?? []).filter(
        (line) =>
          (!schoolFilter || line.school.id === schoolFilter) &&
          (!serviceDateFilter || line.service_date === serviceDateFilter),
      ),
    [schoolFilter, serviceDateFilter, workbench],
  );
  const selected = useMemo(
    () =>
      visibleLines.flatMap((line) => {
        const draft = drafts[line.confirmed_need_line_id];
        return draft?.selected ? [confirmedNeedLineRequest(line, draft)] : [];
      }),
    [drafts, visibleLines],
  );
  const selectedChunk = selected.slice(0, pageSize);
  const localErrors = useMemo(
    () =>
      visibleLines.flatMap((line) => {
        const draft = drafts[line.confirmed_need_line_id];
        if (!draft?.selected) return [];
        const message = localDraftError(line, draft);
        return message ? [{ line, message }] : [];
      }),
    [drafts, visibleLines],
  );
  const previewAdjustedLines = useMemo(
    () =>
      preview?.ordered_preview_lines.filter(
        (line) =>
          !exactDecimalEqual(
            line.proposed_quantity_before,
            line.confirmed_quantity_after,
          ),
      ) ?? [],
    [preview],
  );

  const editDraft = (
    lineId: string,
    patch: Partial<ConfirmedNeedDraftLine>,
    source: "direct" | "excel" = "direct",
  ) => {
    invalidateIntent(true);
    setDrafts((current) => ({
      ...current,
      [lineId]: {
        ...current[lineId],
        ...patch,
        selected:
          patch.selected ??
          (Object.keys(patch).some((key) => key !== "selected")
            ? true
            : current[lineId]?.selected),
      },
    }));
    setDraftTouched(true);
    setDraftSource(source);
    setStaleLocalDraft(false);
  };

  const requestPreview = async () => {
    if (!api || !authSubject || !workbench || !selectedChunk.length) return;
    if (localErrors.length) {
      setNotice(localErrors[0]?.message ?? "Bản nháp chưa hợp lệ.");
      return;
    }
    const requestGeneration = invalidateIntent();
    setBusy(true);
    setNotice(null);
    const result = await api.preview(
      confirmedNeedPreviewRequest(
        authSubject,
        correlationId,
        workbench.confirmed_need_batch_id,
        workbench.batch_version,
        selectedChunk,
      ),
    );
    if (requestGeneration !== intentGeneration.current) {
      setBusy(false);
      return;
    }
    setBusy(false);
    const next = confirmedNeedPreviewFromResult(result);
    if (!next) {
      const message = confirmedNeedResultMessage(result);
      if (confirmedNeedResultIsStale(result)) {
        if (await loadReview(batchId, true)) setNotice(message);
      } else setNotice(message);
      return;
    }
    if (!next.success && confirmedNeedPreviewIsStale(next)) {
      if (await loadReview(batchId, true))
        setNotice(
          "Dữ liệu đã thay đổi. Bản nháp của bạn vẫn được giữ để đối chiếu trước khi tiếp tục.",
        );
      return;
    }
    setPreview(next);
    setPreviewLines(selectedChunk);
    setPendingCommand(null);
    setNotice(
      next.success
        ? "Số lượng đã sẵn sàng để xác nhận. Hãy kiểm tra phần tóm tắt bên dưới."
        : "Hãy sửa đúng các nội dung được đánh dấu trước khi xác nhận số lượng.",
    );
  };

  const executeCommand = useCallback(
    async (request: ConfirmedNeedCommandRequest) => {
      if (!api) return;
      const requestGeneration = intentGeneration.current;
      setBusy(true);
      setNotice(null);
      const result: AtlasRpcResult = await api.confirm(request);
      if (requestGeneration !== intentGeneration.current) {
        setBusy(false);
        return;
      }
      setBusy(false);
      if (confirmedNeedResultAllowsExactRetry(result)) {
        setPendingCommand(request);
        setNotice(confirmedNeedResultMessage(result));
        return;
      }
      setPendingCommand(null);
      if (confirmedNeedResultIsStale(result)) {
        const message = confirmedNeedResultMessage(result);
        if (await loadReview(batchId, true)) setNotice(message);
        return;
      }
      if (result.kind !== "success") {
        setNotice(confirmedNeedResultMessage(result));
        return;
      }
      const message = confirmedNeedResultMessage(result);
      const readback = confirmedNeedReadbackFromResult(result);
      if (readback) adopt(readback);
      else if (!(await loadReview())) return;
      setNotice(message);
    },
    [adopt, api, batchId, loadReview],
  );

  const confirm = () => {
    if (
      !authSubject ||
      !workbench ||
      !preview?.success ||
      !preview.preview_hash
    )
      return;
    const request = confirmedNeedCommandRequest(
      authSubject,
      correlationId,
      workbench.confirmed_need_batch_id,
      workbench.batch_version,
      preview.preview_hash,
      previewLines,
    );
    setPendingCommand(request);
    void executeCommand(request);
  };

  const validateBatch = async () => {
    if (!api || !authSubject || !workbench?.validation_allowed) return;
    const requestGeneration = invalidateIntent();
    const request = confirmedNeedValidationRequest(
      authSubject,
      correlationId,
      workbench.confirmed_need_batch_id,
      workbench.batch_version,
    );
    setBusy(true);
    setNotice(null);
    const result = await api.validate(request);
    if (requestGeneration !== intentGeneration.current) {
      setBusy(false);
      return;
    }
    setBusy(false);
    if (confirmedNeedResultIsStale(result)) {
      const message = confirmedNeedResultMessage(result);
      if (await loadReview(batchId, true)) setNotice(message);
      return;
    }
    if (result.kind !== "success") {
      setNotice(confirmedNeedResultMessage(result));
      return;
    }
    const readback = confirmedNeedReadbackFromResult(result);
    if (readback) adopt(readback);
    else if (!(await loadReview())) return;
    setNotice(
      result.response.validation_status === "VALIDATED"
        ? "Đã hoàn tất xác nhận. Nhu cầu đang chờ phê duyệt."
        : "Chưa thể hoàn tất xác nhận. Hãy sửa các dòng được đánh dấu rồi thử lại.",
    );
  };

  const beginLifecycleConfirmation = (kind: "approval" | "release") => {
    invalidateIntent();
    setLifecycleConfirmation(kind);
    setNotice(null);
  };

  const executeLifecycleCommand = async (
    request: ConfirmedNeedApprovalRequest | ConfirmedNeedReleaseRequest,
    kind: "approval" | "release",
  ) => {
    if (!api) return;
    const requestGeneration = intentGeneration.current;
    setBusy(true);
    setNotice(null);
    const result =
      kind === "approval"
        ? await api.approve(request as ConfirmedNeedApprovalRequest)
        : await api.release(request as ConfirmedNeedReleaseRequest);
    if (requestGeneration !== intentGeneration.current) {
      setBusy(false);
      return;
    }
    setBusy(false);
    setLifecycleConfirmation(null);
    if (confirmedNeedLifecycleRequiresRefresh(result)) {
      setLifecycleRefreshRequired(true);
      setNotice(
        `${confirmedNeedResultMessage(result)} Hãy làm mới dữ liệu trước khi thử lại.`,
      );
      return;
    }
    if (result.kind !== "success") {
      setNotice(confirmedNeedResultMessage(result));
      return;
    }
    const message = confirmedNeedResultMessage(result);
    const readback = confirmedNeedReadbackFromResult(result);
    if (readback) adopt(readback);
    else if (!(await loadReview())) return;
    setNotice(message);
  };

  const confirmLifecycle = () => {
    if (!authSubject || !workbench || !lifecycleConfirmation) return;
    const request =
      lifecycleConfirmation === "approval"
        ? confirmedNeedApprovalRequest(
            authSubject,
            correlationId,
            workbench.confirmed_need_batch_id,
            workbench.batch_version,
          )
        : confirmedNeedReleaseRequest(
            authSubject,
            correlationId,
            workbench.confirmed_need_batch_id,
            workbench.batch_version,
          );
    void executeLifecycleCommand(request, lifecycleConfirmation);
  };

  const refreshAuthoritative = async () => {
    if (
      unsafeLocalWork &&
      !lifecycleRefreshRequired &&
      !window.confirm(
        "Làm mới sẽ bỏ bản nháp và kết quả Excel chưa xác nhận. Tiếp tục?",
      )
    )
      return;
    await loadReview(batchId);
  };

  const exportWorkbook = async () => {
    if (!workbench) return;
    setBusy(true);
    setNotice(null);
    const fresh = await readFullBatch(workbench.confirmed_need_batch_id);
    if (
      !fresh.workbench ||
      !authorityBindingsMatch(workbench, fresh.workbench)
    ) {
      setBusy(false);
      setNotice(
        fresh.error ??
          "Dữ liệu đã thay đổi. Hãy làm mới trước khi xuất file Excel mới.",
      );
      return;
    }
    try {
      await downloadConfirmedNeedWorkbook(
        fresh.workbench,
        drafts,
        `Xac-nhan-nhu-cau-${fresh.workbench.service_period.period_start}.xlsx`,
      );
      setNotice(
        `Đã xuất toàn bộ ${fresh.workbench.pagination.total_lines} dòng. Xuất Excel không ghi dữ liệu nghiệp vụ.`,
      );
    } catch {
      setNotice("Không thể tạo file Excel. Hãy thử xuất lại.");
    } finally {
      setBusy(false);
    }
  };

  const importWorkbook = async (file: File) => {
    if (!workbench) return;
    invalidateIntent(true);
    setBusy(true);
    setNotice(null);
    try {
      const workbook = await readConfirmedNeedWorkbook(file);
      const fresh = await readFullBatch(workbench.confirmed_need_batch_id);
      if (
        !fresh.workbench ||
        !authorityBindingsMatch(workbench, fresh.workbench)
      ) {
        setStaleLocalDraft(true);
        setNotice(
          fresh.error ??
            "Dữ liệu đã thay đổi. Bản nháp hiện tại được giữ lại; hãy làm mới và xuất file mới.",
        );
        return;
      }
      const review = reviewConfirmedNeedWorkbook(
        workbook,
        fresh.workbench,
        drafts,
      );
      setImportReview(review);
      setNotice(
        review.canApply
          ? "Đã đọc file Excel. Các thay đổi chưa được áp dụng vào bảng và chưa được lưu."
          : "File Excel có lỗi. Bản nháp hiện tại vẫn được giữ nguyên.",
      );
    } catch {
      setImportReview({
        totalRows: 0,
        changedRows: 0,
        unchangedRows: 0,
        errorRows: 1,
        errors: [
          {
            rowNumber: null,
            field: "File Excel",
            message:
              "Không thể đọc file Excel. Hãy dùng file được xuất từ trang này.",
          },
        ],
        changedLines: [],
        candidate: null,
        canApply: false,
      });
      setNotice(
        "Không thể đọc file Excel. Bản nháp hiện tại vẫn được giữ nguyên.",
      );
    } finally {
      setBusy(false);
    }
  };

  const applyWorkbook = () => {
    if (!importReview?.canApply) return;
    invalidateIntent();
    setDrafts((current) =>
      applyConfirmedNeedWorkbookReview(importReview, current),
    );
    setImportReview(null);
    setDraftTouched(true);
    setDraftSource("excel");
    setStaleLocalDraft(false);
    setNotice(
      "Đã áp dụng thay đổi Excel vào bảng trên màn hình. Chưa lưu dữ liệu.",
    );
  };

  const status = workbench?.authoritative_batch_status;
  const draftLifecycle = status === "DRAFT_REVIEW" || status === "REOPENED";
  const released = status === "RELEASED_FOR_PURCHASE_HANDOFF";
  const nextConsequence = lifecycleRefreshRequired
    ? "Làm mới để xem kết quả mới nhất trước khi tiếp tục."
    : preview?.success
      ? "Xác nhận sẽ lưu các số lượng trong phần kiểm tra cuối cùng. Hệ thống không tự chuyển sang bước tiếp theo."
      : draftLifecycle && selected.length > 0
        ? `Kiểm tra tối đa ${Math.min(selected.length, pageSize)} dòng và mở phần xác nhận cuối cùng. Chưa lưu thay đổi.`
        : draftLifecycle && (workbench?.line_counts.unreviewed ?? 0) > 0
          ? "Phạm vi đang xem không còn dòng cần xác nhận. Xem các dòng còn lại để tiếp tục."
          : draftLifecycle
            ? "Kiểm tra toàn bộ số lượng và cho biết các dòng cần sửa trước khi hoàn tất."
            : status === "VALIDATED"
              ? "Phê duyệt toàn bộ số lượng đã hoàn tất xác nhận."
              : status === "APPROVED"
                ? "Phát hành để bước lên đơn có thể sử dụng số lượng đã phê duyệt; chưa tạo đơn mua."
                : released
                  ? "Nhu cầu đã được phát hành. SL xác nhận không nhất thiết là SL đặt mua; mọi làm tròn mua hàng sau này sẽ được hiển thị trước khi cam kết mua."
                  : "Làm mới để xác định hành động tiếp theo.";

  return (
    <div className="confirmed-need-shell">
      <Panel
        title="Xác nhận nhu cầu"
        description="Rà soát số lượng đề xuất và nhập số lượng xác nhận cho tuần phục vụ."
        status={
          <Chip
            tone={
              workbench?.blockers.length ||
              currentNeedResolution === "denied" ||
              currentNeedResolution === "error"
                ? "danger"
                : "warning"
            }
          >
            {workbench
              ? lifecycleLabel(status)
              : currentNeedResolution === "loading"
                ? "Đang tải"
                : currentNeedResolution === "missing"
                  ? "Chưa có nhu cầu"
                  : currentNeedResolution === "denied"
                    ? "Không thể truy cập"
                    : "Chưa có dữ liệu"}
          </Chip>
        }
      >
        <div className="confirmed-need-workbench">
          <div className="confirmed-need-context">
            {workbench ? (
              <>
                <div>
                  <span>Tuần phục vụ</span>
                  <b>
                    {viDate(workbench.service_period.period_start)} –{" "}
                    {viDate(workbench.service_period.period_end)}
                  </b>
                </div>
                <div>
                  <span>Trạng thái hiện tại</span>
                  <b>{lifecycleLabel(status)}</b>
                </div>
                <label>
                  <span>Trường</span>
                  <select
                    aria-label="Trường đang xem"
                    value={schoolFilter}
                    onChange={(event) => {
                      invalidateIntent();
                      setSchoolFilter(event.target.value);
                    }}
                  >
                    <option value="">Tất cả trường</option>
                    {schools.map((school) => (
                      <option key={school.id} value={school.id}>
                        {school.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  <span>Ngày</span>
                  <select
                    aria-label="Ngày đang xem"
                    value={serviceDateFilter}
                    onChange={(event) => {
                      invalidateIntent();
                      setServiceDateFilter(event.target.value);
                    }}
                  >
                    <option value="">Tất cả các ngày</option>
                    {serviceDates.map((date) => (
                      <option key={date} value={date}>
                        {viDate(date)}
                      </option>
                    ))}
                  </select>
                </label>
                <button
                  type="button"
                  className="quiet"
                  disabled={loading || busy}
                  onClick={() => void refreshAuthoritative()}
                >
                  Làm mới dữ liệu
                </button>
              </>
            ) : currentNeedResolution === "loading" ? (
              <span>Đang tìm nhu cầu xác nhận cho tuần này…</span>
            ) : currentNeedResolution === "missing" ? (
              <span>Chưa có nhu cầu xác nhận cho tuần này.</span>
            ) : currentNeedResolution === "denied" ? (
              <span>Bạn không có quyền truy cập nhu cầu xác nhận này.</span>
            ) : currentNeedResolution === "error" ? (
              <span>
                Không thể tải nhu cầu xác nhận. Hãy thử làm mới trang.
              </span>
            ) : (
              <span>Chưa có nhu cầu xác nhận để hiển thị.</span>
            )}
          </div>

          {loading && <p role="status">Đang tải nhu cầu xác nhận…</p>}
          {workbench && (
            <>
              <section
                className="confirmed-need-attention"
                aria-label="Tình hình xác nhận nhu cầu"
              >
                <span>
                  Tổng số dòng <b>{workbench.line_counts.total}</b>
                </span>
                <span>
                  Chưa xác nhận <b>{workbench.line_counts.unreviewed}</b>
                </span>
                <span>
                  Đã điều chỉnh <b>{workbench.line_counts.adjusted}</b>
                </span>
                <span>
                  Cần xử lý <b>{workbench.validation.blocking_count}</b>
                </span>
              </section>

              {draftSource === "excel" && (
                <p className="confirmed-need-local-notice" role="status">
                  Thay đổi từ Excel mới chỉ nằm trong bảng trên màn hình; chưa
                  được lưu.
                </p>
              )}
              {staleLocalDraft && (
                <p className="confirmed-need-stale-notice" role="alert">
                  Bản nháp đang dựa trên dữ liệu cũ. Hãy đối chiếu sau khi làm
                  mới trước khi xác nhận.
                </p>
              )}

              {issueList(
                "Dòng cần sửa trước khi hoàn tất",
                workbench.validation.grouped_issues.blocking,
                "danger",
              )}
              {issueList(
                "Cảnh báo",
                workbench.validation.grouped_issues.warnings,
                "warning",
              )}
              {issueList("Lỗi chặn", workbench.blockers, "danger")}
              {issueList("Cảnh báo", workbench.warnings, "warning")}

              <div className="confirmed-need-table-scroll">
                <CompactTable
                  headers={[
                    "Nguyên liệu / Ngày / Trường / Điểm giao",
                    "ĐVT",
                    "SL lý thuyết",
                    "SL đề xuất",
                    "SL xác nhận",
                    "Chênh lệch",
                    "Lý do / Ghi chú",
                  ]}
                >
                  {visibleLines.map((line) => {
                    const draft =
                      drafts[line.confirmed_need_line_id] ??
                      initialConfirmedNeedDraft(line);
                    const error = draft.selected
                      ? localDraftError(line, draft)
                      : null;
                    const difference = subtractExactDecimals(
                      draft.exact_quantity,
                      line.proposed_confirmed_quantity,
                    );
                    const adjusted = !exactDecimalEqual(
                      draft.exact_quantity,
                      line.proposed_confirmed_quantity,
                    );
                    return (
                      <tr key={line.confirmed_need_line_id}>
                        <td>
                          <b>{line.ingredient.name}</b>
                          <small>
                            {viDate(line.service_date)} · {line.school.name} ·{" "}
                            {line.delivery_location.name}
                          </small>
                        </td>
                        <td>{line.controlled_unit.code}</td>
                        <td>
                          {exactQuantityDisplay(line.theoretical_quantity)}
                        </td>
                        <td>
                          {exactQuantityDisplay(
                            line.proposed_confirmed_quantity,
                          )}
                        </td>
                        <td>
                          <input
                            aria-label={`Số lượng xác nhận ${line.ingredient.name}`}
                            inputMode="decimal"
                            value={draft.exact_quantity}
                            disabled={!workbench.editing_allowed}
                            onChange={(event) => {
                              const exactQuantity = event.target.value;
                              const returnsToProposal = exactDecimalEqual(
                                exactQuantity,
                                line.proposed_confirmed_quantity,
                              );
                              editDraft(line.confirmed_need_line_id, {
                                exact_quantity: exactQuantity,
                                ...(returnsToProposal
                                  ? {
                                      reason_code: "PROPOSAL_ACCEPTED",
                                      reason_note: "",
                                    }
                                  : {}),
                              });
                            }}
                          />
                          <small className="confirmed-need-policy-hint">
                            Bước gợi ý:{" "}
                            {line.effective_policy ? (
                              <>
                                {exactQuantityDisplay(
                                  line.effective_policy.planning_step,
                                )}{" "}
                                {line.controlled_unit.code}
                              </>
                            ) : (
                              "cần xử lý"
                            )}
                          </small>
                        </td>
                        <td className="confirmed-need-difference">
                          {difference ?? "—"}
                        </td>
                        <td>
                          {!adjusted && !error ? (
                            <span className="confirmed-need-accepted-proposal">
                              Chấp nhận đề xuất
                            </span>
                          ) : (
                            <div className="confirmed-need-adjustment-fields">
                              <label>
                                Lý do điều chỉnh
                                <select
                                  aria-label={`Lý do ${line.ingredient.name}`}
                                  value={
                                    adjusted &&
                                    draft.reason_code === "PROPOSAL_ACCEPTED"
                                      ? ""
                                      : draft.reason_code
                                  }
                                  disabled={!workbench.editing_allowed}
                                  onChange={(event) =>
                                    editDraft(line.confirmed_need_line_id, {
                                      reason_code: event.target
                                        .value as ConfirmedNeedDraftLine["reason_code"],
                                    })
                                  }
                                >
                                  {adjusted && (
                                    <option value="" disabled>
                                      Chọn lý do
                                    </option>
                                  )}
                                  {confirmedNeedReasonOptions()
                                    .filter(([code]) =>
                                      adjusted
                                        ? code !== "PROPOSAL_ACCEPTED"
                                        : code === "PROPOSAL_ACCEPTED",
                                    )
                                    .map(([code, label]) => (
                                      <option key={code} value={code}>
                                        {label}
                                      </option>
                                    ))}
                                </select>
                              </label>
                              <label>
                                Ghi chú
                                <input
                                  aria-label={`Ghi chú ${line.ingredient.name}`}
                                  value={draft.reason_note}
                                  disabled={!workbench.editing_allowed}
                                  onChange={(event) =>
                                    editDraft(line.confirmed_need_line_id, {
                                      reason_note: event.target.value,
                                    })
                                  }
                                  placeholder="Bổ sung khi được yêu cầu"
                                />
                              </label>
                            </div>
                          )}
                          <small>
                            {decisionLabel(line.current_decision_kind)}
                          </small>
                          {error && <small role="alert">{error}</small>}
                          {line.validation_issues.blocking.length > 0 &&
                            issueList(
                              "Cần sửa dòng này",
                              line.validation_issues.blocking,
                              "danger",
                            )}
                          {line.decision_history.length > 0 && (
                            <details>
                              <summary>
                                Lịch sử ({line.decision_history.length})
                              </summary>
                              <ol>
                                {line.decision_history.map((decision) => (
                                  <li key={decision.decision_id}>
                                    {exactQuantityDisplay(
                                      decision.confirmed_quantity_after,
                                    )}{" "}
                                    {line.controlled_unit.code} ·{" "}
                                    {confirmedNeedReasonLabel(
                                      decision.reason_code,
                                    )}
                                    {decision.reason_note && (
                                      <small>{decision.reason_note}</small>
                                    )}
                                  </li>
                                ))}
                              </ol>
                            </details>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </CompactTable>
                {visibleLines.length === 0 && (
                  <p role="status">
                    Không có dòng nào phù hợp với trường và ngày đang chọn.
                  </p>
                )}
              </div>

              <section
                className="confirmed-need-xlsx-actions"
                aria-label="Làm việc với Excel"
              >
                <div>
                  <b>Excel (không bắt buộc)</b>
                  <small>
                    Có thể xuất toàn bộ nhu cầu của tuần, chỉnh sửa rồi nhập
                    lại. Không cần dùng Excel để xác nhận trên màn hình.
                  </small>
                </div>
                <button
                  type="button"
                  className="quiet"
                  disabled={busy}
                  onClick={() => void exportWorkbook()}
                >
                  Xuất Excel
                </button>
                <label className="confirmed-need-file-action">
                  Nhập Excel
                  <input
                    type="file"
                    accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    disabled={busy || !workbench.editing_allowed}
                    onChange={(event) => {
                      const file = event.target.files?.[0];
                      event.currentTarget.value = "";
                      if (file) void importWorkbook(file);
                    }}
                  />
                </label>
              </section>

              {importReview && (
                <section
                  className="confirmed-need-import-review"
                  aria-label="Đã đọc file Excel"
                >
                  <header>
                    <div>
                      <strong>Đã đọc file Excel</strong>
                      <small>
                        Kết quả này chỉ là so sánh trên màn hình, chưa lưu dữ
                        liệu.
                      </small>
                    </div>
                    <button
                      type="button"
                      className="quiet"
                      onClick={() => setImportReview(null)}
                    >
                      Đóng
                    </button>
                  </header>
                  <dl>
                    <div>
                      <dt>Tổng số dòng</dt>
                      <dd>{importReview.totalRows}</dd>
                    </div>
                    <div>
                      <dt>Dòng thay đổi</dt>
                      <dd>{importReview.changedRows}</dd>
                    </div>
                    <div>
                      <dt>Dòng không thay đổi</dt>
                      <dd>{importReview.unchangedRows}</dd>
                    </div>
                    <div>
                      <dt>Dòng lỗi</dt>
                      <dd>{importReview.errorRows}</dd>
                    </div>
                  </dl>
                  {importReview.errors.length > 0 && (
                    <ul className="confirmed-need-import-errors">
                      {importReview.errors.map((error, index) => (
                        <li key={`${error.rowNumber}:${error.field}:${index}`}>
                          <b>
                            {error.rowNumber
                              ? `Dòng ${error.rowNumber}`
                              : "File"}{" "}
                            · {error.field}
                          </b>
                          <span>{error.message}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                  {importReview.changedLines.length > 0 && (
                    <div className="confirmed-need-import-changes">
                      {importReview.changedLines.map((changed) => (
                        <article key={changed.line.confirmed_need_line_id}>
                          <div>
                            <b>{changed.line.ingredient.name}</b>
                            <small>
                              {viDate(changed.line.service_date)} ·{" "}
                              {changed.line.school.name}
                            </small>
                          </div>
                          <span>
                            {changed.before.exact_quantity} →{" "}
                            <b>{changed.after.exact_quantity}</b>{" "}
                            {changed.line.controlled_unit.code}
                          </span>
                          <span>
                            So với đề xuất: {changed.differenceFromProposal}
                          </span>
                          <span>
                            {confirmedNeedReasonLabel(
                              changed.after.reason_code,
                            )}
                            {changed.noteRequired ? " · Cần ghi chú" : ""}
                          </span>
                        </article>
                      ))}
                    </div>
                  )}
                  <button
                    type="button"
                    className="primary"
                    disabled={!importReview.canApply}
                    onClick={applyWorkbook}
                  >
                    Áp dụng vào bảng
                  </button>
                </section>
              )}

              {preview && (
                <section
                  className="confirmed-need-preview"
                  aria-label={
                    preview.success ? "Kiểm tra lần cuối" : "Nội dung cần sửa"
                  }
                >
                  <header>
                    <strong>
                      {preview.success
                        ? "Kiểm tra lần cuối"
                        : "Cần sửa trước khi xác nhận"}
                    </strong>
                    <small>
                      {preview.success
                        ? `${preview.ordered_preview_lines.length} dòng, ${previewAdjustedLines.length} dòng điều chỉnh. Chưa lưu dữ liệu.`
                        : "Các nội dung bên dưới cho biết chính xác điều cần sửa."}
                    </small>
                  </header>
                  {issueList("Cần xử lý", preview.blockers, "danger")}
                  {issueList("Cảnh báo", preview.warnings, "warning")}
                  {previewAdjustedLines.map((line) => {
                    const sourceLine = workbench.lines.find(
                      (candidate) =>
                        candidate.confirmed_need_line_id ===
                        line.confirmed_need_line_id,
                    );
                    return (
                      <p key={line.confirmed_need_line_id}>
                        {sourceLine?.ingredient.name ?? "Dòng điều chỉnh"}:{" "}
                        {exactQuantityDisplay(line.proposed_quantity_before)} →{" "}
                        <b>
                          {exactQuantityDisplay(line.confirmed_quantity_after)}
                        </b>{" "}
                        {sourceLine?.controlled_unit.code}
                      </p>
                    );
                  })}
                  <div className="confirmed-need-preview-actions">
                    {preview.success && (
                      <button
                        type="button"
                        className="primary"
                        disabled={
                          busy ||
                          !workbench.allowed_actions.confirm_quantities ||
                          !workbench.editing_allowed
                        }
                        onClick={confirm}
                      >
                        Xác nhận
                      </button>
                    )}
                    <button
                      type="button"
                      className="quiet"
                      disabled={busy}
                      onClick={() => invalidateIntent()}
                    >
                      Quay lại
                    </button>
                  </div>
                </section>
              )}

              {selected.length > pageSize && !preview && (
                <p className="confirmed-need-batch-progress" role="status">
                  Có {selected.length} quyết định cần xác nhận. Mỗi lần xử lý
                  tối đa {pageSize} dòng; sau mỗi lần, bạn sẽ xác nhận nhóm tiếp
                  theo. Hệ thống không tự lưu nhóm tiếp theo.
                </p>
              )}

              {!preview && (
                <section
                  className="confirmed-need-next-action"
                  aria-label="Hành động tiếp theo"
                >
                  <div>
                    <span>Hành động tiếp theo</span>
                    <p>{nextConsequence}</p>
                  </div>
                  {lifecycleRefreshRequired ? (
                    <button
                      type="button"
                      className="primary"
                      disabled={busy}
                      onClick={() => void refreshAuthoritative()}
                    >
                      Làm mới dữ liệu
                    </button>
                  ) : draftLifecycle && selected.length > 0 ? (
                    <button
                      type="button"
                      className="primary"
                      disabled={
                        busy ||
                        localErrors.length > 0 ||
                        !workbench.allowed_actions.preview_confirmation ||
                        !workbench.editing_allowed ||
                        staleLocalDraft
                      }
                      onClick={() => void requestPreview()}
                    >
                      Xác nhận số lượng
                    </button>
                  ) : draftLifecycle && workbench.line_counts.unreviewed > 0 ? (
                    <button
                      type="button"
                      className="primary"
                      disabled={busy}
                      onClick={() => {
                        setSchoolFilter("");
                        setServiceDateFilter("");
                      }}
                    >
                      Xem các dòng còn lại
                    </button>
                  ) : draftLifecycle ? (
                    <button
                      type="button"
                      className="primary"
                      disabled={busy || !workbench.validation_allowed}
                      onClick={() => void validateBatch()}
                    >
                      Hoàn tất xác nhận
                    </button>
                  ) : status === "VALIDATED" &&
                    workbench.allowed_actions.approve_confirmed_needs ? (
                    <button
                      type="button"
                      className="primary commitment"
                      disabled={busy}
                      onClick={() => beginLifecycleConfirmation("approval")}
                    >
                      Phê duyệt
                    </button>
                  ) : status === "APPROVED" &&
                    workbench.allowed_actions
                      .release_confirmed_needs_for_purchase_handoff ? (
                    <button
                      type="button"
                      className="primary commitment"
                      disabled={busy}
                      onClick={() => beginLifecycleConfirmation("release")}
                    >
                      Phát hành
                    </button>
                  ) : null}
                </section>
              )}

              {lifecycleConfirmation && (
                <section
                  className="confirmed-need-commitment"
                  aria-label="Xác nhận bước tiếp theo"
                >
                  <p>
                    {lifecycleConfirmation === "approval"
                      ? "Phê duyệt toàn bộ số lượng đã hoàn tất xác nhận?"
                      : "Phát hành cho bước lên đơn sử dụng sau này? Hành động này không chọn nhà cung cấp, không tạo bàn giao mua hàng và không tạo đơn mua. SL xác nhận không nhất thiết là SL đặt mua; mọi làm tròn mua hàng sau này sẽ được hiển thị trước khi cam kết mua."}
                  </p>
                  <div>
                    <button
                      type="button"
                      className="primary"
                      disabled={busy}
                      onClick={confirmLifecycle}
                    >
                      {lifecycleConfirmation === "approval"
                        ? "Xác nhận phê duyệt"
                        : "Xác nhận phát hành"}
                    </button>
                    <button
                      type="button"
                      className="quiet"
                      disabled={busy}
                      onClick={() => setLifecycleConfirmation(null)}
                    >
                      Hủy
                    </button>
                  </div>
                </section>
              )}

              {pendingCommand && (
                <button
                  type="button"
                  className="confirmed-need-exact-retry"
                  disabled={busy}
                  onClick={() => void executeCommand(pendingCommand)}
                >
                  Thử lưu lại
                </button>
              )}

              {(workbench.lifecycle_history.length > 0 ||
                workbench.approval.approved_actor ||
                workbench.release.released_actor) && (
                <details className="confirmed-need-evidence">
                  <summary>Lịch sử xử lý</summary>
                  <ol>
                    {workbench.lifecycle_history.map((item) => (
                      <li key={`${item.evidence_kind}:${item.evidence_id}`}>
                        {item.evidence_kind === "VALIDATION"
                          ? "Hoàn tất xác nhận"
                          : item.evidence_kind === "APPROVAL"
                            ? "Phê duyệt"
                            : "Phát hành"}{" "}
                        · {item.actor.name} ·{" "}
                        {new Date(item.occurred_at).toLocaleString("vi-VN")}
                      </li>
                    ))}
                  </ol>
                </details>
              )}
            </>
          )}

          {notice && (
            <p className="operator-notice" role="status">
              {notice}
            </p>
          )}
        </div>
      </Panel>
    </div>
  );
}
