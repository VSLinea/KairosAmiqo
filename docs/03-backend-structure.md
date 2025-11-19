---
status: draft
phase: 2
document_id: P2.S1.T4
canonical: true
type: backend-structure
last_reviewed: 2025-11-18
owner: amiqlab
related:
  - /docs/00-architecture-overview.md
  - /docs/01-data-model.md
  - /docs/02-api-contracts.md
  - /tracking/TRACKING.md
---

# Kairos Amiqo — Backend Project Structure (Draft)

## Purpose

This document defines the canonical backend project structure for the Kairos Amiqo server. It describes how the Fastify backend is organized, how files are laid out, and how modules interact to deliver the API contracts defined in `docs/02-api-contracts.md`.

**Key Objectives**:
- Establish consistent organization across development, testing, CI/CD, and deployment environments
- Define the minimal backend structure required for MVP and TestFlight release
- Design for future scalability (1M+ users, multi-region deployment)
- Establish conventions for routes, controllers, services, schemas, middleware, plugins, and utilities
- Ensure alignment with API Contracts (`docs/02-api-contracts.md`), Data Model (`docs/01-data-model.md`), and Architecture Overview (`docs/00-architecture-overview.md`)

**Architectural Boundaries**:
This document clarifies the separation between:
- **Client-side responsibilities**: E2EE encryption/decryption, key management, cryptographic operations
- **Server-side responsibilities**: Storage, routing, validation, authorization, state machine enforcement

**Audience**:
- Backend developers implementing Phase 3 (Backend Implementation)
- DevOps engineers configuring deployment pipelines
- Future contributors maintaining or extending the backend
- Automation tooling (code generators, linters, CI/CD scripts)

This document serves as the authoritative reference for backend structure and must remain synchronized with implementation as the project evolves through Phase 3-5.

## Architectural Principles

The Kairos Amiqo backend follows these core architectural principles to ensure maintainability, scalability, and security:

### 1. Modularity

- Each backend concern is isolated into its own directory with clear boundaries
- Logical separation: routing → controllers → services → data layer
- **No circular dependencies**: Controllers call services; services never call controllers
- Plugin-based architecture for cross-cutting concerns (authentication, logging, metrics)
- Modules can be tested, replaced, or scaled independently

### 2. Separation of Concerns

**Routing** (`/src/routes`):
- Maps HTTP verbs and paths to controller functions
- No business logic in route definitions
- Handles HTTP-specific concerns (headers, status codes, response serialization)

**Controllers** (`/src/controllers`):
- Orchestrate request handling
- Extract and validate request parameters
- Call service layer for business logic
- Format responses using canonical envelopes

**Services** (`/src/services`):
- Implement all business logic (state transitions, validation rules, consensus detection)
- Interact with database via abstraction layer
- Return domain objects or errors (no HTTP concerns)

**Schemas** (`/src/schemas`):
- Define JSON schemas for request/response validation
- Enforce type safety at API boundaries
- Reusable across routes, tests, and documentation

**Middleware** (`/src/middleware`):
- Handle cross-cutting concerns (authentication, rate limiting, logging, CORS)
- Execute before/after route handlers
- Minimal, focused, and reusable

### 3. Stateless Backend

- Backend remains **stateless** except for PostgreSQL database
- No in-memory caches, no session stores, no sticky sessions
- All client state (UI context, encryption keys, negotiation preferences) stays on device
- Horizontal scaling requires no coordination between backend instances
- Each request is self-contained with Firebase JWT authentication

### 4. E2EE Boundary

- Server treats `encrypted_payload` and `counter_payload` fields as **opaque blobs**
- Backend **never attempts to decrypt** negotiation or event payloads
- Validation and authorization operate strictly on **metadata** (state, owner_id, participant_count, timestamps)
- Business logic (state machine, consensus detection) uses only unencrypted fields
- Logs must never contain decrypted payload content

### 5. Fail-Fast & Predictable Errors

- Input validation fails **early** using strict JSON schemas at route boundaries
- All validation errors return immediately with `400` or `422` status codes
- Business logic errors (state conflicts, authorization failures) return canonical error envelopes
- All errors follow format defined in `docs/02-api-contracts.md`
- No silent failures; every error path produces a structured response

### 6. Strict Type-Safe JSON

- Backend enforces strict JSON schemas for all request and response payloads
- No loosely typed objects or dynamic shapes allowed
- Schema validation performed by Fastify plugins before reaching controllers
- Type mismatches rejected with `400 Bad Request`
- Output serialization ensures consistent response structure

### 7. Horizontal Scalability

- Fastify instances must scale across multiple nodes without coordination
- No in-memory locks, no per-instance state, no local caching
- Database connections pooled and managed per-instance
- Ready for multi-region PostgreSQL deployment (read replicas, write leader)
- Stateless design enables autoscaling based on request load

### 8. Minimal Latency Path

- Endpoints perform only **essential work** (validation, database query, response formatting)
- No event loop blocking operations (synchronous crypto, file I/O, CPU-intensive tasks)
- Database queries optimized with indexes on critical paths (owner_id, updated_at, negotiation_id)
- Avoid N+1 queries; use batch operations where possible
- Response times target: p50 < 50ms, p99 < 200ms (excluding network latency)

### 9. Testability

- Routes, controllers, and services are **individually testable** without full server startup
- All business logic isolated in service layer for unit testing
- Controllers remain thin orchestration layers (integration tests)
- Schemas are testable independently (validate fixtures against schemas)
- Mock database layer for fast unit tests; real database for integration tests

### 10. Environment Isolation

- Local, staging, and production environments follow **identical project structure**
- No environment-specific code paths scattered in business logic
- Configuration differences handled via environment variables only
- Same Docker image deployed across all environments
- Environment-specific behavior (e.g., verbose logging) controlled by config, not code branches

## Repository Layout

The Kairos Amiqo backend resides within the monorepo under the dedicated directory:

```
KairosAmiqo/backend/
```

This placement ensures clean separation from other monorepo components (iOS app, RACAG tooling, documentation) and facilitates independent development, testing, and deployment workflows.

### Top-Level Backend Structure

```
backend/
├── src/                  # Main application source code
├── tests/                # Unit and integration tests
├── migrations/           # SQL migrations for PostgreSQL schema evolution
├── scripts/              # Utility scripts (db setup, seeding, local dev helpers)
├── package.json          # Project manifest, dependencies, npm scripts
├── tsconfig.json         # TypeScript configuration (applies in Phase 3)
├── Dockerfile            # Container build definition for production
├── docker-compose.yaml   # Optional local development stack (Postgres + backend)
└── README.md             # Backend-specific documentation entry point
```

