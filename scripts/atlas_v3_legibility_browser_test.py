"""Final v3 pixels and existing #354 gates; local fixture entry, no hosted calls.

Start Vite on port 3000, then run with --part visual, regressions or performance.
Historical product/prototype artifacts are never overwritten.
"""
import argparse
import json
import math
import time
from io import BytesIO
from PIL import Image
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
import atlas_product_corrections_browser_test as gates
from atlas_persistent_workspace_browser_test import SIZES, launch, select, capture
from atlas_workspace_performance import OWNERS, run as benchmark

ROOT = Path("docs/testing/artifacts/atlas-design-language-v3")
URL = "http://127.0.0.1:3000/atlas-vnext-review.html"
SCREENS = [("menu", "Thực đơn"), ("need", "Xác nhận nhu cầu"),
           ("recipe", "Công thức"), ("allocation", "Phân bổ NCC")]
PAIRS = [("fg.primary", "bg.workbench", 7), ("fg.secondary", "bg.workbench", 7),
         ("fg.muted", "bg.workbench", 4.5), ("fg.placeholder", "bg.workbench", 4.5),
         ("border.default", "bg.workbench", 3), ("border.strong", "bg.workbench", 3),
         ("border.strong", "bg.toolbar", 3), ("fg.inverse", "action.primary.default", 7),
         ("fg.inverse", "action.primary.hover", 7), ("fg.inverse", "action.primary.pressed", 7),
         ("fg.primary", "bg.selected", 7), ("border.accent", "bg.selected", 3),
         ("focus.ring", "bg.workbench", 3), ("focus.ring", "bg.toolbar", 3),
         ("focus.ring", "bg.selected", 3), ("focus.inverse", "bg.navigation", 3),
         ("fg.disabled", "bg.disabled", 4.5), ("fg.attention", "bg.toolbar", 4.5),
         ("fg.inverse", "bg.navigation", 7)] + [(f"status.{s}", f"bg.{s}", 4.5)
         for s in ["success", "warning", "danger", "info"]] + [(f"border.{s}", f"bg.{s}", 3)
         for s in ["success", "warning", "danger", "info"]]


def linear(hex_color):
    rgb = [int(hex_color.strip().lstrip("#")[i:i+2], 16) / 255 for i in [0, 2, 4]]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]


def luminance(hex_color):
    return sum(c*w for c, w in zip(linear(hex_color), [.2126, .7152, .0722]))


def oklch(hex_color):
    r, g, b = linear(hex_color)
    l = (.4122214708*r + .5363325363*g + .0514459929*b) ** (1/3)
    m = (.2119034982*r + .6806995451*g + .1073969566*b) ** (1/3)
    s = (.0883024619*r + .2817188376*g + .6299787005*b) ** (1/3)
    light = .2104542553*l + .793617785*m - .0040720468*s
    a = 1.9779984951*l - 2.428592205*m + .4505937099*s
    b = .0259040371*l + .7827717662*m - .808675766*s
    return {"L": round(light, 4), "C": round(math.hypot(a, b), 4),
            "h": round(math.degrees(math.atan2(b, a)) % 360, 1)}


def token_report(page):
    names = sorted({name for a, b, _ in PAIRS for name in [a, b]})
    scales = {"neutral": [25, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950],
              "brand": [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950],
              "clay": [200, 500, 700],
              **{s: [50, 200, 500, 600, 700] for s in ["success", "warning", "danger", "info"]}}
    names += [f"{family}.{step}" for family, steps in scales.items() for step in steps]
    values = page.locator(".atlas-vnext").evaluate("""(root,names)=>{
      const css=getComputedStyle(root);
      return Object.fromEntries(names.map(n=>[n,css.getPropertyValue('--atlas-colors-'+n.replaceAll('.','-')).trim()]));
    }""", names)
    matrix = []
    for a, b, floor in PAIRS:
        high, low = sorted([luminance(values[a]), luminance(values[b])], reverse=True)
        ratio = (high + .05) / (low + .05)
        matrix.append({"foreground": a, "background": b, "colors": [values[a], values[b]],
                       "ratio": round(ratio, 2), "floor": floor, "pass": ratio >= floor})
        assert ratio >= floor, matrix[-1]
    ramps = {}
    for family, steps in scales.items():
        ramp = [{"step": step, "hex": values[f"{family}.{step}"],
                 **oklch(values[f"{family}.{step}"])} for step in steps]
        assert all(a["L"] > b["L"] for a, b in zip(ramp, ramp[1:])), family
        if family == "neutral":
            assert all(c["C"] <= .0001 for c in ramp)
        ramps[family] = ramp
    return {"source": "final application computed CSS custom properties", "contrast": matrix, "scales": ramps}


