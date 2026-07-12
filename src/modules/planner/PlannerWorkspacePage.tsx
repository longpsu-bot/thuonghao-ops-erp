import { useMemo, useState } from "react";
import { demandSources, requirementLines } from "./fixtures/plannerFixtures";
import type { Filters, LocalLineState } from "./types";
import { DemandSourcePanel } from "./components/DemandSourcePanel";
import { PlannerHeader } from "./components/PlannerHeader";
import { PlannerSummaryCards } from "./components/PlannerSummaryCards";
import {
  RequirementDetail,
  RequirementTable,
} from "./components/RequirementWorkspace";

const initialFilters: Filters = {
  from: "2026-07-13",
  to: "2026-07-15",
  sourceType: "",
  customer: "",
  severity: "",
  readiness: "",
  search: "",
};
const blankState = (): LocalLineState => ({
  reviewed: false,
  flagged: false,
  substitutionDraft: false,
  overrideDraft: false,
  locallyReady: false,
});

export function PlannerWorkspacePage() {
  const [filters, setFilters] = useState(initialFilters);
  const [selectedSource, setSelectedSource] = useState("");
  const [selectedId, setSelectedId] = useState<string>();
  const [localStates, setLocalStates] = useState<
    Record<string, LocalLineState>
  >({});
  const customers = [...new Set(demandSources.map((x) => x.customer))];
  const sources = useMemo(
    () =>
      demandSources.filter(
        (x) =>
          x.serviceDate >= filters.from &&
          x.serviceDate <= filters.to &&
          (!filters.sourceType || x.type === filters.sourceType) &&
          (!filters.customer || x.customer === filters.customer),
      ),
    [filters],
  );
  const lines = useMemo(
    () =>
      requirementLines.filter(
        (x) =>
          x.serviceDate >= filters.from &&
          x.serviceDate <= filters.to &&
          (!filters.sourceType || x.sourceType === filters.sourceType) &&
          (!filters.customer || x.customer === filters.customer) &&
          (!filters.severity || x.severity === filters.severity) &&
          (!filters.readiness || x.readiness === filters.readiness) &&
          (!selectedSource || x.sourceId === selectedSource) &&
          (!filters.search ||
            `${x.ingredient} ${x.customer} ${x.sourceReference} ${x.supplierName ?? ""}`
              .toLocaleLowerCase("vi")
              .includes(filters.search.toLocaleLowerCase("vi"))),
      ),
    [filters, selectedSource],
  );
  const selected = requirementLines.find((x) => x.id === selectedId);
  const toggle = (key: keyof LocalLineState) => {
    if (!selectedId) return;
    setLocalStates((old) => {
      const current = old[selectedId] ?? blankState();
      return { ...old, [selectedId]: { ...current, [key]: !current[key] } };
    });
  };
  const reset = () => {
    setFilters(initialFilters);
    setSelectedSource("");
    setSelectedId(undefined);
    setLocalStates({});
  };
  return (
    <main>
      <PlannerHeader
        filters={filters}
        customers={customers}
        onChange={setFilters}
        onReset={reset}
      />
      <PlannerSummaryCards sources={sources} lines={lines} />
      <div className="workspace">
        <DemandSourcePanel
          sources={sources}
          selected={selectedSource}
          onSelect={setSelectedSource}
        />
        <RequirementTable
          lines={lines}
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
            <b>{lines.filter((x) => x.readiness === "BLOCKED").length}</b> dòng
            đang chặn (fixture)
          </span>
          <span>
            <b>{lines.filter((x) => x.readiness === "NEEDS_REVIEW").length}</b>{" "}
            dòng cần duyệt (fixture)
          </span>
          <span>
            <b>{Object.values(localStates).filter((x) => x.flagged).length}</b>{" "}
            cờ cục bộ
          </span>
          <span>
            <b>
              {
                Object.values(localStates).filter(
                  (x) => x.substitutionDraft || x.overrideDraft,
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
            onClose={() => setSelectedId(undefined)}
          />
        </>
      )}
    </main>
  );
}
