import { useMemo, useState } from "react";
import { formatDateWithWeekdayVi } from "./date";
import { DemandSourcePanel } from "./components/DemandSourcePanel";
import { PlannerHeader } from "./components/PlannerHeader";
import { PlannerSummaryCards } from "./components/PlannerSummaryCards";
import {
  RequirementDetail,
  RequirementTable,
  type RequirementGroup,
} from "./components/RequirementWorkspace";
import { demandSources, requirementLines } from "./fixtures/plannerFixtures";
import type {
  Filters,
  LocalLineState,
  PlannerViewMode,
  RequirementLine,
} from "./types";

const initialFilters: Filters = {
  from: "2026-07-13",
  to: "2026-07-15",
  sourceType: "",
  customer: "",
  severity: "",
  readiness: "",
  search: "",
};

export type PlannerReviewScenario =
  "all" | "normal" | "exception-first" | "blocked";

function filtersForScenario(scenario: PlannerReviewScenario): Filters {
  if (scenario === "normal") return { ...initialFilters, readiness: "READY" };
  if (scenario === "blocked") {
    return { ...initialFilters, readiness: "BLOCKED" };
  }
  return initialFilters;
}
const blankState = (): LocalLineState => ({
  reviewed: false,
  flagged: false,
  substitutionDraft: false,
  overrideDraft: false,
  locallyReady: false,
  reviewNote: "",
});

function requiresAttention(line: RequirementLine, state?: LocalLineState) {
  return (
    line.severity === "WARNING" ||
    line.severity === "BLOCKING" ||
    line.supplierStatus === "MISSING" ||
    line.supplierStatus === "CONFLICT" ||
    line.readiness === "NEEDS_REVIEW" ||
    line.readiness === "BLOCKED" ||
    line.hasSubstitution ||
    line.hasOverride ||
    Boolean(state?.flagged)
  );
}

function groupLines(
  lines: RequirementLine[],
  viewMode: PlannerViewMode,
): RequirementGroup[] {
  const groups = new Map<string, RequirementLine[]>();
  const keyFor = (line: RequirementLine) => {
    if (viewMode === "CUSTOMER") return line.customer;
    if (viewMode === "SOURCE") return line.sourceType;
    return line.serviceDate;
  };
  lines.forEach((line) => {
    const key = keyFor(line);
    groups.set(key, [...(groups.get(key) ?? []), line]);
  });
  const sourceLabel: Record<string, string> = {
    CATERING_MENU: "Thực đơn",
    WHOLESALE_ORDER: "Bán sỉ",
    PANTRY_ADD: "Bổ sung kho",
    MANUAL_DEMAND: "Thủ công",
    CORRECTION: "Điều chỉnh",
  };
  return [...groups.entries()].map(([key, group]) => {
    const blockers = group.filter(
      (line) => line.severity === "BLOCKING" || line.readiness === "BLOCKED",
    ).length;
    const attention = group.filter((line) => requiresAttention(line)).length;
    const ready = group.filter((line) => line.readiness === "READY").length;
    const sourceCount = new Set(group.map((line) => line.sourceId)).size;
    const title =
      viewMode === "DATE"
        ? formatDateWithWeekdayVi(key)
        : viewMode === "SOURCE"
          ? sourceLabel[key]
          : key;
    const summary =
      viewMode === "DATE"
        ? `${group.length} dòng · ${attention} cần kiểm tra · ${blockers} đang chặn · ${ready} sẵn sàng mua hàng`
        : `${sourceCount} nguồn nhu cầu · ${group.length} dòng · ${attention} cần kiểm tra · ${blockers} đang chặn`;
    return { id: `${viewMode}-${key}`, title, summary, lines: group };
  });
}

