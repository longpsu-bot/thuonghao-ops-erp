# PD-01.1 — Weekly Menu Foundation implementation note

**Status:** In-memory MVP foundation
**Contract:** `planning-domain-weekly-menu-contract.md`

This implementation adds an isolated Planning-domain TypeScript model and an Atlas fixture workbench. It does not introduce a database migration, RPC, Supabase client, or authoritative frontend calculation.

The domain module exposes contract-aligned commands for import, validate, edit, approve, reopen, and request need generation. It also shapes the four contract read models. Tests cover import, validation blocks, lifecycle protection, reopen traceability, and need-generation eligibility.

The UI is explicitly prototype-only: it uses a local fixture, defaults to a compact decision view, and keeps line/audit detail collapsed. Replacing the in-memory command boundary with backend commands is deferred to a separate backend-integrated task.
