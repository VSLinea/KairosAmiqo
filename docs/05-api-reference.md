---
status: draft
phase: 2
document_id: P2.S2
canonical: true
type: api-reference
last_reviewed: 2025-11-19
owner: amiqlab
related:
  - /docs/00-architecture-overview.md
  - /docs/01-data-model.md
  - /docs/02-api-contracts.md
  - /docs/03-backend-structure.md
  - /docs/04-database-schema.md
  - /tracking/TRACKING.md
---

# Kairos Amiqo — API Reference (Draft)

This document provides the **canonical backend API reference** for the Kairos Amiqo service.

It is separate from, but aligned with:

- `02-api-contracts.md` — canonical rules, validation, and semantics  
- `03-backend-structure.md` — backend architecture and module layout  
- `04-database-schema.md` — PostgreSQL schema  

## 1. Overview

This document is the **developer-facing API reference** for the Kairos Amiqo backend service. It provides concrete endpoint specifications, request/response examples, and error codes for engineers implementing or consuming the API.

This reference **complements** but does not replace `02-api-contracts.md`, which defines the canonical rules, validation logic, and semantic contracts. Where `02-api-contracts.md` focuses on **what the API must enforce**, this document focuses on **how to call the API** in practice.

**API Coverage:**

- **Negotiation endpoints**: Create invitations, send replies, list active/past negotiations, fetch negotiation details
- **Event endpoints**: Query upcoming events, fetch event details, future event creation (Phase 4+)
- **User endpoints**: Fetch current user profile, update profile settings (Phase 4+)
- **Utility endpoints**: Health checks, version info, schema compatibility

**Primary Client:** The iOS app is the primary consumer of this API in Phase 3. Future Android and web clients will reuse the same endpoints without modification.

**Key Constraints:**

- All endpoints except `/health` and `/version` require **Firebase JWT authentication**
- All responses use the **canonical envelope format** (success: `{ data, meta }`, error: `{ error }`)
- **E2EE boundaries**: The backend operates on metadata only; encrypted message payloads are opaque blobs never decrypted server-side
- **Rate limiting**: Per-user and global rate limits enforced; violations return `429` with error details

## 2. Authentication & Headers (Recap)

### Firebase JWT Authentication

All protected endpoints require a valid Firebase ID token in the `Authorization` header:

```
Authorization: Bearer <firebase_id_token>
```

**Backend Validation:**

The Fastify backend validates each JWT by:

1. Verifying signature using Firebase JWKS (public keys cached, refreshed periodically)
2. Checking `exp` (expiration) and `iat` (issued-at) timestamps
3. Validating `aud` (audience) and `iss` (issuer) match the expected Firebase project
4. Extracting `sub` (subject) as the canonical user identifier

**No cookies, no sessions.** Authentication is stateless and token-based.

### Standard Headers

**Request Headers:**

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes (protected endpoints) | `Bearer <firebase_id_token>` |
| `Content-Type` | Yes (POST/PUT) | `application/json; charset=utf-8` |
| `X-Request-Id` | Optional | Client-supplied correlation ID for tracing |

**Response Headers:**

| Header | Always Present | Description |
|--------|----------------|-------------|
| `Content-Type` | Yes | `application/json; charset=utf-8` |
| `X-Request-Id` | Yes | Echoes client ID or server-generated UUID |

### Public vs Protected Endpoints

**Public (no auth required):**
- `GET /health`
- `GET /version`

**Protected (JWT required):**
- All `/negotiate/*` endpoints
- All `/events/*` endpoints
- All `/users/*` endpoints

### Rate Limiting

The backend enforces two levels of rate limiting:

1. **Global rate limit**: Protects against traffic spikes (e.g., 1000 req/min)
2. **Per-user rate limit**: Prevents abuse by individual users (e.g., 60 req/min per `user_id`)

**Rate limit exceeded:**
- HTTP Status: `429 Too Many Requests`
- Response body: Canonical error envelope with `code: "RATE_LIMIT_EXCEEDED"`
- `Retry-After` header indicates seconds until limit resets (value in seconds)

See Section 8.5 for detailed rate limit error responses and handling strategies.

## 3. Global Request & Response Conventions

### Content Type

All requests and responses use:

```
Content-Type: application/json; charset=utf-8
```

**No exceptions:** No form-encoded, multipart, or XML payloads are supported.

### Request Body Format

**POST and PUT endpoints:**

- Request bodies MUST be valid JSON objects
- No top-level wrappers beyond what the endpoint specifies (e.g., `{ "title": "Coffee chat", ... }`)
- All date/time fields use **UTC ISO-8601 format**: `2025-11-18T10:00:00Z`
- UUIDs use lowercase hyphenated format: `550e8400-e29b-41d4-a716-446655440000`

**GET endpoints:**

- Query parameters for filtering/pagination (e.g., `?state=awaiting_replies&limit=20`)
- No request body

### Response Envelope

All responses follow the canonical envelope format defined in `02-api-contracts.md`:

**Successful Response:**

```json
{
  "data": { /* object or array */ },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2025-11-18T10:00:00Z",
    /* optional pagination, counts, etc. */
  }
}
```

