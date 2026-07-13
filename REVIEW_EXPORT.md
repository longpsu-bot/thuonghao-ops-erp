# Atlas UI review export

Every pull request to `main` runs the **Atlas UI Review Export** workflow. After
the checks pass, it publishes an `atlas-ui-review` artifact containing the
built static UI files.

## Download and review

1. Open the pull request on GitHub and select the **Checks** tab.
2. Open the completed **Atlas UI Review Export** workflow run.
3. In the **Artifacts** section, download `atlas-ui-review` and unzip it.
4. Open the extracted `index.html` in a browser, then navigate through the
   screens and workflows.

This export is a UI prototype only. It uses mock/local data only; it does not
connect to Supabase, Retool, production data, or operational systems.

Please focus feedback on layout, wording, workflow clarity, missing screens,
and operational fit.
