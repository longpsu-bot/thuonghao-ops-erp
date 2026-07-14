import { useState } from "react";
import { Chip, CompactTable, Panel } from "../atlas/WorkbenchComponents";
import {
  IngredientSupplierAdminWorkbench as createReadModel,
  SetDefaultSupplierPolicy,
  SetIngredientSupplierEligibility,
  type IngredientSupplierAdminState,
} from "./ingredientSupplierAdminDomain";
import { ingredientSupplierAdminFixture } from "./ingredientSupplierAdminFixtures";

const audit = {
  actorId: "admin-lan",
  at: "2026-07-14T05:00:00.000Z",
  reason: "Prototype operator review",
};

export function IngredientSupplierAdminWorkbench() {
  const [state, setState] = useState<IngredientSupplierAdminState>(
    ingredientSupplierAdminFixture,
  );
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const model = createReadModel(state);

  const recordEligibility = () => {
    const result = SetIngredientSupplierEligibility(state, {
      ingredientId: "ingredient-rice",
      supplierId: "supplier-minh-tam",
      status: "ELIGIBLE",
      ...audit,
    });
    if (result.accepted) setState(result.state);
    setNotice(
      result.accepted
        ? "Ingredient-supplier eligibility recorded with audit evidence."
        : (result.message ?? "Unable to change eligibility."),
    );
  };

  const recordPreference = () => {
    const result = SetDefaultSupplierPolicy(state, {
      defaultSupplierPolicyId: "rice-preferred-minh-tam",
      ingredientId: "ingredient-rice",
      supplierId: "supplier-minh-tam",
      preference: "PREFERRED",
      status: "ACTIVE",
      ...audit,
    });
    if (result.accepted) setState(result.state);
    setNotice(
      result.accepted
        ? "Preferred supplier reference recorded; no PO or supplier commitment was created."
        : (result.message ?? "Unable to change supplier preference."),
    );
  };

  return (
    <Panel
      title="Ingredients & Suppliers Admin Workbench"
      description="Decisions: Is this ingredient valid for recipes, Planning, Procurement, and Warehouse use? Which suppliers are active and eligible for which ingredients?"
      status={
        <Chip tone={model.blockingIssueCount ? "danger" : "ok"}>
          {model.blockingIssueCount
            ? `${model.blockingIssueCount} blocking issue(s)`
            : "Ready for review"}
        </Chip>
      }
    >
      <div
        className="confirmed-need-summary"
        aria-label="Ingredients and suppliers administration summary"
      >
        <article>
          <span>Active ingredients</span>
          <strong>{model.activeIngredientCount}</strong>
        </article>
        <article>
          <span>Inactive ingredients</span>
          <strong>{model.inactiveIngredientCount}</strong>
        </article>
        <article>
          <span>Active suppliers</span>
          <strong>{model.activeSupplierCount}</strong>
        </article>
        <article>
          <span>Inactive suppliers</span>
          <strong>{model.inactiveSupplierCount}</strong>
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
      <div className="workbench-actions confirmed-need-actions">
        <button onClick={recordEligibility}>
          Set ingredient-supplier eligibility
        </button>
        <button onClick={recordPreference}>
          Set preferred supplier reference
        </button>
        <button
          className="primary"
          onClick={() => setDetailsOpen((open) => !open)}
          aria-expanded={detailsOpen}
        >
          {detailsOpen
            ? "Hide master-data details"
            : "Review master-data details"}
        </button>
      </div>
      {notice && <p className="prototype-notice">{notice}</p>}
      <p className="supporting-copy">{model.boundaryNote}</p>
      {detailsOpen && (
        <div className="weekly-menu-details">
          <h3>Ingredient readiness</h3>
          <CompactTable
            headers={[
              "Ingredient",
              "Status",
              "Purchase / planning / inventory",
              "Eligible suppliers",
              "Default / preferred",
              "Issues",
            ]}
          >
            {model.ingredients.map((ingredient) => (
              <tr key={ingredient.ingredientId}>
                <td>
                  {ingredient.ingredientName}
                  <small>{ingredient.ingredientGroup}</small>
                </td>
                <td>
                  <Chip
                    tone={ingredient.status === "ACTIVE" ? "ok" : "warning"}
                  >
                    {ingredient.status}
                  </Chip>
                </td>
                <td>
                  {ingredient.unitProfile.purchaseUnit || "Missing"} /{" "}
                  {ingredient.unitProfile.planningUnit} /{" "}
                  {ingredient.unitProfile.inventoryUnit}
                  <small>
                    Usable: {ingredient.unitProfile.usableUnit ?? "Not set"}
                  </small>
                </td>
                <td>
                  {ingredient.eligibleSuppliers.length
                    ? ingredient.eligibleSuppliers
                        .map((supplier) => supplier.supplierName)
                        .join(", ")
                    : "None"}
                </td>
                <td>
                  {ingredient.defaultSupplier
                    ? `${ingredient.preference}: ${ingredient.defaultSupplier.supplierName}`
                    : "Not set"}
                </td>
                <td>
                  {ingredient.issues.length
                    ? ingredient.issues.map((issue) => (
                        <small key={issue.issueCode}>{issue.message}</small>
                      ))
                    : "None"}
                </td>
              </tr>
            ))}
          </CompactTable>
          <h3>Supplier eligibility</h3>
          <CompactTable
            headers={[
              "Supplier",
              "Status",
              "Contact reference",
              "Eligible ingredients",
              "Issues",
            ]}
          >
            {model.suppliers.map((supplier) => (
              <tr key={supplier.supplierId}>
                <td>{supplier.supplierName}</td>
                <td>
                  <Chip tone={supplier.status === "ACTIVE" ? "ok" : "warning"}>
                    {supplier.status}
                  </Chip>
                </td>
                <td>{supplier.contactReference ?? "Not set"}</td>
                <td>
                  {supplier.eligibleIngredients.length
                    ? supplier.eligibleIngredients
                        .map((ingredient) => ingredient.ingredientName)
                        .join(", ")
                    : "None"}
                </td>
                <td>
                  {supplier.issues.length
                    ? supplier.issues.map((issue) => (
                        <small key={issue.issueCode}>{issue.message}</small>
                      ))
                    : "None"}
                </td>
              </tr>
            ))}
          </CompactTable>
          <p className="weekly-menu-audit">
            Change history:{" "}
            {model.changeHistory.map((change) => change.changeType).join(" · ")}
          </p>
        </div>
      )}
    </Panel>
  );
}
