export type SchoolStatus = "ACTIVE" | "INACTIVE";
export type SchoolAdminIssueSeverity = "BLOCKING" | "WARNING";

export type SchoolGroup = {
  schoolGroupId: string;
  schoolGroupName: string;
};

export type SchoolType = {
  schoolTypeId: string;
  schoolTypeName: string;
  requiresPlanningType: boolean;
};

export type ServiceDayRule = {
  serviceDayRuleId: string;
  weekday: "MON" | "TUE" | "WED" | "THU" | "FRI" | "SAT" | "SUN";
  isServiceDay: boolean;
  serviceWindow?: string;
};

export type ServiceCalendar = {
  serviceCalendarId: string;
  calendarName: string;
  rules: readonly ServiceDayRule[];
};

export type DeliveryLocation = {
  deliveryLocationId: string;
  locationName: string;
  address: string;
  deliveryNotes?: string;
};

export type SchoolOperationalProfile = {
  schoolTypeId?: string;
  serviceCalendarId?: string;
  defaultDeliveryLocationId?: string;
  operationalNotes?: string;
  requiresSchoolTypeForPlanning: boolean;
  requiresDeliveryLocationForFulfilment: boolean;
};

export type SchoolStatusChange = {
  schoolStatusChangeId: string;
  schoolId: string;
  beforeStatus: SchoolStatus;
  afterStatus: SchoolStatus;
  actorId: string;
  at: string;
  reason: string;
};

export type SchoolMasterDataChange = {
  schoolMasterDataChangeId: string;
  schoolId: string;
  changeType:
    | "SchoolCreated"
    | "SchoolProfileUpdated"
    | "SchoolDisplayOrderChanged"
    | "SchoolTypeAssigned"
    | "SchoolServiceRuleChanged"
    | "SchoolDeliveryLocationChanged"
    | "SchoolActivated"
    | "SchoolDeactivated"
    | "SchoolMasterDataChangeRecorded";
  actorId: string;
  at: string;
  reason: string;
  before?: string;
  after?: string;
};

export type School = {
  schoolId: string;
  schoolName: string;
  schoolGroupId?: string;
  status: SchoolStatus;
  displayOrder: number;
  operationalProfile: SchoolOperationalProfile;
  effectiveFrom?: string;
  effectiveTo?: string;
  statusChanges: readonly SchoolStatusChange[];
  masterDataChanges: readonly SchoolMasterDataChange[];
};

export type SchoolAdminState = {
  schools: readonly School[];
  schoolGroups: readonly SchoolGroup[];
  schoolTypes: readonly SchoolType[];
  serviceCalendars: readonly ServiceCalendar[];
  deliveryLocations: readonly DeliveryLocation[];
};

export type SchoolAdminIssue = {
  schoolId: string;
  severity: SchoolAdminIssueSeverity;
  issueCode:
    | "SCHOOL_NAME_MISSING"
    | "DUPLICATE_ACTIVE_SCHOOL"
    | "SCHOOL_TYPE_MISSING"
    | "SERVICE_RULE_MISSING"
    | "DELIVERY_LOCATION_MISSING";
  message: string;
  isBlocking: boolean;
};

export type SchoolAdminCommandResult = {
  state: SchoolAdminState;
  accepted: boolean;
  message?: string;
  blockers: SchoolAdminIssue[];
};

export type SchoolPlanningReferenceResult = {
  accepted: boolean;
  message?: string;
};

const emptyResult = (
  state: SchoolAdminState,
  message?: string,
): SchoolAdminCommandResult => ({
  state,
  accepted: false,
  message,
  blockers: [],
});

const normalized = (value: string) => value.trim().toLocaleLowerCase();

function change(
  school: School,
  type: SchoolMasterDataChange["changeType"],
  actorId: string,
  at: string,
  reason: string,
  before?: string,
  after?: string,
): SchoolMasterDataChange {
  return {
    schoolMasterDataChangeId: `${school.schoolId}-change-${school.masterDataChanges.length + 1}`,
    schoolId: school.schoolId,
    changeType: type,
    actorId,
    at,
    reason,
    before,
    after,
  };
}

function replaceSchool(
  state: SchoolAdminState,
  next: School,
): SchoolAdminState {
  return {
    ...state,
    schools: state.schools.map((school) =>
      school.schoolId === next.schoolId ? next : school,
    ),
  };
}

function school(state: SchoolAdminState, schoolId: string) {
  return state.schools.find((candidate) => candidate.schoolId === schoolId);
}

