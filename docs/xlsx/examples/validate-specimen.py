"""Static specimen conformance and negative controls. This is NOT an importer.

No application dependencies, network, business commands, or draft application.
The closed schema vocabulary is evaluated with the standard library; this is
not a general-purpose JSON Schema engine.
"""

import copy
from datetime import date, datetime
from decimal import Decimal
import hashlib
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
    locations = {}
    for row in fixture["rows"]:
        locations.setdefault((row["service_date"], row["school_id"]), set()).add(row["delivery_location_id"])
    seen = set()
    for row in fixture["rows"]:
        school_display = row["school_name"]
        if len(locations[(row["service_date"], row["school_id"])]) > 1:
            school_display += f"\nĐiểm giao: {row['delivery_location_name']}"
        key = (row["service_date"], school_display, row["ingredient_name"], row["unit_code"])
        require(key not in seen, "Ambiguous visible tuple must block export")
        seen.add(key)


def verify(files):
    allowed_parts = {
        "[Content_Types].xml", "_rels/.rels", "xl/_rels/workbook.xml.rels",
        "xl/workbook.xml", "xl/styles.xml", "xl/sharedStrings.xml", "xl/theme/theme1.xml",
        *[f"xl/worksheets/sheet{i}.xml" for i in range(1, 4)],
        *[f"xl/worksheets/_rels/sheet{i}.xml.rels" for i in range(1, 3)],
        *[f"xl/tables/table{i}.xml" for i in range(1, 3)],
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
    styles = roots["xl/styles.xml"].find("m:cellXfs", NS)
    visible = SCHEMA["x-atlas-layout"]["visibleHeaders"]
    hidden = SCHEMA["x-atlas-layout"]["hiddenHeaders"]
    projected = []
    for index, date in enumerate(dates, 1):
        sheet = roots[f"xl/worksheets/sheet{index}.xml"]
        require(not sheet.findall(".//m:f", NS), "No formulas")
        rows = [row for row in FIXTURE["rows"] if row["service_date"] == date]
        end = len(rows) + 3
        table = roots[f"xl/tables/table{index}.xml"]
        require(table.get("name") == f"AtlasNeed_{date.replace('-', '')}", "Table name")
        require(table.get("ref") == f"A3:Q{end}", "Full identity-bound Table range")
        require(table.find("m:autoFilter", NS).get("ref") == f"A3:Q{end}", "Whole Table filter")
        require([col.get("name") for col in table.find("m:tableColumns", NS)] == visible + hidden, "Exact Table columns")
        require(table.find("m:tableStyleInfo", NS).get("showRowStripes") == "0", "Restrained table styling")
        cells = {cell.get("r"): cell for cell in sheet.findall(".//m:c", NS)}
        for address, cell in cells.items():
            if text(cell, strings):
                match = re.fullmatch(r"([A-Z]+)([0-9]+)", address)
                require(match is not None, "Canonical cell address")
                column, row_number = match.group(1), int(match.group(2))
                require(len(column) == 1 and "A" <= column <= "Q" and 1 <= row_number <= end, "No nonempty out-of-region cells")
                if row_number < 3:
                    require(column == "A", "Only merged title/help anchors contain values")
        require([text(cells.get(f"{chr(65 + col)}3"), strings) for col in range(17)] == visible + hidden, "Exact header cells")
        data_rows = sheet.find("m:sheetData", NS).findall("m:row", NS)
        require([int(row.get("r")) for row in data_rows if int(row.get("r")) >= 4 and any(text(cell, strings) for cell in row)] == list(range(4, end + 1)), "Complete data rows")
        seen = set()
        by_id = {row["confirmed_need_line_id"]: row for row in rows}
        locations = {}
        for row in rows:
            locations.setdefault(row["school_id"], set()).add(row["delivery_location_id"])
        for row_index in range(4, end + 1):
            values = [text(cells.get(f"{chr(65 + col)}{row_index}"), strings) for col in range(17)]
            row_id = values[6]
            require(row_id in by_id and row_id not in seen, "Unknown/duplicate line")
            seen.add(row_id)
            row = by_id[row_id]
            expected_hidden = [FIXTURE["metadata"]["workbook_marker"], row_id, row["current_revision_id"], row["current_decision_id"] or "", date, row["school_id"], row["delivery_location_id"], row["ingredient_id"], row["unit_id"], row["exact_quantity"], row["reason_code"], row["shopping_note"]]
            require(values[5:] == expected_hidden, "Canonical row-bound evidence")
            expected_school = row["school_name"] + (f"\nĐiểm giao: {row['delivery_location_name']}" if len(locations[row["school_id"]]) > 1 else "")
            require(values[:3] == [expected_school, row["ingredient_name"], row["unit_code"]], "Canonical visible labels")
            require(Decimal(values[3]) == Decimal(row["exact_quantity"]), "Exact quantity XML")
            require(values[4] == row["shopping_note"], "Exported supplier annotation")
            for col in range(17):
                cell = cells[f"{chr(65 + col)}{row_index}"]
                protection = styles[int(cell.get("s", "0"))].find("m:protection", NS)
                is_unlocked = protection is not None and protection.get("locked") == "0"
                require(is_unlocked == (col in [3, 4]), "Only D/E editable")
                if col >= 5:
                    require(cell.get("t") in ["s", "inlineStr"], "Hidden evidence stored as text")
            projected.append(dict(zip(["school_display", "ingredient_name", "unit_code", "quantity", "note"] + hidden, values)))
        require(seen == set(by_id), "Every-and-only line set")
        require([text(cells[f"G{row_index}"], strings) for row_index in range(4, end + 1)] == [row["confirmed_need_line_id"] for row in rows], "Deterministic specimen export order")
        cols = sheet.find("m:cols", NS)
        require(any(col.get("min") == "6" and col.get("max") == "17" and col.get("hidden") == "1" for col in cols), "Hidden F:Q")
        pane = sheet.find(".//m:pane", NS)
        require(pane.get("ySplit") == "3" and pane.get("state") == "frozen", "Frozen header")
        require([node.get("ref") for node in sheet.findall("m:mergeCells/m:mergeCell", NS)] == ["A1:E1", "A2:E2"], "No merged data cells")
        protection = sheet.find("m:sheetProtection", NS)
        require(protection.get("sheet") == "1" and protection.get("autoFilter") == "0" and protection.get("sort") == "1", "Protected filter; sort denied")
        require(protection.get("selectLockedCells") == "0" and protection.get("selectUnlockedCells") == "0", "Both cell selections allowed")
        setup = sheet.find("m:pageSetup", NS)
        require(setup.get("orientation") == "landscape" and setup.get("fitToWidth") == "1" and setup.get("fitToHeight") == "0", "Readable page fit")
        require(len(sheet.findall("m:rowBreaks/m:brk", NS)) == 2, "School page breaks")
        definitions = {node.get("name"): node.text for node in wb.findall("m:definedNames/m:definedName", NS) if node.get("localSheetId") == str(index - 1)}
        require(definitions.get("_xlnm.Print_Area") == f"'{date}'!$A$1:$E${end}", "Visible print area")
        require(definitions.get("_xlnm.Print_Titles") == f"'{date}'!$1:$3", "Repeat date/header on pages")
    meta = roots[f"xl/worksheets/sheet{len(dates) + 1}.xml"]
    require(not meta.findall(".//m:f", NS), "No metadata formulas")
    require(meta.find("m:sheetProtection", NS) is not None, "Protected metadata")
    meta_cells = {cell.get("r"): cell for cell in meta.findall(".//m:c", NS)}
    require(all(re.fullmatch(r"[AB](?:[1-9]|10)", address) for address, cell in meta_cells.items() if text(cell, strings)), "No nonempty metadata extras")
    pairs = [(text(meta_cells.get(f"A{i}"), strings), text(meta_cells.get(f"B{i}"), strings)) for i in range(1, 11)]
    require(pairs == [(key, str(value)) for key, value in FIXTURE["metadata"].items()], "Exact metadata contract")
    normalized_meta = dict(pairs)
    normalized_meta["batch_version"] = int(normalized_meta["batch_version"])
    return {"metadata": normalized_meta, "rows": projected}


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
        require(isinstance(value, list) and len(value) >= rule.get("minItems", 0), "Schema array/minItems")
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


def main(path):
    verify_presentation(FIXTURE)
    with ZipFile(path) as archive:
        require(archive.testzip() is None, "Healthy ZIP")
        files = {name: archive.read(name) for name in archive.namelist()}
    normalized = verify(files)
    check_schema(normalized, SCHEMA)
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
        (sheet, "O4", "9.123456"), (sheet, "P4", "OTHER"),
        ("xl/worksheets/sheet3.xml", "B2", "ATLAS_SHOPPING_LIST_V2"),
        ("xl/worksheets/sheet3.xml", "B8", "8"),
        ("xl/worksheets/sheet3.xml", "B9", "00000000-0000-0000-0000-000000009999"),
        ("xl/worksheets/sheet3.xml", "B10", "00000000-0000-0000-0000-000000009999"),
        ("xl/worksheets/sheet3.xml", "B5", "2026-04-19"),
        ("xl/worksheets/sheet3.xml", "B6", "2026-04-22"),
        ("xl/worksheets/sheet3.xml", "C1", "unexpected metadata"),
        (sheet, "R4", "unexpected column"), (sheet, "A44", "unexpected row"),
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
    for operation in ["delete", "expand", "external", "macro_type"]:
        mutated = copy.copy(files)
        target = {"delete": sheet, "expand": "xl/tables/table1.xml", "external": "xl/worksheets/_rels/sheet1.xml.rels", "macro_type": "[Content_Types].xml"}[operation]
        root = ET.fromstring(mutated[target])
        if operation == "delete":
            data = root.find("m:sheetData", NS)
            data.remove(data.find('m:row[@r="4"]', NS))
        elif operation == "expand":
            root.set("ref", "A3:Q44")
        elif operation == "external":
            root[0].set("TargetMode", "External")
            root[0].set("Target", "https://example.invalid/fixture-control")
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
        if row["ingredient_name"] == "Gạo tẻ hạt dài":
            row["ingredient_name"] = "Gạo tẻ"
    try:
        verify_presentation(ambiguous)
    except AssertionError:
        rejected += 1
    else:
        raise AssertionError("Ambiguous canonical label control passed")
    require(len(FIXTURE["rows"]) == 80 and len({row["school_id"] for row in FIXTURE["rows"]}) == 3, "Required fixture coverage")
    require(len({row["ingredient_id"] for row in FIXTURE["rows"]}) >= 8, "Ingredient coverage")
    print(f"PASS: static XLSX/fixture/schema conformance; {rejected}/{len(controls) + 5} negative controls rejected.")
    print(f"SHA256: {hashlib.sha256(path.read_bytes()).hexdigest()}")
    print("Not tested here: connected V1 import, persistence, or native staff Excel behavior.")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else HERE / "atlas-shopping-list-v1-example.xlsx"))
