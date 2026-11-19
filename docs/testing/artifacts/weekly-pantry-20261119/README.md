# Weekly Pantry workbench

In the local review application, the operator selected Trường Lê Lợi and Gạo thơm
with the keyboard, entered 0.65 kg per menu day, checked the calculated week,
saved the rule and stopped it. The displayed week had one menu day. The rule
list and preview expose the delivery date and exact quantity for that school.
The 390 px viewport had no page-level horizontal overflow.

| State | Laptop | Phone |
| --- | --- | --- |
| Daily entry before the change | [1366 px](pantry-before-1366.png) | [390 px](pantry-before-390.png) |
| Weekly rules | [1366 px](pantry-weekly-1366.png) | [390 px](pantry-weekly-390.png) |
| Quantity preview | [1366 px](pantry-preview-1366.png) | [390 px](pantry-preview-390.png) |

Database coverage uses authenticated RPCs against a disposable local PostgreSQL
instance. The four-source case in `pantry_b1_composition.sql` checks 20 kg from
the recipe, 5 kg of supplements, 3 kg of manual orders and 2 kg of automatic
orders, with an exact total of 30 kg and evidence of five menu days at 0.4 kg.
