"""Measure retained-owner switching with local fixtures and 4x CPU throttling."""
import argparse
import json
import statistics
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from atlas_persistent_workspace_browser_test import launch, select

OWNERS = ["Trường học", "Thực đơn", "Sĩ số", "Hàng đặt riêng", "Xác nhận nhu cầu", "Phân bổ NCC", "Đơn mua",
          "Công thức", "Lệnh điều chỉnh", "Nguyên liệu", "Nhà cung ứng", "Phiếu xuất kho",
          "Đối chiếu PO / Phiếu xuất kho"]
LEGACY_SUBSET = ["Trường học", "Phân bổ NCC", "Công thức", "Phiếu xuất kho"]
LEGACY_OWNERS = ["Trường học", "Xác nhận nhu cầu", "Phân bổ NCC", "Công thức",
                 "Phiếu xuất kho", "Nguyên liệu", "Đối chiếu PO / Phiếu xuất kho"]


def distribution(samples):
    values = sorted(s["paint_ms"] for s in samples)
    return {"sample_count": len(values), "median_ms": round(statistics.median(values), 2),
            "p95_ms": values[int(len(values) * .95) - 1]}


def run(browser, width, legacy_comparison=False):
    print(f"starting {width}", flush=True)
    page = browser.new_page(viewport={"width": width, "height": 900}, reduced_motion="reduce")
    page.goto("http://127.0.0.1:3000/atlas-vnext-review.html")
    page.wait_for_load_state("networkidle")
    owners = LEGACY_OWNERS if legacy_comparison else OWNERS
    targets = LEGACY_SUBSET if legacy_comparison else OWNERS
    for label in owners[1:]:
        launch(page, label)
        if label in ["Phân bổ NCC", "Công thức", "Phiếu xuất kho"]:
            select(page, {"Phân bổ NCC": "procurement", "Công thức": "recipes", "Phiếu xuất kho": "pxk"}[label])
    page.wait_for_timeout(500)
    print(f"{len(owners)} owners ready at {width}", flush=True)
    session = page.context.new_cdp_session(page)
    session.send("Emulation.setCPUThrottlingRate", {"rate": 4})
    samples = []
    for cycle in range(6):
        for label in targets:
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
            assert page.locator('main>[role="tabpanel"]').count() == len(owners)
            assert not page.evaluate("!!document.activeElement?.closest('[hidden],[inert]')")
            if cycle:
                samples.append({"owner": label, "paint_ms": round(duration, 2)})
    subset = [sample for sample in samples if sample["owner"] in LEGACY_SUBSET]
    assert len(samples) == len(targets) * 5 and len(subset) == 20
    page.close()
    return {"width": width, "owners": len(owners), "samples": samples, **distribution(samples),
            "legacy_four_owner_subset": {"labels": LEGACY_SUBSET, **distribution(subset)}}


if __name__ == "__main__":
    args = argparse.ArgumentParser()
    args.add_argument("--phase", choices=["product-corrections"], required=True)
    phase = args.parse_args().phase
    with sync_playwright() as p:
        browser = p.chromium.launch()
        results = {"phase": phase, "browser": browser.version, "cpu_throttle": 4,
                   "environment": "local Vite development / fixtures; browser click to two animation frames",
                   "results": [run(browser, width) for width in [1440, 650]]}
        browser.close()
    path = Path("docs/testing/artifacts/atlas-product-corrections-01/performance.json")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"phase": phase, "results": [{k: v for k, v in r.items() if k != "samples"} for r in results["results"]]}))
