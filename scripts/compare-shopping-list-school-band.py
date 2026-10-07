"""Normalize the final A+ native PDF to A4 and verify every page.

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
import hashlib
from PIL import Image, ImageDraw
from pypdf import PdfReader, PdfWriter
from pypdf.generic import RectangleObject
from reportlab.lib.pagesizes import A4

out = Path(sys.argv[1]).resolve()
qa = out / "qa"
qa.mkdir(exist_ok=True)
spec = json.loads((out / "specimen-report.json").read_text(encoding="utf-8"))
native = json.loads((out / "excel-report.json").read_text(encoding="utf-8-sig"))
authority = json.loads((out / "authority-2026-09-17.json").read_text(encoding="utf-8"))
assert len(authority["workbench"]["lines"]) == 248
compact = lambda text: re.sub(r"\s+", "", unicodedata.normalize("NFC", text or ""))
reports = {}
variant = "A+"
pdf = out / "ShoppingList-SchoolBand-APlus-2026-09-17.pdf"
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
unit_values = []
quantity_values = []
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
        unit_right = right + native[variant]["column_widths_pt"][2] * 0.96
        quantity_right = unit_right + native[variant]["column_widths_pt"][3] * 0.96
        unit_values += [w["text"] for w in page.crop((right, 0, unit_right, page.height)).extract_words()
                        if w["text"] in spec[variant]["units"]]
        quantity_values += [w["text"] for w in page.crop((unit_right, 0, quantity_right, page.height)).extract_words()
                            if re.fullmatch(r"[0-9]+(?:[.,][0-9]+)?", w["text"])]
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


assert len(reader.pages) == 12, "Owner acceptance requires A+ to remain 12 pages"
data_rows = [r for r in rows if r["kind"] == "DATA_LINE"]
assert collections.Counter(unit_values) == collections.Counter(r["visible"][2] for r in data_rows), "Unit label lost/clipped"
assert collections.Counter(quantity_values) == collections.Counter(r["visible"][3] for r in data_rows), "PDF quantities differ from clean XLSX"
assert data_rows[0]["visible"][3] == "228.01"
clean_xlsx = out / "ShoppingList-SchoolBand-APlus-2026-09-17.xlsx"
assert hashlib.sha256(clean_xlsx.read_bytes()).hexdigest().upper() == native[variant]["clean_sha256"]
reports[variant].update(clean_deliverable_unchanged=True, pdf_quantities="PASS", pdf_unit_labels="PASS")
(out / "final-pdf-report.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(reports, indent=2))
