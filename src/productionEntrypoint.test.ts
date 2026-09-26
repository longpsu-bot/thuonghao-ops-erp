import { describe, expect, it } from "vitest";
import entrypoint from "./main.tsx?raw";
import indexHtml from "../index.html?raw";

describe("Atlas production entrypoint cutover", () => {
  it("mounts the connected vNext root without legacy presentation imports", () => {
    expect(entrypoint).toContain(
      'import { AtlasVNextConnectedApp } from "./AtlasVNextConnectedApp";',
    );
    expect(entrypoint).toContain("<AtlasVNextConnectedApp />");
    expect(entrypoint).not.toMatch(
      /@mantine|MantineProvider|DatesProvider|AtlasApp|\.\/theme|\.\/styles\.css|dayjs|PlanningInputsWorkbench|AtlasDatePickerInputContext/,
    );
  });

  it("keeps the normal HTML mount and school operations title", () => {
    expect(indexHtml).toContain("<title>Atlas · Vận hành trường học</title>");
    expect(indexHtml).toContain('<div id="root"></div>');
    expect(indexHtml).toContain(
      '<script type="module" src="/src/main.tsx"></script>',
    );
  });

  it("resets the document margin without relying on legacy global CSS", () => {
    expect(indexHtml).toMatch(/html,\s*body\s*\{\s*margin:\s*0;/);
  });
});
