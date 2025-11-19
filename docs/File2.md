# Copilot Persona — OPERATIONAL DIRECTIVES (KairosAmiqo)

This file defines how Copilot must operate **during day-to-day development work** inside this repository.

---

## 1. WORKFLOW PRIORITY

Copilot must always think in this order:

1. **Canonical Documentation**  
   `/docs/00–05-*`
2. **Database Schema**  
   `/docs/04-database-schema.md`
3. **API Contracts**  
   `/docs/02-api-contracts.md`
4. **Backend Structure**  
   `/docs/03-backend-structure.md`
5. **iOS Integration**  
   `/ios/*`
6. **RACAG Retrieval Results**  
   The final authority if ambiguity exists  

This is the resolution hierarchy.

---

## 2. WHEN WRITING CODE

All backend code must:

- Use TypeScript  
- Follow `/docs/03-backend-structure.md`  
- Follow API specs in `/docs/02-api-contracts.md`
- Conform to data model in `/docs/01-data-model.md`
- Enforce validation exactly as per docs  
- Use canonical envelope format  
- Apply Firebase JWT auth middleware  
- Never deviate from database schema  

Every file must be generated in perfect structure:
/backend/src/
app.ts
plugins/
middleware/
routes/
services/
utils/
---

## 3. WHEN READING OR EDITING CODE

Copilot must:

- Maintain style consistency  
- Preserve structure  
- Identify security, schema, or logic violations  
- Infer intentions from RACAG context  
- Highlight violations of the canonical architecture  

Copilot must NOT:

- Reformat the entire file unnecessarily  
- Modify working logic unless explicitly asked  
- Overwrite sections required by the spec

---

## 4. API DEVELOPMENT RULES

- Every endpoint must return canonical envelopes:
  - success `{ data, meta }`
  - error `{ error }`

- All validation must follow:
  - schema constraints
  - API contract constraints
  - business rules from state machine

- All handlers must enforce:
  - Firebase JWT validation  
  - Authorization rules (owner/participant)  
  - Rate limits  

---

## 5. DATABASE DEVELOPMENT RULES

- Use Prisma as the ORM
- First migration: `0001_init.sql` generated from schema docs
- Never break migration rules:
  - No dropping columns
  - No renaming columns
  - No changing FK/PK
- Only additive forward-only changes

---

## 6. E2EE RULES

Backend must:

- Never decrypt encrypted content
- Never inspect encrypted blobs
- Treat encrypted fields as opaque strings
- Validate only metadata

Any violation must be flagged immediately.

---

## 7. RACAG USAGE RULES

When needed:

1. Retrieve relevant documentation  
2. Extract rules or definitions  
3. Apply deterministically  
4. Mention which doc sections governed the decision (short reference)

Copilot must lean heavily on RACAG retrieval to avoid forgetting.

---

## 8. TESTING RULES

Copilot must enforce:

- Unit tests for utils  
- Integration tests for each endpoint  
- DB-backed tests for complex logic  
- TestFlight-specific tests for iOS flows  

Test names must be deterministic and descriptive.

---

## 9. CODE QUALITY RULES

- No magic values  
- No TODOs without task IDs  
- No undocumented fields  
- No unused imports  
- Log minimal and structured (Pino)  
- Never leak sensitive data in logs

---

## 10. COMMUNICATION STYLE

Copilot answers must be:

- Structured  
- Hierarchical  
- Dense with information  
- Minimal in fluff  
- No conversational tone  
- No emojis  
- Engineering-first