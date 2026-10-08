"""Integrated production UI with opt-in local snapshots; no hosted requests.

Start Vite, then: python -X utf8 scripts/atlas_product_corrections_browser_test.py
"""
import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright, expect
from atlas_persistent_workspace_browser_test import SIZES, launch, select, capture, capacity
from atlas_workspace_performance import OWNERS

ROOT = Path("docs/testing/artifacts/atlas-product-corrections-01")
SAVE_IMAGES = True


def opened(page, label):
    launch(page, label)
    expect(page.locator('main>[role="tabpanel"]:not([hidden])')).to_have_attribute("aria-label", label)


def active(page):
    return page.locator('main>[role="tabpanel"]:not([hidden])')


def snapshot(page, name, results):
    capture(page, ROOT, name, results, full_page=False, save_image=SAVE_IMAGES)
    assert len(results[-1]["heading"]) == 1, results[-1]


def new_page(browser, url, width, height, scenario="", motion="reduce"):
    page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion=motion)
    failures = []
    page.on("pageerror", lambda error: failures.append(str(error)))
    page.on("request", lambda request: failures.append(request.url)
            if urlparse(request.url).hostname not in ["127.0.0.1", "localhost", None] else None)
    page.goto(url + (f"?scenario={scenario}" if scenario else ""))
    page.wait_for_load_state("networkidle")
    return page, failures


def close(page, failures):
    assert not failures, failures
    page.close()


def change_editor(page):
    page.get_by_role("button", name="Tạo lệnh điều chỉnh", exact=True).click()
    editor = page.get_by_role("form", name="Tạo lệnh điều chỉnh", exact=True)
    editor.get_by_label("Món", exact=True).select_option("dish-0")
    editor.get_by_label("Loại công thức", exact=True).select_option("scope-0")
    editor.get_by_label("Hành động", exact=True).select_option("ADD")
    editor.get_by_label("Nguyên liệu thêm", exact=True).select_option("ingredient-3")
    editor.get_by_label("Định lượng mới", exact=True).fill("1,5")
    editor.get_by_label("Lý do điều chỉnh", exact=True).fill("Điều chỉnh theo thực đơn")
    expect(page.get_by_role("button", name="Xem tác động", exact=True)).to_be_enabled()
    quantity = page.get_by_label("Định lượng mới", exact=True)
    expect(quantity).to_have_attribute("aria-describedby", re.compile(".+"))
    expect(page.get_by_role("group", name="Định lượng và đơn vị", exact=True)).to_contain_text("Kilôgam")
    expect(page.get_by_role("combobox", name="Đơn vị", exact=True)).to_have_count(0)


def reveal_menu_cell(page):
    cell = page.get_by_role("table", name="Thực đơn theo trường").get_by_text("Canh rau ngót", exact=True)
    cell.scroll_into_view_if_needed()
    # Keep the evidence cell clear of the table's sticky School column on phones.
    cell.evaluate("""e=>{
      const td=e.closest('td'), first=td.parentElement.firstElementChild;
      let scroll=td.closest('table').parentElement;
      while(scroll && scroll.scrollWidth<=scroll.clientWidth) scroll=scroll.parentElement;
      if(scroll && getComputedStyle(first).position==='sticky')
        scroll.scrollLeft+=td.getBoundingClientRect().left-first.getBoundingClientRect().right;
    }""")
    expect(cell).to_be_in_viewport()
    assert cell.evaluate("""e=>{
      const first=e.closest('tr').firstElementChild, range=document.createRange();
      range.selectNodeContents(e);
      const text=range.getBoundingClientRect();
      return text.right<=innerWidth && (getComputedStyle(first).position!=='sticky'||text.left>=first.getBoundingClientRect().right);
    }""")


