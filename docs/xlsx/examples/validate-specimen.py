"""Static specimen conformance and negative controls. This is NOT an importer.

No application dependencies, network, business commands, or draft application.
The closed schema vocabulary is evaluated with the standard library; this is
not a general-purpose JSON Schema engine.
"""

import copy
from datetime import date, datetime
from decimal import Decimal
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import re
from uuid import UUID
import xml.etree.ElementTree as ET
from zipfile import ZipFile

HERE = Path(__file__).parent
FIXTURE = json.loads((HERE / "atlas-shopping-list-v1.fixture.json").read_text(encoding="utf-8"))
SCHEMA = json.loads((HERE.parent / "atlas-shopping-list-xlsx-v1.schema.json").read_text(encoding="utf-8"))
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def text(cell, strings):
    if cell is None:
        return ""
    kind = cell.get("t")
    if kind == "s":
        return strings[int(cell.find("m:v", NS).text)]
    if kind == "inlineStr":
        return "".join(node.text or "" for node in cell.findall(".//m:t", NS))
    value = cell.find("m:v", NS)
    return value.text if value is not None else ""


def verify_presentation(fixture):
    """Reject genuinely ambiguous canonical displays before specimen export."""
    seen = {}
    for row in fixture["rows"]:
        key = (row["service_date"], row["school_name"], row["ingredient_name"], row["unit_display"])
        identity = (row["school_id"], row["ingredient_id"], row["unit_id"])
        require(key not in seen or seen[key] == identity, "Ambiguous displayed business identities must block export")
        seen[key] = identity


def preferred_supplier(row, fixture=None):
    fixture = FIXTURE if fixture is None else fixture
    suppliers = {item["supplier_id"]: item for item in fixture["suppliers"]}
    candidates = sorted(
        (
            item for item in fixture["supplier_eligibilities"]
            if item["ingredient_id"] == row["ingredient_id"]
            and item["eligibility_status"] == "ACTIVE"
            and item["effective_from"] <= row["service_date"]
            and (item["effective_to"] is None or row["service_date"] < item["effective_to"])
            and suppliers[item["supplier_id"]]["supplier_status"] == "ACTIVE"
        ),
        key=lambda item: item["priority"],
    )
    if not candidates or (len(candidates) > 1 and candidates[0]["priority"] == candidates[1]["priority"]):
        return ""
    return suppliers[candidates[0]["supplier_id"]]["supplier_name"]


def print_content(row, fixture):
    """QA display metric, never an identity key or runtime business constraint."""
    quantity = row["exact_quantity"]
    if "." in quantity:
        quantity = quantity.rstrip("0").rstrip(".")
    return {"school": row["school_name"], "school_display": row["school_name"],
            "ingredient": row["ingredient_name"], "supplier": preferred_supplier(row, fixture),
            "quantity": quantity, "unit": row["unit_display"]}


def combined_print_chars(content):
    return sum(len(content[key].replace("\n", "")) for key in
               ["school_display", "ingredient", "supplier", "quantity", "unit"])


def within_print_envelope(content):
    envelope = SCHEMA["x-atlas-print-certification"]
    return (all(len(content[key]) <= limit for key, limit in envelope["fieldMaxChars"].items())
            and combined_print_chars(content) <= envelope["combinedCharEnvelope"])


