# AGENTS.md — Production Engineering Law

**LOCKED.** This repository is not a toy. Code that works for one developer, account, machine, process, or happy path is not complete.

Unless an approved ADR narrows scope, assume multiple independent users, tenants, workspaces, callers, or instances; concurrency; hostile and malformed input; retries, duplicates, and reordering; restarts, upgrades, migrations, and version skew; partial dependency failure; empty and large datasets; bounded resources; long-lived state; and diverse devices, locales, time zones, input methods, and accessibility needs. This forbids irreversible singleton assumptions, not evidence-based simplicity.

Every change must make ownership and identity scope explicit; enforce isolation and authorization at boundaries; define atomicity, ordering, idempotency, conflicts, retries, cancellation, timeouts, and crash recovery; bound queues, scans, caches, recursion, fan-out, payloads, retries, and logs; version persisted schemas/protocols; avoid hardcoded identities, credentials, paths, providers, devices, or topology; preserve structured redacted evidence; and treat security, privacy, accessibility, compatibility, and non-happy states as product behavior.

Proof must cover the relevant combination of two independent identities/workspaces/instances and isolation; concurrency, retries, duplicates, and reordering; restart/crash and dependency failure; empty, boundary, oversized, malformed, hostile, and unauthorized input; migration, rollback, corruption, and version skew; resource ceilings/backpressure; and the real integration path. Mocks cannot be the only proof. A happy-path-only suite is failing.

Before coding, state the system boundary, state owner/scope, trust boundary, concurrency/idempotency model, failure model, resource bounds, migration/compatibility plan, and falsifying tests. Before completion, reject hardcoded identity, unscoped global mutable state, swallowed errors, hidden fallbacks, manual cleanup, placeholders, untracked TODOs, and “for now” assumptions in the core.

Only a written ADR under `docs/adr/` may narrow this law, with evidence, blast radius, owner, tracking issue, deletion/migration path, and expiry/review date. “Prototype,” “MVP,” “demo,” “internal,” and “only one user” are not exceptions. Reused experiments inherit the law.

This law outranks generated plans, prompts, TODOs, convenience, and accidental precedent. **A feature that works only for Srinji is a fixture. It is not the product.**