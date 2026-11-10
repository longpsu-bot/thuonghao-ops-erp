import argparse
import json
import re
from pathlib import Path

from playwright.sync_api import sync_playwright, expect


def main():
    parser = argparse.ArgumentParser(description="Verify four local Atlas hierarchy surfaces.")
    parser.add_argument("--output", required=True)
    parser.add_argument("--desktop", action="store_true", help="Review desktop first at 1920, 1440 and 1366px.")
    args = parser.parse_args()
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    url = "http://127.0.0.1:5175/atlas-vnext-review.html"
    records, checks, page_errors, external = [], [], [], []

    def check(name, passed, detail=None):
        checks.append({"name": name, "pass": bool(passed), "detail": detail})

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        viewports = [(1920, 1080), (1440, 900), (1366, 768)] if args.desktop else [(1366, 768), (390, 844), (360, 800)]
        for width, height in viewports:
            context = browser.new_context(viewport={"width": width, "height": height}, device_scale_factor=1)

            def local_only(route):
                if route.request.url.startswith(("http://127.0.0.1:5175/", "data:", "blob:")):
                    route.continue_()
                else:
                    external.append(route.request.url)
                    route.abort()

            context.route("**/*", local_only)
            page = context.new_page()
            page.on("pageerror", lambda error: page_errors.append(str(error)))

            def open_owner(label):
                page.goto(url, wait_until="networkidle")
                page.evaluate("document.fonts.ready")
                page.get_by_role("button", name="Chức năng", exact=True).click()
                drawer = page.get_by_role("dialog", name="Chức năng", exact=True)
                drawer.get_by_role("button", name=label, exact=True).click()
                drawer.wait_for(state="hidden")
                page.get_by_role("tabpanel", name=label, exact=True).wait_for(state="visible")

            def capture(slug, label, extra=None):
                page.evaluate("() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))")
                target = out / f"{slug}-{width}.png"
                assert not target.exists(), f"Artifact collision: {target}"
                page.screenshot(path=str(target), animations="disabled")
                record = {"surface": slug, "owner": label, "viewport": [width, height], "screenshot": target.name, **page.evaluate("""() => ({documentSize:[document.documentElement.scrollWidth,document.documentElement.scrollHeight],documentY:scrollY})""")}
                if extra:
                    record.update(extra)
                records.append(record)
                check(f"{slug}-{width}: document fits", record["documentSize"] == [width, height], record["documentSize"])
                (out / "browser-checks.partial.json").write_text(json.dumps({"records": records, "checks": checks, "pageErrors": page_errors, "blockedExternalRequests": external}, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"captured {slug} {width}", flush=True)

            open_owner("Xác nhận nhu cầu")
            table = page.get_by_role("table", name="Nhu cầu xác nhận", exact=True)
            row = table.locator("tbody tr").first
            quantity = row.get_by_role("textbox", name=re.compile("^Số lượng xác nhận"))
            quantity.wait_for(state="visible")
            box = quantity.bounding_box()
            region = page.get_by_role("region", name="Bảng xác nhận nhu cầu", exact=True)
            region_box = region.bounding_box()
            geometry = region.evaluate("e => ({client:e.clientWidth,scroll:e.scrollWidth,left:e.scrollLeft})")
            borders = row.evaluate("""e => ({record:getComputedStyle(e).borderBottomWidth,identity:getComputedStyle(e.querySelector('[data-field=ingredient]')).borderBottomWidth,reason:getComputedStyle(e.querySelector('[data-field=reason]')).borderTopWidth})""")
            if width < 768:
                check(f"need-{width}: quantity in first view", 0 <= box["x"] and box["x"] + box["width"] <= width and region_box["y"] <= box["y"] and box["y"] + box["height"] <= min(height, region_box["y"] + region_box["height"]), {"input": box, "region": region_box})
                check(f"need-{width}: no quantity panning", geometry["scroll"] <= geometry["client"] + 1 and geometry["left"] == 0, geometry)
                check(f"need-{width}: record/group separator lines", all(v == "1px" for v in borders.values()), borders)
                check(f"need-{width}: input unoccluded at all edges", quantity.evaluate("""e => {const r=e.getBoundingClientRect();const x=(r.left+r.right)/2,y=(r.top+r.bottom)/2;return [[r.left+2,y],[r.right-2,y],[x,r.top+2],[x,r.bottom-2]].every(([x,y])=>{const hit=document.elementFromPoint(x,y);return hit===e||e.contains(hit);});}"""))
            desktop_need = table.evaluate("""e => {const r=e.getBoundingClientRect();const rows=[...e.querySelectorAll('tbody tr')];const bottom=e.parentElement.getBoundingClientRect().bottom;return {firstRowHeight:rows[0].getBoundingClientRect().height,fullyVisibleRows:rows.filter(row=>row.getBoundingClientRect().bottom<=bottom+1).length,columnWidths:[...e.querySelectorAll('thead th')].map(c=>c.getBoundingClientRect().width)};}""") if width >= 1366 else None
            if width >= 1366:
                check(f"need-{width}: five comparable rows visible", desktop_need["fullyVisibleRows"] >= 5, desktop_need)
                check(f"need-{width}: six columns without panning", len(desktop_need["columnWidths"]) == 6 and geometry["scroll"] <= geometry["client"] + 1, geometry)
                check(f"need-{width}: compact rows and readable input", desktop_need["firstRowHeight"] <= 64 and box["height"] >= 40, {"row": desktop_need["firstRowHeight"], "input": box})
            capture("need", "Xác nhận nhu cầu", {"quantity": box, "tableViewport": geometry, "separators": borders, "desktop": desktop_need})
            line_id = row.get_attribute("data-confirmed-need-line-id")
            quantity.fill("12,5")
            row.get_by_role("combobox", name=re.compile("^Lý do ")).select_option("OTHER")
            row.get_by_role("textbox", name=re.compile("^Ghi chú ")).fill("Kiểm tra bố cục và giữ bản nháp")
            page.get_by_role("button", name="Sắp xếp theo Nguyên liệu", exact=True).click()
            retained = table.locator(f'[data-confirmed-need-line-id="{line_id}"]')
            expect(retained.get_by_role("textbox", name=re.compile("^Số lượng xác nhận"))).to_have_value("12,5")
            expect(retained.get_by_role("textbox", name=re.compile("^Ghi chú "))).to_have_value("Kiểm tra bố cục và giữ bản nháp")
            check(f"need-{width}: sort preserves one exact draft input", retained.get_by_role("textbox", name=re.compile("^Số lượng xác nhận")).count() == 1)
            retained.get_by_role("textbox", name=re.compile("^Số lượng xác nhận")).fill("10,123")
            expect(retained.get_by_role("textbox", name=re.compile("^Số lượng xác nhận"))).to_have_attribute("aria-invalid", "true")
            expect(page.get_by_role("button", name="Lưu", exact=True)).to_be_disabled()
            expect(page.get_by_role("button", name="Tiếp tục phân bổ NCC", exact=True)).to_be_disabled()
            check(f"need-{width}: invalid quantity keeps Save/Continue locked", True)
            if width == 390:
                capture("need-invalid", "Xác nhận nhu cầu")

            open_owner("Sĩ số")
            file = page.get_by_label("Nhập sĩ số XLSX", exact=True)
            template = page.get_by_role("button", name="Tải mẫu sĩ số XLSX", exact=True)
            helper = page.locator("#atlas-attendance-xlsx-help")
            paste = page.get_by_role("button", name="Dán hàng loạt", exact=True)
            file_box, button_box, helper_box = file.bounding_box(), template.bounding_box(), helper.bounding_box()
            check(f"attendance-{width}: aligned import tools", abs(file_box["y"] - button_box["y"]) < 2 if width >= 1024 else button_box["y"] >= helper_box["y"] + helper_box["height"], {"file": file_box, "template": button_box, "helper": helper_box})
            attendance_lines = file.evaluate("e => ({import:getComputedStyle(e.parentElement.parentElement).borderBottomWidth,totals:getComputedStyle(e.parentElement.parentElement.previousElementSibling).borderBottomWidth})")
            check(f"attendance-{width}: import/data separators", all(v == "1px" for v in attendance_lines.values()), attendance_lines)
            if width >= 1366:
                attendance_table = page.get_by_role("table", name="Sĩ số theo trường", exact=True)
                check(f"attendance-{width}: table leads in first view", attendance_table.bounding_box()["y"] <= 420, attendance_table.bounding_box())
                check(f"attendance-{width}: helper stays on one line", helper_box["height"] < 28, helper_box)
                count_box = attendance_table.get_by_role("textbox", name="Học sinh Trường Nguyễn Du", exact=True).bounding_box()
                check(f"attendance-{width}: quantity input stays bounded", 76 <= count_box["width"] <= 140 and count_box["height"] >= 40, count_box)
            capture("attendance", "Sĩ số", {"separators": attendance_lines})
            paste.click()
            expect(page.get_by_role("textbox", name="Dữ liệu dán", exact=True)).to_be_visible()
            check(f"attendance-{width}: paste remains reachable", True)
            if args.desktop:
                paste.click()
                page.get_by_role("textbox", name="Học sinh Trường Nguyễn Du", exact=True).fill("101")
                page.get_by_role("button", name="Xem thay đổi", exact=True).click()
                review = page.get_by_role("complementary", name="Xem thay đổi", exact=True)
                expect(review).to_be_focused()
                editor_box = file.evaluate("""e => {const grid=e.closest('[data-testid=planning-source-editor-review]');const column=[...grid.children].find(c=>c.contains(e));const r=column.getBoundingClientRect();return {x:r.x,width:r.width};}""")
                import_boxes = [control.bounding_box() for control in [file, template, paste]]
                check(f"attendance-review-{width}: controls stay in editor column", all(b["x"] >= editor_box["x"] and b["x"] + b["width"] <= editor_box["x"] + editor_box["width"] + 1 for b in import_boxes), {"editor": editor_box, "controls": import_boxes})
                title_box = page.get_by_role("heading", name="Sĩ số", exact=True).bounding_box()
                check(f"attendance-review-{width}: context stays visible", title_box["y"] >= 100, title_box)
                capture("attendance-review", "Sĩ số")
                review.get_by_role("button", name="Đóng", exact=True).click()
                expect(page.get_by_role("button", name="Xem thay đổi", exact=True)).to_be_focused()
                check(f"attendance-review-{width}: Close returns focus", True)

            open_owner("Hàng đặt riêng")
            expect(page.get_by_role("heading", name="Thêm hàng đặt riêng", exact=True)).to_be_visible()
            school = page.get_by_role("combobox", name="Trường cần thêm hàng", exact=True)
            associated = school.evaluate("e => !!document.querySelector('label[for=\"' + CSS.escape(e.id) + '\"]')")
            check(f"pantry-{width}: persistent School label", associated)
            expect(page.get_by_role("table", name="Hàng đặt riêng", exact=True)).to_be_attached()
            add = page.get_by_role("button", name="+ Thêm dòng", exact=True)
            expect(add).to_be_disabled()
            pantry_border = page.get_by_role("heading", name="Thêm hàng đặt riêng", exact=True).evaluate("e => getComputedStyle(e.parentElement).borderBottomWidth")
            check(f"pantry-{width}: add/data separator", pantry_border == "1px", pantry_border)
            if width >= 1366:
                source_box = page.get_by_role("combobox", name="Nguồn của dòng mới", exact=True).bounding_box()
                school_box, add_box = school.bounding_box(), add.bounding_box()
                heading_box = page.get_by_role("heading", name="Thêm hàng đặt riêng", exact=True).bounding_box()
                check(f"pantry-{width}: one aligned desktop add group", max(b["y"] for b in [source_box, school_box, add_box]) - min(b["y"] for b in [source_box, school_box, add_box]) < 2 and heading_box["x"] < school_box["x"], [heading_box, school_box, source_box, add_box])
                check(f"pantry-{width}: School input has readable measure", school_box["width"] >= 300, school_box)
            capture("pantry", "Hàng đặt riêng", {"separator": pantry_border})
            school.click()
            options = page.get_by_role("listbox", name="Trường cần thêm hàng", exact=True).get_by_role("option")
            options.first.click()
            expect(add).to_be_enabled()
            add.click()
            expect(page.get_by_role("textbox", name="Số lượng dòng 1", exact=True)).to_be_visible()
            check(f"pantry-{width}: explicit eligible Add works", True)
            if width == 390 or args.desktop:
                capture("pantry-added", "Hàng đặt riêng")
            if args.desktop:
                page.get_by_role("combobox", name="Nguyên liệu dòng 1", exact=True).fill("gao")
                page.get_by_role("option", name=re.compile("Gạo thơm")).first.click()
                page.get_by_role("textbox", name="Số lượng dòng 1", exact=True).fill("5")
                page.get_by_role("button", name="Xem thay đổi", exact=True).click()
                review = page.get_by_role("complementary", name="Xem thay đổi", exact=True)
                expect(review).to_be_focused()
                editor_box = school.evaluate("""e => {const grid=e.closest('[data-testid=planning-source-editor-review]');const column=[...grid.children].find(c=>c.contains(e));const r=column.getBoundingClientRect();return {x:r.x,width:r.width};}""")
                add_boxes = [control.bounding_box() for control in [school, add, page.get_by_role("combobox", name="Nguồn của dòng mới", exact=True)]]
                check(f"pantry-review-{width}: add group stays in editor column", all(b["x"] >= editor_box["x"] and b["x"] + b["width"] <= editor_box["x"] + editor_box["width"] + 1 for b in add_boxes), {"editor": editor_box, "controls": add_boxes})
                capture("pantry-review", "Hàng đặt riêng")

            open_owner("Công thức")
            page.get_by_role("button", name="Sửa công thức Canh bí đỏ thịt bằm", exact=True).click()
            page.get_by_role("heading", name="Công thức gốc", exact=True).wait_for(state="visible")
            edit = page.get_by_role("button", name="Sửa thông tin món", exact=True)
            copy = page.get_by_role("button", name="Sao chép công thức", exact=True)
            edit_box, copy_box = edit.bounding_box(), copy.bounding_box()
            recipe_border = edit.evaluate("e => Math.max(parseFloat(getComputedStyle(e.parentElement).borderBottomWidth),parseFloat(getComputedStyle(e.closest('[data-role=recipe-controls]')).borderBottomWidth)) + 'px'")
            check(f"recipe-{width}: utility/context separator", recipe_border == "1px", recipe_border)
            if width >= 1366:
                scope_box = page.get_by_role("combobox", name="Loại công thức", exact=True).bounding_box()
                base_table = page.get_by_role("table", name="Công thức gốc", exact=True)
                basis_box = page.get_by_label("Số suất áp dụng cho định lượng", exact=True).bounding_box()
                ingredient_box = base_table.get_by_role("textbox", name="Định lượng Bí đỏ", exact=True).bounding_box()
                check(f"recipe-{width}: utilities align with context", all(abs(b["y"] - scope_box["y"]) < 2 and b["height"] >= 40 for b in [edit_box, copy_box]), [edit_box, copy_box, scope_box])
                check(f"recipe-{width}: basis is compact and table leads", basis_box["y"] < 440 and base_table.bounding_box()["y"] < 480, {"basis": basis_box, "table": base_table.bounding_box()})
                check(f"recipe-{width}: first ingredient quantity visible", ingredient_box["y"] + ingredient_box["height"] < height - 64, ingredient_box)
            if width < 768:
                check(f"recipe-{width}: utility targets fit", all(b["height"] >= 44 and b["x"] >= 0 and b["x"] + b["width"] <= width for b in (edit_box, copy_box)), [edit_box, copy_box])
                same_row = abs(edit_box["y"] - copy_box["y"]) < 2
                check(f"recipe-{width}: utilities aligned", abs(edit_box["width"] - copy_box["width"]) < 2, [edit_box, copy_box])
                if width == 390:
                    check("recipe-390: peers share row", same_row, [edit_box, copy_box])
            capture("recipe", "Công thức", {"utilities": [edit_box, copy_box], "separator": recipe_border})
            page.get_by_role("button", name="Đóng công thức", exact=True).click()
            expect(page.get_by_role("button", name="Sửa công thức Canh bí đỏ thịt bằm", exact=True)).to_be_focused()
            check(f"recipe-{width}: Close returns focus", True)
            context.close()
        version = browser.version
        browser.close()
    check("no page errors", not page_errors, page_errors)
    check("no external requests", not external, external)
    result = {"browser": version, "records": records, "checks": checks, "pageErrors": page_errors, "blockedExternalRequests": external}
    (out / "browser-checks.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    failures = [c for c in checks if not c["pass"]]
    print(json.dumps({"captures": len(records), "checks": len(checks), "failures": failures}, ensure_ascii=True), flush=True)
    assert not failures, failures


if __name__ == "__main__":
    main()
