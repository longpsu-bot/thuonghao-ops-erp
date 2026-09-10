import { Box, ChakraProvider } from "@chakra-ui/react";
import type { ReactNode } from "react";
import { atlasSystem } from "./system";

export function AtlasVNextProvider({ children }: { children: ReactNode }) {
  return (
    <ChakraProvider value={atlasSystem}>
      <Box className="atlas-vnext" minW="var(--atlas-layout-zero, 0)">
        {children}
      </Box>
    </ChakraProvider>
  );
}
