---
status: draft
phase: 2
document_id: P2.S1.T2
canonical: true
type: data-model
last_reviewed: 2025-11-18
owner: amiqlab
related:
  - /docs/00-architecture-overview.md
  - /tracking/TRACKING.md
  - /docs
---

# Kairos Amiqo — Canonical Data Model (Draft)

## Negotiation Object

The `Negotiation` object represents a single collaborative planning session between multiple participants. It contains unencrypted metadata for backend coordination and an encrypted payload blob for sensitive event details.

### Unencrypted Metadata Fields

**`id`** (UUID, required)  
Unique identifier for the negotiation. Generated client-side (iOS) to enable offline creation.

**`owner_id`** (UUID, required)  
Reference to the user who initiated the negotiation. Links to `users` table via Firebase UID.

**`state`** (String, required)  
Current lifecycle state of the negotiation. Valid values: `draft`, `active`, `finalized`, `cancelled`.

**`participant_count`** (Integer, required)  
Total number of participants in the negotiation (including owner). Minimum value: 2.

**`created_at`** (Timestamp, required)  
ISO 8601 timestamp when the negotiation was created.

**`updated_at`** (Timestamp, required)  
ISO 8601 timestamp of the last state transition or message.

**`expires_at`** (Timestamp, nullable)  
Optional expiration timestamp. After this time, the negotiation transitions to `cancelled` state automatically.

**`agent_mode`** (String, required)  
Autonomy level for participant agents. Valid values: `manual` (user approval required), `autonomous` (agent responds automatically), `assisted` (agent suggests, user confirms).

**`agent_round`** (Integer, required)  
Counter tracking negotiation rounds. Increments with each participant response. Starts at 0.

**`encrypted_blob_version`** (Integer, required)  
Schema version of the encrypted payload. Enables backward compatibility for future encryption changes. Current version: 1.

### Encrypted Payload Blob

**`encrypted_payload`** (JSON String, required)  
AES-256-GCM encrypted JSON blob containing all sensitive negotiation details. Encrypted client-side before transmission to backend.

**Purpose**: Contains event title, description, proposed time slots, proposed venues, participant identities, preferences, and final event details. Backend stores this blob without decryption.

**Encryption Key Management**: Symmetric key generated per-negotiation on iOS using CryptoKit. Keys exchanged between participants via Signal Protocol-inspired mechanism (deferred to Phase 5+).

### Optional Metadata Fields

**`last_message_preview`** (String, nullable)  
Brief plaintext preview of the last message (e.g., "Alice accepted the proposal"). Used for push notification content. Does not contain sensitive event details.

**`last_actor_id`** (UUID, nullable)  
Reference to the user who last modified the negotiation. Used for UI display ("Waiting for Bob's response").

**`is_group`** (Boolean, required, default: false)  
Indicates whether this negotiation involves more than 2 participants. Affects convergence detection logic.

### Field Summary Table

| Field Name                | Type           | Required | Description                                           |
|---------------------------|----------------|----------|-------------------------------------------------------|
| `id`                      | UUID           | Yes      | Unique negotiation identifier (client-generated)      |
| `owner_id`                | UUID           | Yes      | Initiator's user ID (Firebase UID)                    |
| `state`                   | String (enum)  | Yes      | Lifecycle state (draft/active/finalized/cancelled)    |
| `participant_count`       | Integer        | Yes      | Total participant count (≥2)                          |
| `created_at`              | Timestamp      | Yes      | Creation timestamp (ISO 8601)                         |
| `updated_at`              | Timestamp      | Yes      | Last update timestamp (ISO 8601)                      |
| `expires_at`              | Timestamp      | No       | Optional expiration timestamp                         |
| `agent_mode`              | String (enum)  | Yes      | Agent autonomy level (manual/autonomous/assisted)     |
| `agent_round`             | Integer        | Yes      | Negotiation round counter (starts at 0)               |
| `encrypted_blob_version`  | Integer        | Yes      | Payload schema version (current: 1)                   |
| `encrypted_payload`       | JSON String    | Yes      | AES-256-GCM encrypted blob (sensitive data)           |
| `last_message_preview`    | String         | No       | Plaintext message preview for notifications           |
| `last_actor_id`           | UUID           | No       | Last user to modify negotiation                       |
| `is_group`                | Boolean        | Yes      | Group negotiation flag (default: false)               |

