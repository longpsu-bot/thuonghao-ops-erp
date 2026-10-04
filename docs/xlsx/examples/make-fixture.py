"""Create deterministic synthetic print and supplier-selection evidence only."""

import json
from pathlib import Path
from uuid import UUID


def identity(value):
    return str(UUID(int=value))


dates = ["2026-04-20", "2026-04-21", "2026-04-22"]
schools = [
    (10, "Trường mẫu khu vực phía đông nam", 14),
    (20, "Trường mẫu B", 5),
    (30, "Trường mẫu C", 25),
]
names = [
    "Ớt hiểm đỏ", "Tỏi", "Cà rốt", "Cải ngọt",
    "Rau mẫu",
    "Hành lá", "Gạo tẻ", "Thịt heo nạc", "Trứng gà", "Dầu ăn", "Muối", "Nước mắm",
    "Rau ngót", "Bí đỏ", "Khoai tây", "Cà chua", "Cần ta", "Dưa leo",
    "Bắp cải", "Đậu cô ve", "Su su", "Củ cải trắng", "Nấm rơm", "Sữa chua ăn",
    "Thịt gà phi lê", "Cá basa phi lê", "Tôm tươi", "Đậu hũ", "Bún tươi", "Miến dong",
    "Bột năng", "Đường cát", "Hạt nêm", "Rau muống", "Cải thìa", "Súp lơ xanh",
]
units = {"Kg": identity(301), "Quả": identity(302), "Lít": identity(303)}
suppliers = [
    {"supplier_id": identity(501), "supplier_name": "Kho mẫu A", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(502), "supplier_name": "Kho mẫu D", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(503), "supplier_name": "Nhà cung cấp thay thế A", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(504), "supplier_name": "Nhà cung cấp thay thế B", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(505), "supplier_name": "Kho mẫu B", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(506), "supplier_name": "Nhà cung cấp tạm ngưng", "supplier_status": "INACTIVE"},
    {"supplier_id": identity(507), "supplier_name": "Kho mẫu C", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(508), "supplier_name": "Kho mẫu E", "supplier_status": "ACTIVE"},
]


def eligibility(ingredient, supplier, priority, start="2026-01-01", end=None, status="ACTIVE"):
    return {
        "ingredient_id": identity(400 + ingredient),
        "supplier_id": identity(500 + supplier),
        "priority": priority,
        "effective_from": start,
        "effective_to": end,
        "eligibility_status": status,
    }


eligibilities = [
    eligibility(0, 1, 1),
    eligibility(1, 2, 1), eligibility(1, 3, 2), eligibility(1, 4, 3),
    eligibility(2, 6, 1), eligibility(2, 5, 2),
    eligibility(3, 3, 1, status="INACTIVE"), eligibility(3, 7, 2),
    eligibility(4, 3, 1, start="2026-04-22"), eligibility(4, 7, 2),
    eligibility(5, 3, 1, end="2026-04-20"), eligibility(5, 8, 2),
]
for index in range(6, len(names)):
    if index % 4 != 3:
        eligibilities.append(eligibility(index, [1, 2, 5, 7, 8][index % 5], 1))

quantities = ["0.2", "1", "3", "7", "31", "0.5", "25", "12.5", "60", "2.5", "0.5", "1.5"]
rows = []
for date_index, service_date in enumerate(dates):
    school_specs = schools if date_index == 0 else ([(20, "Trường mẫu B", 5), (30, "Trường mẫu C", 7)] if date_index == 1 else [(20, "Trường mẫu B", 3)])
    for display_order, school_name, count in school_specs:
        for ingredient_index in range(count):
            number = len(rows) + 1
            unit = "Quả" if ingredient_index == 8 else ("Lít" if ingredient_index in [9, 11] else "Kg")
            quantity = "1.234567" if ingredient_index == 4 else ("0" if ingredient_index == 11 else quantities[ingredient_index % len(quantities)])
            rows.append({
                "confirmed_need_line_id": identity(1000 + number),
                "current_revision_id": identity(2000 + number),
                "current_decision_id": identity(3000 + number) if ingredient_index == 1 else None,
                "service_date": service_date,
                "school_id": identity(100 + display_order),
                "school_name": school_name,
                "school_display_order": display_order,
                "delivery_location_id": identity(900) if date_index == 2 and ingredient_index > 0 else identity(200 + display_order),
                "delivery_location_name": "Bếp phụ" if date_index == 2 and ingredient_index > 0 else "Bếp chính",
                "ingredient_id": identity(400 + ingredient_index),
                "ingredient_name": names[ingredient_index],
                "unit_id": units[unit],
                "unit_code": unit,
                "exact_quantity": quantity,
                "reason_code": "OPERATIONAL_QUANTITY_ADJUSTMENT" if ingredient_index == 1 else "PROPOSAL_ACCEPTED",
                "reason_note": "Điều chỉnh theo số suất đã xác nhận" if ingredient_index == 1 else "",
                "planning_step": "0.000001" if ingredient_index == 4 else ("1" if unit == "Quả" else "0.1"),
                "source_order": number,
            })


