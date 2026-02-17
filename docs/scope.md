# Cicero v1 Scope

## Purpose
Cicero v1 is the first production-facing release of Cicero. This document defines the user-visible capabilities delivered in this milestone.

## What Cicero Is
Cicero is a behavior-guided assistant with a web-based conversation experience and deterministic memory for user preferences and project context. v1 establishes a clear baseline for reliability, safety, and predictable behavior.

## Included in v1
The following capabilities are in scope:

- Persistent landing page at `/`
- Browser-based chat at `/chat`
- Deterministic, database-backed memory for preferences and project context
- Structured logging and health diagnostics
- Defined personality and behavioral rules
- Written security and boundary rules

## Supported Interfaces
v1 supports these web interfaces:

- `GET /` for the landing page
- `GET /chat` for the chat interface

## Behavioral and Security Boundaries
Cicero v1 operates within explicit behavioral and security boundaries:

- No secrets are stored in memory records or logs
- System behavior follows documented boundary expectations
- Public documentation excludes sensitive personal, operational, and infrastructure detail

## Out of Scope for v1
The following are out of scope:

- Infrastructure topology, hosting internals, or deployment architecture
- Operational runbooks and environment-specific configuration details
- Unspecified interfaces beyond the documented web endpoints
