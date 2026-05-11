# cicero-health

Stub skill. Currently returns a hardcoded placeholder for any training/health question.

## What this will become

A real skill that queries Carlos's personal health datastore:

- **Ingestion:** Apple Health export (sleep, activity rings, heart rate) + Heavy app (strength training sessions) → ETL → Postgres on Saturn.
- **Interface:** This skill will execute SQL (or a semantic-search wrapper) against that Postgres instance and return structured summaries.
- **Privacy:** Data stays on Saturn. Never leaves the box without explicit instruction.

## TODO (real implementation)

- [ ] Stand up Postgres on Saturn with a `health` schema (`workouts`, `sleep_sessions`, `body_metrics`, source-of-record tables).
- [ ] Write the Apple Health export ingester (XML → Postgres). One-shot import, then incremental.
- [ ] Write the Heavy ingester (CSV or API → Postgres). Decide whether to scrape the Heavy app DB on the phone or use their export.
- [ ] Decide query interface: direct SQL via a tool, or wrap in semantic search via the `cicero-memory` (Chroma) skill.
- [ ] Replace the placeholder behavior in `SKILL.md` with the real query path.
- [ ] Add tests against a seeded fixture DB.

See `docs/roadmap.md` for the broader plan.