def snap(page, name, results):
    capture(page, ROOT, name, results, full_page=False)
    panel = gates.active(page)
    metrics = panel.evaluate("""root=>{
      const visible=e=>e.getClientRects().length && getComputedStyle(e).visibility!=='hidden';
      const style=e=>{const c=getComputedStyle(e);return {text:e.textContent.slice(0,70),size:c.fontSize,color:c.color,bg:c.backgroundColor,border:c.borderColor,opacity:c.opacity,outline:c.outlineColor,outlineWidth:c.outlineWidth,height:e.getBoundingClientRect().height}};
      return {cells:[...root.querySelectorAll('th,td')].filter(visible).map(style),
        controls:[...root.querySelectorAll('input,select,textarea,button')].filter(visible).map(e=>({...style(e),tag:e.tagName,disabled:e.disabled,label:e.getAttribute('aria-label')})),
        selected:[...root.querySelectorAll('tr[aria-selected=true]')].map(e=>({...style(e),cue:!!e.querySelector('[data-selection-indicator]'),edge:e.querySelector('[data-selection-indicator]')&&getComputedStyle(e.querySelector('[data-selection-indicator]')).width})),
        selectedDish:[...root.querySelectorAll('button[data-dish-select][aria-pressed=true]')].map(e=>({...style(e),edge:getComputedStyle(e.firstElementChild).borderLeftWidth}))};
    }""")
    assert all(float(c["size"].replace("px", "")) >= 14 for c in metrics["cells"]), name
    assert all(c["cue"] for c in metrics["selected"]), name
    assert all(float(c["edge"].replace("px", "")) >= 3 for c in metrics["selected"] + metrics["selectedDish"]), name
    results[-1]["rendered"] = metrics
    return metrics


def assert_focus(control):
    expect(control).to_have_css("outline-color", "rgb(15, 100, 78)")
    expect(control).to_have_css("outline-width", "2px")
    expect(control).to_have_css("outline-offset", "2px")