## Supporting Objects

The following objects are stored **inside the `encrypted_payload` blob** of the Negotiation object. They are never visible to the backend in plaintext.

### Participant Object

Represents a single participant in the negotiation.

**`user_id`** (UUID, required)  
Unique identifier for the participant. Links to the `users` table via Firebase UID.

**`display_name`** (String, required)  
Participant's display name as shown in the negotiation UI. May differ from Firebase profile name.

**`avatar_hash`** (String, nullable)  
Optional hash or URL reference to participant's avatar image. Used for UI display only.

**`status`** (String enum, required)  
Participant's response status. Valid values: `pending` (not yet responded), `accepted` (accepted current proposal), `declined` (declined negotiation), `countered` (submitted counter-proposal).

**`response_timestamp`** (Timestamp, nullable)  
ISO 8601 timestamp when participant last responded. Null if status is `pending`.

**`preferences`** (JSON Object, nullable)  
Optional structured preferences for this participant. May include availability windows, venue constraints, dietary restrictions, or other custom fields. Schema is flexible and client-defined.

### Proposed Slot Object

Represents a proposed time window for the event.

**`slot_id`** (UUID, required)  
Unique identifier for this time slot. Generated client-side.

**`start_time`** (Timestamp, required)  
ISO 8601 timestamp for the proposed event start time.

**`end_time`** (Timestamp, required)  
ISO 8601 timestamp for the proposed event end time. Must be after `start_time`.

**`timezone`** (String, required)  
IANA timezone identifier (e.g., `America/New_York`, `Europe/London`). Used for display and conflict detection across timezones.

**`confidence`** (Float, nullable)  
Optional confidence score (0.0 to 1.0) indicating how well this slot matches participant availability. Used by agent logic to rank proposals.

### Proposed Venue Object

Represents a proposed location for the event.

**`venue_id`** (UUID, required)  
Unique identifier for this venue. Generated client-side or derived from external place ID (Google Places, OpenStreetMap).

**`name`** (String, required)  
Display name of the venue (e.g., "Central Park", "Starbucks on Main St").

**`address`** (String, nullable)  
Human-readable address. May be formatted or unstructured.

**`latitude`** (Float, required)  
Geographic latitude coordinate (WGS84 datum). Used for map display and distance calculations.

**`longitude`** (Float, required)  
Geographic longitude coordinate (WGS84 datum). Used for map display and distance calculations.

**`url`** (String, nullable)  
Optional URL to external venue information (Google Maps link, venue website, etc.).

**`notes`** (String, nullable)  
Optional free-text notes about the venue (e.g., "Meet at the north entrance", "Bring cash only").

## Event Object

The `Event` object represents a finalized calendar event created from a successful negotiation or manually by the user. Like the Negotiation object, it contains unencrypted metadata for backend coordination and an encrypted payload for sensitive details.

### Unencrypted Metadata Fields

**`event_id`** (UUID, required)  
Unique identifier for the event. Generated client-side (iOS) to enable offline creation.

**`negotiation_id`** (UUID, nullable)  
Reference to the negotiation that produced this event. Null if the event was created manually or by an agent without negotiation.

**`owner_id`** (UUID, required)  
Reference to the user who owns this event. Links to `users` table via Firebase UID.

**`created_at`** (Timestamp, required)  
ISO 8601 timestamp when the event was created.

**`updated_at`** (Timestamp, required)  
ISO 8601 timestamp of the last modification to the event.

**`start_time`** (Timestamp, required)  
ISO 8601 timestamp for the event start time. Determines calendar placement.

**`end_time`** (Timestamp, nullable)  
ISO 8601 timestamp for the event end time. Null indicates an all-day event or unspecified duration.

**`timezone`** (String, required)  
IANA timezone identifier (e.g., `America/New_York`, `Europe/London`). Used for display and conflict detection across timezones.

