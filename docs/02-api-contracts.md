---
status: draft
phase: 2
document_id: P2.S1.T3
canonical: true
type: api-contract
last_reviewed: 2025-11-18
owner: amiqlab
related:
  - /docs/00-architecture-overview.md
  - /docs/01-data-model.md
  - /tracking/TRACKING.md
---

# Kairos Amiqo — API Contracts (Draft)

## Overview

## API Conventions

### Content Type

**Required**: All requests and responses use `application/json`.

**Request Header**:
```
Content-Type: application/json
```

**Response Header**:
```
Content-Type: application/json
```

**Error Handling**: Requests with non-JSON content types are rejected with `415 Unsupported Media Type`.

### Envelope Format

**Success Envelope**:
```json
{
  "data": { /* resource or array of resources */ }
}
```

**Error Envelope**:
```json
{
  "error": {
    "code": "error_code_string",
    "message": "Human-readable error message",
    "details": { /* optional additional context */ }
  }
}
```

### Timestamps

**Format**: ISO 8601 with timezone information (e.g., `2025-11-18T14:30:00Z` or `2025-11-18T14:30:00-05:00`).

**Backend Storage**: All timestamps stored in UTC internally.

**Client Display**: Clients convert timestamps to local timezone for display. Timezone information preserved in `timezone` field where applicable (Negotiation, Event).

**Field Names**: Use `_at` suffix for timestamps (e.g., `created_at`, `updated_at`, `expires_at`).

### UUIDs

**Format**: All resource identifiers use UUID version 4 (random).

**Generation**: Client-generated UUIDs enable offline creation and prevent ID collisions.

**Validation**: Backend validates UUID format on all ID fields. Malformed UUIDs rejected with `400 Bad Request`.

**Field Names**: Use `_id` suffix for UUID fields (e.g., `negotiation_id`, `event_id`, `owner_id`).

### HTTP Status Codes

| Status Code | Meaning                                                                 |
|-------------|-------------------------------------------------------------------------|
| `200`       | Success (GET, PATCH, DELETE with response body)                        |
| `201`       | Resource created (POST)                                                 |
| `204`       | Success with no response body (DELETE, PATCH)                           |
| `400`       | Bad request (malformed JSON, invalid field values)                      |
| `401`       | Unauthorized (missing or invalid Firebase token)                        |
| `403`       | Forbidden (valid token, insufficient permissions)                       |
| `404`       | Resource not found                                                      |
| `409`       | Conflict (duplicate resource, invalid state transition)                 |
| `422`       | Unprocessable entity (validation failed)                                |
| `500`       | Internal server error                                                   |

### Pagination

**Query Parameters**:
- `limit` (integer, optional): Maximum number of items to return (default: 50, max: 100)
- `cursor` (string, optional): Opaque pagination cursor from previous response

**Response Format**:
```json
{
  "data": [ /* array of resources */ ],
  "pagination": {
    "next_cursor": "opaque_signed_token",
    "has_more": true
  }
}
```

**Cursor Properties**:
- Opaque: Clients must not parse or modify cursor values
- Signed: Backend signs cursors to prevent tampering
- Expiration: Cursors expire after 24 hours

**Applies To**: `GET /negotiations`, `GET /events`

### Idempotency

**Non-Idempotent**:
- `POST /negotiate/start`: Creates new negotiation with client-generated UUID (duplicate UUIDs rejected with `409 Conflict`)

**Conditionally Idempotent**:
- `POST /negotiate/reply`: Multiple identical replies may be deduplicated by backend based on `agent_round` and participant state (implementation detail)

**Always Idempotent**:
- All `GET` requests: No side effects, safe to retry
- `PATCH` requests: Applying same update multiple times produces same result
- `DELETE` requests: Deleting already-deleted resource returns `404` (idempotent outcome)

### Versioning

**Header**: Clients must include API version in all requests.

```
Kairos-API-Version: 1
```

**Current Version**: 1

**Version Compatibility**:
- Backend supports current version only (no backward compatibility for MVP)
- Breaking changes increment version number
- Missing version header treated as version 1 (default)

**Breaking Change Policy** (deferred to Phase 4+):
- Field removals or type changes
- Required field additions
- Endpoint removals
- State machine transition changes

## Authentication

All API requests require authentication using **Firebase ID Tokens (JWT)**. The backend validates tokens on every request and extracts the authenticated user's identity.

### Authentication Method

**Firebase ID Token (JWT)**  
Clients must obtain an ID token from Firebase Authentication and include it in the `Authorization` header of every request.

### Required Headers

```
Authorization: Bearer <firebase_id_token>
```

**Token Format**:
- Standard JWT format: `header.payload.signature`
- Issued by Firebase Authentication
- Contains claims: `sub` (user ID), `email`, `email_verified`, `iat`, `exp`, `aud`, `iss`

### Backend Responsibilities

1. **Signature Verification**: Validate JWT signature using Firebase public keys
2. **Claims Validation**: Verify `aud` (audience), `iss` (issuer), `exp` (expiration)
3. **UID Extraction**: Extract user ID from `sub` claim for authorization checks
4. **Token Freshness**: Reject tokens with `exp` in the past

### Client Responsibilities

1. **Token Acquisition**: Obtain ID token from Firebase Authentication after user signs in
2. **Token Refresh**: Refresh expired tokens before making requests (Firebase SDK handles automatically)
3. **Header Inclusion**: Include `Authorization: Bearer <token>` on every authenticated request
4. **Anonymous Requests**: All endpoints require authentication; no anonymous access allowed

### Authentication Error Categories

**`invalid_token` (401)**  
Token is malformed, signature verification failed, or claims are invalid.

**`expired_token` (401)**  
Token's `exp` claim is in the past. Client must refresh token and retry.

**`unauthorized` (401)**  
No `Authorization` header provided or token extraction failed.

