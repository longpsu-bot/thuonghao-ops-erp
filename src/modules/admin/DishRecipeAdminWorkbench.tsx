import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  CreateRecipeVersion,
  DishRecipeAdminWorkbench as createReadModel,
  ReleaseRecipeVersionForPlanning,
  ValidateRecipeVersion,
  type DishRecipeAdminState,
} from "./dishRecipeAdminDomain";
import { dishRecipeAdminFixture } from "./dishRecipeAdminFixtures";

const audit = {
  actorId: "admin-lan",
  at: "2026-07-14T06:00:00.000Z",
  reason: "Prototype operator review",
};

const statusTone = (status: string) => {
  if (status === "ACTIVE" || status === "VALIDATED") return "ok" as const;
  if (status === "INACTIVE" || status === "LOCKED") return "warning" as const;
  if (status === "RELEASED_FOR_PLANNING") return "ok" as const;
  return "neutral" as const;
};

export function DishRecipeAdminWorkbench() {
  const [state, setState] = useState<DishRecipeAdminState>(
    dishRecipeAdminFixture,
  );
  const [selectedDishId, setSelectedDishId] = useState("dish-pumpkin-soup");
  const [selectedVersionId, setSelectedVersionId] = useState<string>();
  const [notice, setNotice] = useState("");
  const model = createReadModel(state, selectedDishId, selectedVersionId);

  const validate = () => {
    if (!model.selectedVersion) return;
    const result = ValidateRecipeVersion(state, {
      recipeVersionId: model.selectedVersion.recipeVersionId,
      ...audit,
    });
    if (result.accepted) setState(result.state);
    setNotice(
      result.accepted
        ? "Recipe version validated with Admin review evidence."
        : (result.message ?? "Unable to validate recipe version."),
    );
  };

  const release = () => {
    if (!model.selectedVersion) return;
    const result = ReleaseRecipeVersionForPlanning(state, {
      recipeVersionId: model.selectedVersion.recipeVersionId,
      ...audit,
    });
    if (result.accepted) setState(result.state);
    setNotice(
      result.accepted
        ? `Released ${result.releasedReference?.recipeVersionId} for future Planning reference; prior operational facts were preserved.`
        : (result.message ?? "Unable to release recipe version."),
    );
  };

  const createCorrection = () => {
    if (!model.selectedRecipe || !model.selectedVersion) return;
    const recipeVersionId = `${model.selectedRecipe.recipeId}-v${model.versions.length + 1}`;
    const result = CreateRecipeVersion(state, {
      recipeVersionId,
      recipeId: model.selectedRecipe.recipeId,
      basedOnRecipeVersionId: model.selectedVersion.recipeVersionId,
      copyLines: true,
      ...audit,
      reason:
        "Create an auditable successor instead of editing released history",
    });
    if (result.accepted) {
      setState(result.state);
      setSelectedVersionId(recipeVersionId);
    }
    setNotice(
      result.accepted
        ? "New draft version created; the released or locked source remains unchanged."
        : (result.message ?? "Unable to create successor version."),
    );
  };

  return (
    <Panel
      title="Dishes & Recipes Admin Workbench"
      description="Decision: Is this dish and recipe version safe to release for Planning and Need Generation?"
      status={
        <Chip tone={model.blockingIssueCount ? "danger" : "ok"}>
          {model.blockingIssueCount
            ? `${model.blockingIssueCount} blocking issue(s)`
            : "Ready for governed action"}
        </Chip>
      }
    >
      <div
        className="confirmed-need-summary"
        aria-label="Dishes and recipes administration summary"
      >
        <article>
          <span>Active dishes</span>
          <strong>{model.activeDishCount}</strong>
        </article>
        <article>
          <span>Inactive dishes</span>
          <strong>{model.inactiveDishCount}</strong>
        </article>
        <article>
          <span>No released recipe</span>
          <strong>{model.dishesWithoutReleasedRecipeCount}</strong>
        </article>
        <article>
          <span>Blocking issues</span>
          <strong>{model.blockingIssueCount}</strong>
        </article>
        <article>
          <span>Warnings</span>
          <strong>{model.warningCount}</strong>
        </article>
      </div>

      <div
        className="recipe-admin-selector"
        aria-label="Dish and recipe selection"
      >
        <label>
          Dish
          <select
            aria-label="Dish"
            value={selectedDishId}
            onChange={(event) => {
              setSelectedDishId(event.target.value);
              setSelectedVersionId(undefined);
              setNotice("");
            }}
          >
            {state.dishes.map((dish) => (
              <option key={dish.dishId} value={dish.dishId}>
                {dish.dishName} · {dish.status}
              </option>
            ))}
          </select>
        </label>
        <label>
          Recipe version
          <select
            aria-label="Recipe version"
            value={model.selectedVersion?.recipeVersionId ?? ""}
            onChange={(event) => {
              setSelectedVersionId(event.target.value);
              setNotice("");
            }}
          >
            {!model.versions.length && (
              <option value="">No recipe version</option>
            )}
            {model.versions.map((version) => (
              <option
                key={version.recipeVersionId}
                value={version.recipeVersionId}
              >
                v{version.versionNumber} · {version.status} ·{" "}
                {version.lockStatus}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="recipe-admin-identity">
        <article>
          <span>Dish identity</span>
          <strong>{model.selectedDish.dishName}</strong>
          <small>
            {model.selectedDish.dishCategory ?? "Uncategorized"} · order{" "}
            {model.selectedDish.displayOrder ?? "—"}
          </small>
        </article>
        <article>
          <span>Dish status</span>
          <Chip tone={statusTone(model.selectedDish.status)}>
            {model.selectedDish.status}
          </Chip>
          <small>Admin-owned menu reference</small>
        </article>
        <article>
          <span>Selected lifecycle</span>
          <strong>{model.selectedVersion?.status ?? "NO RECIPE"}</strong>
          <small>
            Lock:{" "}
            {model.versions.find(
              (item) =>
                item.recipeVersionId === model.selectedVersion?.recipeVersionId,
            )?.lockStatus ?? "N/A"}
          </small>
        </article>
      </div>

      <div className="workbench-actions confirmed-need-actions">
        <button onClick={validate} disabled={!model.canValidate}>
          Validate recipe version
        </button>
        <button
          className="primary"
          onClick={release}
          disabled={!model.canRelease}
        >
          Release for Planning
        </button>
        <button
          onClick={createCorrection}
          disabled={
            !model.selectedVersion || model.selectedVersion.status === "DRAFT"
          }
        >
          Create correction version
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}

      <div className="recipe-admin-grid">
        <section aria-labelledby="recipe-versions-heading">
          <h3 id="recipe-versions-heading">Versions & lock state</h3>
          <CompactTable headers={["Version", "Lifecycle", "Lock", "Basis"]}>
            {model.versions.map((version) => (
              <tr key={version.recipeVersionId}>
                <td>v{version.versionNumber}</td>
                <td>
                  <Chip tone={statusTone(version.status)}>
                    {version.status}
                  </Chip>
                </td>
                <td>{version.lockStatus}</td>
                <td>{version.basedOnRecipeVersionId ?? "Initial version"}</td>
              </tr>
            ))}
          </CompactTable>
        </section>

        <section aria-labelledby="recipe-bom-heading">
          <h3 id="recipe-bom-heading">BOM lines</h3>
          <CompactTable
            headers={["Ingredient", "Quantity", "Unit", "Reference"]}
          >
            {model.lines.map((line) => (
              <tr key={line.recipeLineId}>
                <td>
                  {line.ingredientName}
                  <small>{line.ingredientId}</small>
                </td>
                <td>{line.quantity}</td>
                <td>{line.unit}</td>
                <td>{line.ingredientStatus ?? "MISSING"}</td>
              </tr>
            ))}
          </CompactTable>
          {!model.lines.length && (
            <p className="supporting-copy">No BOM lines recorded.</p>
          )}
        </section>

        <section aria-labelledby="recipe-variants-heading">
          <h3 id="recipe-variants-heading">School-type variants</h3>
          <CompactTable
            headers={["School type", "Base line", "Quantity", "Reason"]}
          >
            {model.variants.map((variant) => (
              <tr key={variant.schoolTypeRecipeVariantId}>
                <td>{variant.schoolTypeId}</td>
                <td>{variant.recipeLineId}</td>
                <td>
                  {variant.quantity} {variant.unit}
                </td>
                <td>{variant.reason}</td>
              </tr>
            ))}
          </CompactTable>
          {!model.variants.length && (
            <p className="supporting-copy">No school-type variants recorded.</p>
          )}
        </section>

        <section aria-labelledby="recipe-evidence-heading">
          <h3 id="recipe-evidence-heading">Change & review evidence</h3>
          {model.changeSets.map((changeSet) => (
            <article
              className="recipe-evidence-card"
              key={changeSet.recipeChangeSetId}
            >
              <strong>{changeSet.summary}</strong>
              <small>
                {changeSet.status} · {changeSet.fromRecipeVersionId} →{" "}
                {changeSet.toRecipeVersionId}
              </small>
            </article>
          ))}
          {model.reviewEvidence.map((evidence) => (
            <article
              className="recipe-evidence-card"
              key={evidence.recipeReviewEvidenceId}
            >
              <strong>{evidence.outcome}</strong>
              <small>{evidence.evidence}</small>
              <small>QA approval: no · Production approval: no</small>
            </article>
          ))}
          {!model.changeSets.length && !model.reviewEvidence.length && (
            <p className="supporting-copy">
              No change set or review evidence recorded.
            </p>
          )}
        </section>

        <section aria-labelledby="recipe-issues-heading">
          <h3 id="recipe-issues-heading">Blockers & warnings</h3>
          {[...model.blockers, ...model.warnings].map((issue, index) => (
            <article
              className="recipe-issue-card"
              key={`${issue.issueCode}-${index}`}
            >
              <Chip tone={issue.isBlocking ? "danger" : "warning"}>
                {issue.isBlocking ? "BLOCKER" : "WARNING"}
              </Chip>
              <strong>{issue.message}</strong>
              <small>{issue.issueCode}</small>
            </article>
          ))}
          {!model.blockers.length && !model.warnings.length && (
            <p className="supporting-copy">
              No blockers or warnings for this selection.
            </p>
          )}
        </section>

        <section aria-labelledby="recipe-usage-heading">
          <h3 id="recipe-usage-heading">Downstream references & boundary</h3>
          {model.downstreamUsage.map((usage) => (
            <article className="recipe-evidence-card" key={usage.usageId}>
              <strong>{usage.domain}</strong>
              <small>
                {usage.referenceId} · {usage.recipeVersionId}
              </small>
            </article>
          ))}
          <p className="supporting-copy">{model.boundaryNote}</p>
        </section>
      </div>

      <p className="weekly-menu-audit">
        Change history:{" "}
        {model.changeHistory.map((change) => change.changeType).join(" · ") ||
          "No changes recorded"}
      </p>
    </Panel>
  );
}
