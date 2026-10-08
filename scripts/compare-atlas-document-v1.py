"""Compare actual owner/native and production prints; never invent a reference."""
from pathlib import Path
import json
import shutil
import sys
import fitz
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
references = Path(sys.argv[2])
reference_output = root / "owner-reference-print"
reference_output.mkdir(exist_ok=True)
comparisons = []
for label, reference, native, production in [
    ("PO-theo-hang", "3F_20-04-2026_ALL_GROUPED-sheet-1.pdf", "V1-equivalent-3F-all-sheet-1.pdf", "V1-equivalent-3F-details_ing.pdf"),
    ("PO-theo-truong", "3F_20-04-2026_ALL_GROUPED-sheet-2.pdf", "V1-equivalent-3F-all-sheet-2.pdf", "V1-equivalent-3F-details_school.pdf"),
    ("PO-tong", "3F_20-04-2026_ALL_GROUPED-sheet-3.pdf", "V1-equivalent-3F-all-sheet-3.pdf", "V1-equivalent-3F-sum.pdf"),
    ("PXK-13", "Dispatch_GROUPED_20-04-2026-sheet-1.pdf", "V1-equivalent-PXK-13-sheet-1.pdf", "V1-equivalent-PXK-13.pdf"),
]:
    shutil.copyfile(references / reference, reference_output / reference)
    files = [reference_output / reference, root / "native-qa" / native, root / production]
    documents = [fitz.open(file) for file in files]
    comparisons.append({"document": label, "V1_native_pages": len(documents[0]), "Atlas_native_pages": len(documents[1]), "Atlas_production_PDF_pages": len(documents[2])})
    for index in range(max(map(len, documents))):
        canvas = Image.new("RGB", (2100, 1040), "#eeeeee")
        draw = ImageDraw.Draw(canvas)
        for column, (document, heading) in enumerate(zip(documents, ["Owner V1 native", "Atlas native XLSX", "Atlas production PDF"])):
            x = column * 700
            draw.text((x + 10, 8), f"{heading} | {label} | page {index + 1}", fill="black")
            if index >= len(document):
                draw.text((x + 10, 40), "No page in this export", fill="black")
                continue
            pixmap = document[index].get_pixmap(matrix=fitz.Matrix(1.3, 1.3), alpha=False)
            picture = Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)
            picture.thumbnail((690, 995))
            canvas.paste(picture, (x + 5, 35))
        canvas.save(root / f"side-by-side-{label}-{index + 1}.png")

# These families have no owner V1 reference in the supplied files. Compare the
# reviewed Atlas baseline with this revision and label that limitation explicitly.
for name, sheets in [("Shopping-list-APlus-preserved", 1), ("Attendance-import-template", 2), ("Purchase-review-preliminary", 2)]:
    for sheet in range(1, sheets + 1):
        filename = f"{name}-sheet-{sheet}.pdf"
        files = [root.parent / "native-qa" / filename, root / "native-qa" / filename]
        canvas = Image.new("RGB", (1400, 1040), "#eeeeee")
        draw = ImageDraw.Draw(canvas)
        for column, (file, heading) in enumerate(zip(files, ["Reviewed Atlas baseline (no owner V1 reference)", "Current Atlas revision"])):
            document = fitz.open(file)
            pixmap = document[0].get_pixmap(matrix=fitz.Matrix(1.3, 1.3), alpha=False)
            picture = Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)
            picture.thumbnail((690, 995))
            draw.text((column * 700 + 10, 8), heading, fill="black")
            canvas.paste(picture, (column * 700 + 5, 35))
        canvas.save(root / f"baseline-comparison-{name}-{sheet}.png")
(root / "comparison-pages.json").write_text(json.dumps(comparisons, indent=2) + "\n", encoding="utf8")
print(json.dumps(comparisons))
