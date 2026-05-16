# Roadmap

Current state and what comes next. Ordered by implementation priority — quick wins first, infrastructure second, pipelines third.

---

## Now (stable)

Cicero CLI on minerva (Mac). Local-only. Passive.

- OpenClaw 2026.5.12, `deepseek-r1:14b` via Ollama on Apple Silicon.
- Workspace versioned in git, symlinked into `~/.openclaw/workspace`.
- Personality and behavioral rules in `workspace/SOUL.md`.
- `cicero-health` and `cicero-memory` skills registered as stubs.
- launchd agent (`ai.openclaw.gateway`), idempotent `deploy/mac/setup.sh`.
- `cicero chat` and `cicero ask` CLI wrappers.

---

## 1. Quick Wins — Skills and Plugins (no code required)

Install order matters: `openclawbrain` first (memory foundation), then `self-improving` on top of it.

### `gog` — Google Workspace CLI
```bash
openclaw skills install gog
```
Unlocks Gmail search, attachment download, and send — the delivery mechanism for all reports. Also Google Sheets if structured data needs a spreadsheet surface. OAuth setup required after install. No security concerns; review source before authenticating.

### `humanizer` — AI Writing Polish
```bash
openclaw skills install humanizer
```
Post-processes written output to reduce AI-isms. Apply to all report narratives. Instruction-only, no credentials, low risk.

### `openclawbrain` — Long-Term Memory Graph
```bash
openclaw plugins install clawhub:openclawbrain@0.2.20
openclaw plugins enable openclawbrain
openclaw gateway restart
```
Local SQLite + FTS5 graph with Ollama-backed embeddings. Bounded context injection per turn — does not bloat the prompt with full history. This is the cold memory layer. Requires OpenClaw ≥ 2026.5.2 (we are on 2026.5.12).

Legacy ZIP format (pre-ClawPack); static analysis is benign, but verify the bundle before enabling: `openclaw plugins install --dry-run clawhub:openclawbrain@0.2.20`.

### `self-improving` — Short-Term Memory + Self-Reflection
```bash
openclaw skills install self-improving
```
Hot memory layer: maintains a `memory.md` ≤ 100 lines that is always loaded. Logs corrections, preferences, and repeated patterns. Integrates with the heartbeat cycle.

**Caution:** High-agency skill. Can permanently modify agent behavior by writing to its own memory file. Steps after install:
1. Review `security/boundaries.md` (skill-provided).
2. Audit `corrections.md` monthly to catch drift.
3. Install only after `openclawbrain` is running — the two layers are designed to work together.

### Memory architecture with both installed

| Layer | Tool | Storage | Loaded |
|---|---|---|---|
| Hot (short-term) | `self-improving` | `memory.md` ≤ 100 lines | Always, every turn |
| Cold (long-term) | `openclawbrain` | SQLite/FTS5 graph | Bounded injection per turn |
| Semantic (future) | `cicero-memory` (Chroma) | Vector store | On explicit search query |

Chroma remains on the roadmap as a semantic search layer over structured data (health records, garden notes, decisions). `openclawbrain` handles conversational memory and preferences. They are complementary, not redundant.

---

## 2. Big Brain / Galaxy Brain Routing

Cicero runs `deepseek-r1:14b` locally by default — free, private, sufficient for daily use. Complex analytical tasks (reports, financial narratives, multi-step synthesis) benefit from a more capable model. Big Brain / Galaxy Brain mode adds optional Anthropic API escalation.

| Mode | Model | Use case |
|---|---|---|
| Default | `deepseek-r1:14b` (local, Ollama) | Routing, triage, simple lookups, daily use |
| Big Brain | `claude-sonnet-4-6` (Anthropic API) | Monthly reports, bill analysis, investment summaries |
| Galaxy Brain | `claude-opus-4-7` (Anthropic API) | Annual financial review, deep synthesis, complex multi-step tasks |

**Implementation:** Add `claude-sonnet-4-6` and `claude-opus-4-7` as named providers in `openclaw.json`. Expose a `--mode` flag on relevant skills and cron jobs. Default to local; escalate explicitly. Requires an Anthropic API key in the credential store (`openclaw credentials set anthropic`).

