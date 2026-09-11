import { useCallback, useMemo, useState } from "react";
import {
  initialConfirmedNeedDraft,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedWorkbenchData,
} from "../bridges/confirmedNeed";
import { foldVietnameseSearch } from "../foldVietnameseSearch";
import { draftChanged, draftError } from "./confirmedNeedDraft";
// Local presentation and drafts issue no reads and never replace authority.
export function useConfirmedNeedDraft(
  workbench: ConfirmedNeedWorkbenchData | null,
  schoolIds: string[],
) {
  const [drafts, setDrafts] = useState<Record<string, ConfirmedNeedDraftLine>>(
    {},
  );
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [differencesOnly, setDifferencesOnly] = useState(false);
  const resetDrafts = useCallback(
    (b: ConfirmedNeedWorkbenchData) =>
      setDrafts(
        Object.fromEntries(
          b.lines.map((l) => [
            l.confirmed_need_line_id,
            initialConfirmedNeedDraft(l),
          ]),
        ),
      ),
    [],
  );
  const changedLines = useMemo(
    () =>
      workbench?.lines.filter(
        (l) =>
          drafts[l.confirmed_need_line_id] &&
          draftChanged(l, drafts[l.confirmed_need_line_id]!),
      ) ?? [],
    [workbench, drafts],
  );
  const dirty = changedLines.length > 0;
  const errors = Object.fromEntries(
    changedLines.flatMap((l) => {
      const error = draftError(l, drafts[l.confirmed_need_line_id]!);
      return error ? [[l.confirmed_need_line_id, error]] : [];
    }),
  );
  const schools = Array.from(
    new Map(
      workbench?.lines.map((l) => [
        l.school.id,
        { school_id: l.school.id, school_name: l.school.name },
      ]) ?? [],
    ).values(),
  );
  const changedIds = new Set(changedLines.map((l) => l.confirmed_need_line_id));
  const query = foldVietnameseSearch(search.trim());
  const visibleLines =
    workbench?.lines.filter(
      (l) =>
        (!schoolIds.length || schoolIds.includes(l.school.id)) &&
        (!query ||
          foldVietnameseSearch(
            `${l.ingredient.name} ${l.school.name} ${l.delivery_location.name}`,
          ).includes(query)) &&
        (filter !== "needs_review" ||
          ["CHANGED", "NEW", "UNREVIEWED"].includes(l.confirmation_state)) &&
        (filter !== "carried_forward" ||
          l.confirmation_state === "CARRIED_FORWARD") &&
        (!differencesOnly || changedIds.has(l.confirmed_need_line_id)),
    ) ?? [];
  visibleLines.sort((a, b) => {
    const needsReview = (state: string) =>
      ["CHANGED", "NEW", "UNREVIEWED"].includes(state);
    return (
      Number(needsReview(b.confirmation_state)) -
      Number(needsReview(a.confirmation_state))
    );
  });
  const visibleIds = new Set(visibleLines.map((l) => l.confirmed_need_line_id));
  const hiddenDirtyCount = changedLines.filter(
    (l) => !visibleIds.has(l.confirmed_need_line_id),
  ).length;
  return {
    drafts,
    setDrafts,
    resetDrafts,
    search,
    setSearch,
    filter,
    setFilter,
    differencesOnly,
    setDifferencesOnly,
    changedLines,
    dirty,
    errors,
    schools,
    visibleLines,
    hiddenDirtyCount,
  };
}
