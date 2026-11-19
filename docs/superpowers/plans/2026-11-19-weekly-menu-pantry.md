# Weekly menu pantry implementation plan

**Goal:** Keep weekly automatic pantry, manual special orders and recipe demand individually traceable for the same School, Ingredient and delivery date.

1. Add effective-dated rule revisions under Planning using the existing actor, command receipt, capability and RLS conventions. Verify create, change, disable, out-of-order edits, retry and authorization.
2. Derive one system-owned Pantry contribution from distinct dates in the current School menu snapshot. Include the first menu day in correction impact when another day changes. Verify repeated saves, manual rows at the same grain, empty weeks and frozen releases.
3. Connect the rule editor to the Hàng đặt riêng workbench. Verify keyboard operation, narrow layout, error and stale states.
4. Expose the automatic quantity separately in grouped and atomic Need evidence. Preserve established source fields for older reads. Verify exact totals and both Need views, run focused database suites in an isolated local instance, then publish the branch for CI.