**`forbidden` (403)**  
Token is valid but user lacks permission for the requested resource (e.g., accessing another user's negotiation).

### Security Constraints

- **Stateless Authentication**: No server-side sessions; every request validated independently
- **No API Keys**: Only Firebase ID tokens accepted; no custom API keys or bearer tokens
- **No Passwords**: Backend never receives or stores passwords; Firebase handles credentials
- **HTTPS Only**: All requests must use HTTPS in production (enforced by infrastructure)

### Relationship to Data Model

**User Identity**:
- Firebase `sub` claim maps to `owner_id` and `user_id` fields in Negotiation and Event objects
- Backend automatically sets `owner_id` to authenticated user's UID when creating resources
- Clients cannot spoof `owner_id`; backend overrides any client-provided value with authenticated UID

**Authorization Rules**:
- Users can only access negotiations where they are the owner or a participant (checked server-side)
- Users can only modify their own events
- Participant list validation deferred to Phase 3 implementation

## Core Endpoints

### POST /negotiate/start

#### Purpose

Creates a new negotiation and initializes it in `draft` or `active` state. The client provides an encrypted payload containing event details, participant list, and proposed slots/venues.

#### Method & Path

```
POST /negotiate/start
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **Authenticated User**: Extracted from token `sub` claim and set as `owner_id`
- **Authorization**: No additional checks; any authenticated user can create negotiations

#### Request Schema

Based on canonical Negotiation object from `docs/01-data-model.md`:

**Required Fields**:
- `id` (UUID v4): Client-generated negotiation identifier
- `state` (string enum): Initial state (`draft` or `active`)
- `participant_count` (integer): Total participants including owner (≥ 2)
- `agent_mode` (string enum): `manual`, `assisted`, or `autonomous`
- `encrypted_payload` (string): AES-256-GCM encrypted JSON blob

**Optional Fields**:
- `expires_at` (ISO 8601 timestamp): Auto-cancel time (must be ≥ `created_at`)
- `is_group` (boolean): Group negotiation flag (default: `false`)

**Auto-Generated by Backend**:
- `owner_id`: Set from authenticated user's Firebase UID (client value ignored)
- `created_at`: Set to current UTC timestamp
- `updated_at`: Set to current UTC timestamp
- `agent_round`: Initialized to 0
- `encrypted_blob_version`: Set to 1 (current version)

#### Request Envelope

```json
{
  "id": "uuid-v4-string",
  "state": "draft",
  "participant_count": 3,
  "agent_mode": "assisted",
  "encrypted_payload": "base64-encoded-encrypted-blob",
  "expires_at": "2025-11-25T14:30:00Z",
  "is_group": true
}
```

#### Backend Behavior

**Validation**:
1. Validate Firebase JWT signature and claims
2. Validate `id` is a well-formed UUID v4
3. Reject if negotiation with same `id` already exists (`409 Conflict`)
4. Validate `state` is `draft` or `active`
5. Validate `participant_count` ≥ 2
6. Validate `agent_mode` ∈ {`manual`, `assisted`, `autonomous`}
7. Validate `encrypted_payload` is non-empty string
8. Validate `expires_at` ≥ `created_at` if provided
9. Reject invalid fields with `400 Bad Request` or `422 Unprocessable Entity`

**State Initialization**:
- Set `owner_id` from authenticated user's UID (overwrite any client-provided value)
- Set `created_at` and `updated_at` to current UTC timestamp
- Set `agent_round` to 0
- Set `encrypted_blob_version` to 1

**Persistence**:
- Insert negotiation into `negotiations` table (PostgreSQL)
- Return created resource with all fields including auto-generated values

#### Response

**Success (201 Created)**:
```json
{
  "data": {
    "id": "uuid-v4-string",
    "owner_id": "firebase-uid",
    "state": "draft",
    "participant_count": 3,
    "created_at": "2025-11-18T14:30:00Z",
    "updated_at": "2025-11-18T14:30:00Z",
    "expires_at": "2025-11-25T14:30:00Z",
    "agent_mode": "assisted",
    "agent_round": 0,
    "encrypted_blob_version": 1,
    "encrypted_payload": "base64-encoded-encrypted-blob",
    "is_group": true,
    "last_message_preview": null,
    "last_actor_id": null
  }
}
```

**Error Codes**:
- `400 Bad Request`: Malformed JSON, invalid UUID format, invalid enum values
- `401 Unauthorized`: Missing or invalid Firebase token
- `409 Conflict`: Negotiation with same `id` already exists
- `415 Unsupported Media Type`: Non-JSON content type
- `422 Unprocessable Entity`: Validation failed (e.g., `participant_count` < 2, `expires_at` < `created_at`)
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **E2EE Key Exchange**: Mechanism for sharing encryption keys between participants deferred to Phase 5+
- **Participant Validation**: Backend does not validate participant identities in `encrypted_payload` for MVP
- **Push Notifications**: Triggering APNs when state transitions to `active` deferred to Phase 3 implementation
- **Agent Classification**: Automatic detection of `agent_mode` based on user preferences deferred

### POST /negotiate/reply

#### Purpose

Processes a participant's reply to an existing negotiation. The participant can accept the current proposal, decline participation, or submit a counter-proposal with modified slots/venues. Behavior follows the canonical state machine defined in `docs/01-data-model.md`.

Backend responsibilities:
- Validate participant authorization
- Apply state transitions per state machine rules
- Update participant status in encrypted payload
- Store encrypted reply payload
- Increment negotiation round counter

#### Method & Path

```
POST /negotiate/reply
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **Actor Identity**: Extracted from token `sub` claim and set as `actor_id`
- **Authorization**: User must be a participant in the negotiation (owner or invited participant)
- **Forbidden (403)**: User is not a participant of the specified negotiation
- **No Anonymous Access**: All replies require authenticated user

#### Request Schema

**Required Fields**:
- `negotiation_id` (UUID v4): ID of the negotiation being replied to
- `action` (string enum): Participant's action (`accept`, `decline`, `counter`)
- `agent_mode` (string enum): Agent autonomy level for this action (`manual`, `assisted`, `autonomous`)
- `encrypted_payload` (string): AES-256-GCM encrypted JSON blob containing updated participant status and preferences

**Conditionally Required Fields**:
- `counter_payload` (string): Additional encrypted blob containing modified proposed slots/venues. Required only when `action` is `counter`.

**Auto-Set by Backend**:
- `actor_id`: Set from authenticated user's Firebase UID
- `updated_at`: Set to current UTC timestamp
- `agent_round`: Incremented by 1 for `assisted` or `autonomous` modes
- `last_actor_id`: Set to authenticated user's UID
- `last_message_preview`: Generated based on action (e.g., "Alice accepted the proposal")

**Validation Rules**:
- `negotiation_id` must be a valid UUID v4 referencing an existing negotiation
- User must be owner or participant (checked via encrypted participant list or owner_id)
- `action` must be one of: `accept`, `decline`, `counter`
- `encrypted_payload` must be non-empty string (valid base64)
- `counter_payload` required if and only if `action` is `counter`
- Action must be valid for negotiation's current state per state machine

#### Backend Behavior

**Authorization & Validation**:
1. Validate Firebase JWT signature and claims
2. Fetch negotiation by `negotiation_id` (return `404 Not Found` if missing)
3. Verify authenticated user is owner or participant (return `403 Forbidden` if not)
4. Validate `action` is allowed for current negotiation state per state machine
5. Validate `encrypted_payload` is non-empty
6. If `action` is `counter`, validate `counter_payload` is present and non-empty
7. Reject invalid requests with `400 Bad Request` or `422 Unprocessable Entity`

**State Transitions**:
- **Accept**: Update participant status to `accepted`. If all participants accepted, transition negotiation state to `finalized` and trigger Event creation.
- **Decline**: Update participant status to `declined`. If all participants declined, transition negotiation state to `cancelled`.
- **Counter**: Update participant status to `countered`. Negotiation remains in `active` state. Reset other participants' acceptance flags (implementation detail in encrypted payload).

**Updates Applied**:
- Replace `encrypted_payload` with new encrypted blob (contains updated participant statuses)
- If `action` is `counter`, store `counter_payload` (implementation detail: may merge or replace proposals)
- Set `updated_at` to current UTC timestamp
- Set `last_actor_id` to authenticated user's UID
- Set `last_message_preview` based on action:
  - `accept`: "Alice accepted the proposal"
  - `decline`: "Alice declined the proposal"
  - `counter`: "Alice submitted a counter-proposal"
- Increment `agent_round` by 1 if `agent_mode` is `assisted` or `autonomous`
- Update negotiation `state` if consensus reached (all accept → `finalized`, all decline → `cancelled`)

**Persistence**:
- Update negotiation record in `negotiations` table (PostgreSQL)
- Atomic transaction to prevent race conditions

#### Response

**Success (200 OK)**:
```json
{
  "data": {
    "id": "uuid-v4-string",
    "state": "active",
    "updated_at": "2025-11-18T14:35:00Z"
  }
}
```

**Response Fields**:
- `id`: Negotiation ID (unchanged)
- `state`: Updated negotiation state (`active`, `finalized`, or `cancelled`)
- `updated_at`: Timestamp of this reply

#### Error Codes

- `400 Bad Request`: Malformed JSON, invalid UUID format, invalid enum values
- `401 Unauthorized`: Missing or invalid Firebase token
- `403 Forbidden`: User is not a participant of the negotiation
- `404 Not Found`: Negotiation with specified `negotiation_id` does not exist
- `409 Conflict`: Invalid state transition (e.g., replying to `cancelled` or `finalized` negotiation)
- `422 Unprocessable Entity`: Validation failed (e.g., `counter_payload` missing when `action` is `counter`, or `encrypted_payload` empty)
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **Push Notifications**: APNs triggered on state changes deferred to Phase 3 implementation
- **Participant Identity Validation**: Backend does not decrypt or validate participant identities in `encrypted_payload` for MVP
- **Agent Autonomous Chaining**: Automatic multi-round agent negotiation deferred to Phase 5+
- **E2EE Reply Decryption**: All decryption of `encrypted_payload` and `counter_payload` remains client-side only
- **Backend Encryption Boundary**: Backend never decrypts payloads; stores opaque encrypted blobs only
- **Consensus Heuristics**: Advanced consensus detection (e.g., majority acceptance with timeout) deferred to Phase 4+

### GET /negotiations/:id

#### Purpose

Returns a single Negotiation resource by ID. This endpoint is used by the iOS app to refresh negotiation state after receiving push notifications or after offline sync. Returns only metadata and encrypted blob; no decryption occurs server-side.

Use cases:
- Refresh negotiation state after push notification
- Verify current state before submitting reply
- Offline sync when app returns online

#### Method & Path

```
GET /negotiations/:id
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **Authorization**: User must be the negotiation owner or a participant
- **Forbidden (403)**: User is not owner or participant of the specified negotiation
- **No Anonymous Access**: All requests require authenticated user

#### Path & Query Parameters

**Path Parameters**:
- `id` (UUID v4, required): Negotiation identifier

**Query Parameters**:
- None for MVP

#### Backend Behavior

**Request Processing**:
1. Validate Firebase JWT signature and claims
2. Validate `id` is a well-formed UUID v4 (return `400 Bad Request` if malformed)
3. Fetch negotiation from database by `id` (return `404 Not Found` if missing)
4. Verify authenticated user is owner or participant:
   - Check if authenticated UID matches `owner_id` (instant authorization)
   - If not owner, check participant list in `encrypted_payload` (implementation detail: may require decryption client-side or secondary participant index)
   - Return `403 Forbidden` if user is neither owner nor participant
5. Return negotiation resource with all fields

**Encryption Boundary**:
- Backend does **not** decrypt `encrypted_payload`
- Backend returns encrypted blob exactly as stored
- Client is responsible for decryption using negotiation key

#### Response

**Success (200 OK)**:
```json
{
  "data": {
    "id": "uuid-v4-string",
    "owner_id": "firebase-uid",
    "state": "active",
    "participant_count": 3,
    "created_at": "2025-11-18T14:30:00Z",
    "updated_at": "2025-11-18T14:35:00Z",
    "expires_at": "2025-11-25T14:30:00Z",
    "agent_mode": "assisted",
    "agent_round": 2,
    "encrypted_blob_version": 1,
    "encrypted_payload": "base64-encoded-encrypted-blob",
    "last_message_preview": "Alice accepted the proposal",
    "last_actor_id": "firebase-uid-alice",
    "is_group": true
  }
}
```

**Response Fields**:
Returns the canonical Negotiation resource as defined in `docs/01-data-model.md`. All fields included.

#### Error Codes

- `400 Bad Request`: Invalid UUID format for `id` parameter
- `401 Unauthorized`: Missing or invalid Firebase token
- `403 Forbidden`: User is not the owner or a participant of the negotiation
- `404 Not Found`: Negotiation with specified `id` does not exist
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **Denormalized Participant Previews**: Lightweight participant metadata (display names, avatar hashes) may be added to response in Phase 4+ to reduce client-side decryption overhead
- **Derived Fields**: Future versions may include computed fields such as `has_unread_updates`, `awaiting_user_action`, or `time_until_expiration`
- **Push Notification Acknowledgement**: Integration with APNs acknowledgement tracking deferred to Phase 3+
- **Participant Index**: Secondary index for participant authorization checks (to avoid encrypted payload inspection) deferred to Phase 3 optimization

### GET /negotiations

#### Purpose

Returns a paginated list of Negotiations where the authenticated user is either the owner or a participant. This endpoint powers the iOS dashboard, history views, and pull-to-refresh sync functionality.

**Use Cases**:
- iOS app dashboard: display active negotiations
- History view: show past finalized/cancelled negotiations
- Offline sync: refresh negotiation list when app returns online
- Pull-to-refresh: fetch latest updates

**Authorization**: Backend filters results to only include negotiations where the authenticated user is involved (owner or participant).

#### Method & Path

```
GET /negotiations
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **User Identity**: Extracted from token `sub` claim
- **Authorization**: Backend returns only negotiations where user is:
  - `owner_id` matches authenticated UID, OR
  - User appears in participant list (participant index deferred to Phase 3)
- **Forbidden (403)**: User attempts to impersonate another user or access unauthorized negotiations
- **No Anonymous Access**: All requests require authenticated user

#### Query Parameters

All query parameters are optional:

**Pagination**:
- `limit` (integer, optional): Maximum number of items to return. Default: 50, Maximum: 100.
- `cursor` (string, optional): Opaque pagination cursor from previous response. Used to fetch next page.

**Filters** (optional for MVP, full support in Phase 3):
- `state` (string enum, optional): Filter by negotiation state. Valid values: `draft`, `active`, `finalized`, `cancelled`.
- `agent_mode` (string enum, optional): Filter by agent autonomy level. Valid values: `manual`, `assisted`, `autonomous`.
- `updated_after` (ISO 8601 timestamp, optional): Return only negotiations updated after this timestamp.
- `updated_before` (ISO 8601 timestamp, optional): Return only negotiations updated before this timestamp.

#### Backend Behavior

**Request Processing**:
1. Validate Firebase JWT signature and claims
2. Parse and validate pagination parameters (`limit`, `cursor`)
3. Validate optional filters (`state`, `agent_mode`, timestamp ranges)
4. Query negotiations where:
   - `owner_id` = authenticated user's UID, OR
   - User appears in participant index (Phase 3 implementation)
5. Apply optional filters:
   - State filter: `WHERE state = ?`
   - Agent mode filter: `WHERE agent_mode = ?`
   - Timestamp range: `WHERE updated_at BETWEEN ? AND ?`
6. Sort results by `updated_at DESC` (most recent first)
7. Apply pagination:
   - Limit results to `limit` items
   - If `cursor` provided, start from cursor position
8. Generate `next_cursor`:
   - Opaque signed token containing last item's ordering key
   - Expires after 24 hours
9. Return encrypted payloads untouched (no server-side decryption)

**Performance Notes**:
- Index on `(owner_id, updated_at DESC)` for efficient owner queries
- Participant index optimization deferred to Phase 3

#### Response

**Success (200 OK)**:
```json
{
  "data": [
    {
      "id": "uuid-v4-string",
      "owner_id": "firebase-uid",
      "state": "active",
      "participant_count": 3,
      "created_at": "2025-11-18T14:30:00Z",
      "updated_at": "2025-11-18T14:35:00Z",
      "expires_at": "2025-11-25T14:30:00Z",
      "agent_mode": "manual",
      "agent_round": 0,
      "encrypted_blob_version": 1,
      "encrypted_payload": "base64-encoded-encrypted-blob",
      "last_message_preview": "Alice accepted the proposal",
      "last_actor_id": "firebase-uid-alice",
      "is_group": true
    }
  ],
  "pagination": {
    "next_cursor": "opaque_signed_token",
    "has_more": true
  }
}
```

**Response Structure**:
- `data`: Array of Negotiation resources (see `docs/01-data-model.md` for field definitions)
- `pagination.next_cursor`: Opaque cursor for fetching next page (null if no more results)
- `pagination.has_more`: Boolean indicating if additional results exist

**Empty Results**:
```json
{
  "data": [],
  "pagination": {
    "next_cursor": null,
    "has_more": false
  }
}
```

#### Error Codes

- `400 Bad Request`: Invalid query parameters (e.g., `limit` > 100, malformed `cursor`, invalid timestamp format, invalid enum values)
- `401 Unauthorized`: Missing or invalid Firebase token
- `403 Forbidden`: User attempts to access another user's negotiations (impersonation attempt)
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **Participant Authorization Index**: Secondary index mapping `(user_id, negotiation_id)` for efficient participant queries deferred to Phase 3
- **Full Filter Support**: Complete implementation of `state`, `agent_mode`, and timestamp filters deferred to Phase 3
- **Push Notification Markers**: Derived field `has_unread_updates` to indicate unseen state changes deferred to Phase 4+
- **Aggregation Optimizations**: Query performance tuning and caching strategies planned when dataset reaches 1M+ negotiations
- **Search Functionality**: Full-text search on `last_message_preview` or participant names deferred to Phase 5+
- **Sort Options**: Additional sort orders (e.g., by `created_at`, `expires_at`, `agent_round`) deferred to Phase 4+

### POST /events

#### Purpose

Creates a calendar Event derived from a finalized negotiation. For MVP, events are created **automatically** by the backend when a negotiation transitions to `finalized` state. This endpoint exists for testing, tooling, and manual event creation scenarios.

**Primary Use Case (Phase 3+)**: Backend automatically creates events when negotiations finalize.

**Secondary Use Case (MVP)**: Manual event creation via client for testing or emergency workflows.

**Encryption Boundary**: Backend does not decrypt negotiation payloads. Event details (time, venue, participants) come from client-provided encrypted blob.

#### Method & Path

```
POST /events
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **User Identity**: Extracted from token `sub` claim and set as `owner_id`
- **Authorization**: Only the negotiation owner may manually create an event
- **Forbidden (403)**: User attempts to create event for negotiation they do not own
- **Automated Creation (Phase 3+)**: Backend will bypass this endpoint and apply internal logic to create events automatically

#### Request Schema

**Required Fields**:
- `id` (UUID v4): Client-generated event identifier
- `negotiation_id` (UUID v4): ID of the finalized negotiation this event is derived from
- `encrypted_payload` (string): AES-256-GCM encrypted JSON blob containing event details (title, time, venue, participants, reminders)

**Optional Fields**:
- `timezone` (string): IANA timezone identifier (e.g., `Europe/Berlin`, `America/New_York`). Used for display and conflict detection.
- `expires_at` (ISO 8601 timestamp): Optional expiration timestamp for the event (e.g., for temporary meetups)

**Auto-Generated by Backend**:
- `owner_id`: Set from authenticated user's Firebase UID (client value ignored)
- `created_at`: Set to current UTC timestamp
- `updated_at`: Set to current UTC timestamp
- `encrypted_blob_version`: Set to 1 (current version)

**Validation Rules**:
- `id` must be a valid UUID v4
- `negotiation_id` must reference an existing negotiation
- Referenced negotiation must be in `finalized` state (return `409 Conflict` if not)
- Authenticated user must be the negotiation owner (return `403 Forbidden` if not)
- `encrypted_payload` must be non-empty valid base64 string
- `timezone` must be a valid IANA identifier if provided
- `expires_at` must be ≥ `created_at` if provided
- Reject invalid schema with `400 Bad Request` or `422 Unprocessable Entity`

#### Backend Behavior

**Validation & Authorization**:
1. Validate Firebase JWT signature and claims
2. Validate `id` is a well-formed UUID v4
3. Validate `negotiation_id` is a well-formed UUID v4
4. Fetch negotiation by `negotiation_id` (return `404 Not Found` if missing)
5. Verify negotiation state is `finalized` (return `409 Conflict` if not)
6. Verify authenticated user is negotiation owner (return `403 Forbidden` if not)
7. Validate `encrypted_payload` is non-empty
8. Validate `timezone` is valid IANA identifier if provided
9. Validate `expires_at` ≥ `created_at` if provided

**Event Creation Logic**:
- Populate event fields:
  - `id`: From request
  - `owner_id`: From authenticated user's UID (overwrite any client-provided value)
  - `negotiation_id`: From request
  - `encrypted_payload`: From request (stored as-is, no decryption)
  - `encrypted_blob_version`: Set to 1
  - `created_at`: Current UTC timestamp
  - `updated_at`: Current UTC timestamp
  - `timezone`: From request if provided
  - `expires_at`: From request if provided
- Store encrypted payload without decryption
- Insert event record into `events` table (PostgreSQL)
- Return created event with all fields including auto-generated values

**Idempotency**:
- Duplicate `id` rejected with `409 Conflict`
- Client should generate unique UUIDs for each event

#### Response

**Success (201 Created)**:
```json
{
  "data": {
    "id": "uuid-v4-string",
    "negotiation_id": "uuid-v4-string",
    "owner_id": "firebase-uid",
    "created_at": "2025-11-18T14:40:00Z",
    "updated_at": "2025-11-18T14:40:00Z",
    "encrypted_blob_version": 1,
    "encrypted_payload": "base64-encoded-encrypted-blob",
    "timezone": "Europe/Berlin",
    "expires_at": "2025-11-25T10:00:00Z"
  }
}
```

**Response Fields**:
Returns the canonical Event resource as defined in `docs/01-data-model.md`. All fields included.

#### Error Codes

- `400 Bad Request`: Malformed JSON, invalid UUID format, invalid timezone
- `401 Unauthorized`: Missing or invalid Firebase token
- `403 Forbidden`: User is not the negotiation owner
- `404 Not Found`: Negotiation with specified `negotiation_id` does not exist
- `409 Conflict`: Event with same `id` already exists, OR negotiation is not in `finalized` state
- `422 Unprocessable Entity`: Validation failed (e.g., `encrypted_payload` empty, `expires_at` < `created_at`)
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **Automatic Event Creation**: Backend will automatically create events when negotiations transition to `finalized` state (Phase 3 implementation). This endpoint will become secondary/manual-only.
- **Event Reminders**: APNs-based reminders for upcoming events scheduled for Phase 4+
- **Event Sharing**: Functionality to share events with non-Kairos users (e.g., export to ICS files) planned for Phase 5
- **Calendar Sync**: Integration with iOS EventKit for automatic calendar sync implemented client-side (not backend responsibility)
- **Event Updates**: `PATCH /events/:id` endpoint for modifying finalized events deferred to Phase 4+
- **Encryption Boundary**: Backend continues to store all event data encrypted end-to-end; no plaintext event details ever written to disk

### GET /events/:id

#### Purpose

Returns a single Event resource by ID. Used by the iOS app to refresh event details after receiving push notifications, navigating to event view, or syncing after offline mode. Backend returns event metadata and encrypted payload without decryption.

**Use Cases**:
- Refresh event details after push notification
- Display event details in calendar view
- Offline sync when app returns online
- Verify event state before modifications

**Authorization**: Only the event owner may access the event.

#### Method & Path

```
GET /events/:id
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **Actor Identity**: Extracted from token `sub` claim
- **Authorization**: Only the event owner (user whose UID matches `owner_id`) may access the event
- **Forbidden (403)**: User attempts to access an event they do not own
- **No Anonymous Access**: All requests require authenticated user

#### Path & Query Parameters

**Path Parameters**:
- `id` (UUID v4, required): Event identifier

**Query Parameters**:
- None for MVP

**Validation**:
- `id` must be a well-formed UUID v4 (return `400 Bad Request` if malformed)

#### Backend Behavior

**Request Processing**:
1. Validate Firebase JWT signature and claims
2. Validate `id` is a well-formed UUID v4 (return `400 Bad Request` if malformed)
3. Fetch event from database by `id` (return `404 Not Found` if missing)
4. Verify authorization:
   - Check if authenticated user's UID matches event's `owner_id`
   - Return `403 Forbidden` if user is not the owner
5. Return event resource with all fields

**Encryption Boundary**:
- Backend does **not** decrypt `encrypted_payload`
- Backend returns encrypted blob exactly as stored
- Client is responsible for decryption using event key

#### Response

**Success (200 OK)**:
```json
{
  "data": {
    "id": "uuid-v4-string",
    "negotiation_id": "uuid-v4-string",
    "owner_id": "firebase-uid",
    "created_at": "2025-11-18T14:40:00Z",
    "updated_at": "2025-11-18T14:40:00Z",
    "expires_at": "2025-11-25T10:00:00Z",
    "timezone": "Europe/Berlin",
    "encrypted_blob_version": 1,
    "encrypted_payload": "base64-encoded-encrypted-blob"
  }
}
```

**Response Fields**:
Returns the canonical Event resource as defined in `docs/01-data-model.md`. All fields included.

#### Error Codes

- `400 Bad Request`: Invalid UUID format for `id` parameter
- `401 Unauthorized`: Missing or invalid Firebase token
- `403 Forbidden`: User is not the event owner
- `404 Not Found`: Event with specified `id` does not exist
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **Denormalized Negotiation Preview**: Include lightweight negotiation metadata (state, participant count) in event response to reduce client-side queries (Phase 4+)
- **ICS Export**: Generate downloadable ICS file for calendar import deferred to Phase 5+
- **Sharing Tokens**: Generate shareable links for event details (with optional E2EE key sharing) deferred to Phase 5+
- **Event Updates API**: `PATCH /events/:id` endpoint for modifying events deferred to Phase 4+
- **Encryption Boundary**: Backend will always treat `encrypted_payload` as opaque; no plaintext event details ever exposed server-side

### GET /events

#### Purpose

Returns a paginated list of Events that belong to the authenticated user. This endpoint powers the iOS event history view, event list displays, event reminders, and offline sync functionality.

**Use Cases**:
- iOS event history view: display past and upcoming events
- Event list dashboard: show user's calendar events
- Offline sync: refresh event list when app returns online
- Event reminders: fetch events for notification scheduling

**Authorization**: Backend filters results to only include events where `owner_id` matches the authenticated user's UID. Never returns events belonging to other users.

#### Method & Path

```
GET /events
```

#### Authentication Requirements

- **Required**: Firebase ID Token (JWT) in `Authorization: Bearer <token>` header
- **User Identity**: Extracted from token `sub` claim
- **Authorization**: Backend returns only events where `owner_id` matches authenticated UID
- **Forbidden (403)**: User attempts to access another user's events
- **No Anonymous Access**: All requests require authenticated user

#### Query Parameters

All query parameters are optional:

**Pagination**:
- `limit` (integer, optional): Maximum number of items to return. Default: 50, Maximum: 100.
- `cursor` (string, optional): Opaque pagination cursor from previous response. Used to fetch next page.

**Filters** (optional for MVP, full support in Phase 3):
- `timezone` (string, optional): Filter by IANA timezone identifier (e.g., `Europe/Berlin`, `America/New_York`).
- `updated_after` (ISO 8601 timestamp, optional): Return only events updated after this timestamp.
- `updated_before` (ISO 8601 timestamp, optional): Return only events updated before this timestamp.

**Note**: Events do not have a state machine (unlike Negotiations), so state filters are not applicable.

#### Backend Behavior

**Request Processing**:
1. Validate Firebase JWT signature and claims
2. Parse and validate pagination parameters (`limit`, `cursor`)
3. Validate optional filters:
   - `timezone` must be a valid IANA timezone identifier if provided
   - `updated_after` and `updated_before` must be valid ISO 8601 timestamps if provided
4. Query events where `owner_id` = authenticated user's UID
5. Apply optional filters:
   - Timezone filter: `WHERE timezone = ?`
   - Timestamp range: `WHERE updated_at BETWEEN ? AND ?`
6. Sort results by `updated_at DESC` (most recent first)
7. Apply pagination:
   - Limit results to `limit` items
   - If `cursor` provided, start from cursor position
8. Generate `next_cursor`:
   - Opaque signed token containing last item's ordering key
   - Expires after 24 hours
9. Return encrypted payloads untouched (no server-side decryption)

**Performance Notes**:
- Index on `(owner_id, updated_at DESC)` for efficient owner queries
- Additional indexes for timezone filtering deferred to Phase 3

#### Response

**Success (200 OK)**:
```json
{
  "data": [
    {
      "id": "uuid-v4-string",
      "negotiation_id": "uuid-v4-string",
      "owner_id": "firebase-uid",
      "created_at": "2025-11-18T14:40:00Z",
      "updated_at": "2025-11-18T14:40:00Z",
      "expires_at": "2025-11-25T10:00:00Z",
      "timezone": "Europe/Berlin",
      "encrypted_blob_version": 1,
      "encrypted_payload": "base64-encoded-encrypted-blob"
    }
  ],
  "pagination": {
    "next_cursor": "opaque_signed_token",
    "has_more": true
  }
}
```

**Response Structure**:
- `data`: Array of Event resources (see `docs/01-data-model.md` for field definitions)
- `pagination.next_cursor`: Opaque cursor for fetching next page (null if no more results)
- `pagination.has_more`: Boolean indicating if additional results exist

**Empty Results**:
```json
{
  "data": [],
  "pagination": {
    "next_cursor": null,
    "has_more": false
  }
}
```

#### Error Codes

- `400 Bad Request`: Invalid query parameters (e.g., `limit` > 100, malformed `cursor`, invalid timezone format, invalid timestamp format)
- `401 Unauthorized`: Missing or invalid Firebase token
- `403 Forbidden`: User attempts to access another user's events
- `500 Internal Server Error`: Database failure or unexpected error

#### Future Notes

- **Full Filter Support**: Complete implementation of `timezone` and timestamp filters deferred to Phase 3
- **Reminder Status**: Derived field `reminder_status` to indicate upcoming event reminders deferred to Phase 4+
- **Unread Updates**: Field `has_unread_updates` to track event modifications since last view deferred to Phase 4+
- **ICS Export**: Bulk export of event list to ICS format for external calendar import deferred to Phase 5
- **Sort Options**: Additional sort orders (e.g., by `created_at`, `expires_at`) deferred to Phase 4+
- **Search Functionality**: Full-text search on event titles or descriptions deferred to Phase 5+ (requires client-side decryption)
- **Encryption Boundary**: Backend never decrypts `encrypted_payload`; all event details remain opaque server-side

## Error Format

All API errors follow a canonical error envelope structure. Errors are always returned as JSON with appropriate HTTP status codes and deterministic error codes for client-side handling.

### Global Error Envelope Specification

**Canonical Structure**:
```json
{
  "error": {
    "code": "string_identifier",
    "message": "Human-readable explanation",
    "details": {}
  }
}
```

**Field Definitions**:
- `error.code` (string, required): Machine-readable error identifier in `snake_case` format
- `error.message` (string, required): Human-readable error description for developers/logs
- `error.details` (object, optional): Additional context about the error (field-level validation failures, etc.)

**Constraints**:
- No additional top-level fields allowed
- `details` object is optional and may be omitted for simple errors
- All errors must follow this structure regardless of HTTP status code

### Error Code Naming Convention

Error codes use stable, deterministic identifiers to enable backward-compatible client logic.

**Format Rules**:
- Use `snake_case` format exclusively
- Error codes must be deterministic and never change once released
- New error codes may be added in future versions without breaking compatibility
- Error codes must not leak encrypted payload content or sensitive implementation details

**Canonical Error Codes**:
- `invalid_token`: JWT signature verification failed or claims are invalid
- `expired_token`: JWT `exp` claim is in the past; client must refresh token
- `unauthorized`: No `Authorization` header provided or token extraction failed
- `forbidden`: Valid token but user lacks permission for requested resource
- `validation_failed`: Request schema validation failed (generic)
- `invalid_uuid`: UUID format validation failed
- `invalid_enum`: Enum field contains value not in allowed set
- `missing_field`: Required field not provided in request
- `state_conflict`: Resource state does not allow requested operation
- `not_found`: Resource with specified identifier does not exist
- `conflict`: Duplicate resource identifier or concurrent modification conflict
- `internal_error`: Unexpected server-side error (database failure, etc.)

### Mapping to HTTP Status Codes

| error.code          | HTTP Status | Description                                          |
|---------------------|-------------|------------------------------------------------------|
| `invalid_token`     | 401         | JWT signature verification failed                    |
| `expired_token`     | 401         | JWT expiration time (`exp`) exceeded                 |
| `unauthorized`      | 401         | No authentication credentials provided               |
| `forbidden`         | 403         | Authenticated but lacks permission                   |
| `not_found`         | 404         | Resource does not exist                              |
| `conflict`          | 409         | Duplicate identifier or resource already exists      |
| `state_conflict`    | 409         | Invalid state transition or operation not allowed    |
| `validation_failed` | 422         | Request validation failed (generic)                  |
| `invalid_uuid`      | 400         | Malformed UUID format                                |
| `invalid_enum`      | 400         | Enum field contains invalid value                    |
| `missing_field`     | 400         | Required field not provided                          |
| `internal_error`    | 500         | Unexpected server error                              |

### Rules for `details` Object

The optional `details` object provides additional context for errors, particularly validation failures.

**Allowed Fields**:
- `field` (string): Name of the field that failed validation (e.g., `participant_count`, `expires_at`)
- `expected` (string): Expected format, type, or constraint (e.g., `"UUID v4"`, `">= 2"`, `"ISO 8601 timestamp"`)
- `received` (any): Actual value received (sanitized; never include decrypted content)
- `reason` (string): Backend-safe explanation of why validation failed

**Example (Validation Error)**:
```json
{
  "error": {
    "code": "validation_failed",
    "message": "Participant count must be at least 2",
    "details": {
      "field": "participant_count",
      "expected": ">= 2",
      "received": 1,
      "reason": "Negotiations require at least two participants (owner + one other)"
    }
  }
}
```

**Example (Invalid UUID)**:
```json
{
  "error": {
    "code": "invalid_uuid",
    "message": "Negotiation ID must be a valid UUID v4",
    "details": {
      "field": "negotiation_id",
      "expected": "UUID v4 format",
      "received": "not-a-uuid",
      "reason": "Malformed UUID format"
    }
  }
}
```

**Security Constraints**:
- Backend **must never** include decrypted negotiation or event data in error messages
- Backend **must never** leak encrypted payload content (even partially)
- `details` object **must** remain metadata-only (field names, types, constraints)
- Server logs may contain deeper debugging information, but error envelope must remain minimal and safe

### Backend Behavior Requirements

**JSON-Only Responses**:
- Backend must **always** return error responses as `application/json`
- Never return HTML error pages or plaintext error messages
- Set `Content-Type: application/json` header on all error responses

**Canonical Envelope**:
- All errors must be wrapped in the canonical error envelope
- No bare error strings or non-standard formats allowed
- Maintain consistency across all endpoints and error scenarios

**HTTP Status Codes**:
- Always set appropriate HTTP status code matching error category
- Include canonical `error.code` for client-side logic

**Encryption Boundary**:
- Never decrypt `encrypted_payload` or `counter_payload` for error messages
- Never include encrypted blob content in error responses
- Field names and metadata are safe; payload content is not

**Logging**:
- Server logs may contain deeper error details (stack traces, SQL errors, etc.)
- Error envelope sent to client must remain minimal and safe
- Never log decrypted payload content (encryption boundary applies to logs)

### Client Responsibilities

**Error Code Logic**:
- Rely on `error.code` for programmatic handling, not HTTP status codes
- HTTP status codes may map to multiple error codes (e.g., 401 → `invalid_token` or `expired_token`)
- Use `error.code` to determine retry strategy, user messaging, and recovery actions

**Token Refresh Handling**:
- Handle `invalid_token` and `expired_token` by refreshing Firebase ID token
- Retry original request after token refresh
- If refresh fails, prompt user to re-authenticate

**Retryable Errors**:
- Treat all `5xx` errors as retryable after exponential backoff
- `internal_error` should trigger automatic retry (up to 3 attempts)
- Do not retry `4xx` errors except `401` (after token refresh)

**User Messaging**:
- Show human-friendly message derived from `error.message` or custom copy
- Never expose raw `error.code` to end users
- Use localized error messages based on `error.code` (client-side translation)

**Forward Compatibility**:
- Never assume structure beyond documented contract
- Gracefully handle new error codes by treating as generic errors
- Do not hard-code error code lists; use fallback logic for unknown codes

### Future-Proofing Notes

**Error Code Versioning**:
- Error codes are stable across API versions (v1, v2, etc.)
- New error codes may be added without breaking compatibility
- Existing error codes will never be removed or renamed (deprecated codes may be aliased)
- Clients should implement fallback logic for unrecognized error codes

**Localization**:
- Future API versions may support localized `error.message` via `Accept-Language` header
- Localization deferred to Phase 4+
- Clients should maintain their own localized error message mappings based on `error.code`

**Additional Categories**:
- New error code categories may be introduced in Phase 4+ (e.g., rate limiting, quota exceeded)
- Error envelope structure will remain backward-compatible
- `details` object may include new optional fields without breaking existing clients

**Backward Compatibility**:
- Error envelope structure is part of the public API contract and must remain stable
- Any breaking changes to error format will trigger API version bump (v1 → v2)
- MVP (v1) error format is final and frozen for production use

## Notes on E2EE Payload Handling

### Purpose

This section documents how the backend treats all encrypted blobs in Kairos Amiqo (negotiations and events). It defines the **contract boundary** for end-to-end encryption (E2EE) in the system.

**Key Principles**:
- Backend treats encrypted payloads as opaque binary data
- All semantic interpretation of encrypted content happens client-side
- Backend never decrypts, inspects, or transforms encrypted blobs
- E2EE is a client-side responsibility; backend is untrusted

### Encrypted Fields

The following fields contain encrypted payloads and are treated as opaque by the backend:

**Negotiation Resources**:
- `Negotiation.encrypted_payload`: Contains event details, participant list, proposed slots, proposed venues, preferences

**Negotiation Reply Endpoint**:
- `POST /negotiate/reply` request body:
  - `encrypted_payload`: Updated participant statuses and preferences
  - `counter_payload`: Modified proposed slots/venues (conditional; required only when `action` is `counter`)

**Event Resources**:
- `Event.encrypted_payload`: Contains event title, description, venue details, participant identities, notes, reminders

**Backend Perspective**:
- All these fields are **base64-encoded opaque blobs**
- Backend never inspects or partially parses JSON inside encrypted payloads
- Backend stores and returns blobs exactly as provided

### Cryptographic Expectations (Client-Side)

The client (iOS app) is responsible for all cryptographic operations. The following describes the semantic contract for how encrypted payloads are produced and consumed.

**Encryption Scheme**:
- Payloads are encrypted client-side using an Authenticated Encryption with Associated Data (AEAD) scheme (e.g., AES-256-GCM via CryptoKit)
- Each negotiation/event uses a **content encryption key (CEK)** that never leaves the client's secure storage
- A fresh nonce/IV is required per encryption operation to ensure semantic security

**Key Management (Client-Side)**:
- Clients generate CEKs locally using secure random number generation
- Keys are stored in device secure storage (iOS Keychain, Secure Enclave where available)
- Backend does not manage keys, nonces, or key rotation
- Key sharing between participants (for group negotiations) handled client-side via out-of-band mechanisms (deferred to Phase 5+)

**Payload Structure (Client-Side)**:
- Clients must include all necessary metadata for decryption (version, nonce, authentication tag) either:
  - Embedded within the encrypted blob itself, OR
  - Stored separately in client-side secure storage
- Backend does not enforce or validate cryptographic metadata

**Semantic Guarantees**:
- These are **client-side implementation expectations**, not backend-enforced rules
- Backend validates only that blobs are non-empty strings; cryptographic correctness is client responsibility

### Encrypted Blob Versioning

The `encrypted_blob_version` field enables forward compatibility for encrypted payload formats.

**Purpose**:
- Integer version field indicating the encryption scheme and payload structure version
- Used by clients to determine how to interpret and decrypt stored payloads
- Enables future migration to new encryption algorithms or payload formats

**Backend Behavior**:
- Backend stores `encrypted_blob_version` as a simple integer field
- Backend never attempts to "understand" or validate the blob format based on version
- Backend does not perform version-specific validation or transformation

**Current Version**:
- **MVP (Phase 1-3)**: `encrypted_blob_version = 1` is the only supported value
- Version 1 implies: AES-256-GCM encryption with client-managed keys

**Future Versions**:
- Version 2, 3, etc. may introduce:
  - New encryption algorithms (e.g., ChaCha20-Poly1305)
  - Different payload structures (e.g., protobuf instead of JSON)
  - Key derivation changes
- Backend remains agnostic; clients handle version-specific logic
- Older clients may refuse to process newer versions (client-side decision)

### Backend Responsibilities

**Backend MUST**:
- Store encrypted payloads exactly as provided (byte-for-byte fidelity)
- Return encrypted payloads exactly as stored (no modification, re-encoding, or transformation)
- Treat payloads as opaque binary data (base64-encoded strings in JSON)
- Validate only:
  - **Presence**: Check if required fields are provided
  - **Type**: Verify field is a string
  - **Size**: Enforce maximum payload size limits (see below)

**Backend MUST NOT**:
- Decrypt negotiation or event encrypted payloads under any circumstances
- Parse, partially inspect, or attempt to understand encrypted contents
- Derive, generate, or store encryption keys, IVs, nonces, or salts
- Log decrypted data (logs may contain encrypted blobs, but never plaintext)
- Transform encrypted payloads (e.g., re-encrypt, compress, or normalize)

**Size Limits**:
- For MVP, backend enforces a maximum encrypted payload size of **16 KB per blob**
- This limit protects storage and performance but is a backend configuration detail
- Clients should not rely on exact size limits; future versions may adjust
- Payloads exceeding limit rejected with `422 Unprocessable Entity` and `validation_failed` error code

### Client Responsibilities

**Key Management**:
- Generate and manage encryption keys per negotiation/event
- Securely store keys on-device using iOS Keychain or Secure Enclave
- Handle key backup/recovery strategies client-side (e.g., iCloud Keychain with user opt-in)
- Ensure shared keys for group negotiations never traverse the backend

**Encryption/Decryption**:
- Perform all encryption operations locally before sending to backend
- Perform all decryption operations locally after receiving from backend
- Use secure cryptographic libraries (e.g., Apple CryptoKit)
- Generate fresh nonces/IVs for each encryption operation

**Error Handling**:
- Handle decryption failures gracefully (corrupted blobs, wrong keys, version mismatches)
- Backend cannot assist with decryption failures; treat as unrecoverable data loss
- Implement client-side validation before encryption (e.g., check payload size, structure)

**Data Loss Scenarios**:
- If clients lose encryption keys, backend **cannot** recover plaintext
- Backend cannot "fix" corrupted encrypted blobs
- Clients should implement key backup strategies (e.g., secure cloud backup with user consent)

### Error Handling Boundary

Backend validation of encrypted fields is strictly limited to structural checks. Cryptographic validation is a client-side concern.

**Backend Validation** (API-level):
- Check if required encrypted fields are present
- Check if encrypted fields are non-empty strings
- Optionally check approximate length (enforce size limits)

**Backend Does NOT Validate**:
- Cryptographic correctness (MAC/authentication tag validity)
- Encryption algorithm used
- Key derivation or nonce uniqueness
- Payload structure after decryption

**Client-Side Decryption Failures**:
- If a blob fails client-side decryption, this is a **client-side error**
- Backend successfully stored and returned the blob; API semantics are successful
- Client app may surface its own errors (e.g., "Unable to decrypt event details")
- Backend is unaware of decryption failures

**Example Scenario**:
1. Client sends `POST /negotiate/start` with encrypted payload
2. Backend validates payload is non-empty string, stores it, returns `201 Created`
3. Client later fetches negotiation with `GET /negotiations/:id`
4. Backend returns encrypted payload exactly as stored
5. Client attempts decryption and fails (wrong key, corrupted data, version mismatch)
6. From backend's perspective: API succeeded (stored and retrieved blob successfully)
7. From client's perspective: Decryption failed (client-side error handling required)

### Future Work (Phase 4+)

The current E2EE architecture is designed to support future enhancements without breaking changes:

**Multi-Device Key Sync** (Phase 5+):
- Synchronize encryption keys across user's devices using secure cloud backup
- Possible integration with iCloud Keychain or custom key escrow service
- Backend remains uninvolved; keys never sent to backend

**Group Key Management** (Phase 5+):
- Scalable key distribution for multi-participant negotiations (10+ participants)
- Possible adoption of Signal Protocol double ratchet or similar
- Backend may relay encrypted key exchange messages but never accesses keys

**Key Rotation Policies** (Phase 5+):
- Periodic key rotation for long-lived negotiations
- Forward secrecy guarantees (compromise of current key does not reveal past messages)
- Backward compatibility with older encrypted payloads

**Encrypted Search/Indexing** (Phase 6+):
- Client-side preprocessing to enable server-side search without decryption
- Techniques: searchable encryption, encrypted bloom filters, encrypted indexes
- Backend stores encrypted indexes but cannot interpret search terms

**E2EE-Backed Sharing Links** (Phase 6+):
- Generate shareable links for events/negotiations that carry keys out-of-band
- Possible QR code or deep link mechanisms
- Backend stores encrypted content; keys transmitted separately via link fragment

**No MVP Impact**:
- None of these features are in scope for MVP (Phase 1-3)
- Current API surface is designed not to block these enhancements
- `encrypted_blob_version` field enables migration to new schemes

## Status

**Document Status**: Draft (Phase 2)  
**Last Updated**: 2025-11-18  
**Canonical**: Yes  
**Implementation Status**: Specification complete, implementation pending Phase 3

### Completion Summary

This document defines the complete API contract for Kairos Amiqo MVP (Phase 1-3). All core endpoints have been specified:

**Negotiation Endpoints**:
- `POST /negotiate/start`: Create new negotiation
- `POST /negotiate/reply`: Submit participant reply (accept/decline/counter)
- `GET /negotiations/:id`: Fetch single negotiation by ID
- `GET /negotiations`: List negotiations (paginated)

**Event Endpoints**:
- `POST /events`: Create event from finalized negotiation
- `GET /events/:id`: Fetch single event by ID
- `GET /events`: List events (paginated)

**Cross-Cutting Specifications**:
- API Conventions (content type, envelopes, timestamps, UUIDs, pagination, versioning)
- Authentication (Firebase ID Token validation)
- Error Format (canonical error envelope, error codes, HTTP status mapping)
- E2EE Payload Handling (encryption boundary, backend/client responsibilities)

### Architecture Alignment

This specification is fully aligned with the new Kairos Amiqo architecture:
- **Backend**: Node.js + Fastify + PostgreSQL
- **Authentication**: Firebase Authentication (JWT tokens)
- **Encryption**: End-to-end encryption (AES-256-GCM) with client-side key management
- **No Legacy Systems**: All references to Directus, Node-RED, and mock-server have been removed

### Next Steps

**Phase 2 Continuation**:
- **P2.S2.T1**: Backend Implementation Guidelines (Fastify project structure, middleware, error handling patterns)
- **P2.S2.T2**: Backend Architecture Document (PostgreSQL schema, indexes, migration strategy)

**Phase 3 Implementation**:
- Backend API implementation using this specification as canonical reference
- Database schema implementation per `docs/01-data-model.md`
- Firebase Authentication integration
- Automated testing against contract specifications

### Document Freeze

**This document is now frozen for Phase 2; backend implementation begins in Phase 3.**

All changes to API contracts after this point require:
1. Architecture review and approval
2. Version bump if breaking changes introduced
3. Update to this canonical specification document
4. Coordination with iOS client implementation

For questions or clarifications, refer to:
- `docs/00-architecture-overview.md` for system design context
- `docs/01-data-model.md` for data structure definitions
- `tracking/TRACKING.md` for implementation roadmap and task dependencies

