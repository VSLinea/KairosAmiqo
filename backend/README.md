# Kairos Backend (Fastify)

**Status:** 🚧 Not yet implemented (awaiting Phase 3)  
**Framework:** Fastify (Node.js + TypeScript)  
**Database:** PostgreSQL 16  
**Authentication:** Firebase Auth (JWT verification)

---

## Overview

The Kairos backend is a RESTful API built with Fastify that handles:
- User authentication via Firebase JWT tokens
- Negotiation lifecycle management (start, reply, state transitions)
- Database operations (PostgreSQL)
- Future: AI agent orchestration, push notifications, webhooks

**Design Philosophy:**
- **Stateless:** All state persisted in PostgreSQL
- **Token-based auth:** Firebase JWT in `Authorization: Bearer <token>` header
- **Zero legacy:** No Directus, Node-RED, or mock server dependencies
- **Type-safe:** TypeScript throughout
- **Fast & minimal:** Fastify core + essential plugins only

---

## Technology Stack

| Component         | Technology              | Purpose                              |
|-------------------|-------------------------|--------------------------------------|
| **Web Framework** | Fastify                 | HTTP server + routing                |
| **Language**      | TypeScript              | Type safety + modern syntax          |
| **Database**      | PostgreSQL 16           | Relational data storage              |
| **ORM**           | TBD (Drizzle/Prisma)    | Query builder + migrations           |
| **Auth**          | Firebase Admin SDK      | JWT token verification               |
| **Validation**    | Zod / JSON Schema       | Request/response validation          |
| **Logging**       | Pino (Fastify default)  | Structured logging                   |
| **Environment**   | dotenv                  | Config management (.env)             |

---

## Planned Directory Structure

```
backend/
├── src/
│   ├── index.ts                 # App entry point (bootstrap server)
│   ├── config/
│   │   ├── env.ts               # Environment variable validation
│   │   └── firebase.ts          # Firebase Admin SDK initialization
│   ├── middleware/
│   │   ├── auth.ts              # JWT verification middleware
│   │   ├── error-handler.ts    # Global error handler
│   │   └── logger.ts            # Request logging
│   ├── routes/
│   │   ├── negotiate.ts         # POST /negotiate/start, /negotiate/reply
│   │   └── negotiations.ts      # GET /negotiations/:id
│   ├── controllers/
│   │   ├── negotiate.controller.ts    # Business logic for negotiations
│   │   └── negotiations.controller.ts # Query logic
│   ├── services/
│   │   ├── negotiation.service.ts     # Core negotiation state machine
│   │   └── database.service.ts        # Database connection pool
│   ├── models/
│   │   ├── negotiation.ts       # Negotiation data types
│   │   ├── participant.ts       # Participant data types
│   │   └── event.ts             # Event data types
│   └── utils/
│       ├── validators.ts        # Zod schemas for request validation
│       └── errors.ts            # Custom error classes
├── migrations/
│   └── 001_initial_schema.sql   # PostgreSQL schema (Phase 3)
├── tests/
│   ├── integration/
│   │   └── negotiate.test.ts    # E2E endpoint tests
│   └── unit/
│       └── negotiation.service.test.ts
├── .env.example                 # Template for environment variables
├── package.json                 # Dependencies + scripts
├── tsconfig.json                # TypeScript config
└── README.md                    # This file
```

---

## API Endpoints (Planned)

### Authentication
All endpoints require `Authorization: Bearer <firebase_jwt_token>` header.

### Core Negotiation Endpoints

#### `POST /negotiate/start`
**Purpose:** Create a new negotiation with proposed slots and venues  
**Request Body:**
```json
{
  "intent_type": "coffee",
  "participants": ["user_id_1", "user_id_2"],
  "proposed_slots": [
    {"start": "2026-01-15T14:00:00Z", "end": "2026-01-15T15:00:00Z"}
  ],
  "proposed_venues": [
    {"poi_id": "poi_123", "name": "Blue Bottle Coffee"}
  ]
}
```
**Response:** `201 Created` with negotiation ID

---

#### `POST /negotiate/reply`
**Purpose:** Accept, counter, or decline a negotiation  
**Request Body:**
```json
{
  "negotiation_id": "uuid",
  "action": "accept",  // or "counter", "decline"
  "selected_slot_index": 0,
  "selected_venue_index": 0,
  "counter_proposals": []  // if action = "counter"
}
```
**Response:** `200 OK` with updated negotiation state

---

#### `GET /negotiations/:id`
**Purpose:** Fetch negotiation details  
**Response:**
```json
{
  "id": "uuid",
  "status": "pending",
  "initiator_id": "user_id",
  "participants": [...],
  "proposed_slots": [...],
  "proposed_venues": [...],
  "created_at": "2026-01-15T12:00:00Z",
  "updated_at": "2026-01-15T12:30:00Z"
}
```

---

## Database Schema (Planned)

### Core Tables

**`negotiations`**
- `id` (UUID, primary key)
- `initiator_id` (TEXT, Firebase UID)
- `status` (ENUM: pending, confirmed, cancelled, expired)
- `intent_type` (TEXT)
- `round` (INTEGER, default 1)
- `created_at`, `updated_at` (TIMESTAMP)