**Error Response:**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid negotiation state transition",
    "details": {
      "field": "state",
      "current": "accepted",
      "requested": "awaiting_replies"
    }
  }
}
```

**Notes:**

- The `meta` object in successful responses is optional; it always includes `request_id` and `timestamp` when present
- The `details` object in error responses provides context-specific debugging information
- See Section 8 for complete error reference

### HTTP Status Codes

| Status | Meaning | Use Cases |
|--------|---------|----------|
| `200` | OK | Successful GET, PUT |
| `201` | Created | Successful POST (e.g., new negotiation) |
| `400` | Bad Request | Validation errors, malformed JSON |
| `401` | Unauthorized | Missing or invalid JWT |
| `403` | Forbidden | Valid JWT but insufficient permissions |
| `404` | Not Found | Resource does not exist |
| `409` | Conflict | Invalid state transition, duplicate constraint |
| `429` | Too Many Requests | Rate limit exceeded |
| `500` | Internal Server Error | Unexpected backend failure |

**Error responses always include the canonical error envelope.**

### Idempotency & Retries

**Safe/Idempotent Operations:**

- All `GET` endpoints are safe and idempotent
- Clients can retry freely without side effects

**Non-Idempotent Operations:**

- `POST /negotiate/start`: Creates a new negotiation row; retries create duplicates
- `POST /negotiate/reply`: Updates participant status; duplicate replies may cause `409` conflicts

**Retry Guidance:**

- For `POST` endpoints, clients should:
  1. Check response status before retrying
  2. Use exponential backoff for `500`/`503` errors
  3. Do **not** retry `400`/`404`/`409` errors (client must fix request)
- Use `X-Request-Id` header to correlate requests/responses for debugging

### E2EE Boundaries

**Backend Metadata-Only Storage:**

The Kairos Amiqo backend **never decrypts user content**. All encrypted payloads are treated as opaque strings/blobs.

**What the backend sees:**

- Negotiation metadata: state, intent category, participant IDs, timestamps
- Proposed slots: start times, durations (plaintext for scheduling logic)
- Proposed venues: names, provider IDs (plaintext for location matching)
- Event metadata: status, timestamps, owner

**What the backend does NOT see:**

- User messages between participants
- Detailed venue descriptions or notes
- Personal preferences or context shared privately

**Encrypted Payload Handling:**

- Fields like `message_ciphertext` (future) are stored as-is without validation
- Backend logic operates only on metadata fields
- Decryption happens client-side using CryptoKit (iOS) or equivalent

This design ensures **zero-knowledge privacy**: even with full database access, the backend cannot reconstruct private conversations.

## 4. Negotiation Endpoints

### 4.1 POST /negotiate/start

**Summary**

Creates a new negotiation (invitation) with proposed slots and venues. The authenticated user becomes the organizer and owner of the negotiation. This endpoint is called when the iOS client creates a new invitation from the dashboard or Amiqo conversation view.

The backend creates rows in the `negotiations`, `participants`, `proposed_slots`, and `proposed_venues` tables atomically. The initial state is always `awaiting_invites`, meaning the organizer is still drafting and has not yet sent invitations to other participants.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `POST` |
| **Path** | `/negotiate/start` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Extracts `owner` from the Firebase JWT `sub` claim (client-supplied `owner` is ignored)
2. Creates a new `negotiations` row with `state = 'awaiting_invites'`
3. Creates `participants` rows for the organizer (with `status = 'organizer'`) and all invited users (with `status = 'invited'`)
4. Creates `proposed_slots` rows with sequential `slot_index` values
5. Creates `proposed_venues` rows with sequential `venue_index` values
6. Returns the full negotiation metadata in the canonical envelope

**E2EE Boundaries:** The backend stores only metadata (participant IDs, slot times, venue names). Any encrypted message payloads (future feature) are stored as-is without decryption or validation.

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `Content-Type` | Yes | `application/json; charset=utf-8` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | `string` | No | Negotiation title (default: `"Untitled invitation"`) |
| `intent_category` | `string` | Yes | One of: `coffee`, `lunch`, `dinner`, `drinks`, `gym`, `walk`, `movie`, `concert`, `study`, `game`, `brunch` |
| `participant_ids` | `string[]` | Yes | Array of Firebase user IDs to invite (must include organizer, min 2 total) |
| `proposed_slots` | `object[]` | Yes | Array of time slot options (min 1, max 10) |
| `proposed_slots[].starts_at` | `string` | Yes | UTC ISO-8601 timestamp (future time required) |
| `proposed_slots[].duration_minutes` | `number` | No | Duration in minutes (default: 60) |
| `proposed_venues` | `object[]` | Yes | Array of venue options (min 1, max 10) |
| `proposed_venues[].name` | `string` | Yes | Venue name (non-empty) |
| `proposed_venues[].provider_id` | `string` | No | External provider ID (e.g., Google Place ID) |
| `proposed_venues[].metadata` | `object` | No | Additional venue metadata (coordinates, address, etc.) |
| `agent_mode` | `boolean` | No | Whether AI agent assistance is enabled (default: `false`) |

**Example Request:**

```json
{
  "title": "Coffee catch-up",
  "intent_category": "coffee",
  "participant_ids": [
    "firebase-uid-organizer",
    "firebase-uid-friend1",
    "firebase-uid-friend2"
  ],
  "proposed_slots": [
    {
      "starts_at": "2025-11-20T10:00:00Z",
      "duration_minutes": 30
    },
    {
      "starts_at": "2025-11-20T14:00:00Z",
      "duration_minutes": 30
    }
  ],
  "proposed_venues": [
    {
      "name": "Blue Bottle Coffee",
      "provider_id": "google-place-123",
      "metadata": {
        "lat": 37.7749,
        "lon": -122.4194
      }
    },
    {
      "name": "Ritual Coffee Roasters",
      "provider_id": "google-place-456"
    }
  ],
  "agent_mode": true
}
```

**Successful Response**

**Status:** `201 Created`

**Body:**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "owner": "firebase-uid-organizer",
    "title": "Coffee catch-up",
    "state": "awaiting_invites",
    "intent_category": "coffee",
    "participants": [
      {
        "id": "participant-uuid-1",
        "user_id": "firebase-uid-organizer",
        "status": "organizer",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "participant-uuid-2",
        "user_id": "firebase-uid-friend1",
        "status": "invited",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "participant-uuid-3",
        "user_id": "firebase-uid-friend2",
        "status": "invited",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "proposed_slots": [
      {
        "id": "slot-uuid-1",
        "slot_index": 0,
        "starts_at": "2025-11-20T10:00:00Z",
        "duration_minutes": 30,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "slot-uuid-2",
        "slot_index": 1,
        "starts_at": "2025-11-20T14:00:00Z",
        "duration_minutes": 30,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "proposed_venues": [
      {
        "id": "venue-uuid-1",
        "venue_index": 0,
        "name": "Blue Bottle Coffee",
        "provider_id": "google-place-123",
        "metadata": {
          "lat": 37.7749,
          "lon": -122.4194
        },
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "venue-uuid-2",
        "venue_index": 1,
        "name": "Ritual Coffee Roasters",
        "provider_id": "google-place-456",
        "metadata": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "agent_mode": true,
    "agent_round": 0,
    "created_at": "2025-11-18T10:00:00Z",
    "updated_at": "2025-11-18T10:00:00Z",
    "expires_at": "2025-11-25T10:00:00Z"
  },
  "meta": {
    "request_id": "req-uuid-123",
    "timestamp": "2025-11-18T10:00:00Z"
  }
}
```

**Error Responses**

**400 Bad Request** — Validation error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid intent_category value",
    "details": {
      "field": "intent_category",
      "value": "invalid-category",
      "allowed": ["coffee", "lunch", "dinner", "drinks", "gym", "walk", "movie", "concert", "study", "game", "brunch"]
    }
  }
}
```

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-123"
    }
  }
}
```

**Notes**

- **Owner extraction:** The `owner` field is always set to the Firebase JWT `sub` claim. Client-supplied `owner` values are ignored for security.
- **Organizer participant:** The backend automatically ensures the organizer is included in `participants` with `status = 'organizer'`.
- **Minimum participants:** At least 2 participants required (organizer + 1 invitee).
- **Slot/venue limits:** Maximum 10 slots and 10 venues per negotiation.
- **Default title:** If `title` is omitted or empty, backend uses `"Untitled invitation"`.
- **Snapshot fields:** The `proposed_slots_json` and `proposed_venues_json` columns in the database are populated as convenience snapshots; normalized tables are the source of truth. Snapshot JSON fields are never returned by any API endpoint.
- **Expiration:** Backend sets `expires_at` to 7 days from creation by default.

---

### 4.2 POST /negotiate/reply

**Summary**

Sends a reply to an existing negotiation (invitation). Participants can accept, decline, or counter-propose with alternative slots/venues. This endpoint is called when iOS users respond to invitations from the Active Invitations list or push notifications.

The backend updates the `participants` table (status change) and may transition the negotiation state (e.g., `awaiting_invites → awaiting_replies` or `awaiting_replies → accepted`). Counter-proposals append new slots/venues to the normalized tables.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `POST` |
| **Path** | `/negotiate/reply` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Validates the actor is a participant in the negotiation
2. Checks the current negotiation state allows replies
3. Updates the participant's status based on the action (`accept`, `decline`, `counter`)
4. Transitions negotiation state if all participants have responded
5. Appends counter-proposed slots/venues to normalized tables if action is `counter`
6. Returns the updated negotiation metadata

**State Transitions:**

| Current State | Action | Conditions | New State |
|---------------|--------|------------|-----------|
| `awaiting_invites` | `accept` | Organizer finalizes | `awaiting_replies` |
| `awaiting_replies` | `accept` | All accepted | `accepted` |
| `awaiting_replies` | `decline` | Any decline | `cancelled` |
| `awaiting_replies` | `counter` | Counter-proposal | `awaiting_replies` (round increments) |

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `Content-Type` | Yes | `application/json; charset=utf-8` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `negotiation_id` | `string` | Yes | UUID of the negotiation to reply to |
| `action` | `string` | Yes | One of: `accept`, `decline`, `counter` |
| `counter_slots` | `object[]` | Conditional | Required if `action = 'counter'` (min 1, max 10) |
| `counter_slots[].starts_at` | `string` | Yes | UTC ISO-8601 timestamp (future time required) |
| `counter_slots[].duration_minutes` | `number` | No | Duration in minutes (default: 60) |
| `counter_venues` | `object[]` | Conditional | Required if `action = 'counter'` (min 1, max 10) |
| `counter_venues[].name` | `string` | Yes | Venue name (non-empty) |
| `counter_venues[].provider_id` | `string` | No | External provider ID |
| `counter_venues[].metadata` | `object` | No | Additional venue metadata |

**Example Request (Accept):**

```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "action": "accept"
}
```

**Example Request (Counter):**

```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "action": "counter",
  "counter_slots": [
    {
      "starts_at": "2025-11-21T15:00:00Z",
      "duration_minutes": 45
    }
  ],
  "counter_venues": [
    {
      "name": "Sightglass Coffee",
      "provider_id": "google-place-789"
    }
  ]
}
```

**Successful Response**

**Status:** `200 OK`