def matrix(browser, url, sizes, results):
    for width, height in sizes:
        size = f"{width}x{height}"
        print(f"matrix {size}", flush=True)
        page, failures = new_page(browser, url, width, height)
        snapshot(page, f"launcher-collapsed-{size}", results)
        trigger = page.get_by_role("button", name="Bàn làm việc", exact=True)
        trigger.click()
        launcher = page.get_by_role("dialog", name="Bàn làm việc", exact=True)
        expect(launcher.locator("button[data-destination]")).to_have_count(len(OWNERS))
        snapshot(page, f"launcher-open-{size}", results)
        page.get_by_role("textbox", name="Tìm bàn làm việc", exact=True).fill("cong thuc")
        page.keyboard.press("ArrowDown")
        expect(launcher.get_by_role("button", name="Công thức", exact=True)).to_be_focused()
        page.keyboard.press("Escape")
        expect(trigger).to_be_focused()
        for label in OWNERS[1:]:
            opened(page, label)
            if page.locator('main>[role="tabpanel"]').count() == 8:
                snapshot(page, f"tabs-eight-{size}", results)
        expect(page.locator('main>[role="tabpanel"]')).to_have_count(len(OWNERS))
        snapshot(page, f"tabs-thirteen-{size}", results)
        for index, label in enumerate(OWNERS):
            opened(page, label)
            expect(page.locator('main>[role="tabpanel"]')).to_have_count(len(OWNERS))
            snapshot(page, f"owner-{index:02}-{size}", results)
        if width >= 1024:
            tabs = page.get_by_role("tablist", name="Bàn làm việc đang mở").get_by_role("tab")
            tabs.first.focus()
            page.keyboard.press("Home")
            for index in range(len(OWNERS)):
                if index:
                    page.keyboard.press("ArrowRight")
                expect(tabs.nth(index)).to_be_focused()
                assert tabs.nth(index).evaluate("e=>{const i=e.parentElement.getBoundingClientRect(),s=e.closest('[role=tablist]').getBoundingClientRect();return i.left>=s.left-1&&i.right<=s.right+1}")
        else:
            for label in OWNERS:
                page.get_by_role("button", name=re.compile("^Đang mở:")).click()
                popup = page.get_by_role("dialog", name="Bàn làm việc đang mở", exact=True)
                target = popup.get_by_role("button", name=label, exact=True)
                target.scroll_into_view_if_needed()
                assert target.bounding_box()["height"] >= 44
                target.click()
                expect(active(page)).to_have_attribute("aria-label", label)
        opened(page, "Công thức")
        select(page, "recipes")
        quantity = page.get_by_role("textbox", name="Định lượng Bí đỏ", exact=True)
        expect(quantity.locator("xpath=ancestor::tr")).to_contain_text("Kilôgam")
        expect(quantity.locator("xpath=ancestor::tr").get_by_role("combobox")).to_have_count(0)
        unit = quantity.locator("xpath=ancestor::tr").get_by_text("Kilôgam", exact=True)
        unit.scroll_into_view_if_needed()
        expect(quantity).to_be_in_viewport(ratio=1)
        expect(unit).to_be_in_viewport(ratio=1)
        snapshot(page, f"recipe-editor-unit-{size}", results)
        opened(page, "Lệnh điều chỉnh")
        change_editor(page)
        page.get_by_label("Định lượng mới", exact=True).scroll_into_view_if_needed()
        snapshot(page, f"change-order-quantity-unit-{size}", results)
        opened(page, "Thực đơn")
        page.get_by_role("button", name="Đồng bộ Google Sheet", exact=True).click()
        expect(page.get_by_role("table", name="Thực đơn theo trường")).to_contain_text("Canh rau ngót")
        expect(page.get_by_role("button", name="Đồng bộ Google Sheet", exact=True)).to_be_enabled()
        reveal_menu_cell(page)
        snapshot(page, f"menu-valid-readback-{size}", results)
        close(page, failures)

        for scenario in ["missingRecipeUnit", "invalidMenuCell", "pendingValidMenu"]:
            page, failures = new_page(browser, url, width, height, scenario)
            if scenario == "missingRecipeUnit":
                opened(page, "Công thức")
                select(page, "recipes")
                page.get_by_label("Tìm nguyên liệu để thêm", exact=True).fill("Cà rốt")
                page.get_by_role("button", name="Thêm Cà rốt", exact=True).click()
                blocker = page.get_by_text("Nguyên liệu chưa có đơn vị mua đang dùng", exact=False)
                expect(blocker).to_be_visible()
                expect(page.get_by_role("button", name="Xem thay đổi", exact=True)).to_be_disabled()
                blocker.scroll_into_view_if_needed()
            else:
                opened(page, "Thực đơn")
                page.get_by_role("button", name="Đồng bộ Google Sheet", exact=True).click()
                expect(page.get_by_role("table", name="Thực đơn theo trường")).to_contain_text("Canh rau ngót")
                if scenario == "invalidMenuCell":
                    expect(page.get_by_text("1 ô cần xử lý trước khi lưu.", exact=True)).to_be_visible()
                    page.get_by_text("Xem ô cần kiểm tra", exact=True).click()
                    expect(active(page)).to_contain_text("Món chưa có trong danh mục")
                    expect(active(page)).to_contain_text("Thực đơn chính thức:Tuần 37:row:5:soup")
                    candidate_table = page.get_by_role("table", name="Thực đơn theo trường").element_handle()
                    opened(page, "Xác nhận nhu cầu")
                    opened(page, "Thực đơn")
                    assert candidate_table.evaluate("e=>e.isConnected && !e.closest('[hidden],[inert]')")
                    expect(active(page)).to_contain_text("Thực đơn chính thức:Tuần 37:row:5:soup")
                else:
                    expect(page.get_by_role("button", name="Đồng bộ Google Sheet", exact=True)).to_be_disabled()
                reveal_menu_cell(page)
            snapshot(page, f"{scenario}-{size}", results)
            close(page, failures)


