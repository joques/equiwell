# EquiWell Backend Architecture Specification

## 1. Executive Overview

**EquiWell** is an enterprise-oriented, high-performance spatial decision-support and groundwater asset lifecycle management platform designed for the **Kunene Region of Namibia**.

The backend is built in **Zig (v0.17)**, delivering memory-safe, ultra-low latency, zero-dependency socket networking optimized for edge gateways and cloud deployment alike.

---

## 2. Layered Architecture

EquiWell follows a strict **Clean / Layered Architectural Pattern** ensuring separation of concerns:

```
HTTP Request / TCP Client
           ↓
┌────────────────────────────────────────┐
│  Server & Networking Layer (server/)   │
│  - TCP socket listener (ws2_32 / POSIX)│
│  - HTTP parser (Request / Response)    │
│  - Middleware chain (Auth, CORS, Logs) │
│  - Centralized Router (/api/v1/)       │
└──────────────────┬─────────────────────┘
                   ↓
┌────────────────────────────────────────┐
│  Route Controllers Layer (routes/)     │
│  - HTTP status & parameter decoding    │
│  - Delegating to domain services       │
└──────────────────┬─────────────────────┘
                   ↓
┌────────────────────────────────────────┐
│  Business Services Layer (services/)   │
│  - Business logic & lifecycle rules    │
│  - Coordinates repos & calculations    │
└────────┬───────────────────┬───────────┘
         ↓                   ↓
┌─────────────────┐ ┌────────────────────┐
│ Domain Modules  │ │  External Adapters │
│ (domain/)       │ │  (integrations/)   │
│ - MCDA factors  │ │  - Google Maps API │
│ - ML yield      │ │  - AI Worker Queue │
│ - Gini metrics  │ │  - IoT telemetry   │
│ - Depletion     │ └────────────────────┘
│ - Feasibility   │
└─────────────────┘
         ↓
┌────────────────────────────────────────┐
│  Repository Layer (repositories/)      │
│  - Storage interfaces & data access    │
└──────────────────┬─────────────────────┘
                   ↓
┌────────────────────────────────────────┐
│  Database Layer (database/)            │
│  - Thread-safe storage with Mutex      │
│  - Kunene Region seed fixtures         │
│  - Migration engine abstraction        │
└────────────────────────────────────────┘
```

---

## 3. Directory Layout & Module Responsibilities

| Subsystem | Path | Description |
| :--- | :--- | :--- |
| **Bootstrapper** | `src/main.zig` | Minimal 15-line application entry point. |
| **Application** | `src/app/application.zig` | Dependency injection container wiring config, DB, repos, services, and server. |
| **Server** | `src/server/` | Socket listener, request/response models, middleware, CORS, and route dispatcher. |
| **Auth & Security** | `src/auth/` | Salted PBKDF2-HMAC-SHA256 password KDF, RFC-7519 JWT, and 5-tier RBAC matrix. |
| **Data Models** | `src/models/` | Strongly-typed business entities (User, Borehole, LabTest, Telemetry, etc.). |
| **Domain Logic** | `src/domain/` | Pure hydrogeology algorithms (MCDA, Yield, Depletion), Gini equity metrics, and terrain physics. |
| **Repositories** | `src/repositories/` | Storage abstraction isolating business logic from in-memory/PostgreSQL backends. |
| **Database** | `src/database/` | Thread-safe concurrent storage engine, atomic spinlocks, and Kunene seed data. |
| **Integrations** | `src/integrations/` | Adapters for Google Maps Directions API, background AI workers, and IoT sensors. |
| **Services** | `src/services/` | Application business logic, validation, and domain orchestration. |
| **Routes** | `src/routes/` | HTTP serialization and endpoint handlers. |
| **Observability** | `src/observability/` | Structured logger, latency metrics, and request tracing. |
| **Utilities** | `src/utils/` | Validation helpers, entity ID generators, date/time, and JSON parsers. |

---

## 4. API Endpoints Summary (`/api/v1/`)

All production endpoints are standardized under the canonical `/api/v1/` prefix while supporting backward-compatible legacy routes:

- **Health Probes:** `GET /api/v1/health`, `GET /api/v1/health/live`, `GET /api/v1/health/ready`
- **Dashboard:** `GET /api/v1/dashboard/summary`
- **Users:** `POST /api/v1/users/register`, `POST /api/v1/users/login`, `GET /api/v1/users`, `GET /api/v1/users/{id}`, `PUT /api/v1/users/{id}`, `PATCH /api/v1/users/{id}/role`, `DELETE /api/v1/users/{id}`
- **Boreholes:** `GET /api/v1/boreholes`, `POST /api/v1/boreholes`, `GET /api/v1/boreholes/{id}`, `PUT /api/v1/boreholes/{id}`, `PATCH /api/v1/boreholes/{id}`, `DELETE /api/v1/boreholes/{id}`
- **Health:** `POST /api/v1/boreholes/{id}/lab-tests`, `GET /api/v1/boreholes/{id}/lab-tests`, `GET /api/v1/boreholes/{id}/usage-quotas`
- **Maintenance:** `POST /api/v1/boreholes/{id}/telemetry`, `GET /api/v1/maintenance-alerts`, `GET /api/v1/boreholes/{id}/history`
- **Allocation:** `GET /api/v1/allocation-metrics`, `GET /api/v1/community-requests`, `POST /api/v1/community-requests`
- **Logistics:** `GET /api/v1/boreholes/{id}/logistics`, `POST /api/v1/routes/calculate`, `POST /api/v1/routes/google-maps-directions`
- **AI & Hydrogeology:** `GET /api/v1/factors`, `POST /api/v1/suggestions/generate`, `GET /api/v1/suggestions/{id}`, `POST /api/v1/ai/predict-yield`, `POST /api/v1/ai/aquifer-depletion-risk`, `POST /api/v1/ai/siting-tasks/async`, `GET /api/v1/tasks/{id}`, `POST /api/v1/callbacks/ai/siting-complete`, `POST /api/v1/ai/training-data/borehole-logs`, `POST /api/v1/ai/training-data/yield-maps`, `POST /api/v1/ai/routes/terrain-feasibility`