**Body:**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "owner": "firebase-uid-organizer",
    "title": "Coffee catch-up",
    "state": "awaiting_replies",
    "intent_category": "coffee",
    "participants": [
      {
        "id": "participant-uuid-1",
        "user_id": "firebase-uid-organizer",
        "status": "organizer",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "participant-uuid-2",
        "user_id": "firebase-uid-friend1",
        "status": "accepted",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:05:00Z"
      },
      {
        "id": "participant-uuid-3",
        "user_id": "firebase-uid-friend2",
        "status": "invited",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "proposed_slots": [
      {
        "id": "slot-uuid-1",
        "slot_index": 0,
        "starts_at": "2025-11-20T10:00:00Z",
        "duration_minutes": 30,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "slot-uuid-2",
        "slot_index": 1,
        "starts_at": "2025-11-20T14:00:00Z",
        "duration_minutes": 30,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "proposed_venues": [
      {
        "id": "venue-uuid-1",
        "venue_index": 0,
        "name": "Blue Bottle Coffee",
        "provider_id": "google-place-123",
        "metadata": {
          "lat": 37.7749,
          "lon": -122.4194
        },
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "venue-uuid-2",
        "venue_index": 1,
        "name": "Ritual Coffee Roasters",
        "provider_id": "google-place-456",
        "metadata": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "agent_mode": true,
    "agent_round": 0,
    "created_at": "2025-11-18T10:00:00Z",
    "updated_at": "2025-11-18T10:05:00Z",
    "expires_at": "2025-11-25T10:00:00Z"
  },
  "meta": {
    "request_id": "req-uuid-456",
    "timestamp": "2025-11-18T10:05:00Z"
  }
}
```

**Error Responses**

**400 Bad Request** — Validation error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required counter_slots for action 'counter'",
    "details": {
      "field": "counter_slots",
      "action": "counter"
    }
  }
}
```

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**403 Forbidden** — Actor not a participant

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "User is not a participant in this negotiation",
    "details": {
      "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "firebase-uid-stranger"
    }
  }
}
```

**404 Not Found** — Negotiation does not exist

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Negotiation not found",
    "details": {
      "negotiation_id": "invalid-uuid"
    }
  }
}
```

**409 Conflict** — Invalid state transition

```json
{
  "error": {
    "code": "INVALID_STATE_TRANSITION",
    "message": "Cannot reply to negotiation in current state",
    "details": {
      "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
      "current_state": "accepted",
      "requested_action": "accept"
    }
  }
}
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-456"
    }
  }
}
```

**Notes**

- **Participant validation:** The backend verifies the authenticated user is a participant before processing the reply.
- **State machine enforcement:** Replies are only allowed in `awaiting_invites` and `awaiting_replies` states. Attempts to reply to `accepted`, `cancelled`, or `expired` negotiations return `409`.
- **Counter-proposal limits:** Maximum 10 counter-slots and 10 counter-venues per reply.
- **Agent round increment:** If `agent_mode = true` and action is `counter`, the `agent_round` field increments.
- **Normalized tables:** Counter-proposed slots/venues are appended to `proposed_slots` and `proposed_venues` tables with sequential indexes.
- **Snapshot updates:** The `proposed_slots_json` and `proposed_venues_json` snapshot fields are regenerated after counter-proposals.

---

### 4.3 GET /negotiations/:id

**Summary**

Retrieves detailed metadata for a single negotiation by UUID. This endpoint is called when iOS users tap on an invitation card to view full details (participants, proposed slots, proposed venues, state, etc.).

The backend returns metadata only; encrypted message payloads (if present) are returned as-is without decryption.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/negotiations/:id` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Validates the authenticated user is a participant in the negotiation
2. Retrieves the negotiation row from the `negotiations` table
3. Joins with `participants`, `proposed_slots`, and `proposed_venues` tables
4. Sorts participants (organizer first, then others by `created_at`)
5. Sorts slots by `starts_at` ascending
6. Sorts venues by `venue_index` ascending
7. Returns the full negotiation metadata in the canonical envelope

**Authorization:** Only participants in the negotiation can retrieve its details. Non-participants receive `403 Forbidden`.

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

#### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `string` | UUID of the negotiation to retrieve |

**Example Request:**

```
GET /negotiations/550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer <firebase_id_token>
```

**Successful Response**

**Status:** `200 OK`

**Body:**

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "owner": "firebase-uid-organizer",
    "title": "Coffee catch-up",
    "state": "awaiting_replies",
    "intent_category": "coffee",
    "participants": [
      {
        "id": "participant-uuid-1",
        "user_id": "firebase-uid-organizer",
        "status": "organizer",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "participant-uuid-2",
        "user_id": "firebase-uid-friend1",
        "status": "accepted",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:05:00Z"
      },
      {
        "id": "participant-uuid-3",
        "user_id": "firebase-uid-friend2",
        "status": "invited",
        "display_name": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "proposed_slots": [
      {
        "id": "slot-uuid-1",
        "slot_index": 0,
        "starts_at": "2025-11-20T10:00:00Z",
        "duration_minutes": 30,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "slot-uuid-2",
        "slot_index": 1,
        "starts_at": "2025-11-20T14:00:00Z",
        "duration_minutes": 30,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "proposed_venues": [
      {
        "id": "venue-uuid-1",
        "venue_index": 0,
        "name": "Blue Bottle Coffee",
        "provider_id": "google-place-123",
        "metadata": {
          "lat": 37.7749,
          "lon": -122.4194
        },
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      },
      {
        "id": "venue-uuid-2",
        "venue_index": 1,
        "name": "Ritual Coffee Roasters",
        "provider_id": "google-place-456",
        "metadata": null,
        "created_at": "2025-11-18T10:00:00Z",
        "updated_at": "2025-11-18T10:00:00Z"
      }
    ],
    "agent_mode": true,
    "agent_round": 0,
    "created_at": "2025-11-18T10:00:00Z",
    "updated_at": "2025-11-18T10:05:00Z",
    "expires_at": "2025-11-25T10:00:00Z"
  },
  "meta": {
    "request_id": "req-uuid-789",
    "timestamp": "2025-11-18T10:10:00Z"
  }
}
```

**Error Responses**

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**403 Forbidden** — User not a participant

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "User is not a participant in this negotiation",
    "details": {
      "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "firebase-uid-stranger"
    }
  }
}
```

**404 Not Found** — Negotiation does not exist

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Negotiation not found",
    "details": {
      "negotiation_id": "invalid-uuid"
    }
  }
}
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-789"
    }
  }
}
```

**Notes**

- **Participant authorization:** Only users listed in the `participants` table can retrieve negotiation details.
- **Sorting:** Participants are sorted with organizer first, then by `created_at`. Slots are sorted by `starts_at` ascending. Venues are sorted by `venue_index` ascending.
- **Normalized data:** The response includes data from normalized tables (`participants`, `proposed_slots`, `proposed_venues`), not the JSONB snapshot fields.
- **E2EE metadata:** All fields returned are metadata only. Encrypted payloads (future feature) are returned as-is without backend decryption.
- **Display names:** The `display_name` field is nullable; iOS clients should fall back to Firebase profile names or user IDs.

---

### 4.4 GET /negotiations

**Summary**

Retrieves a paginated list of negotiations filtered by state and participant. This endpoint is called when iOS users view their Active Invitations, Past Invitations, or Awaiting Response lists.

The backend returns metadata-only summaries; full details require a subsequent `GET /negotiations/:id` call.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/negotiations` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Extracts the authenticated user ID from the Firebase JWT `sub` claim
2. Filters negotiations where the user is a participant
3. Applies optional `state` filter (e.g., `awaiting_replies`, `accepted`, `cancelled`)
4. Sorts results by `updated_at` descending (most recent first)
5. Paginates results using cursor-based pagination
6. Returns negotiation summaries with participant counts and latest updates

**Common Use Cases:**

- **Active Invitations:** `?state=awaiting_invites,awaiting_replies`
- **Past Invitations:** `?state=accepted,cancelled,expired`
- **Awaiting Response:** `?state=awaiting_replies` + filter where user status is `invited`

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `state` | `string` | No | Comma-separated list of states to filter by (default: all states) |
| `limit` | `number` | No | Maximum results per page (default: 20, max: 100) |
| `cursor` | `string` | No | Pagination cursor from previous response |

**Example Request:**

```
GET /negotiations?state=awaiting_replies,awaiting_invites&limit=20
Authorization: Bearer <firebase_id_token>
```

**Successful Response**

**Status:** `200 OK`

**Body:**

```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "owner": "firebase-uid-organizer",
      "title": "Coffee catch-up",
      "state": "awaiting_replies",
      "intent_category": "coffee",
      "participant_count": 3,
      "accepted_count": 1,
      "agent_mode": true,
      "created_at": "2025-11-18T10:00:00Z",
      "updated_at": "2025-11-18T10:05:00Z",
      "expires_at": "2025-11-25T10:00:00Z"
    },
    {
      "id": "660f9511-f3ac-52e5-b827-557766551111",
      "owner": "firebase-uid-friend1",
      "title": "Lunch planning",
      "state": "awaiting_invites",
      "intent_category": "lunch",
      "participant_count": 4,
      "accepted_count": 0,
      "agent_mode": false,
      "created_at": "2025-11-17T14:00:00Z",
      "updated_at": "2025-11-17T14:00:00Z",
      "expires_at": "2025-11-24T14:00:00Z"
    }
  ],
  "meta": {
    "request_id": "req-uuid-101112",
    "timestamp": "2025-11-18T10:15:00Z",
    "pagination": {
      "limit": 20,
      "cursor": "next-cursor-base64-encoded",
      "has_more": true
    }
  }
}
```

**Error Responses**

**400 Bad Request** — Invalid query parameter

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid state value in query parameter",
    "details": {
      "field": "state",
      "value": "invalid-state",
      "allowed": ["awaiting_invites", "awaiting_replies", "accepted", "cancelled", "expired"]
    }
  }
}
```

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-101112"
    }
  }
}
```

**Notes**

- **User filtering:** Results automatically filter to negotiations where the authenticated user is a participant. No need to pass `user_id` in the query.
- **State filtering:** The `state` parameter accepts comma-separated values for multiple states (e.g., `awaiting_invites,awaiting_replies`).
- **Cursor pagination:** Use the `cursor` value from `meta.pagination.cursor` to fetch the next page. The cursor is a base64-encoded opaque token.
- **Summary fields:** The response includes summary fields (`participant_count`, `accepted_count`) for UI rendering without requiring full detail fetches.
- **Sorting:** Results are sorted by `updated_at` descending (most recently updated first).
- **Participant counts:** The `participant_count` includes all participants (organizer + invitees). The `accepted_count` includes only participants with `status = 'accepted'` or `status = 'organizer'`.
- **Limit bounds:** The `limit` parameter is capped at 100. Requests exceeding this return `400` validation error.

<!-- Completed: P2.S2.T1.ST1.SP3 -->

## 5. Event Endpoints

### 5.1 GET /events/upcoming

**Summary**

Retrieves a list of upcoming confirmed events owned by the authenticated user. This endpoint returns only future events (where `starts_at >= now()`) sorted chronologically by start time.

The iOS app calls this endpoint to populate the dashboard "Upcoming Events" card, calendar views, and notification-triggered event details. All returned data is metadata only, respecting E2EE boundaries.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/events/upcoming` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Extracts the authenticated user ID from the Firebase JWT `sub` claim
2. Queries the `events` table for rows where `owner = user_id` and `starts_at >= NOW()`
3. Filters to events with `status = 'confirmed'` (excludes draft and cancelled)
4. Sorts results by `starts_at` ascending (earliest event first)
5. Applies optional `limit` and `after` filters from query parameters
6. Returns event metadata in the canonical envelope