def mark(control, key, value):
    control.fill(value)
    control.evaluate("(e,key)=>e.dataset.certification=key", key)
    return control.element_handle()


def pairs(browser, url, results, proofs):
    for width, height in [(1440, 900), (360, 800)]:
        for kind in ["recipe", "planning", "procurement", "master"]:
            print(f"pair {kind} {width}", flush=True)
            page, failures = new_page(browser, url, width, height)
            if kind == "recipe":
                names = ["Công thức", "Lệnh điều chỉnh"]
                opened(page, names[0]); select(page, "recipes")
                first = mark(page.get_by_label("Định lượng Bí đỏ", exact=True), "first", "2,25")
                opened(page, names[1])
                change_editor(page)
                second = mark(page.get_by_label("Lý do điều chỉnh", exact=True), "second", "Giữ lệnh riêng")
                values = ["2,25", "Giữ lệnh riêng"]
                dirty_names = names
            elif kind == "planning":
                names = ["Sĩ số", "Xác nhận nhu cầu"]
                opened(page, names[0])
                first = mark(page.get_by_label("Học sinh Trường Nguyễn Du", exact=True), "first", "123")
                opened(page, names[1])
                second = mark(page.get_by_label("Số lượng xác nhận Gạo thơm", exact=True), "second", "12,5")
                values = ["123", "12,5"]
                dirty_names = names
            elif kind == "procurement":
                names = ["Phân bổ NCC", "Đơn mua"]
                opened(page, names[0]); select(page, "procurement")
                first = mark(page.get_by_label("Ghi chú cho NCC An Phú", exact=True), "first", "Giao sớm")
                opened(page, names[1])
                second = mark(active(page).get_by_label("Tìm kiếm", exact=True), "second", "An Phú")
                if width < 1024:
                    page.get_by_role("button", name="Bộ lọc", exact=True).click()
                day = active(page).get_by_role("spinbutton", name="Day", exact=True)
                day.focus()
                day.press("ArrowUp")
                expect(day).to_have_attribute("aria-valuenow", "8")
                page.get_by_role("button", name=re.compile("^Mở lịch")).first.click()
                expect(page.get_by_role("application", name=re.compile("^Lịch"))).to_be_visible()
                values = ["Giao sớm", "An Phú"]
                dirty_names = [names[0]]
            else:
                names = ["Nguyên liệu", "Nhà cung ứng"]
                opened(page, names[0])
                page.get_by_label("Tìm nguyên liệu", exact=True).fill("Nguyên liệu thử")
                page.get_by_role("button", name="Tạo nguyên liệu", exact=True).click()
                first = mark(page.get_by_label("Tên nguyên liệu", exact=True), "first", "Nguyên liệu thử")
                opened(page, names[1])
                page.get_by_label("Tìm nhà cung ứng", exact=True).fill("Nhà cung ứng thử")
                page.get_by_role("button", name="Tạo nhà cung ứng", exact=True).click()
                second = mark(page.get_by_label("Tên nhà cung ứng", exact=True), "second", "Nhà cung ứng thử")
                values = ["Nguyên liệu thử", "Nhà cung ứng thử"]
                dirty_names = names
            for index, (name, handle, value) in enumerate(zip(names, [first, second], values)):
                assert first.evaluate("e=>e.isConnected") and second.evaluate("e=>e.isConnected")
                opened(page, name)
                assert handle.evaluate("e=>e===document.querySelector('[data-certification='+e.dataset.certification+']')")
                assert handle.input_value() == value
                assert not handle.evaluate("e=>!!e.closest('[hidden],[inert]')")
                expect(page.get_by_role("application", name=re.compile("^Lịch"))).to_have_count(0)
                if kind == "procurement" and index == 1:
                    expect(active(page).get_by_role("spinbutton", name="Day", exact=True)).to_have_attribute("aria-valuenow", "8")
                snapshot(page, f"retained-{kind}-{index}-{width}x{height}", results)
            page.get_by_role("button", name="Tài khoản và môi trường", exact=True).click()
            page.get_by_role("button", name="Đăng xuất", exact=True).click()
            for name in dirty_names:
                expect(page.get_by_role("button", name=f"{name} — Chưa lưu", exact=True)).to_be_visible()
            snapshot(page, f"signout-{kind}-{width}x{height}", results)
            for name in dirty_names:
                if width < 1024:
                    page.get_by_role("button", name=re.compile("^Đang mở:")).click()
                page.get_by_role("button", name=f"Đóng {name}", exact=True).click()
                dialog = page.get_by_role("dialog")
                expect(dialog.get_by_role("button", name="Tiếp tục chỉnh sửa", exact=True)).to_be_visible()
                expect(active(page)).to_have_attribute("aria-label", name)
                dialog.get_by_role("button", name="Tiếp tục chỉnh sửa", exact=True).click()
                expect(dialog).to_have_count(0)
            assert first.input_value() == values[0] and second.input_value() == values[1]
            proofs.append({"pair": kind, "width": width, "same_dom": True, "values": values,
                           "hidden_inert": True, "signout_dirty_owners": dirty_names,
                           "owner_close_cancel": True, "natural_dialog_exit": True})
            close(page, failures)


