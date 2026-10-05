import type { AtlasWorkbenchId } from "./AtlasWorkbenchRegistry";

export type AtlasWorkspaceState = {
  openIds: AtlasWorkbenchId[];
  activeId: AtlasWorkbenchId | null;
};
export type AtlasWorkspaceAction =
  | { type: "OPEN" | "ACTIVATE"; id: AtlasWorkbenchId }
  | { type: "CLOSE_APPROVED"; id: AtlasWorkbenchId };

export function atlasWorkspaceReducer(
  state: AtlasWorkspaceState,
  action: AtlasWorkspaceAction,
): AtlasWorkspaceState {
  if (action.type === "OPEN")
    return {
      openIds: state.openIds.includes(action.id)
        ? state.openIds
        : [...state.openIds, action.id],
      activeId: action.id,
    };
  if (action.type === "ACTIVATE")
    return state.openIds.includes(action.id)
      ? { ...state, activeId: action.id }
      : state;
  const index = state.openIds.indexOf(action.id);
  const openIds = state.openIds.filter((id) => id !== action.id);
  return {
    openIds,
    activeId:
      state.activeId === action.id
        ? (openIds[index] ?? openIds[index - 1] ?? null)
        : state.activeId,
  };
}
