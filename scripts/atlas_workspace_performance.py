"""Measure retained-owner switching with local fixtures and 4x CPU throttling."""
import argparse
import json
import statistics
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from atlas_persistent_workspace_browser_test import launch, select


def run(browser, width):
    print(f"starting {width}", flush=True)
    page = browser.new_page(viewport={"width": width, "height": 900}, reduced_motion="reduce")
    page.goto("http://127.0.0.1:3000/atlas-vnext-review.html")
    page.wait_for_load_state("networkidle")
    for label, kind in [("Lập nhu cầu", "need"), ("Kế hoạch mua hàng", "procurement"),
                        ("Công thức", "recipes"), ("Phiếu xuất kho", "pxk")]:
        launch(page, label)
        select(page, kind)
    for label in ["Nguyên liệu và Nhà cung ứng", "Đối chiếu PO / Phiếu xuất kho"]:
        launch(page, label)
    page.wait_for_timeout(500)
    print(f"seven owners ready at {width}", flush=True)
    session = page.context.new_cdp_session(page)
    session.send("Emulation.setCPUThrottlingRate", {"rate": 4})
    samples = []
    for cycle in range(6):
        for label in ["Trường học", "Kế hoạch mua hàng", "Công thức", "Phiếu xuất kho"]:
            if width < 1024:
                page.get_by_role("button", name="Đang mở:", exact=False).click()
                target = page.get_by_role("dialog", name="Bàn làm việc đang mở", exact=True).get_by_role("button", name=label, exact=True)
            else:
                target = page.get_by_role("tablist", name="Bàn làm việc đang mở").get_by_role("tab", name=label, exact=True)
            target.scroll_into_view_if_needed()
            duration = target.evaluate("""async button => {
              const start = performance.now();
              button.click();
              await Promise.race([
                new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))),
                new Promise((_, reject) => setTimeout(() => reject(new Error('paint did not settle within 10s')), 10000))
              ]);
              return performance.now() - start;
            }""")
            print(f"{width} {cycle} {label}: {duration:.1f}ms", flush=True)
            panel = page.locator('main>[role="tabpanel"]:not([hidden])')
            expect(panel).to_have_attribute("aria-label", label)
            assert page.locator('main>[role="tabpanel"]').count() == 7
            assert not page.evaluate("!!document.activeElement?.closest('[hidden],[inert]')")
            if cycle:
                samples.append({"owner": label, "paint_ms": round(duration, 2)})
    values = sorted(s["paint_ms"] for s in samples)
    page.close()
    return {"width": width, "owners": 7, "samples": samples,
            "median_ms": round(statistics.median(values), 2), "p95_ms": values[int(len(values) * .95) - 1]}


if __name__ == "__main__":
    args = argparse.ArgumentParser()
    args.add_argument("--phase", choices=["before", "after"], required=True)
    phase = args.parse_args().phase
    with sync_playwright() as p:
        browser = p.chromium.launch()
        results = {"phase": phase, "browser": browser.version, "cpu_throttle": 4,
                   "environment": "local Vite development / fixtures; browser click to two animation frames",
                   "results": [run(browser, width) for width in [1440, 650]]}
        browser.close()
    path = Path("docs/testing/artifacts/atlas-persistent-workspace-03c") / f"performance-{phase}.json"
    path.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"phase": phase, "results": [{k: v for k, v in r.items() if k != "samples"} for r in results["results"]]}))