function profileIssue(schoolValue: School): SchoolAdminIssue[] {
  const profile = schoolValue.operationalProfile;
  const issues: SchoolAdminIssue[] = [];
  if (!schoolValue.schoolName.trim())
    issues.push({
      schoolId: schoolValue.schoolId,
      severity: "BLOCKING",
      issueCode: "SCHOOL_NAME_MISSING",
      message: "School name is required.",
      isBlocking: true,
    });
  if (profile.requiresSchoolTypeForPlanning && !profile.schoolTypeId)
    issues.push({
      schoolId: schoolValue.schoolId,
      severity: "BLOCKING",
      issueCode: "SCHOOL_TYPE_MISSING",
      message: "School type is required for Planning.",
      isBlocking: true,
    });
  if (!profile.serviceCalendarId)
    issues.push({
      schoolId: schoolValue.schoolId,
      severity: "WARNING",
      issueCode: "SERVICE_RULE_MISSING",
      message: "No default service calendar is assigned.",
      isBlocking: false,
    });
  if (
    profile.requiresDeliveryLocationForFulfilment &&
    !profile.defaultDeliveryLocationId
  )
    issues.push({
      schoolId: schoolValue.schoolId,
      severity: "BLOCKING",
      issueCode: "DELIVERY_LOCATION_MISSING",
      message: "Delivery location is required for fulfilment reference.",
      isBlocking: true,
    });
  return issues;
}

function accepted(state: SchoolAdminState): SchoolAdminCommandResult {
  return { state, accepted: true, blockers: [] };
}

export function CreateSchool(
  state: SchoolAdminState,
  input: Omit<School, "statusChanges" | "masterDataChanges"> & {
    actorId: string;
    at: string;
    reason: string;
  },
): SchoolAdminCommandResult {
  if (!input.schoolName.trim())
    return {
      ...emptyResult(state, "School name is required."),
      blockers: profileIssue({
        ...input,
        statusChanges: [],
        masterDataChanges: [],
      }),
    };
  if (
    state.schools.some(
      (candidate) =>
        candidate.status === "ACTIVE" &&
        input.status === "ACTIVE" &&
        normalized(candidate.schoolName) === normalized(input.schoolName),
    )
  )
    return {
      ...emptyResult(state, "Duplicate active school identity is not allowed."),
      blockers: [
        {
          schoolId: input.schoolId,
          severity: "BLOCKING",
          issueCode: "DUPLICATE_ACTIVE_SCHOOL",
          message: "An active school with this name already exists.",
          isBlocking: true,
        },
      ],
    };
  const created: School = {
    ...input,
    schoolName: input.schoolName.trim(),
    statusChanges: [],
    masterDataChanges: [],
  };
  const createdChange = change(
    created,
    "SchoolCreated",
    input.actorId,
    input.at,
    input.reason,
  );
  return accepted({
    ...state,
    schools: [
      ...state.schools,
      { ...created, masterDataChanges: [createdChange] },
    ],
  });
}

function update(
  state: SchoolAdminState,
  schoolId: string,
  actorId: string,
  at: string,
  reason: string,
  type: SchoolMasterDataChange["changeType"],
  apply: (current: School) => School,
): SchoolAdminCommandResult {
  const current = school(state, schoolId);
  if (!current) return emptyResult(state, "School was not found.");
  if (!reason.trim()) return emptyResult(state, "A change reason is required.");
  const updated = apply(current);
  const event = change(
    current,
    type,
    actorId,
    at,
    reason,
    JSON.stringify(current.operationalProfile),
    JSON.stringify(updated.operationalProfile),
  );
  return accepted(
    replaceSchool(state, {
      ...updated,
      masterDataChanges: [...current.masterDataChanges, event],
    }),
  );
}

export function UpdateSchoolProfile(
  state: SchoolAdminState,
  input: {
    schoolId: string;
    profile: SchoolOperationalProfile;
    actorId: string;
    at: string;
    reason: string;
  },
) {
  return update(
    state,
    input.schoolId,
    input.actorId,
    input.at,
    input.reason,
    "SchoolProfileUpdated",
    (current) => ({ ...current, operationalProfile: input.profile }),
  );
}

export function SetSchoolDisplayOrder(
  state: SchoolAdminState,
  input: {
    schoolId: string;
    displayOrder: number;
    actorId: string;
    at: string;
    reason: string;
  },
) {
  if (input.displayOrder < 0)
    return emptyResult(state, "Display order cannot be negative.");
  return update(
    state,
    input.schoolId,
    input.actorId,
    input.at,
    input.reason,
    "SchoolDisplayOrderChanged",
    (current) => ({ ...current, displayOrder: input.displayOrder }),
  );
}

export function AssignSchoolType(
  state: SchoolAdminState,
  input: {
    schoolId: string;
    schoolTypeId: string;
    actorId: string;
    at: string;
    reason: string;
  },
) {
  if (
    !state.schoolTypes.some((item) => item.schoolTypeId === input.schoolTypeId)
  )
    return emptyResult(state, "School type was not found.");
  return update(
    state,
    input.schoolId,
    input.actorId,
    input.at,
    input.reason,
    "SchoolTypeAssigned",
    (current) => ({
      ...current,
      operationalProfile: {
        ...current.operationalProfile,
        schoolTypeId: input.schoolTypeId,
      },
    }),
  );
}

