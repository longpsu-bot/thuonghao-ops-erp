import json, sys
from pathlib import Path
sys.path.insert(0, 'scripts')
from playwright.sync_api import sync_playwright, expect
from atlas_persistent_workspace_browser_test import launch, select
from atlas_workspace_performance import OWNERS, LEGACY_SUBSET, distribution
results=[]
with sync_playwright() as p:
    browser=p.chromium.launch()
    for width in [1440,650]:
      for workload in ['legacy-seven','eleven-legacy-sequence']:
        page=browser.new_page(viewport={'width':width,'height':900},reduced_motion='reduce')
        page.goto('http://127.0.0.1:3000/atlas-vnext-review.html');page.wait_for_load_state('networkidle')
        labels=OWNERS[1:] if workload=='eleven-legacy-sequence' else ['Xác nhận nhu cầu','Phân bổ NCC','Công thức','Phiếu xuất kho','Nguyên liệu','Đối chiếu PO / Phiếu xuất kho']
        for label in labels:
          launch(page,label)
          if label in ['Phân bổ NCC','Công thức','Phiếu xuất kho']:
            select(page,{'Phân bổ NCC':'procurement','Công thức':'recipes','Phiếu xuất kho':'pxk'}[label])
        page.wait_for_timeout(500)
        cdp=page.context.new_cdp_session(page);cdp.send('Performance.enable');cdp.send('Emulation.setCPUThrottlingRate',{'rate':4})
        dom=page.evaluate("[...document.querySelectorAll('main>[role=tabpanel]')].map(e=>({owner:e.getAttribute('aria-label'),nodes:e.querySelectorAll('*').length,rows:e.querySelectorAll('tr').length}))")
        samples=[]
        for cycle in range(6):
          for label in LEGACY_SUBSET:
            if width<1024:
              page.get_by_role('button',name='Đang mở:',exact=False).click()
              target=page.get_by_role('dialog',name='Bàn làm việc đang mở',exact=True).get_by_role('button',name=label,exact=True)
            else:
              target=page.get_by_role('tablist',name='Bàn làm việc đang mở').get_by_role('tab',name=label,exact=True)
            target.scroll_into_view_if_needed()
            before={m['name']:m['value'] for m in cdp.send('Performance.getMetrics')['metrics']}
            duration=target.evaluate('''async b=>{const s=performance.now();b.click();await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return performance.now()-s}''')
            after={m['name']:m['value'] for m in cdp.send('Performance.getMetrics')['metrics']}
            if cycle:samples.append({'owner':label,'paint_ms':round(duration,2),**{k:round(1000*(after[k]-before[k]),2) for k in ['ScriptDuration','LayoutDuration','RecalcStyleDuration','TaskDuration']}})
        result={'width':width,'workload':workload,'dom':dom,'samples':samples,**distribution(samples)}
        results.append(result);print(json.dumps({k:v for k,v in result.items() if k not in ['samples','dom']}),flush=True);page.close()
    browser.close()
Path('docs/testing/artifacts/atlas-product-corrections-01/performance-investigation.json').write_text(json.dumps({'method':'Same 4xCPU/six cycles/two RAF; exact historical four-target sequence; fresh pages; warmup excluded; idle Vite; current integrated source','results':results},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
