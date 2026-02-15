# Cicero

Cicero is planned to be a **sovereign, local-first home AI assistant**: a voice-driven system you can run on your own hardware that can understand requests, safely take actions across your devices, and continuously improve through structured customization. The default posture is **private-by-design** (your home data stays in your home), with optional, explicit “escape hatches” for cloud compute (for example GPU fine-tuning or model experimentation).

This repository is currently **early-stage** and may only contain scaffolding. This README describes the *intended direction* of the project: what Cicero is meant to become, the constraints it should uphold, and how the major pieces fit together.

## Vision

Most “assistants” are either:

- smart, but require sending your life to someone else’s servers, or
- local, but brittle, untrusted, and hard to extend beyond chat.

Cicero’s goal is to combine **capability with control**:

- **Local-first intelligence** powered by models you run yourself (initially via Ollama).
- **Actionability**: not only answering questions, but orchestrating real work in your home (routines, automations, multi-step tasks).
- **Safety and auditability**: actions must be explainable, constrained, reversible when possible, and logged.
- **Customization that compounds**: the system should get better by learning your preferences *without* becoming a black box.

## Product Goals (What Cicero Should Do)

### 1) Great Voice UX

- Low-latency wake/activate flow (wake word is optional; push-to-talk should always work).
- Robust speech recognition and speech synthesis with a “conversational but not chatty” tone.
- Interruptions, confirmations, and “read-back” behavior suitable for a noisy home.

### 2) A Safe, Structured Agent That Can Act

Cicero is planned to operate as an *orchestrator*:

- Understand intent, ask clarifying questions when needed, and plan a sequence of steps.
- Execute steps through connectors (“skills”) that are permissioned and testable.
- Prefer deterministic tools over free-form model output for critical actions.

Examples of planned task classes:

- Home control: lights, thermostat, scenes, media, presence/bedtime routines.
- Personal ops: timers, reminders, lists, calendar triage, simple messaging.
- Household knowledge: “Where did we buy the air filter?”, “When did we last change it?”
- Device orchestration: “Start the robot vacuum after we leave,” “Mute the TV when the baby monitor triggers.”

### 3) A Local “Home Memory” With Explicit Boundaries

Cicero should maintain a local, user-owned knowledge base:

- Capture: notes, preferences, household docs, manuals, receipts (as provided by the user).
- Retrieval: fast, citation-backed answers (show where the fact came from).
- Retention controls: deletion, retention windows, and “never store this” modes.

### 4) Customization and Tuning Without Losing Sovereignty

Planned customization layers:

- **Configuration**: declarative settings (household members, rooms, devices, do-not-disturb rules).
- **Policies**: what Cicero is allowed to do, when it must ask, and what is forbidden.
- **Skills**: local connectors and routines (Home Assistant, Hue, Sonos, etc.).
- **Model adaptation**: optional fine-tuning / preference optimization using GPU services (for example Modal), with careful control over what data leaves the home.

## Non-Goals (What Cicero Is Not)

- A generic “chat app.” Conversation is a UI, not the product.
- A surveillance system. Always-on sensing should be optional, transparent, and minimized.
- An autopilot with unrestricted device access. “Act” must be gated by permissions and policy.
- A cloud-first assistant. Cloud compute may exist as an opt-in tool, not a dependency.

## Guiding Principles

- **Local by default**: run without an internet connection for core capabilities.
- **Explicit consent**: cloud calls and data egress require clear opt-in and are auditable.
- **Least privilege**: each connector/skill gets only the permissions it needs.
- **Deterministic where it matters**: use structured tool calls, schemas, and validations.
- **Observable**: actions are logged with enough context to debug and trust the system.
- **Reversible**: prefer actions that can be undone; otherwise require confirmation.

## Planned Architecture (High Level)

At a high level, Cicero is intended to be composed of:

### 1) Local Runtime (the “Orchestrator”)

Runs on a home server (or a capable desktop), responsible for:

- voice session management (start/stop, barge-in, timeouts)
- request routing (ASR -> intent -> plan -> tools -> response -> TTS)
- policy enforcement and permissions
- audit log + trace store

### 2) Model Layer (Ollama-first)

- Local inference via Ollama for core reasoning and language.
- Pluggable providers: different local models, or optional remote models (explicitly enabled).
- Structured outputs (JSON schemas, tool call definitions) to reduce “agent drift.”

### 3) Tools/Skills Layer (Connectors)

Skills are planned to be:

- clearly permissioned (what they can read/write)
- individually testable
- schema-defined (inputs/outputs validated)
- able to run locally (preferred), with optional remote adapters when necessary

Examples:

- Home Assistant / Matter / Hue / Sonos
- calendar/reminders (local CalDAV or similar)
- media control (TV, speakers)
- local file/notes index

### 4) Memory Layer

Planned storage components:

- structured household facts + preferences (small, explicit, editable)
- conversational/session summaries (optional, bounded retention)
- document index for retrieval (citations required for “factual” answers)

### 5) Optional GPU Tuning / Experimentation (Modal)

When enabled, Cicero may:

- run training/evaluation jobs on GPUs (for example Modal)
- produce a tuned artifact (adapter weights, prompt/policy bundles, eval reports)
- keep raw private data local unless explicitly exported

## Security and Privacy Model (Planned)

Baseline assumptions:

- The home network is not inherently trusted.
- The assistant must be resilient to prompt injection via connected services (web content, device names, media metadata, etc.).

Planned controls:

- Role-based permissions per skill and per household member.
- “Dangerous action” gating (confirmations, step-up auth, time windows).
- Signed/verified skill bundles (optional but desirable).
- Local audit log with redaction support.
- Network egress allow-list for any cloud calls.

## Roadmap (Aspirational)

This is the rough shape of milestones (subject to change):

1. **Local voice loop**: microphone input -> ASR -> local LLM -> TTS, with usable latency.
2. **Tool calling + policy**: a minimal, safe tool framework + confirmations and logging.
3. **First home integrations**: a small set of practical skills (lights/media/routines).
4. **Home memory**: preference store + document-backed retrieval with citations.
5. **Customization workflow**: configs, policies, and “skill templates” that are easy to extend.
6. **Optional tuning**: evaluation harness + opt-in GPU workflows for improving behavior.

## Contributing

If you want to help shape the direction, the most valuable contributions early are:

- defining the initial “skills” interface (schemas, permissions, testing)
- voice UX decisions (latency budgets, barge-in behavior, error recovery)
- policy model and audit trail format
- a minimal integration with a home platform (for example Home Assistant)

## Clawbot Setup (No Siri)

For the current local-first setup notes for Clawbot (Ollama + OpenClaw + Tailscale Serve), see:

- `clawbot/README.md`
