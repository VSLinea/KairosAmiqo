# Copilot Persona — EXTENSIONS & SPECIAL MODES (KairosAmiqo)

This file defines advanced behaviors, fallback modes, and extensions to the core/operational persona.

---

## 1. SPECIAL MODES OVERVIEW

Copilot supports three special behavior modes:

1. **Strict Schema Guardian Mode**  
2. **Migration Safety Mode**  
3. **iOS–Backend Sync Mode**

These modes activate automatically depending on user requests.

---

## 2. STRICT SCHEMA GUARDIAN MODE

Triggers when user requests:

- Schema edits  
- Migration scripts  
- SQL changes  
- Database refactors  
- State machine modifications  

Behavior:

- Enforce schema rules from `/docs/04-database-schema.md`
- Reject destructive operations (drops, renames, type changes)
- Warn before any backward-incompatible modification
- Propose safe alternatives
- Require migration sequences to follow Section 6 conventions
- Ensure utctime-only timestamps
- Check consistency with API contracts

---

## 3. MIGRATION SAFETY MODE

Triggers on:

- Any request to add a column  
- Add a table  
- Modify a constraint  
- Create or change indexes  

Behavior:

- Use forward-only patterns  
- Use `CREATE INDEX CONCURRENTLY`  
- Never modify existing table relationships  
- Provide multi-step migrations  
- Ensure draft → stable → validated patterns  

Copilot must also generate:

- Roll-forward plans  
- No rollbacks (prohibited in Kairos system)

---

## 4. iOS–BACKEND SYNC MODE

Triggers on:

- iOS code that touches API or database  
- Swift model updates  
- JSON parsing  
- Data decoding logic  

Behavior:

- Compare Swift struct fields to API docs  
- Enforce identical names and casing  
- Enforce required/optional rules  
- Ensure envelope shape is preserved  
- Ensure enums match canonical state machine  

Copilot must check:

- `/docs/02-api-contracts.md`
- `/docs/01-data-model.md`
- `/docs/05-api-reference.md`
- Swift models in `/ios/KairosAmiqo/Models`

---

## 5. RACAG-ENHANCED SEARCH MODE

Copilot must automatically:

- Pull embeddings from RACAG
- Use context_assembler → markdown unification
- Retrieve the most relevant chunk IDs
- Maintain continuity across long tasks
- Use retrieval to avoid forgetting documentation details

If a decision conflicts with RACAG context, Copilot must flag it.

---

## 6. DETECTING ARCHITECTURE VIOLATIONS

Copilot must actively detect and warn about:

- Unauthorized API fields
- Routes not in the spec  
- Database columns that disagree with schema  
- iOS models missing fields  
- JSON envelope mismatches  
- Backend logic that reads encrypted data  
- Timestamp formats not UTC ISO-8601  
- Inconsistent UUID casing  
- State machine violations  
- Breaking migration rules  

---

## 7. EPIC/SUBTASK MODE (P–S–T–ST–SP)

Copilot must:

- Use the hierarchical ID system consistently  
- Mark outputs with the correct ID  
- Link tasks back to `/tracking/TRACKING.md`  
- Enforce proper task ordering  
- Prevent skipping steps that break the sequence  

---

## 8. PRODUCTION READINESS MODE

For any production-bound work, Copilot must:

- Enforce structured logs (Pino)
- Enforce rate limits
- Enforce JWT validation strictly
- Enforce error envelope format
- Avoid leaking metadata about other users
- Follow GCP Cloud Run best practices

---

## 9. PERFORMANCE & SCALABILITY GUARDRAILS

Copilot must ensure:

- Queries use existing indexes  
- Avoid n+1 patterns  
- Use pagination when required  
- Avoid JSONB deep traversal  
- Avoid ORM overfetching  
- Use transactions appropriately  
- Avoid blocking the event loop  

---

## 10. HOW TO UPDATE THIS FILE

Only update this file when:

- Adding a new operating mode  
- Changing architecture  
- Changing production rules  

All updates require a tracking entry in:
/tracking/TRACKING.md
with a task ID (P–S–T–ST–SP).