**Design Rationale**:
- **Consistency**: Standard Node.js project layout familiar to backend developers
- **CI/CD Automation**: Predictable structure enables automated build, test, and deployment pipelines
- **Isolation**: Backend code completely separated from iOS (`ios/`), RACAG (`racag/`), and docs (`docs/`)
- **Self-Contained**: All backend concerns (code, tests, migrations, deployment) live under `backend/`

**Phase 3 Implementation**:
- Phase 3 (Backend Implementation) will generate the full folder tree and populate implementation files
- This document serves as the specification; actual directory creation deferred to Phase 3 tasks
- Structure designed to support future growth (new endpoints, additional services, advanced features)

**Key Directories**:

**`/src`**: Contains all application source code (routes, controllers, services, middleware, schemas, plugins, config). Detailed breakdown provided in the next section.

**`/tests`**: Houses unit tests (service layer, utility functions) and integration tests (full HTTP request/response flows). Mirrors `/src` structure for easy navigation.

**`/migrations`**: SQL migration files for PostgreSQL schema evolution. Each migration is versioned and applied sequentially. Managed via migration tool (e.g., `node-pg-migrate` or custom scripts).

**`/scripts`**: Utility scripts for development and operations:
- Database setup and teardown
- Test data seeding
- Local environment initialization
- Health checks and smoke tests

**`/package.json`**: Defines project metadata, dependencies (Fastify, pg, Firebase Admin SDK), and npm scripts (`start`, `dev`, `test`, `migrate`, `lint`).

**`/tsconfig.json`**: TypeScript compiler configuration. Enables strict type checking, module resolution, and build output paths. (Phase 3 may start with JavaScript and migrate to TypeScript incrementally.)

**`/Dockerfile`**: Multi-stage container build definition for production deployment. Optimized for minimal image size and fast startup.

**`/docker-compose.yaml`**: Local development stack configuration. Spins up PostgreSQL and backend service together for rapid iteration.

**`/README.md`**: Backend-specific documentation entry point. Links to canonical docs (`docs/02-api-contracts.md`, `docs/01-data-model.md`) and provides quick-start instructions for contributors.

## Fastify Project Structure

### /src

The `/src` directory contains all application source code for the Kairos Amiqo backend. It is organized into subdirectories by architectural concern: routes handle HTTP endpoints, controllers orchestrate request processing, services implement business logic, and supporting modules provide schemas, middleware, plugins, utilities, and configuration.

**Note**: Detailed specifications for each subdirectory (`/routes`, `/controllers`, `/services`, `/schemas`, `/middleware`, `/utils`, `/plugins`, `/config`) are provided in the following subsections.

### /src/routes

The `/src/routes` directory defines all HTTP endpoints (paths and verbs) exposed by the Kairos Amiqo backend. Route files perform no business logic; they solely map incoming requests to controller functions. Each route registers JSON schemas for request/response validation, ensuring type safety at API boundaries. Routes are implemented as Fastify plugins and loaded into the main server instance during application startup.

**Phase 3 Note**: Detailed route files (e.g., `negotiations.routes.js`, `events.routes.js`) will be defined during Phase 3 implementation.

### /src/controllers

The `/src/controllers` directory contains controller functions that orchestrate request handling for each API endpoint. Controllers extract validated inputs from Fastify request objects (already validated by route-registered schemas) and delegate all business logic to the service layer. They convert service results into canonical API response envelopes (success or error) and set appropriate HTTP status codes. Controllers contain no database queries, no raw SQL, and no direct data access; all persistence operations are performed by services. Controllers must never perform cryptographic operations; E2EE encryption and decryption remain strictly client-side responsibilities.

**Phase 3 Note**: Detailed controller files (e.g., `negotiations.controller.js`, `events.controller.js`) will be implemented in Phase 3.

### /src/services

The `/src/services` directory implements all business logic for negotiations and events. Services encapsulate state transitions (following the canonical state machine defined in `docs/01-data-model.md`), validation rules, consensus detection, and domain operations. They interact with PostgreSQL through a dedicated data-access layer, never writing raw SQL directly. Services have no dependencies on Fastify, routes, or controllers; they operate purely on domain objects and return structured results or errors. This isolation ensures services remain fully testable with mock database adapters, enabling fast unit tests without spinning up PostgreSQL. Services must treat encrypted payloads as opaque and perform all authorization checks on unencrypted metadata only.

**Phase 3 Note**: Detailed services (e.g., `negotiations.service.js`, `events.service.js`) will be implemented during Phase 3.

### /src/schemas

The `/src/schemas` directory contains JSON schema definitions that enforce canonical request and response structures for all API endpoints. All API payloads must validate against these schemas before reaching controller functions, ensuring type safety and early rejection of malformed input. Schemas correspond directly to the endpoint specifications defined in `docs/02-api-contracts.md`, serving as the single source of truth for API surface validation. They are shared across Fastify routes (for runtime validation), integration tests (for test fixtures), and documentation tooling (for API reference generation). Schemas contain no business logic; they perform only structural validation (field presence, types, formats, enum constraints).

**Phase 3 Note**: Detailed schema definitions will be created during Phase 3.

### /src/middleware

The `/src/middleware` directory contains Fastify middleware functions that handle cross-cutting concerns before requests reach controllers. Middleware executes in a defined order: authentication → authorization → rate limiting → request logging → error handling. Each middleware function has a single, focused responsibility and contains no business logic. Middleware operates strictly on request metadata (headers, query parameters, path parameters) and never inspects or decrypts `encrypted_payload` or `counter_payload` fields.

**Middleware Categories**:

**Authentication Middleware** (`auth.middleware.js`):
- Validates Firebase ID Token (JWT) from `Authorization: Bearer <token>` header
- Verifies JWT signature using Firebase public keys
- Validates JWT claims (`exp`, `aud`, `iss`, `sub`)
- Extracts authenticated user ID from `sub` claim and attaches to request context
- Rejects requests with missing, expired, or invalid tokens (`401 Unauthorized`)
- Must execute before all other middleware and controllers

**Authorization Middleware** (`authz.middleware.js`):
- Verifies authenticated user has permission to access requested resource
- Checks `owner_id` against authenticated user ID for ownership verification
- Validates participant access for negotiations (owner or participant only)
- Performs authorization checks on **metadata only** (never decrypts payloads)
- Returns `403 Forbidden` if authorization fails
- Applied per-route for resources requiring ownership or participant checks

**Rate Limiting Middleware** (`rateLimit.middleware.js`):
- Enforces global and per-route request rate limits
- Tracks requests by authenticated user ID (after auth middleware)
- Configurable limits (e.g., 100 requests/minute global, 10 requests/minute per negotiation endpoint)
- Returns `429 Too Many Requests` when limits exceeded
- Uses in-memory storage for MVP; Redis-backed for production scaling (Phase 4+)

