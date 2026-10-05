"""Native Chromium date ownership regression, using the local Vite review App.

Start: pnpm exec vite
Run: python -X utf8 scripts/atlas_date_ownership_browser_test.py
Requires the existing system Python Playwright installation. No hosted writes.
This verifies the approved browser interaction gate only.
"""
import argparse
import json
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect


def launch(page, label):
    page.get_by_role("button", name="Bàn làm việc", exact=True).click()
    page.get_by_role("dialog", name="Bàn làm việc", exact=True).get_by_role(
        "button", name=label, exact=True
    ).click()
    filters = page.get_by_role("button", name="Bộ lọc", exact=True)
    if filters.count() and filters.is_visible() and filters.get_attribute("aria-expanded") != "true":
        filters.click()


def close_owner(page, label):
    close = page.get_by_role("button", name=f"Đóng {label}", exact=True)
    if not close.count():
        page.get_by_role("button", name=re.compile("^Đang mở:")).click()
        close = page.get_by_role("dialog", name="Bàn làm việc đang mở", exact=True).get_by_role("button", name=f"Đóng {label}", exact=True)
    close.click()


def assert_calendar_bounds(page):
    geometry = page.get_by_role("grid").evaluate("""grid => {
      const popup=grid.closest('[data-part=content]');
      const rect=popup.getBoundingClientRect();
      const focus=document.activeElement.getBoundingClientRect();
      const clipped=[];
      for(let ancestor=popup.parentElement;ancestor;ancestor=ancestor.parentElement){
        const style=getComputedStyle(ancestor),r=ancestor.getBoundingClientRect();
        if(['auto','scroll','hidden','clip'].includes(style.overflowX)&&(rect.left<r.left-1||rect.right>r.right+1)||['auto','scroll','hidden','clip'].includes(style.overflowY)&&(rect.top<r.top-1||rect.bottom>r.bottom+1))clipped.push(ancestor.id||ancestor.tagName);
      }
      return {popup:{left:rect.left,top:rect.top,right:rect.right,bottom:rect.bottom},focus:{left:focus.left,top:focus.top,right:focus.right,bottom:focus.bottom},clipped,width:innerWidth,height:innerHeight};
    }""")
    for rect in [geometry["popup"], geometry["focus"]]:
        assert rect["left"] >= -1 and rect["top"] >= -1 and rect["right"] <= geometry["width"]+1 and rect["bottom"] <= geometry["height"]+1, geometry
    assert not geometry["clipped"], geometry