**Event-Negotiation Linkage:**

- If an event originated from a negotiation, `negotiation_id` is populated
- If the linked negotiation is deleted, `negotiation_id` becomes `NULL` (due to `ON DELETE SET NULL` FK rule)
- Events remain queryable even after source negotiations are removed

**Use Cases:**

- Dashboard "Upcoming Events" card (next 5 events)
- Full calendar view (next 30 days)
- Notification tap → event detail view

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | `number` | No | Maximum results to return (default: 20, max: 100) |
| `after` | `string` | No | ISO-8601 timestamp; only return events starting strictly after this time |

**Example Request:**

```
GET /events/upcoming?limit=10&after=2025-11-20T00:00:00Z
Authorization: Bearer <firebase_id_token>
```

**Successful Response**

**Status:** `200 OK`

**Body:**

```json
{
  "data": [
    {
      "id": "event-uuid-001",
      "owner": "firebase-uid-user",
      "title": "Coffee with Sarah",
      "starts_at": "2025-11-20T10:00:00Z",
      "ends_at": "2025-11-20T10:30:00Z",
      "status": "confirmed",
      "intent_category": "coffee",
      "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
      "metadata": {
        "venue_name": "Blue Bottle Coffee",
        "participant_count": 3
      },
      "agent_mode": true,
      "created_at": "2025-11-18T10:00:00Z",
      "updated_at": "2025-11-18T12:00:00Z"
    },
    {
      "id": "event-uuid-002",
      "owner": "firebase-uid-user",
      "title": "Lunch planning",
      "starts_at": "2025-11-21T12:30:00Z",
      "ends_at": "2025-11-21T13:30:00Z",
      "status": "confirmed",
      "intent_category": "lunch",
      "negotiation_id": null,
      "metadata": {
        "venue_name": "Mission Chinese Food"
      },
      "agent_mode": false,
      "created_at": "2025-11-19T08:00:00Z",
      "updated_at": "2025-11-19T08:00:00Z"
    },
    {
      "id": "event-uuid-003",
      "owner": "firebase-uid-user",
      "title": "Gym session",
      "starts_at": "2025-11-22T07:00:00Z",
      "ends_at": "2025-11-22T08:00:00Z",
      "status": "confirmed",
      "intent_category": "gym",
      "negotiation_id": "660f9511-f3ac-52e5-b827-557766551111",
      "metadata": null,
      "agent_mode": false,
      "created_at": "2025-11-20T06:00:00Z",
      "updated_at": "2025-11-20T06:00:00Z"
    }
  ],
  "meta": {
    "request_id": "req-uuid-202122",
    "timestamp": "2025-11-18T15:00:00Z",
    "count": 3
  }
}
```

**Error Responses**

**400 Bad Request** — Invalid query parameter

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid 'after' timestamp format",
    "details": {
      "field": "after",
      "value": "invalid-timestamp",
      "expected": "ISO-8601 format (e.g., 2025-11-20T00:00:00Z)"
    }
  }
}
```

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-202122"
    }
  }
}
```

**Notes**

- **Ownership filtering:** Results automatically filter to events where `owner = authenticated_user_id`. No need to pass `user_id` in the query.
- **Status filtering:** Only `confirmed` events are returned. Draft and cancelled events are excluded.
- **Future events only:** Backend enforces `starts_at >= NOW()` in the query. Past events require a separate endpoint (future feature).
- **Sorting:** Results are sorted by `starts_at` ascending (earliest event first).
- **Limit bounds:** The `limit` parameter is capped at 100. Requests exceeding this return `400` validation error.
- **After filter:** The `after` parameter filters events starting strictly after the provided timestamp (exclusive). Useful for "show me events after tomorrow" queries.
- **Negotiation linkage:** The `negotiation_id` field is nullable. If the source negotiation is deleted, the event persists with `negotiation_id = NULL`.
- **Metadata field:** The `metadata` JSONB column stores non-sensitive context (venue names, participant counts, etc.) for UI rendering.
- **E2EE boundaries:** All fields are metadata only. No encrypted payloads are returned. Detailed event descriptions or private notes live client-side.
- **iOS use case:** The dashboard "Upcoming Events" card typically calls this with `limit=5` to show the next 5 events.

---

### 5.2 GET /events/:id

**Summary**

Retrieves full metadata for a single event by UUID. This endpoint returns detailed information about a confirmed event owned by the authenticated user.

The iOS app calls this endpoint when users tap on event notifications, calendar entries, or dashboard cards to view complete event details. All returned data is metadata only, respecting E2EE boundaries.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/events/:id` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Validates the authenticated user ID from the Firebase JWT `sub` claim
2. Retrieves the event row from the `events` table by `id`
3. Verifies the event is owned by the authenticated user (`owner = user_id`)
4. Returns full event metadata in the canonical envelope

**Authorization:** Only the event owner can retrieve event details. Non-owners receive `403 Forbidden`, even if the event exists.

**Event-Negotiation Linkage:**

- If the event originated from a negotiation, `negotiation_id` is populated
- If the linked negotiation is deleted, `negotiation_id` becomes `NULL` (due to `ON DELETE SET NULL` FK rule)
- The event remains queryable even after the source negotiation is removed

**Use Cases:**

- Notification tap → full event detail view
- Calendar entry tap → event viewer
- Dashboard card tap → event timeline

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

#### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | `string` | UUID of the event to retrieve |

**Example Request:**

```
GET /events/event-uuid-001
Authorization: Bearer <firebase_id_token>
```

**Successful Response**

**Status:** `200 OK`

**Body:**

```json
{
  "data": {
    "id": "event-uuid-001",
    "owner": "firebase-uid-user",
    "title": "Coffee with Sarah",
    "starts_at": "2025-11-20T10:00:00Z",
    "ends_at": "2025-11-20T10:30:00Z",
    "status": "confirmed",
    "intent_category": "coffee",
    "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
    "metadata": {
      "venue_name": "Blue Bottle Coffee",
      "venue_address": "66 Mint St, San Francisco, CA 94103",
      "participant_count": 3,
      "participant_names": ["Sarah", "Mike"]
    },
    "agent_mode": true,
    "created_at": "2025-11-18T10:00:00Z",
    "updated_at": "2025-11-18T12:00:00Z"
  },
  "meta": {
    "request_id": "req-uuid-303132",
    "timestamp": "2025-11-18T16:00:00Z"
  }
}
```

**Error Responses**

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**403 Forbidden** — Event exists but user is not the owner

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "User is not the owner of this event",
    "details": {
      "event_id": "event-uuid-001",
      "user_id": "firebase-uid-stranger"
    }
  }
}
```

