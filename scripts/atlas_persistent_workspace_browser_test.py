"""Production App fixture evidence; no hosted calls. Start: pnpm exec vite.

Run: python -X utf8 scripts/atlas_persistent_workspace_browser_test.py --phase after
"""
import argparse
import json
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

SIZES = [(1920, 1080), (1440, 900), (1366, 768), (650, 900), (360, 800)]
LABELS = {"need": "Lập nhu cầu", "procurement": "Kế hoạch mua hàng", "recipes": "Công thức", "pxk": "Phiếu xuất kho"}


def launch(page, label):
    page.get_by_role("button", name="Bàn làm việc", exact=True).click()
    page.get_by_role("dialog", name="Bàn làm việc", exact=True).get_by_role("button", name=label, exact=True).click()
    expect(page.get_by_role("dialog", name="Bàn làm việc", exact=True)).to_have_count(0)


def select(page, kind):
    if kind == "need":
        page.get_by_role("tab", name="Xác nhận nhu cầu", exact=True).click()
        expect(page.get_by_role("textbox", name=re.compile("^Số lượng xác nhận")).first).to_be_visible()
    elif kind == "procurement":
        page.get_by_role("button", name=re.compile("^(Xem phân bổ|Phân bổ NCC) Gạo thơm")).click()
        expect(page.locator('aside[aria-label="Phân bổ Gạo thơm"]')).to_be_visible()
    elif kind == "recipes":
        page.get_by_role("button", name="Sửa công thức Canh bí đỏ thịt bằm", exact=True).click()
        expect(page.get_by_role("heading", name="Công thức gốc", exact=True)).to_be_visible()
    else:
        page.get_by_role("table", name="Phiếu xuất kho theo trường").get_by_role("button", name=re.compile("^Phát hành")).first.click()
        expect(page.get_by_role("region", name="Nội dung phiếu", exact=True)).to_be_visible()


def dirty(page, kind):
    if kind == "need":
        control = page.get_by_role("textbox", name=re.compile("^Số lượng xác nhận")).first
        control.fill("31")
        page.get_by_role("combobox", name=re.compile("^Lý do")).first.select_option("OTHER")
        page.get_by_role("textbox", name=re.compile("^Ghi chú Gạo thơm")).first.fill("Điều chỉnh theo ghi nhận tại bếp")
    elif kind == "procurement":
        control = page.get_by_role("textbox", name=re.compile("^Ghi chú cho ")).first
        control.fill("Giữ ghi chú nhà cung ứng")
    elif kind == "recipes":
        page.get_by_role("button", name="Sửa thông tin món", exact=True).click()
        control = page.get_by_role("textbox", name="Tên món", exact=True)
        control.fill("Canh bí đỏ giữ nguyên bản nháp")
    else:
        control = page.get_by_role("textbox", name="Ghi chú trên phiếu", exact=True)
        control.fill("Giữ ghi chú phát hành")
    return control, control.input_value()


def capture(page, root, name, results, full_page=True, save_image=True):
    if save_image:
        page.screenshot(path=str(root / f"{name}.png"), full_page=full_page)
    metrics = page.evaluate("""() => ({
      viewport:{width:innerWidth,height:innerHeight},
      activeOwner:document.querySelector('main>[role=tabpanel]:not([hidden])')?.getAttribute('aria-label'),
      overflow:document.documentElement.scrollWidth>innerWidth,
      activePanels:[...document.querySelectorAll('main>[role=tabpanel]')].filter(e=>!e.hidden).length,
      hiddenOwners:[...document.querySelectorAll('main>[role=tabpanel][hidden]')].map(e=>({name:e.getAttribute('aria-label'),inert:e.inert})),
      focusHidden:!!document.activeElement?.closest('[hidden],[inert]'),
      heading:[...document.querySelectorAll('h1')].filter(e=>e.getClientRects().length).map(e=>({text:e.textContent,size:getComputedStyle(e).fontSize,weight:getComputedStyle(e).fontWeight})),
      targets:[...document.querySelectorAll('header button,button[id$="open-trigger"]')].filter(e=>e.getClientRects().length).map(e=>({label:e.getAttribute('aria-label')||e.textContent,width:e.getBoundingClientRect().width,height:e.getBoundingClientRect().height}))
    })""")
    results.append({"capture": name, **metrics})
    assert not metrics["overflow"], results[-1]
    assert not metrics["focusHidden"], results[-1]
    assert metrics["activePanels"] == 1, results[-1]
    assert all(owner["inert"] for owner in metrics["hiddenOwners"]), results[-1]


