/**
 * OPS v1 — School master -> Google Sheet "Lists" validation list.
 *
 * Receives:
 * {
 *   event: "schools_changed",
 *   schools: [
 *     { id, name, display_order }
 *   ]
 * }
 *
 * Writes:
 * Lists!A2:A
 *
 * Column A is the existing school validation source.
 */

function maybeHandleSchoolSync_(e) {
  let body = {};

  try {
    body = JSON.parse(
      e && e.postData && e.postData.contents
        ? e.postData.contents
        : "{}"
    );
  } catch (err) {
    return ContentService
      .createTextOutput("ERROR_PARSE: " + err.message)
      .setMimeType(ContentService.MimeType.TEXT);
  }

  // Not a school event -> let existing dish handler continue.
  if (body.event !== "schools_changed") {
    return null;
  }

  try {
    const result = syncSchoolsToLists_(
      Array.isArray(body.schools) ? body.schools : []
    );

    return ContentService
      .createTextOutput(
        JSON.stringify({
          ok: true,
          event: "schools_changed",
          ...result,
        })
      )
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService
      .createTextOutput("ERROR_SCHOOL_SYNC: " + err.message)
      .setMimeType(ContentService.MimeType.TEXT);
  }
}