def visual(browser):
    results = []
    colors = None
    for width, height in SIZES:
        print(f"visual {width}x{height}", flush=True)
        page, failures = gates.new_page(browser, URL, width, height)
        for key, label in SCREENS:
            gates.opened(page, label)
            if key in ["recipe", "allocation"]:
                select(page, "recipes" if key == "recipe" else "procurement")
            if key == "recipe":
                expect(page.get_by_role("button", name="Xem thay đổi", exact=True)).to_be_in_viewport()
            if key == "allocation":
                expect(page.get_by_role("button", name="Lưu phân bổ", exact=True)).to_be_in_viewport()
            snap(page, f"{key}-{width}x{height}", results)
            if key == "allocation":
                rail = page.locator('tr[aria-selected=true] [data-selection-indicator]').bounding_box()
                pixels = Image.open(BytesIO(page.screenshot())).convert("RGB")
                point = (int(rail["x"] + rail["width"] / 2), int(rail["y"] + rail["height"] / 2))
                assert pixels.getpixel(point) == (15, 100, 78), (width, point, pixels.getpixel(point))
                results[-1]["selected_rail_pixel"] = list(pixels.getpixel(point))
            if key == "allocation" and width in [650, 360]:
                page.get_by_role("button", name="Lưu phân bổ", exact=True).scroll_into_view_if_needed()
                snap(page, f"allocation-editor-action-{width}x{height}", results)
            if width == 1440:
                colors = token_report(page)
        gates.close(page, failures)

    for width, height in [(1440, 900), (360, 800)]:
        for scenario in ["invalidMenuCell", "missingRecipeUnit"]:
            page, failures = gates.new_page(browser, URL, width, height, scenario)
            if scenario == "invalidMenuCell":
                gates.opened(page, "Thực đơn")
                page.get_by_role("button", name="Đồng bộ Google Sheet", exact=True).click()
                expect(page.get_by_text("1 ô cần xử lý trước khi lưu.", exact=True)).to_be_visible()
                page.get_by_text("Xem ô cần kiểm tra", exact=True).click()
                gates.reveal_menu_cell(page)
            else:
                gates.opened(page, "Công thức")
                select(page, "recipes")
                page.get_by_label("Tìm nguyên liệu để thêm", exact=True).fill("Cà rốt")
                page.get_by_role("button", name="Thêm Cà rốt", exact=True).click()
                expect(page.get_by_role("button", name="Xem thay đổi", exact=True)).to_be_disabled()
                page.get_by_text("Nguyên liệu chưa có đơn vị mua đang dùng", exact=False).scroll_into_view_if_needed()
            snap(page, f"{scenario}-{width}x{height}", results)
            if scenario == "missingRecipeUnit":
                disabled = page.get_by_role("button", name="Xem thay đổi", exact=True)
                disabled.scroll_into_view_if_needed()
                expect(disabled).to_have_css("background-color", "rgb(241, 241, 241)")
                expect(disabled).to_have_css("color", "rgb(85, 85, 85)")
                before = disabled.evaluate("e=>{const c=getComputedStyle(e);return [c.backgroundColor,c.color,c.opacity]}")
                assert before == ["rgb(241, 241, 241)", "rgb(85, 85, 85)", "1"], before
                disabled.hover()
                assert disabled.evaluate("e=>{const c=getComputedStyle(e);return [c.backgroundColor,c.color,c.opacity]}") == before
                snap(page, f"recipe-disabled-action-{width}x{height}", results)
            if width == 1440:
                session = page.context.new_cdp_session(page)
                for vision in ["achromatopsia", "protanopia", "deuteranopia"]:
                    session.send("Emulation.setEmulatedVisionDeficiency", {"type": vision})
                    snap(page, f"{scenario}-{vision}", results)
                session.send("Emulation.setEmulatedVisionDeficiency", {"type": "none"})
            gates.close(page, failures)

        page, failures = gates.new_page(browser, URL, width, height)
        gates.opened(page, "Xác nhận nhu cầu")
        page.get_by_label("Số lượng xác nhận Gạo thơm", exact=True).fill("12,5")
        snap(page, f"need-unsaved-{width}x{height}", results)
        gates.opened(page, "Công thức")
        select(page, "recipes")
        field = page.get_by_label("Định lượng Bí đỏ", exact=True)
        field.focus()
        expect(field).to_be_focused()
        assert_focus(field)
        field.scroll_into_view_if_needed()
        unit = field.locator("xpath=ancestor::td/following-sibling::td[1]")
        unit.scroll_into_view_if_needed()
        expect(field).to_be_in_viewport()
        expect(unit).to_be_in_viewport()
        snap(page, f"recipe-edit-focus-unit-{width}x{height}", results)
        if width == 1440:
            session = page.context.new_cdp_session(page)
            for vision in ["achromatopsia", "protanopia", "deuteranopia"]:
                session.send("Emulation.setEmulatedVisionDeficiency", {"type": vision})
                snap(page, f"recipe-selected-{vision}", results)
            session.send("Emulation.setEmulatedVisionDeficiency", {"type": "none"})
        gates.close(page, failures)

    page, failures = gates.new_page(browser, URL, 1440, 900)
    for index, label in enumerate(OWNERS):
        if index:
            gates.opened(page, label)
        snap(page, f"smoke-{index:02}", results)
    assert page.locator('main>[role="tabpanel"]').count() == len(OWNERS)
    snap(page, "workspace-thirteen-open-tabs", results)
    page.get_by_role("button", name="Bàn làm việc", exact=True).click()
    expect(page.get_by_role("dialog", name="Bàn làm việc").locator("button[data-destination]")).to_have_count(len(OWNERS))
    snap(page, "launcher-thirteen", results)
    gates.close(page, failures)

    page, failures = gates.new_page(browser, URL, 360, 800)
    gates.opened(page, "Xác nhận nhu cầu")
    checkbox = gates.active(page).get_by_role("checkbox", name="Chỉ hiển thị thay đổi chưa lưu", exact=True)
    label = checkbox.locator("xpath=..")
    control = label.locator('[data-part="control"]')
    assert control.evaluate("e=>getComputedStyle(e).borderColor") == "rgb(112, 112, 112)"
    label.click()
    expect(checkbox).to_be_checked()
    expect(control).to_have_css("background-color", "rgb(15, 100, 78)")
    assert control.evaluate("e=>getComputedStyle(e).backgroundColor") == "rgb(15, 100, 78)"
    snap(page, "checkbox-checked-mobile", results)
    checkbox.focus()
    page.keyboard.press("Tab")
    page.keyboard.press("Shift+Tab")
    expect(checkbox).to_be_focused()
    assert_focus(control)
    snap(page, "checkbox-focus-mobile", results)
    # Isolated CSS-state probe reuses rendered production classes, not app facts.
    disabled_style = label.evaluate("""root=>{
      const probe=root.cloneNode(true); probe.dataset.disabled='';
      probe.querySelector('input').disabled=true;
      for(const part of probe.querySelectorAll('[data-part]')) part.dataset.disabled='';
      root.parentElement.append(probe);
      const control=getComputedStyle(probe.querySelector('[data-part=control]'));
      const label=getComputedStyle(probe.querySelector('[data-part=label]'));
      const result={bg:control.backgroundColor,color:control.color,opacity:control.opacity,
        border:control.borderColor,label:label.color,labelOpacity:label.opacity};
      probe.remove(); return result;
    }""")
    assert disabled_style == {"bg": "rgb(241, 241, 241)", "color": "rgb(85, 85, 85)",
                             "opacity": "1", "border": "rgb(208, 208, 208)",
                             "label": "rgb(85, 85, 85)", "labelOpacity": "1"}, disabled_style
    results[-1]["checked_disabled_css_probe"] = disabled_style
    gates.close(page, failures)
    (ROOT / "colors.json").write_text(json.dumps(colors, indent=2) + "\n", encoding="utf-8")
    return {"captures": results, "hosted_requests": 0, "viewport_zoom": "100%", "vision_simulation": "Chromium CDP, not human CVD certification"}


