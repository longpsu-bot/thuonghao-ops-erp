"""Checkpoint E: 36 equal-state token comparisons; localhost fixtures only.

Start Vite; run python -B -X utf8 scripts/atlas_legibility_variants_capture.py.
"""
import json
import re
from pathlib import Path
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright, expect
from atlas_persistent_workspace_browser_test import launch, select, dirty, capture
from atlas_product_corrections_browser_test import reveal_menu_cell

ROOT = Path("docs/testing/artifacts/atlas-v3-legibility-variants")
SIZES = [(1440, 900), (1366, 768), (360, 800)]
SCREENS = {"menu": "Thực đơn", "need": "Xác nhận nhu cầu", "recipe": "Công thức", "allocation": "Phân bổ NCC"}


def measure(page):
    return page.evaluate("""() => {
      const panel=document.querySelector('main>[role=tabpanel]:not([hidden])');
      const visible=e=>e.getClientRects().length>0;
      const style=e=>{const s=getComputedStyle(e);return {
        text:e.textContent?.trim().slice(0,80),font:s.fontSize,weight:s.fontWeight,
        foreground:s.color,background:s.backgroundColor,border:s.borderColor,
        edge:s.borderWidth,underline:s.textDecorationLine,outline:s.outlineStyle
      }};
      return {
        table:[...panel.querySelectorAll('th,td,p,span,button,input')].filter(e=>visible(e)&&e.closest('table')).map(style),
        labels:[...panel.querySelectorAll('label')].filter(visible).map(style),
        controls:[...panel.querySelectorAll('input,select,textarea')].filter(visible).map(style),
        selected:[...document.querySelectorAll('[role=tab][aria-selected=true],tr[aria-selected=true]')].filter(visible).map(style),
        selectedMarkers:[...panel.querySelectorAll('tr[aria-selected=true] td:first-of-type')].filter(visible).map(e=>getComputedStyle(e).boxShadow),
        alerts:[...panel.querySelectorAll('[role=alert]')].filter(visible).map(e=>({...style(e),icon:getComputedStyle(e,'::before').maskImage})),
        surfaces:['.atlas-vnext','main','header'].map(q=>({selector:q,...style(document.querySelector(q))})),
        fingerprint:{text:panel.innerText.replace(/\\s+/g,' ').trim(),values:[...panel.querySelectorAll('input,select,textarea')].filter(visible).map(e=>[e.getAttribute('aria-label')||e.id,e.value])}
      };
    }""")


def compact_table(detail):
    table = detail["table"]
    styles = {tuple((k, v) for k, v in e.items() if k != "text") for e in table}
    detail["table"] = {"elementsMeasured": len(table),
                       "minimumFontPx": min(float(e["font"].removesuffix("px")) for e in table),
                       "styles": [dict(style) for style in sorted(styles)]}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    results, fingerprints = [], {}
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        for variant in "ABC":
            for width, height in SIZES:
                page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
                failures = []
                page.on("pageerror", lambda error: failures.append(str(error)))
                page.on("request", lambda request: failures.append(request.url)
                        if urlparse(request.url).hostname not in ["127.0.0.1", "localhost", None] else None)
                page.goto(f"http://127.0.0.1:3000/atlas-vnext-review.html?legibility={variant}&scenario=invalidMenuCell&capture=1")
                page.wait_for_load_state("networkidle")
                page.evaluate("document.fonts.ready")
                for label in SCREENS.values():
                    launch(page, label)
                for screen, label in SCREENS.items():
                    print(f"{variant} {screen} {width}x{height}", flush=True)
                    launch(page, label)
                    if screen == "menu":
                        page.get_by_role("button", name="Đồng bộ Google Sheet", exact=True).click()
                        expect(page.get_by_text("1 ô cần xử lý trước khi lưu.", exact=True)).to_be_visible()
                        expect(page.get_by_role("table", name="Thực đơn theo trường")).to_contain_text("Canh rau ngót")
                    elif screen == "need":
                        dirty(page, "need")
                    elif screen == "recipe":
                        select(page, "recipes")
                        quantity = page.get_by_role("textbox", name="Định lượng Bí đỏ", exact=True)
                        quantity.fill("2,25")
                        expect(quantity.locator("xpath=ancestor::tr")).to_contain_text("Kilôgam")
                    else:
                        select(page, "procurement")
                        page.get_by_role("textbox", name=re.compile("^Ghi chú cho ")).first.fill("Giao sớm")
                    page.locator("h1:visible").click()
                    page.evaluate("document.fonts.ready")
                    name = f"{variant}-{screen}-{width}x{height}"
                    capture(page, ROOT, name, results, full_page=False)
                    detail = measure(page)
                    assert len(results[-1]["heading"]) == 1, name
                    assert detail["table"] and all(float(e["font"].replace("px", "")) >= 14 for e in detail["table"]), (name, detail["table"])
                    assert all(e["font"] == "14px" and int(e["weight"]) >= 600 for e in detail["labels"]), (name, detail["labels"])
                    assert all(marker != "none" for marker in detail["selectedMarkers"]), (name, detail["selectedMarkers"])
                    key = (screen, width, height)
                    if key in fingerprints:
                        assert detail["fingerprint"] == fingerprints[key], f"Unequal state: {name}"
                    fingerprints[key] = detail.pop("fingerprint")
                    compact_table(detail)
                    results[-1].update(detail)
                    results[-1]["primary"] = True
                    if width == 360 and screen in ["menu", "recipe", "allocation"]:
                        if screen == "menu":
                            reveal_menu_cell(page)
                        elif screen == "recipe":
                            unit = quantity.locator("xpath=ancestor::tr").get_by_text("Kilôgam", exact=True)
                            unit.scroll_into_view_if_needed()
                            expect(quantity).to_be_in_viewport(ratio=1)
                            expect(unit).to_be_in_viewport(ratio=1)
                        else:
                            page.get_by_role("button", name="Lưu phân bổ", exact=True).scroll_into_view_if_needed()
                        capture(page, ROOT, f"{variant}-{screen}-detail-{width}x{height}", results, full_page=False)
                        results[-1]["primary"] = False
                assert not failures, failures
                page.close()
        browser.close()
    assert sum(r["primary"] for r in results) == 36 and len(results) == 45
    (ROOT / "measurements.json").write_text(json.dumps({"baseline": "ea0d00a3cbf413588462873b8e03370e476f08d6", "equalState": True, "captures": results}, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PASS: 36 primary + 9 detail screenshots; equal state; table >=14px, labels 14px/600; no document overflow, hidden focus or hosted calls.")


if __name__ == "__main__":
    main()
