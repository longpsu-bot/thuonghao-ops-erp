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
    "Procurement": "atlas-vnext-procurement--long-allocation",
    "Ingredients": "atlas-master-data-ingredient-supplier-workbench--dense-ingredient-landing",
    "Planning Menu": "atlas-vnext-planning-sources--menu",
}

SPOT_STORIES = {
    "Attendance": "atlas-vnext-planning-sources--attendance",
    "Pantry": "atlas-vnext-planning-sources--pantry-additive",
    "Supplier Catalogue": "atlas-master-data-ingredient-supplier-workbench--supplier-landing",
}


def measure(page, *, horizontal, inject_height):
    return page.evaluate(
        """({ horizontal, injectHeight }) => {
          const table = document.querySelector('table[aria-label]');
          const viewport = table.closest('[role="region"]');
          if (injectHeight) {
            viewport.style.height = '240px';
            viewport.style.maxHeight = '240px';
          }
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
            configuredMaxHeight: getComputedStyle(viewport).maxHeight,
            injectedHeight: injectHeight,
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
        {"horizontal": horizontal, "injectHeight": inject_height},
    )


def check(result, *, horizontal, require_local_overflow=True):
    failures = []
    if result["rowCount"] < 5:
        failures.append("fixture has fewer than five body rows")
    if require_local_overflow and result["scrollHeight"] <= result["clientHeight"]:
        failures.append("viewport has no vertical overflow")
    if require_local_overflow and result["scrollTop"] < 100:
        failures.append("vertical scroll did not move")
    if abs(result["firstTop"] - result["viewportTop"]) > 1:
        failures.append("first header did not remain at viewport top")
    if abs(result["secondTop"] - result["viewportTop"]) > 1:
        failures.append("second header did not remain at viewport top")
    if horizontal and result["firstPosition"] != "sticky":
        failures.append("identity header lacks horizontal sticky positioning")
    if not result["firstPainted"]:
        failures.append("body data paints over the first sticky header")
    if result["firstBackground"] != "rgb(240, 244, 241)":
        failures.append("identity header lost its opaque toolbar surface")
    if not horizontal and not result["secondPainted"]:
        failures.append("non-first header is not painted at viewport top")
    if horizontal:
        if int(result["headerRowZ"]) <= int(result["bodyZ"]):
            failures.append("sticky header row is not above the body identity cell")
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


def procurement_geometry(page, base_url, width):
    viewport = page.get_by_role("region", name="Bảng phân bổ nhà cung ứng")
    viewport.locator("tbody button").first.click()
    detail = page.locator('[role="region"][aria-label^="Phân bổ "]').first
    detail.wait_for()
    attached = page.evaluate(
        """() => {
          const detail = document.querySelector('[role="region"][aria-label^="Phân bổ "]');
          const viewport = document.querySelector('[role="region"][aria-label="Bảng phân bổ nhà cung ứng"]');
          const workbar = document.querySelector('[role="group"][aria-label="Phạm vi mua hàng"]');
          const footer = detail.querySelector('footer');
          return {
            detailWidth: detail.getBoundingClientRect().width,
            detailBottom: detail.getBoundingClientRect().bottom,
            footerBottom: footer.getBoundingClientRect().bottom,
            tableBottom: viewport.getBoundingClientRect().bottom,
            workbarTop: workbar.getBoundingClientRect().top,
            documentOverflow: document.documentElement.scrollWidth > innerWidth + 1,
          };
        }"""
    )
    failures = []
    if attached["detailWidth"] < 320:
        failures.append("attached detail is narrower than 320px")
    if attached["footerBottom"] > page.viewport_size["height"] + 1:
        failures.append("attached detail footer clips below the viewport")
    if attached["tableBottom"] > page.viewport_size["height"] + 1:
        failures.append("long allocation table extends below the viewport")
    if not 0 <= attached["workbarTop"] < page.viewport_size["height"]:
        failures.append("primary workbar is outside the viewport")
    if attached["documentOverflow"]:
        failures.append("attached detail causes document-wide horizontal overflow")

    page.goto(
        f"{base_url}/iframe.html?id=atlas-vnext-procurement--short-allocation&viewMode=story",
        wait_until="domcontentloaded",
        timeout=60000,
    )
    short = page.get_by_role("region", name="Bảng phân bổ nhà cung ứng")
    short.locator("tbody tr").first.wait_for(timeout=60000)
    natural = short.evaluate(
        """e => ({
          rowCount: e.querySelectorAll('tbody tr').length,
          clientHeight: e.clientHeight,
          scrollHeight: e.scrollHeight,
          maxHeight: getComputedStyle(e).maxHeight,
        })"""
    )
    if natural["rowCount"] != 2 or natural["clientHeight"] != natural["scrollHeight"]:
        failures.append("short allocation table lost natural height")
    return {"attached": attached, "short": natural, "failures": failures}


def spot_check(page):
    return page.locator('table[aria-label]').first.evaluate(
        """table => {
          const viewport = table.parentElement;
          viewport.style.height = '100px';
          viewport.style.maxHeight = '100px';
          viewport.scrollTop = 70;
          const header = table.querySelector('thead th');
          const vr = viewport.getBoundingClientRect();
          const hr = header.getBoundingClientRect();
          return {
            rowCount: table.querySelectorAll('tbody tr').length,
            scrollTop: viewport.scrollTop,
            headerTop: hr.top,
            viewportTop: vr.top,
            headerPainted: document.elementFromPoint(hr.left + 10, vr.top + 12)?.closest('th') === header,
            documentOverflow: document.documentElement.scrollWidth > innerWidth + 1,
          };
        }"""
    )


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
        for width, height in ((1366, 768), (1440, 900), (1920, 1080), (390, 844)):
            page = browser.new_page(viewport={"width": width, "height": height})
            for name, story in STORIES.items():
                if width in (1366, 1920) and name != "Procurement":
                    continue
                page.goto(
                    f"{args.base_url}/iframe.html?id={story}&viewMode=story",
                    wait_until="domcontentloaded",
                    timeout=60000,
                )
                page.locator('table[aria-label] tbody tr').first.wait_for(timeout=60000)
                # The legacy Storybook preview imports src/styles.css, whose bare
                # `th { position: sticky }` masks missing Chakra header props.
                # A later bare selector neutralizes that rule while allowing
                # component-scoped Chakra classes and inline styles to win.
                page.add_style_tag(content="th { position: static; }")
                horizontal = width == 390 or name in ("Confirmed Need", "Planning Menu")
                for mode in ((False, True) if horizontal else (False,)):
                    inject_height = not (name == "Procurement" and width >= 1024)
                    result = measure(page, horizontal=mode, inject_height=inject_height)
                    failures = check(result, horizontal=mode)
                    label = f"{name} {width}px {'horizontal' if mode else 'vertical'}"
                    print(json.dumps({"case": label, "result": result, "failures": failures}, ensure_ascii=True))
                    if args.screenshots_dir:
                        direction = "horizontal" if mode else "vertical"
                        filename = f"{name.lower().replace(' ', '-')}-{width}-{direction}.png"
                        page.screenshot(path=str(args.screenshots_dir / filename))
                    all_failures.extend(f"{label}: {failure}" for failure in failures)
                if name == "Procurement" and width >= 1024:
                    geometry = procurement_geometry(page, args.base_url, width)
                    print(json.dumps({"case": f"Procurement {width}px geometry", **geometry}))
                    all_failures.extend(
                        f"Procurement {width}px geometry: {failure}"
                        for failure in geometry["failures"]
                    )
            if width in (1440, 390):
                for name, story in SPOT_STORIES.items():
                    page.goto(
                        f"{args.base_url}/iframe.html?id={story}&viewMode=story",
                        wait_until="domcontentloaded",
                        timeout=60000,
                    )
                    page.locator('table[aria-label] tbody tr').first.wait_for(timeout=60000)
                    page.add_style_tag(content="th { position: static; }")
                    result = spot_check(page)
                    failures = []
                    if result["scrollTop"] < 50 or abs(result["headerTop"] - result["viewportTop"]) > 1:
                        failures.append("vertical sticky header did not persist")
                    if not result["headerPainted"]:
                        failures.append("body paints over header")
                    if result["documentOverflow"]:
                        failures.append("document has horizontal overflow")
                    print(json.dumps({"case": f"{name} {width}px spot", "result": result, "failures": failures}))
                    all_failures.extend(f"{name} {width}px: {failure}" for failure in failures)
            page.close()
        browser.close()
    if all_failures:
        raise SystemExit(f"{len(all_failures)} sticky-header assertion(s) failed")


if __name__ == "__main__":
    main()