**`participants`**
- `id` (UUID, primary key)
- `negotiation_id` (UUID, foreign key)
- `user_id` (TEXT, Firebase UID)
- `role` (ENUM: initiator, invitee)
- `response_status` (ENUM: pending, accepted, declined, countered)

**`proposed_slots`**
- `id` (UUID, primary key)
- `negotiation_id` (UUID, foreign key)
- `start_time` (TIMESTAMP)
- `end_time` (TIMESTAMP)
- `proposed_by` (TEXT, Firebase UID)

**`proposed_venues`**
- `id` (UUID, primary key)
- `negotiation_id` (UUID, foreign key)
- `poi_id` (TEXT)
- `name` (TEXT)
- `proposed_by` (TEXT, Firebase UID)

**`events`**
- `id` (UUID, primary key)
- `negotiation_id` (UUID, foreign key, nullable)
- `title` (TEXT)
- `start_time` (TIMESTAMP)
- `end_time` (TIMESTAMP)
- `venue_id` (TEXT)
- `created_at`, `updated_at` (TIMESTAMP)

See `/docs/01-data-model.md` and `/docs/04-database-schema.md` for complete schema.

---

## Development Setup (Phase 3+)

**Prerequisites:**
- Node.js 20+
- PostgreSQL 16 (via Docker or local install)
- Firebase Admin SDK credentials (JSON key file)

**Install Dependencies:**
```bash
cd backend/
npm install
```

**Configure Environment:**
```bash
cp .env.example .env
# Edit .env with Firebase credentials + Postgres connection string
```

**Run Database Migrations:**
```bash
npm run migrate
```

**Start Development Server:**
```bash
npm run dev
# Server starts on http://localhost:3000
```

**Run Tests:**
```bash
npm test                  # All tests
npm run test:unit         # Unit tests only
npm run test:integration  # Integration tests only
```

---

## Environment Variables

**`.env.example` template:**
```env
# Server
PORT=3000
NODE_ENV=development

# Firebase Auth
FIREBASE_PROJECT_ID=kairos-amiqo
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-admin-key.json

# PostgreSQL
DATABASE_URL=postgresql://postgres:password@localhost:5432/kairos

# Security
JWT_AUDIENCE=kairos-amiqo-ios
ALLOWED_ORIGINS=http://localhost:3000,https://app.kairos.example

# Logging
LOG_LEVEL=info
```

---

## Development Notes

### Current Status (Phase 1)
- ✅ Directory structure planned
- ✅ Technology stack chosen
- ⏸️ No code written yet (awaiting Phase 3)
- ⏸️ Schema design in Phase 2 (documentation phase)

### Implementation Order (Phase 3)
1. **Week 1:** Fastify bootstrap + Firebase auth middleware
2. **Week 2:** Database migrations + ORM setup
3. **Week 3:** `/negotiate/start` endpoint + tests
4. **Week 4:** `/negotiate/reply` endpoint + state machine
5. **Week 5:** Integration testing + error handling

### Why Fastify?
- **Performance:** One of the fastest Node.js frameworks
- **TypeScript-first:** Native TS support, minimal boilerplate
- **Plugin ecosystem:** Auth, validation, logging built-in
- **Schema validation:** JSON Schema / Zod integration
- **Low overhead:** Minimal abstractions compared to Express

### Why Firebase Auth?
- **Proven:** Battle-tested at scale
- **Free tier:** Generous limits for MVP
- **iOS SDK:** Native support, seamless integration
- **JWT standard:** Compatible with any REST API
- **Admin SDK:** Easy server-side verification

---

## Testing Strategy

### Unit Tests
- `negotiation.service.ts`: State transition logic
- `validators.ts`: Request schema validation
- `auth.ts`: JWT verification edge cases

### Integration Tests
- Full endpoint flows (start → reply → confirm)
- Database transactions (rollback on error)
- Firebase token verification (mock/real)

### E2E Tests (Phase 5)
- iOS app → Backend → Database round-trip
- Multi-user negotiation scenarios
- Edge cases (expired tokens, invalid IDs)

---

## Where to Look Next

1. **Documentation Phase (P2):**
   - `/docs/02-api-contracts.md` — Full API specification
   - `/docs/01-data-model.md` — Data model
   - `/docs/04-database-schema.md` — Database schema
   - `/docs/01-REFERENCE/03-architecture-overview.md` — System design

2. **Implementation Phase (P3):**
   - `/backend/src/index.ts` — Start here when coding begins
   - `/backend/migrations/` — Database schema evolution

3. **Tracking:**
   - `/tracking/TRACKING.md` — Current progress + task breakdown

---

## Security Considerations

### Authentication
- ✅ Firebase JWT verification on every request
- ✅ User ID extracted from token (not from request body)
- ✅ Token expiration enforced (Firebase handles)
- ✅ HTTPS required in production

### Database
- ✅ Parameterized queries only (no SQL injection)
- ✅ User can only access their own negotiations
- ✅ Postgres row-level security (future consideration)

### Rate Limiting
- TBD: Fastify rate-limit plugin (Phase 4)

### Secrets Management
- ✅ `.env` file (local dev)
- ✅ Google Secret Manager (production)
- ❌ Never commit credentials to Git

---

**Last Updated:** November 18, 2025  
**Phase:** P1 (Repository Setup)  
**Next Milestone:** Phase 3 (Backend Implementation - Jan 2026)
