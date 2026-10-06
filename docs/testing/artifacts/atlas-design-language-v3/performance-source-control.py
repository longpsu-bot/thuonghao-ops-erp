"""Bounded same-host check against exact pre-v3 PR source, with both watchers off."""
import json
import sys
from pathlib import Path
sys.path.insert(0, "scripts")
from playwright.sync_api import sync_playwright
from atlas_workspace_performance import run

baseline = Path(sys.argv[1])
source = (baseline / "scripts/atlas_workspace_performance.py").read_text(encoding="utf8")
url = "http://127.0.0.1:3000/atlas-vnext-review.html"
assert source.count(url) == 1
namespace = {"__name__": "pre_v3_benchmark"}
exec(compile(source.replace(url, url.replace("3000", "3001")), "<pre-v3-benchmark>", "exec"), namespace)
results = []
with sync_playwright() as p:
    browser = p.chromium.launch()
    for width in [1440]:
        after = run(browser, width)
        before = namespace["run"](browser, width)
        results.append({"width": width, "before": before, "after": after})
    report = {"baseline_sha": "ea0d00a3cbf413588462873b8e03370e476f08d6",
              "browser": browser.version, "cpu_throttle": 4,
              "method": "Final frozen-source bounded desktop check: current FIRST at3000, exact pre-v3 PR SECOND at3001; separate caches, both Vite watchers explicitly closed; 11 owners, 55 samples each, first cycle excluded, 4xCPU; no scan/test/build/install jobs active.",
              "results": results}
    browser.close()
Path("docs/testing/artifacts/atlas-design-language-v3/performance-final-control.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
print(json.dumps([{ "width": r["width"], "before": r["before"]["median_ms"],
                   "after": r["after"]["median_ms"], "before_p95": r["before"]["p95_ms"],
                   "after_p95": r["after"]["p95_ms"]} for r in results]))
