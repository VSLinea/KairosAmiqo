---
status: draft
phase: 2
document_id: P2.S1.T3
canonical: true
type: terminology
last_reviewed: 2025-11-18
owner: amiqlab
related:
  - /docs/00-architecture-overview.md
  - /docs/01-data-model.md
  - /tracking/TRACKING.md
---

# Kairos Amiqo — Canonical Terminology (Draft)

This document defines the precise, canonical terminology used throughout the Kairos Amiqo system across backend, iOS, data models, and future agent systems. These terms eliminate ambiguity, prevent semantic drift, and ensure consistency between all layers of the architecture.

---

## 1. Negotiation (System Core Object)
**Definition:**  
A structured, multi-participant decision-making process containing encrypted proposals, participant states, and lifecycle transitions.

**Where Used:**  
- Backend data model  
- API requests/responses  
- iOS business logic  
- E2EE encrypted payload  
- State machine  
- Notifications  
- Agents (future)  

**Notes:**  
Negotiation is **always** the canonical name of the object in database, API, and documents.

---

## 2. Invitation (UI Presentation Term)
**Definition:**  
User-friendly label for a negotiation in the iOS interface — especially in dashboard cards, lists, and push notifications.

**Where Used:**  
- iOS UI only  
- Marketing copy / onboarding  
- Notifications («You have a new invitation»)

**NOT used in backend or data model.**  
A UI synonym for “Negotiation”, not a separate object.

---

## 3. Invite (Verb)
**Definition:**  
The action of adding participants to a negotiation.

**Where Used:**  
- User actions («Invite someone»)  
- Agent suggestions («Should I invite Sam?»)  
- Buttons and flows

**Not a data object.**  
Represents an action, not a schema.

---

## 4. Proposal (Encrypted Substructure)
**Definition:**  
A proposed option inside a negotiation: a time slot, a venue, or a counter-proposal.

**Where Used:**  
- Encrypted negotiation payload  
- Agent reasoning  
- iOS UI («New proposal from Bob»)  

**Not a top-level backend object.**

---

## 5. Event (Final Outcome)
**Definition:**  
A finalized meeting outcome created after a negotiation reaches consensus. Stored as a separate backend object for reminders, calendars, and scheduling.

**Where Used:**  
- Calendar integration  
- Push reminders  
- Agenda view  
- Backend unencrypted event object  

**Created from a negotiation; cannot exist independently.**

---

## 6. Participant (Encrypted Sub-object)
**Definition:**  
A user involved in a negotiation. Stored fully encrypted except minimal metadata (participant_count).

**Where Used:**  
- Inside encrypted payload  
- State tracking  
- E2EE messaging  

---

## 7. Counter-proposal (Action)
**Definition:**  
A participant's modification of proposed slots or venues.

**Where Used:**  
- Inside encrypted payload  
- Agent/UI action  
- Negotiation round updates  

---

## 8. Agent Mode (System-Level Behavior)
**Definition:**  
Defines if participant agents behave in *manual*, *autonomous*, or *assisted* mode.

**Where Used:**  
- Negotiation metadata  
- Agent logic execution  
- UI mode indicators  

---

## 9. Encrypted Payload Blob (Core Privacy Container)
**Definition:**  
AES-256-GCM encrypted JSON containing all sensitive negotiation data (slots, venues, messages, preferences, counters, etc.).

**Where Used:**  
- Stored on backend  
- Created and decrypted only on client  
- Diff-compatible with blob versioning  

---

## 10. Summary Field (Safe Metadata)
**Definition:**  
A short plaintext preview («Coffee with Alice at 10:00») used for dashboard/event listings.

**Where Used:**  
- UI  
- Notifications  
- Event object  

**Never contains sensitive content.**

---

## 11. State Machine Terms
**Lifecycle states:**
- **draft**  
- **awaiting_replies**  
- **counter_proposed**  
- **finalized**  
- **cancelled**  
- **expired**

These appear in Negotiation metadata and backend persistence.

---

# ✨ Summary of Naming Rules

### Backend, API, Data Model → **Use “Negotiation” exclusively.**  
### iOS UI → **May use “Invitation” as display text.**  
### Verb → “Invite” is allowed (action only).  
### Never use → “Plans”, “Invites” as nouns, “Start plan”, “Pending proposals”, etc.

---

# ✨ Status  
This terminology file is part of the Phase 2 documentation rewrite and is used as the canonical reference for all future backend and iOS implementation (Phase 3 & Phase 4).