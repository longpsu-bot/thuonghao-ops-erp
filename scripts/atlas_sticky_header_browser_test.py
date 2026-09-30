"""Check Atlas sticky table headers against real Chromium scroll geometry.

Start Storybook with `pnpm exec storybook dev -p 6006 --no-open`, then run
`python scripts/atlas_sticky_header_browser_test.py`.
"""

import argparse
import json
from pathlib import Path

from playwright.sync_api import sync_playwright


STORIES = {
    "Confirmed Need": "atlas-vnext-confirmed-need--certified-shape-248-current-lines",
    "Procurement": "atlas-vnext-procurement--normal",
    "Ingredients": "atlas-master-data-ingredient-supplier-workbench--dense-ingredient-landing",
    "Planning Menu": "atlas-vnext-planning-sources--menu",
}


def measure(page, *, horizontal):
    return page.evaluate(
        """({ horizontal }) => {
          const table = document.querySelector('table[aria-label]');
          const viewport = table.closest('[role="region"]');
          viewport.style.height = '240px';
          viewport.style.maxHeight = '240px';
          if (horizontal && innerWidth > 700) viewport.style.width = '700px';
          viewport.scrollTop = 180;
          viewport.scrollLeft = horizontal ? 120 : 0;
          const headers = table.querySelectorAll('thead th');
          const first = headers[0];
          const second = headers[1];
          const body = table.querySelector('tbody td');
          const vr = viewport.getBoundingClientRect();
          const fr = first.getBoundingClientRect();
          const sr = second.getBoundingClientRect();
          const br = body.getBoundingClientRect();
          const firstHit = document.elementFromPoint(fr.left + 20, vr.top + 18);
          const secondHit = document.elementFromPoint(
            Math.min(sr.left + 12, vr.right - 5), vr.top + 18
          );
          const overlapLeft = Math.max(fr.left, sr.left);
          const overlapRight = Math.min(fr.right, sr.right, vr.right);
          const intersectionHit = overlapRight - overlapLeft > 10
            ? document.elementFromPoint(overlapLeft + 5, vr.top + 18)
            : null;
          return {
            rowCount: table.querySelectorAll('tbody tr').length,
            scrollTop: viewport.scrollTop,
            scrollLeft: viewport.scrollLeft,
            scrollHeight: viewport.scrollHeight,
            clientHeight: viewport.clientHeight,
            scrollWidth: viewport.scrollWidth,
            clientWidth: viewport.clientWidth,
            viewportTop: vr.top,
            viewportLeft: vr.left,
            firstTop: fr.top,
            secondTop: sr.top,
            firstLeft: fr.left,
            bodyLeft: br.left,
            firstHeight: fr.height,
            firstWidth: fr.width,
            firstBackground: getComputedStyle(first).backgroundColor,
            firstName: first.textContent.trim(),
            secondName: second.textContent.trim(),
            firstPainted: firstHit?.closest('th') === first,
            secondPainted: secondHit?.closest('th') === second,
            intersectionPainted: intersectionHit?.closest('th') === first,
            hasIntersection: intersectionHit !== null,
            firstPosition: getComputedStyle(first).position,
            secondPosition: getComputedStyle(second).position,
            bodyPosition: getComputedStyle(body).position,
            headerRowZ: getComputedStyle(first.parentElement).zIndex,
            bodyZ: getComputedStyle(body).zIndex,
            documentOverflow: document.documentElement.scrollWidth > innerWidth + 1,
          };
        }""",
        {"horizontal": horizontal},
    )


def check(result, *, horizontal):
    failures = []
    if result["rowCount"] < 5:
        failures.append("fixture has fewer than five body rows")
    if result["scrollHeight"] <= result["clientHeight"]:
        failures.append("viewport has no vertical overflow")
    if result["scrollTop"] < 100:
        failures.append("vertical scroll did not move")
    if abs(result["firstTop"] - result["viewportTop"]) > 1:
        failures.append("first header did not remain at viewport top")
    if abs(result["secondTop"] - result["viewportTop"]) > 1:
        failures.append("second header did not remain at viewport top")
    if result["firstPosition"] != "sticky":
        failures.append("first header cancels sticky positioning")
    if result["secondPosition"] != "sticky":
        failures.append("second header cancels sticky positioning")
    if not result["firstPainted"]:
        failures.append("body data paints over the first sticky header")
    if result["firstBackground"] != "rgb(240, 244, 241)":
        failures.append("identity header lost its opaque toolbar surface")
    if not horizontal and not result["secondPainted"]:
        failures.append("non-first header is not painted at viewport top")
    if horizontal:
        if result["scrollWidth"] <= result["clientWidth"]:
            failures.append("viewport has no horizontal overflow")
        if result["scrollLeft"] < 80:
            failures.append("horizontal scroll did not move")
        if abs(result["firstLeft"] - result["viewportLeft"]) > 1:
            failures.append("identity header did not remain at viewport left")
        if abs(result["firstLeft"] - result["bodyLeft"]) > 1:
            failures.append("identity header and body column are misaligned")
        if result["bodyPosition"] != "sticky":
            failures.append("identity body column lost its horizontal freeze")
        if result["hasIntersection"] and not result["intersectionPainted"]:
            failures.append("ordinary header paints over the identity intersection")
    if result["documentOverflow"]:
        failures.append("document has horizontal overflow")
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:6006")
    parser.add_argument("--screenshots-dir", type=Path)
    args = parser.parse_args()
    if args.screenshots_dir:
        args.screenshots_dir.mkdir(parents=True, exist_ok=True)
    all_failures = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        for width, height in ((1440, 900), (390, 844)):
            page = browser.new_page(viewport={"width": width, "height": height})
            for name, story in STORIES.items():
                page.goto(
                    f"{args.base_url}/iframe.html?id={story}&viewMode=story",
                    wait_until="domcontentloaded",
                    timeout=60000,
                )
                page.locator('table[aria-label] tbody tr').first.wait_for(timeout=60000)
                horizontal = width == 390 or name in ("Confirmed Need", "Planning Menu")
                for mode in ((False, True) if horizontal else (False,)):
                    result = measure(page, horizontal=mode)
                    failures = check(result, horizontal=mode)
                    label = f"{name} {width}px {'horizontal' if mode else 'vertical'}"
                    print(json.dumps({"case": label, "result": result, "failures": failures}, ensure_ascii=True))
                    if args.screenshots_dir:
                        direction = "horizontal" if mode else "vertical"
                        filename = f"{name.lower().replace(' ', '-')}-{width}-{direction}.png"
                        page.screenshot(path=str(args.screenshots_dir / filename))
                    all_failures.extend(f"{label}: {failure}" for failure in failures)
            page.close()
        browser.close()
    if all_failures:
        raise SystemExit(f"{len(all_failures)} sticky-header assertion(s) failed")


if __name__ == "__main__":
    main()