**CORS Middleware** (`cors.middleware.js`):
- Configures Cross-Origin Resource Sharing headers for iOS app
- Allows requests from authorized origins only (iOS app bundle ID, staging domains)
- Sets appropriate `Access-Control-Allow-*` headers
- Handles preflight `OPTIONS` requests
- Production deployment restricts origins to known client domains

**Request Logging Middleware** (`logging.middleware.js`):
- Logs request metadata (method, path, status code, response time, user ID)
- Attaches request ID for distributed tracing
- **Must never log encrypted payloads or decrypted content**
- Logs authentication failures with sanitized error details
- Structured JSON logging format for cloud observability (Cloud Logging, Datadog)

**Error Handling Middleware** (`errorHandler.middleware.js`):
- Catches unhandled errors from routes, controllers, and services
- Converts errors to canonical error envelopes per `docs/02-api-contracts.md`
- Maps exception types to appropriate HTTP status codes and `error.code` values
- Ensures all error responses follow standard format (no HTML, no plaintext)
- Logs internal errors with full stack traces (server-side only; not sent to client)

**Design Constraints**:
- Middleware must never contain business logic (state transitions, validation rules, domain operations)
- Middleware must never inspect or decrypt `encrypted_payload` fields
- Authorization relies exclusively on unencrypted metadata (`owner_id`, `participant_count`, timestamps)
- JWT decoding and validation must complete before controller execution
- Middleware must remain stateless and horizontally scalable

**Phase 3 Note**: Detailed middleware implementations (authentication, authorization, rate limiting, CORS, logging, error handling) will be created during Phase 3.

### /src/utils

The `/src/utils` directory contains small, stateless helper modules that support the backend without owning any business logic. Utilities must be pure, side-effect free (unless explicitly documented), and fully decoupled from Fastify, routes, controllers, and services. They provide reusable building blocks for validation, timestamps, UUID handling, pagination, envelope creation, and other low-level concerns.

**Key Principles**:
- Utilities are **generic** and must not depend on domain objects
- Utilities must never access the database or external services
- Utilities must not contain negotiation logic, authorization logic, or state machine rules
- Utilities must never log encrypted content
- Utilities must remain compatible with unit testing (pure functions preferred)

**Common Utility Modules**:

**`uuid.js`**:
- Wrapper around `crypto.randomUUID()` or `nanoid`
- Generates opaque UUIDv4 identifiers for negotiations, events, and request IDs
- Guarantees consistent ID format across backend layers

**`timestamps.js`**:
- Generates canonical timestamps in ISO-8601 UTC format (`new Date().toISOString()`)
- Ensures consistent `created_at` / `updated_at` handling across controllers and services

**`envelope.js`**:
- Produces the canonical success and error envelopes defined in `docs/02-api-contracts.md`
- Ensures all responses follow a uniform structure
- Used by controllers and error-handling middleware

**`pagination.js`**:
- Provides helpers for `limit`, `offset`, and cursor-based pagination
- Ensures consistent behavior across endpoints that implement listing features

**`validation.js`**:
- Wraps small helper functions for data-shape checks (e.g., `isUUID`, `isNonEmptyArray`)
- Complements but does not replace schema validation performed by Fastify

**`logger.js`** (optional for Phase 3):
- Thin wrapper over a structured logging backend (Pino by default)
- Ensures consistent logging format and redaction rules

**Design Constraints**:
- Utilities must be dependency-free or use only standard library primitives
- Utilities must never import from `/src/services`, `/src/controllers`, or `/src/routes`
- Utilities must remain lightweight and reusable across the entire backend

**Phase 3 Note**: Utility modules will be implemented as part of backend scaffolding during Phase 3. At minimum, `uuid.js`, `timestamps.js`, and `envelope.js` will be created first to support `/negotiate/start` and `/negotiate/reply` implementation.

### /src/plugins

The `/src/plugins` directory contains Fastify plugins that extend server capabilities in a modular, reusable, and testable manner. Plugins encapsulate cross-cutting functionality that does not belong in routes, controllers, or middleware. Each plugin is implemented as an independent Fastify module and loaded at startup by the main server instance.

Plugins differ from middleware in that they:
- Integrate deeply with Fastify lifecycle hooks
- Register decorators, utilities, and shared instances
- Configure global behaviors (auth, logging, db connections)
- May register additional routes or schemas
- Are initialized in a specific load order during server startup

**Plugin Categories**:

**1. Database Plugin** (`db.plugin.js`):
- Initializes PostgreSQL connection pool using the `pg` library
- Exposes a typed `db` decorator available via `fastify.db`
- Provides helper methods for transactions, prepared statements, and query execution
- Ensures a single shared pool per Fastify instance
- Handles connection cleanup on server shutdown
- Must not contain business logic

**2. Firebase Auth Plugin** (`firebase-auth.plugin.js`):
- Initializes Firebase Admin SDK for JWT verification
- Loads Firebase project credentials on startup
- Registers `fastify.verifyJWT(token)` decorator
- Caches Firebase public keys for efficient JWT validation
- Ensures authentication middleware uses a single shared verifier
- Must never log raw tokens or decrypted content

**3. Schema Registration Plugin** (`schemas.plugin.js`):
- Registers all JSON schemas found in `/src/schemas`
- Allows routes to reference schemas by ID (`$ref`)
- Ensures consistent validation rules across all endpoints
- Enables automatic API documentation generation in future phases
- Maintains strict alignment with `docs/02-api-contracts.md`

**4. Rate Limiter Plugin** (`rate-limit.plugin.js`):
- Wraps Fastify's rate-limiting mechanisms with Kairos defaults
- Configures per-user and global limits
- Uses in-memory storage for MVP; Redis-ready for Phase 4+
- Exposes `fastify.rateLimit` decorators for middleware and controllers

**5. Logging Plugin** (`logging.plugin.js`):
- Configures Fastify's built-in logger (Pino)
- Defines redaction rules for sensitive fields (`encrypted_payload`)
- Attaches request IDs for distributed tracing
- Exposes a typed `fastify.log` decorator

**6. Error Handler Plugin** (`error-handler.plugin.js`):
- Registers the global error handler
- Converts all thrown errors to canonical API error envelopes
- Maps error types to correct HTTP status codes
- Ensures controllers and services never manually format errors
- Fired after route execution but before the response is sent

**7. Healthcheck Plugin** (`health.plugin.js`):
- Provides `/health`, `/ready`, and `/version` endpoints
- Used by cloud load balancers and orchestration systems
- Returns static OK payload for liveness checks
- Returns DB connectivity status for readiness probes

**Design Constraints**:
- Plugins must be isolated in behavior and purpose
- Plugins must not contain business logic, database schemas, or state machine rules
- Plugins must be idempotent: safe to load exactly once during startup
- Plugins must not depend on controllers, services, or routes
- Startup must fail fast if any plugin encounters configuration or connectivity errors

