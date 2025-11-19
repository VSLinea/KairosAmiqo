# Kairos Amiqo

**Privacy-first AI assistant for social planning**

> **Status:** Under active development (Phase 1 - Repository Restructure)  
> **Target:** Clean-slate monorepo with Fastify backend + SwiftUI iOS app  
> **Launch:** Q1 2026

---

## Overview

Kairos Amiqo is a privacy-first mobile application that simplifies social planning through AI-driven autonomous negotiation. Users can create plans, invite friends, and let their personal AI agents handle scheduling details while maintaining end-to-end encryption.

**Core Principles:**
- **Privacy by design:** Zero-knowledge architecture with E2EE
- **Autonomous negotiation:** AI agents negotiate on behalf of users
- **Minimal friction:** "Set it and forget it" experience
- **Cross-platform:** iOS-first, Android planned

---

## Monorepo Structure

```
KairosAmiqo/
├── backend/          # Fastify REST API (Node.js + TypeScript)
├── ios/              # SwiftUI iOS application
├── docs/             # Architecture & API documentation
├── racag/            # Retrieval-Augmented Coding Agent (dev tooling)
├── infra/            # Infrastructure configs (Postgres, Docker)
├── scripts/          # Build, migration, deployment scripts
├── tests/            # Integration & E2E test suites
├── tracking/         # Project tracking & progress logs (TRACKING.md)
├── .gitignore        # Monorepo-wide ignore rules
└── README.md         # This file
```

---

## Technology Stack

### Backend
- **Framework:** Fastify (Node.js)
- **Language:** TypeScript
- **Database:** PostgreSQL
- **Authentication:** Firebase Auth (JWT)
- **API Style:** REST
- **Deployment:** Google Cloud Run (planned)

### iOS App
- **Framework:** SwiftUI
- **Language:** Swift 5.9+
- **Architecture:** MVVM (ObservableObject)
- **Concurrency:** async/await + @MainActor
- **Networking:** URLSession + Codable
- **Security:** CryptoKit (AES-256-GCM E2EE)
- **Minimum iOS:** 17.0+

### Infrastructure
- **Database:** PostgreSQL 16
- **Orchestration:** Docker Compose (dev), GCP (prod)
- **CI/CD:** GitHub Actions (planned)

### Developer Tools
- **RACAG:** Retrieval-Augmented Coding Agent (semantic code search)
- **Version Control:** Git + GitHub
- **IDE:** Xcode (iOS), VS Code (backend)

---

## Development Philosophy

### Clean Slate Approach
This monorepo represents a **complete architectural reset** from previous iterations. We are building from the ground up with:
- No legacy dependencies (Directus, Node-RED, mock servers removed)
- Clear separation of concerns (backend, frontend, tooling)
- Documentation-first design (contracts before implementation)
- Test-driven development (E2E scenarios defined upfront)

### Phase-Based Delivery
Development follows a strict phased approach:
1. **Phase 1:** Repository purge & reset (current)
2. **Phase 2:** Documentation rewrite (canonical specs)
3. **Phase 3:** Backend implementation (Fastify API)
4. **Phase 4:** iOS refactor (new API integration)
5. **Phase 5:** Integration, deployment, TestFlight

See [`/tracking/TRACKING.md`](./tracking/TRACKING.md) for detailed task breakdown.

---

## Getting Started

### For Developers

**1. Review Project Status:**
```bash
cat tracking/TRACKING.md
```

**2. Understand the Architecture:**
- Read `/docs/` for canonical architecture specifications
- Review API contracts in `/docs/02-api-contracts.md`

**3. Set Up Local Environment:**

**Backend (Fastify):**
```bash
cd backend/
npm install
cp .env.example .env
npm run dev
```

**iOS (Xcode):**
```bash
cd ios/
open KairosAmiqo.xcodeproj
# Build and run in Xcode (Cmd+R)
```

**Database (Postgres):**
```bash
docker compose up -d postgres
# Migrations will be in backend/migrations/ (Phase 3)
```

---

## Project Tracking

**Primary Source of Truth:** [`/tracking/TRACKING.md`](./tracking/TRACKING.md)

All tasks, stages, and progress are tracked in the canonical tracking document using the `P.S.T.ST.SP` hierarchy:
- **P** = Phase
- **S** = Stage
- **T** = Task
- **ST** = Step
- **SP** = Substep

**Current Status:** Phase 1 (P1) - Repository Purge & Reset

---

## Architecture Highlights

### Authentication Flow
1. User signs in via Firebase Auth (iOS)
2. iOS app obtains Firebase JWT token
3. Token sent in `Authorization: Bearer <token>` header
4. Fastify backend verifies token with Firebase Admin SDK
5. User ID extracted from token for all database operations

### Negotiation Flow
1. User creates plan (iOS) → `POST /negotiate/start`
2. Backend creates negotiation record + proposed slots/venues
3. Participants receive notifications (push/email)
4. Participants reply (accept/counter) → `POST /negotiate/reply`
5. Backend manages state transitions (pending → confirmed → event)
6. AI agents handle autonomous negotiation (Phase 4+)

### End-to-End Encryption (E2EE)
- **Agent preferences:** Encrypted client-side, stored as blobs
- **Agent messages:** Encrypted with AES-256-GCM
- **Key management:** CryptoKit + iOS Keychain
- **Server:** Zero-knowledge (cannot read encrypted data)

---

## Security & Privacy

**Core Commitments:**
- ✅ End-to-end encryption for sensitive data
- ✅ Firebase Auth for secure user identity
- ✅ No third-party analytics (self-hosted only)
- ✅ Minimal data collection (no PII in logs)
- ✅ GDPR-compliant (user can delete all data)
- ✅ Open-source roadmap (transparency)

**Threat Model:**
- Assumes server is semi-trusted (malicious admin scenario)
- Assumes network is untrusted (TLS required)
- Assumes device is trusted (user controls iOS Keychain)

---

## Contributing

**Current Status:** Not accepting external contributions during Phase 1-3 (core architecture definition).

Once TestFlight launches (Phase 5), we will open contributions for:
- Bug fixes
- Performance improvements
- Feature requests (via GitHub Issues)

---

## Roadmap

| Phase | Focus                  | Status       | Target     |
|-------|------------------------|--------------|------------|
| P1    | Repository Reset       | 🔄 In Progress | Nov 2025   |
| P2    | Documentation Rewrite  | 📋 Planned    | Dec 2025   |
| P3    | Backend Implementation | 📋 Planned    | Jan 2026   |
| P4    | iOS Refactor           | 📋 Planned    | Feb 2026   |
| P5    | TestFlight Launch      | 📋 Planned    | Mar 2026   |

See [`/tracking/TRACKING.md`](./tracking/TRACKING.md) for granular task breakdown.

---

## License

**Proprietary** - All rights reserved (for now)  
Open-source licensing TBD post-launch.

---

## Contact

**Project Lead:** Lyra  
**Repository:** [github.com/VSLinea/KairosMain](https://github.com/VSLinea/KairosMain)  
**Issues:** Use GitHub Issues (once public)

---

**Last Updated:** November 18, 2025  
**Tracking Version:** 1  
**Monorepo Version:** Phase 1 (Clean Slate)
