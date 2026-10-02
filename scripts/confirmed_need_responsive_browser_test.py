"""Local production-component fixture review; never connects to hosted APIs."""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:3017')
parser.add_argument('--phase', choices=['before', 'css-only', 'after'], required=True)
args = parser.parse_args()
root = Path('docs/testing/artifacts/confirmed-need-responsive-editing-01') / args.phase
root.mkdir(parents=True, exist_ok=True)
GEOMETRY = """() => {
 const v=document.querySelector('[aria-label="Bảng xác nhận nhu cầu"]');
 const row=document.querySelector('[data-confirmed-need-line]');
 const rect=e=>{if(!e)return null; const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,position:s.position,insetLeft:s.left,zIndex:s.zIndex};};
 const q=row.querySelector('input'), i=row.querySelector('[data-field="identity"]');
 const overlap=(a,b)=>a&&b&&Math.min(a.right,b.right)>Math.max(a.left,b.left)&&Math.min(a.bottom,b.bottom)>Math.max(a.top,b.top);
 return {viewport:{...rect(v),clientWidth:v.clientWidth,scrollWidth:v.scrollWidth,scrollLeft:v.scrollLeft,scrollTop:v.scrollTop}, identity:rect(i),header:rect(document.querySelector('thead th')),headerRow:rect(document.querySelector('thead tr')),quantity:rect(q),reason:rect(row.querySelector('select')),note:rect(row.querySelector('[data-field="reason"] input')),identityOverlapsQuantity:overlap(rect(i),rect(q)),identityOverlapsReason:overlap(rect(i),rect(row.querySelector('select'))),pageWidth:document.documentElement.clientWidth,pageScrollWidth:document.documentElement.scrollWidth,active:document.activeElement.getAttribute('aria-label'),value:q.value,save:rect([...document.querySelectorAll('button')].find(b=>b.textContent.trim()==='Lưu'))};
}"""
results, failures, errors, blocked, smoke = [], [], [], [], []

def check(ok, message):
    if not ok:
        failures.append(message)

def record(page, size, state):
    g=page.evaluate(GEOMETRY)
    results.append({'size':size,'state':state,**g})
    page.screenshot(path=str(root / f'{size}-{state}.png'), full_page=True)
    check(g['pageScrollWidth']<=g['pageWidth']+1, f'{size}/{state}: body overflow')
    return g

def fits(g, field):
    r=g[field];v=g['viewport']
    return r and r['left']>=v['left']-1 and r['right']<=v['right']+1

