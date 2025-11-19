---
status: draft
phase: 2
document_id: P2.S1.T1
canonical: true
type: architecture
last_reviewed: 2025-11-18
owner: amiqlab
related:
  - /docs/00-architecture-overview.md
  - /tracking/TRACKING.md
  - /docs
---

# Kairos Amiqo — Architecture Overview

**Status**: Phase 2 Draft (Documentation Rewrite)  
**Tracking**: See `tracking/TRACKING.md` for implementation roadmap  
**Last Updated**: 2025-11-18

---

## System Overview

Kairos Amiqo is a privacy-first social coordination application that enables groups to collaboratively plan meetups through asynchronous negotiation. The system prioritizes:

- **Privacy-by-design**: End-to-end encryption for all event details
- **Collaborative autonomy**: Each participant's agent negotiates on their behalf
- **Minimal backend trust**: Backend never sees plaintext event data
- **Offline-first iOS experience**: SwiftUI app operates independently, syncs when online

The architecture separates concerns across three layers:

1. **Client Layer**: iOS app (SwiftUI + CryptoKit)
2. **Backend Layer**: Node.js API (Fastify + JWT validation)
3. **Data Layer**: PostgreSQL (encrypted blobs + metadata)

Authentication uses Firebase for identity federation. Negotiation state machines run on the backend with encrypted payloads.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                        │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────┐    │
│  │ Auth Layer │  │ Negotiation  │  │ Calendar Sync &  │    │
│  │ (Firebase) │  │ Coordinator  │  │ Local Persistence│    │
│  └────────────┘  └──────────────┘  └──────────────────┘    │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          │ HTTPS + JWT                       │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────────┐
         │     Backend (Node.js + Fastify)         │
         │  ┌───────────────┐  ┌────────────────┐ │
         │  │ Negotiation   │  │ Event Finalizer│ │
         │  │ State Machine │  │ (Encrypted)    │ │
         │  └───────────────┘  └────────────────┘ │
         │          │                   │          │
         │          └───────────────────┘          │
         │                   │                     │
         └───────────────────┼─────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │  PostgreSQL Database │
                  │  (Encrypted Blobs +  │
                  │   Metadata Only)     │
                  └──────────────────────┘
```

## Data Boundary & Privacy Model

**Privacy Principle**: The backend is untrusted. All sensitive negotiation data is encrypted client-side before transmission.

### What the Backend Sees

- Negotiation IDs (UUIDs)
- State transitions (`draft` → `active` → `finalized` → `cancelled`)
- Participant count (not identities)
- Encrypted payload blobs

### What the Backend Never Sees

- Event titles, descriptions, or venues
- Participant names or contact details
- Proposed time slots or preferences
- Final event details

### Encryption Strategy

- iOS app generates per-negotiation symmetric keys (AES-256-GCM via CryptoKit)
- Keys exchanged via Signal Protocol-inspired double ratchet (deferred to Phase 5+)
- Backend stores encrypted JSON blobs only
- Decryption occurs client-side after retrieval

## Core System Flows

### Authentication Flow

```
User → iOS App → Firebase Auth → JWT Token → Backend Validates → Session Established
```

**Steps**:
1. Firebase handles identity federation (Apple Sign-In, Google, Email)
2. Backend validates Firebase JWT on every request
3. No passwords stored in Kairos systems

### Negotiation Flow

```
Initiator Creates Plan → Encrypted Proposal → Backend (State: draft)
                                ↓
                    Participants Receive Push Notification
                                ↓
                    Each Participant's Agent Evaluates
                                ↓
            Accept / Counter / Decline → Backend (State Transitions)
                                ↓
                    Convergence Detected → State: finalized
                                ↓
                    Event Created → Calendar Sync
```

**Key Characteristics**:
- All plan details encrypted before leaving initiator's device
- Backend coordinates state transitions without seeing content
- Participant agents respond asynchronously (no real-time requirement)
- Convergence detection triggers event finalization

### Event Finalization Flow

```
Backend Detects Consensus → Sends Encrypted Event Details → iOS Decrypts
                                                    ↓
                                            Calendar Integration (EventKit)
                                                    ↓
                                            Push Notifications Sent
```

**Post-Finalization**:
- iOS app syncs event to system calendar
- All participants receive notification
- Negotiation state transitions to `finalized`

## Backend Responsibilities

The Fastify backend serves as a coordination layer and state machine orchestrator.

### Core Responsibilities

1. **Authentication**: Validate Firebase JWTs on every request
2. **Negotiation State Management**: Track lifecycle transitions (`draft` → `active` → `finalized` → `cancelled`)
3. **Push Notifications**: Trigger APNs for state changes
4. **Encrypted Blob Storage**: Persist encrypted negotiation payloads in PostgreSQL
5. **Participant Coordination**: Route messages between participants without seeing content
6. **Agent Scheduling**: Trigger periodic evaluation jobs for autonomous negotiation

### Key Constraints

- No plaintext event data ever written to disk
- All business logic operates on metadata (state, timestamps, participant count)
- No calendar access; events pushed to clients only
- No access to venue names, time preferences, or participant identities

## iOS Responsibilities

The SwiftUI app is the user's primary interface and privacy guardian.

### Core Responsibilities

1. **Encryption/Decryption**: All E2EE operations (AES-256-GCM via CryptoKit)
2. **Calendar Integration**: Sync finalized events to iOS Calendar (EventKit)
3. **User Preferences**: Store availability, venue preferences, learned locations locally
4. **Autonomous Agent**: Run negotiation logic locally, respond on user's behalf
5. **Offline Support**: Queue actions, sync when network available
6. **UI/UX**: Present negotiations, events, maps, notifications

### Key Constraints

- Never send plaintext event data over the network
- Maintain local cache for offline operation
- Respect user's privacy settings (calendar access, location services)
- All sensitive data encrypted at rest using iOS Keychain

## Non-Goals

This architecture explicitly does not address:

- **Web client**: iOS-only for MVP; web requires different E2EE strategy
- **Android client**: Deferred to post-MVP (Phase 8+); will mirror iOS architecture
- **Real-time chat**: Negotiation is asynchronous; no WebSocket required
- **Advanced AI recommendations**: Agent logic is rule-based for MVP
- **Multi-tenant backend**: Single deployment for MVP; scaling deferred
- **Video/voice calls**: Out of scope for negotiation workflow

## Future Extensions

_(Deferred to Phase 5+ per tracking/TRACKING.md)_

- **Signal Protocol Integration**: Replace symmetric keys with double ratchet for forward secrecy
- **Group Key Management**: Scalable key distribution for large groups (10+ participants)
- **Android Client**: Mirror iOS architecture with Kotlin + Jetpack Compose
- **Web Client**: Browser-based E2EE using SubtleCrypto API
- **Advanced Agent Reasoning**: LLM-based negotiation strategies and preference learning
- **Federated Backend**: Multi-region deployment with conflict resolution

---

**Next Steps**: See Phase 2 tasks in `tracking/TRACKING.md` for detailed data models, API specifications, and authentication flows.
