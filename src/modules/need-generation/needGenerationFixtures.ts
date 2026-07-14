import type {
  NeedGenerationCalculationFixtures,
  ReadyPlanningInputSetFixture,
} from "./needGenerationDomain";

export const readyPlanningInputFixture: ReadyPlanningInputSetFixture = {
  id: "planning-input-2026-29",
  periodStart: "2026-07-13",
  periodEnd: "2026-07-19",
  status: "READY",
  version: 1,
  readinessSnapshotId: "readiness-2026-29-v1",
  weeklyMenu: {
    id: "weekly-menu-2026-29",
    version: 1,
    lines: [
      {
        id: "menu-line-1",
        serviceDate: "2026-07-14",
        schoolId: "school-nguyen-du",
        dishId: "dish-pumpkin-soup",
      },
    ],
  },
  attendance: {
    id: "attendance-2026-29",
    version: 1,
    lines: [
      {
        id: "attendance-line-1",
        serviceDate: "2026-07-14",
        schoolId: "school-nguyen-du",
        portions: 320,
      },
    ],
  },
};

export const prototypeCalculationFixtures: NeedGenerationCalculationFixtures = {
  calculationRuleVersion: "prototype-exact-portion-v1",
  recipes: [
    {
      id: "recipe-pumpkin-soup",
      version: 3,
      dishId: "dish-pumpkin-soup",
      active: true,
      bomLines: [
        {
          id: "bom-pumpkin",
          ingredientId: "ingredient-pumpkin",
          quantityPerPortion: 0.225,
          unit: "kg",
          ingredientActive: true,
        },
        {
          id: "bom-stock",
          ingredientId: "ingredient-stock",
          quantityPerPortion: 0.01,
          unit: "kg",
          ingredientActive: true,
        },
      ],
    },
  ],
};
