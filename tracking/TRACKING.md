---
project: Kairos Amiqo
tracking_version: 1
description: High-level progress tracker for Phases, Stages, Tasks, Steps, and Substeps under the P.S.T.ST.SP hierarchy.
---

## Legend
- Status values: TODO | IN_PROGRESS | DONE | BLOCKED
- Identifier format: P{phase}.S{stage}.T{task}[.ST{step}][.SP{substep}]

## Phase Overview
- **P1 – Repository Purge & Reset (Clean Slate)** ✅ COMPLETE
- **P2 – Documentation Rewrite (New Canonical Universe)**
- **P3 – Backend Implementation (Fastify API)**
- **P4 – iOS Refactor for New Backend**
- **P5 – Integration, Cloud Deployment & TestFlight**

## Task Tracking (Task-level only)

### P1 – Repository Purge & Reset
- [DONE] P1.S1.T1 – Identify dead components
- [DONE] P1.S1.T2 – Identify live components
- [DONE] P1.S1.T3 – Create repo snapshot notes
- [DONE] P1.S1.T4 – Disable obsolete CI/CD (conceptually)
- [DONE] P1.S2.T1 – Remove Directus code/config
- [DONE] P1.S2.T2 – Remove Node-RED code/config
- [DONE] P1.S2.T3 – Remove mock-server artifacts
- [DONE] P1.S2.T4 – Remove legacy schemas/YAML
- [DONE] P1.S2.T5 – Remove legacy backend scripts
- [DONE] P1.S3.T1 – Remove flowsBase/plansBase references
- [DONE] P1.S3.T2 – Remove Directus API calls
- [DONE] P1.S3.T3 – Remove Node-RED networking
- [DONE] P1.S3.T4 – Remove deprecated negotiation logic
- [DONE] P1.S4.T1 – Establish new backend/ structure
- [DONE] P1.S4.T2 – Move RACAG into tooling
- [DONE] P1.S4.T3 – Prepare fastify/ backend root
- [DONE] P1.S4.T4 – Ensure infra only runs Postgres
- [DONE] P1.S5.T1 – Create new monorepo
- [DONE] P1.S5.T2 – Verify monorepo integrity
- [DONE] P1.S5.T3 – Repository freeze (READMEs, .gitignore, .keep files)

### P2 – Documentation Rewrite
- [DONE] P2.S1.T1 – New architecture overview (high-level)
- [DONE] P2.S1.T2 – New component interaction diagram
- [DONE] P2.S1.T3 – New API surface summary
- [DONE] P2.S1.T4 – New system diagram (ASCII/markdown)
- [DONE] P2.S2.T1 – Negotiation model (core)
- [DONE] P2.S2.T2 – Participants model
- [DONE] P2.S2.T3 – Proposed slots model
- [DONE] P2.S2.T4 – Proposed venues model
- [DONE] P2.S2.T5 – Events model
- [DONE] P2.S2.T6 – Prep model for future encrypted blobs (E2EE)
- [DONE] P2.S3.T1 – POST /negotiate/start (contract)
- [DONE] P2.S3.T2 – POST /negotiate/reply (contract)
- [DONE] P2.S3.T3 – GET /negotiations/:id (contract)
- [TODO] P2.S3.T4 – Authentication flow using Firebase JWT
- [DONE] P2.S4.T1 – Token flow (login → token → API)
- [DONE] P2.S4.T2 – Request shape per endpoint
- [DONE] P2.S4.T3 – Error shape
- [DONE] P2.S4.T4 – Response shape
- [TODO] P2.S4.T5 – Offline sync behavior
- [TODO] P2.S5.T1 – Encryption model spec (at-rest & in-flight)
- [TODO] P2.S5.T2 – Storage model for encrypted blobs
- [TODO] P2.S5.T3 – E2EE rollout phases and compatibility notes

### P3 – Backend Implementation (Fastify)
- [TODO] P3.S1.T1 – Node project init
- [TODO] P3.S1.T2 – Install Fastify and core middleware
- [TODO] P3.S1.T3 – Install Firebase JWT verification tooling
- [TODO] P3.S1.T4 – Install PostgreSQL client/ORM
- [TODO] P3.S1.T5 – Dotenv/env config wiring
- [TODO] P3.S2.T1 – Server bootstrap (app entry)
- [TODO] P3.S2.T2 – Routes structure
- [TODO] P3.S2.T3 – Controllers/handlers structure
- [TODO] P3.S2.T4 – Middleware structure (auth, logging, errors)
- [TODO] P3.S3.T1 – Firebase JWT verifier integration
- [TODO] P3.S3.T2 – Request context injection (user_id from token)
- [TODO] P3.S3.T3 – Token expiration and error handling
- [TODO] P3.S4.T1 – Implement /negotiate/start
- [TODO] P3.S4.T2 – Implement /negotiate/reply
- [TODO] P3.S4.T3 – Implement state transitions
- [TODO] P3.S4.T4 – Implement expiration handling
- [TODO] P3.S4.T5 – Prepare hooks for future AI/agent integration
- [TODO] P3.S5.T1 – PostgreSQL connection setup
- [TODO] P3.S5.T2 – Table definitions for negotiations, participants, slots, venues, events
- [TODO] P3.S5.T3 – Migrations folder and first migration
- [TODO] P3.S5.T4 – Basic repository/query utilities

