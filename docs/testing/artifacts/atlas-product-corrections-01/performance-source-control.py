import json,sys
from pathlib import Path
sys.path.insert(0,'scripts')
from playwright.sync_api import sync_playwright
from atlas_workspace_performance import run
source=Path('.superpowers/sdd/atlas-product-corrections-01/baseline/scripts/atlas_workspace_performance.py').read_text(encoding='utf-8')
assert source.count('http://127.0.0.1:3000/atlas-vnext-review.html')==1
namespace={'__name__':'historical_benchmark'}
exec(compile(source.replace('http://127.0.0.1:3000/atlas-vnext-review.html','http://127.0.0.1:3001/atlas-vnext-review.html'),'<starting-main-benchmark>','exec'),namespace)
results=[]
with sync_playwright() as p:
 browser=p.chromium.launch()
 for width in [1440,650]:
  baseline=namespace['run'](browser,width)
  final=run(browser,width,legacy_comparison=True)
  results.append({'width':width,'baseline':baseline,'final':final})
 report={'baseline_sha':'dd00f304e43de77b59288e32109db6fd8884c5f7','browser':browser.version,'cpu_throttle':4,
 'runtime':'Both exact source trees served by the same Vite createServer wrapper with server.watch=null; archived baseline source unedited. No heavy jobs active.',
 'method':'Original starting-main benchmark loaded without source edits; URL only redirected to read-only archived main Vite at3001. Final source same seven equivalent owners/four-target sequence. Six cycles, warmup excluded,20samples per viewport/source; click to two RAF. All heavy jobs stopped before run.',
 'results':results}
 browser.close()
Path('docs/testing/artifacts/atlas-product-corrections-01/performance-source-control.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({**{k:v for k,v in report.items() if k!='results'},'results':[{ 'width':r['width'], 'baseline_median':r['baseline']['median_ms'],'baseline_p95':r['baseline']['p95_ms'],'final_median':r['final']['median_ms'],'final_p95':r['final']['p95_ms']} for r in results]},ensure_ascii=False))
