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


def finalize(path):
    here = Path(__file__).parent
    fixture = json.loads((here / "atlas-shopping-list-v1.fixture.json").read_text(encoding="utf-8"))
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
            hidden_values = [fixture["metadata"]["workbook_marker"], row["confirmed_need_line_id"], row["current_revision_id"], row["current_decision_id"] or "", date, row["school_id"], row["delivery_location_id"], row["ingredient_id"], row["unit_id"], row["exact_quantity"], row["reason_code"], row["shopping_note"]]
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
        ET.SubElement(cols, tag("col"), min="6", max="17", width="1", customWidth="1", hidden="1")
        sheet_data = sheet.find("m:sheetData", NS)
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
        ET.SubElement(props, tag("pageSetUpPr"), fitToPage="1")
        insertion = list(sheet).index(sheet.find("m:tableParts", NS))
        native = [
            ET.Element(tag("printOptions"), horizontalCentered="1"),
            ET.Element(tag("pageMargins"), left="0.25", right="0.25", top="0.4", bottom="0.4", header="0.15", footer="0.15"),
            ET.Element(tag("pageSetup"), paperSize="9", orientation="landscape", fitToWidth="1", fitToHeight="0"),
        ]
        footer = ET.Element(tag("headerFooter"))
        ET.SubElement(footer, tag("oddFooter")).text = "&LPhiếu đi chợ – Mẫu minh họa&RTrang &P / &N"
        native.append(footer)
        breaks = [i + 3 for i in range(1, len(rows)) if rows[i]["school_id"] != rows[i - 1]["school_id"]]
        page_breaks = ET.Element(tag("rowBreaks"), count=str(len(breaks)), manualBreakCount=str(len(breaks)))
        for value in breaks:
            ET.SubElement(page_breaks, tag("brk"), id=str(value), min="0", max="16383", man="1")
        native.append(page_breaks)
        for node in native:
            sheet.insert(insertion, node)
            insertion += 1
        files[sheet_path] = xml(sheet)
        table_path = f"xl/tables/table{index + 1}.xml"
        table = ET.fromstring(files[table_path])
        style_info = table.find("m:tableStyleInfo", NS)
        if style_info is not None:
            style_info.set("showRowStripes", "0")
            style_info.set("showColumnStripes", "0")
        files[table_path] = xml(table)
        for name, content in [("_xlnm.Print_Area", f"'{date}'!$A$1:$E${end}"), ("_xlnm.Print_Titles", f"'{date}'!$1:$3")]:
            ET.SubElement(defined, tag("definedName"), name=name, localSheetId=str(index)).text = content
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
