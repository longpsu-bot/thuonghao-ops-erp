"""Isolated native Excel PDF QA; not an exporter/importer or business validator.

Use bundled Python/pdfplumber: validate-native-print.py PDF [specimen XLSX].
Run validate-specimen.py separately, and visually inspect every rendered page.
Text extraction cannot independently certify the appearance of clipped glyphs.
"""

from collections import Counter
from decimal import Decimal
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile

import pdfplumber

HERE = Path(__file__).parent
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def groups(values):
    result = []
    for value in sorted(set(values)):
        if result and value - result[-1][-1] < 2.5:
            result[-1].append(value)
        else:
            result.append([value])
    return [sum(group) / len(group) for group in result]


def norm(value):
    return re.sub(r"\s+", "", value)


def expected_cells(path, date_count):
    result = {column: [] for column in "ABCDE"}
    with ZipFile(path) as archive:
        strings = ["".join(item.itertext()) for item in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
        for index in range(1, date_count + 1):
            sheet = ET.fromstring(archive.read(f"xl/worksheets/sheet{index}.xml"))
            for row in sheet.findall("m:sheetData/m:row", NS):
                if int(row.get("r")) < 4:
                    continue
                for cell in row:
                    column = cell.get("r")[0]
                    if column not in result:
                        continue
                    if cell.get("t") == "s":
                        value = strings[int(cell.find("m:v", NS).text)]
                    elif cell.get("t") == "inlineStr":
                        value = "".join(cell.find("m:is", NS).itertext())
                    else:
                        node = cell.find("m:v", NS)
                        value = node.text if node is not None else ""
                    if value:
                        result[column].append(value)
    return result


def validate(pdf_path, workbook_path):
    schema = json.loads((HERE.parent / "atlas-shopping-list-xlsx-v1.schema.json").read_text(encoding="utf-8"))
    fixture = json.loads((HERE / "atlas-shopping-list-v1.fixture.json").read_text(encoding="utf-8"))
    layout = schema["x-atlas-layout"]["print"]
    gate = schema["x-atlas-print-certification"]
    expected = expected_cells(workbook_path, len(fixture["daily_batches"]))
    row_title_dates = ["/".join(reversed(row["service_date"].split("-"))) for row in fixture["rows"]]
    actual = {column: [] for column in "ABCDE"}
    body_sizes = []
    row_counts = []
    with pdfplumber.open(pdf_path) as document:
        for page in document.pages:
            assert abs(page.width - 595.32) < 1 and abs(page.height - 841.92) < 1, "A4 portrait PDF"
            bounds = groups(round(edge["x0"], 2) for edge in page.edges if edge["height"] > 40)
            assert len(bounds) == 6, "All five columns on one horizontal page"
            horizontal = groups(round(edge["top"], 2) for edge in page.edges
                                if edge["orientation"] == "h" and edge["width"] > 20)
            assert len(horizontal) >= 2, "Date/header/table boundaries"
            repeated_header = norm(page.crop((0, 0, page.width, horizontal[1])).extract_text() or "")
            assert f"({row_title_dates[sum(row_counts)]})" in repeated_header, "Repeated date title for these rows"
            for heading in ["TRƯỜNG", "THÀNH PHẦN", "ĐVT", "SỐ LƯỢNG", "GHI CHÚ"]:
                assert norm(heading) in repeated_header, "Repeated complete column heading"
            body_top = horizontal[1] + 0.5
            for index, column in enumerate("ABCDE"):
                crop = page.crop((bounds[index] + 0.1, body_top, bounds[index + 1] - 0.1, page.height - 30))
                # Exclude the small footer; body and Supplier are >=14 pt here.
                content = crop.filter(lambda item: item.get("object_type") != "char" or item["size"] > 14)
                value = content.extract_text() or ""
                assert "#" not in value, "No hashed quantities or clipped-number fallback"
                actual[column].append(value if column == "D" else norm(value))
                if column in "CD":
                    body_sizes.extend(char["size"] for char in content.chars)
                if column == "D":
                    row_counts.append(len(re.findall(r"\d+(?:[,\.]\d+)?", value)))
            assert not re.search(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", page.extract_text() or ""), "Hidden identities do not print"
        for column in "ABCE":
            assert "".join(actual[column]) == "".join(map(norm, expected[column])), f"Complete, ordered visible {column} content"
        quantities = [token for value in actual["D"] for token in re.findall(r"\d+(?:[,\.]\d+)?", value)]
        assert Counter(Decimal(value.replace(",", ".")) for value in quantities) == Counter(map(Decimal, expected["D"])), "Every exact quantity visible"
        assert sum(row_counts) == len(fixture["rows"]), "Every-and-only printed row set"
        effective_body = min(body_sizes)
        observed_scale = effective_body / layout["bodyFontPt"] * 100
        assert effective_body >= gate["minimumEffectiveBodyPt"], "Native effective body font floor"
        assert observed_scale >= gate["minimumPrintScalePercent"], "Observed native print scale floor"
        return {"pages": len(document.pages), "rows_per_page": row_counts,
                "configured_scale_percent": layout["scalePercent"], "observed_scale_percent": round(observed_scale, 2),
                "effective_body_pt": round(effective_body, 2), "hashes": 0,
                "complete_visible_columns": "A:E", "quantities": len(quantities)}


if __name__ == "__main__":
    pdf = Path(sys.argv[1])
    workbook = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "atlas-shopping-list-v1-example.xlsx"
    print("PASS native print evidence: " + json.dumps(validate(pdf, workbook), sort_keys=True))
