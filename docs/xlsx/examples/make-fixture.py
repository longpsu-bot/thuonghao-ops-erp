"""Create deterministic synthetic print and supplier-selection evidence only."""

import json
from pathlib import Path
from uuid import UUID


def identity(value):
    return str(UUID(int=value))


dates = ["2026-04-20", "2026-04-21", "2026-04-22"]
schools = [
    (10, "Trường Nguyễn Du - Cơ sở phía Đông", 14),
    (20, "Tân Định", 5),
    (30, "Tân Bình", 25),
]
names = [
    "Ớt hiểm đỏ", "Tỏi", "Cà rốt", "Cải ngọt",
    "Đu đủ hường sơ chế, bỏ vỏ và hạt, cắt miếng theo quy cách bếp trường",
    "Hành lá", "Gạo tẻ", "Thịt heo nạc", "Trứng gà", "Dầu ăn", "Muối", "Nước mắm",
    "Rau ngót", "Bí đỏ", "Khoai tây", "Cà chua", "Cần ta", "Dưa leo",
    "Bắp cải", "Đậu cô ve", "Su su", "Củ cải trắng", "Nấm rơm", "Sữa chua ăn",
    "Thịt gà phi lê", "Cá basa phi lê", "Tôm tươi", "Đậu hũ", "Bún tươi", "Miến dong",
    "Bột năng", "Đường cát", "Hạt nêm", "Rau muống", "Cải thìa", "Súp lơ xanh",
]
units = {"Kg": identity(301), "Quả": identity(302), "Lít": identity(303)}
suppliers = [
    {"supplier_id": identity(501), "supplier_name": "Công ty Hoàng Dung Dairy", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(502), "supplier_name": "An Phú", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(503), "supplier_name": "Nhà cung cấp thay thế A", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(504), "supplier_name": "Nhà cung cấp thay thế B", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(505), "supplier_name": "Nông sản Bình Minh - giao bếp trường mỗi sáng", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(506), "supplier_name": "Nhà cung cấp tạm ngưng", "supplier_status": "INACTIVE"},
    {"supplier_id": identity(507), "supplier_name": "Tân Thành", "supplier_status": "ACTIVE"},
    {"supplier_id": identity(508), "supplier_name": "Chợ A", "supplier_status": "ACTIVE"},
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
    school_specs = schools if date_index == 0 else ([(20, "Tân Định", 5), (30, "Tân Bình", 7)] if date_index == 1 else [(20, "Tân Định", 3)])
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

fixture = {
    "synthetic": True,
    "description": "Synthetic three-date collection of distinct authoritative daily batches; print-page and supplier-eligibility stress fixture, never production data.",
    "print_cases": {
        "two_line_school_ids": [identity(110)],
        "two_line_ingredient_ids": [identity(404)],
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
Path(__file__).with_name("atlas-shopping-list-v1.fixture.json").write_text(
    json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