**Phase 3 Note**: Core plugins (`db.plugin.js`, `firebase-auth.plugin.js`, `schemas.plugin.js`, `logging.plugin.js`, and `error-handler.plugin.js`) will be implemented first. Rate limiting and healthcheck plugins may be introduced later during Phase 4.

### /src/config

The `/src/config` directory houses all configuration modules that define how the backend loads, validates, and exposes environment-specific settings (database connection, Firebase credentials, server ports, rate limits, feature flags, etc.). Configuration is centralized, strongly validated, and environment-agnostic — no config values are hardcoded in routes, controllers, services, middleware, or plugins.

**Key Principles**:
- Configuration is **pure data**, fully separated from logic
- Loaded at startup only; never mutated at runtime
- Validated using strict schema validation (Zod or custom validator)
- Exposed via a single immutable object (`config`) imported across the backend
- Never logs secrets (passwords, private keys, tokens)

**Files**:

**`env.js`**:
- Loads environment variables (`process.env`)
- Applies type coercion (numbers, booleans)
- Provides defaults only for development-safe values
- Rejects missing required variables with a startup error (fail-fast)

**`config.js`**:
- Aggregates validated values into a structured object:
  - `server.port`
  - `server.host`
  - `database.url`
  - `database.ssl`
  - `firebase.projectId`
  - `firebase.clientEmail`
  - `firebase.privateKey`
  - `rateLimit.global`
  - `rateLimit.perUser`
  - `features.*`
- Exports a frozen configuration instance used by all plugins and services

**`config.schema.js`**:
- Defines a schema (Zod recommended) that validates:
  - Required environment variables
  - Types (string, boolean, number, URL)
  - Allowed ranges (e.g., port number, rate limits)
  - Secret formatting (ensures Firebase privateKey is valid PEM)
- Prevents the server from starting with invalid configuration

**Design Constraints**:
- No sensitive values printed to logs
- No environment-specific logic in application code
- Configuration files must be dependency-free except for schema validation tools
- Configuration object must remain immutable after initialization

**Phase 3 Note**: During backend scaffolding, `/src/config` will be implemented first, as all plugins (DB, Firebase, schemas) require validated configuration before Fastify can start.

### /tests

The `/tests` directory contains all automated tests for the backend. Tests are structured to mirror the `/src` directory, ensuring a clear separation of unit, integration, and end-to-end test layers. A consistent testing strategy strengthens correctness, prevents regressions, and provides confidence during rapid iteration in Phase 3 and Phase 4.

**Test Layers**:

**1. Unit Tests**:
- Target isolated functions in `/src/services`, `/src/utils`, and `/src/middleware`
- No database, no Fastify server
- Mock dependencies explicitly
- Fastest test category; used for validation and state-machine rules

**2. Integration Tests**:
- Spin up a Fastify instance (in-memory)
- Validate full request → route → controller → service → response pipeline
- Use **test database schema** (temporary database or test schema)
- Validate JSON schema enforcement

**3. End-to-End (E2E) Tests**:
- Optional for MVP
- Use docker-composed backend + PostgreSQL + Firebase emulator
- Validate real authentication, database writes, negotiation flow behavior

**Structure Example**:
```
tests/
  unit/
    services/
    utils/
  integration/
    negotiations/
  e2e/
    full_flow.test.js
```

**Phase 3 Note**: Minimum test coverage for MVP includes:
- `/src/services/negotiations.service.js` state machine transitions
- `/src/services/events.service.js` creation rules
- Schema validation for `/negotiate/start` and `/negotiate/reply`

### /migrations

The `/migrations` directory stores versioned SQL migration files that define the evolution of the PostgreSQL schema. Migrations ensure reproducible database structure across local, staging, and production environments.

**Key Principles**:
- Each migration is a standalone, timestamped SQL file
- Migrations run sequentially and are immutable once deployed
- All schema changes (tables, indexes, enums) must be written in SQL
- No JavaScript-driven migrations (to maintain portability)

**Contents of Each Migration**:
- Create/alter/drop tables (`negotiations`, `events`, `participants`, `proposed_slots`, `proposed_venues`)
- Add or update enum types (`state`, `event_status`, `intent_category`)
- Create indexes for critical query paths
- Foreign key constraints
- Default values (timestamps, UUIDs)

**Naming Convention**:
```
20251201T120000_create_negotiations_table.sql
20251201T120500_create_events_table.sql
20251201T121000_add_negotiation_indexes.sql
```

**Phase 3 Note**: Initial migrations will implement the schema defined in `docs/01-data-model.md`. All migrations are executed via npm script (`npm run migrate`) or via docker-compose tooling.

### /scripts

The `/scripts` directory contains helper scripts that support backend development, testing, and operations. Scripts are lightweight and automate repeatable workflows for developers.

**Common Scripts**:

**`dev.sh`**:
- Starts backend in local development mode
- Loads environment variables from `.env.local`
- Runs in watch mode (auto-reload on file changes)

**`init-db.sh`**:
- Creates database schemas
- Applies migrations
- Seeds with basic test data (optional)

**`reset-db.sh`**:
- Drops and re-creates development database
- Useful during rapid iteration

**`healthcheck.sh`**:
- Sends a `/health` request to the local backend
- Verifies server is running and configuration is valid

**`lint.sh`**:
- Runs ESLint + Prettier on backend codebase

**Design Constraints**:
- All scripts must be POSIX-compatible (`sh`, not bash-isms)
- Scripts must be idempotent
- Scripts must be safe to run repeatedly
- No sensitive environment variables printed to output

**Phase 3 Note**: Core scripts (`dev.sh`, `init-db.sh`, `reset-db.sh`) will be generated automatically during backend scaffolding.

## Environment Configuration

### Environment Variables

The Kairos Amiqo backend is fully configured through environment variables, enabling strict separation between code and configuration. All environment variables must be defined explicitly and validated at startup via `/src/config/config.schema.js`. Missing or malformed variables MUST cause the server to fail fast.

Environment variables are grouped by domain:

**Server Configuration**:
- `PORT` — HTTP port Fastify binds to (e.g., 8080)
- `HOST` — Bind address (e.g., 0.0.0.0 for cloud; localhost for local dev)
- `NODE_ENV` — `development`, `staging`, or `production`
- `LOG_LEVEL` — Logging verbosity (`info`, `debug`, `warn`, `error`)

**PostgreSQL Configuration**:
- `DATABASE_URL` — Full PostgreSQL connection string
- `DATABASE_SSL` — `true` or `false` (required for cloud deployments)
- `DATABASE_POOL_MIN` — Minimum connection pool size
- `DATABASE_POOL_MAX` — Maximum connection pool size

