"""Verify emitted School glyph text and bounds against native PDF cell borders.

Read-only PDF/XLSX verification. AutoFit height is intentionally not a clipping
oracle: native printer wrapping differs from Excel's screen layout.
"""

import argparse
import hashlib
import json
import re
import unicodedata
from pathlib import Path

import openpyxl
import pdfplumber
from pdfplumber.utils import extract_text


def canonical_text(value):
    # Printer wrapping adds line breaks, including inside long tokens. Every
    # non-whitespace glyph must remain in its original order and identity.
    return re.sub(r"\s+", "", unicodedata.normalize("NFC", value))


def cluster_borders(rects, axis):
    grouped = []
    for rect in sorted(rects, key=lambda r: (r[axis[0]] + r[axis[1]]) / 2):
        position = (rect[axis[0]] + rect[axis[1]]) / 2
        if grouped and abs(position - grouped[-1]["position"]) < 0.2:
            grouped[-1]["low"] = min(grouped[-1]["low"], rect[axis[0]])
            grouped[-1]["high"] = max(grouped[-1]["high"], rect[axis[1]])
        else:
            grouped.append({"position": position, "low": rect[axis[0]], "high": rect[axis[1]]})
    return grouped


def printed_candidates(page, first_visible, last_visible):
    vertical = cluster_borders(
        [r for r in page.rects if r["width"] < 1.5 and r["height"] > 10],
        ("x0", "x1"),
    )
    horizontal = cluster_borders(
        [r for r in page.rects if r["height"] < 1.5 and r["width"] > page.width / 2],
        ("top", "bottom"),
    )
    if len(vertical) <= last_visible + 1:
        return []
    left = vertical[first_visible]["high"]
    right = vertical[last_visible + 1]["low"]
    candidates = []
    for upper, lower in zip(horizontal, horizontal[1:]):
        chars = [c for c in page.chars
                 if c["x0"] >= left - 0.2 and c["x1"] <= right + 0.2
                 and upper["position"] < (c["top"] + c["bottom"]) / 2 < lower["position"]]
        if not chars:
            continue
        text = extract_text(chars, x_tolerance=2, y_tolerance=2)
        candidates.append({
            "text": text,
            "printedLineCount": len({round(c["top"], 1) for c in chars if not c["text"].isspace()}),
            "cellBounds": [round(left, 4), round(upper["high"], 4), round(right, 4), round(lower["low"], 4)],
            "topClearancePoints": min(c["top"] for c in chars) - upper["high"],
            "bottomClearancePoints": lower["low"] - max(c["bottom"] for c in chars),
            "leftClearancePoints": min(c["x0"] for c in chars) - left,
            "rightClearancePoints": right - max(c["x1"] for c in chars),
        })
    return candidates


