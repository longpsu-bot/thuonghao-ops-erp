# Atlas UI review instructions

## Preferred review: GitHub Pages

Open the Atlas UI review site in a normal browser:

`https://longpsu-bot.github.io/thuonghao-ops-erp/`

Use this as the preferred method for reviewing the full workflow. No download, unzipping, launcher, local server, Python, Node, pnpm, npm, Git, or developer tools are required. The site is updated after the GitHub Pages deployment workflow completes on `main`.

## App preview artifact: fallback full workflow review

1. Download the `atlas-ui-review` artifact.
2. Unzip the download.
3. Double-click `Open Atlas Review.bat`.
4. Keep the launcher window open while you review the full workflow.

The launcher opens the preview in your browser. No Python, Node, pnpm, npm, Git, or developer tools are required. Close the launcher window when you finish reviewing. If the launcher does not work but `index.html` opens correctly in your browser, you may use `index.html` as a fallback.

Use the app preview to review the end-to-end workflow, including how pages and workflow states connect. This download remains a fallback if the GitHub Pages site is unavailable.

## Storybook preview: component and state review

1. Download the `atlas-storybook-review` artifact.
2. Unzip the download.
3. Double-click `Open Storybook Review.bat`.
4. Keep the launcher window open while you review isolated UI components and states.

The launcher opens the preview in your browser. No Python, Node, pnpm, npm, Git, or developer tools are required. Close the launcher window when you finish reviewing. If the launcher does not work but `index.html` opens correctly in your browser, you may use `index.html` as a fallback.

Use the Storybook preview to focus on individual components, representative states, and the wording or visual treatment of those states.

## Scope of all previews

Review only the layout, wording, workflow structure, and mocked UI states. The GitHub Pages site and both artifacts contain no backend, Supabase data, Retool integration, production data, credentials, or real operations.

Do not review backend correctness, Supabase data, Retool parity, real calculations, document generation, inventory, payment, or accounting yet. The previews do not perform real import or export, generate real documents, update inventory, run QA, process payments, or create invoices.