def discard(browser, url, proofs):
    for motion in ["no-preference", "reduce"]:
        page, failures = new_page(browser, url, 1440, 900, motion=motion)
        opened(page, "Công thức")
        page.get_by_role("button", name="Tạo món mới", exact=True).click()
        page.get_by_label("Tên món", exact=True).fill("Bỏ tên này")
        page.get_by_role("button", name="Đóng công thức", exact=True).click()
        page.get_by_role("dialog").get_by_role("button", name="Bỏ thay đổi", exact=True).click()
        expect(page.get_by_label("Tên món", exact=True)).to_have_count(0)
        expect(page.get_by_role("dialog")).to_have_count(0)
        proofs.append({"discard_motion": motion, "metadata_unmounted": True,
                       "dialog_closed_naturally": True, "synthetic_animation_event": False})
        close(page, failures)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:3000/atlas-vnext-review.html")
    parser.add_argument("--sizes", nargs="+")
    parser.add_argument("--part", choices=["all", "matrix", "pairs"], default="all")
    parser.add_argument("--keep-images", action="store_true", help="Reuse existing unchanged-UI PNGs while rerunning assertions and metadata")
    args = parser.parse_args()
    SAVE_IMAGES = not args.keep_images
    ROOT.mkdir(parents=True, exist_ok=True)
    results, proofs = [], []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        if args.part in ["all", "matrix"]:
            sizes = [tuple(map(int, size.split("x"))) for size in args.sizes] if args.sizes else SIZES
            matrix(browser, args.url, sizes, results)
            (ROOT / "browser-matrix.json").write_text(json.dumps({"browser": browser.version,
                "fixture_only": True, "hosted_requests": 0, "captures": results},
                ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if args.part in ["all", "pairs"]:
            pairs(browser, args.url, results, proofs)
            capacity(browser, args.url, ROOT, results, full_page=False, save_image=SAVE_IMAGES)
            discard(browser, args.url, proofs)
        report = {"browser": browser.version, "fixture_only": True, "hosted_requests": 0,
                  "captures": results, "proofs": proofs}
        (ROOT / f"browser-{args.part}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        browser.close()
    print(json.dumps({"captures": len(results), "proofs": len(proofs), "status": "PASS"}))
