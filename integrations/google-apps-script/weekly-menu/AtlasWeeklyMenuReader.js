/**
 * Read-only Atlas addition to the existing bound Apps Script project.
 * Insert the documented early route in the existing doPost; do not replace v1 handlers.
 * Script Properties: ATLAS_WEEKLY_MENU_SPREADSHEET_ID and either
 * ATLAS_WEEKLY_MENU_SECRET (preferred) or the existing SYNC_SECRET.
 */
function maybeHandleAtlasWeeklyMenuRead_(e) {
  var raw = e && e.postData && e.postData.contents;
  var body;
  try {
    body = JSON.parse(raw || "{}");
  } catch (_) {
    return null;
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  if (typeof body.event !== "string" || body.event.indexOf("atlas_") !== 0)
    return null;
  function result(value) {
    return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(
      ContentService.MimeType.JSON,
    );
  }
  function fail(code) {
    return result({ success: false, error_code: code });
  }
  try {
    if (
      body.event !== "atlas_weekly_menu_read" ||
      typeof raw !== "string" ||
      raw.length > 4096
    )
      return fail("INVALID_REQUEST");
    var allowed = [
      "event",
      "contract_version",
      "week_start",
      "request_id",
      "secret",
    ];
    if (
      Object.keys(body).some(function (key) {
        return allowed.indexOf(key) < 0;
      })
    )
      return fail("INVALID_REQUEST");
    var props = PropertiesService.getScriptProperties();
    var deployment =
      typeof atlasWeeklyMenuDeploymentConfig_ === "function"
        ? atlasWeeklyMenuDeploymentConfig_()
        : null;
    var expected = deployment
      ? deployment.secretSha256
      : props.getProperty("ATLAS_WEEKLY_MENU_SECRET") ||
        props.getProperty("SYNC_SECRET") ||
        "";
    var received = typeof body.secret === "string" ? body.secret : "";
    if (
      !expected ||
      !received ||
      expected.length > 1024 ||
      received.length > 1024
    )
      return fail("UNAUTHORIZED");
    if (deployment) {
      if (typeof expected !== "string" || !/^[0-9a-f]{64}$/.test(expected))
        return fail("UNAUTHORIZED");
      received = Utilities.computeDigest(
        Utilities.DigestAlgorithm.SHA_256,
        received,
        Utilities.Charset.UTF_8,
      )
        .map(function (byte) {
          return ("0" + ((byte + 256) % 256).toString(16)).slice(-2);
        })
        .join("");
    }
    var difference = expected.length ^ received.length;
    for (var i = 0; i < expected.length; i += 1)
      difference |= expected.charCodeAt(i) ^ (received.charCodeAt(i) || 0);
    if (difference !== 0) return fail("UNAUTHORIZED");
    if (
      body.contract_version !== "ATLAS-WEEKLY-MENU-READ.v1" ||
      typeof body.request_id !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        body.request_id,
      )
    )
      return fail("INVALID_REQUEST");
    if (
      typeof body.week_start !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(body.week_start)
    )
      return fail("INVALID_WEEK");
    var monday = new Date(body.week_start + "T00:00:00.000Z");
    if (
      isNaN(monday.valueOf()) ||
      monday.toISOString().slice(0, 10) !== body.week_start ||
      monday.getUTCDay() !== 1
    )
      return fail("INVALID_WEEK");
    var spreadsheetId = deployment
      ? deployment.spreadsheetId
      : props.getProperty("ATLAS_WEEKLY_MENU_SPREADSHEET_ID") || "";
    if (!/^[A-Za-z0-9_-]{10,200}$/.test(spreadsheetId))
      return fail("SOURCE_NOT_CONFIGURED");
    var book = SpreadsheetApp.openById(spreadsheetId);
    if (!book || book.getId() !== spreadsheetId)
      return fail("SOURCE_NOT_CONFIGURED");
    var parts = body.week_start.split("-");
    var sheetName = "Tuần " + parts[2] + "-" + parts[1] + "-" + parts[0];
    var sheet = book.getSheetByName(sheetName);
    if (!sheet) return fail("WEEKLY_SHEET_MISSING");
    var lastRow = sheet.getLastRow();
    if (lastRow < 3) return fail("EMPTY_SHEET");
    if (lastRow > 500) return fail("RESPONSE_SIZE_LIMIT");
    var timezone = book.getSpreadsheetTimeZone();
    var values = sheet
      .getRange(3, 1, lastRow - 2, 9)
      .getValues()
      .map(function (row) {
        return row.map(function (cell) {
          if (cell instanceof Date) {
            if (isNaN(cell.valueOf())) throw new Error("INVALID_CELL");
            return Utilities.formatDate(cell, timezone, "yyyy-MM-dd");
          }
          if (
            cell === null ||
            typeof cell === "string" ||
            typeof cell === "boolean"
          )
            return cell;
          if (typeof cell === "number" && isFinite(cell)) return cell;
          throw new Error("INVALID_CELL");
        });
      });
    var output = {
      success: true,
      contract_version: "ATLAS-WEEKLY-MENU-READ.v1",
      request_id: body.request_id,
      week_start: body.week_start,
      spreadsheet_id: spreadsheetId,
      sheet_name: sheetName,
      range: "'" + sheetName + "'!A3:I500",
      rows: values,
    };
    // Six UTF-8 bytes/UTF-16 pair is an intentionally conservative local guard;
    // Edge also counts actual streamed UTF-8 bytes before decoding/returning anything.
    if (JSON.stringify(output).length > 500000)
      return fail("RESPONSE_SIZE_LIMIT");
    return result(output);
  } catch (_) {
    // No raw Google error, sheet values, token, or stack trace is returned or logged.
    return fail("SHEET_READ_FAILED");
  }
}

/** Run once from the bound Sheet's Apps Script editor, not from a Web App. */
function initializeAtlasWeeklyMenuReader() {
  var book = SpreadsheetApp.getActiveSpreadsheet();
  if (!book)
    throw new Error("Run this setup from the bound spreadsheet editor.");
  var props = PropertiesService.getScriptProperties();
  if (!(
    props.getProperty("ATLAS_WEEKLY_MENU_SECRET") ||
    props.getProperty("SYNC_SECRET")
  ))
    throw new Error("Configure a nonempty reader secret before setup.");
  var existing = props.getProperty("ATLAS_WEEKLY_MENU_SPREADSHEET_ID");
  if (existing && existing !== book.getId())
    throw new Error(
      "Existing reader source differs; explicit configuration review required.",
    );
  props.setProperty("ATLAS_WEEKLY_MENU_SPREADSHEET_ID", book.getId());
  return { configured: true };
}