export function PlannerWorkspacePage({
  reviewScenario = "all",
}: {
  reviewScenario?: PlannerReviewScenario;
}) {
  const [filters, setFilters] = useState(() =>
    filtersForScenario(reviewScenario),
  );
  const [viewMode, setViewMode] = useState<PlannerViewMode>("DATE");
  const [attentionOnly, setAttentionOnly] = useState(
    reviewScenario === "exception-first",
  );
  const [selectedSource, setSelectedSource] = useState("");
  const [selectedId, setSelectedId] = useState<string>();
  const [localStates, setLocalStates] = useState<
    Record<string, LocalLineState>
  >({});
  const customers = [
    ...new Set(demandSources.map((source) => source.customer)),
  ];
  const sources = useMemo(
    () =>
      demandSources.filter(
        (source) =>
          (!filters.from || source.serviceDate >= filters.from) &&
          (!filters.to || source.serviceDate <= filters.to) &&
          (!filters.sourceType || source.type === filters.sourceType) &&
          (!filters.customer || source.customer === filters.customer),
      ),
    [filters],
  );
  const lines = useMemo(
    () =>
      requirementLines.filter(
        (line) =>
          (!filters.from || line.serviceDate >= filters.from) &&
          (!filters.to || line.serviceDate <= filters.to) &&
          (!filters.sourceType || line.sourceType === filters.sourceType) &&
          (!filters.customer || line.customer === filters.customer) &&
          (!filters.severity || line.severity === filters.severity) &&
          (!filters.readiness || line.readiness === filters.readiness) &&
          (!selectedSource || line.sourceId === selectedSource) &&
          (!filters.search ||
            `${line.ingredient} ${line.customer} ${line.sourceReference} ${line.supplierName ?? ""}`
              .toLocaleLowerCase("vi")
              .includes(filters.search.toLocaleLowerCase("vi"))) &&
          (!attentionOnly || requiresAttention(line, localStates[line.id])),
      ),
    [filters, selectedSource, attentionOnly, localStates],
  );
  const groups = useMemo(() => groupLines(lines, viewMode), [lines, viewMode]);
  const selected = requirementLines.find((line) => line.id === selectedId);
  const toggle = (key: Exclude<keyof LocalLineState, "reviewNote">) => {
    if (!selectedId) return;
    setLocalStates((current) => ({
      ...current,
      [selectedId]: {
        ...(current[selectedId] ?? blankState()),
        [key]: !(current[selectedId] ?? blankState())[key],
      },
    }));
  };
  const updateReviewNote = (reviewNote: string) => {
    if (!selectedId) return;
    setLocalStates((current) => ({
      ...current,
      [selectedId]: { ...(current[selectedId] ?? blankState()), reviewNote },
    }));
  };
  const reset = () => {
    setFilters(filtersForScenario(reviewScenario));
    setViewMode("DATE");
    setAttentionOnly(reviewScenario === "exception-first");
    setSelectedSource("");
    setSelectedId(undefined);
    setLocalStates({});
  };
  return (
    <main>
      <PlannerHeader
        filters={filters}
        customers={customers}
        viewMode={viewMode}
        attentionOnly={attentionOnly}
        onChange={setFilters}
        onViewModeChange={setViewMode}
        onAttentionOnlyChange={setAttentionOnly}
        onReset={reset}
      />
      <div className="prototype-banner">
        Đây là prototype dùng dữ liệu mẫu. Các số lượng và truy vết chỉ phục vụ
        rà soát luồng nghiệp vụ.
      </div>
      <PlannerSummaryCards sources={sources} lines={lines} />
      <div className="workspace">
        <DemandSourcePanel
          sources={sources}
          selected={selectedSource}
          onSelect={setSelectedSource}
        />
        <RequirementTable
          groups={groups}
          selected={selectedId}
          onSelect={setSelectedId}
          states={localStates}
        />
      </div>
      <section className="exceptions">
        <div>
          <span className="eyebrow">NGOẠI LỆ & HÀNH ĐỘNG NHÁP</span>
          <h2>Hàng đợi cần xử lý</h2>
        </div>
        <div className="exception-metrics">
          <span>
            <b>{lines.filter((line) => line.readiness === "BLOCKED").length}</b>{" "}
            dòng đang chặn (fixture)
          </span>
          <span>
            <b>
              {lines.filter((line) => line.readiness === "NEEDS_REVIEW").length}
            </b>{" "}
            dòng cần duyệt (fixture)
          </span>
          <span>
            <b>
              {
                Object.values(localStates).filter((state) => state.flagged)
                  .length
              }
            </b>{" "}
            cờ cục bộ
          </span>
          <span>
            <b>
              {
                Object.values(localStates).filter(
                  (state) => state.substitutionDraft || state.overrideDraft,
                ).length
              }
            </b>{" "}
            nháp điều chỉnh
          </span>
        </div>
        <p>
          Chọn một dòng để đánh dấu đã xem, gắn cờ, tạo nháp thay thế/override
          hoặc xem đầy đủ trace. Không có thao tác nào gọi backend.
        </p>
      </section>
      {selected && (
        <>
          <div className="scrim" onClick={() => setSelectedId(undefined)} />
          <RequirementDetail
            line={selected}
            state={localStates[selected.id] ?? blankState()}
            onAction={toggle}
            onReviewNoteChange={updateReviewNote}
            onClose={() => setSelectedId(undefined)}
          />
        </>
      )}
    </main>
  );
}
