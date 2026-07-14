import type { SchoolAdminState } from "./schoolAdminDomain";

export const schoolAdminFixture: SchoolAdminState = {
  schoolGroups: [
    {
      schoolGroupId: "group-thuong-hao",
      schoolGroupName: "Thượng Hảo Catering",
    },
  ],
  schoolTypes: [
    {
      schoolTypeId: "primary",
      schoolTypeName: "Tiểu học",
      requiresPlanningType: true,
    },
    {
      schoolTypeId: "kindergarten",
      schoolTypeName: "Mầm non",
      requiresPlanningType: true,
    },
  ],
  serviceCalendars: [
    {
      serviceCalendarId: "weekday-morning",
      calendarName: "Thứ hai – Thứ sáu",
      rules: ["MON", "TUE", "WED", "THU", "FRI"].map((weekday) => ({
        serviceDayRuleId: `weekday-${weekday}`,
        weekday: weekday as "MON",
        isServiceDay: true,
        serviceWindow: "06:30–10:30",
      })),
    },
  ],
  deliveryLocations: [
    {
      deliveryLocationId: "nd-central-kitchen",
      locationName: "Bếp Trường Nguyễn Du",
      address: "Quận 1, TP.HCM",
      deliveryNotes: "Giao cổng phía bắc",
    },
  ],
  schools: [
    {
      schoolId: "school-nguyen-du",
      schoolName: "Trường Nguyễn Du",
      schoolGroupId: "group-thuong-hao",
      status: "ACTIVE",
      displayOrder: 10,
      operationalProfile: {
        schoolTypeId: "primary",
        serviceCalendarId: "weekday-morning",
        defaultDeliveryLocationId: "nd-central-kitchen",
        operationalNotes: "Bếp trung tâm · tuyến Bắc",
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
      schoolName: "Trường Minh An",
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
