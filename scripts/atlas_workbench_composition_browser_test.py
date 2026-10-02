"""Capture and check real Atlas workbenches in Storybook; no hosted calls.

Start: pnpm exec storybook dev -p 6006 --no-open
Run: python scripts/atlas_workbench_composition_browser_test.py --phase before
"""

import argparse
import json
import re
from pathlib import Path

from playwright.sync_api import sync_playwright


def geometry(page, kind):
    return page.evaluate("""kind => {
      const rect = el => { const r = el.getBoundingClientRect();
        return {x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom}; };
      if (kind === 'recipe') {
        const nav = document.querySelector('[aria-label="Điều hướng món"]') ||
          document.querySelector('table[aria-label="Danh mục món"]').parentElement;
        const control = [...nav.querySelectorAll('button')][0];
        const selected = nav.querySelector('button[aria-pressed="true"]');
        const frame = nav.parentElement.getBoundingClientRect();
        return {navigator:rect(nav),clientWidth:nav.clientWidth,scrollWidth:nav.scrollWidth,
          navigatorFrame:rect(nav.parentElement),selected: selected ? rect(selected) : null,
          selectedVisible:!selected || (selected.getBoundingClientRect().top>=frame.top-1 && selected.getBoundingClientRect().bottom<=frame.bottom+1),
          controlsFit:[...nav.querySelectorAll('button')].filter(el=>el.getClientRects().length)
            .every(el=>el.getBoundingClientRect().right<=nav.getBoundingClientRect().right+1),
          selection:rect(control),editor:rect(document.querySelector('[aria-label="Không gian công thức"]')),
          pageOverflow:document.documentElement.scrollWidth > innerWidth};
      }
      const editor = document.querySelector('aside[aria-label^="Phân bổ"]');
      const footer = editor.querySelector('footer');
      const note = editor.querySelector('textarea');
      const table = document.querySelector('[aria-label="Bảng phân bổ nhà cung ứng"]');
      const body = [...editor.children].find(el=>getComputedStyle(el).overflowY==='auto');
      return {editor:rect(editor),footer:rect(footer),note:note ? rect(note) : null,
        body:body ? {clientHeight:body.clientHeight,scrollHeight:body.scrollHeight} : null,
        actionsFit:[...footer.querySelectorAll('button')].every(el=>
          el.getBoundingClientRect().right<=editor.getBoundingClientRect().right+1),
        table:rect(table),alignSelf:getComputedStyle(editor).alignSelf,
        trailingSpace:editor.getBoundingClientRect().bottom-footer.getBoundingClientRect().bottom,
        pageOverflow:document.documentElement.scrollWidth > innerWidth};
    }""", kind)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--phase', choices=['before', 'after'], required=True)
    parser.add_argument('--url', default='http://localhost:6006')
    parser.add_argument('--scenarios', nargs='+', help='Refresh named after scenarios only')
    args = parser.parse_args()
    root = Path('docs/testing/artifacts/atlas-workbench-composition-02') / args.phase
    root.mkdir(parents=True, exist_ok=True)
    results = []
    if args.scenarios:
        assert args.phase=='after'
        results=[item for item in json.loads((root/'geometry.json').read_text(encoding='utf-8'))
                 if item.get('scenario') not in args.scenarios]
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        for kind, story in [('recipe', 'atlas-recipes-dish-recipe-workbench--catalogue'),
                            ('procurement', 'atlas-vnext-procurement--saved-manual-split')]:
            sizes=[(1440,900),(1280,800),(1024,768),(390,844)]
            if args.phase=='after': sizes += [(768,1024),(360,800)]
            if args.scenarios: sizes=[]
            for width, height in sizes:
                page = browser.new_page(viewport={'width':width,'height':height}, reduced_motion='reduce')
                page.goto(f'{args.url}/iframe.html?id={story}&viewMode=story')
                page.wait_for_load_state('networkidle')
                if kind == 'recipe':
                    page.get_by_role('button', name='Sửa công thức Canh bí đỏ thịt bằm', exact=True).click()
                    page.get_by_role('heading', name='Công thức gốc', exact=True).wait_for()
                else:
                    page.get_by_role('button', name=re.compile('^Xem phân bổ Gạo thơm')).click()
                    page.locator('aside[aria-label^="Phân bổ"]').wait_for()
                page.screenshot(path=str(root / f'{kind}-{width}x{height}.png'), full_page=True)
                result = {'kind':kind,'viewport':[width,height],**geometry(page,kind)}
                results.append(result)
                if args.phase == 'after':
                    assert not result['pageOverflow'], result
                    if kind == 'recipe':
                        assert result['scrollWidth'] <= result['clientWidth'] + 1, result
                        assert result['controlsFit'], result
                    else:
                        assert result['editor']['right'] <= width + 1, result
                        assert not result['note'] or result['note']['right'] <= result['editor']['right'], result
                        assert result['actionsFit'], result
                        assert result['trailingSpace'] <= 2, result
                page.close()
        if args.phase == 'after':
            scenarios = [
                ('recipe-browse','recipe','atlas-recipes-dish-recipe-workbench--catalogue',False),
                ('recipe-short','recipe','atlas-recipes-dish-recipe-workbench--catalogue',True),
                ('recipe-last-selected','recipe','atlas-recipes-dish-recipe-workbench--catalogue',True),
                ('recipe-long','recipe','atlas-recipes-dish-recipe-workbench--composition-long-content',True),
                ('recipe-locked','recipe','atlas-recipes-dish-recipe-workbench--locked-catalogue',True),
                ('recipe-review','recipe','atlas-recipes-dish-recipe-workbench--catalogue',True),
                ('procurement-none','procurement','atlas-vnext-procurement--normal',True),
                ('procurement-one','procurement','atlas-vnext-procurement--normal',True),
                ('procurement-one-row','procurement','atlas-vnext-procurement--composition-one-row',True),
                ('procurement-short-editor','procurement','atlas-vnext-procurement--composition-short-editor',True),
                ('procurement-long','procurement','atlas-vnext-procurement--composition-long-content',True),
                ('procurement-rebalance','procurement','atlas-vnext-procurement--rebalance',True),
                ('procurement-dense','procurement','atlas-vnext-procurement--long-allocation',True),
                ('procurement-note-dirty','procurement','atlas-vnext-procurement--saved-manual-split',True),
            ]
            for label,kind,story,selected in scenarios:
                if args.scenarios and label not in args.scenarios: continue
                for width,height in [(1280,800),(390,844)]:
                    print(f'Checking {label} {width}x{height}',flush=True)
                    page=browser.new_page(viewport={'width':width,'height':height}, reduced_motion='reduce')
                    page.goto(f'{args.url}/iframe.html?id={story}&viewMode=story')
                    page.wait_for_load_state('networkidle')
                    if selected:
                        if kind=='recipe':
                            target=page.get_by_role('button',name='Sửa công thức Cơm trắng',exact=True) if label=='recipe-last-selected' else page.get_by_role('button',name=re.compile('^(Sửa|Xem) công thức Canh bí đỏ'))
                            target.click()
                            page.get_by_role('heading',name='Công thức gốc',exact=True).wait_for()
                            if label=='recipe-short':
                                if width<1280: page.get_by_role('button',name='Chọn món khác',exact=True).click()
                                choice=page.get_by_role('button',name='Sửa công thức Thịt heo kho',exact=True)
                                choice.focus()
                                choice.press('Enter')
                                page.get_by_role('heading',name='Thịt heo kho',exact=True).wait_for()
                            if label=='recipe-review':
                                page.get_by_label('Định lượng Bí đỏ',exact=True).fill('30')
                                page.get_by_role('button',name='Xem thay đổi',exact=True).click()
                                page.get_by_role('button',name='Lưu công thức',exact=True).wait_for()
                        else:
                            page.get_by_role('button',name=re.compile('^(Xem phân bổ|Phân bổ NCC) Gạo thơm')).first.click()
                            page.locator('aside[role="region"]').wait_for()
                            if label=='procurement-one':
                                page.get_by_role('button',name='Dùng đề xuất',exact=True).click()
                                page.get_by_role('textbox',name='Ghi chú cho NCC An Phú',exact=True).wait_for()
                            if label=='procurement-note-dirty':
                                page.get_by_role('textbox',name='Ghi chú cho NCC An Phú',exact=True).fill('Giao trước 05:30 · Kiểm tra đóng gói')
                                page.get_by_text('Đang chỉnh sửa · chưa lưu',exact=True).wait_for()
                        page.evaluate('() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))')
                        result={'scenario':label,'kind':kind,'viewport':[width,height],**geometry(page,kind)}
                        assert not result['pageOverflow'],result
                        if kind=='recipe': assert result['controlsFit'] and result['selectedVisible'] and result['scrollWidth']<=result['clientWidth']+1,result
                        else: assert result['actionsFit'] and result['trailingSpace']<=2,result
                        results.append(result)
                        if label=='procurement-short-editor' and width==1280:
                            result['stretchProbe']=page.evaluate('''() => {
                              const editor=document.querySelector('aside[role="region"]');
                              const body=[...editor.children].find(el=>getComputedStyle(el).overflowY==='auto');
                              const current=editor.getBoundingClientRect().height;
                              editor.style.alignSelf='auto'; body.style.flex='1';
                              const stretched=editor.getBoundingClientRect().height;
                              const bodyHeight=body.clientHeight;
                              editor.style.alignSelf=''; body.style.flex='';
                              return {currentHeight:current,stretchedHeight:stretched,stretchedBodyHeight:bodyHeight};
                            }''')
                    page.screenshot(path=str(root/f'{label}-{width}x{height}.png'),full_page=True)
                    if label=='recipe-review':
                        page.get_by_role('button',name='Lưu công thức',exact=True).click()
                        page.get_by_role('heading',name='Công thức gốc',exact=True).wait_for()
                        page.screenshot(path=str(root/f'recipe-saved-{width}x{height}.png'),full_page=True)
                    page.close()
            # 200% desktop reflow: CSS viewport equals half of a 1440x900 window.
            page=browser.new_page(viewport={'width':720,'height':450},device_scale_factor=2)
            page.goto(f'{args.url}/iframe.html?id=atlas-recipes-dish-recipe-workbench--catalogue&viewMode=story')
            page.get_by_role('button',name='Sửa công thức Canh bí đỏ thịt bằm',exact=True).click()
            result={'scenario':'recipe-200-percent-reflow','kind':'recipe','viewport':[720,450],**geometry(page,'recipe')}
            assert not result['pageOverflow'] and result['controlsFit'],result
            results.append(result)
            page.screenshot(path=str(root/'recipe-200-percent-reflow.png'),full_page=True)
            page.close()
        browser.close()
    results=list({(item['kind'],item.get('scenario'),tuple(item['viewport'])):item for item in results}.values())
    (root / 'geometry.json').write_text(json.dumps(results, indent=2) + "\n", encoding='utf-8')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