This is foundational for all report-generating workstreams below — wire it before building the pipelines.

---

## 3. Health Data Ingestion

The `cicero-health` skill returns a placeholder. Real implementation:

1. **Ingestion.** Apple Health XML export + Heavy app CSV → ETL → Postgres on Saturn. Schema: `workouts`, `sleep_sessions`, `body_metrics`. One-shot historical import, then incremental.
2. **Query interface.** Thin wrapper (SQL or HTTP) the skill calls with a natural-language parameter.
3. **Replace the stub.** Update `workspace/skills/cicero-health/SKILL.md` with real dispatch.

See `workspace/skills/cicero-health/README.md` for the full TODO list.

---

## 4. APS Utility Bill Automation

**Goal:** Pull hourly energy consumption from the APS portal, calculate estimated vs. actual bill, trend analysis, deliver report before bill due date, log everything to Postgres.

**Stack:** Playwright (scraping) · Python (parsing, rate plan logic) · Postgres · Dagster (scheduling) · `gog` (Gmail delivery)

**Pipeline:**
1. Playwright logs into APS portal, downloads hourly consumption CSV.
2. Parse and validate; write hourly rows to Postgres (`aps_hourly_usage`).
3. Apply APS TOU rate plan logic to compute estimated bill.
4. Compare estimated vs. actual; compute delta.
5. SQL window functions for MoM and YoY trends.
6. Cicero generates report narrative (Big Brain mode).
7. `humanizer` post-processes the narrative.
8. `gog gmail send` delivers the report N days before bill due date.
9. Dagster cron triggers on monthly schedule.

**Key risk:** APS portal layout changes break the Playwright scraper. Build with scrape-failure alerting so Cicero notifies rather than silently failing.

**Note:** Do not use the `peytoncasper/browser-automation` ClawHub skill for this — flagged as suspicious. Build the scraper directly in Playwright/Python.

---

## 5. Fidelity Investment Statements → Report

**Goal:** Ingest Fidelity statements, log holdings and performance data to Postgres, produce a written investment and retirement savings narrative.

**Stack:** `gog gmail` or Playwright (ingestion) · pdfplumber (PDF parsing if needed) · Postgres · Cicero (narrative, Big Brain / Galaxy Brain)

**Pipeline:**
1. **Ingestion — two paths:**
   - *Email path:* `gog gmail search` for Fidelity statement emails → download CSV/PDF attachments.
   - *Portal path:* Playwright logs into Fidelity, downloads statements.
2. Parse holdings, cost basis, realized/unrealized gain/loss, allocation by account type (brokerage, IRA, 401k).
3. Write to Postgres (`fidelity_holdings`, `fidelity_performance`).
4. Cicero generates narrative: performance vs. benchmark, allocation drift, retirement savings trajectory.
5. Deliver via Gmail (Big Brain for monthly; Galaxy Brain for annual review).

**Key risk:** Fidelity detects automation and MFA may interrupt the portal path. Design a semi-automated fallback: Cicero handles analysis, manual download is triggered if scraping breaks.

**MLflow artifact option:** Log the HTML report with interactive charts (Plotly standalone) as an MLflow artifact run. Viewable in MLflow UI on Saturn.

---

## 6. MLflow Integrations

Saturn hosts MLflow. Two patterns.

### Report Artifacts

Any report generated above (APS, Fidelity) can additionally be logged as an MLflow artifact — HTML with Plotly charts. Provides a versioned, browsable archive of all historical reports in the MLflow UI.

### Automated Model Promotion

For models trained via Dagster pipelines and logged to MLflow:

1. `cicero-dagster` skill triggers the training pipeline via Dagster's API.
2. Dagster runs hyperparameter search internally; all trials log to MLflow.
3. `cicero-mlflow` skill reads completed runs and ranks using a **weighted Euclidean norm**:

   ```yaml
   # model_selection_config.yaml — defined per experiment
   metrics:
     f1:        { target: 1.0, weight: 1.5 }
     precision: { target: 1.0, weight: 1.0 }
     recall:    { target: 1.0, weight: 1.0 }
     loss:      { target: 0.0, weight: 0.8 }
   ```

   Score = `sqrt(sum(w_i * (metric_i - target_i)^2))`. Lowest wins. Reproducible and auditable.

4. Cicero applies a judgment layer: flags low sample counts, data freshness gaps, asymmetric metric importance for the specific model's use case.
5. `cicero-github` skill opens a PR bumping the model version in a config file. PR description contains the metric table and Cicero's qualitative notes.
6. Carlos reviews and merges. Promotion is gated on human approval.

---

## 7. Proactive Agents

`workspace/cron/` is reserved. When proactive behavior is ready:

1. Wire cron jobs for report delivery schedules (APS monthly, Fidelity monthly/annual).
2. Wire heartbeat checks: calendar, email triage, model promotion cycle.
3. Notification channel required — iMessage on Mac (see Mac migration) or workspace memory note until then.
4. Start with low-stakes, read-only checks before enabling anything that sends messages or modifies state.

---

## 8. iMessage Channel

Cicero is now running on minerva (Mac). The Mac migration is complete. iMessage is the next channel unlock.

1. Enable iMessage via BlueBubbles or the native macOS bridge.
2. Wire the channel in OpenClaw (`openclaw channels add imessage`).
3. This unblocks proactive notifications — required for cron-driven heartbeats and report delivery.
4. Start with read-only (receive only) before enabling send, per `docs/security.md`.

Keep Saturn running as the data server (Postgres, MLflow, Dagster) until those workloads migrate or are confirmed unnecessary.

---

## 9. `stock-analysis` Skill

```bash
openclaw skills install stock-analysis
```

Market data via Yahoo Finance. Portfolio benchmarking, dividend analysis, performance context for Fidelity reports.

**Flagged:** The rumor scanner and Twitter/X integration components have not been reviewed. Install only after disabling those features individually. Do not enable until the Fidelity pipeline is running and there is a clear use for the data.

---

## Future Skills

Not started. No dependencies on the above workstreams unless noted.

- **Garden.** Track plantings, harvests, notes. Flat-file or SQLite backend.
- **Home automation.** Read/control devices. Depends on home infra at migration time.
- **Apple Reminders.** Mac-only via `remindctl`. Actuates — security review required before enabling.
- **Web search.** Brave API key. Low priority while CLI-only.

---

## Appendix: Postgres Schema (Proposed)

```sql
-- Utility
CREATE TABLE aps_hourly_usage (
  id            SERIAL PRIMARY KEY,
  ts            TIMESTAMPTZ NOT NULL,
  kwh           NUMERIC(8,4) NOT NULL,
  ingested_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE aps_bills (
  id                   SERIAL PRIMARY KEY,
  billing_period_start DATE,
  billing_period_end   DATE,
  actual_amount        NUMERIC(10,2),
  estimated_amount     NUMERIC(10,2),
  delta                NUMERIC(10,2),
  rate_plan            TEXT,
  ingested_at          TIMESTAMPTZ DEFAULT now()
);

-- Investments
CREATE TABLE fidelity_holdings (
  id                  SERIAL PRIMARY KEY,
  snapshot_date       DATE NOT NULL,
  account_type        TEXT,           -- brokerage, ira, 401k
  symbol              TEXT,
  description         TEXT,
  quantity            NUMERIC(14,4),
  cost_basis          NUMERIC(14,2),
  market_value        NUMERIC(14,2),
  unrealized_gain_loss NUMERIC(14,2),
  ingested_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE fidelity_performance (
  id              SERIAL PRIMARY KEY,
  snapshot_date   DATE NOT NULL,
  account_type    TEXT,
  total_value     NUMERIC(14,2),
  total_cost_basis NUMERIC(14,2),
  total_gain_loss  NUMERIC(14,2),
  ingested_at     TIMESTAMPTZ DEFAULT now()
);
```
