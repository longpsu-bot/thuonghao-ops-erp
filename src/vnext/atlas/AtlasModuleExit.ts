import type { Ref } from "react";

export interface AtlasModuleExitHandle {
  requestExit(next: () => void): void;
}

export type AtlasModuleExitProps = { exitRef?: Ref<AtlasModuleExitHandle> };
