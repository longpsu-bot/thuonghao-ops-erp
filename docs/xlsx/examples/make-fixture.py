"""Generate synthetic review evidence only; no application imports or network access."""

import json
from pathlib import Path
from uuid import UUID


def identity(value):
    return str(UUID(int=value))


schools = [
    (20, "Trường mẫu Bình Minh"),
    (10, "Trường mẫu Tiểu học và Trung học cơ sở Nguyễn Du – Cơ sở phía Đông"),
    (30, "Trường mẫu An Hòa"),
]
ingredients = [
    ("Gạo tẻ", "Kg", "25", "0.1"),
    ("Thịt heo nạc", "Kg", "12.5", "0.1"),
    ("Cà rốt", "Kg", "8", "0.1"),
    ("Ớt hiểm đỏ", "Kg", "0.2", "0.1"),
    ("Tỏi", "Kg", "1.234567", "0.000001"),
    ("Cải ngọt", "Kg", "7", "0.1"),
    ("Đu đủ hường sơ chế, bỏ vỏ và hạt, cắt miếng theo quy cách bếp trường", "Kg", "31", "0.1"),
    ("Trứng gà", "Quả", "60", "1"),
    ("Dầu ăn", "Lít", "2.5", "0.1"),
    ("Muối", "Kg", "0.5", "0.1"),
    ("Nước mắm", "Lít", "1.5", "0.1"),
    ("Hành lá", "Kg", "0", "0.1"),
    ("Gạo tẻ hạt dài", "Kg", "10", "0.1"),
]
unit_ids = {"Kg": identity(301), "Quả": identity(302), "Lít": identity(303)}
rows = []
for date_index, date in enumerate(["2026-04-20", "2026-04-21"]):
    for school_index, (display_order, school_name) in enumerate(schools):
        for ingredient_index, (name, unit, quantity, step) in enumerate(ingredients):
            number = len(rows) + 1
            existing = ingredient_index == 1
            rows.append({
                "confirmed_need_line_id": identity(1000 + number),
                "current_revision_id": identity(2000 + number),
                "current_decision_id": identity(3000 + number) if existing else None,
                "service_date": date,
                "school_id": identity(100 + school_index),
                "school_name": school_name,
                "school_display_order": display_order,
                "delivery_location_id": identity(200 + school_index),
                "delivery_location_name": "Bếp chính",
                "ingredient_id": identity(400 + ingredient_index),
                "ingredient_name": name,
                "unit_id": unit_ids[unit],
                "unit_code": unit,
                "exact_quantity": quantity,
                "reason_code": "OPERATIONAL_QUANTITY_ADJUSTMENT" if existing else "PROPOSAL_ACCEPTED",
                "reason_note": "Điều chỉnh theo số suất đã xác nhận" if existing else "",
                "shopping_note": "NCC dự kiến: Nhà cung cấp mẫu A" if ingredient_index in [0, 1] else ("NCC dự kiến: Nhà cung cấp mẫu B – chọn rau tươi" if ingredient_index == 5 else ""),
                "planning_step": step,
                "source_order": number,
            })
        # Same School/Ingredient/Unit at another location must remain another row.
        if school_index == 0:
            row = dict(rows[-13])
            number = len(rows) + 1
            row.update({
                "confirmed_need_line_id": identity(1000 + number),
                "current_revision_id": identity(2000 + number),
                "delivery_location_id": identity(250),
                "delivery_location_name": "Bếp phụ",
                "exact_quantity": "5",
                "source_order": number,
            })
            rows.append(row)

fixture = {
    "synthetic": True,
    "description": "Synthetic retained multi-day batch shape; not a new daily generation policy.",
    "metadata": {
        "contract_name": "ATLAS_SHOPPING_LIST",
        "contract_version": "ATLAS_SHOPPING_LIST_V1",
        "workbook_marker": identity(9000),
        "exported_at": "2026-04-19T10:00:00.000Z",
        "service_period_start": "2026-04-20",
        "service_period_end": "2026-04-21",
        "confirmed_need_batch_id": identity(1),
        "batch_version": 7,
        "need_generation_run_id": identity(2),
        "release_snapshot_id": identity(3),
    },
    "rows": sorted(rows, key=lambda row: (row["service_date"], row["school_display_order"], row["source_order"], row["confirmed_need_line_id"])),
}
Path(__file__).with_name("atlas-shopping-list-v1.fixture.json").write_text(
    json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
