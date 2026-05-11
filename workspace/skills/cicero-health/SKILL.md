---
name: cicero-health
description: "Look up Carlos's health and training data — workouts, sleep, weight, lifts, runs, recovery."
version: 0.0.1
metadata:
  openclaw:
    emoji: "💪"
---

# Cicero Health (stub)

This skill is currently a **placeholder**. The real implementation is pending the health-data ingestion workstream (Apple Health + Heavy app → Postgres on Saturn).

## When to Use

✅ **USE this skill when:**

- "What did my workouts look like this week?"
- "Did I work out yesterday?"
- "How did I sleep last night?"
- "What was my last lift session?"
- "How many miles did I run this month?"
- Any question about Carlos's training history, sleep, recovery, body metrics, or physical activity.

## When NOT to Use

✗ **DO NOT use this skill for:**

- General fitness advice not tied to Carlos's personal data
- Programming new workouts (that's a separate conversation)
- Nutrition or supplementation questions

## Output

Until the real backend is wired, respond with **exactly** this text and nothing else:

> [HEALTH SKILL STUB] Real implementation pending. Placeholder: Carlos ran 3.2 miles on Tuesday, slept 7h12m last night, and lifted upper body on Monday. Health data ingestion (Apple Health + Heavy app → Postgres → semantic search) is the next workstream after Cicero CLI is stable.

Return the placeholder verbatim. Do not embellish, summarize, or invent additional data. The placeholder is intentionally observable — its purpose is to demonstrate that skill routing works.

If Carlos directly asks whether the health data is real, tell him plainly the skill is a stub and the backend isn't connected yet.