with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    browser_version=browser.version
    for width,height,dpr in [(1440,900,1),(1366,768,1),(1280,800,1),(1024,768,1),(768,1024,1),(390,844,1),(360,800,1),(720,450,2)]:
        size=f'{width}x{height}'+('-reflow200' if dpr==2 else '')
        page=browser.new_page(viewport={'width':width,'height':height},device_scale_factor=dpr,locale='vi-VN',reduced_motion='reduce')
        page.on('pageerror', lambda e: errors.append(str(e)))
        def route(r):
            if r.request.url.startswith(args.url) or r.request.url.startswith('data:'):
                r.continue_()
            else:
                blocked.append(r.request.url)
                r.abort()
        page.route('**/*',route)
        page.goto(args.url)
        page.wait_for_load_state('networkidle')
        q=page.get_by_role('textbox',name='Số lượng xác nhận Gạo thơm',exact=True)
        q.wait_for()
        g=record(page,size,'normal')
        check(g['identity']['position']==('sticky' if width>=1280 else 'static'), f'{size}: identity position')
        check(g['header']['position']==('sticky' if width>=1280 else 'static'), f'{size}: identity header position')
        check(g['headerRow']['position']=='sticky',f'{size}: vertical sticky header')
        if width>=1280:
            check(g['identity']['insetLeft'] in ['0px','0'],f'{size}: desktop left inset')
        # Native focus first, with no injected scrollIntoView or production reveal.
        q.focus()
        page.wait_for_timeout(100)
        g=record(page,size,'quantity-focus')
        check(fits(g,'quantity') and not g['identityOverlapsQuantity'],f'{size}: native focus quantity visibility')
        q.fill('12,5')
        page.wait_for_timeout(100)
        g=record(page,size,'dirty-quantity')
        check(g['value']=='12,5', f'{size}: exact draft')
        check(fits(g,'quantity') and not g['identityOverlapsQuantity'],f'{size}: dirty quantity visibility')
        reason=page.get_by_role('combobox',name='Lý do Gạo thơm',exact=True)
        reason.focus()
        page.wait_for_timeout(100)
        g=record(page,size,'reason-focus')
        check(fits(g,'reason') and not g['identityOverlapsReason'],f'{size}: native focus reason visibility')
        reason.select_option('OTHER')
        note=page.get_by_role('textbox',name='Ghi chú Gạo thơm',exact=True)
        note.focus()
        note.fill('Bếp yêu cầu')
        save=page.get_by_role('button',name='Lưu',exact=True)
        expect(save).to_be_enabled()
        g=record(page,size,'note-edit')
        check(fits(g,'note'),f'{size}: note visibility')
        check(save.is_enabled(), f'{size}: valid Save')
        save.scroll_into_view_if_needed()
        g=record(page,size,'dirty-save')
        check(g['save']['top']>=-1 and g['save']['bottom']<=height+1,f'{size}: reachable Save')
        # Keyboard from quantity to reason/note, relying on native Tab reveal.
        q.focus()
        page.keyboard.press('Tab')
        check(reason.evaluate('(e)=>e===document.activeElement'), f'{size}: Tab quantity to reason')
        g=page.evaluate(GEOMETRY)
        check(fits(g,'reason') and not g['identityOverlapsReason'], f'{size}: keyboard reason reveal')
        page.keyboard.press('Tab')
        check(note.evaluate('(e)=>e===document.activeElement'), f'{size}: Tab reason to note')
        q.focus()
        page.keyboard.press('Control+a')
        page.keyboard.insert_text('10,123')
        g=record(page,size,'invalid')
        check(q.get_attribute('aria-invalid')=='true',f'{size}: validation error')
        description=q.get_attribute('aria-describedby')
        check(bool(description) and page.locator(f'[id="{description}"]').count()==1,f'{size}: error association')
        check(fits(g,'quantity') and not g['identityOverlapsQuantity'],f'{size}: invalid quantity reveal')
        # Scroll locally in both axes; header remains sticky vertically.
        page.get_by_role('region',name='Bảng xác nhận nhu cầu',exact=True).evaluate('(e)=>{e.scrollLeft=400;e.scrollTop=30}')
        g=record(page,size,'local-scroll')
        if width<1280:
            check(abs(g['identity']['left']-(g['viewport']['left']-g['viewport']['scrollLeft']))<=1,f'{size}: identity moves with local scroll')
        check(abs(g['headerRow']['top']-g['viewport']['top'])<=1,f'{size}: vertical header retained after scroll')
        page.close()
    for width,height in [(1366,768),(390,844)]:
        page=browser.new_page(viewport={'width':width,'height':height},reduced_motion='reduce')
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.route('**/*',route)
        page.goto(args.url)
        q=page.get_by_role('textbox',name='Số lượng xác nhận Gạo thơm',exact=True)
        q.wait_for()
        q.focus()
        page.keyboard.press('Control+a')
        page.keyboard.insert_text('12,5')
        page.keyboard.press('Tab')
        page.keyboard.press('o')
        page.get_by_role('combobox',name='Lý do Gạo thơm',exact=True).select_option('OTHER')
        note=page.get_by_role('textbox',name='Ghi chú Gạo thơm',exact=True)
        note.fill('Bếp yêu cầu')
        expect(page.get_by_role('button',name='Lưu',exact=True)).to_be_enabled()
        page.get_by_role('region',name='Bảng xác nhận nhu cầu',exact=True).evaluate('(e)=>e.scrollLeft=400')
        page.get_by_role('button',name='Sắp xếp theo Nguyên liệu / nơi nhận',exact=True).click()
        page.get_by_role('button',name='Sắp xếp theo Đề xuất vận hành',exact=True).click()
        check(q.input_value()=='12,5',f'{width}: sorting draft preserved')
        search=page.get_by_role('textbox',name='Tìm kiếm',exact=True)
        search.fill('thit')
        expect(page.get_by_text('Có 1 thay đổi chưa lưu ngoài bộ lọc hiện tại.',exact=True)).to_be_visible()
        search.fill('')
        check(q.input_value()=='12,5',f'{width}: filtering draft preserved')
        page.get_by_role('button',name='Làm mới dữ liệu',exact=True).click()
        page.get_by_role('dialog').wait_for()
        page.get_by_role('button',name='Tiếp tục chỉnh sửa',exact=True).click()
        check(q.input_value()=='12,5',f'{width}: dirty dialog preserves draft')
        q.focus()
        check(q.evaluate('(e)=>e===document.activeElement'),f'{width}: focus retained')
        page.get_by_role('button',name='Lưu',exact=True).click()
        expect(page.get_by_text('Đã lưu thay đổi.',exact=True)).to_be_visible()
        check(q.input_value()=='12,5',f'{width}: fixture Save exact readback')
        check(note.input_value()=='Bếp yêu cầu',f'{width}: fixture Save note readback')
        page.screenshot(path=str(root/f'{width}x{height}-saved-filter-sort-smoke.png'),full_page=True)
        smoke.append({'width':width,'sortingFiltering':'pass','dirtyCancel':'pass','exactFixtureSaveReadback':'12.500000 / 12,5','reason':'OTHER','note':'Bếp yêu cầu'})
        page.close()
    # Released fixture preserves disabled editing.
    page=browser.new_page(viewport={'width':390,'height':844})
    page.goto(args.url+'?scenario=released')
    page.get_by_role('textbox',name='Số lượng xác nhận Gạo thơm',exact=True).wait_for()
    check(page.get_by_role('textbox',name='Số lượng xác nhận Gạo thơm',exact=True).is_disabled(),'released: quantity disabled')
    record(page,'390x844','released')
    browser.close()
(root/'geometry.json').write_text(json.dumps({'browser':browser_version,'phase':args.phase,'cases':results,'smoke':smoke,'failures':failures,'pageErrors':errors,'blockedExternalRequests':blocked},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'phase':args.phase,'captures':len(results),'failures':failures,'pageErrors':errors,'blockedRequests':len(blocked)},ensure_ascii=False))
if args.phase=='after' and (failures or errors or blocked):
    raise SystemExit(1)
