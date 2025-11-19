# Kairos Documentation

**Status:** 📋 Not yet implemented (awaiting Phase 2)  
**Purpose:** Canonical specifications for architecture, APIs, and data models  
**Target:** Complete rewrite with zero legacy references

---

## Purpose of This Directory

The `/docs` directory serves as the **single source of truth** for:
- System architecture and component interactions
- API contracts (request/response schemas, endpoints)
- Database schema and data models
- Authentication flows and security policies
- Development workflows and conventions

**Design Principle:** Documentation-first development. All contracts are defined in `/docs` before implementation begins in Phase 3.

---

## Planned Document Structure

### Phase 2 Deliverables (Documentation Rewrite)

```
docs/
├── README.md                              # This file
├── 00-architecture-overview.md            # System-level design
├── 01-data-model.md                       # Database schema (PostgreSQL)
├── 02-api-contracts.md                    # REST API contracts (Fastify)
├── 02-terminology.md                      # Canonical terminology
├── 03-backend-structure.md                # Backend project structure
├── 04-database-schema.md                  # Complete database schema
└── 05-api-reference.md                    # Full API reference
```

---

## Naming Conventions

### File Names
- **Lowercase with hyphens:** `core-data-model.md` (not `CoreDataModel.md`)
- **Descriptive:** `authentication-flow.md` (not `auth.md`)
- **No version suffixes:** Update in place, use Git history for versions

### Section Headers
- **ATX-style headers:** `## Section Name` (not underline style)
- **Sentence case:** "Database schema" (not "Database Schema")
- **Consistent depth:** Max 3 levels (`###` for subsections)

