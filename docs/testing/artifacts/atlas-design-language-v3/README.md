# Atlas v3 final evidence

All browser evidence uses the existing local review fixture and production workbenches; hosted requests and business writes are zero. `visual.json` records 56 viewport captures, rendered styles, selected-rail pixels and eleven-owner smoke. `regressions.json` records 131 layout/state measurements and ten persistence/discard proofs. `colors.json` and `contrast.md` contain 27 actual semantic contrast pairs and measured perceptual scales. CDP grayscale/CVD is engineering simulation, not human certification.

Run from the authorized repository using already-installed Python Playwright/Pillow and Vite:

```powershell
node docs/testing/artifacts/atlas-design-language-v3/serve-benchmark.mjs 3000 .
python -X utf8 scripts/atlas_v3_legibility_browser_test.py --part visual
python -X utf8 scripts/atlas_v3_legibility_browser_test.py --part regressions
python -X utf8 scripts/atlas_v3_legibility_browser_test.py --part performance
python -X utf8 scripts/atlas_v3_legibility_browser_test.py --part scan
```

Use separate terminals. The helper explicitly closes Vite's watcher so artifact/build writes cannot reset the fixture. Restart it after source edits. The visual harness asserts actual focused CSS (Brand600, 2px ring, 2px offset), neutral disabled hover, paired quantity/Unit, visible action footers and selected-rail pixels. Assertions fail on v2's inherited gray 1px quantity focus; `logs/focus-rendered-red.log` preserves that failure. `logs/visual-final.log` records the complete final green run.

`scan.json` records 1,801.7 seconds and 200 read-only scans. Local recovery restarts reopened the fixture; the initial/midpoint/final images support chroma review, not a staff fatigue study.

The historical performance files retain raw samples and explicit environmental limits. `performance-final-control.json` is the final bounded desktop control against an exact read-only archive of pre-v3 PR head `ea0d00a3cbf413588462873b8e03370e476f08d6`. Serve that archive separately on3001 using this repository's helper, then pass its absolute path to `performance-source-control.py`. Both watchers must be closed and test/build/install jobs stopped. Archive copies are benchmark inputs only; do not implement in them. Do not recursively move/delete an archive containing a node_modules junction.

Local full testing excludes only the task-created ignored archive beneath `.superpowers/sdd/atlas-design-language-v3/baseline/**`, preventing duplicate discovery. All tracked test files remain included; CI configuration and timeouts are unchanged. Raw logs are preserved in `raw-logs.zip`; checked-in readable logs normalize terminal control sequences and trailing whitespace only.

The integrated Product decision, twelve operator answers, review verdicts, validation totals and performance limits are in [Checkpoint E](../../../ui/atlas-product-corrections-01-evidence.md#checkpoint-e--atlas-design-language-v3). The canonical visual contract is [Atlas Design Language v3](../../../ui/atlas-design-language-v3.md). Draft PR354 tracks exact final-head CI; no merge or manual deployment is part of this task.