export function SetSchoolServiceRule(
  state: SchoolAdminState,
  input: {
    schoolId: string;
    serviceCalendarId: string;
    actorId: string;
    at: string;
    reason: string;
  },
) {
  if (
    !state.serviceCalendars.some(
      (item) => item.serviceCalendarId === input.serviceCalendarId,
    )
  )
    return emptyResult(state, "Service calendar was not found.");
  return update(
    state,
    input.schoolId,
    input.actorId,
    input.at,
    input.reason,
    "SchoolServiceRuleChanged",
    (current) => ({
      ...current,
      operationalProfile: {
        ...current.operationalProfile,
        serviceCalendarId: input.serviceCalendarId,
      },
    }),
  );
}

export function SetSchoolDeliveryLocation(
  state: SchoolAdminState,
  input: {
    schoolId: string;
    deliveryLocationId: string;
    actorId: string;
    at: string;
    reason: string;
  },
) {
  if (
    !state.deliveryLocations.some(
      (item) => item.deliveryLocationId === input.deliveryLocationId,
    )
  )
    return emptyResult(state, "Delivery location was not found.");
  return update(
    state,
    input.schoolId,
    input.actorId,
    input.at,
    input.reason,
    "SchoolDeliveryLocationChanged",
    (current) => ({
      ...current,
      operationalProfile: {
        ...current.operationalProfile,
        defaultDeliveryLocationId: input.deliveryLocationId,
      },
    }),
  );
}

export function SetSchoolStatus(
  state: SchoolAdminState,
  input: {
    schoolId: string;
    status: SchoolStatus;
    actorId: string;
    at: string;
    reason: string;
  },
) {
  const current = school(state, input.schoolId);
  if (!current) return emptyResult(state, "School was not found.");
  if (current.status === input.status)
    return emptyResult(state, "School status is already set.");
  if (!input.reason.trim())
    return emptyResult(state, "A status-change reason is required.");
  const statusChange: SchoolStatusChange = {
    schoolStatusChangeId: `${current.schoolId}-status-${current.statusChanges.length + 1}`,
    schoolId: current.schoolId,
    beforeStatus: current.status,
    afterStatus: input.status,
    actorId: input.actorId,
    at: input.at,
    reason: input.reason,
  };
  const type =
    input.status === "ACTIVE" ? "SchoolActivated" : "SchoolDeactivated";
  const event = change(
    current,
    type,
    input.actorId,
    input.at,
    input.reason,
    current.status,
    input.status,
  );
  return accepted(
    replaceSchool(state, {
      ...current,
      status: input.status,
      statusChanges: [...current.statusChanges, statusChange],
      masterDataChanges: [...current.masterDataChanges, event],
    }),
  );
}

export function RecordSchoolMasterDataChange(
  state: SchoolAdminState,
  input: { schoolId: string; actorId: string; at: string; reason: string },
) {
  return update(
    state,
    input.schoolId,
    input.actorId,
    input.at,
    input.reason,
    "SchoolMasterDataChangeRecorded",
    (current) => current,
  );
}

export function SchoolPlanningReference(
  schoolValue: School | undefined,
  explicitInactiveOverrideEvidence?: string,
): SchoolPlanningReferenceResult {
  if (!schoolValue)
    return { accepted: false, message: "School reference is missing." };
  if (
    schoolValue.status === "INACTIVE" &&
    !explicitInactiveOverrideEvidence?.trim()
  )
    return {
      accepted: false,
      message:
        "Inactive school requires explicit override evidence for new Planning reference.",
    };
  return { accepted: true };
}

export type SchoolAdminWorkbench = {
  activeSchoolCount: number;
  inactiveSchoolCount: number;
  blockingIssueCount: number;
  warningCount: number;
  schools: readonly (School & { issues: readonly SchoolAdminIssue[] })[];
  boundaryNote: string;
};

export function SchoolAdminWorkbench(
  state: SchoolAdminState,
): SchoolAdminWorkbench {
  const schools = state.schools.map((item) => ({
    ...item,
    issues: profileIssue(item),
  }));
  const issues = schools.flatMap((item) => item.issues);
  return {
    activeSchoolCount: state.schools.filter((item) => item.status === "ACTIVE")
      .length,
    inactiveSchoolCount: state.schools.filter(
      (item) => item.status === "INACTIVE",
    ).length,
    blockingIssueCount: issues.filter((item) => item.isBlocking).length,
    warningCount: issues.filter((item) => !item.isBlocking).length,
    schools,
    boundaryNote:
      "Admin governs future school master-data references and does not rewrite Planning facts or released downstream operational records.",
  };
}
