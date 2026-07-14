import {
  ApproveConfirmedNeeds,
  ReleaseConfirmedNeedsForPurchaseHandoff,
  ValidateConfirmedNeeds,
} from "../confirmed-need/confirmedNeedDomain";
import { draftConfirmedNeedFixture } from "../confirmed-need/confirmedNeedFixtures";
import { CreatePurchaseHandoffFromConfirmedNeeds } from "./purchaseHandoffDomain";

const validated = ValidateConfirmedNeeds(
  draftConfirmedNeedFixture,
  "planner-lan",
  "2026-07-14T01:20:00.000Z",
).batch!;
const approved = ApproveConfirmedNeeds(
  validated,
  "manager-minh",
  "2026-07-14T01:25:00.000Z",
).batch!;

export const releasedConfirmedNeedFixture =
  ReleaseConfirmedNeedsForPurchaseHandoff(
    approved,
    "planner-lan",
    "2026-07-14T01:30:00.000Z",
  ).batch!;

export const preparedPurchaseHandoffFixture =
  CreatePurchaseHandoffFromConfirmedNeeds({
    purchaseHandoffBatchId: "purchase-handoff-2026-29-v1",
    confirmedNeedBatch: releasedConfirmedNeedFixture,
    actorId: "planner-lan",
    at: "2026-07-14T01:35:00.000Z",
  }).batch!;
