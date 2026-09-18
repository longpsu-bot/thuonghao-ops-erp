-- EXPLAIN on the real 17/09 Staging shape (304 atomic / 248 grouped)
-- showed each partition check filtering 303 irrelevant contribution members
-- per source line and rescanning current revisions by release alone.
-- Add exact non-unique lookup paths. All guard bodies, constraints and truth
-- conditions remain byte-for-byte unchanged; these indexes confer no authority.
create index confirmed_need_contributions_release_member_lookup
  on atlas_planning.confirmed_need_line_revision_contributions (
    need_generation_release_snapshot_line_id,
    confirmed_need_batch_id,
    confirmed_need_line_revision_id
  );
create index confirmed_need_revisions_current_member_lookup
  on atlas_planning.confirmed_need_line_revisions (
    need_generation_release_snapshot_id,
    confirmed_need_line_revision_id,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version
  ) where source_kind = 'NEED_GENERATION' and is_current;
