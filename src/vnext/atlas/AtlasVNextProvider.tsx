import { Box, ChakraProvider } from "@chakra-ui/react";
import type { Icon } from "@phosphor-icons/react";
import {
  createContext,
  useContext,
  useRef,
  type ReactNode,
  type RefObject,
} from "react";
import { atlasSystem } from "./system";
import "./typography.css";

const AtlasPortalContainerContext =
  createContext<RefObject<HTMLDivElement | null> | null>(null);
const AtlasWorkbenchActiveContext = createContext(true);
const AtlasWorkbenchIconContext = createContext<Icon | undefined>(undefined);

export function useAtlasWorkbenchActive() {
  return useContext(AtlasWorkbenchActiveContext);
}

export function useAtlasWorkbenchIcon() {
  return useContext(AtlasWorkbenchIconContext);
}

/** One shared Chakra system; each retained owner contains its own portals. */
export function AtlasWorkbenchScope({
  active,
  icon,
  children,
}: {
  active: boolean;
  icon?: Icon;
  children: ReactNode;
}) {
  const portalRef = useRef<HTMLDivElement>(null);
  return (
    <AtlasWorkbenchActiveContext.Provider value={active}>
      <AtlasPortalContainerContext.Provider value={portalRef}>
        <AtlasWorkbenchIconContext.Provider value={icon}>
          {children}
        </AtlasWorkbenchIconContext.Provider>
        <Box ref={portalRef} data-atlas-portal-root="" />
      </AtlasPortalContainerContext.Provider>
    </AtlasWorkbenchActiveContext.Provider>
  );
}

export function useAtlasPortalContainer() {
  const ref = useContext(AtlasPortalContainerContext);
  if (!ref)
    throw new Error("Atlas portal container requires AtlasVNextProvider");
  return ref;
}

export function AtlasVNextProvider({ children }: { children: ReactNode }) {
  const portalRef = useRef<HTMLDivElement>(null);
  return (
    <ChakraProvider value={atlasSystem}>
      <Box
        className="atlas-vnext"
        minW="var(--atlas-layout-zero, 0)"
        onFocusCapture={({ target }) => {
          if (
            ((target instanceof HTMLInputElement && target.type === "text") ||
              target instanceof HTMLTextAreaElement) &&
            !target.readOnly &&
            target.getAttribute("role") !== "combobox" &&
            (target.closest("td, [role=gridcell], [data-atlas-editable-row]") ||
              target.inputMode === "decimal" ||
              target.inputMode === "numeric")
          )
            target.select();
        }}
      >
        <AtlasPortalContainerContext.Provider value={portalRef}>
          {children}
          <Box ref={portalRef} data-atlas-portal-root="" />
        </AtlasPortalContainerContext.Provider>
      </Box>
    </ChakraProvider>
  );
}