**404 Not Found** — Event does not exist

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Event not found",
    "details": {
      "event_id": "invalid-uuid"
    }
  }
}
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-303132"
    }
  }
}
```

**Notes**

- **Ownership-only access:** Only the event owner can retrieve event details. This ensures events are private and not shared without explicit invitation mechanisms (future feature).
- **Authorization check:** The backend validates `owner = authenticated_user_id` before returning data. Non-owners receive `403 Forbidden`, even if the event UUID is valid.
- **Negotiation linkage:** The `negotiation_id` field is nullable. If the source negotiation is deleted (by owner or expiration), the event persists with `negotiation_id = NULL`.
- **Metadata JSONB:** The `metadata` field stores non-sensitive context for UI rendering (venue names, addresses, participant counts, etc.). This data is unencrypted and queryable.
- **E2EE boundaries:** All fields are metadata only. Detailed event descriptions, private notes, or encrypted messages live client-side and are never stored or returned by the backend.
- **Status field:** Events can have status `draft`, `confirmed`, or `cancelled`. This endpoint returns events regardless of status (unlike `/events/upcoming` which filters to `confirmed` only). This behavior is intentional: visibility for GET /events/:id is governed strictly by ownership, not by event status, so draft and cancelled events remain fully retrievable by their owner for audit, history, and client‑side display consistency.
- **iOS use cases:**
  - **Notification tap:** User receives push notification for upcoming event → taps → app calls `GET /events/:id` → displays full event detail view
  - **Calendar entry:** User taps calendar entry → app fetches event details → renders timeline with venue, participants, time
  - **Dashboard card:** User taps "Upcoming Events" card entry → app navigates to event detail → fetches full metadata
- **Future extensibility:** The `metadata` JSONB field allows adding new UI-relevant fields (e.g., weather forecasts, traffic estimates) without schema migrations.

---

### 5.3 POST /events (Phase 4+ — placeholder only)

**Summary**

Creates a standalone event not associated with a negotiation. Placeholder only. Full implementation planned for Phase 4.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `POST` |
| **Path** | `/events` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |
| **Status** | *Not implemented — Phase 4+* |

**Description**

Reserved for Phase 4. This endpoint will allow clients to create events directly (bypassing negotiation workflows). No request schema or behavior is defined at this stage.

**Notes**

- **Placeholder only** — do not implement in backend during Phase 3
- **Schema and validation TBD** in Phase 4
- **Event rows created by this endpoint** will follow the same metadata structure as negotiation-derived events
- **Client apps must NOT call this endpoint** before implementation

> This endpoint is a Phase 4+ feature and must remain a placeholder in Phase 2 & Phase 3.

<!-- Completed: P2.S2.T1.ST2.SP4 -->

## 6. User Endpoints

### 6.1 GET /me

**Summary**

Returns the authenticated user's profile metadata derived from Firebase Auth and the `app_users` table. This endpoint is **required for MVP/TestFlight** to support user identity, UI personalization, and invitation workflows.

**Phase:** MVP / Phase 3

The iOS app calls this endpoint during onboarding, dashboard initialization, and invitation flows to retrieve the current user's profile. The backend extracts the user ID from the Firebase JWT and returns metadata stored in the `app_users` table.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/me` |
| **Auth** | Required (Firebase JWT) |
| **Rate Limit** | Standard (per-user + global) |

**Description**

This endpoint:

1. Extracts the authenticated user's Firebase UID from the JWT `sub` claim
2. Queries the `app_users` table for a row matching `firebase_uid = sub`
3. If no row exists (first-time user), creates a new `app_users` row with default values (upsert behavior)
4. Returns the user's profile metadata in the canonical envelope

**Auto-Provisioning (Upsert Behavior):**

On first call for a new Firebase user, the backend automatically creates an `app_users` row with:
- `firebase_uid` = JWT `sub`
- `display_name` = Firebase profile name (if available) or `null`
- `locale` = inferred from `Accept-Language` header (if present) or `null`
- `feature_flags` = `{}`
- `agent_mode_default` = `false`

**Existing fields** (`display_name`, `locale`, `feature_flags`) are **NOT overwritten** during auto-provisioning if the user row already exists. Only the first-time creation populates these defaults.

If the `Accept-Language` header is present, the backend **SHOULD** populate `locale` when creating a new user.

**Non-Sensitive Metadata Only:**

This endpoint returns only **non-sensitive profile metadata**. It never includes:
- Firebase ID tokens or refresh tokens
- Email addresses or phone numbers
- Encrypted payloads or private user content

**E2EE Boundaries:**

All returned fields are metadata only. No encrypted blobs are stored or returned by this endpoint.

**Future profile update endpoints MUST NOT accept encrypted fields; profile data is plaintext metadata only.**

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `X-Request-Id` | Optional | Client-supplied correlation ID |

This endpoint **MUST NOT** accept a request body.

**Successful Response**

**Status:** `200 OK`

**Note:** All successful responses must include `data` and may include `meta`.

**Response Fields:**

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | `string` (UUID) | No | Internal user ID (primary key) |
| `firebase_uid` | `string` | No | Firebase Auth UID (lowercase) |
| `display_name` | `string` | Yes | User's display name for UI rendering |
| `locale` | `string` | Yes | Preferred locale (e.g., `en-US`, `es-MX`) |
| `feature_flags` | `object` | No | JSON object containing feature toggles |
| `agent_mode_default` | `boolean` | No | Whether AI agent mode is enabled by default |
| `created_at` | `string` (ISO-8601) | No | Account creation timestamp |
| `updated_at` | `string` (ISO-8601) | No | Last profile update timestamp |

**Example Response:**

```json
{
  "data": {
    "id": "user-uuid-123",
    "firebase_uid": "firebase-uid-current",
    "display_name": "Alex",
    "locale": "en-US",
    "feature_flags": {
      "beta_agent_mode": true,
      "calendar_sync_enabled": false
    },
    "agent_mode_default": true,
    "created_at": "2025-11-10T09:00:00Z",
    "updated_at": "2025-11-18T12:30:00Z"
  },
  "meta": {
    "request_id": "req-uuid-xyz",
    "timestamp": "2025-11-18T12:30:45Z"
  }
}
```

**Error Responses**

**401 Unauthorized** — Missing or invalid JWT

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid Firebase JWT token",
    "details": {}
  }
}
```

**404 Not Found** — User row missing

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "User profile not found",
    "details": {
      "firebase_uid": "firebase-uid-current"
    }
  }
}
```

**Note:** This error cannot occur in normal operation; only possible if the database row was manually removed or corrupted.
```

**429 Too Many Requests** — Rate limit exceeded

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests, please retry later",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

**500 Internal Server Error** — Backend failure

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "details": {
      "request_id": "req-uuid-xyz"
    }
  }
}
```

**Notes**

- **Identity extraction:** The user's Firebase UID is extracted from the JWT `sub` claim. Client-supplied user IDs are ignored.
- **Auto-provisioning (upsert):** If the user has no `app_users` row, the backend creates one automatically on first call. This ensures all authenticated users have a profile record.
- **Default values:** New users receive default values (`agent_mode_default = false`, `feature_flags = {}`, nullable `display_name` and `locale`).
- **Display name and locale:** These fields are optional. iOS clients may override them locally or prompt users to set them during onboarding.
- **Feature flags:** The `feature_flags` object allows server-side feature toggles without requiring app updates. Example flags:
  - `beta_agent_mode`: Enable AI agent features
  - `calendar_sync_enabled`: Enable calendar integration (future)
  - `dark_mode_forced`: Force dark mode (testing)
- **E2EE boundaries:** All fields are metadata only. No encrypted payloads, private messages, or sensitive identifiers are returned.
- **No secrets or tokens:** The response never includes Firebase ID tokens, refresh tokens, email addresses, phone numbers, or authentication credentials.
- **iOS use cases:**
  - **Onboarding:** App calls `/me` after Firebase sign-in to retrieve or create user profile
  - **Dashboard personalization:** Display name used in greeting ("Welcome back, Alex")
  - **Invitation flows:** Display name and locale used as defaults when creating invitations
  - **Settings screen:** Profile data pre-populates user preferences
- **Rate limiting:** Standard per-user rate limits apply. Clients should cache the response locally and only refresh when needed (e.g., after profile updates or app foreground).
- **Caching:** iOS clients should cache `/me` for the duration of the app session.
- **Future extensibility:** Additional metadata fields (e.g., avatar URL, timezone preference) can be added to `feature_flags` or as top-level fields without breaking existing clients.
- **Cross-reference:** See `01-data-model.md` for the canonical `app_users` object.

<!-- Completed: P2.S2.T1.ST3.SP2 -->

---

### 6.2 GET /users/:id (future, admin-only)

**Summary**

This endpoint is **reserved for future admin/support tooling only**, NOT for the mobile app or public API. It is explicitly **out of scope for MVP/TestFlight**.

Purpose: Allow a trusted admin backend to look up a user's profile by internal ID for support or moderation purposes. This will be locked behind elevated authentication and separate infrastructure (admin panel or internal tools).

