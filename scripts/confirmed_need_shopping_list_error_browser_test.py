"""Bounded local fixture review using production XLSX and workbench boundaries."""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:3018/docs/testing/artifacts/confirmed-need-shopping-list-error-ux-01/harness/index.html')
args = parser.parse_args()
root = Path('docs/testing/artifacts/confirmed-need-shopping-list-error-ux-01')
root.mkdir(parents=True, exist_ok=True)
cases, errors, blocked = [], [], []
safe = 'Không thể đọc Phiếu đi chợ. Hãy kiểm tra tệp .xlsx và thử lại.'
geometry = """() => {
 const rect=e=>{if(!e)return null;const r=e.getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height};};
 const v=document.querySelector('[aria-label="Bảng xác nhận nhu cầu"]');
 const row=document.querySelector('[data-confirmed-need-line]');
 const alert=document.querySelector('[role="alert"]');
 const buttons=[...document.querySelectorAll('button')];
 return {pageWidth:document.documentElement.clientWidth,pageScrollWidth:document.documentElement.scrollWidth,viewport:rect(v),scrollLeft:v.scrollLeft,identity:getComputedStyle(row.querySelector('[data-field="identity"]')).position,headerRow:getComputedStyle(document.querySelector('thead tr')).position,quantity:rect(row.querySelector('input')),reason:rect(row.querySelector('select')),alert:rect(alert),alertText:alert?.textContent,alertLineHeight:alert?parseFloat(getComputedStyle(alert).lineHeight):null,save:rect(buttons.find(b=>b.textContent.trim()==='Lưu')),active:document.activeElement.getAttribute('aria-label'),saveCalls:window.shoppingListEvidence.saveCalls};
}"""

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    version = browser.version
    for width, height in [(1440, 900), (390, 844)]:
        page = browser.new_page(viewport={'width': width, 'height': height}, locale='vi-VN', reduced_motion='reduce')
        page.on('pageerror', lambda error: errors.append(str(error)))
        def route(request):
            if request.request.url.startswith('http://127.0.0.1:3018') or request.request.url.startswith('data:'):
                request.continue_()
            else:
                blocked.append(request.request.url)
                request.abort()
        page.route('**/*', route)
        page.goto(args.url)
        page.wait_for_load_state('networkidle')
        quantity = page.get_by_role('textbox', name='Số lượng xác nhận Gạo thơm', exact=True)
        expect(quantity).to_have_value('10,25')
        file_input = page.get_by_label('Nhập Phiếu đi chợ .xlsx', exact=True)
        import_button = page.get_by_role('button', name='Nhập Phiếu đi chợ', exact=True)

        def record(state):
            data = page.evaluate(geometry)
            assert data['pageScrollWidth'] <= data['pageWidth'] + 1, data
            assert data['saveCalls'] == 0, data
            assert data['identity'] == ('sticky' if width >= 1280 else 'static'), data
            assert data['headerRow'] == 'sticky', data
            if data['alert']:
                alert = data['alert']
                assert 0 <= alert['left'] and alert['right'] <= width + 1, data
                assert 0 <= alert['top'] and alert['bottom'] <= height, data
                assert all(raw not in data['alertText'] for raw in ['JSZip', 'ExcelJS', 'Corrupted zip', 'central directory']), data
            assert 0 <= import_button.bounding_box()['y'] < height
            cases.append({'width': width, 'height': height, 'state': state, **data})
            page.screenshot(path=str(root / f'{width}x{height}-{state}.png'), full_page=True)

        record('normal')
        quantity.focus()
        for attempt in range(2):
            file_input.set_input_files({'name': 'corrupt.xlsx', 'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'buffer': bytes([80, 75, 3, 4, 0])})
            expect(page.get_by_role('alert')).to_have_text(safe)
            expect(import_button).to_be_enabled()
            expect(quantity).to_be_focused()
            assert file_input.input_value() == ''
        record('corrupt-error')
        stale = bytes(page.evaluate("() => window.shoppingListFixtureBytes('stale')"))
        file_input.set_input_files({'name': 'stale.xlsx', 'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'buffer': stale})
        expect(page.get_by_role('alert')).to_contain_text('không còn khớp dữ liệu Atlas hiện tại')
        expect(import_button).to_be_enabled()
        expect(quantity).to_be_focused()
        record('stale-error')
        edited = bytes(page.evaluate("() => window.shoppingListFixtureBytes('edited')"))
        file_input.set_input_files({'name': 'edited.xlsx', 'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'buffer': edited})
        expect(page.get_by_text('Đã nhập 1 thay đổi vào bản nháp.', exact=True)).to_be_visible()
        expect(quantity).to_have_value('12,5')
        expect(quantity).to_be_focused()
        expect(page.get_by_role('alert')).to_have_count(0)
        expect(page.get_by_role('button', name='Lưu', exact=True)).to_be_enabled()
        expect(page.get_by_role('button', name='Tiếp tục phân bổ NCC', exact=True)).to_be_disabled()
        save_button = page.get_by_role('button', name='Lưu', exact=True)
        save_button.scroll_into_view_if_needed()
        save_bounds = save_button.bounding_box()
        assert 0 <= save_bounds['y'] and save_bounds['y'] + save_bounds['height'] <= height
        record('imported-dirty')
        reason = page.get_by_role('combobox', name='Lý do Gạo thơm', exact=True)
        reason.focus()
        data = page.evaluate(geometry)
        assert data['reason']['left'] >= data['viewport']['left'] - 1
        assert data['reason']['right'] <= data['viewport']['right'] + 1
        expect(reason).to_be_focused()
        record('dirty-reason-focus')
        # A later failed import must preserve the successful local draft.
        file_input.set_input_files({'name': 'corrupt.xlsx', 'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'buffer': b'not xlsx'})
        expect(page.get_by_role('alert')).to_have_text(safe)
        expect(quantity).to_have_value('12,5')
        expect(reason).to_be_focused()
        expect(page.get_by_role('button', name='Lưu', exact=True)).to_be_enabled()
        record('dirty-corrupt-error')
        page.close()
    browser.close()
assert not errors and not blocked, {'errors': errors, 'blocked': blocked}
(root / 'geometry.json').write_text(json.dumps({'browser': version, 'cases': cases, 'pageErrors': errors, 'blockedExternalRequests': blocked, 'hostedBusinessWrites': 0}, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'captures': len(cases), 'pageErrors': errors, 'blockedRequests': len(blocked)}, ensure_ascii=False))
