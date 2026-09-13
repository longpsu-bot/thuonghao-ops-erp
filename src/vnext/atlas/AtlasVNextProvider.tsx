import { Box, ChakraProvider } from "@chakra-ui/react";
import {
  createContext,
  useContext,
  useRef,
  type ReactNode,
  type RefObject,
} from "react";
import { atlasSystem } from "./system";

const AtlasPortalContainerContext =
  createContext<RefObject<HTMLDivElement | null> | null>(null);

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
      <Box className="atlas-vnext" minW="var(--atlas-layout-zero, 0)">
        <AtlasPortalContainerContext.Provider value={portalRef}>
          {children}
          <Box ref={portalRef} data-atlas-portal-root="" />
        </AtlasPortalContainerContext.Provider>
      </Box>
    </ChakraProvider>
  );
}