def header_candidates(page, record):
    """Unbordered PXK A6: bound it by actual neighboring header glyphs."""
    vertical = cluster_borders(
        [r for r in page.rects if r["width"] < 1.5 and r["height"] > 10],
        ("x0", "x1"),
    )
    if len(vertical) < 2:
        return []
    left, right = vertical[0]["high"], vertical[-1]["low"]
    lines = {}
    for char in page.chars:
        lines.setdefault(round(char["top"], 1), []).append(char)
    ordered = [lines[key] for key in sorted(lines)]
    previous = next((chars for chars in ordered
                     if canonical_text(extract_text(chars)).startswith(canonical_text(record["precedingText"]))), None)
    following = next((chars for chars in ordered
                      if canonical_text(extract_text(chars)).startswith(canonical_text(record["followingText"]))), None)
    if not previous or not following:
        return []
    upper = max(char["bottom"] for char in previous)
    lower = min(char["top"] for char in following)
    chars = [c for c in page.chars if c["x0"] >= left - 0.2 and c["x1"] <= right + 0.2
             and upper < (c["top"] + c["bottom"]) / 2 < lower]
    if not chars:
        return []
    return [{
        "text": extract_text(chars, x_tolerance=2, y_tolerance=2),
        "printedLineCount": len({round(c["top"], 1) for c in chars if not c["text"].isspace()}),
        "geometryMethod": "unbordered PXK header bounded horizontally by table borders and vertically by row5/row7 neighboring glyphs",
        "cellBounds": [round(left, 4), round(upper, 4), round(right, 4), round(lower, 4)],
        "topClearancePoints": min(c["top"] for c in chars) - upper,
        "bottomClearancePoints": lower - max(c["bottom"] for c in chars),
        "leftClearancePoints": min(c["x0"] for c in chars) - left,
        "rightClearancePoints": right - max(c["x1"] for c in chars),
    }]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--minimum-clearance-points", type=float, default=0.5)
    args = parser.parse_args()
    output = args.output_directory.resolve()
    report_path = output / "school-row-printed-report.json"
    # A failed or interrupted rerun must invalidate an earlier PASS record.
    report_path.write_text(json.dumps({"status": "RUNNING", "checkedSchoolRows": 0}) + "\n", encoding="utf-8")
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8-sig"))
    checks = []
    evidence_files = []
    def record_hash(path):
        evidence_files.append({"path": path.relative_to(output).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    for file in manifest["files"]:
        record_hash(output / file["name"])
        workbook = openpyxl.load_workbook(output / file["name"])
        for sheet_index, sheet in enumerate(file["sheets"], start=1):
            pdf_path = output / "native-qa" / file["name"].replace(".xlsx", f"-sheet-{sheet_index}.pdf")
            record_hash(pdf_path)
            records = sheet["schoolRows"]
            if not records:
                continue
            source_sheet = workbook[sheet["name"]]
            last_column = max(record["lastColumn"] for record in records)
            visible = [index for index in range(1, max(6, last_column) + 1)
                       if not source_sheet.column_dimensions[openpyxl.utils.get_column_letter(index)].hidden]
            with pdfplumber.open(pdf_path) as pdf:
                candidates = []
                for page_index, page in enumerate(pdf.pages, start=1):
                    first_visible = visible.index(records[0]["firstColumn"])
                    last_visible = visible.index(records[0]["lastColumn"])
                    native_candidates = (header_candidates(page, records[0])
                                         if records[0].get("boundaryKind") == "adjacent-header-text"
                                         else printed_candidates(page, first_visible, last_visible))
                    for candidate in native_candidates:
                        candidate["page"] = page_index
                        candidates.append(candidate)
                next_candidate = 0
                for record in records:
                    wanted = canonical_text(record["text"])
                    match = None
                    for index in range(next_candidate, len(candidates)):
                        if canonical_text(candidates[index]["text"]) == wanted:
                            match = candidates[index]
                            next_candidate = index + 1
                            break
                    if match is None:
                        raise AssertionError(f"PRINTED_SCHOOL_TEXT_MISSING: {sheet['name']} {record['address']}")
                    for side in ("top", "bottom", "left", "right"):
                        clearance = match[f"{side}ClearancePoints"]
                        if clearance < args.minimum_clearance_points:
                            raise AssertionError(f"PRINTED_SCHOOL_GLYPH_BORDER_OVERLAP: {sheet['name']} {record['address']} {side}={clearance}")
                    checks.append({
                        "file": file["name"], "sheet": sheet["name"], "address": record["address"],
                        "sourceText": record["text"], "allocatedHeightPoints": record["height"],
                        "deterministicMeasuredLineCount": 1 + (record["measuredHeight"] - 28) / 16,
                        "printedFullTextMatches": True,
                        **{key: round(value, 4) if isinstance(value, float) else value for key, value in match.items()},
                    })
        workbook.close()
    report = {
        "method": "Native PDF glyph sequence equals source after NFC/whitespace normalization; bordered cells enclose glyph boxes; unbordered PXK School headers stay within horizontal table bounds and between neighboring header glyphs.",
        "minimumClearancePoints": args.minimum_clearance_points,
        "manifestSha256": hashlib.sha256((output / "manifest.json").read_bytes()).hexdigest(),
        "evidenceFiles": evidence_files,
        "status": "PASS", "checkedSchoolRows": len(checks), "checks": checks,
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verified full printed text and geometry clearances for {len(checks)} School rows.")


if __name__ == "__main__":
    main()
