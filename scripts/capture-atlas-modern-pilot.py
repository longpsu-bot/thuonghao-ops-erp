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
parser.add_argument("--workspace", action="store_true", help="D evidence, B/C/D comparison and persistent workspace checks")
parser.add_argument("--checks-only", action="store_true", help="Repeat workspace checks using an existing completed capture matrix")
parser.add_argument("--surface", action="append", choices=["need", "procurement", "recipes", "dispatch"])
parser.add_argument("--variant", action="append", choices=["A", "B", "C", "D"])
args = parser.parse_args()
assert args.out.is_absolute(), "Use an absolute artifact path outside the repository"
repo_root = Path(__file__).resolve().parents[1]
assert args.out.resolve() != repo_root and repo_root not in args.out.resolve().parents, "Do not commit screenshot binaries"
origin = urlsplit(args.url)
assert origin.scheme == "http" and origin.hostname in ("localhost", "127.0.0.1", "::1"), "Storybook must be local"
args.out.mkdir(parents=True, exist_ok=True)
surfaces = args.surface or ["need", "procurement", "recipes", "dispatch"]
variants = ["B", "C", "D"] if args.workspace else ["A", "B", "C"]
viewports = [(1920, 1080), (1440, 900), (1366, 768), (650, 900), (360, 800)]
records, errors, external, workspace_checks = [], [], [], {}
if args.checks_only:
    assert args.workspace, "Checks-only requires --workspace"
    records = json.loads((args.out / "capture-records.json").read_text(encoding="utf-8"))