> **Status:** Not implemented — reserved for Phase 4/5 admin tooling. Must NOT be exposed to public/mobile clients.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/admin/users/:id` (proposed) |
| **Auth** | Admin-only (future) |
| **Scope** | Phase 4+ |
| **Status** | *Not implemented* |

**Notes**

- **Must never be callable with a regular Firebase JWT** from the mobile app.
- **Admin-only requirement:** This endpoint **MUST** require a Firebase Admin token or backend-service token; public JWTs **MUST** be rejected.
- **RBAC requirement:** When implemented, this endpoint **MUST** enforce RBAC role claims.
- **Privacy constraint:** Response **MUST NOT** include email, phone, or sensitive identifiers.
- Will likely live behind a separate admin service or Cloud Run service with its own `audience`/`claims` validation.
- Included here only for forward planning; no implementation, no stubs in Phase 3.
- Future design must include audit logging, role-based access control (RBAC), and privacy safeguards.

---

### 6.3 DELETE /me (account deletion – future)

**Summary**

This endpoint is **reserved for future account deletion and data-retention flows**. It would coordinate Firebase Auth account deletion, `app_users` soft-deactivation, and long-term retention rules for negotiation metadata (to preserve other users' history).

This is explicitly **NOT part of MVP/TestFlight** and must not be implemented until legal/privacy policies are finalized.

> **Status:** Not implemented — reserved for a future E2EE + retention policy design. Must NOT be implemented in MVP/TestFlight.

**Design Notes**

Deleting a user fully is non-trivial because negotiations and events involve multiple participants:

- **Soft-delete or anonymization:** User metadata may need to be anonymized (e.g., replace `display_name` with "Deleted User") rather than fully removed.
- **Preserve other participants' data:** Other users' negotiation and event history must remain intact and queryable.
- **Lineage-preserving anonymization:** Negotiations and events owned by the user require lineage-preserving anonymization to maintain audit trails for other participants.
- **Respect E2EE boundaries:** Backend must never decrypt encrypted blobs as part of deletion logic.
- **Legal/privacy compliance:** Must follow GDPR, CCPA, and other jurisdictional data-retention requirements.

**Future design must address:**

1. **Firebase Auth deletion:** Coordinate with Firebase Admin SDK to delete the user's Firebase account.
2. **Database soft-deletion:** Mark `app_users` row as `deleted = true` or anonymize fields.
3. **Cascade rules:** Decide whether to:
   - Preserve negotiations/events with anonymized owner
   - Transfer ownership to a system "ghost user"
   - Delete only user-initiated negotiations (not participations)
4. **Audit trail:** Log all deletion requests for compliance.
5. **UX flow:** Design confirmation UI, waiting periods, and irreversibility warnings.
6. **Data-retention rules:** See `04-database-schema.md` Section 6 (Migration Rules) for canonical data-retention and anonymization strategies.
6. **Data-retention rules:** See `04-database-schema.md` Section 6 (Migration Rules) for canonical data-retention and anonymization strategies.

**MVP/TestFlight Note**

For MVP/TestFlight:
- **Only Firebase console or manual tooling** may be used for test account cleanup.
- The mobile app **MUST NOT expose any account-deletion UI** until this endpoint and its policies are fully designed.
- Test users created during TestFlight can be manually removed via Firebase Admin SDK if needed.

<!-- Completed: P2.S2.T1.ST3.SP3 -->
<!-- Completed: Section 6 Sweep Fixes -->

## 7. Utility & Infrastructure Endpoints

### 7.1 GET /health

**Summary**

A lightweight, public health check endpoint used by GCP load balancers, Cloud Run health probes, CI/CD smoke tests, and uptime monitoring systems. This endpoint reports basic service health and dependency readiness without requiring authentication.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/health` |
| **Auth** | Not required (public endpoint) |
| **Rate Limit** | Global (very high), no per-user limit |

**Description**

The `/health` endpoint provides a fast, side-effect-free health check for the Fastify backend service. It is designed to be called frequently by orchestration systems (Kubernetes, Cloud Run) and monitoring tools.

**Implementation Notes:**

- **MVP/Phase 3:** Simple in-process check returning `{ "status": "ok" }` when the process is running
- **Phase 4+:** May include database connectivity checks, migration version verification, and dependency health

The handler must always return quickly (< 100ms) and avoid heavy operations like full database scans or external API calls.

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Request-Id` | Optional | Client-supplied correlation ID |
| `Cache-Control` | Recommended | `no-store` (this endpoint must not be cached) |

**No request body. No query parameters.**

**Caching:** This endpoint **MUST NOT** be cached by clients, CDNs, or proxies. Always set `Cache-Control: no-store`.

**Successful Response**

**Status:** `200 OK`

**Body:**

```json
{
  "data": {
    "status": "ok",
    "uptime_seconds": 12345,
    "timestamp": "2025-11-18T12:00:00Z"
  },
  "meta": {
    "request_id": "req-uuid-health",
    "timestamp": "2025-11-18T12:00:00Z"
  }
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `status` | `string` | Health status: `"ok"` when healthy, `"degraded"` or `"error"` in Phase 4+ |
| `uptime_seconds` | `number` | Process uptime in seconds (optional). Clients must treat absence as null and not rely on its presence. |
| `timestamp` | `string` (ISO-8601) | Current server time |

**Error Responses**

**500 Internal Server Error** — Service unhealthy (rare)

```json
{
  "error": {
    "code": "SERVICE_UNAVAILABLE",
    "message": "Health check failed",
    "details": {}
  }
}
```

**503 Service Unavailable** — Dependencies unavailable

```json
{
  "error": {
    "code": "SERVICE_UNAVAILABLE",
    "message": "Backend dependencies unavailable",
    "details": {}
  }
}
```

**Note:** `500` is used when the backend instance is unhealthy internally. `503` is used when dependencies (e.g., Postgres) are unavailable or during temporary unready states. Cloud Run will treat both as failing the readiness probe.

**Notes**

- **Status values:** `"ok"` indicates the process is healthy and ready to accept requests.
- **Uptime tracking:** The `uptime_seconds` field helps identify recent restarts or deployments.
- **No internal details:** This endpoint must never expose stack traces, database credentials, or internal error details.
- **Error envelope:** Even health check failures use the canonical error envelope format.
- **Cloud Run integration:** Cloud Run uses this endpoint to determine container readiness and liveness.
- **Readiness vs Liveness:** For MVP/Phase 3, `/health` serves as both liveness and readiness probe for Cloud Run. Dedicated endpoints may be added in Phase 4+.
- **Monitoring:** External services (UptimeRobot, Pingdom) can poll this endpoint to detect outages.
- **Fast response:** Must complete in < 100ms to avoid false positives from orchestration timeouts.

---

### 7.2 GET /version

**Summary**

A public, unauthenticated endpoint exposing the deployed backend version, schema/API versions, and environment metadata. Mobile clients use this to verify backend compatibility, and CI/CD systems use it to confirm deployed builds.

**Method & Path**

| Property | Value |
|----------|-------|
| **Method** | `GET` |
| **Path** | `/version` |
| **Auth** | Not required (public endpoint) |
| **Rate Limit** | Global (high), no per-user limit |

**Description**

The `/version` endpoint returns static version metadata loaded from environment variables or build-time constants. It enables:

- **iOS version compatibility checks:** App can verify the backend supports its expected schema version
- **Deployment verification:** CI/CD confirms the correct build is deployed
- **Debug tooling:** Engineers can inspect backend version from the app's debug menu

**Request**

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Request-Id` | Optional | Client-supplied correlation ID |
| `Cache-Control` | Recommended | `no-store` (this endpoint must not be cached) |

**No request body. No query parameters.**

**Caching:** This endpoint **MUST NOT** be cached by clients, CDNs, or proxies. Always set `Cache-Control: no-store`.

**Successful Response**

**Status:** `200 OK`

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `backend_version` | `string` | Git SHA or semantic version (e.g., `1.0.0+abc1234`) |
| `schema_version` | `string` | Logical schema/API version (e.g., `negotiations-v1`) |
| `environment` | `string` | Deployment environment: `dev`, `staging`, `prod` |
| `build_timestamp` | `string` (ISO-8601) | When the backend was built |
| `commit_sha` | `string` | Short commit hash (e.g., `abc1234`) (optional) |
| `commit_sha_full` | `string` | Full commit SHA (optional) |
| `commit_url` | `string` | Optional link to the commit in the VCS (GitHub, GitLab) |

**Example Response:**

```json
{
  "data": {
    "backend_version": "1.0.0+abc1234",
    "schema_version": "negotiations-v1",
    "environment": "staging",
    "build_timestamp": "2025-11-18T11:45:00Z",
    "commit_sha": "abc1234",
    "commit_sha_full": "abc1234567890abcdef1234567890abcdef12345",
    "commit_url": "https://github.com/VSLinea/KairosMain/commit/abc1234"
  },
  "meta": {
    "request_id": "req-uuid-version",
    "timestamp": "2025-11-18T12:01:00Z"
  }
}
```

**Error Responses**

**500 Internal Server Error** — Version metadata unavailable (rare)

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Version information unavailable",
    "details": {}
  }
}
```

**Notes**

- **Schema version compatibility:** iOS clients can check `schema_version` against their expected version. If mismatched:
  - Display warning: "Backend update required" or "App update required"
  - Gate features that rely on new schema fields
  - Prevent API calls to unsupported endpoints
- **Backend version format:** Use semantic versioning (e.g., `1.2.3`) plus git SHA suffix for traceability: `1.2.3+abc1234`
- **Environment detection:** The `environment` field helps distinguish staging from production deployments in logs and error reports.
- **Build timestamp:** Useful for identifying stale deployments or confirming rollback success.
- **Commit URL:** Enables one-click navigation from error reports to source code for debugging.
- **No secrets:** This endpoint is safe to call from the app's debug menu and exposes no sensitive information.
- **Caching:** iOS clients should cache `/version` for the duration of the app session and re-check only when the app returns to foreground.
- **CI/CD smoke test:** Deployment pipelines can call `/version` to verify:
  - Backend responds after deployment
  - Deployed version matches expected git SHA
  - Environment label is correct

**iOS Use Case Example:**

```swift
// Check backend compatibility on app launch
let response = try await apiClient.get("/version")
if response.schema_version != "negotiations-v1" {
    showAlert("Backend version mismatch. Please update the app.")
}
```

<!-- Completed: P2.S2.T1.ST4.SP1 -->

## 8. Error Reference

### 8.1 Error Envelope Recap

The Kairos Amiqo backend returns **all errors** using a single, canonical JSON structure.
This structure is defined in `02-api-contracts.md` and must be followed by **every endpoint**.

#### Error Envelope Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable explanation",
    "details": { /* optional object with context fields */ }
  }
}
```

#### Required Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `error.code` | string | Yes | Machine-readable identifier (UPPER_SNAKE_CASE) |
| `error.message` | string | Yes | Short human-readable description |
| `error.details` | object | No | Optional structured debugging fields |

- `code` **must** match one of the codes defined in Section 8.2 onward.
- `message` must be concise and safe for user-facing UI.
- `details` must never include sensitive information (JWTs, database errors, secrets).

details object must never include sensitive information  
Error responses never include `meta`.  
All error timestamps must be client‑ignored; only success envelopes may include `meta`.

#### HTTP Status Mapping

| HTTP Status | Typical Code | Meaning |
|-------------|--------------|---------|
| 400 | `VALIDATION_ERROR` | Client sent invalid data |
| 401 | `UNAUTHORIZED` | Missing/invalid Firebase JWT |
| 403 | `FORBIDDEN` | Actor authenticated but not allowed |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `CONFLICT` | Invalid state transition, duplicate constraint |
| 429 | `RATE_LIMIT_EXCEEDED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unexpected backend failure |