### P4 – iOS Refactor for New Backend
- [TODO] P4.S1.T1 – Remove old API client tied to Directus/Node-RED
- [TODO] P4.S1.T2 – Remove flowsBase/plansBase endpoints
- [TODO] P4.S1.T3 – Remove legacy negotiation networking paths
- [TODO] P4.S2.T1 – Base URL for new Fastify backend
- [TODO] P4.S2.T2 – Firebase token injection into Authorization header
- [TODO] P4.S2.T3 – Unified error handling and decoding
- [TODO] P4.S3.T1 – startNegotiation → POST /negotiate/start
- [TODO] P4.S3.T2 – replyNegotiation → POST /negotiate/reply
- [TODO] P4.S3.T3 – State handling in AppVM/models
- [TODO] P4.S3.T4 – UI bindings to negotiation state
- [TODO] P4.S4.T1 – Integrate new API calls into AppVM
- [TODO] P4.S4.T2 – Remove old logic paths
- [TODO] P4.S4.T3 – Update offline cache behavior
- [TODO] P4.S4.T4 – Test flows end-to-end in simulator

### P5 – Integration & TestFlight
- [TODO] P5.S1.T1 – Local Fastify + Postgres backend validation
- [TODO] P5.S1.T2 – Local iOS app → backend tests
- [TODO] P5.S1.T3 – Simulated multi-user negotiation scenarios
- [TODO] P5.S2.T1 – Deploy backend to Cloud Run
- [TODO] P5.S2.T2 – Connect backend to Cloud SQL Postgres
- [TODO] P5.S2.T3 – Configure basic security (HTTPS, allowed origins)
- [TODO] P5.S3.T1 – User creation and login paths
- [TODO] P5.S3.T2 – Negotiation start/reply flows
- [TODO] P5.S3.T3 – Basic notification flow (or placeholder/log)
- [TODO] P5.S3.T4 – Edge case testing (failures, invalid tokens, bad payloads)
- [TODO] P5.S3.T5 – Logging and error observability sanity check

## Activity Log (Detailed Substeps — chronological, not authoritative)

### Phase 2 — Documentation Rewrite

- P1.S5.T1.ST4.SP1 – Initialized TRACKING.md scaffold. Status: DONE.
- P1.S5.T2.ST3.SP1 – Verified monorepo integrity. Status: DONE.
- P1.S5.T3.ST2.SP2 – Repository freeze applied. Phase 1 completed.
- 2025‑11‑18 — Completed P2.S2.T1.ST5.SP4 — Negotiation-specific errors finalized.

## Next Active Task
- No active task currently set.

---

## Phase 1 – Completion Summary (2025-11-18)

**Status:** ✅ Phase 1 COMPLETE  
**Scope:** Full repository purge, reset, monorepo establishment, and integrity verification.

### Highlights
- Obsolete backend stack fully removed (Directus, Node‑RED, mock-server).
- Legacy negotiation logic, YAML schemas, and networking references eliminated.
- New monorepo (KairosAmiqo/) created with clean 8‑folder structure.
- RACAG moved into tooling and verified in-place.
- iOS project copied cleanly without legacy backend coupling.
- Repository frozen with .gitignore, READMEs, and .keep sentinels.
- Full contamination scan — repository confirmed clean.

### Artifacts Created in Phase 1
- `README.md` (root)
- `.gitignore`
- Folder scaffolds in backend/, infra/, scripts/, tests/, docs/, tracking/
- TRACKING.md initialized and updated through completion

### Activity Log Entry
- **2025‑11‑18** — Phase 1 summary recorded and freeze confirmed.

## Phase 2 – Sync Update (2025-11-18)

**Scope:** Documentation rewrite for backend architecture, data model, and API contracts.

### Status Summary

- **P2.S1.T1 – Architecture Overview Doc** — `DONE`  
- **P2.S1.T2 – Data Model Doc** — `DONE`  
- **P2.S1.T3 – API Contracts Doc** — `DONE`  
- **P2.S1.T4 – Backend Structure Doc** — `IN_PROGRESS`

### Subtask Coverage Details

- `P2.S1.T1.*` — All architecture subsections completed.  
- `P2.S1.T2.*` — All data-model subsections completed, including validation and state machine.  
- `P2.S1.T3.*` — All API contract sections fully specified and frozen for Phase 3.  
- `P2.S1.T4.ST1` — Backend structure skeleton complete.  
- `P2.S1.T4.ST2` — `/src` subsystem definitions complete (routes, controllers, services, middleware, plugins, schemas, utils, config, tests, migrations, scripts).  
- `P2.S1.T4.ST3` — Environment, Secrets Management, Local vs Cloud Config, Dev Workflow complete. Pending SP5–SP7 (Build & Deployment, Observability, Security).