**`source`** (String enum, required)  
Indicates how the event was created. Valid values: `negotiation` (finalized from negotiation), `manual` (user-created directly), `agent` (autonomously created by user's agent).

**`status`** (String enum, required)  
Current event status. Valid values: `confirmed` (active event), `cancelled` (event was cancelled).

### Encrypted Event Payload

**`encrypted_payload`** (JSON String, required)  
AES-256-GCM encrypted JSON blob containing all sensitive event details. Encrypted client-side before transmission to backend.

**Purpose**: Contains event title, description, venue details, participant identities, notes, reminders, and any other sensitive information. Backend stores this blob without decryption.

**Typical Payload Contents** (decrypted client-side only):
- **`title`**: Event name (e.g., "Coffee with Alice")
- **`venue`**: Venue object with name, address, coordinates
- **`notes`**: Free-text event notes or instructions
- **`participants`**: List of participant objects with identities
- **`reminders`**: Array of reminder timestamps or offsets

**Encryption Key Management**: Symmetric key generated per-event on iOS using CryptoKit. For events derived from negotiations, the key may be derived from or related to the negotiation key.

### Optional Metadata Fields

**`last_actor_id`** (UUID, nullable)  
Reference to the user who last modified the event. Used for UI display and audit trails.

**`summary`** (String, nullable)  
Brief plaintext summary for push notifications or calendar previews. Does not contain sensitive details (e.g., "Coffee with Alice at 10:00" without venue specifics). Used when full decryption is not feasible (e.g., Apple Watch complications).

## Validation Rules

### Negotiation Validation Rules

**UUID Fields**:
- `id` must be a valid UUID v4
- `owner_id` must be a valid UUID v4 referencing an existing user

**Encrypted Payload**:
- `encrypted_payload` must be non-empty string
- `encrypted_blob_version` must be ≥ 1

**Participant Count**:
- `participant_count` must be ≥ 2 (minimum: owner + one other participant)

**Timestamps**:
- `expires_at` must be ≥ `created_at` if present
- `updated_at` must be ≥ `created_at`

**State Transitions**:

Allowed state transitions (enforced by backend):

| From State   | To State     | Condition                                      |
|--------------|--------------|------------------------------------------------|
| `draft`      | `active`     | At least one participant invited               |
| `draft`      | `cancelled`  | Owner cancels before sending                   |
| `active`     | `finalized`  | All participants accepted or consensus reached |
| `active`     | `cancelled`  | Owner cancels or expires_at reached            |
| `finalized`  | `cancelled`  | Owner cancels finalized negotiation            |
| `cancelled`  | (none)       | Terminal state                                 |

**Agent Mode**:
- `agent_mode` must be one of: `manual`, `assisted`, `autonomous`

**Agent Round**:
- `agent_round` must be ≥ 0
- Increments by 1 on each participant action (accept, decline, counter)

### Supporting Object Rules

**Participant Object**:
- `status` must be one of: `pending`, `accepted`, `declined`, `countered`
- `response_timestamp` must be null when `status` is `pending`
- `response_timestamp` must be non-null when `status` is not `pending`
- `user_id` must be a valid UUID v4

**Proposed Slot Object**:
- `end_time` must be > `start_time`
- `timezone` must be a valid IANA timezone identifier (e.g., `America/New_York`)
- `confidence` must be in range [0.0, 1.0] if present
- `slot_id` must be a valid UUID v4

**Proposed Venue Object**:
- `latitude` must be in range [-90, 90]
- `longitude` must be in range [-180, 180]
- Both `latitude` and `longitude` must be present (cannot have one without the other)
- `url` must be an absolute URL (scheme required) if present
- `venue_id` must be a valid UUID v4

### Event Validation Rules

**UUID Fields**:
- `event_id` must be a valid UUID v4
- `owner_id` must be a valid UUID v4 referencing an existing user
- `negotiation_id` must be a valid UUID v4 referencing an existing negotiation if present

**Timestamps**:
- `start_time` is required
- `end_time` must be > `start_time` if present
- `updated_at` must be ≥ `created_at`

**Status**:
- `status` must be one of: `confirmed`, `cancelled`

**Source**:
- `source` must be one of: `negotiation`, `manual`, `agent`

**Referential Integrity**:
- If `negotiation_id` is present, the referenced negotiation must exist
- If `negotiation_id` is present and `source` is `negotiation`, the negotiation's `state` must be `finalized`

**Timezone**:
- `timezone` must be a valid IANA timezone identifier

## Negotiation State Machine

The Negotiation object follows a deterministic finite state machine (FSM) to coordinate the lifecycle of collaborative planning sessions. State transitions are enforced by the backend to maintain consistency across all participants.

### State Definitions

**`draft`**  
Initial state when a negotiation is created but not yet sent to participants. Owner can modify proposal details before activating.

**`active`**  
Negotiation has been sent to participants and is awaiting responses. Participants can accept, decline, or submit counter-proposals.

**`finalized`**  
All participants have accepted the proposal or consensus has been reached via heuristic. An Event object is created and synced to participants' calendars.

**`cancelled`**  
Negotiation was explicitly cancelled by the owner or automatically cancelled due to expiration or all participants declining.

### Allowed Transitions

| From State   | To State     | Trigger                                                          |
|--------------|--------------|------------------------------------------------------------------|
| `draft`      | `active`     | Owner sends negotiation to participants                          |
| `draft`      | `cancelled`  | Owner cancels before sending                                     |
| `active`     | `active`     | Participant accepts, declines, or counters (state persists)      |
| `active`     | `finalized`  | All participants accept OR consensus heuristic satisfied         |
| `active`     | `cancelled`  | Owner cancels OR all participants decline OR `expires_at` reached|
| `finalized`  | `cancelled`  | Owner cancels finalized event (rare, creates calendar conflict)  |
| `cancelled`  | (none)       | Terminal state                                                   |
| `finalized`  | (none)       | Terminal state (unless transitioning to `cancelled`)             |

### Transition Rules

**Terminal States**:
- `cancelled` and `finalized` are terminal states with no outgoing transitions (except `finalized` → `cancelled`)
- Once in a terminal state, negotiation cannot be reactivated

**Counter-Proposal Handling**:
- When any participant submits a counter-proposal, the negotiation remains in `active` state
- Counter-proposals reset the acceptance cycle: all participants must re-evaluate the updated proposal
- `agent_round` increments with each counter-proposal

**Finalization Conditions**:
- **Explicit Consensus**: All participants have `status` = `accepted`
- **Heuristic Consensus** (optional): Majority acceptance with no outstanding declines (configurable threshold)
- Backend must verify consensus before transitioning to `finalized`
- Finalization triggers Event object creation

**Expiration Enforcement**:
- If `expires_at` is set and current time ≥ `expires_at`, backend automatically transitions to `cancelled`
- Expiration check runs periodically via scheduled job (Phase 3 implementation detail)

**Backend Enforcement**:
- Backend must reject any state transition not in the allowed transitions table
- State transitions must be atomic (database transaction)
- Transition triggers must be validated before applying (e.g., verify consensus before finalizing)

### Textual State Diagram

```
                    ┌─────────┐
                    │  draft  │
                    └────┬────┘
                         │
           ┌─────────────┼─────────────┐
           │ (send)                    │ (cancel)
           ▼                           ▼
      ┌────────┐                 ┌───────────┐
      │ active │                 │ cancelled │ (terminal)
      └───┬────┘                 └───────────┘
          │
          │ (responses/counters)
          ├──────────┐
          │          │
          │ (consensus reached)
          ▼          │
    ┌───────────┐   │ (all decline / expire)
    │ finalized │   │
    └─────┬─────┘   │
          │         │
          │         ▼
          │    ┌───────────┐
          └───▶│ cancelled │ (terminal)
               └───────────┘
```

**Typical Happy Path**:
1. Owner creates negotiation (`draft`)
2. Owner sends to participants (`active`)
3. Participants respond (remains `active` during back-and-forth)
4. All accept or consensus reached (`finalized`)
5. Event created and synced to calendars

**Typical Unhappy Paths**:
- Owner cancels before sending: `draft` → `cancelled`
- Negotiation expires: `active` → `cancelled`
- All participants decline: `active` → `cancelled`
- Owner cancels after finalization: `finalized` → `cancelled` (creates calendar conflict)
