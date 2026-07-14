import {
  GenerateTheoreticalNeedsFromInputs,
  ReleaseGeneratedNeedsForConfirmation,
  ValidateGeneratedNeeds,
} from "../need-generation/needGenerationDomain";
import {
  prototypeCalculationFixtures,
  readyPlanningInputFixture,
} from "../need-generation/needGenerationFixtures";
import { CreateConfirmedNeedsFromGeneration } from "./confirmedNeedDomain";

const generated = GenerateTheoreticalNeedsFromInputs({
  needGenerationRunId: "need-run-2026-29-v1",
  inputSet: readyPlanningInputFixture,
  fixtures: prototypeCalculationFixtures,
  actorId: "planner-lan",
  at: "2026-07-14T01:00:00.000Z",
}).run!;
const validated = ValidateGeneratedNeeds(
  generated,
  "planner-lan",
  "2026-07-14T01:05:00.000Z",
).run!;

export const releasedNeedGenerationFixture =
  ReleaseGeneratedNeedsForConfirmation(
    validated,
    "manager-minh",
    "2026-07-14T01:10:00.000Z",
  ).run!;

export const draftConfirmedNeedFixture = CreateConfirmedNeedsFromGeneration({
  confirmedNeedBatchId: "confirmed-need-2026-29-v1",
  generationRun: releasedNeedGenerationFixture,
  actorId: "planner-lan",
  at: "2026-07-14T01:15:00.000Z",
}).batch!;