#### Example

```json
{
  "error": {
    "code": "INVALID_STATE_TRANSITION",
    "message": "Cannot accept an expired negotiation",
    "details": {
      "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
      "current_state": "expired",
      "requested_action": "accept"
    }
  }
}
```

<!-- Completed: P2.S2.T1.ST5.SP2 -->

### 8.2 Common Error Codes
The table below defines the **core, cross-cutting error codes** that can be returned by any endpoint in the Kairos Amiqo backend.  
Domain-specific codes for negotiations and events are documented in Sections **8.3** and **8.4**.

#### 8.2.1 Summary Table

| Code                    | HTTP Status | Description                                      |
|-------------------------|------------|--------------------------------------------------|
| `VALIDATION_ERROR`      | `400`      | Request payload or query params are invalid      |
| `UNAUTHORIZED`          | `401`      | Missing or invalid Firebase JWT                  |
| `FORBIDDEN`             | `403`      | Authenticated but not allowed to perform action  |
| `NOT_FOUND`             | `404`      | Resource does not exist or is not visible        |
| `CONFLICT`              | `409`      | Generic conflict (duplicates, invariants)        |
| `RATE_LIMIT_EXCEEDED`   | `429`      | Global or per-user rate limit exceeded           |
| `INTERNAL_ERROR`        | `500`      | Unexpected backend failure                       |
| `SERVICE_UNAVAILABLE`   | `500`/`503`| Backend or critical dependency is unavailable    |

These codes are **global**: every route must choose one of them (or a documented domain-specific code) and pair it with the appropriate HTTP status from Section 3.

> Note: Authentication‑specific clarifications (token expiry, audience mismatch, clock skew, etc.) are consolidated here. Error responses never include a `meta` block, and `error.details` must never contain sensitive identifiers.
---

#### 8.2.2 `VALIDATION_ERROR` (400)

Indicates that the client sent syntactically valid JSON, but one or more fields failed validation.

**Typical Causes:**

- Required field missing or empty
- Field has an invalid value (e.g., unknown `intent_category`, invalid `state`)
- Timestamp is malformed or not in UTC ISO-8601 format
- Array length outside allowed bounds (e.g., too many proposed slots)

**Typical `details` Payload:**

```json
{
  "field": "intent_category",
  "value": "coffeee",
  "allowed": ["coffee", "lunch", "dinner", "drinks", "gym", "walk", "movie", "concert", "study", "game", "brunch"]
}
```

**Backend Rules:**

- Never use `VALIDATION_ERROR` for authentication/authorization problems.
- Always include a `field` key in `details` when a single field is at fault.
- When multiple fields fail, either:
  - return the first failing field, or
  - return a `fields` object mapping each field to its error.

---

#### 8.2.3 `UNAUTHORIZED` (401)

Indicates that the request is not authenticated.

**Typical Causes:**

- Missing `Authorization` header
- Malformed `Authorization` header (not `Bearer <token>`)
- Firebase JWT is expired, invalid, or cannot be verified

**Typical `details` Payload:**

```json
{
  "reason": "missing_token"
}
```

or

```json
{
  "reason": "token_expired"
}
```

**Backend Rules:**

- Never include raw JWTs or decoded token contents in `details`.
- Use a short, non-sensitive `reason` value suitable for logs and client-side handling.
- Do not fall back to `INTERNAL_ERROR` for authentication failures; always use `UNAUTHORIZED`.

---

#### 8.2.4 `FORBIDDEN` (403)

Indicates that the user is authenticated but not allowed to perform the requested action.

**Typical Causes:**

- User is not a participant in the requested negotiation
- User is not the owner of the requested event
- User attempts an action outside their role (e.g., non-organizer changing organizer-only settings)

**Typical `details` Payload:**

```json
{
  "resource_type": "negotiation",
  "resource_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "firebase-uid-stranger"
}
```

**Backend Rules:**

- Use `FORBIDDEN` rather than `NOT_FOUND` when the resource clearly exists but access is denied.
- Do not leak sensitive information; keep `message` generic and use `details` sparingly.

---

#### 8.2.5 `NOT_FOUND` (404)

Indicates that the requested resource does not exist or is not visible to the caller.

**Typical Causes:**

- Negotiation ID does not exist
- Event ID does not exist
- Resource existed but was deleted

**Typical `details` Payload:**

```json
{
  "resource_type": "event",
  "resource_id": "invalid-uuid"
}
```

**Backend Rules:**

- Prefer `NOT_FOUND` over `FORBIDDEN` when it is safer not to reveal resource existence.
- For ID-lookup endpoints (`GET /negotiations/:id`, `GET /events/:id`), use `NOT_FOUND` when no row is returned after applying authorization filters.

---

#### 8.2.6 `CONFLICT` (409)

Indicates that the request cannot be completed because it would violate a uniqueness or state invariant.

**Typical Causes:**

- Creating a resource that already exists (duplicate key)
- Updating a resource that has changed since the client last fetched it
- High-level conflicts not covered by a more specific domain code

**Typical `details` Payload:**

```json
{
  "reason": "duplicate",
  "field": "negotiation_id"
}
```

**Backend Rules:**

- Use `CONFLICT` for generic 409 situations.
- Use more specific domain codes (e.g., `INVALID_STATE_TRANSITION`) in Sections 8.3 and 8.4 when applicable.

---

#### 8.2.7 `RATE_LIMIT_EXCEEDED` (429)

Indicates that the client has exceeded global or per-user rate limits.

**Typical Causes:**

- Too many requests in a short window from the same `user_id`
- Burst traffic that exceeds global service thresholds

**Typical `details` Payload:**

```json
{
  "retry_after_seconds": 60
}
```

**Backend Rules:**