def select_by_keyboard(page, label, key):
    trigger = page.get_by_role("button", name=f"Mở lịch — {label}", exact=True)
    if label == "Tuần phục vụ":
        page.get_by_role("textbox", name=label, exact=True).press("ArrowDown")
    else:
        trigger.click()
    grid = page.get_by_role("grid")
    expect(grid).to_be_visible()
    selected = grid.locator('[data-part="table-cell-trigger"][data-selected]').first
    expect(selected).to_be_focused()
    assert_calendar_bounds(page)
    selected.press(key)
    page.keyboard.press("Enter")
    expect(grid).to_have_count(0)
    if label == "Ngày phục vụ":
        expect(trigger).to_be_focused()
    else:
        expect(page.get_by_role("textbox", name=label, exact=True)).to_be_focused()



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:3000/atlas-vnext-review.html")
    parser.add_argument("--sizes", nargs="+", default=["1440x900", "650x900", "360x800"])
    parser.add_argument("--out", default="docs/testing/artifacts/atlas-persistent-workspace-03c/date-ownership.json")
    args = parser.parse_args()
    errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        results = []
        for size in args.sizes:
            width,height = map(int,size.split("x"))
            page = browser.new_page(viewport={"width": width, "height": height}, reduced_motion="reduce")
            page.on("pageerror", lambda error: errors.append({"message": str(error), "stack": error.stack}))
            page.goto(args.url)
            page.wait_for_load_state("networkidle")
            for label in ["Lập nhu cầu", "Kế hoạch mua hàng", "Phiếu xuất kho", "Đối chiếu PO / Phiếu xuất kho"]:
                launch(page, label)
            mounted_inputs = page.locator('[data-scope="date-picker"][data-part="root"]').count()
            assert mounted_inputs >= 4

            launch(page, "Kế hoạch mua hàng")
            day_segment = page.get_by_role("spinbutton").first.element_handle()
            initial_day = day_segment.inner_text()
            select_by_keyboard(page, "Ngày phục vụ", "ArrowRight")
            chosen_day = page.get_by_role("spinbutton").first.inner_text()
            assert chosen_day != initial_day
            launch(page, "Lập nhu cầu")
            expect(page.get_by_role("grid")).to_have_count(0)
            assert day_segment.get_attribute("aria-disabled") == "true"
            assert day_segment.evaluate("e=>{e.focus();return document.activeElement!==e}")
            day_segment.evaluate("e=>e.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowUp',bubbles:true}))")
            page.wait_for_timeout(3100)
            assert day_segment.inner_text() == chosen_day
            expect(page.get_by_role("grid")).to_have_count(0)

            launch(page, "Lập nhu cầu")
            week_field = page.get_by_role("textbox", name="Tuần phục vụ", exact=True)
            week_node = week_field.element_handle()
            initial_week = week_field.input_value()
            select_by_keyboard(page, "Tuần phục vụ", "ArrowDown")
            week_focus = page.evaluate("({tag:document.activeElement?.tagName,label:document.activeElement?.getAttribute('aria-label'),hidden:!!document.activeElement?.closest('[hidden],[inert]')})")
            assert not week_focus["hidden"]
            chosen_week = week_field.input_value()
            assert chosen_week != initial_week
            launch(page, "Đối chiếu PO / Phiếu xuất kho")
            ranges = page.get_by_role("spinbutton").all_text_contents()
            page.wait_for_timeout(3100)
            assert page.get_by_role("spinbutton").all_text_contents() == ranges
            expect(page.get_by_role("grid")).to_have_count(0)
            launch(page, "Lập nhu cầu")
            assert week_field.evaluate("(e, original)=>e===original", week_node)
            expect(week_field).to_have_value(chosen_week)

            launch(page, "Kế hoạch mua hàng")
            assert page.get_by_role("spinbutton").first.evaluate("(e, original)=>e===original", day_segment)
            expect(page.get_by_role("spinbutton").first).to_have_text(chosen_day)
            page.get_by_role("button", name="Mở lịch — Ngày phục vụ", exact=True).click()
            close_owner(page, "Lập nhu cầu")
            expect(page.locator('[role="tabpanel"][id$="-panel-planning"]')).to_have_count(0)
            launch(page, "Kế hoạch mua hàng")
            assert page.get_by_role("spinbutton").first.evaluate("(e, original)=>e===original", day_segment)
            expect(page.get_by_role("spinbutton").first).to_have_text(chosen_day)
            select_by_keyboard(page, "Ngày phục vụ", "ArrowRight")
            close_owner(page, "Kế hoạch mua hàng")
            expect(page.locator('[role="tabpanel"][id$="-panel-procurement"]')).to_have_count(0)
            remaining_dates = page.get_by_role("spinbutton").all_text_contents()
            page.wait_for_timeout(3100)
            assert page.get_by_role("spinbutton").all_text_contents() == remaining_dates
            expect(page.get_by_role("grid")).to_have_count(0)

            launch(page, "Phiếu xuất kho")
            trigger = page.get_by_role("button", name="Mở lịch — Ngày phục vụ", exact=True)
            trigger.click()
            expect(page.get_by_role("grid")).to_be_visible()
            page.keyboard.press("Escape")
            expect(page.get_by_role("grid")).to_have_count(0)
            expect(trigger).to_be_focused()
            trigger.click()
            page.get_by_role("button", name="Bàn làm việc", exact=True).click()
            expect(page.get_by_role("grid")).to_have_count(0)
            page.keyboard.press("Escape")
            assert not page.evaluate("!!document.activeElement?.closest('[hidden],[inert]')")
            assert not errors, errors
            result = {
                "result": "PASS", "browser": browser.version,
                "viewport": {"width": width, "height": height}, "actualTouch": False,
                "mountedDateControls": mounted_inputs,
                "dailyKeyboard": "ArrowRight / Enter, retained segment DOM identity and date",
                "weekKeyboard": "ArrowDown / Enter, retained field and canonical week",
                "weekSelectionFocus": week_focus,
                "delayedSwitch": "after 3100ms: dates retained, hidden input blocked, calendar stays dismissed",
                "delayedClose": "after 3100ms: remaining owner dates unchanged, calendar stays dismissed",
                "inactiveClose": "retained active date and segment identity; calendar reopens and selects correctly",
                "dismissal": "Escape returns trigger focus; outside pointer closes calendar",
                "calendarGeometry": "popup and focused cell within viewport and scroll clipping ancestors",
                "pageErrors": errors.copy(),
            }
            results.append(result)
            print(json.dumps(result, ensure_ascii=False), flush=True)
            page.close()
        output = Path(args.out)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps({"result":"PASS","results":results}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        browser.close()


if __name__ == "__main__":
    main()