**Firebase Authentication**:
- `FIREBASE_PROJECT_ID` — Firebase project ID
- `FIREBASE_CLIENT_EMAIL` — Email of Firebase service account
- `FIREBASE_PRIVATE_KEY` — PEM-encoded private key (escaped properly)
- `FIREBASE_TOKEN_CACHE_TTL` — TTL for JWKS cache (seconds)

**Rate Limiting**:
- `RATE_LIMIT_GLOBAL` — Global requests/minute
- `RATE_LIMIT_PER_USER` — Per-user requests/minute
- `RATE_LIMIT_BURST` — Maximum burst capacity

**Feature Flags**:
- `FEATURE_AGENT_MODE` — Enables future agent-driven negotiation mode
- `FEATURE_DEBUG_RESPONSES` — Enables additional debugging metadata for dev builds only

**Misc**:
- `REQUEST_ID_HEADER` — Custom header for external tracing systems
- `API_VERSION` — Helps with versioned routing if introduced later

**Secret Handling Requirements**:
- Secrets (database credentials, Firebase keys) must NEVER be printed to logs
- Local development may use `.env.local` but `.env` files must not be committed
- In cloud deployments, secrets must be stored in:
  - Google Secret Manager (GCP)
  - or secure platform-specific equivalents

**Phase 3 Note**: The backend will not start unless ALL required environment variables pass validation in `config.schema.js`. Validation failures must abort startup with a clear error.

### Secrets Management

Secret values (database credentials, Firebase private keys, JWT signing keys, API tokens, and internal service credentials) must be handled with the highest level of security across all environments. The backend must never hardcode secrets, commit them to the repository, or print them to logs.

The Kairos Amiqo backend defines a strict secrets-handling model:

**1. Local Development (Laptop)**:
- Secrets stored only in a local `.env.local` file
- `.env.local` is **never** committed to Git
- May be generated once through a secure onboarding script
- Access restricted to the current user account
- Must not include production credentials
- Firebase private keys must use escaped newlines (`\n`)

