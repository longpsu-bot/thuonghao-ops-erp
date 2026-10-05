"""Capture the review-only Storybook pilot; never connects to hosted services.

Requires the host's existing Python Playwright/Pillow and a running Storybook.
python scripts/capture-atlas-modern-pilot.py --out ABSOLUTE_ARTIFACT_DIRECTORY
Use --smoke for the first batched desktop/mobile inspection; full run is the
confirmation/evidence pass. Outputs are outside Git, including the manifest.
"""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit

from PIL import Image, ImageDraw, ImageFont
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--out", type=Path, required=True)
parser.add_argument("--url", default="http://localhost:6006")
parser.add_argument("--smoke", action="store_true")
parser.add_argument("--surface", action="append", choices=["need", "procurement", "recipes", "dispatch"])
parser.add_argument("--variant", action="append", choices=["A", "B", "C"])
args = parser.parse_args()
assert args.out.is_absolute(), "Use an absolute artifact path outside the repository"
repo_root = Path(__file__).resolve().parents[1]
assert args.out.resolve() != repo_root and repo_root not in args.out.resolve().parents, "Do not commit screenshot binaries"
origin = urlsplit(args.url)
assert origin.scheme == "http" and origin.hostname in ("localhost", "127.0.0.1", "::1"), "Storybook must be local"
args.out.mkdir(parents=True, exist_ok=True)
surfaces = args.surface or ["need", "procurement", "recipes", "dispatch"]
variants = ["A", "B", "C"]
viewports = [(1920, 1080), (1440, 900), (1366, 768), (650, 900), (360, 800)]
records, errors, external = [], [], []

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(device_scale_factor=1, reduced_motion="reduce")
    page = context.new_page()
    page.on("pageerror", lambda error: errors.append(str(error)))
    # Fail closed: no real application network call can escape the local harness.
    def route(request_route):
        url = request_route.request.url
        target = urlsplit(url)
        if (target.scheme, target.hostname, target.port) == (origin.scheme, origin.hostname, origin.port) or target.scheme in ("data", "blob"):
            request_route.continue_()
        else:
            external.append(url)
            request_route.abort()
    context.route("**/*", route)
    for surface in surfaces:
        for variant in args.variant or variants:
            for width, height in ([(1440, 900), (360, 800)] if args.smoke else viewports):
                states = ["normal", "selected", "dirty"] if args.smoke else (
                    ["normal", "selected", "dirty", "blocked", "loading", "error", "empty", "ready"]
                    if width == 1440 else ["normal", "selected", "dirty"]
                    if width in (650, 360) else ["normal"]
                )
                for state in states:
                    page.set_viewport_size({"width": width, "height": height})
                    url = f"{args.url}/iframe.html?id=atlas-prototypes-modern-operational-03a--pilot&viewMode=story&surface={surface}&variant={variant}&state={state}"
                    page.goto(url, wait_until="networkidle")
                    page.wait_for_selector('[data-prepared="true"]', timeout=20000)
                    page.evaluate("document.fonts.ready")
                    page.evaluate("window.scrollTo(0, 0)")
                    page.add_style_tag(content="*,*::before,*::after{animation:none!important;transition:none!important}")
                    metrics = page.evaluate("""() => {
                      const table = document.querySelector('main table');
                      const rows = table ? [...table.querySelectorAll('tbody tr')] : [];
                      const scroll = table?.closest('[role=region], [data-scope=scroll-area]');
                      const limit = scroll?.getBoundingClientRect().bottom ?? innerHeight;
                      return {documentWidth:document.documentElement.scrollWidth, viewportWidth:innerWidth,
                        tableTop:table?.getBoundingClientRect().top ?? null, rowCount:rows.length,
                        visibleRows:rows.filter(row=>{const r=row.getBoundingClientRect();return r.top>=0 && r.bottom<=Math.min(limit,innerHeight-62)}).length,
                        localScrollRegions:[...document.querySelectorAll('main *')].filter(e=>e.scrollWidth>e.clientWidth+2 && ['auto','scroll'].includes(getComputedStyle(e).overflowX)).length,
                        title:document.querySelector('main h1')?.textContent,
                        bodyHeight:document.documentElement.scrollHeight};
                    }""")
                    assert metrics["documentWidth"] <= width + 1, (surface, variant, state, width, metrics)
                    assert metrics["title"], (surface, variant, state, "Missing workbench")
                    if surface == "need" and state in ("normal", "selected", "dirty"):
                        export = page.get_by_role("button", name="Xuất Phiếu đi chợ", exact=True)
                        imp = page.get_by_role("button", name="Nhập Phiếu đi chợ", exact=True)
                        assert export.count() == imp.count() == 1
                        assert export.is_disabled() == (state == "dirty")
                        assert imp.is_disabled() == (state == "dirty")
                        if state == "dirty":
                            assert page.get_by_role("button", name="Lưu", exact=True).is_enabled()
                            assert page.get_by_role("button", name="Tiếp tục phân bổ NCC", exact=True).is_disabled()
                    name = f"{surface}-{variant}-{state}-{width}x{height}"
                    page.screenshot(path=str(args.out / f"{name}.png"))
                    if state in ("selected", "dirty") and width in (1440, 650, 360):
                        page.screenshot(path=str(args.out / f"{name}-full.png"), full_page=True)
                    if surface == "need" and state == "dirty" and width in (650, 360):
                        quantity = page.get_by_role("textbox", name="Số lượng xác nhận Gạo thơm")
                        quantity.focus()
                        page.screenshot(path=str(args.out / f"{name}-focused.png"))
                    records.append({"surface": surface, "variant": variant, "state": state, "width": width, "height": height, "file": f"{name}.png", **metrics})
                    print(name, "rows", metrics["visibleRows"], flush=True)
    # One runnable interaction check: composition switches preserve dirty drafts.
    page.goto(f"{args.url}/iframe.html?id=atlas-prototypes-modern-operational-03a--pilot&viewMode=story&surface=need&variant=A&state=dirty", wait_until="networkidle")
    page.wait_for_selector('[data-prepared="true"]')
    before = page.get_by_role("textbox", name="Số lượng xác nhận Gạo thơm").input_value()
    for variant in variants:
        page.locator(".pilot-switcher button[aria-pressed]").nth(variants.index(variant)).click()
        assert page.get_by_role("textbox", name="Số lượng xác nhận Gạo thơm").input_value() == before
    assert not errors, errors
    assert not external, external
    browser_version = browser.version
    browser.close()