def capacity(browser, url, root, results, full_page=True, save_image=True):
    for width, height in [(1366, 768), (360, 800)]:
        page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
        page.goto(url + "?capacity=12")
        page.wait_for_load_state("networkidle")
        if width > 1024:
            tabs = page.get_by_role("tab")
            expect(tabs).to_have_count(12)
            strip = page.get_by_role("tablist", name="Bàn làm việc đang mở")
            assert strip.evaluate("e=>e.scrollWidth>e.clientWidth")
            tabs.first.focus()
            for index in range(12):
                tab = tabs.nth(index)
                if index:
                    page.keyboard.press("ArrowRight")
                expect(tab).to_be_focused()
                expect(tab).to_have_attribute("aria-selected", "true")
                assert tab.evaluate("e=>{const item=e.parentElement.getBoundingClientRect(),s=e.closest('[role=tablist]').getBoundingClientRect();return item.left>=s.left-1&&item.right<=s.right+1}")
            capture(page, root, f"capacity-{width}x{height}", results, full_page=full_page, save_image=save_image)
            page.keyboard.press("Home")
            expect(tabs.first).to_be_focused()
        else:
            page.get_by_role("button", name=re.compile("^Đang mở:")).click()
            popup = page.get_by_role("dialog", name="Bàn làm việc đang mở", exact=True)
            expect(popup.get_by_role("button")).to_have_count(24)
            for index in range(12):
                button = popup.locator("button[data-destination]").nth(index)
                button.scroll_into_view_if_needed()
                expect(button).to_be_in_viewport()
                assert button.bounding_box()["height"] >= 44
                assert popup.get_by_role("button", name=re.compile("^Đóng ")).nth(index).bounding_box()["height"] >= 44
            capture(page, root, f"capacity-{width}x{height}", results, full_page=full_page, save_image=save_image)
        page.close()


def workspace(browser, url, root, results):
    for width, height in [(1440, 900), (360, 800)]:
        page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
        page.goto(url)
        page.wait_for_load_state("networkidle")
        school = page.get_by_role("textbox", name=re.compile("Học sinh mặc định")).first
        school.fill("123")
        school.evaluate("e=>e.dataset.workspaceRetain='school'")
        school = page.locator('[data-workspace-retain="school"]')
        launch(page, "Công thức")
        page.get_by_role("button", name="Tạo món mới", exact=True).click()
        dish = page.get_by_role("textbox", name="Tên món", exact=True)
        dish.fill("Món giữ trong bàn làm việc")
        dish.evaluate("e=>e.dataset.workspaceRetain='dish'")
        dish = page.locator('[data-workspace-retain="dish"]')
        launch(page, "Phiếu xuất kho")
        select(page, "pxk")
        note = page.get_by_role("textbox", name="Ghi chú trên phiếu", exact=True)
        note.fill("Giao cổng phụ")
        page.get_by_role("button", name="Tài khoản và môi trường", exact=True).click()
        page.get_by_role("button", name="Đăng xuất", exact=True).click()
        for label in ["Trường học", "Công thức", "Phiếu xuất kho"]:
            expect(page.get_by_role("button", name=f"{label} — Chưa lưu", exact=True)).to_be_visible()
        expect(school).to_have_value("123")
        expect(dish).to_have_value("Món giữ trong bàn làm việc")
        expect(note).to_have_value("Giao cổng phụ")
        capture(page, root, f"multiple-dirty-signout-{width}x{height}", results)
        page.get_by_role("button", name="Bàn làm việc", exact=True).click()
        capture(page, root, f"launcher-{width}x{height}", results)
        page.get_by_role("textbox", name="Tìm bàn làm việc", exact=True).fill("cong thuc")
        page.keyboard.press("ArrowDown")
        expect(page.get_by_role("button", name="Công thức", exact=True)).to_be_focused()
        page.keyboard.press("Escape")
        expect(page.get_by_role("button", name="Bàn làm việc", exact=True)).to_be_focused()
        if width < 1024:
            page.get_by_role("button", name=re.compile("^Đang mở:")).click()
            capture(page, root, f"open-selector-{width}x{height}", results)
        page.get_by_role("button", name="Đóng Trường học", exact=True).click()
        expect(page.get_by_role("button", name="Tiếp tục chỉnh sửa", exact=True)).to_be_visible()
        expect(school).to_be_visible()
        page.get_by_role("button", name="Tiếp tục chỉnh sửa", exact=True).click()
        expect(school).to_have_value("123")
        if width < 1024:
            page.get_by_role("button", name=re.compile("^Đang mở:")).click()
        page.get_by_role("button", name="Đóng Trường học", exact=True).click()
        page.get_by_role("button", name="Bỏ thay đổi", exact=True).click()
        expect(school).to_have_count(0)
        if width >= 1024:
            expect(page.get_by_role("tablist", name="Bàn làm việc đang mở").get_by_role("tab", name=re.compile("^Công thức"))).to_be_focused()
        else:
            expect(page.get_by_role("button", name=re.compile("^Đang mở:"))).to_be_focused()
        expect(dish).to_have_value("Món giữ trong bàn làm việc")
        capture(page, root, f"guarded-close-{width}x{height}", results)
        page.close()


