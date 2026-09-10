import { describe, expect, it } from "vitest";
import { checkSources } from "./check-atlas-vnext-ui-boundary.mjs";

describe("Atlas vNext presentation boundary", () => {
  it("permits Chakra-only vNext and existing business API/model imports", () => {
    expect(
      checkSources({
        "src/vnext/atlas/View.tsx":
          'import { Box } from "@chakra-ui/react"; import type { Model } from "../../modules/atlas/procurement/model"; export { api } from "../../modules/atlas/api";',
      }),
    ).toEqual([]);
  });
  it.each([
    "@mantine/core",
    "@mantine/dates",
    "@mantine/hooks",
    "@mantine/core/styles.css",
  ])("rejects %s under vNext", (name) => {
    expect(
      checkSources({ "src/vnext/atlas/View.tsx": `import "${name}";` }),
    ).toHaveLength(1);
  });
  it.each([
    "../../theme",
    "../../theme.ts",
    "../../styles.css",
    "@/theme",
    "@/styles.css",
    "/src/theme.ts",
    "src/styles.css?inline",
  ])("rejects legacy presentation import %s", (name) => {
    expect(
      checkSources({
        "src/vnext/atlas/View.tsx": `import theme from "${name}";`,
      }),
    ).toHaveLength(1);
  });
  it.each([
    'import { Button } from "@chakra-ui/react"',
    'export { Button } from "@chakra-ui/react"',
    'const ui = import("@chakra-ui/react")',
    'const ui = require("@chakra-ui/react")',
  ])("rejects Chakra in legacy source: %s", (source) => {
    expect(
      checkSources({ "src/modules/atlas/Legacy.tsx": source }),
    ).toHaveLength(1);
  });
  it("ignores comments and permits legacy Mantine", () => {
    expect(
      checkSources({
        "src/modules/atlas/Legacy.tsx":
          '/* import "@chakra-ui/react" */\nimport "@mantine/core";',
        "src/vnext/atlas/View.tsx":
          '// import "@mantine/hooks"\nimport "@chakra-ui/react";',
      }),
    ).toEqual([]);
  });
  it("reports deterministically by path", () => {
    const sources = {
      "src/z.ts": 'import "@chakra-ui/react"',
      "src/a.ts": 'import "@chakra-ui/react"',
    };
    expect(checkSources(sources)[0]).toContain("src/a.ts");
  });
});
