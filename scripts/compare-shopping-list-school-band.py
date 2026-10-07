"""Normalize native Excel PDFs to A4, verify all pages, build Owner comparison.

Usage: bundled-python scripts/compare-shopping-list-school-band.py OUTPUT_DIR
Requires bundled pypdf/pdfplumber/reportlab/Pillow and Poppler on PATH.
"""
import collections
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

import pdfplumber
from PIL import Image, ImageDraw
from pypdf import PdfReader, PdfWriter
from pypdf.generic import RectangleObject
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Table, TableStyle, Paragraph
from reportlab.lib.styles import ParagraphStyle

out = Path(sys.argv[1]).resolve()
qa = out / "qa"
qa.mkdir(exist_ok=True)
spec = json.loads((out / "specimen-report.json").read_text(encoding="utf-8"))
native = json.loads((out / "excel-report.json").read_text(encoding="utf-8-sig"))
authority = json.loads((out / "authority-2026-09-17.json").read_text(encoding="utf-8"))
assert len(authority["workbench"]["lines"]) == 248
compact = lambda text: re.sub(r"\s+", "", unicodedata.normalize("NFC", text or ""))
reports = {}
texts = {}
for variant in "ABC":
    pdf = out / f"ShoppingList-SchoolBand-{variant}-2026-09-17.pdf"
    raw = qa / f"{variant}-native.pdf"
    if not raw.exists() or abs(float(PdfReader(pdf).pages[0].mediabox.width) - A4[0]) > 0.02:
        raw.write_bytes(pdf.read_bytes())
    reader = PdfReader(raw)
    writer = PdfWriter()
    sizes = []
    for page in reader.pages:
        w, h = float(page.mediabox.width), float(page.mediabox.height)
        sizes.append([w, h])
        scale = min(A4[0] / w, A4[1] / h)
        page.scale_by(scale)
        page.mediabox = RectangleObject([0, 0, *A4])
        page.cropbox = RectangleObject([0, 0, *A4])
        writer.add_page(page)
    with pdf.open("wb") as stream:
        writer.write(stream)
    page_starts = [4] + native[variant]["page_start_rows"]
    assert len(reader.pages) == len(page_starts), "Native automatic break diverged from generated plan"
    rows = spec[variant]["rows"]
    stops = page_starts[1:] + [rows[-1]["row"] + 1]
    distribution = [sum(start <= r["row"] < stop and r["kind"] == "DATA_LINE" for r in rows)
                    for start, stop in zip(page_starts, stops)]
    assert sum(distribution) == 248 and all(distribution)
    page_texts = []
    ingredient_texts = []
    with pdfplumber.open(pdf) as document:
        for page in document.pages:
            assert abs(page.width - A4[0]) < 0.02 and abs(page.height - A4[1]) < 0.02
            text = page.extract_text() or ""
            assert all(h in text for h in ["TRƯỜNG", "THÀNH PHẦN", "ĐVT", "SỐ LƯỢNG", "GHI CHÚ"])
            assert "17/09/2026" in text
            for word in page.extract_words():
                assert 14.0 <= word["x0"] <= word["x1"] <= page.width - 14.0, (variant, word)
                assert 17.5 <= word["top"] <= word["bottom"] <= page.height - 17.5, (variant, word)
            page_texts.append(text)
            left = 14.4 + native[variant]["column_widths_pt"][0] * 0.96
            right = left + native[variant]["column_widths_pt"][1] * 0.96
            ingredient_texts.append(page.crop((left, 0, right, page.height)).extract_text() or "")
    all_text = compact(" ".join(page_texts))
    ingredient_counts = collections.Counter(l["ingredient"]["name"] for l in authority["workbench"]["lines"])
    for ingredient, count in ingredient_counts.items():
        assert compact(" ".join(ingredient_texts)).count(compact(ingredient)) >= count, (variant, ingredient, "missing/clipped")
    for school in {l["school"]["name"] for l in authority["workbench"]["lines"]}:
        assert compact(school) in all_text, (variant, school)
    assert all_text.count("Miếng") == 3
    assert "v1-unit-" not in all_text
    assert sum("(tiếp)" in text for text in page_texts) == spec[variant]["continuation_bands"]
    for page_index, start in enumerate(page_starts[1:], 1):
        first = next(r for r in rows if r["row"] == start)
        assert first["kind"] == "SCHOOL_BAND"
        assert compact(first["visible"][0]) in compact(page_texts[page_index])
    reports[variant] = {k: v for k, v in spec[variant].items() if k != "rows"}
    reports[variant].update(pdf_pages=len(reader.pages), data_rows_per_page=distribution,
                            raw_pdf_size_pt=sizes[0], final_pdf_size_pt=list(A4),
                            native_widths_pt=native[variant]["column_widths_pt"],
                            clipping=False, page_cropping=False, pdf_content_check="PASS")
    texts[variant] = page_texts
    subprocess.run(["pdftoppm", "-r", "100", "-png", str(pdf), str(qa / variant)], check=True)
    images = sorted(qa.glob(f"{variant}-[0-9]*.png"), key=lambda p: int(p.stem.split("-")[-1]))
    assert len(images) == len(reader.pages)
    contact = Image.new("RGB", (1000, ((len(images) + 3) // 4) * 380), "#eeeeee")
    draw = ImageDraw.Draw(contact)
    for i, image_path in enumerate(images):
        image = Image.open(image_path).convert("RGB")
        image.thumbnail((242, 348))
        x, y = (i % 4) * 250 + 4, (i // 4) * 380 + 20
        contact.paste(image, (x, y))
        draw.text((x, y - 15), f"{variant}, page {i + 1}", fill="black")
    contact.save(qa / f"{variant}-all-pages.png")

pdfmetrics.registerFont(TTFont("AtlasTNR", "C:/Windows/Fonts/times.ttf"))
pdfmetrics.registerFont(TTFont("AtlasTNRBold", "C:/Windows/Fonts/timesbd.ttf"))
c = canvas.Canvas(str(out / "ShoppingList-SchoolBand-Comparison.pdf"), pagesize=A4)
style = ParagraphStyle("body", fontName="AtlasTNR", fontSize=10, leading=13)
def text(x, y, value, size=11, bold=False):
    c.setFont("AtlasTNRBold" if bold else "AtlasTNR", size)
    c.drawString(x, y, value)
def table(data, widths, y, font_size=10):
    t = Table([[Paragraph(str(v), style) for v in row] for row in data], colWidths=widths)
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dddddd")),
                           ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
                           ("VALIGN", (0, 0), (-1, -1), "TOP"),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
    _, height = t.wrap(540, 760)
    t.drawOn(c, 28, y - height)
    return y - height
text(28, 802, "Atlas Shopping List - School band comparison", 18, True)
text(28, 779, "17/09/2026 | 248 DATA_LINE | 20 Schools | V2 | Owner choice pending", 11)
data = [["Measured result", "A - Compact", "B - Balanced", "C - Spacious"]]
fields = [("PDF pages", "pdf_pages"), ("Initial / continuation bands", None),
          ("Wrapped Ingredient rows", "wrapped_ingredient_rows"), ("Wrapped DATA_LINE", "wrapped_data_rows"),
          ("Wrapped School bands", "wrapped_school_bands"), ("Unit usable width (pt)", "unit_usable_width_pt"),
          ("Note usable width (pt)", "note_usable_width_pt"), ("Normal / wrapped height (pt)", None),
          ("Overflow / clipping / cropping", None)]
for label, key in fields:
    values = []
    for v in "ABC":
        r = reports[v]
        values.append(str(r[key]) if key else
                      f'{r["initial_school_bands"]} / {r["continuation_bands"]}' if label.startswith("Initial") else
                      f'{r["normal_row_pt"]} / {r["wrapped_row_pt"]}' if label.startswith("Normal") else "None")
    data.append([label, *values])
y = table(data, [188, 115, 115, 115], 755)
for line in [
    "Recommendation: B. 13 pages, 30 pt rows and 54.5 pt usable Unit clearance.",
    "A saves one page. C adds writing height and Unit/Ingredient clearance,",
    "uses 15 pages and trades Note width for that extra clearance.",
    "All widths are logical workbook pt, before 96% print scale; Miếng = 46.995 pt.",
    "All specimens: frozen rows 1-3; repeated print titles 1:3; one Table; no band merges.",
    "Quantity header: retain SỐ LƯỢNG. It fits all three; SL gains no body space.",
    "No row striping: neutral School bands and ruled rows provide clear scanning.",
    "Native PDFs were uniformly scaled from 620 x 876.88 pt to physical A4.",
    "School ID is identity; hidden School Name is a validated snapshot on every data row.",
    "No business write. Final geometry and hosted acceptance remain pending. Freeze HOLD.",
]:
    y -= 19
    text(28, y, line, 10)
c.showPage()
for variant in "ABC":
    page_texts = texts[variant]
    selections = {0: "First Schools, kg, Cái and Miếng"}
    many = next(i for i, t in enumerate(page_texts) if "THUẬN GIAO" in t)
    selections[many] = "School with 16 data lines"
    continuation = next(i for i, t in enumerate(page_texts) if "(tiếp)" in t)
    selections[continuation] = "Continuation at first body row"
    count_page = max(range(len(page_texts)), key=lambda i: sum(u in page_texts[i] for u in ["Cốc", "Gói", "Hộp", "Quả", "Trái"]))
    selections[count_page] = "Count/package Units"
    for i, label in sorted(selections.items()):
        text(28, 813, f"{variant} - native specimen page {i+1}: {label}", 12, True)
        image_path = next(p for p in qa.glob(f"{variant}-[0-9]*.png") if int(p.stem.split("-")[-1]) == i + 1)
        c.drawImage(str(image_path), 28, 26, width=A4[0]-56, height=770, preserveAspectRatio=True, anchor="c")
        c.showPage()
text(28, 807, "Hidden-column / flat DATA_LINE view", 17, True)
text(28, 783, "Values read in native Excel after unprotect/unhide F:Q; original specimens unchanged.", 10)
flat = native["B"]["flat_data"][:3]
y = table([["__school_name", "Ingredient / Unit / Qty", "__school_id"],
           *[[r["school_name"], f'{r["ingredient"]} / {r["unit"]} / {r["quantity"]}', r["school_id"]] for r in flat]],
          [145, 175, 213], 758)
y -= 30
for row in flat:
    text(28, y, row["ingredient"], 11, True)
    y -= 10
    y = table([["Hidden field", "Copied value"],
               *[[key, row[field]] for key, field in [("__line_id", "line_id"), ("__revision_id", "revision_id"),
                                                      ("__ingredient_id", "ingredient_id"), ("__unit_id", "unit_id"),
                                                      ("__exported_quantity", "exported_quantity")]]], [145, 388], y)
    y -= 20
assert y > 20, "Hidden view exceeds printable page"
c.save()
with pdfplumber.open(out / "ShoppingList-SchoolBand-Comparison.pdf") as comparison:
    for page in comparison.pages:
        assert abs(page.width - A4[0]) < 0.02 and abs(page.height - A4[1]) < 0.02
        for word in page.extract_words():
            assert 20 <= word["x0"] <= word["x1"] <= page.width - 20
            assert 15 <= word["top"] <= word["bottom"] <= page.height - 20
(out / "comparison-report.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({v: {k: reports[v][k] for k in ["pdf_pages", "data_rows_per_page", "unit_usable_width_pt", "note_usable_width_pt", "pdf_content_check"]} for v in "ABC"}, ensure_ascii=False))