Example (never committed):
```
DATABASE_URL=postgres://user:pass@localhost:5432/kairos
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**2. Local Docker Development**:
- Secrets are passed via `docker-compose.yaml` using environment variables
- Never baked into images
- Docker secrets or `.env.docker` may be used but never committed

**3. Staging & Production (GCP)**:
All secrets must be stored in **Google Secret Manager**.

Required secrets include:
- PostgreSQL connection string
- Firebase service account credentials
- JWT/Tracing configuration
- Future internal service tokens (agent service, notifications)

**Access rules**:
- Only the backend service account may access secrets
- No human access in production
- Rotated regularly (Firebase private keys support rotation)

**Loading mechanism**:
- Secrets are pulled at container startup via:
  - GCP Secret Manager API (recommended)
  - or environment variables injected by Cloud Run or GKE

**4. Never Log Secrets**:
- No logs may contain:
  - DATABASE_URL
  - Firebase private keys
  - JWT tokens
  - Internal auth tokens
- Logger plugin must redact these fields automatically

**5. Never Store Secrets in Client Apps**:
- iOS app must never embed:
  - Firebase private keys
  - PostgreSQL strings
  - Backend authentication tokens
- Client uses Firebase Auth for identity; the backend uses service-level credentials only

**6. Enforcement**:
- Startup validation fails immediately if:
  - Required secrets missing
  - Invalid PEM formatting
  - Invalid URLs or connection strings
- CI checks ensure `.env*` files are blocked from commits

**Phase 3 Note**: Secret Manager integration will be implemented in `config.js` during backend scaffolding. Local development will use `.env.local`, and production deployments will exclusively rely on GCP Secret Manager.

### Local vs Cloud Configuration

The Kairos Amiqo backend must behave identically across development, staging, and production environments. The only differences between environments should be **configuration values**, never code paths. This ensures predictable behavior, stable deployments, and simplifies debugging.

Environment-specific behavior is achieved exclusively via environment variables validated in `/src/config/config.schema.js`.

**1. Local Development (Laptop)**:
- Backend runs with:
  - `npm run dev`
  - Hot-reload enabled
  - Verbose logging enabled
  - Local `.env.local` file for secrets
- PostgreSQL runs locally (Docker or native)
- Firebase Auth uses the Firebase emulator or staging keys
- No rate limiting required unless explicitly testing throttling
- Logging is verbose for developer visibility

**Local behavior constraints**:
- Never call production services
- Never connect to production databases
- Private keys must be development-only
- Local developer identity must map to a Firebase test account

**2. Local Docker Development**:
- Backend + PostgreSQL launched via `docker-compose.yaml`
- Simulates production network separation but on a developer machine
- Ideal for integration tests and reproducible environments
- Uses `.env.docker` or environment injected into the compose file

**Local Docker constraints**:
- Must behave exactly like staging/production containers
- Environment variables loaded exactly as in production
- Zero code differences compared to cloud deployment

**3. Staging Environment (Cloud)**:
- Uses GCP Secret Manager for all credentials
- Backend deployed as a container (Cloud Run or GKE)
- Connected to staging PostgreSQL instance
- Firebase staging credentials and users
- Logs routed to Google Cloud Logging
- Rate limiting enabled in staging
- Appropriate CORS restrictions for staging iOS builds

**Staging constraints**:
- Mirrors production as closely as possible
- Used for TestFlight build validation prior to public release
- Can share infrastructure resources with production but not databases

**4. Production Environment (Cloud)**:
- Fully isolated from staging and development
- Secrets stored in Google Secret Manager (production namespace)
- Production Firebase credentials
- Production PostgreSQL instance with automatic backups
- Horizontal autoscaling enabled based on request load
- Rate limiting fully enforced
- CORS restricted to official client applications/domains

**Production constraints**:
- No debug logs
- No verbose logging
- No test users
- No local file system usage
- Strict security controls for all environment variables
- Immutable deployments (build once, deploy many)

**Environment Parity Principle**:
Across all environments:
- Same backend code
- Same Docker image
- Same Fastify configuration structure
- Same middleware stack
- Same plugin structure
- Only environment variables change

This parity ensures predictable behavior and allows the backend to scale cleanly from local testing to multi-region cloud deployment.

**Phase 3 Note**: Environment switching will be implemented in `/src/config` using `NODE_ENV` and validated variable groups. Development and production use the same code paths; only `config.js` values differ.

## Development Workflow

The Kairos Amiqo backend follows a clean, predictable development workflow designed for speed, consistency, and safety. Development behavior must be identical across machines. This section describes how developers install dependencies, run the server, manage environment variables, interact with the database, and execute tests during Phase 3 implementation and beyond.

### Installation

Developers must install backend dependencies using npm:

```bash
npm install
```

Requirements:
- Node.js 20+ (LTS)
- npm 10+
- PostgreSQL client tools (`psql`) available on PATH
- Docker (optional but recommended for local DB)

After installation:
- Create a `.env.local` file
- Populate required variables based on `/src/config/config.schema.js`

### Running the Server

Local development mode:

```bash
npm run dev
```

Behavior:
- Enables hot reload via `nodemon`
- Loads environment variables from `.env.local`
- Starts Fastify on the configured `PORT`
- Uses local PostgreSQL instance (Docker or native)
- Logs are verbose (`LOG_LEVEL=debug`)

Recommended: start PostgreSQL via Docker:

```bash
docker-compose up -d postgres
```

Server startup fails fast if:
- Required env variables are missing
- Database connection fails
- Firebase credentials are invalid

### Linting & Formatting

Kairos Amiqo backend requires consistent code formatting:

```bash
npm run lint
npm run format
```

Rules:
- ESLint enforces code quality
- Prettier enforces formatting
- No unused variables
- No console.log (use Fastify logger)
- Imports must be ordered by standard convention

### Testing Strategy

Tests are executed using:

```bash
npm test
npm run test:unit
npm run test:integration
```

Workflow:
- Unit tests never require PostgreSQL
- Integration tests use a temporary schema
- E2E tests (optional) use docker-compose environment

All tests must pass before merging changes.

### Database Workflow

For local development:

```bash
npm run migrate
npm run reset-db
```

- `migrate` applies SQL migrations under `/migrations`
- `reset-db` drops and recreates local DB for clean state
- No manual SQL editing during development (schema evolves via migrations)

For inspecting DB:

```bash
psql $DATABASE_URL
```

### Environment Setup & Switching

Developers must maintain a clean separation between environments:

- `.env.local` → local development
- Cloud Run / GCP Secret Manager → staging/production
- No `.env` files committed to repo

Switch environments using:

```bash
export NODE_ENV=development
export NODE_ENV=staging
export NODE_ENV=production
```

Combined with validated configs in `/src/config`, this ensures predictable behavior and prevents configuration drift.

### Summary

The development workflow emphasizes:
- Fast iteration
- Safety through validation
- Consistent structure across machines
- Minimal surprises during onboarding
- Fail-fast behavior for invalid configurations

This workflow becomes the backbone for Phase 3 backend scaffolding and TestFlight readiness.

## Building & Deployment

The Kairos Amiqo backend must support a clean, repeatable build and deployment process that works consistently across local development, staging, and production. Builds must be deterministic, container-friendly, and aligned with the privacy-first, Firebase-authenticated architecture described in the canonical docs.

### Local Development Builds

Local development is optimized for fast iteration and debugging, not for minimal image size.

Typical workflow:

- Install dependencies:
  - `npm install`
- Start the local PostgreSQL instance (either via Docker or native):
  - e.g. `docker-compose up postgres` (Phase 3 target)
- Create `.env.local` with all required variables (see Environment Variables and Secrets Management sections).
- Run the backend in development mode:
  - `npm run dev`

Behavior in `npm run dev`:

- Uses `NODE_ENV=development`
- Enables hot-reload (via nodemon or a similar tool)
- Loads configuration from `.env.local`
- Connects to local PostgreSQL using a development-only `DATABASE_URL`
- Uses Firebase credentials suitable for development or staging
- Emits verbose logs (`LOG_LEVEL=debug`)

Build vs run relationship:

- Source of truth lives in `/src`
- Optional `npm run build` can compile TypeScript or perform preflight checks (Phase 3+)
- `npm run dev` runs directly from source during early phases, then from compiled output (`dist/`) once introduced

The key rule: development builds may be convenient, but they must never bypass validation of environment variables or authentication. Firebase JWT verification is always active, even in dev mode.

### Containerization

The backend is designed to be containerized via a Dockerfile located in the `backend/` directory. The actual Dockerfile will be implemented in Phase 3+, but the structure is defined now.

Containerization principles:

- Multi-stage build:
  - **Builder stage**:
    - Install dependencies
    - Run tests (optional but recommended)
    - Run `npm run build` once TypeScript or other compilation exists
  - **Runtime stage**:
    - Only production dependencies
    - Only compiled artifacts (e.g. `dist/`)
    - No dev tools or compilers
- Non-root execution:
  - Final image must run as a non-root user
- Configuration via environment variables only:
  - `PORT`, `NODE_ENV`, `DATABASE_URL`, Firebase config, rate limit values, etc.
- No secrets baked into the image:
  - Secrets must be provided by the runtime environment (Cloud Run / Secret Manager)

Container lifecycle (conceptual):

1. Build image locally or in CI:
   - `docker build -t kairos-backend:local .`
2. Run container with env vars:
   - `docker run --env-file .env.docker kairos-backend:local`
3. Use the same image as the base for staging/production deployments.

### Deployment Target (Cloud Run)

The primary deployment target for the Kairos Amiqo backend is **Google Cloud Run**.

Reasons:

- Fully managed container runtime
- Automatic HTTPS termination
- Autoscaling based on load
- Per-service identity (service accounts)
- Native integration with Cloud SQL and Secret Manager

Cloud Run deployment expectations:

- A CI/CD pipeline or manual build step produces:
  - `gcr.io/<project-id>/kairos-backend:<version>`
- Deployment uses:
  - `gcloud run deploy kairos-backend --image gcr.io/<project-id>/kairos-backend:<version> --region=<region> --platform=managed`
- The Cloud Run service:
  - Injects environment variables for:
    - `DATABASE_URL`
    - Firebase credentials (referencing Secret Manager)
    - Rate limiting configuration
  - Binds to a dedicated service account with:
    - Permission to read secrets
    - Permission to connect to Cloud SQL (where applicable)

Firebase JWT behavior:

- Unchanged between local and Cloud Run
- Every request includes the Firebase JWT from the iOS client
- Backend validates tokens using Firebase public keys and project ID
- No special-case "trusted network" mode in production

Ingress:

- Public HTTPS endpoints for the iOS client
- HTTP disabled at the edge; Cloud Run handles TLS
- Optional: API gateway or load balancer in front for advanced routing

### Database (Cloud SQL Postgres)

Production and staging databases are expected to use **Cloud SQL for PostgreSQL** (or an equivalent managed Postgres service).

Connection strategy:

- In early phases:
  - Simple `DATABASE_URL` connection from Cloud Run to Cloud SQL using a connection string
- In more advanced phases:
  - Cloud SQL Auth Proxy or built-in Cloud Run/Cloud SQL integration
  - Optional VPC connector to keep database off the public internet

Database behavior:

- Uses connection pooling at the Fastify/driver level
- Migrations are applied before new versions are fully promoted
- Only the backend service account can connect to production DB

Schema separation:

- Core application schema:
  - Negotiations, participants, proposed_slots, proposed_venues, events
- RACAG schema (if used on the backend later):
  - Separate namespace / tables for retrieval and embeddings
  - RACAG remains optional and loosely coupled

Migration workflow:

- Migrations live under `/migrations`
- CI or a dedicated job runs:
  - `npm run migrate` (or equivalent)
- No ad-hoc schema changes in production; everything goes through migrations

### CI/CD (Future Phase 5)

A CI/CD pipeline will be introduced in Phase 5 to automate build, test, and deploy.

Conceptual pipeline:

1. **Trigger**:
   - Push to `main` or a release branch
2. **Steps**:
   - Install dependencies
   - Run linters: `npm run lint`
   - Run tests: `npm test`
   - Build backend: `npm run build`
   - Build Docker image
   - Push image to Artifact Registry or Container Registry
3. **Deployment**:
   - Update Cloud Run service to the new image
   - Run database migrations
4. **Secrets**:
   - Pulled from GCP Secret Manager
   - No secrets stored in GitHub or CI config
5. **Rollback**:
   - Ability to roll back to the previous image version
   - Backup/restore strategy for critical migrations

TestFlight considerations:

- Staging backend must be stable and running before sending TestFlight builds to users.
- Staging environment mirrors production infrastructure but uses isolated databases and Firebase projects.

### Deployment Checklist

Before deploying a new backend version (especially one used by TestFlight clients), the following checklist must pass:

- ✅ Backend builds locally without errors (`npm run build`)
- ✅ All migrations applied to the target environment
- ✅ Cloud SQL (or equivalent Postgres) reachable from the backend
- ✅ Firebase JWT validation verified against staging/production Firebase project
- ✅ Core endpoints manually verified:
  - `POST /negotiate/start`
  - `POST /negotiate/reply`
  - `GET /negotiations/:id`
  - `/health` or `/ready` endpoint
- ✅ iOS app can authenticate and call the backend in staging mode
- ✅ Logs are visible in Cloud Logging (or equivalent), and basic metrics are available
- ✅ No secrets appear in logs, configs, or images

> Status: Section frozen for Phase 3 implementation.

## Observability

### Logging

Logging must use Fastify's built-in Pino logger with structured JSON logs. All logs are machine-readable, queryable, and designed for high-volume production environments.

**Log Fields**:
Every log entry includes:
- `request_id` — Unique identifier for request tracing
- `method` — HTTP method (GET, POST, etc.)
- `path` — Request path (e.g., `/negotiate/start`)
- `status_code` — HTTP response status
- `duration_ms` — Request duration in milliseconds
- `user_id` — Firebase UID (if authenticated)

**Redaction Rules**:
The following fields must NEVER appear in logs:
- `encrypted_payload`
- `counter_payload`
- `firebase_token`
- All secrets (DATABASE_URL, FIREBASE_PRIVATE_KEY, etc.)

Redaction is enforced automatically by the logging plugin.

**Logging Levels by Environment**:
- **development**: `debug` — verbose output for local debugging
- **staging**: `info` — request-level logs for integration testing
- **production**: `warn`/`error` — only warnings and errors to minimize noise

**Log Content Constraints**:
- Logs must never include decrypted content
- Logs must never include sensitive metadata (e.g., participant email addresses)
- Logs may include negotiation IDs, state transitions, and error codes

**Log Routing**:
- **Local**: stdout (viewable in terminal)
- **Cloud Run**: Automatic ingestion into Google Cloud Logging

**Correlation IDs**:
- Requests include a `request-id` header (generated by Fastify or passed by client)
- Correlation IDs enable end-to-end tracing across backend, database, and external services

**Use Case**:
Logs are essential for debugging negotiation state transitions (e.g., draft → active → finalized) and identifying authorization failures or validation errors.

### Metrics

The backend must expose internal metrics via a Fastify plugin. Metrics provide real-time visibility into system health, performance, and usage patterns.

**Metrics Categories**:

- **HTTP latency**: p50, p95, p99 percentiles for all endpoints
- **Request throughput**: Requests per second (RPS) overall and per endpoint
- **Negotiation creation rate**: Rate of `POST /negotiate/start` requests
- **Negotiation reply rate**: Rate of `POST /negotiate/reply` requests
- **DB query timings**: Query duration for common operations (list, fetch by ID, update)
- **Error rate by error_code**: Breakdown of validation_error, authorization_error, conflict_error, internal_error

**Integration**:
- Future integration with **Google Cloud Monitoring** (Phase 4)
- Metrics collected in-memory and exported periodically
- Prometheus-compatible format (optional)

**Privacy**:
- Metrics must NOT include encrypted payloads
- Metrics must NOT include personally identifiable information (PII)
- Aggregated only; no per-user tracking beyond error rates

**Configuration**:
- Metrics are disabled in production unless explicitly configured via environment variable (`FEATURE_METRICS=true`)
- Always enabled in development and staging for performance validation

### Error Tracking

All errors are captured by the global error handler plugin and logged with structured context for debugging and alerting.

**Error Envelope Structure**:
Errors follow the canonical envelope format defined in `docs/02-api-contracts.md`:
```json
{
  "error": {
    "code": "validation_error",
    "message": "Missing required field: state",
    "details": { "field": "state" }
  }
}
```

**Logged Fields**:
- `request_id` — Correlation ID
- `user_id` — Firebase UID (if authenticated)
- `path` — Request path
- `message` — Human-readable error message
- `stack` — Stack trace (server-only, never sent to client)

**Privacy**:
- No sensitive content (encrypted payloads, tokens, secrets) ever logged
- Error messages must not leak internal implementation details to clients

**Production-Ready Integrations**:
- **Cloud Error Reporting (GCP)**: Automatic error aggregation and alerting
- **Sentry** (Phase 4+): Optional third-party error tracking with detailed context

**Error Severity Classification**:
- `validation_error` → **warn** (client-side issue; expected)
- `authorization_error` → **warn** (permission denied; expected)
- `conflict_error` → **info** (negotiation state conflict; expected during concurrent edits)
- `internal_error` → **error** (unexpected server failure; requires investigation)

**Alerting Strategy**:
- Repeated failures (e.g., malformed Firebase tokens) must be rate-limited to prevent alert spam
- Critical errors (database connectivity, Firebase unavailable) trigger immediate alerts
- Non-critical errors (validation failures) are logged but do not trigger alerts

> Status: Section frozen for Phase 3 implementation.

## Security Considerations

### Authentication

The Kairos Amiqo backend implements a **100% Firebase JWT-based** authentication model. No session cookies, no backend-managed session state, and no alternative authentication mechanisms are supported.

**Authentication Flow**:
- iOS app obtains an ID token from Firebase Authentication
- Backend validates every incoming request (except health/readiness endpoints)
- JWT validation ensures the token is cryptographically valid and not expired

**JWT Validation Rules**:
- Signature verified against Firebase public keys (JWKS)
- Validate required claims:
  - `exp` — Token expiration timestamp (must be in the future)
  - `iat` — Issued-at timestamp (must be reasonable)
  - `aud` — Audience (must match Firebase project ID)
  - `iss` — Issuer (must match Firebase issuer URL)
  - `sub` — Subject (unique user ID)
- Reject expired or malformed tokens immediately with `401 Unauthorized`

**User Identity Extraction**:
- Backend extracts authenticated user ID from the `sub` claim
- User ID is attached to the Fastify request context for downstream use
- Backend must NEVER trust any client-supplied `user_id` field in request bodies

**Stateless Authentication**:
- No session IDs
- No cookies
- No backend-managed authentication state
- Every request is independently verified

**Middleware Execution**:
- Authentication middleware runs **before all routes** except:
  - `/health`
  - Readiness probes (e.g., `/ready`)
- Unauthenticated requests are rejected before reaching controllers or services

**Token Rotation & Caching**:
- Backend caches Firebase JWKS public keys to minimize validation latency
- JWKS cache respects TTL headers from Firebase
- Backend handles Firebase token rotation automatically

### Authorization

Authorization in the Kairos Amiqo backend is **metadata-only**. The backend never decrypts negotiation content; all authorization decisions are based on unencrypted metadata fields and Firebase-verified user identity.

**Negotiation Access Rules**:
- A user may read or reply to a negotiation if and only if:
  - The user is the negotiation `owner` (owner_id matches Firebase sub), OR
  - The user is a listed participant (user_id matches a `participants[].user_id`)
- Any other user receives `403 Forbidden`

**Event Access Rules**:
- Only the event owner may read or modify event entries
- Event ownership is derived from the originating negotiation metadata

**Centralized Authorization**:
- Authorization checks are performed in:
  - Middleware (for route-level enforcement), OR
  - Service layer (for business-logic-level enforcement)
- Authorization logic must not be duplicated across controllers

**No Trust in Client Data**:
- Authorization must never rely on client-supplied fields (e.g., `owner_id` in request body)
- All ownership and participant lists are verified against database records

**Authorization Failures**:
- Return `403 Forbidden` with canonical error envelope:
  ```json
  {
    "error": {
      "code": "authorization_error",
      "message": "You do not have permission to access this negotiation"
    }
  }
  ```

**Authorization Data Sources**:
- Unencrypted negotiation metadata (owner_id, participants)
- Firebase `sub` identity (from validated JWT)
- Database-verified object ownership

### Rate Limiting

Rate limiting is mandatory in staging and production environments to prevent abuse, spam, and resource exhaustion. The backend enforces two levels of rate limiting: global and per-user.

**Rate Limiting Levels**:

**1. Global Limit**:
- Prevents abusive traffic bursts from any source
- Applies to all authenticated endpoints
- Example: 1000 requests/minute globally

**2. Per-User Limit**:
- Prevents spam from individual authenticated accounts
- Example: 100 requests/minute per Firebase `sub`

**Rate Limiter Implementation**:
- **MVP (Phase 3)**: In-memory store (sufficient for single-instance deployments)
- **Production (Phase 4)**: Redis or Google Memorystore (for multi-instance deployments)

**Rate Limit Responses**:
- Return `429 Too Many Requests` with canonical error envelope:
  ```json
  {
    "error": {
      "code": "rate_limit_exceeded",
      "message": "Too many requests. Please try again later.",
      "details": { "retry_after_seconds": 60 }
    }
  }
  ```

**Endpoint-Specific Limits**:
- Negotiation endpoints (`/negotiate/start`, `/negotiate/reply`) require stricter limits
- Read-only endpoints (`GET /negotiations`, `GET /events`) may have more relaxed limits

**Privacy & Storage**:
- Rate limiter tracks only:
  - Request count per user ID
  - Request count per IP (optional)
- Rate limiter must NOT store sensitive request bodies or encrypted payloads

### E2EE Boundaries (Backend Perspective)

The Kairos Amiqo backend respects strict end-to-end encryption (E2EE) boundaries. All negotiation message content is encrypted client-side using AES-256-GCM (via CryptoKit on iOS), and the backend treats encrypted payloads as opaque blobs.

**E2EE Principles**:

**Backend Never Decrypts**:
- `encrypted_payload` and `counter_payload` are stored and transmitted as opaque blobs
- Backend never attempts to decrypt, parse, or inspect encrypted content
- Backend has no access to encryption keys (keys are managed client-side)

**Business Logic on Metadata Only**:
All backend operations (state transitions, consensus detection, validation) use:
- **Metadata fields**: owner_id, participant_count, state, created_at, updated_at, expires_at
- **Structural data**: participants[], proposed_slots[], proposed_venues[]
- **Never encrypted content**

**Error Messages**:
- Backend error messages must never quote or reference encrypted content
- Example: ❌ "Invalid encrypted_payload: ABC123..."
- Example: ✅ "Negotiation state transition not allowed"

**Logging**:
- Logs must never include `encrypted_payload` or `counter_payload`
- Redaction is enforced automatically by the logging plugin

**Payload Size Validation**:
- Backend may enforce maximum payload size (e.g., 10 KB) to prevent abuse
- Size validation is allowed; content inspection is not

**Future Agent Mode**:
- Future agent-driven negotiation features must also maintain E2EE boundaries
- Server-side agents may only operate on metadata and structural data
- No server-side decryption, even for agent mode

**Authorization on Metadata**:
- All authorization checks (ownership, participant membership) use unencrypted metadata
- Backend never needs to decrypt content to enforce access control

> Status: Section frozen for Phase 3 implementation.

## Status

**Document State**  
- Status: `draft` but structurally complete for Phase 2.  
- Scope: Backend structure only (Fastify + PostgreSQL + Firebase Auth).  
- This document is the canonical specification to be followed exactly in Phase 3.

**Alignment**  
Aligned with:  
- `docs/00-architecture-overview.md`  
- `docs/01-data-model.md`  
- `docs/02-api-contracts.md`  
- Canonical terminology defined in Phase 2  
No legacy Directus, Node-RED, or mock-server traces remain.

**Usage in Phase 3**  
Backend scaffolding MUST follow this structure exactly:
- `/src/config` implemented first (env loading + schema validation)
- `/src/plugins` (db, firebase-auth, schemas, logging, error-handler)
- `/src/routes`, `/src/controllers`, `/src/services` for:
  - `POST /negotiate/start`
  - `POST /negotiate/reply`
  - `GET /negotiations/:id`
- `/migrations` implementing canonical DB schema

**Change Control**  
Any structural change to backend layout REQUIRES:  
1. Updating this document first,  
2. Recording a new activity entry in `tracking/TRACKING.md`.  
Implementation must NEVER diverge from this canonical document unless the document is updated first.