### Activity Log (Phase 2 Sync)

- 2025‑11‑18 — Completed P2.S1.T1.* (Architecture Overview)  
- 2025‑11‑18 — Completed P2.S1.T2.* (Data Model)  
- 2025‑11‑18 — Completed P2.S1.T3.* (API Contracts)  
- 2025‑11‑18 — Completed P2.S1.T4.ST1 + ST2  
- 2025‑11‑18 — Completed P2.S1.T4.ST3.SP1–SP4  
- 2025‑11‑18 — Completed P2.S1.T4.ST3.SP5 (Building & Deployment section in docs/03-backend-structure.md).  
- 2025‑11‑18 — Completed P2.S1.T4.ST3.SP6 (Observability section).  
- 2025‑11‑18 — Completed P2.S1.T4.ST3.SP7 (Security Considerations section).  
- 2025‑11‑18 — Completed P2.S1.T4.ST3.SP8 (Added final Status section to backend structure document).  
- 2025‑11‑18 — Completed P2.S1.T5.ST2.SP1 (Overview, Design Principles, Schema Summary in 04-database-schema.md).  
- 2025‑11‑18 — Completed P2.S1.T5.ST3.SP1 (negotiations table defined).  
- 2025‑11‑18 — Completed P2.S1.T5.ST3.SP2 (participants table defined).  
- 2025‑11‑18 — Completed P2.S1.T5.ST3.SP3 (proposed_slots table defined).  
- 2025‑11‑18 — Completed P2.S1.T5.ST3.SP4 (proposed_venues table defined).  
- 2025‑11‑18 — Completed P2.S1.T5.ST3.SP5 (events table defined).  
- 2025‑11‑18 — Completed P2.S1.T5.ST4.SP1 (Data Types section populated).  
- 2025‑11‑18 — Completed P2.S1.T5.ST4.SP2 (Constraints section populated).  
- 2025‑11‑18 — Completed P2.S1.T5.ST5.SP1 (Indexing Strategy section populated).  
- 2025‑11‑18 — Completed P2.S1.T5.ST5.SP2 — Referential Integrity section fully populated.  
- 2025‑11‑18 — Completed P2.S1.T5.ST6.SP1 — Migration Rules scaffold created.  
- 2025‑11‑18 — **Completed P2.S1.T5.ST6.SP2 — Migration Rules fully populated** (all 7 subsections: Overview, Migration Categories, Allowed Patterns, Prohibited Operations, Example Sequences, Versioning Rules, Summary).  
- 2025‑11‑18 — **Completed P2.S1.T5.ST6.SP3 — Database Schema Status section finalized** (Completion Summary, Architectural Alignment, Constraints & Migration Freeze, Handoff to Phase 3).  
- 2025‑11‑18 — **✅ P2.S1.T5 COMPLETE** — Database Schema documentation finalized (1801 lines, all tables/constraints/indexes/integrity/migrations/status fully specified).  
- 2025‑11‑18 — **Completed P2.S2.T1.ST1.SP1** — API Reference document scaffold created (docs/05-api-reference.md with 9 sections).  
- 2025‑11‑18 — **Completed P2.S2.T1.ST1.SP2** — Populated API reference sections 1–3 (Overview, Auth recap, Conventions).  
- 2025‑11‑18 — **Completed P2.S2.T1.ST1.SP3** — Populated Section 4 Negotiation Endpoints (POST /negotiate/start, POST /negotiate/reply, GET /negotiations/:id, GET /negotiations).  
- 2025‑11‑18 — **Completed P2.S2.T1.ST2.SP1** — Event Endpoints scaffold created (5.1 GET /events/upcoming, 5.2 GET /events/:id, 5.3 POST /events placeholder).  
- 2025‑11‑18 — **Completed P2.S2.T1.ST2.SP2** — GET /events/upcoming fully populated.  
- 2025‑11‑18 — **Completed P2.S2.T1.ST2.SP3** — GET /events/:id fully populated.  
- 2025‑11‑18 — **Completed P2.S2.T1.ST2.SP4** — Scaffolded POST /events placeholder section.  
- 2025‑11‑18 — **Completed P2.S2.T1.ST3.SP1** — Scaffolded Section 6 User Endpoints in 05-api-reference.md.  
- 2025‑11‑18 — **Completed P2.S2.T1.ST3.SP2** — Fully defined GET /me endpoint in 05-api-reference.md.  
- 2025‑11‑18 — **Completed P2.S2.T1.ST3.SP3** — Marked admin-style user endpoints as future placeholders in 05-api-reference.md (no MVP/TestFlight implementation).  
- 2025‑11‑18 — **Completed P2.S2.T1.ST4.SP1** — Documented /health and /version utility endpoints in 05-api-reference.md.
- 2025‑11‑18 — **Completed P2.S2.T1.ST5.SP1** — Scaffolded Error Reference section.
- 2025‑11‑18 — Completed P2.S2.T1.ST5.SP4 — Negotiation-specific errors finalized.

---