def verify_print_certification(fixture):
    cert = fixture["print_certification"]
    envelope = SCHEMA["x-atlas-print-certification"]
    require(envelope["qaOnly"] and not envelope["runtimeBusinessConstraint"], "Print envelope is QA only")
    require(cert["combined_char_envelope"] == envelope["combinedCharEnvelope"] == 84, "84-character QA envelope")
    require(cert["field_envelopes"] == envelope["fieldMaxChars"], "Matching independent field envelopes")
    snapshot = cert["observed_snapshot"]
    require((snapshot["row_count"], snapshot["p95_combined"], snapshot["p99_combined"], snapshot["max_combined"]) ==
            (248, 58, 65.53, 67), "Supplied calibration snapshot, not a hosted read or runtime rule")
    require(cert["guard_band_percent"] == envelope["guardBandPercent"] == 25, "25-percent design guard band")
    require(cert["combined_char_envelope"] == (snapshot["max_combined"] * 125 + 99) // 100, "Ceiling of guarded maximum")
    by_id = {row["confirmed_need_line_id"]: row for row in fixture["rows"]}
    cases = cert["stress_lines"]
    require(set(cases) == {"school", "ingredient", "supplier", "quantity", "composite"}, "All five visible stress cases")
    contents = {key: print_content(by_id[value], fixture) for key, value in cases.items()}
    for key in ["school", "ingredient", "supplier", "quantity"]:
        require(envelope["fieldMaxChars"][key] - 1 <= len(contents[key][key]) <= envelope["fieldMaxChars"][key],
                f"Independent {key} boundary stress")
    require(75 <= combined_print_chars(contents["composite"]) <= 84, "True 75–84-character composite stress")
    require(len(contents["school"]["ingredient"]) <= 16 and len(contents["school"]["supplier"]) <= 12, "School stress uses ordinary other labels")
    for key in ["ingredient", "supplier", "quantity"]:
        require(len(contents[key]["school"]) <= 16, f"{key} stress has an ordinary School")
    require(len(contents["ingredient"]["supplier"]) <= 12 and len(contents["ingredient"]["quantity"]) <= 4, "Ingredient stress is isolated")
    require(len(contents["supplier"]["ingredient"]) <= 16 and len(contents["supplier"]["quantity"]) <= 4, "Supplier stress is isolated")
    require(len(contents["quantity"]["ingredient"]) <= 16 and len(contents["quantity"]["supplier"]) <= 12, "Quantity stress is isolated")
    all_contents = [print_content(row, fixture) for row in fixture["rows"]]
    require(all(within_print_envelope(content) for content in all_contents), "Every normal fixture row is inside the certified QA envelope")
    require(not any(all(len(content[key]) >= limit - 1 for key, limit in envelope["fieldMaxChars"].items())
                    for content in all_contents), "No artificial all-maxima composite")
    control = cert["out_of_envelope_control"]
    require(control["name"] == "OUT_OF_CERTIFIED_PRINT_ENVELOPE", "Named isolated overflow control")
    outside = {"school": control["school_display"], "school_display": control["school_display"],
               "ingredient": control["ingredient_name"], "supplier": control["supplier_name"],
               "unit": control["unit_display"], "quantity": control["quantity"]}
    require(len(outside["ingredient"]) == 68 and len(outside["supplier"]) == 46, "Retained isolated extreme concepts")
    require(not within_print_envelope(outside), "Detector recognizes out-of-certified content without changing normal geometry")
    return {"max_combined_chars": max(map(combined_print_chars, all_contents)),
            "stress_combined_chars": {key: combined_print_chars(content) for key, content in contents.items()},
            "out_of_envelope_combined_chars": combined_print_chars(outside)}


def verify(files):
    print_gate = SCHEMA["x-atlas-layout"]["print"]
    require(print_gate["normalRowPt"] <= 30, "Normal rows <=30 pt")
    require(print_gate["wrappedRowPt"] <= 44 and print_gate["bodyHardCapPt"] <= 44,
            "Wrapped and absolute body rows <=44 pt")
    require("multiLocationRowPt" not in print_gate, "No Location presentation row class")
    date_count = len(FIXTURE["daily_batches"])
    allowed_parts = {
        "[Content_Types].xml", "_rels/.rels", "xl/_rels/workbook.xml.rels",
        "xl/workbook.xml", "xl/styles.xml", "xl/sharedStrings.xml", "xl/theme/theme1.xml",
        *[f"xl/worksheets/sheet{i}.xml" for i in range(1, date_count + 2)],
        *[f"xl/worksheets/_rels/sheet{i}.xml.rels" for i in range(1, date_count + 1)],
        *[f"xl/tables/table{i}.xml" for i in range(1, date_count + 1)],
    }
    require(set(files) == allowed_parts, "Exact allowed synthetic specimen OPC part set")
    allowed_relationships = {
        "officeDocument", "worksheet", "styles", "sharedStrings", "theme", "table",
    }
    rel_base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
    for name, value in files.items():
        if name.endswith(".rels"):
            for relation in ET.fromstring(value):
                require(relation.get("TargetMode", "Internal") == "Internal", "No external relationships")
                require(relation.get("Type", "") in {rel_base + kind for kind in allowed_relationships}, "No forbidden relationship types")
    content_types = ET.fromstring(files["[Content_Types].xml"])
    allowed_content_types = {
        "application/vnd.openxmlformats-package.relationships+xml", "application/xml",
        *[f"application/vnd.openxmlformats-officedocument.spreadsheetml.{kind}+xml" for kind in ["sheet.main", "worksheet", "styles", "sharedStrings", "table"]],
        "application/vnd.openxmlformats-officedocument.theme+xml",
    }
    require(all(node.get("ContentType") in allowed_content_types for node in content_types), "Only allowed XLSX content types")
    roots = {name: ET.fromstring(value) for name, value in files.items() if name.endswith(".xml")}
    strings_root = roots.get("xl/sharedStrings.xml")
    strings = [] if strings_root is None else ["".join(node.text or "" for node in item.findall(".//m:t", NS)) for item in strings_root]
    wb = roots["xl/workbook.xml"]
    dates = sorted({row["service_date"] for row in FIXTURE["rows"]})
    sheets = wb.find("m:sheets", NS)
    require([sheet.get("name") for sheet in sheets] == dates + ["_ATLAS_META"], "Exact date/meta sheet set")
    require(sheets[-1].get("state") == "veryHidden", "Very-hidden metadata")
    require(wb.find("m:workbookProtection", NS).get("lockStructure") == "1", "Workbook structure protection")
    require(not any("vba" in name.lower() or "externallink" in name.lower() for name in files), "No VBA/external links")
    style_root = roots["xl/styles.xml"]
    styles = style_root.find("m:cellXfs", NS)
    fonts = style_root.find("m:fonts", NS)
    fills = style_root.find("m:fills", NS)
    borders = style_root.find("m:borders", NS)
    visible = SCHEMA["x-atlas-layout"]["visibleHeaders"]
    hidden = SCHEMA["x-atlas-layout"]["hiddenHeaders"]
    print_layout = SCHEMA["x-atlas-layout"]["print"]
    print_cases = FIXTURE["print_cases"]
    height_counts = {"normal": 0, "wrapped": 0}
    all_body_heights = []
    printed_pages = []
    projected = []
    for index, date in enumerate(dates, 1):
        sheet = roots[f"xl/worksheets/sheet{index}.xml"]
        require(not sheet.findall(".//m:f", NS), "No formulas")
        rows = [row for row in FIXTURE["rows"] if row["service_date"] == date]
        end = len(rows) + 3
        table = roots[f"xl/tables/table{index}.xml"]
        require(table.get("name") == f"AtlasNeed_{date.replace('-', '')}", "Table name")
        require(table.get("ref") == f"A3:O{end}", "Full identity-bound Table range")
        require(table.find("m:autoFilter", NS).get("ref") == f"A3:O{end}", "Whole Table filter")
        require([col.get("name") for col in table.find("m:tableColumns", NS)] == visible + hidden, "Exact Table columns")
        require(table.find("m:tableStyleInfo", NS).get("showRowStripes") == "0", "Restrained table styling")
        cells = {cell.get("r"): cell for cell in sheet.findall(".//m:c", NS)}
        require(len(files[f"xl/worksheets/sheet{index}.xml"]) < 250_000, "Bounded worksheet XML")
        require(len(cells) <= 15 * (end + 1), "Bounded used range")
        for address, cell in cells.items():
            if text(cell, strings):
                match = re.fullmatch(r"([A-Z]+)([0-9]+)", address)
                require(match is not None, "Canonical cell address")
                column, row_number = match.group(1), int(match.group(2))
                require(len(column) == 1 and "A" <= column <= "O" and 1 <= row_number <= end, "No nonempty out-of-region cells")
                if row_number < 3:
                    require(column == "A" and row_number == 1, "Only quiet date title above headings")
        require([text(cells.get(f"{chr(65 + col)}3"), strings) for col in range(15)] == visible + hidden, "Exact header cells")
        require(text(cells.get("A1"), strings).endswith(date.split("-")[2] + "/" + date.split("-")[1] + "/" + date.split("-")[0] + ")"), "Date title")
        for address in ["A1", "A3", "B3", "C3", "D3", "E3"]:
            cell = cells[address]
            xf = styles[int(cell.get("s", "0"))]
            font = fonts[int(xf.get("fontId", "0"))]
            require(font.find("m:name", NS).get("val") == "Times New Roman", "Title/header Times font")
            require(font.find("m:b", NS) is not None, "Title/header bold")
            expected_size = print_layout["titleFontPt"] if address == "A1" else print_layout["headerFontPt"]
            require(float(font.find("m:sz", NS).get("val")) == expected_size, "Title/header size hierarchy")
            require(font.find("m:color", NS).get("rgb") == "FF000000", "Title/header black")
            fill = fills[int(xf.get("fillId", "0"))].find("m:patternFill", NS)
            fg = fill.find("m:fgColor", NS) if fill is not None else None
            require(fg is None or fg.get("rgb") == "FFFFFFFF", "Title/header white/no fill")
            if address.endswith("3"):
                border = borders[int(xf.get("borderId", "0"))]
                require(
                    border.find("m:top", NS).get("style") == "medium"
                    and border.find("m:bottom", NS).get("style") == "medium",
                    "Strong black heading rules",
                )
        data_rows = sheet.find("m:sheetData", NS).findall("m:row", NS)
        require([int(row.get("r")) for row in data_rows if int(row.get("r")) >= 4 and any(text(cell, strings) for cell in row)] == list(range(4, end + 1)), "Complete data rows")
        title_row = next(item for item in data_rows if item.get("r") == "1")
        spacer_row = next(item for item in data_rows if item.get("r") == "2")
        header_row = next(item for item in data_rows if item.get("r") == "3")
        require(float(title_row.get("ht")) == print_layout["titleRowPt"], "Compact title height")
        require(float(spacer_row.get("ht")) == print_layout["spacerRowPt"], "Controlled title spacing")
        require(float(header_row.get("ht")) == print_layout["headerRowPt"], "Compact header height")
        row_heights = {int(item.get("r")): float(item.get("ht", "0")) for item in data_rows if int(item.get("r")) >= 4}
        all_body_heights.extend(row_heights.values())
        require(max(row_heights.values()) <= print_layout["bodyHardCapPt"], "Hard body height cap")
        seen = set()
        by_id = {row["confirmed_need_line_id"]: row for row in rows}
        break_ids = [int(node.get("id")) for node in sheet.findall("m:rowBreaks/m:brk", NS)]
        continuation_rows = {
            break_id + 1 for break_id in break_ids
            if 4 <= break_id < end
            and rows[break_id - 3]["school_id"] == rows[break_id - 4]["school_id"]
        }
        for row_index in range(4, end + 1):
            values = [text(cells.get(f"{chr(65 + col)}{row_index}"), strings) for col in range(15)]
            row_id = values[6]
            require(row_id in by_id and row_id not in seen, "Unknown/duplicate line")
            seen.add(row_id)
            row = by_id[row_id]
            supplier = preferred_supplier(row)
            expected_hidden = [FIXTURE["metadata"]["workbook_marker"], row_id, row["current_revision_id"], row["current_decision_id"] or "", date, row["school_id"], row["delivery_location_id"], row["ingredient_id"], row["unit_id"], row["exact_quantity"]]
            require(values[5:] == expected_hidden, "Canonical row-bound evidence")
            first_in_school = row_index == 4 or rows[row_index - 5]["school_id"] != row["school_id"]
            expected_school = row["school_name"] if first_in_school else ""
            if row_index in continuation_rows:
                expected_school = f'{row["school_name"]} (tiếp)'
            require(values[:3] == [expected_school, row["ingredient_name"], row["unit_display"]], "Canonical visible labels, School name only")
            require("Điểm giao" not in values[0] and "Delivery Location" not in values[0], "No Location/address in School text")
            require(not values[2].startswith("v1-unit-"), "Operator-facing Unit, not a migration identifier")
            starts_school = first_in_school or row_index in continuation_rows
            if (row_index in continuation_rows or row["ingredient_id"] in print_cases["wrapped_ingredient_ids"]
                  or any(item["supplier_id"] in print_cases["wrapped_supplier_ids"] and item["supplier_name"] == supplier for item in FIXTURE["suppliers"])
                  or (starts_school and row["school_id"] in print_cases["wrapped_school_ids"])):
                height_class = "wrapped"
            else:
                height_class = "normal"
            expected_height = print_layout[{"normal": "normalRowPt", "wrapped": "wrappedRowPt"}[height_class]]
            require(row_heights[row_index] == expected_height, f"Bounded {height_class} row height at {date} {row_index}")
            height_counts[height_class] += 1
            if expected_school:
                xf = styles[int(cells[f"A{row_index}"].get("s", "0"))]
                require(fonts[int(xf.get("fontId", "0"))].find("m:b", NS) is not None, "First/continued School bold")
            require(Decimal(values[3]) == Decimal(row["exact_quantity"]), "Exact quantity XML")
            require(values[4] == supplier, "Only first eligible supplier suggestion")
            for col in range(15):
                cell = cells[f"{chr(65 + col)}{row_index}"]
                protection = styles[int(cell.get("s", "0"))].find("m:protection", NS)
                is_unlocked = protection is not None and protection.get("locked") == "0"
                require(is_unlocked == (col in [3, 4]), "Only D/E editable")
                if col >= 5:
                    require(cell.get("t") in ["s", "inlineStr"], "Hidden evidence stored as text")
                else:
                    xf = styles[int(cell.get("s", "0"))]
                    font = fonts[int(xf.get("fontId", "0"))]
                    require(font.find("m:name", NS).get("val") == "Times New Roman", "Print font")
                    expected_size = print_layout[
                        "supplierFontPt" if col == 4 else ("quantityFontPt" if col == 3 else ("schoolFontPt" if col == 0 and expected_school else "bodyFontPt"))
                    ]
                    require(float(font.find("m:sz", NS).get("val")) == expected_size, "Column typography")
                    color = font.find("m:color", NS)
                    require(color is not None and color.get("rgb") == "FF000000", "Black print text")
                    alignment = xf.find("m:alignment", NS)
                    require(alignment is not None and alignment.get("vertical") == "center", "Centered row baseline")
                    require((alignment.get("wrapText") == "1") == (col in [0, 1, 4]), "Controlled wrap columns")
                    fill = fills[int(xf.get("fillId", "0"))].find("m:patternFill", NS)
                    fg = fill.find("m:fgColor", NS) if fill is not None else None
                    require(fg is None or fg.get("rgb") == "FFFFFFFF", "White/no printed fill")
                    border = borders[int(xf.get("borderId", "0"))]
                    top = border.find("m:top", NS)
                    if col == 0:
                        require(border.find("m:left", NS).get("style") == "medium", "Medium outer left edge")
                    if col == 4:
                        require(border.find("m:right", NS).get("style") == "medium", "Medium outer right edge")
                    if row_index == end:
                        require(border.find("m:bottom", NS).get("style") == "medium", "Medium outer bottom edge")
                    if first_in_school:
                        require(top is not None and top.get("style") == "medium", f"Strong School start at {date} {cell.get('r')}")
                    elif col == 0 and row_index not in continuation_rows:
                        require(top is None or top.get("style") in (None, "thin"), "Ordinary line weight")
            projected.append(dict(zip(["school_display", "ingredient_name", "unit_display", "quantity", "note"] + hidden, values)))
        require(seen == set(by_id), "Every-and-only line set")
        require([text(cells[f"G{row_index}"], strings) for row_index in range(4, end + 1)] == [row["confirmed_need_line_id"] for row in rows], "Deterministic specimen export order")
        cols = sheet.find("m:cols", NS)
        require(any(col.get("min") == "6" and col.get("max") == "15" and col.get("hidden") == "1" for col in cols), "Hidden F:O")
        for col_index, expected in enumerate(print_layout["columnWidths"], 1):
            match = [col for col in cols if int(col.get("min")) <= col_index <= int(col.get("max"))]
            require(len(match) == 1 and abs(float(match[0].get("width")) - expected) < 0.01, "A4 column proportions")
        pane = sheet.find(".//m:pane", NS)
        require(pane.get("ySplit") == "3" and pane.get("state") == "frozen", "Frozen header")
        require([node.get("ref") for node in sheet.findall("m:mergeCells/m:mergeCell", NS)] == ["A1:E1"], "No merged data cells")
        protection = sheet.find("m:sheetProtection", NS)
        require(protection.get("sheet") == "1" and protection.get("autoFilter") == "0" and protection.get("sort") == "1", "Protected filter; sort denied")
        require(protection.get("selectLockedCells") == "0" and protection.get("selectUnlockedCells") == "0", "Both cell selections allowed")
        setup = sheet.find("m:pageSetup", NS)
        require(setup.get("paperSize") == "9" and setup.get("orientation") == "portrait"
                and setup.get("scale") == str(print_layout["scalePercent"])
                and setup.get("fitToWidth") is None and setup.get("fitToHeight") is None, "Portrait A4 explicit scale")
        require(sheet.find("m:sheetPr/m:pageSetUpPr", NS).get("fitToPage") == "0", "No automatic fit-to-width")
        gate = SCHEMA["x-atlas-print-certification"]
        require(print_layout["scalePercent"] >= gate["minimumPrintScalePercent"]
                and print_layout["bodyFontPt"] * print_layout["scalePercent"] / 100 >= gate["minimumEffectiveBodyPt"],
                "Authored scale floor; native PDF must independently confirm it")
        margins = sheet.find("m:pageMargins", NS)
        for side in ["left", "right", "top", "bottom"]:
            require(float(margins.get(side)) == print_layout[f"{side}MarginIn"], "Centralized A4 margins")
        if index == 1:
            require(continuation_rows, "Large-group continuation")
        else:
            require(not break_ids, "Second-date fixture remains one page")
        body_budget = (
            print_layout["a4HeightPt"]
            - 72 * (print_layout["topMarginIn"] + print_layout["bottomMarginIn"])
            - print_layout["footerAllowancePt"]
            - print_layout["titleRowPt"]
            - print_layout["spacerRowPt"]
            - print_layout["headerRowPt"]
        )
        for first, last in zip([4] + [value + 1 for value in break_ids], break_ids + [end]):
            used = sum(row_heights[row_number] for row_number in range(first, last + 1))
            scaled = used * print_layout["pageHeightScaleUpperBound"]
            require(scaled <= body_budget + 0.01, "Printed page respects fitted A4 body budget")
            printed_pages.append({"date": date, "rows": last - first + 1, "body_pt": used, "scaled_body_pt": round(scaled, 2), "blank_pt": round(body_budget - scaled, 2)})
        definitions = {node.get("name"): node.text for node in wb.findall("m:definedNames/m:definedName", NS) if node.get("localSheetId") == str(index - 1)}
        require(definitions.get("_xlnm.Print_Area") == f"'{date}'!$A$1:$E${end}", "Visible print area")
        require(definitions.get("_xlnm.Print_Titles") == f"'{date}'!$1:$3", "Repeat date/header on pages")
    meta = roots[f"xl/worksheets/sheet{len(dates) + 1}.xml"]
    require(not meta.findall(".//m:f", NS), "No metadata formulas")
    require(meta.find("m:sheetProtection", NS) is not None, "Protected metadata")
    meta_cells = {cell.get("r"): cell for cell in meta.findall(".//m:c", NS)}
    allowed_meta_addresses = {f"{column}{row}" for row in range(1, 7) for column in "AB"} | {f"{column}{row}" for row in range(8, 9 + len(dates)) for column in "ABCDE"}
    require(all(address in allowed_meta_addresses for address, cell in meta_cells.items() if text(cell, strings)), "No nonempty metadata extras")
    pairs = [(text(meta_cells.get(f"A{i}"), strings), text(meta_cells.get(f"B{i}"), strings)) for i in range(1, 7)]
    require(pairs == [(key, str(value)) for key, value in FIXTURE["metadata"].items()], "Exact metadata contract")
    normalized_meta = dict(pairs)
    daily_headers = ["service_date", "confirmed_need_batch_id", "batch_version", "need_generation_run_id", "release_snapshot_id"]
    require([text(meta_cells.get(f"{column}8"), strings) for column in "ABCDE"] == daily_headers, "Exact daily authority headers")
    daily_batches = []
    for index, expected in enumerate(FIXTURE["daily_batches"], 9):
        batch = dict(zip(daily_headers, [text(meta_cells.get(f"{column}{index}"), strings) for column in "ABCDE"]))
        require(batch == {key: str(value) for key, value in expected.items()}, "Exact per-date batch evidence")
        batch["batch_version"] = int(batch["batch_version"])
        daily_batches.append(batch)
    require([batch["service_date"] for batch in daily_batches] == dates, "One batch per date sheet")
    require(len(set(all_body_heights)) <= 2, "At most two body heights")
    require(max(all_body_heights) <= 44 and not ({72, 168} & set(all_body_heights)), "No giant body rows")
    require(height_counts["normal"] / len(all_body_heights) >= 0.8, "At least 80% normal-height rows")
    return {"metadata": normalized_meta, "daily_batches": daily_batches, "rows": projected, "print_metrics": {
        "normal_row_count": height_counts["normal"],
        "wrapped_row_count": height_counts["wrapped"],
        "distinct_body_heights": len(set(all_body_heights)),
        "min_body_height": min(all_body_heights),
        "max_body_height": max(all_body_heights),
        "body_budget_pt": round(body_budget, 2),
        "pages": printed_pages,
    }}


def change_cell(files, sheet_path, address, value):
    root = ET.fromstring(files[sheet_path])
    cell = root.find(f'.//m:c[@r="{address}"]', NS)
    if cell is None:
        data = root.find("m:sheetData", NS)
        row_number = re.search(r"[0-9]+$", address).group(0)
        row = data.find(f'm:row[@r="{row_number}"]', NS)
        if row is None:
            row = ET.SubElement(data, f"{{{NS['m']}}}row", r=row_number)
        cell = ET.SubElement(row, f"{{{NS['m']}}}c", r=address)
    for child in list(cell):
        cell.remove(child)
    cell.set("t", "inlineStr")
    ET.SubElement(ET.SubElement(cell, f"{{{NS['m']}}}is"), f"{{{NS['m']}}}t").text = value
    files[sheet_path] = ET.tostring(root)


def verify_location_invariance(original_path, probe_path):
    """Compare independently regenerated XLSX files with changed hidden locations."""
    def signature(path):
        with ZipFile(path) as archive:
            strings = ["".join(item.itertext()) for item in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
            visible = []
            locations = []
            for index in range(1, len(FIXTURE["daily_batches"]) + 1):
                sheet = ET.fromstring(archive.read(f"xl/worksheets/sheet{index}.xml"))
                cells = {cell.get("r"): cell for cell in sheet.findall(".//m:c", NS)}
                visible.append({
                    "cells": [(address, text(cell, strings), cell.get("s")) for address, cell in cells.items() if address[0] in "ABCDE"],
                    "heights": [(row.get("r"), row.get("ht")) for row in sheet.findall("m:sheetData/m:row", NS)],
                    "print": [ET.tostring(sheet.find(f"m:{key}", NS)) for key in
                              ["cols", "sheetPr", "pageMargins", "pageSetup", "rowBreaks", "headerFooter", "mergeCells"]],
                })
                locations.extend(text(cell, strings) for address, cell in cells.items() if address.startswith("L") and int(address[1:]) >= 4)
            return visible, locations, archive.read("xl/styles.xml")
    original, original_locations, original_styles = signature(original_path)
    probe, probe_locations, probe_styles = signature(probe_path)
    require(original_locations != probe_locations, "Invariance probe actually changes hidden Location identities")
    require(original == probe and original_styles == probe_styles,
            "Changing hidden locations leaves visible cells, School borders, row heights, widths, wrapping and page setup/breaks identical")
    print("PASS LOCATION_INVARIANCE: independently regenerated visible/print signatures are identical.")


def check_schema(value, rule):
    """Evaluate only the JSON Schema vocabulary used in this closed fixture schema.

    This is not a general-purpose JSON Schema engine or production validator.
    """
    if "$ref" in rule:
        resolved = SCHEMA
        for part in rule["$ref"].split("/")[1:]:
            resolved = resolved[part]
        return check_schema(value, resolved)
    if "oneOf" in rule:
        passed = 0
        for option in rule["oneOf"]:
            try:
                check_schema(value, option)
                passed += 1
            except (AssertionError, ValueError):
                pass
        require(passed == 1, "Schema oneOf")
    if "const" in rule:
        require(value == rule["const"], "Schema const")
    if "enum" in rule:
        require(value in rule["enum"], "Schema enum")
    kind = rule.get("type")
    if kind == "object":
        require(isinstance(value, dict), "Schema object")
        require(set(rule.get("required", [])) <= set(value), "Schema required keys")
        if rule.get("additionalProperties") is False:
            require(set(value) <= set(rule["properties"]), "Schema closed keys")
        for key, item in value.items():
            check_schema(item, rule["properties"][key])
    elif kind == "array":
        require(isinstance(value, list) and rule.get("minItems", 0) <= len(value) <= rule.get("maxItems", len(value)), "Schema array bounds")
        for item in value:
            check_schema(item, rule["items"])
    elif kind == "integer":
        require(type(value) is int and value >= rule.get("minimum", value), "Schema integer/minimum")
    elif kind == "string":
        require(isinstance(value, str), "Schema string")
        require(rule.get("minLength", 0) <= len(value) <= rule.get("maxLength", len(value)), "Schema string length")
        if "pattern" in rule:
            require(re.fullmatch(rule["pattern"], value) is not None, "Schema pattern")
        fmt = rule.get("format")
        if fmt == "uuid":
            UUID(value)
        elif fmt == "date":
            date.fromisoformat(value)
        elif fmt == "date-time":
            require(datetime.fromisoformat(value.replace("Z", "+00:00")).tzinfo is not None, "Schema zoned timestamp")


def validate_daily_currentness(workbook, authority, containing_sheet_dates=None, local_dirty_dates=None):
    """Isolated contract model: validate every date before returning quantity proposals."""
    dates = [batch["service_date"] for batch in workbook["daily_batches"]]
    require(dates == sorted(set(dates)) == sorted(authority["batches"]), "Exact daily sheet/batch set")
    require(not (set(dates) & set(local_dirty_dates or [])), "Do not overwrite an unsaved local draft")
    require(workbook["metadata"]["service_period_start"] == dates[0] and workbook["metadata"]["service_period_end"] == dates[-1], "Exact collection bounds")
    rows_by_date = {day: [] for day in dates}
    for row in workbook["rows"]:
        day = row["__service_date"]
        require(day in rows_by_date, "Row bound to represented date")
        if containing_sheet_dates is not None:
            require(containing_sheet_dates[row["__line_id"]] == day, "Row remains on its bound date sheet")
        rows_by_date[day].append(row)
    proposals = {}
    for batch in workbook["daily_batches"]:
        day = batch["service_date"]
        require(batch == authority["batches"][day], "Fresh daily batch/version/source evidence")
        expected = authority["lines"][day]
        seen = set()
        for row in rows_by_date[day]:
            line_id = row["__line_id"]
            require(line_id in expected and line_id not in seen, "Every-and-only daily line")
            seen.add(line_id)
            current = expected[line_id]
            for key in ["__workbook_marker", "__revision_id", "__decision_id", "__service_date", "__school_id", "__location_id", "__ingredient_id", "__unit_id", "__exported_quantity"]:
                require(row[key] == current[key], "Fresh row identity/revision/quantity evidence")
            if Decimal(row["quantity"].replace(",", ".")) != Decimal(current["__exported_quantity"]):
                proposals[line_id] = row["quantity"]
        require(seen == set(expected), "Complete daily row set")
    return proposals


def current_authority(normalized):
    return {
        "batches": {batch["service_date"]: copy.deepcopy(batch) for batch in normalized["daily_batches"]},
        "lines": {
            day: {row["__line_id"]: copy.deepcopy(row) for row in normalized["rows"] if row["__service_date"] == day}
            for day in [batch["service_date"] for batch in normalized["daily_batches"]]
        },
    }


def export_allowed(local_draft_dirty):
    return not local_draft_dirty


def main(path):
    verify_presentation(FIXTURE)
    with ZipFile(path) as archive:
        require(archive.testzip() is None, "Healthy ZIP")
        files = {name: archive.read(name) for name in archive.namelist()}
    normalized = verify(files)
    check_schema({key: normalized[key] for key in ["metadata", "daily_batches", "rows"]}, SCHEMA)
    # Negative controls test the static conformance validator, not production import.
    sheet = "xl/worksheets/sheet1.xml"
    controls = [
        (sheet, "A4", "Trường khác"), (sheet, "B4", "Hàng khác"),
        (sheet, "C4", "ĐVT khác"), (sheet, "D4", "1.234568"),
        (sheet, "F4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "G4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "G5", normalized["rows"][0]["__line_id"]),
        (sheet, "H4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "I4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "J4", "2026-04-21"), (sheet, "N4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "K4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "L4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "M4", "00000000-0000-0000-0000-000000009999"),
        (sheet, "O4", "9.123456"),
        ("xl/worksheets/sheet4.xml", "B2", "ATLAS_SHOPPING_LIST_V2"),
        ("xl/worksheets/sheet4.xml", "B10", "9"),
        ("xl/worksheets/sheet4.xml", "B11", "00000000-0000-0000-0000-000000009999"),
        ("xl/worksheets/sheet4.xml", "B5", "2026-04-19"),
        ("xl/worksheets/sheet4.xml", "B6", "2026-04-23"),
        ("xl/worksheets/sheet4.xml", "C1", "unexpected metadata"),
        (sheet, "P4", "unexpected column"), (sheet, "A48", "unexpected row"),
        (sheet, "A3", "SL"),
    ]
    rejected = 0
    for sheet_path, address, value in controls:
        mutated = copy.copy(files)
        change_cell(mutated, sheet_path, address, value)
        try:
            verify(mutated)
        except AssertionError:
            rejected += 1
        else:
            raise AssertionError(f"Negative control unexpectedly passed: {address}")
    # Row removal and Table expansion are structural controls, not cell edits.
    structural_controls = ["delete", "expand", "external", "macro_type", "oversize", "height_drift", "missing_sheet", "extra_sheet"]
    for operation in structural_controls:
        mutated = copy.copy(files)
        target = {"delete": sheet, "expand": "xl/tables/table1.xml", "external": "xl/worksheets/_rels/sheet1.xml.rels", "macro_type": "[Content_Types].xml", "oversize": sheet, "height_drift": sheet, "missing_sheet": "xl/workbook.xml", "extra_sheet": "xl/workbook.xml"}[operation]
        root = ET.fromstring(mutated[target])
        if operation == "delete":
            data = root.find("m:sheetData", NS)
            data.remove(data.find('m:row[@r="4"]', NS))
        elif operation == "expand":
            root.set("ref", "A3:O44")
        elif operation == "external":
            root[0].set("TargetMode", "External")
            root[0].set("Target", "https://example.invalid/fixture-control")
        elif operation == "missing_sheet":
            sheets = root.find("m:sheets", NS)
            sheets.remove(sheets[1])
        elif operation == "extra_sheet":
            sheets = root.find("m:sheets", NS)
            sheets.append(copy.deepcopy(sheets[0]))
            sheets[-1].set("name", "2026-04-23")
        elif operation in ["oversize", "height_drift"]:
            root.find(f'm:sheetData/m:row[@r="{4 if operation == "oversize" else 5}"]', NS).set(
                "ht",
                str(SCHEMA["x-atlas-layout"]["print"]["bodyHardCapPt"] + 1)
                if operation == "oversize"
                else str(SCHEMA["x-atlas-layout"]["print"]["normalRowPt"] + 1),
            )
        else:
            root[0].set("ContentType", "application/vnd.ms-excel.sheet.macroEnabled.main+xml")
        mutated[target] = ET.tostring(root)
        try:
            verify(mutated)
        except AssertionError:
            rejected += 1
        else:
            raise AssertionError(f"Structural negative control passed: {operation}")
    ambiguous = copy.deepcopy(FIXTURE)
    for row in ambiguous["rows"]:
        if row["ingredient_name"] == "Cà rốt":
            row["ingredient_name"] = "Tỏi"
    try:
        verify_presentation(ambiguous)
    except AssertionError:
        rejected += 1
    else:
        raise AssertionError("Ambiguous canonical label control passed")
    changed_locations = copy.deepcopy(FIXTURE)
    for position, row in enumerate(changed_locations["rows"]):
        row["delivery_location_id"] = str(UUID(int=90000 + position))
        row["delivery_location_name"] = "UNPRINTED address " * 40
    verify_presentation(changed_locations)
    repeated_identity = copy.deepcopy(FIXTURE)
    repeated_identity["rows"].append({**repeated_identity["rows"][0],
        "confirmed_need_line_id": str(UUID(int=99990)), "delivery_location_id": str(UUID(int=99991))})
    verify_presentation(repeated_identity)
    require([print_content(row, changed_locations) for row in changed_locations["rows"]]
            == [print_content(row, FIXTURE) for row in FIXTURE["rows"]],
            "Location ID/name has zero visible envelope or ambiguity effect")
    finalizer_spec = importlib.util.spec_from_file_location("specimen_finalizer", HERE / "finalize-specimen.py")
    finalizer = importlib.util.module_from_spec(finalizer_spec)
    finalizer_spec.loader.exec_module(finalizer)
    page_breaks = finalizer.page_breaks
    print_layout = SCHEMA["x-atlas-layout"]["print"]
    for index, day in enumerate(sorted({row["service_date"] for row in FIXTURE["rows"]}), 1):
        data = ET.fromstring(files[f"xl/worksheets/sheet{index}.xml"]).find("m:sheetData", NS)
        original_rows = [row for row in FIXTURE["rows"] if row["service_date"] == day]
        changed_rows = [row for row in changed_locations["rows"] if row["service_date"] == day]
        require(page_breaks(original_rows, data, print_layout) == page_breaks(changed_rows, data, print_layout),
                "Location ID/name has zero School grouping or pagination effect")
    require(len(FIXTURE["rows"]) == 59 and len({row["school_id"] for row in FIXTURE["rows"]}) == 4, "Required daily and visible stress coverage")
    require(len(normalized["daily_batches"]) == 3 and len({batch["confirmed_need_batch_id"] for batch in normalized["daily_batches"]}) == 3, "Three independent daily batches")
    require(len({row["ingredient_id"] for row in FIXTURE["rows"]}) >= 8, "Ingredient coverage")
    first_date = [row for row in normalized["rows"] if row["__service_date"] == "2026-04-20"]
    reordered = list(reversed(first_date))
    by_id = {row["confirmed_need_line_id"]: row for row in FIXTURE["rows"]}
    require(
        all(
            row["__school_id"] == by_id[row["__line_id"]]["school_id"]
            and row["__location_id"] == by_id[row["__line_id"]]["delivery_location_id"]
            and row["__ingredient_id"] == by_id[row["__line_id"]]["ingredient_id"]
            and row["__unit_id"] == by_id[row["__line_id"]]["unit_id"]
            for row in reordered
        ),
        "Complete-row reorder retains independent identity",
    )
    require(preferred_supplier(FIXTURE["rows"][0]) == "Kho mẫu A", "One supplier")
    require(preferred_supplier(FIXTURE["rows"][1]) == "Kho mẫu D", "First of three eligible suppliers")
    require(preferred_supplier(FIXTURE["rows"][2]) == "Kho mẫu B", "Inactive first supplier skipped")
    require(preferred_supplier(FIXTURE["rows"][4]) == "Kho mẫu C", "Future first supplier skipped")
    require(preferred_supplier(FIXTURE["rows"][5]) == "Kho mẫu E", "Expired first supplier skipped")
    require(any(preferred_supplier(row) == "" for row in FIXTURE["rows"]), "No supplier gives clean blank")
    notes = {row["note"] for row in normalized["rows"]}
    require("Nhà cung cấp thay thế A" not in notes and "Nhà cung cấp thay thế B" not in notes, "Alternative suppliers not visible")
    authority = current_authority(normalized)
    require(validate_daily_currentness(normalized, authority) == {}, "Three current dates import unchanged after restart")
    edited = copy.deepcopy(normalized)
    edited["rows"][0]["quantity"] = "2"
    require(validate_daily_currentness(edited, authority) == {edited["rows"][0]["__line_id"]: "2"}, "Quantity edit imports after restart")
    note_only = copy.deepcopy(normalized)
    note_only["rows"][0]["note"] = "handwritten working note"
    require(validate_daily_currentness(note_only, authority) == {}, "GHI CHÚ edit produces no draft")
    edited["rows"][0]["note"] = "another working note"
    require(validate_daily_currentness(edited, authority) == {edited["rows"][0]["__line_id"]: "2"}, "Quantity plus GHI CHÚ equals quantity only")
    supplier_changed = copy.deepcopy(normalized)
    supplier_changed["rows"][0]["note"] = "Different current Supplier name"
    require(validate_daily_currentness(supplier_changed, authority) == {}, "Supplier suggestion drift alone does not stale import")
    try:
        validate_daily_currentness(normalized, authority, local_dirty_dates={"2026-04-21"})
    except AssertionError:
        rejected += 1
    else:
        raise AssertionError("Unsaved local draft import control passed")
    for scenario in ["stale_second_date", "wrong_daily_batch", "wrong_revision", "missing_row", "duplicate_row", "extra_row", "transplanted_row", "missing_daily_sheet", "extra_daily_sheet"]:
        candidate = copy.deepcopy(normalized)
        fresh = current_authority(normalized)
        if scenario == "stale_second_date":
            fresh["batches"]["2026-04-21"]["batch_version"] += 1
        elif scenario == "wrong_daily_batch":
            candidate["daily_batches"][1]["confirmed_need_batch_id"] = str(UUID(int=9999))
        elif scenario == "wrong_revision":
            fresh["lines"]["2026-04-21"][next(iter(fresh["lines"]["2026-04-21"]))]["__revision_id"] = str(UUID(int=9999))
        elif scenario == "missing_row":
            candidate["rows"].pop(0)
        elif scenario == "duplicate_row":
            candidate["rows"].append(copy.deepcopy(candidate["rows"][0]))
        elif scenario == "extra_row":
            candidate["rows"].append({**candidate["rows"][0], "__line_id": str(UUID(int=9999))})
        elif scenario == "transplanted_row":
            sheet_dates = {row["__line_id"]: row["__service_date"] for row in candidate["rows"]}
            sheet_dates[candidate["rows"][0]["__line_id"]] = "2026-04-21"
        elif scenario == "missing_daily_sheet":
            candidate["daily_batches"].pop(1)
        elif scenario == "extra_daily_sheet":
            candidate["daily_batches"].append({**candidate["daily_batches"][0], "service_date": "2026-04-23"})
        try:
            validate_daily_currentness(candidate, fresh, sheet_dates if scenario == "transplanted_row" else None)
        except AssertionError:
            rejected += 1
        else:
            raise AssertionError(f"Multi-date currentness negative control passed: {scenario}")
    require(export_allowed(False) and not export_allowed(True), "Only clean saved state permits export")
    calibration = verify_print_certification(FIXTURE)
    calibration_rejected = 0
    for scenario in ["missing_school_case", "short_ingredient_case", "oversize_supplier", "short_composite",
                     "artificial_all_maxima", "control_inside_envelope", "one_over_boundary"]:
        candidate = copy.deepcopy(FIXTURE)
        by_id = {row["confirmed_need_line_id"]: row for row in candidate["rows"]}
        cases = candidate["print_certification"]["stress_lines"]
        if scenario == "missing_school_case":
            cases.pop("school")
        elif scenario == "short_ingredient_case":
            by_id[cases["ingredient"]]["ingredient_name"] = "Rau"
        elif scenario == "oversize_supplier":
            next(item for item in candidate["suppliers"] if item["supplier_id"] in candidate["print_cases"]["wrapped_supplier_ids"])["supplier_name"] += "A"
        elif scenario == "short_composite":
            by_id[cases["composite"]]["exact_quantity"] = "1"
        elif scenario == "artificial_all_maxima":
            row = by_id[cases["composite"]]
            row["school_name"] = by_id[cases["school"]]["school_name"]
            row["ingredient_name"] = by_id[cases["ingredient"]]["ingredient_name"]
            row["exact_quantity"] = by_id[cases["quantity"]]["exact_quantity"]
        elif scenario == "control_inside_envelope":
            candidate["print_certification"]["out_of_envelope_control"].update(school_display="Mẫu", ingredient_name="Rau", supplier_name="Kho")
        elif scenario == "one_over_boundary":
            by_id[cases["composite"]]["ingredient_name"] += "A" * (85 - combined_print_chars(print_content(by_id[cases["composite"]], candidate)))
        try:
            verify_print_certification(candidate)
        except (AssertionError, KeyError):
            calibration_rejected += 1
        else:
            raise AssertionError(f"Print calibration negative control passed: {scenario}")
    print(f"PASS: static XLSX/fixture/schema conformance; {rejected}/{len(controls) + len(structural_controls) + 1 + 9 + 1} negative controls rejected; three-date currentness/restart/quantity/note model checked.")
    print(f"PRINT_CERTIFICATION: {calibration_rejected}/7 additional QA controls rejected; " + json.dumps(calibration, sort_keys=True))
    print("ROW_RHYTHM: " + json.dumps(normalized["print_metrics"], sort_keys=True))
    print(f"SHA256: {hashlib.sha256(path.read_bytes()).hexdigest()}")
    print("Not tested here: connected V1 import, persistence, or native staff Excel behavior.")


if __name__ == "__main__":
    specimen = Path(sys.argv[1] if len(sys.argv) > 1 else HERE / "atlas-shopping-list-v1-example.xlsx")
    main(specimen)
    if len(sys.argv) > 2:
        verify_location_invariance(specimen, Path(sys.argv[2]))