elif args.variant and (args.out / "capture-records.json").exists():
    records = [record for record in json.loads((args.out / "capture-records.json").read_text(encoding="utf-8")) if record["variant"] not in args.variant]

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
    for surface in ([] if args.checks_only else surfaces):
        for variant in args.variant or variants:
            for width, height in ([(1440, 900), (360, 800)] if args.smoke else viewports):
                if args.workspace and variant != "D" and width not in (1440, 360):
                    continue
                states = ["normal", "selected", "dirty"] if args.smoke or args.workspace and width in (1440, 650, 360) else (
                    ["normal", "selected", "dirty", "blocked", "loading", "error", "empty", "ready"]
                    if width == 1440 else ["normal", "selected", "dirty"]
                    if width in (650, 360) else ["normal"]
                )
                for state in states:
                    page.set_viewport_size({"width": width, "height": height})
                    url = f"{args.url}/iframe.html?id=atlas-prototypes-modern-operational-03a--pilot&viewMode=story&surface={surface}&variant={variant}&state={state}" + ("&workspace=four" if variant == "D" else "")
                    page.goto(url, wait_until="networkidle")
                    page.wait_for_selector('[data-prepared="true"]', timeout=20000)
                    page.evaluate("document.fonts.ready")
                    page.evaluate("window.scrollTo(0, 0)")
                    page.add_style_tag(content="*,*::before,*::after{animation:none!important;transition:none!important}")
                    metrics = page.evaluate("""() => {
                      const workbench = document.querySelector('.workspace-panel:not([hidden])') ?? document.querySelector('main');
                      const table = workbench?.querySelector('table');
                      const rows = table ? [...table.querySelectorAll('tbody tr')] : [];
                      const scroll = table?.closest('[role=region], [data-scope=scroll-area]');
                      const limit = scroll?.getBoundingClientRect().bottom ?? innerHeight;
                      return {documentWidth:document.documentElement.scrollWidth, viewportWidth:innerWidth,
                        tableTop:table?.getBoundingClientRect().top ?? null, rowCount:rows.length,
                        visibleRows:rows.filter(row=>{const r=row.getBoundingClientRect();return r.top>=0 && r.bottom<=Math.min(limit,innerHeight-62)}).length,
                        localScrollRegions:[...document.querySelectorAll('main *')].filter(e=>e.scrollWidth>e.clientWidth+2 && ['auto','scroll'].includes(getComputedStyle(e).overflowX)).length,
                        title:workbench?.querySelector('h1')?.textContent,
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
                    if variant == "D" and surface != "need" and state in ("selected", "dirty") and width in (650, 360):
                        editor = (page.get_by_role("textbox",name="Ghi chú cho NCC An Phú",exact=False) if surface == "procurement" else page.get_by_label("Định lượng Bí đỏ",exact=True) if surface == "recipes" else page.get_by_role("textbox",name="Ghi chú trên phiếu",exact=True))
                        editor.scroll_into_view_if_needed()
                        editor.focus()
                        page.screenshot(path=str(args.out / f"{name}-editor.png"))
                    records.append({"surface": surface, "variant": variant, "state": state, "width": width, "height": height, "file": f"{name}.png", **metrics})
                    (args.out / "capture-records.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
                    print(name, "rows", metrics["visibleRows"], flush=True)
    if args.workspace:
        # Real boundary journey, not duplicated domain tests or production telemetry.
        def go(query, width=1440, height=900):
            page.set_viewport_size({"width": width, "height": height})
            page.goto(f"{args.url}/iframe.html?id=atlas-prototypes-modern-operational-03a--pilot&viewMode=story&variant=D&{query}", wait_until="networkidle")
            page.wait_for_selector('[data-prepared="true"]')
        def launch(label):
            page.get_by_role("button", name="Mở bàn làm việc", exact=True).click()
            page.get_by_role("navigation", name="Mở bàn làm việc Atlas").get_by_role("button", name=label, exact=True).click()
        def evidence():
            return page.locator('.workspace-panel').evaluate_all("nodes => Object.fromEntries(nodes.map(n=>[n.id,{mounts:Number(n.dataset.mountCount),reads:Number(n.dataset.readCount)}]))")
        def shot(name):
            assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), name
            page.screenshot(path=str(args.out / f"{name}.png"))
        go("surface=need&state=normal")
        quantity = page.get_by_role("textbox", name="Số lượng xác nhận Gạo thơm")
        quantity.fill("12,5")
        page.get_by_role("combobox", name="Lý do Gạo thơm").select_option("OTHER")
        page.get_by_role("textbox", name="Ghi chú Gạo thơm").fill("Giữ bản nháp khi đổi bàn")
        page.get_by_role("tab", name="Lập nhu cầu · thay đổi chưa lưu", exact=True).wait_for()
        quantity.evaluate("n => window.__needInput = n")
        launch("Kế hoạch mua hàng")
        search = page.get_by_role("textbox", name="Tìm kiếm", exact=True)
        search.fill("Gạo")
        page.get_by_role("button", name="Xem phân bổ Gạo thơm", exact=False).first.click()
        note = page.get_by_role("textbox", name="Ghi chú cho NCC An Phú", exact=False)
        note.wait_for()
        note.evaluate("n => window.__allocationNote = n")
        procurement = page.locator('#workspace-panel-procurement')
        procurement.evaluate("n => {const s=n.querySelector('[role=region][tabindex]'); if(s) s.scrollLeft=100; window.__tableScroll=s?.scrollLeft ?? 0}")
        launch("Công thức")
        page.get_by_role("textbox", name="Tìm món", exact=True).fill("Canh")
        launch("Phiếu xuất kho")
        page.get_by_role("heading", name="Phiếu xuất kho", exact=True).wait_for()
        before = evidence()
        assert len(before) == 4 and all(v["mounts"] == 1 for v in before.values()), before
        page.get_by_role("tab", name="Lập nhu cầu", exact=False).click()
        assert quantity.input_value() == "12,5"
        assert quantity.evaluate("n => n === window.__needInput")
        assert page.get_by_role("textbox", name="Ghi chú Gạo thơm").input_value() == "Giữ bản nháp khi đổi bàn"
        assert page.get_by_role("dialog").count() == 0
        launch("Kế hoạch mua hàng")
        assert page.get_by_role("tablist",name="Bàn làm việc đang mở",exact=True).get_by_role("tab").count() == 4
        assert search.input_value() == "Gạo" and note.evaluate("n => n === window.__allocationNote")
        assert procurement.evaluate("n => (n.querySelector('[role=region][tabindex]')?.scrollLeft ?? 0) === window.__tableScroll")
        after = evidence()
        assert after == before, (before, after)
        hidden = page.locator('#workspace-panel-need')
        assert hidden.evaluate("n => n.hidden && n.inert")
        page.evaluate("window.__needInput.focus()")
        assert page.evaluate("document.activeElement !== window.__needInput")
        shot("journey-four-open-dirty-inactive-selected-1440x900")
        page.get_by_role("tab", name="Công thức", exact=True).click()
        assert page.get_by_role("textbox", name="Tìm món", exact=True).input_value() == "Canh"
        page.get_by_role("tablist").get_by_role("button", name="Đóng bàn Công thức", exact=True).click()
        page.locator('#workspace-panel-recipes').wait_for(state="detached")
        page.get_by_role("tablist").get_by_role("button", name="Đóng bàn Lập nhu cầu", exact=True).click()
        guard = page.get_by_role("dialog")
        guard.wait_for()
        assert guard.get_by_text("Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?", exact=True).count() == 1
        shot("journey-dirty-close-guard-1440x900")
        guard.get_by_role("button", name="Tiếp tục chỉnh sửa", exact=True).click()
        guard.wait_for(state="hidden")
        page.get_by_role("tablist").wait_for()
        assert quantity.input_value() == "12,5"
        page.get_by_role("tablist").get_by_role("button", name="Đóng bàn Lập nhu cầu", exact=True).click()
        page.get_by_role("dialog").get_by_role("button", name="Bỏ thay đổi", exact=True).click()
        page.locator('#workspace-panel-need').wait_for(state="detached")
        workspace_checks.update({"mountsAndReadsBeforeSwitch":before,"mountsAndReadsAfterSwitch":after,"draftFilterSelectionScroll":"PASS","inactiveFocus":"PASS","cleanClose":"PASS","existingDirtyGuardCancelAndDiscard":"PASS"})
        print("Workspace mount/read/draft/selection/guard journey PASS",flush=True)

        # Local strip overflow and roving keyboard access at all required sizes.
        stress = []
        for width, height in ([(1440,900),(360,800)] if args.smoke else viewports):
            go("surface=need&state=normal&workspace=stress",width,height)
            if width >= 1024:
                first = page.get_by_role("tab", name="Lập nhu cầu", exact=True)
                assert page.get_by_role("tab").count() == 12
                first.focus()
                first.press("End")
                last = page.get_by_role("tab", name="Suất ăn & nguồn", exact=True)
                assert last.get_attribute("aria-selected") == "true"
                assert last.evaluate("n=>n===document.activeElement")
                page.wait_for_function("() => {const n=document.getElementById('workspace-tab-capacity-8'); return n.parentElement.getBoundingClientRect().right <= n.closest('[role=tablist]').getBoundingClientRect().right + 1}")
                assert last.evaluate("n=>n.parentElement.getBoundingClientRect().right <= n.closest('[role=tablist]').getBoundingClientRect().right + 1"), "Active close control clipped"
                metrics = page.locator('.workspace-tabs').evaluate("n=>({width:n.clientWidth,scrollWidth:n.scrollWidth,scrollLeft:n.scrollLeft})")
                assert metrics["scrollWidth"] > metrics["width"] and metrics["scrollLeft"] > 0, metrics
                last.press("Home")
                first.press("ArrowRight")
                assert page.get_by_role("tab",name="Kế hoạch mua hàng",exact=True).get_attribute("aria-selected") == "true"
                first.focus()
                first.press("End")
            else:
                selector = page.get_by_role("combobox",name="Bàn đang mở",exact=True)
                assert selector.locator('option').count() == 12
                selector.select_option("capacity-8")
                assert page.get_by_role("heading",name="Suất ăn & nguồn",exact=True).count() == 1
                assert selector.bounding_box()["height"] >= 44
                metrics = {"mobileOptions":12,"selectHeight":selector.bounding_box()["height"]}
            shot(f"workspace-stress-{width}x{height}")
            stress.append({"width":width,"height":height,**metrics})
            print(f"Twelve-tab keyboard/overflow {width}x{height} PASS",flush=True)
        workspace_checks["twelveTabOverflowKeyboard"] = stress

        # Calendar portal stays with its workbench; narrow switching uses a native selector.
        go("surface=need&state=dirty&workspace=four",360,800)
        mobile = page.get_by_role("combobox",name="Bàn đang mở",exact=True)
        mobile.select_option("procurement")
        shot("journey-mobile-dirty-inactive-360x800")
        mobile.select_option("need")
        assert page.get_by_role("textbox",name="Số lượng xác nhận Gạo thơm").input_value() == "12,5"
        page.get_by_role("button",name="Đóng bàn Lập nhu cầu",exact=True).click()
        page.get_by_role("dialog").wait_for()
        shot("journey-mobile-dirty-close-360x800")
        page.get_by_role("dialog").get_by_role("button",name="Tiếp tục chỉnh sửa",exact=True).click()
        page.get_by_role("dialog").wait_for(state="hidden")
        page.get_by_role("button",name="Đóng bàn Lập nhu cầu",exact=True).click()
        page.get_by_role("dialog").get_by_role("button",name="Bỏ thay đổi",exact=True).click()
        page.locator('#workspace-panel-need').wait_for(state="detached")
        assert mobile.evaluate("n=>n===document.activeElement"), "Mobile approved close lost focus"
        launch("Công thức")
        assert mobile.evaluate("n=>n===document.activeElement"), "Existing mobile launch lost focus"
        page.get_by_role("button",name="Mở bàn làm việc",exact=True).click()
        menu = page.get_by_role("navigation",name="Mở bàn làm việc Atlas",exact=True)
        menu.get_by_role("button").last.focus()
        menu.get_by_role("button").last.press("Tab")
        menu.wait_for(state="hidden")
        assert mobile.evaluate("n=>n===document.activeElement"), "Launcher obscured next keyboard control"
        shot("journey-mobile-approved-close-focus-360x800")
        workspace_checks["mobileSwitchAndGuard"] = "PASS"
        workspace_checks["mobileFocusAndLauncherDismissal"] = "PASS"

        go("surface=need&state=dirty&workspace=four",1366,768)
        save = page.get_by_role("button",name="Lưu",exact=True)
        assert save.is_enabled()
        bounds = save.bounding_box()
        assert bounds["y"] >= 0 and bounds["y"] + bounds["height"] <= 768, bounds
        shot("journey-need-dirty-save-visible-1366x768")
        workspace_checks["laptopNeedSaveBounds"] = bounds
        print("Mobile focus/launcher and laptop Need Save PASS",flush=True)

        go("surface=need&state=normal&workspace=four")
        # Existing Calendar trigger naming is confirmed from the rendered control.
        page.get_by_role("button",name="Mở lịch — Tuần phục vụ",exact=True).click()
        page.get_by_role("application",name="Lịch — Tuần phục vụ",exact=True).wait_for()
        page.get_by_role("tab",name="Kế hoạch mua hàng",exact=True).click()
        assert page.locator('#workspace-panel-need').evaluate("n=>n.hidden && n.inert")
        assert page.get_by_role("dialog").count() == 0
        assert page.get_by_role("application",name="Lịch — Tuần phục vụ",exact=True).count() == 0
        page.get_by_role("tab",name="Lập nhu cầu",exact=True).click()
        assert page.get_by_role("dialog").count() == 0
        assert page.get_by_role("application",name="Lịch — Tuần phục vụ",exact=True).count() == 0
        workspace_checks["calendarPortalHidden"] = "PASS"
        print("Calendar portal ownership/dismissal PASS",flush=True)

    # Existing A/B/C composition check remains separately scoped.
    page.goto(f"{args.url}/iframe.html?id=atlas-prototypes-modern-operational-03a--pilot&viewMode=story&surface=need&variant=A&state=dirty", wait_until="networkidle")
    page.wait_for_selector('[data-prepared="true"]')
    before = page.get_by_role("textbox", name="Số lượng xác nhận Gạo thơm").input_value()
    for index, variant in enumerate(["A", "B", "C"]):
        page.locator(".pilot-switcher button[aria-pressed]").nth(index).click()
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
        ("responsive", [("normal", 360, 800), ("selected", 360, 800), ("dirty", 360, 800)] if args.smoke or args.workspace else [("normal", 650, 900), ("normal", 360, 800), ("dirty", 360, 800)], 360),
    ]:
        cell_heights = [round(height * cell_width / width) + 32 for _, width, height in cases]
        canvas = Image.new("RGB", (cell_width * 3, sum(cell_heights) + 50), "#EDF0ED")
        draw = ImageDraw.Draw(canvas)
        draw.text((12, 12), f"Atlas 03A / {surface} / {sheet} / {' - '.join(variants)}", fill="#2A3330", font=font)
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

manifest = {"browser": f"Chromium {browser_version}", "dpr": 1, "reducedMotion": True, "records": records, "contactSheets": sheets, "pageErrors": errors, "externalRequests": external, "draftPreservation": "PASS", "post348Gates": "PASS", "workspaceChecks":workspace_checks}
if (args.out / "manifest.json").exists():
    previous = json.loads((args.out / "manifest.json").read_text(encoding="utf-8"))
    merged = {record["file"]: record for record in previous["records"]}
    merged.update({record["file"]: record for record in records})
    manifest["records"] = list(merged.values())
    manifest["contactSheets"] = sorted(set(previous["contactSheets"] + sheets))
(args.out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"Captured {len(records)} states, {len(sheets)} contact sheets; all checks passed.")