### Code Blocks
- **Language tags:** ` ```typescript `, ` ```swift `, ` ```sql `
- **Syntax highlighting:** Always specify language for fenced blocks
- **Inline code:** Use backticks for identifiers: `POST /negotiate/start`

---

## Documentation Philosophy

### Documentation-First Development

**Phase 2 (Documentation Rewrite) comes BEFORE Phase 3 (Implementation).**

**Why:**
- ✅ Forces clear thinking about contracts before coding
- ✅ Prevents implementation drift and "figure it out later" debt
- ✅ Enables parallel work (iOS team reads backend spec while backend builds)
- ✅ Serves as acceptance criteria (implementation matches spec = done)

### Living Documents

**Documents evolve with the codebase:**
- Phase 2: Write initial specifications
- Phase 3-4: Update as implementation reveals edge cases
- Phase 5: Final validation against production behavior

**Maintenance:**
- Keep `/docs/` synchronized with production code
- Use Git history for version tracking (no `_v1.md`, `_v2.md` suffixes)
- All documents in flat structure for easy access

---

## Key Documents (Phase 2 Roadmap)

### 1. Architecture Overview
**File:** `00-architecture-overview.md`  
**Purpose:** High-level system design, component interactions, deployment topology  
**Contents:**
- System diagram (iOS ↔ Fastify ↔ PostgreSQL)
- Authentication flow (Firebase JWT)
- Data flow (negotiation lifecycle)
- Technology stack justification

---

### 2. Core Data Model
**File:** `01-data-model.md`  
**Purpose:** Complete PostgreSQL schema specification  
**Contents:**
- Table definitions (`negotiations`, `participants`, `events`, etc.)
- Column types, constraints, indexes
- Foreign key relationships
- Migration strategy

**Reference:** This spec drives `backend/migrations/*.sql` in Phase 3.

---

### 3. Backend APIs
**File:** `02-api-contracts.md`  
**Purpose:** REST API contracts (Fastify endpoints)  
**Contents:**
- Endpoint definitions (`POST /negotiate/start`, etc.)
- Request/response schemas (TypeScript types)
- Error codes and messages
- Authentication requirements

**Reference:** This spec drives `backend/src/routes/*.ts` in Phase 3.

---

### 4. Authentication Flow
**File:** See `00-architecture-overview.md` Authentication Flow section  
**Purpose:** Firebase Auth + JWT verification design  
**Contents:**
- iOS login flow (Firebase SDK)
- Token format and claims
- Backend verification (Firebase Admin SDK)
- Error handling (expired tokens, invalid signatures)

---

### 5. Negotiation State Machine
**File:** See `01-data-model.md` and `02-api-contracts.md`  
**Purpose:** Negotiation lifecycle logic  
**Contents:**
- State transitions (pending → confirmed → event)
- Round limits and expiration rules
- Participant consensus logic
- Future: AI agent integration hooks

---

### 6. E2EE Specification
**File:** See `00-architecture-overview.md` Privacy Model section  
**Purpose:** End-to-end encryption design  
**Contents:**
- Encryption algorithms (AES-256-GCM)
- Key management (iOS Keychain, Diffie-Hellman)
- Encrypted data types (agent preferences, messages)
- Zero-knowledge guarantees

---

## Phase 2 Task Breakdown

**See:** [`/tracking/TRACKING.md`](../tracking/TRACKING.md) for granular task list.

**High-Level Phases:**
- **P2.S1:** Architecture overview (system design)
- **P2.S2:** Core data model (PostgreSQL schema)
- **P2.S3:** Backend API contracts (Fastify endpoints)
- **P2.S4:** Authentication & security flows
- **P2.S5:** E2EE design (encryption model)

**Timeline:** Phase 2 starts after Phase 1 (Repository Purge & Reset) completes.

---

## Current Status

**Phase 1 (Repository Setup):** ✅ In Progress  
**Phase 2 (Documentation Rewrite):** ⏸️ Not started  
**Expected Start:** December 2025

**What Exists Now:**
- This README (structural guide)
- Empty `/docs` directory (awaiting Phase 2)

**What's Coming:**
- Complete API specifications (Phase 2)
- Database schema definitions (Phase 2)
- Architecture diagrams (Phase 2)

---

## Contributing to Documentation

### Phase 2 Writing Guidelines

**1. Use Canonical Specs:**
- Reference existing specifications in `/docs/`
- Reference existing decisions in `/tracking/TRACKING.md`
- Cite technology choices (e.g., "Why Fastify?")

**2. Be Precise:**
- Define all data types (TypeScript interfaces, SQL DDL)
- Include example payloads (JSON request/response samples)
- Document error cases (400/401/403/500 scenarios)

**3. Avoid Ambiguity:**
- ❌ "The system handles authentication" (vague)
- ✅ "Fastify backend verifies Firebase JWT tokens using Firebase Admin SDK v12" (specific)

**4. Link Liberally:**
- Reference other docs: `See [Core Data Model](01-data-model.md)`
- Reference tracking: `Task P2.S3.T1 in /tracking/TRACKING.md`
- Reference code (Phase 3+): `Implemented in backend/src/routes/negotiate.ts`

---

## Documentation Standards

### Markdown Linting
- Use Prettier or markdownlint for consistency
- No trailing whitespace
- Max line length: 120 characters (soft limit)

### Diagrams
- **ASCII art preferred:** Embeds in Git diffs, searchable
- **Mermaid.js allowed:** For complex flows (rendered in GitHub)
- **External images avoided:** Hard to maintain, not version-controlled

### Code Examples
- **Real code:** Copy-paste from actual implementations (Phase 3+)
- **Type annotations:** Always include TypeScript types, Swift types
- **Comments:** Explain "why", not "what" (code shows "what")

---

## Where to Look Next

1. **Check current progress:**
   - [`/tracking/TRACKING.md`](../tracking/TRACKING.md) — Task-level status

2. **Understand project structure:**
   - [`/README.md`](../README.md) — Monorepo overview

3. **Prepare for Phase 2:**
   - Wait for P1 completion
   - Review MASTER-PLAN.md (root repo) for Phase 2 requirements
   - Review existing canonical documents in `/docs/`

---

**Last Updated:** November 18, 2025  
**Phase:** P1 (Repository Setup)  
**Next Milestone:** Phase 2 (Documentation Rewrite - Dec 2025)