def states(browser, url, root, results, sizes, scenarios=("blocked", "loading", "error", "empty", "ready")):
    for width, height in sizes:
        for scenario in scenarios:
            for kind, label in LABELS.items():
                print(f"after: {kind} {scenario} {width}x{height}", flush=True)
                page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(url + f"?scenario={scenario}")
                page.wait_for_load_state("networkidle")
                launch(page, label)
                if kind == "need":
                    page.get_by_role("tab", name="Xác nhận nhu cầu", exact=True).click()
                if scenario == "error":
                    expect(page.locator("main").get_by_role("alert").first).to_be_visible()
                elif scenario == "loading":
                    expect(page.get_by_text(re.compile("Đang tải")).first).to_be_visible()
                elif scenario == "blocked" and kind == "recipes":
                    page.get_by_role("button", name=re.compile("^(Sửa|Xem) công thức Canh bí đỏ")).click()
                    expect(page.get_by_role("heading", name="Công thức gốc", exact=True)).to_be_visible()
                elif scenario == "empty":
                    expect(page.get_by_text(re.compile("(Không có|Chưa có|chưa có)")).first).to_be_visible()
                capture(page, root, f"{kind}-{scenario}-{width}x{height}", results)
                assert not errors, errors
                page.close()


def recovery(browser, url, root, results):
    for width, height in [(1440, 900), (360, 800)]:
        for scenario, kind in [("unknown", "procurement"), ("stale", "pxk")]:
            page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
            page.goto(url + f"?scenario={scenario}")
            page.wait_for_load_state("networkidle")
            launch(page, LABELS[kind])
            select(page, kind)
            if kind == "procurement":
                page.get_by_role("button", name="Dùng đề xuất", exact=True).click()
                page.get_by_role("button", name="Lưu phân bổ", exact=True).click()
                expect(page.get_by_role("button", name="Tải lại để xác nhận", exact=True)).to_be_visible()
                expect(page.get_by_role("button", name="Lưu phân bổ", exact=True)).to_be_disabled()
            else:
                page.get_by_role("region", name="Nội dung phiếu", exact=True).get_by_role("button", name="Phát hành phiếu xuất kho", exact=True).click()
                expect(page.locator("main").get_by_role("alert").first).to_be_visible()
            launch(page, "Trường học")
            launch(page, LABELS[kind])
            expect(page.get_by_role("button", name="Làm mới dữ liệu", exact=True)).to_be_disabled()
            capture(page, root, f"{kind}-{scenario}-{width}x{height}", results)
            page.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["before", "after"], required=True)
    parser.add_argument("--url", default="http://127.0.0.1:3000/atlas-vnext-review.html")
    parser.add_argument("--sizes", nargs="+", help="Optional bounded rerun, e.g. 360x800")
    args = parser.parse_args()
    root = Path("docs/testing/artifacts/atlas-persistent-workspace-03c") / args.phase
    root.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        sizes = [tuple(map(int, size.split("x"))) for size in args.sizes] if args.sizes else SIZES
        for width, height in sizes:
            for kind, label in LABELS.items():
                print(f"{args.phase}: {kind} {width}x{height}", flush=True)
                page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(args.url)
                page.wait_for_load_state("networkidle")
                launch(page, label)
                if args.phase == "after":
                    if kind == "need":
                        page.get_by_role("tab", name="Xác nhận nhu cầu", exact=True).click()
                    capture(page, root, f"{kind}-normal-{width}x{height}", results)
                select(page, kind)
                capture(page, root, f"{kind}-selected-{width}x{height}", results)
                if args.phase == "after":
                    control, value = dirty(page, kind)
                    control.evaluate("e=>e.dataset.retentionCheck='true'")
                    capture(page, root, f"{kind}-dirty-{width}x{height}", results)
                    launch(page, "Trường học")
                    owner = page.locator('[data-retention-check="true"]')
                    assert owner.evaluate("e=>!!e.closest('[hidden][inert]')")
                    launch(page, label)
                    expect(owner).to_have_value(value)
                    expect(owner).to_be_visible()
                    if width == 1366 and kind == "need":
                        save = page.get_by_role("button", name="Lưu", exact=True)
                        expect(save).to_be_enabled()
                        expect(save).to_be_in_viewport()
                assert not errors, errors
                page.close()
        if args.phase == "after" and not args.sizes:
            capacity(browser, args.url, root, results)
            workspace(browser, args.url, root, results)
            states(browser, args.url, root, results, sizes)
            recovery(browser, args.url, root, results)
        (root / "geometry.json").write_text(json.dumps({"browser": browser.version, "reducedMotion": True, "actualTouch": False, "results": results}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        browser.close()


if __name__ == "__main__":
    main()