def regressions(browser):
    gates.ROOT = ROOT / "regressions"
    gates.ROOT.mkdir(exist_ok=True)
    gates.SAVE_IMAGES = False
    results, proofs = [], []
    gates.matrix(browser, URL, SIZES, results)
    gates.pairs(browser, URL, results, proofs)
    gates.capacity(browser, URL, gates.ROOT, results, full_page=False, save_image=False)
    gates.discard(browser, URL, proofs)
    return {"captures_measured_without_duplicate_images": results, "proofs": proofs, "hosted_requests": 0}


def repeated_scan(browser):
    page, failures = gates.new_page(browser, URL, 1440, 900)
    for key, label in SCREENS:
        gates.opened(page, label)
        if key in ["recipe", "allocation"]:
            select(page, "recipes" if key == "recipe" else "procurement")
    session = page.context.new_cdp_session(page)
    start, samples, captures = time.monotonic(), [], []
    for cycle in range(25):
        for vision in ["none", "achromatopsia"]:
            session.send("Emulation.setEmulatedVisionDeficiency", {"type": vision})
            for key, label in SCREENS:
                gates.opened(page, label)
                samples.append({"cycle": cycle, "vision": vision, "screen": key,
                                "elapsed_s": round(time.monotonic() - start, 1)})
                if key == "recipe" and cycle in [0, 12, 24]:
                    snap(page, f"repeated-scan-{cycle}-{vision}", captures)
        print(f"scan cycle {cycle}/24: {time.monotonic()-start:.1f}s", flush=True)
        if cycle < 24:
            time.sleep(max(0, (cycle + 1) * 75 - (time.monotonic() - start)))
    gates.close(page, failures)
    return {"elapsed_s": round(time.monotonic()-start, 1), "samples": samples,
            "captures": captures, "hosted_requests": 0,
            "scope": "30-minute fixture switching/engineering pixel review; not a human fatigue study"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--part", choices=["visual", "regressions", "performance", "scan"], required=True)
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        report = visual(browser) if args.part == "visual" else regressions(browser) if args.part == "regressions" else repeated_scan(browser) if args.part == "scan" else {
            "cpu_throttle": 4, "environment": "local Vite fixtures; click to two animation frames",
            "results": [benchmark(browser, width) for width in [1440, 650]]}
        report.update(browser=browser.version, fixture_only=True, status="PASS")
        browser.close()
    (ROOT / f"{args.part}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"part": args.part, "status": "PASS"}))