# Separate presentation stress rows: no artificial all-field-maxima row.
by_source = {row["source_order"]: row for row in rows}
stress_school = "Trường mẫu khu vực phía đông nam"
stress_location = "Bếp mô phỏng khu vực phía đông A"
stress_ingredient = "Rau củ mô phỏng sơ chế theo quy cách bếp số mười"
stress_supplier = "Cơ sở thực phẩm giả lập A"
composite_ingredient = "Rau củ mô phỏng theo quy cách bếp mẫu"
composite_supplier = "Kho mẫu phía đông"
assert len(stress_school) == 32 and len(stress_location) == 32
assert len(stress_ingredient) == 48
# Supplier/Ingredient strings remain wholly synthetic.
assert len(stress_supplier) == 25
assert len(composite_supplier) == 17
suppliers.extend([
    {"supplier_id": identity(509), "supplier_name": stress_supplier, "supplier_status": "ACTIVE"},
    {"supplier_id": identity(510), "supplier_name": "Kho", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(511), "supplier_name": composite_supplier, "supplier_status": "ACTIVE"},
])
def stress_line(source_order, ingredient_id, ingredient_name, supplier_id):
    row = by_source[source_order]
    row["ingredient_id"] = identity(ingredient_id)
    row["ingredient_name"] = ingredient_name
    eligibilities.append({"ingredient_id": identity(ingredient_id), "supplier_id": identity(supplier_id), "priority": 1,
        "effective_from": "2026-01-01", "effective_to": None, "eligibility_status": "ACTIVE"})
    return row
# Date 1 first rows of ordinary School groups provide true visible composite/Supplier cases.
composite = stress_line(20, 700, composite_ingredient, 511)
composite["exact_quantity"] = "123456789.1"
stress_line(22, 701, "Ớt mẫu", 509)
by_source[21]["exact_quantity"] = "1234567890.1"
# Ingredient stress occurs under an ordinary School with short Supplier and quantity.
stress_line(50, 702, stress_ingredient, 510)
# Date 3 keeps two Delivery Locations and separate daily authority.
for row in rows:
    if row["service_date"] == dates[2]:
        row["school_id"] = identity(140)
        row["school_name"] = "Trường mẫu khu vực phía đông bắc"
        row["school_display_order"] = 40
        row["delivery_location_id"] = identity(240) if row["source_order"] == 57 else identity(940)
        row["delivery_location_name"] = stress_location if row["source_order"] == 57 else "Bếp mẫu B"
location = stress_line(57, 703, "Rau", 510)
location["exact_quantity"] = "1"

fixture = {
    "synthetic": True,
    "description": "Synthetic three-date collection of distinct authoritative daily batches; print-page and supplier-eligibility stress fixture, never production data.",
    "print_cases": {
        "wrapped_school_ids": [identity(110), identity(140)],
        "wrapped_ingredient_ids": [identity(700), identity(702)],
        "wrapped_supplier_ids": [identity(509)],
    },
    "metadata": {
        "contract_name": "ATLAS_SHOPPING_LIST",
        "contract_version": "ATLAS_SHOPPING_LIST_V1",
        "workbook_marker": identity(9000),
        "exported_at": "2026-04-19T10:00:00.000Z",
        "service_period_start": dates[0],
        "service_period_end": dates[-1],
    },
    "daily_batches": [
        {
            "service_date": service_date,
            "confirmed_need_batch_id": identity(1 + index * 10),
            "batch_version": 7 + index,
            "need_generation_run_id": identity(2 + index * 10),
            "release_snapshot_id": identity(3 + index * 10),
        }
        for index, service_date in enumerate(dates)
    ],
    "suppliers": suppliers,
    "supplier_eligibilities": eligibilities,
    "rows": sorted(rows, key=lambda row: (row["service_date"], row["school_display_order"], row["source_order"], row["confirmed_need_line_id"])),
}

fixture["print_certification"] = {
    "combined_char_envelope": 84,
    "guard_band_percent": 25,
    "observed_snapshot": {"source": "User-supplied read-only non-rehearsal Atlas Staging calibration; no hosted access in this task",
        "row_count": 248, "p95_combined": 58, "p99_combined": 65.53, "max_combined": 67,
        "max_school": 28, "max_location": 28, "max_ingredient": 38, "max_supplier": 17, "max_quantity": 11},
    "field_envelopes": {"school": 32, "location": 32, "ingredient": 48, "supplier": 25, "quantity": 12},
    "stress_lines": {"school": identity(1001), "location": identity(1057), "ingredient": identity(1050),
        "supplier": identity(1022), "quantity": identity(1021), "composite": identity(1020)},
    "out_of_envelope_control": {"name": "OUT_OF_CERTIFIED_PRINT_ENVELOPE",
        "school_display": "Trường Nguyễn Du - Cơ sở phía Đông",
        "ingredient_name": "Đu đủ hường sơ chế, bỏ vỏ và hạt, cắt miếng theo quy cách bếp trường",
        "supplier_name": "Nông sản mô phỏng - giao bếp trường mỗi sáng A",
        "unit_code": "Kg", "quantity": "1.234567"},
}

Path(__file__).with_name("atlas-shopping-list-v1.fixture.json").write_text(
    json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
