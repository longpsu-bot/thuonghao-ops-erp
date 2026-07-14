import type { SchoolAdminState } from "./schoolAdminDomain";

export const schoolAdminFixture: SchoolAdminState = {
  schoolGroups: [
    {
      schoolGroupId: "group-thuong-hao",
      schoolGroupName: "ThÆ°á»£ng Háº£o Catering",
    },
  ],
  schoolTypes: [
    {
      schoolTypeId: "primary",
      schoolTypeName: "Tiá»ƒu há»c",
      requiresPlanningType: true,
    },
    {
      schoolTypeId: "kindergarten",
      schoolTypeName: "Máº§m non",
      requiresPlanningType: true,
    },
  ],
  serviceCalendars: [
    {
      serviceCalendarId: "weekday-morning",
      calendarName: "Thá»© hai â€“ Thá»© sáu",
      rules: ["MON", "TUE", "WED", "THU", "FRI"].map((weekday) => ({
        serviceDayRuleId: `weekday-${weekday}`,
        weekday: weekday as "MON",
        isServiceDay: true,
        serviceWindow: "06:30â€“10:30",
      })),
    },
  ],
  deliveryLocations: [
    {
      deliveryLocationId: "nd-central-kitchen",
      locationName: "Báº¿p TrÆ°á»ng Nguyá»…n Du",
      address: "Quáº­n 1, TP.HCM",
      deliveryNotes: "Giao cá»•ng phÃ­a báº¯c",
    },
  ],
  schools: [
    {
      schoolId: "school-nguyen-du",
      schoolName: "TrÆ°á»ng Nguyá»…n Du",
      schoolGroupId: "group-thuong-hao",
      status: "ACTIVE",
      displayOrder: 10,
      operationalProfile: {
        schoolTypeId: "primary",
        serviceCalendarId: "weekday-morning",
        defaultDeliveryLocationId: "nd-central-kitchen",
        operationalNotes: "Báº¿p trung tÃ¢m Â· tuyáº¿n Báº¯c",
        requiresSchoolTypeForPlanning: true,
        requiresDeliveryLocationForFulfilment: true,
      },
      statusChanges: [],
      masterDataChanges: [
        {
          schoolMasterDataChangeId: "school-nguyen-du-change-1",
          schoolId: "school-nguyen-du",
          changeType: "SchoolCreated",
          actorId: "admin-lan",
          at: "2026-07-14T00:00:00.000Z",
          reason: "Imported as prototype master data",
        },
      ],
    },
    {
      schoolId: "school-minh-an",
      schoolName: "TrÆ°á»ng Minh An",
      schoolGroupId: "group-thuong-hao",
      status: "INACTIVE",
      displayOrder: 20,
      operationalProfile: {
        serviceCalendarId: "weekday-morning",
        operationalNotes: "Paused service; retained for historical reference",
        requiresSchoolTypeForPlanning: true,
        requiresDeliveryLocationForFulfilment: true,
      },
      statusChanges: [
        {
          schoolStatusChangeId: "school-minh-an-status-1",
          schoolId: "school-minh-an",
          beforeStatus: "ACTIVE",
          afterStatus: "INACTIVE",
          actorId: "admin-lan",
          at: "2026-07-10T00:00:00.000Z",
          reason: "Service contract paused",
        },
      ],
      masterDataChanges: [
        {
          schoolMasterDataChangeId: "school-minh-an-change-1",
          schoolId: "school-minh-an",
          changeType: "SchoolDeactivated",
          actorId: "admin-lan",
          at: "2026-07-10T00:00:00.000Z",
          reason: "Service contract paused",
          before: "ACTIVE",
          after: "INACTIVE",
        },
      ],
    },
  ],
};