font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
small_font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 14)
sheets = []
for surface in surfaces:
    for sheet, cases, cell_width in [
        ("desktop", [("normal", 1440, 900), ("selected", 1440, 900), ("dirty", 1440, 900)], 600),
        ("responsive", [("normal", 360, 800), ("selected", 360, 800), ("dirty", 360, 800)] if args.smoke else [("normal", 650, 900), ("normal", 360, 800), ("dirty", 360, 800)], 360),
    ]:
        cell_heights = [round(height * cell_width / width) + 32 for _, width, height in cases]
        canvas = Image.new("RGB", (cell_width * 3, sum(cell_heights) + 50), "#EDF0ED")
        draw = ImageDraw.Draw(canvas)
        draw.text((12, 12), f"Atlas 03A / {surface} / {sheet} / A - B - C", fill="#2A3330", font=font)
        y = 50
        for (state, width, height), cell_height in zip(cases, cell_heights):
            for index, variant in enumerate(variants):
                source = args.out / f"{surface}-{variant}-{state}-{width}x{height}.png"
                with Image.open(source) as shot:
                    shot.load()
                    assert shot.size == (width, height), source
                    assert shot.convert("L").getextrema()[0] != shot.convert("L").getextrema()[1], source
                    thumb = shot.convert("RGB").resize((cell_width, cell_height - 32), Image.Resampling.LANCZOS)
                    canvas.paste(thumb, (index * cell_width, y + 32))
                draw.text((index * cell_width + 8, y + 7), f"{variant} / {state} / {width}x{height}", fill="#2A3330", font=small_font)
            y += cell_height
        name = f"contact-{surface}-{sheet}.png"
        canvas.save(args.out / name)
        sheets.append(name)

manifest = {"browser": f"Chromium {browser_version}", "dpr": 1, "reducedMotion": True, "records": records, "contactSheets": sheets, "pageErrors": errors, "externalRequests": external, "draftPreservation": "PASS", "post348Gates": "PASS"}
if (args.out / "manifest.json").exists():
    previous = json.loads((args.out / "manifest.json").read_text(encoding="utf-8"))
    merged = {record["file"]: record for record in previous["records"]}
    merged.update({record["file"]: record for record in records})
    manifest["records"] = list(merged.values())
    manifest["contactSheets"] = sorted(set(previous["contactSheets"] + sheets))
(args.out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"Captured {len(records)} states, {len(sheets)} contact sheets; all checks passed.")
