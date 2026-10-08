"""Read exported/native PDFs, reconcile visible text, and render review contact sheets."""
from pathlib import Path
import json
import re
import sys
import fitz
from PIL import Image, ImageDraw

root = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/testing/artifacts/atlas-document-system-01")
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
normalize = lambda value: re.sub(r"\s+", "", str(value)).replace("\u00a0", "")
report = []
for file in manifest["files"]:
    if file["name"].endswith(".zip"):
        continue
    if not file["name"].endswith(".xlsx"):
        document = fitz.open(root / file["name"])
        text = normalize("".join(page.get_text() for page in document))
        assert "undefined" not in text, f"Invalid fixture label: {file['name']}"
        missing = [value for value in file["visibleStrings"] if normalize(value) not in text]
        report.append({"pdf": file["name"], "pages": len(document), "missing_visible_strings": missing})
        continue
    for index, sheet in enumerate(file["sheets"], 1):
        pdf = root / "native-qa" / file["name"].replace(".xlsx", f"-sheet-{index}.pdf")
        document = fitz.open(pdf)
        text = normalize("".join(page.get_text() for page in document))
        assert "undefined" not in text, f"Invalid fixture label: {pdf.name}"
        missing = [cell for cell in sheet["cells"] if not cell.get("hidden") and isinstance(cell["value"], str) and (len(cell["value"]) > 7 or cell.get("quantity")) and normalize(cell["value"]) not in text]
        report.append({"pdf": pdf.name, "pages": len(document), "missing_visible_strings": missing})
        for page_index, page in enumerate(document):
            page_text = normalize(page.get_text())
            if normalize("Người nhận hàng") in page_text:
                assert normalize("Người giao hàng") in page_text and normalize("Người lập phiếu") in page_text, f"Split signatures: {pdf.name} page {page_index + 1}"
                blocks = [block for block in page.get_text("blocks") if normalize("Ký, ghi họ tên") in normalize(block[4])]
                assert blocks and page.rect.height - max(block[3] for block in blocks) >= 100, f"No handwriting space: {pdf.name} page {page_index + 1}"
        if file["name"] == "Purchase-review-preliminary.xlsx":
            for page_index, page in enumerate(document):
                page_text = page.get_text()
                # Every page with a quantity must carry its supplier, and detail
                # pages must also carry the destination on that physical page.
                if re.search(r"\d+\.\d{6}", page_text):
                    assert "NCC đề xuất:" in page_text, f"Missing supplier: {pdf.name} page {page_index + 1}"
                    if index == 2:
                        assert "Trường mẫu" in page_text and "Bếp mẫu" in page_text, f"Missing destination: {pdf.name} page {page_index + 1}"

(root / "pdf-text-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps([{**record, "missing_visible_strings": record["missing_visible_strings"][:8]} for record in report if record["missing_visible_strings"]], ensure_ascii=True, indent=2))
assert not any(record["missing_visible_strings"] for record in report), "Printed text is missing"

files = sorted(root.glob("*.pdf")) + sorted((root / "native-qa").glob("*.pdf"))
pages = [(file, index) for file in files for index in range(len(fitz.open(file)))]
for previous in root.glob("visual-review-*.png"):
    previous.unlink()
for start in range(0, len(pages), 8):
    canvas = Image.new("RGB", (1600, 2200), "#dddddd")
    draw = ImageDraw.Draw(canvas)
    for offset, (file, page_index) in enumerate(pages[start:start + 8]):
        document = fitz.open(file)
        pixmap = document[page_index].get_pixmap(matrix=fitz.Matrix(1.3, 1.3), alpha=False)
        picture = Image.frombytes("RGB", [pixmap.width, pixmap.height], pixmap.samples)
        picture.thumbnail((780, 510))
        x, y = (offset % 2) * 800, (offset // 2) * 550
        canvas.paste(picture, (x, y + 30))
        draw.text((x + 10, y + 8), f"{file.name} · {page_index + 1}", fill="black")
    canvas.save(root / f"visual-review-{start // 8 + 1:02}.png")
print(f"Rendered every page: {len(pages)} pages in {(len(pages) + 7) // 8} contact sheets.")