- Always set the `Retry-After` HTTP header in seconds.
- Keep `message` user-friendly; clients may show it directly.
- Do not include IP addresses or internal rate limiter state in `details`.

---

#### 8.2.8 `INTERNAL_ERROR` (500)

Indicates that the backend encountered an unexpected failure that is not the client's fault.

**Typical Causes:**

- Unhandled exception in route handler
- Database outage or transient error not yet mapped to `SERVICE_UNAVAILABLE`
- Serialization or deserialization bug

**Typical `details` Payload:**

```json
{
  "request_id": "req-uuid-123"
}
```

**Backend Rules:**

- Never leak stack traces, SQL queries, or internal error messages in `message` or `details`.
- Always log the full internal error server-side with `request_id` for correlation.
- Prefer mapping known failure modes to more specific codes where possible.

---

#### 8.2.9 `SERVICE_UNAVAILABLE` (500/503)

Indicates that the backend or a critical dependency is temporarily unavailable.

**Typical Causes:**

- Database unreachable
- Migration in progress and schema not ready
- Downstream service outage (e.g., future calendar or maps integration)

**Typical `details` Payload:**

```json
{
  "dependency": "postgres",
  "reason": "connection_timeout"
}
```

**Backend Rules:**

Use `503` for temporary dependency failures (Postgres unavailable, migration in progress).  
Use `500` when the failure mode is unknown or not clearly retryable.

<!-- Completed: P2.S2.T1.ST5.SP3 -->

### 8.3 Negotiation-Specific Errors

These error codes apply exclusively to negotiation endpoints (`/negotiate/*`, `/negotiations/*`).  
They refine the global error codes from Section 8.2 with domain‑specific semantics.

Precedence rule: If a user is not a participant, return USER_NOT_PARTICIPANT even if the attempted action is organizer‑only.

---

### 8.3.1 `INVALID_STATE_TRANSITION` (409)

Returned when a request attempts to move a negotiation into a state that is not allowed by the canonical state machine defined in `01-data-model.md`.

**Typical Causes:**
- Accepting an already accepted, cancelled, or expired negotiation  
- Countering after the negotiation has reached `accepted`
- Attempting to finalize invitations while still in `awaiting_replies`

**Example `details`:**
```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "current_state": "accepted",
  "requested_action": "counter"
}
```

---

### 8.3.2 `USER_NOT_PARTICIPANT` (403)

Returned when the authenticated user attempts to interact with a negotiation they are not part of.

**Typical Causes:**
- Calling `GET /negotiations/:id` for a negotiation where user_id not in participants  
- Trying to reply to a negotiation without a participant row  
- Trying to add counter slots/venues as a non‑participant

**Example `details`:**
```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "firebase-uid-stranger"
}
```

---

### 8.3.3 `MISSING_COUNTER_FIELDS` (400)

Returned only when `action = "counter"` but required counter fields are missing.

**Typical Causes:**
- Missing `counter_slots`
- Missing `counter_venues`
- Empty arrays (`[]`) for either field

**Example `details`:**
```json
{
  "action": "counter",
  "missing": ["counter_slots"]
}
```

---

### 8.3.4 `COUNTER_LIMIT_EXCEEDED` (400)

Returned when a counter-proposal exceeds allowed limits.

**Rules:**
- Max 10 counter slots
- Max 10 counter venues

**Example `details`:**
```json
{
  "field": "counter_slots",
  "count": 14,
  "max_allowed": 10
}
```

---

### 8.3.5 `NEGOTIATION_EXPIRED` (409)

Negotiation expired via system rules (`expires_at < now()`), and the user attempts an action.

**Typical Causes:**
- Trying to accept or decline an expired negotiation  
- Trying to counter an expired negotiation  
- Trying to fetch details *after* expiration if endpoint is strict (backend may still allow read)

**Example `details`:**
```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "expired_at": "2025-11-25T10:00:00Z"
}
```

Expired negotiations may still be retrieved via GET endpoints. Expiration restricts write operations only.

---

### 8.3.6 `ORGANIZER_ONLY_ACTION` (403)

Returned when a non-organizer attempts organizer‑only operations.

**Typical Causes:**
- Attempting to finalize from `awaiting_invites → awaiting_replies`
- Attempting to modify title or intent during draft
- Future: modifying organizer-only metadata (Phase 4+)

**Example `details`:**
```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_role": "invited",
  "required_role": "organizer"
}
```

---

### 8.3.7 `NO_ELIGIBLE_SLOTS_OR_VENUES` (409)

Returned when a negotiation is missing valid slots or venues after countering or editing.

**Typical Causes:**
- Participant counters by removing all slots and venues  
- System detects negotiation has no viable scheduling options  

**Example `details`:**
```json
{
  "negotiation_id": "550e8400-e29b-41d4-a716-446655440000",
  "slots_count": 0,
  "venues_count": 0
}
```

---

<!-- Completed: P2.S2.T1.ST5.SP4 -->

### 8.4 Event-Specific Errors
Event-specific error codes apply exclusively to `/events/*` endpoints.  
They refine the global codes in Section 8.2 for the event domain.

---

### 8.4.1 `USER_NOT_EVENT_OWNER` (403)

Returned when the authenticated user attempts to access or modify an event they do not own.

**Typical Causes:**
- Calling `GET /events/:id` for an event owned by another user  
- Attempting future event edits for an event not owned by the user  

**Example `details`:**
```json
{
  "event_id": "event-uuid-001",
  "user_id": "firebase-uid-stranger"
}
```

---

### 8.4.2 `EVENT_NOT_CONFIRMED` (409)

Returned when a request assumes an event is confirmed but the event is still in a `draft` or `cancelled` state.

**Typical Causes:**
- Fetching “upcoming” events when the event is not confirmed  
- Attempting an action restricted to confirmed events (future features)  

**Example `details`:**
```json
{
  "event_id": "event-uuid-001",
  "current_status": "draft"
}
```

Cancelled events remain readable. Do not return EVENT_NOT_CONFIRMED for cancelled events.

---

### 8.4.3 `EVENT_EXPIRED` (409)

Returned when the event has already passed (`ends_at < now()`) and an action assumes it is still active.

**Typical Causes:**
- Attempting future rescheduling flows after event completion  
- Requesting details in strict modes where expired events are filtered  

**Example `details`:**
```json
{
  "event_id": "event-uuid-001",
  "ended_at": "2025-11-20T10:30:00Z"
}
```

---

### 8.4.4 `INVALID_EVENT_TIME` (400)

Returned when event time metadata is invalid.

**Typical Causes:**
- `starts_at >= ends_at`  
- Start or end timestamps not in ISO‑8601  
- Duration negative or zero (future editing flows)  

**Example `details`:**
```json
{
  "field": "starts_at",
  "value": "not-a-timestamp",
  "expected": "ISO-8601 timestamp"
}
```

Both timestamps MUST be ISO‑8601 UTC (e.g., 2025-11-20T10:00:00Z).

---

### 8.4.5 `EVENT_CREATION_DISABLED` (403)

Returned only by the placeholder `POST /events` endpoint during Phase 3.  
Indicates that standalone event creation is not yet implemented.

**Example `details`:**
```json
{
  "endpoint": "/events",
  "status": "disabled_in_phase_3"
}
```

---

<!-- Completed: P2.S2.T1.ST5.SP5 -->


 

## 9. Status

### 9.1 Document Completion Status
The API Reference is now **fully populated** for all Phase 2 requirements:
- Negotiation endpoints (**complete**)
- Event endpoints (**complete**)
- User endpoints (**complete**)
- Utility & infrastructure endpoints (**complete**)
- Error reference (**complete**, all subsections finalized)

Sections reserved for future phases (post‑MVP) are clearly marked as placeholders.

### 9.2 Stability Level
This document is now classified as **Stable – Phase 2 Complete / Phase 3 Implementation Ready**:
- All endpoint specifications are canonical.
- All data models match `02-api-contracts.md` and `04-database-schema.md`.
- No further structural changes expected before Phase 3 implementation.

### 9.3 Future Additions (Phase 4+)
The following sections will be expanded in later phases:
- Event creation (`POST /events`)
- Multi-device session management endpoints  
- Notification preference endpoints  
- Profile editing (`PUT /me`)  
- Admin endpoints (`/admin/*`)
- Account deletion (`DELETE /me`)
- Extended negotiation flows (modification/editing)

### 9.4 Handoff Readiness
This document is ready for:
- **Backend implementation** (Fastify + Zod + PostgreSQL)
- **iOS API integration** (Phase 3)
- **Schema alignment validation**
- **Error-handling integration**

### 9.5 Tag
<!-- Completed: P2.S2.T1.ST6.SP7 -->
<!-- Completed: P2.S2.T1.ST6.SP8 -->
<!-- Completed: P2.S2.GlobalSweep -->