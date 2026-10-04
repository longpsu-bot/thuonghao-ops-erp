"""Add native features absent from the artifact API; normalize ZIP for reproducibility.

Standard library only. Operates on the isolated synthetic specimen, never production.
"""

import copy
import json
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS = {"m": MAIN}
ET.register_namespace("", MAIN)
ET.register_namespace("r", "http://schemas.openxmlformats.org/officeDocument/2006/relationships")


def tag(name):
    return f"{{{MAIN}}}{name}"


def xml(root):
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def preferred_supplier(row, fixture):
    suppliers = {item["supplier_id"]: item for item in fixture["suppliers"]}
    eligible = sorted(
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
    if not eligible or (len(eligible) > 1 and eligible[0]["priority"] == eligible[1]["priority"]):
        return ""
    return suppliers[eligible[0]["supplier_id"]]["supplier_name"]


def body_height_budget(print_layout):
    """A4 vertical budget in points after margins, repeated rows and footer."""
    return (
        print_layout["a4HeightPt"]
        - 72 * (print_layout["topMarginIn"] + print_layout["bottomMarginIn"])
        - print_layout["footerAllowancePt"]
        - print_layout["titleRowPt"]
        - print_layout["spacerRowPt"]
        - print_layout["headerRowPt"]
    )


def page_breaks(rows, sheet_data, print_layout):
    """Pack complete groups when they fit; split large groups after full rows."""
    heights = {int(item.get("r")): float(item.get("ht", "0")) for item in sheet_data.findall("m:row", NS)}
    # Explicit native 95% scale, with a conservative 96% height bound for
    # printer rounding; only the three fixed authored body classes are packed.
    capacity = body_height_budget(print_layout) / print_layout["pageHeightScaleUpperBound"]
    remaining = capacity
    breaks = []
    continuation = []
    index = 0
    while index < len(rows):
        school = (rows[index]["school_id"], rows[index]["delivery_location_id"])
        end = index
        while end < len(rows) and (rows[end]["school_id"], rows[end]["delivery_location_id"]) == school:
            end += 1
        total = sum(heights[i + 4] for i in range(index, end))
        small_group = end - index <= 8
        if index and small_group and total > remaining:
            breaks.append(index + 3)
            remaining = capacity
        elif index and total > remaining and remaining < capacity:
            fit = 0
            space = remaining
            for position in range(index, end):
                if heights[position + 4] > space:
                    break
                space -= heights[position + 4]
                fit += 1
            if fit < 3:  # do not orphan one or two rows of a new School
                breaks.append(index + 3)
                remaining = capacity
        for position in range(index, end):
            height = heights[position + 4]
            if height > remaining:
                breaks.append(position + 3)
                if position > index:
                    continuation.append(position)
                remaining = capacity
                if position > index:
                    height = max(height, print_layout["wrappedRowPt"])
            remaining -= height
        index = end
    return breaks, continuation


def finalize(path):
    here = Path(__file__).parent
    fixture = json.loads((here / "atlas-shopping-list-v1.fixture.json").read_text(encoding="utf-8"))
    layout = json.loads((here.parent / "atlas-shopping-list-xlsx-v1.schema.json").read_text(encoding="utf-8"))["x-atlas-layout"]["print"]
    dates = sorted({row["service_date"] for row in fixture["rows"]})
    with ZipFile(path) as archive:
        files = {name: archive.read(name) for name in archive.namelist()}
    styles = ET.fromstring(files["xl/styles.xml"])
    xfs = styles.find("m:cellXfs", NS)
    unlocked = {}
    text_quantity_styles = {}
    for index, xf in enumerate(list(xfs)):
        clone = copy.deepcopy(xf)
        for protection in clone.findall("m:protection", NS):
            clone.remove(protection)
        clone.set("applyProtection", "1")
        ET.SubElement(clone, tag("protection"), locked="0")
        unlocked[index] = len(xfs)
        xfs.append(clone)
        text_clone = copy.deepcopy(clone)
        text_clone.set("numFmtId", "49")
        text_clone.set("applyNumberFormat", "1")
        text_quantity_styles[index] = len(xfs)
        xfs.append(text_clone)
    xfs.set("count", str(len(xfs)))
    files["xl/styles.xml"] = xml(styles)
    wb = ET.fromstring(files["xl/workbook.xml"])
    meta = wb.find("m:sheets", NS)[-1]
    meta.set("state", "veryHidden")
    password = "ATLAS_SHOPPING_LIST_V1"
    password_hash = 0
    for character in reversed(password):
        password_hash = ((password_hash >> 14) & 1) | ((password_hash << 1) & 0x7FFF)
        password_hash ^= ord(character)
    password_hash = ((password_hash >> 14) & 1) | ((password_hash << 1) & 0x7FFF)
    password_hash ^= len(password) ^ 0xCE4B
    workbook_protection = wb.find("m:workbookProtection", NS)
    if workbook_protection is not None:
        wb.remove(workbook_protection)
    wb.insert(list(wb).index(wb.find("m:sheets", NS)), ET.Element(tag("workbookProtection"), lockStructure="1", workbookPassword=f"{password_hash:04X}"))
    defined = wb.find("m:definedNames", NS)
    if defined is not None:
        wb.remove(defined)
    defined = ET.Element(tag("definedNames"))
    # definedNames precedes calcPr per the workbook schema.
    calc = wb.find("m:calcPr", NS)
    wb.insert(list(wb).index(calc) if calc is not None else len(wb), defined)
    for index, date in enumerate(dates):
        rows = [row for row in fixture["rows"] if row["service_date"] == date]
        end = len(rows) + 3
        sheet_path = f"xl/worksheets/sheet{index + 1}.xml"
        sheet = ET.fromstring(files[sheet_path])
        # Serialize exact XML decimals without passing through a binary number.
        for row_index, row in enumerate(rows, 4):
            quantity = sheet.find(f'.//m:c[@r="D{row_index}"]', NS)
            for child in list(quantity):
                quantity.remove(child)
            text = row["exact_quantity"]
            significant = len(text.replace(".", "").lstrip("0"))
            if significant <= 15:
                quantity.set("t", "n")
                ET.SubElement(quantity, tag("v")).text = text
            else:
                quantity.set("t", "inlineStr")
                ET.SubElement(ET.SubElement(quantity, tag("is")), tag("t")).text = text
                quantity.set("s", str(text_quantity_styles[int(quantity.get("s", "0"))]))
            hidden_values = [fixture["metadata"]["workbook_marker"], row["confirmed_need_line_id"], row["current_revision_id"], row["current_decision_id"] or "", date, row["school_id"], row["delivery_location_id"], row["ingredient_id"], row["unit_id"], row["exact_quantity"]]
            for column, value in enumerate(hidden_values, 5):
                cell = sheet.find(f'.//m:c[@r="{chr(65 + column)}{row_index}"]', NS)
                for child in list(cell):
                    cell.remove(child)
                cell.set("t", "inlineStr")
                ET.SubElement(ET.SubElement(cell, tag("is")), tag("t")).text = value
        for cell in sheet.findall(".//m:c", NS):
            address = cell.get("r")
            if address[0] in "DE" and int(address[1:]) >= 4:
                style_index = int(cell.get("s", "0"))
                if style_index in unlocked:
                    cell.set("s", str(unlocked[style_index]))
        cols = sheet.find("m:cols", NS)
        if cols is None:
            cols = ET.Element(tag("cols"))
            sheet.insert(list(sheet).index(sheet.find("m:sheetData", NS)), cols)
        # Keep populated visible sizing only; hidden technical range is exact.
        for col in list(cols):
            if int(col.get("min")) > 5:
                cols.remove(col)
            elif int(col.get("max")) > 5:
                col.set("max", "5")
        ET.SubElement(cols, tag("col"), min="6", max="15", width="1", customWidth="1", hidden="1")
        for address in ["C3"]:
            cell = sheet.find(f'.//m:c[@r="{address}"]', NS)
            style = copy.deepcopy(xfs[int(cell.get("s", "0"))])
            style.find("m:alignment", NS).set("wrapText", "0")
            cell.set("s", str(len(xfs)))
            xfs.append(style)
        sheet_data = sheet.find("m:sheetData", NS)
        breaks, continuation = page_breaks(rows, sheet_data, layout)
        for position in continuation:
            row = rows[position]
            cell = sheet.find(f'.//m:c[@r="A{position + 4}"]', NS)
            first = next(
                i for i, candidate in enumerate(rows)
                if (candidate["school_id"], candidate["delivery_location_id"])
                == (row["school_id"], row["delivery_location_id"])
            )
            first_cell = sheet.find(f'.//m:c[@r="A{first + 4}"]', NS)
            for child in list(cell):
                cell.remove(child)
            cell.set("t", "inlineStr")
            cell.set("s", first_cell.get("s", "0"))
            multi_location = len({candidate["delivery_location_id"] for candidate in rows if candidate["school_id"] == row["school_id"]}) > 1
            label = f'{row["school_name"]} (tiếp)'
            if multi_location:
                label += f'\nĐiểm giao: {row["delivery_location_name"]}'
            ET.SubElement(ET.SubElement(cell, tag("is")), tag("t")).text = label
            row_node = sheet_data.find(f'm:row[@r="{position + 4}"]', NS)
            minimum = layout["multiLocationRowPt"] if multi_location else layout["wrappedRowPt"]
            row_node.set("ht", str(max(float(row_node.get("ht", "0")), minimum)))
        for name in ["sheetProtection", "autoFilter", "printOptions", "pageMargins", "pageSetup", "headerFooter", "rowBreaks"]:
            for node in sheet.findall(f"m:{name}", NS):
                sheet.remove(node)
        # sheetProtection follows sheetData and precedes mergeCells/tableParts.
        protection = ET.Element(tag("sheetProtection"), {
            "sheet": "1", "objects": "1", "scenarios": "1", "formatCells": "1",
            "formatColumns": "1", "formatRows": "1", "insertColumns": "1",
            "insertRows": "1", "insertHyperlinks": "1", "deleteColumns": "1",
            "deleteRows": "1", "sort": "1", "autoFilter": "0",
            "pivotTables": "1", "selectLockedCells": "0", "selectUnlockedCells": "0",
        })
        # Conventional Excel sheet password hash; protection is not security.
        protection.set("password", f"{password_hash:04X}")
        sheet.insert(list(sheet).index(sheet_data) + 1, protection)
        props = sheet.find("m:sheetPr", NS)
        if props is None:
            props = ET.Element(tag("sheetPr"))
            sheet.insert(0, props)
        for setup in props.findall("m:pageSetUpPr", NS):
            props.remove(setup)
        ET.SubElement(props, tag("pageSetUpPr"), fitToPage="0")
        insertion = list(sheet).index(sheet.find("m:tableParts", NS))
        native = [
            ET.Element(tag("printOptions"), horizontalCentered="1"),
            ET.Element(tag("pageMargins"), left=str(layout["leftMarginIn"]), right=str(layout["rightMarginIn"]), top=str(layout["topMarginIn"]), bottom=str(layout["bottomMarginIn"]), header="0.12", footer="0.12"),
            ET.Element(tag("pageSetup"), paperSize="9", orientation="portrait", scale=str(layout["scalePercent"])),
        ]
        footer = ET.Element(tag("headerFooter"))
        ET.SubElement(footer, tag("oddFooter")).text = "&RTrang &P / &N"
        native.append(footer)
        breaks_element = ET.Element(tag("rowBreaks"), count=str(len(breaks)), manualBreakCount=str(len(breaks)))
        for value in breaks:
            ET.SubElement(breaks_element, tag("brk"), id=str(value), min="0", max="16383", man="1")
        native.append(breaks_element)
        for node in native:
            sheet.insert(insertion, node)
            insertion += 1
        files[sheet_path] = xml(sheet)
        table_path = f"xl/tables/table{index + 1}.xml"
        table = ET.fromstring(files[table_path])
        # Preserve a whole-Table filter definition while hiding buttons so compact
        # print headings retain their full cell width. Filtering is BEST_EFFORT.
        auto_filter = table.find("m:autoFilter", NS)
        if auto_filter is None:
            auto_filter = ET.Element(tag("autoFilter"), ref=table.get("ref"))
            table.insert(0, auto_filter)
        for column in range(15):
            ET.SubElement(auto_filter, tag("filterColumn"), colId=str(column), hiddenButton="1", showButton="0")
        style_info = table.find("m:tableStyleInfo", NS)
        if style_info is not None:
            style_info.set("showRowStripes", "0")
            style_info.set("showColumnStripes", "0")
        files[table_path] = xml(table)
        for name, content in [("_xlnm.Print_Area", f"'{date}'!$A$1:$E${end}"), ("_xlnm.Print_Titles", f"'{date}'!$1:$3")]:
            ET.SubElement(defined, tag("definedName"), name=name, localSheetId=str(index)).text = content
    xfs.set("count", str(len(xfs)))
    files["xl/styles.xml"] = xml(styles)
    files["xl/workbook.xml"] = xml(wb)
    meta_path = f"xl/worksheets/sheet{len(dates) + 1}.xml"
    meta_sheet = ET.fromstring(files[meta_path])
    meta_data = meta_sheet.find("m:sheetData", NS)
    for index, (key, value) in enumerate(fixture["metadata"].items(), 1):
        for column, content in [("A", key), ("B", str(value))]:
            cell = meta_sheet.find(f'.//m:c[@r="{column}{index}"]', NS)
            for child in list(cell):
                cell.remove(child)
            cell.set("t", "inlineStr")
            ET.SubElement(ET.SubElement(cell, tag("is")), tag("t")).text = content
    daily_headers = ["service_date", "confirmed_need_batch_id", "batch_version", "need_generation_run_id", "release_snapshot_id"]
    for row_index, values in [(8, daily_headers)] + [
        (index + 9, [str(batch[key]) for key in daily_headers])
        for index, batch in enumerate(fixture["daily_batches"])
    ]:
        for column, content in enumerate(values):
            cell = meta_sheet.find(f'.//m:c[@r="{chr(65 + column)}{row_index}"]', NS)
            for child in list(cell):
                cell.remove(child)
            cell.set("t", "inlineStr")
            ET.SubElement(ET.SubElement(cell, tag("is")), tag("t")).text = content
    meta_sheet.insert(list(meta_sheet).index(meta_data) + 1, ET.Element(tag("sheetProtection"), sheet="1", objects="1", scenarios="1", password=f"{password_hash:04X}"))
    files[meta_path] = xml(meta_sheet)
    # Artifact ZIP/core times vary; normalize container evidence, not row data.
    if "docProps/core.xml" in files:
        core = ET.fromstring(files["docProps/core.xml"])
        for child in core:
            if child.tag.endswith("created") or child.tag.endswith("modified"):
                child.text = fixture["metadata"]["exported_at"]
        files["docProps/core.xml"] = xml(core)
    # Artifact relationship IDs are random. Normalize each OPC owner scope,
    # including its matching r:id references, without changing row identities.
    relationship_namespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    for rel_path in sorted(name for name in files if name.endswith(".rels")):
        relations = ET.fromstring(files[rel_path])
        ordered = sorted(relations, key=lambda node: (node.get("Type", ""), node.get("Target", ""), node.get("TargetMode", "")))
        mapping = {node.get("Id"): f"rId{index}" for index, node in enumerate(ordered, 1)}
        for node in ordered:
            node.set("Id", mapping[node.get("Id")])
        relations[:] = ordered
        files[rel_path] = xml(relations)
        if rel_path != "_rels/.rels":
            directory, filename = rel_path.rsplit("/_rels/", 1)
            owner_path = f"{directory}/{filename[:-5]}"
            if owner_path in files:
                owner = ET.fromstring(files[owner_path])
                for node in owner.iter():
                    for key, value in list(node.attrib.items()):
                        if key.startswith(f"{{{relationship_namespace}}}") and value in mapping:
                            node.set(key, mapping[value])
                files[owner_path] = xml(owner)
    with ZipFile(path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(files):
            info = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o600 << 16
            archive.writestr(info, files[name])
    print(f"Finalized {path}: {len(dates)} dates, {len(fixture['rows'])} synthetic lines.")


if __name__ == "__main__":
    finalize(Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).with_name("atlas-shopping-list-v1-example.xlsx")))
