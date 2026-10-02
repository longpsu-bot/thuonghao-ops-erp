import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
out=Path("docs/testing/artifacts/reconciliation-attention-01")
out.mkdir(parents=True,exist_ok=True)
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    for width,height in [(1280,800),(390,844)]:
        for case,scenario,mode in [("clean-mismatch","ALL","exceptions"),("blocked-ok","OPERATIONAL_BLOCKER","exceptions"),("replacement-ok","REPLACEMENT_REQUIRED_OK","exceptions"),("all","ATTENTION_MIXED","all"),("warning-only","WARNING_ONLY_OK","exceptions")]:
            page=browser.new_page(viewport={"width":width,"height":height},locale="vi-VN",reduced_motion="reduce")
            errors=[]; external=[]
            page.on("pageerror",lambda error: errors.append(str(error)))
            page.on("request",lambda request: external.append(request.url) if not request.url.startswith("http://127.0.0.1:3011/") else None)
            page.goto("http://127.0.0.1:3011/docs/testing/artifacts/reconciliation-attention-01/index.html?scenario="+scenario)
            page.wait_for_load_state("networkidle")
            table=page.get_by_role("table",name="Đối chiếu theo trường",exact=True)
            status=page.get_by_role("combobox",name="Tình trạng")
            status.select_option(mode)
            rows=table.get_by_role("row"); text=table.inner_text()
            if case=="clean-mismatch":
                assert "Trường Mầm non Hoa Sen" not in text and "Lệch số lượng" in text
            elif case=="blocked-ok":
                assert "Khớp" in text and "Đang bị chặn" in text and rows.count()==2
            elif case=="replacement-ok":
                assert "Khớp" in text and "Cần phiếu thay thế" in text and rows.count()==2
            elif case=="all":
                assert rows.count()==5
                assert "Trường Mầm non Hoa Sen" in rows.last.inner_text()
                expect(page.get_by_text("Cần xử lý 3 · Khớp 3",exact=True)).to_be_visible()
            elif case=="warning-only":
                assert rows.count()==1
                status.select_option("all")
                assert "Khớp" in table.inner_text()
            name=f"{case}-{width}"
            page.screenshot(path=str(out/(name+".png")),full_page=True)
            geometry=page.evaluate("""() => ({viewport:innerWidth,document:document.documentElement.scrollWidth,body:document.body.scrollWidth,table:{width:document.querySelector('table').getBoundingClientRect().width,scroll:document.querySelector('table').parentElement.scrollWidth,client:document.querySelector('table').parentElement.clientWidth},cells:[...document.querySelectorAll('tbody td')].map(e=>({text:e.innerText,width:e.clientWidth,scroll:e.scrollWidth,height:e.clientHeight,scrollHeight:e.scrollHeight}))})""")
            assert geometry["document"]<=width and geometry["body"]<=width
            assert all(c["scroll"]<=c["width"]+1 and c["scrollHeight"]<=c["height"]+1 for c in geometry["cells"])
            if case in ["blocked-ok","replacement-ok","all"]:
                cell=rows.nth(1).get_by_role("cell").nth(2)
                cell.scroll_into_view_if_needed()
                page.screenshot(path=str(out/(name+"-reason.png")),full_page=True)
                expect(cell).to_be_visible()
            action=table.get_by_role("button",name="Xem đối chiếu").first
            action.scroll_into_view_if_needed()
            action.focus(); action.press("Enter")
            detail=page.get_by_role("region",name="Chi tiết đối chiếu")
            expect(detail).to_be_focused()
            detail.scroll_into_view_if_needed()
            assert "SOURCE_WARNING" not in detail.inner_text()
            if case=="warning-only": expect(detail.get_by_text("Lưu ý vận hành",exact=True)).to_be_visible()
            page.screenshot(path=str(out/(name+"-detail.png")),full_page=True)
            detail.get_by_role("button",name="Đóng chi tiết").click()
            expect(action).to_be_focused()
            page.screenshot(path=str(out/(name+"-action.png")),full_page=True)
            if case in ["blocked-ok","replacement-ok"]:
                status.select_option("OK")
                assert table.get_by_role("button",name="Xem đối chiếu").count()==1
                action.focus(); action.press("Enter")
                expect(detail).to_be_focused()
                status.focus(); status.select_option("MISMATCH")
                expect(detail).to_have_count(0)
                expect(status).to_be_focused()
            page.get_by_role("textbox",name="Tìm kiếm").fill("khong ton tai")
            expect(detail).to_have_count(0)
            assert page.evaluate("window.fixtureReads")==1
            assert not errors and not external
            results.append({"case":case,"viewport":{"width":width,"height":height},"geometry":geometry,"tableText":text,"reads":1,"keyboardDetailFocus":True,"closeFocusReturn":True,"hiddenDetailFilterFocus":case in ["blocked-ok","replacement-ok"],"errors":errors,"externalRequests":external})
            page.close()
    (out/"browser-results.json").write_text(json.dumps({"browser":browser.version,"results":results},ensure_ascii=False,indent=2),encoding="utf-8")
    browser.close()
print("PASS: 10 viewport/state runs; attention, geometry, keyboard/focus, one fixture read, zero external requests")
