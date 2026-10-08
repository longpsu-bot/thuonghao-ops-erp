"""Local production-composition fixture check; no hosted calls.
Start Vite on port 5188, then run this script. Screenshots replace PR #358 evidence.
"""
import json
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

OUT = Path('docs/testing/ux/atlas-tab-borders')
SIZES = [(1920,1080),(1440,900),(1366,768),(650,900),(360,800)]
JOBS = ['Thực đơn','Sĩ số','Hàng đặt riêng','Xác nhận nhu cầu','Phân bổ NCC','Đơn mua','Phiếu xuất kho','Đối chiếu PO / Phiếu xuất kho','Trường học','Nguyên liệu','Nhà cung ứng','Công thức','Lệnh điều chỉnh']


def launch(page, label):
    page.get_by_role('button', name='Bàn làm việc', exact=True).click()
    page.get_by_role('dialog', name='Bàn làm việc', exact=True).get_by_role('button', name=label, exact=True).click()
    expect(page.locator('main>[role=tabpanel]:not([hidden])')).to_have_attribute('aria-label', label)


def owner(page, label):
    return page.locator(f'main>[role=tabpanel][aria-label="{label}"]')


results=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    for width,height in SIZES:
        page=browser.new_page(viewport={'width':width,'height':height}, reduced_motion='reduce')
        errors=[]
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.goto('http://127.0.0.1:5188/atlas-vnext-review.html')
        page.wait_for_load_state('networkidle')
        page.get_by_role('button',name='Bàn làm việc',exact=True).click()
        dialog=page.get_by_role('dialog',name='Bàn làm việc',exact=True)
        assert dialog.get_by_role('button').evaluate_all('es=>es.map(e=>e.getAttribute("aria-label"))') == JOBS
        if width==1440: page.screenshot(path=str(OUT/'launcher-1440x900.png'))
        page.keyboard.press('Escape')
        for job in JOBS: launch(page,job)
        expect(page.locator('main>[role=tabpanel]')).to_have_count(13)
        for job in JOBS[:3]:
            expect(owner(page,job).locator('[data-tab-tier=secondary]')).to_have_count(0)
        launch(page,'Sĩ số')
        attendance=page.get_by_role('textbox',name='Học sinh Trường Nguyễn Du',exact=True,include_hidden=True)
        attendance.fill('123')
        launch(page,'Hàng đặt riêng')
        page.get_by_role('combobox',name='Trường thêm dòng',exact=True).select_option('school-1')
        page.get_by_role('button',name='+ Thêm dòng',exact=True).click()
        pantry=page.get_by_role('textbox',name='Số lượng dòng 1',exact=True,include_hidden=True)
        pantry.fill('3,5')
        launch(page,'Thực đơn')
        expect(owner(page,'Sĩ số')).to_have_attribute('hidden','')
        expect(owner(page,'Sĩ số')).to_have_attribute('inert','')
        expect(attendance).to_have_value('123')
        expect(pantry).to_have_value('3,5')
        if width>=1024:
            strip=page.get_by_role('tablist',name='Bàn làm việc đang mở',exact=True)
            tabs=strip.get_by_role('tab')
            expect(tabs).to_have_count(13)
            strip.get_by_role('tab',selected=True).focus()
            page.keyboard.press('End')
            expect(tabs.last).to_be_focused()
            page.keyboard.press('Home')
            expect(tabs.first).to_be_focused()
            launch(page,'Thực đơn')
        else:
            trigger=page.get_by_role('button',name='Đang mở: Thực đơn',exact=True)
            assert trigger.bounding_box()['height']>=44
            trigger.click()
            selector=page.get_by_role('dialog',name='Bàn làm việc đang mở',exact=True)
            expect(selector.get_by_role('button')).to_have_count(26)
            selector.get_by_role('button',name='Thực đơn',exact=True).click()
        launch(page,'Sĩ số')
        expect(page.get_by_role('textbox',name='Học sinh Trường Nguyễn Du',exact=True)).to_have_value('123')
        if width<1024: page.get_by_role('button',name=re.compile('^Đang mở: Sĩ số')).click()
        page.get_by_role('button',name='Đóng Sĩ số',exact=True).click()
        guard=page.get_by_role('dialog')
        guard.get_by_role('button',name='Tiếp tục chỉnh sửa',exact=True).click()
        expect(guard).to_have_count(0)
        expect(attendance).to_have_value('123')
        launch(page,'Thực đơn')
        assert not page.evaluate('document.documentElement.scrollWidth>innerWidth')
        assert not page.evaluate('!!document.activeElement?.closest("[hidden],[inert]")')
        assert page.locator('main>[role=tabpanel][hidden]').evaluate_all('es=>es.every(e=>e.inert)')
        assert not errors, errors
        page.screenshot(path=str(OUT/f'planning-{width}x{height}.png'))
        results.append({'viewport':f'{width}x{height}','workbench_count':13,'independent_drafts':'PASS','close_cancel':'PASS','navigation':'PASS','source_subtabs':0,'document_overflow':False,'page_errors':errors})
        page.close()
    browser.close()
(OUT/'browser-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(results,ensure_ascii=False))
