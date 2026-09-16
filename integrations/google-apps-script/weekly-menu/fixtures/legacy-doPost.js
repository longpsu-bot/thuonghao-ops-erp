function doPost(e) {
  try {
    const props = PropertiesService.getScriptProperties();
    const SYNC_SECRET = props.getProperty("SYNC_SECRET") || "";
    const got = (e && e.parameter && e.parameter.secret) ? String(e.parameter.secret) : "";

    if (SYNC_SECRET && got !== SYNC_SECRET) {
      return ContentService
        .createTextOutput("FORBIDDEN")
        .setMimeType(ContentService.MimeType.TEXT);
    }

 // =====================================================
    // NEW: handle school sync
    // =====================================================
    const schoolResponse = maybeHandleSchoolSync_(e);
    if (schoolResponse) return schoolResponse;

    syncListsValidationFromSupabase();

    return ContentService
      .createTextOutput("OK_SYNCED")
      .setMimeType(ContentService.MimeType.TEXT);

  } catch (err) {
    return ContentService
      .createTextOutput("ERROR: " + err.message)
      .setMimeType(ContentService.MimeType.TEXT);
  }
}
