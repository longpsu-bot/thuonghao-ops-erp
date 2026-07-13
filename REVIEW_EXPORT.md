# OPS Atlas UI review export

This repository can generate a downloadable `atlas-ui-review` artifact for staff review on every pull request to `main`.

## What this artifact is

`atlas-ui-review` is a static build of the current OPS Atlas React prototype. It is intended for reviewing the user interface and workflow direction only.

It is not a production OPS system. It does not connect to Supabase, Retool, Google Sheets, or production data. The screens use local/mock prototype data only.

## How to download it from a pull request

1. Open the pull request in GitHub.
2. Open the **Checks** tab.
3. Select the **UI Review Export** workflow run.
4. Wait until the workflow completes successfully.
5. In the workflow run page, scroll to **Artifacts**.
6. Download **atlas-ui-review**.
7. Unzip the downloaded file.

## How staff can review it

For quick review, open the exported files with a simple local static server instead of double-clicking `index.html` directly.

Example:

```bash
cd path/to/unzipped/atlas-ui-review
python -m http.server 4173
```

Then open:

```text
http://localhost:4173
```

## What feedback should focus on

Staff feedback should focus on:

- layout clarity
- Vietnamese wording
- workflow clarity
- missing screens or missing operational steps
- whether the UI matches real school catering operations
- whether warehouse, purchase, dispatch, attendance, and planner responsibilities are easy to understand

Do not use this artifact to validate final business calculations, Supabase behavior, Retool behavior, permissions, exports, or production data correctness.
