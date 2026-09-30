# EquiWell: Enterprise Groundwater Management Platform

[![Language](https://img.shields.io/badge/Language-Zig%200.17-orange.svg)](https://ziglang.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20POSIX-blue.svg)]()
[![Security](https://img.shields.io/badge/Security-5--Tier%20RBAC%20%2B%20JWT-green.svg)]()
[![Tests](https://img.shields.io/badge/Tests-39%2F39%20Passing%20(100%25)-brightgreen.svg)]()

**EquiWell** is an intelligent, high-performance spatial decision-support and groundwater infrastructure management platform engineered for arid and semi-arid rural communities—with initial deployment focused on the **Kunene Region of Namibia**.

---

## 1. System Architecture

EquiWell uses a **Clean / Layered Enterprise Architecture** with strict separation between HTTP transport, business logic services, storage repositories, domain calculations, and external adapters:

```
HTTP Request / Client
         ↓
┌──────────────────────────────────────────────┐
│  Server & Transport Layer (src/server/)      │
│  - TCP listener (ws2_32 / POSIX)             │
│  - Request / Response models & HTTP parser   │
│  - Middleware Pipeline (Auth, CORS, Logs)    │
│  - Router (/api/v1/ and legacy compatibility)│
└──────────────────────┬───────────────────────┘
                       ↓
┌──────────────────────────────────────────────┐
│  Route Controllers (src/routes/)             │
│  - JSON parameter validation & decoding      │
│  - Delegates directly to Services            │
└──────────────────────┬───────────────────────┘
                       ↓
┌──────────────────────────────────────────────┐
│  Business Services (src/services/)           │
│  - Domain rules, lifecycle coordination      │
│  - Interacts with Repositories & Adapters    │
└───────────┬──────────────────────┬───────────┘
            ↓                      ↓
┌────────────────────────┐ ┌───────────────────┐
│ Domain Logic           │ │ Integrations      │
│ (src/domain/)          │ │ (src/integrations)│
│ - Hydrogeology (MCDA)  │ │ - Google Maps API │
│ - ML Yield Prediction  │ │ - AI Worker Queue │
│ - Gini Equity Indices  │ │ - IoT Telemetry   │
│ - Aquifer Depletion    │ └───────────────────┘
│ - Terrain Feasibility  │
└────────────────────────┘
            ↓
┌──────────────────────────────────────────────┐
│  Repositories (src/repositories/)            │
│  - Storage interfaces isolating persistence  │
└──────────────────────┬───────────────────────┘
                       ↓
┌──────────────────────────────────────────────┐
│  Database Layer (src/database/)              │
│  - In-memory concurrent store with Mutex     │
│  - Kunene Region test fixtures               │
│  - Migrations engine abstraction             │
└──────────────────────────────────────────────┘
```

---

## 2. Directory Structure

```text
Equiwell/
│
├── build.zig                     # Declarative Zig 0.17 build configuration
├── build.zig.zon                 # Package metadata manifest
├── .gitignore                    # Git exclusions
├── README.md                     # This documentation
├── LICENSE                       # Project license
│
├── docs/                         # Canonical project documentation
│   ├── openapi.yaml              # Canonical OpenAPI 3.0 specification
│   ├── architecture.md           # Architecture design document
│   └── security.md               # RBAC matrix and security specifications
│
├── src/                          # Native Zig source code
│   ├── main.zig                  # Lean application bootstrapper
│   │
│   ├── app/                      # Application container
│   │   └── application.zig       # Dependency injection container
│   │
│   ├── config/                   # Global configuration
│   │   └── config.zig            # Environment variable loader
│   │
│   ├── errors/                   # Error handling
│   │   └── api_error.zig         # Standardized error codes & status mapping
│   │
│   ├── observability/            # Logging, metrics, tracing
│   │   ├── logger.zig            # Structured logger
│   │   ├── metrics.zig           # Performance counters
│   │   └── tracing.zig           # Request tracing ID generator
│   │
│   ├── auth/                     # Security & access control
│   │   ├── password.zig          # PBKDF2-HMAC-SHA256 salted password KDF
│   │   ├── jwt.zig               # RFC-7519 HMAC-SHA256 JWT manager
│   │   ├── permissions.zig       # Granular domain permissions
│   │   └── rbac.zig              # Centralized RBAC checks
│   │
│   ├── models/                   # Domain data entities
│   │   ├── user.zig              # User, UserRole
│   │   ├── borehole.zig          # Borehole, PumpType, BoreholeStatus
│   │   ├── health.zig            # LabTest, UsageQuota
│   │   ├── telemetry.zig         # TelemetryRecord, MaintenanceAlert
│   │   ├── allocation.zig        # AllocationMetric
│   │   ├── logistics.zig         # LogisticsAccessibility, RouteResponse
│   │   ├── community.zig         # CommunityRequest
│   │   └── ai.zig                # SitingSuggestion, YieldPrediction, Task
│   │
│   ├── domain/                   # Pure domain calculation algorithms
│   │   ├── hydrogeology/         # MCDA scoring, yield, depletion simulation
│   │   ├── equity/               # Gini coefficient & water stress formulas
│   │   └── terrain/              # 20-ton drilling rig terrain physics
│   │
│   ├── repositories/             # Storage abstraction layer
│   │   ├── user_repository.zig
│   │   ├── borehole_repository.zig
│   │   ├── lab_repository.zig
│   │   ├── telemetry_repository.zig
│   │   ├── allocation_repository.zig
│   │   └── community_repository.zig
│   │
│   ├── database/                 # Persistence engines
│   │   ├── database.zig          # Concurrent in-memory store with Mutex
│   │   ├── migrations.zig        # Migration runner placeholder
│   │   └── seed.zig              # Kunene Region fixture seeding
│   │
│   ├── integrations/             # External system adapters
│   │   ├── google_maps.zig       # Google Maps Directions API & URL builder
│   │   ├── ai_worker.zig         # Distributed AI compute client
│   │   └── iot.zig               # Smart water meter telemetry adapter
│   │
│   ├── services/                 # Business logic services
│   │   ├── user_service.zig
│   │   ├── borehole_service.zig
│   │   ├── health_service.zig
│   │   ├── telemetry_service.zig
│   │   ├── maintenance_service.zig
│   │   ├── allocation_service.zig
│   │   ├── community_service.zig
│   │   ├── logistics_service.zig
│   │   └── ai_service.zig
│   │
│   ├── routes/                   # Route controllers
│   │   ├── user_routes.zig
│   │   ├── dashboard_routes.zig
│   │   ├── borehole_routes.zig
│   │   ├── health_routes.zig
│   │   ├── maintenance_routes.zig
│   │   ├── allocation_routes.zig
│   │   ├── logistics_routes.zig
│   │   └── ai_routes.zig
│   │
│   ├── server/                   # HTTP transport & routing
│   │   ├── server.zig            # TCP listener & connection lifecycle
│   │   ├── router.zig            # Method/path matching (/api/v1/)
│   │   ├── request.zig           # HTTP request parser & query decoder
│   │   ├── response.zig          # HTTP response formatter
│   │   ├── middleware.zig        # Middleware pipeline (auth, rbac)
│   │   └── cors.zig              # CORS headers provider
│   │
│   └── utils/                    # Common utilities
│       ├── validation.zig        # Email, coordinate validators
│       ├── ids.zig               # Standardized ID formatting
│       ├── datetime.zig          # Date/time helpers
│       └── json.zig              # JSON parsing helpers
│
├── tests/                        # Test suites
│   ├── unit/                     # Unit tests (auth, Gini, MCDA, validation)
│   ├── integration/              # Service + Repository tests
│   └── e2e/                      # Application lifecycle tests
│
└── test_api_suite.py             # 39-test automated integration suite (100% pass)
```

---

## 3. Getting Started & Running

### Requirements
- **Zig Compiler:** Version `0.17`
- **Python:** `3.8+` (for automated test suite runner)
- **Target OS:** Windows (with native Winsock `ws2_32`) / POSIX compatible

### Building the Server
```bash
zig build
```

### Running the Server
```bash
./zig-out/bin/Equiwell_02.exe
```
The server will start listening on `http://127.0.0.1:8080`.

### Running Native Zig Unit Tests
```bash
zig test src/root.zig
```

### Running the 39-Test Integration Suite
While the server is running:
```bash
python test_api_suite.py
```

---

## 4. Configuration

All configuration properties support runtime environment variables with safe defaults:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `HOST` | `127.0.0.1` | Network interface to bind socket |
| `PORT` | `8080` | TCP port number |
| `JWT_SECRET` | *(dynamic secret)* | HMAC-SHA256 cryptographic signing key |
| `ENVIRONMENT` | `development` | Environment mode (`development`, `staging`, `production`) |
| `DATABASE_URL`| `inmemory://` | Storage backend connection string |
| `GOOGLE_MAPS_API_KEY` | `""` | Key for Google Maps Directions API integration |
| `AI_WORKER_URL` | `http://127.0.0.1:5000` | Background AI compute cluster URL |

---

## 5. Security & RBAC Roles

The system enforces 5 distinct roles via RFC-7519 JSON Web Tokens:
1. **`admin`**: Full system administration, role management, and asset deletion.
2. **`health_inspector`**: Water potability certificates, *E. coli*/chemical lab tests, and extraction quotas.
3. **`maintenance_crew`**: IoT sensor telemetry, repair dispatch tickets, yield histories, and drilling logs.
4. **`community_leader`**: Traditional authority emergency intervention requests.
5. **`viewer`**: Read-only public transparency access.

---

## 6. API Endpoints Catalog (`/api/v1/`)

| Method | Canonical Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/health` | Service health status probe | Public |
| `GET` | `/api/v1/health/live` | Process liveness probe | Public |
| `GET` | `/api/v1/health/ready` | Dependency readiness probe | Public |
| `GET` | `/api/v1/dashboard/summary` | Aggregate dashboard summary metrics | Public |
| `POST` | `/api/v1/users/register` | Register a new user | Public |
| `POST` | `/api/v1/users/login` | Login and receive JWT token | Public |
| `GET` | `/api/v1/users` | List all users | `admin` |
| `GET` | `/api/v1/users/{id}` | Get user profile | Authenticated |
| `PUT` | `/api/v1/users/{id}` | Update user profile | Authenticated |
| `PATCH` | `/api/v1/users/{id}/role` | Elevate user role | `admin` |
| `DELETE` | `/api/v1/users/{id}` | Delete user | `admin` |
| `GET` | `/api/v1/boreholes` | Query boreholes with filters | Public |
| `POST` | `/api/v1/boreholes` | Register new borehole | `admin`, `crew` |
| `GET` | `/api/v1/boreholes/{id}` | Get borehole details | Public |
| `PUT` | `/api/v1/boreholes/{id}` | Update borehole specs | `admin` |
| `PATCH` | `/api/v1/boreholes/{id}` | Patch status / visibility | `admin`, `crew` |
| `DELETE` | `/api/v1/boreholes/{id}` | Delete borehole | `admin` |
| `POST` | `/api/v1/boreholes/{id}/lab-tests` | Record water quality certificate | `admin`, `health` |
| `GET` | `/api/v1/boreholes/{id}/lab-tests` | Get lab test history | `admin`, `health` |
| `GET` | `/api/v1/boreholes/{id}/usage-quotas` | Get monthly usage quota | `admin`, `health` |
| `POST` | `/api/v1/boreholes/{id}/telemetry` | Ingest IoT sensor data | `admin`, `crew` |
| `GET` | `/api/v1/maintenance-alerts` | List repair alerts | `admin`, `crew` |
| `GET` | `/api/v1/boreholes/{id}/history` | Get yield history | `admin`, `crew` |
| `GET` | `/api/v1/allocation-metrics` | Get Gini equity metrics | Public |
| `GET` | `/api/v1/community-requests` | List community requests | `admin`, `leader` |
| `POST` | `/api/v1/community-requests` | Submit community request | `admin`, `leader` |
| `GET` | `/api/v1/boreholes/{id}/logistics` | Get terrain & logistics profile | `admin`, `crew` |
| `POST` | `/api/v1/routes/calculate` | Calculate transit route | `admin`, `crew` |
| `POST` | `/api/v1/routes/google-maps-directions` | Generate Google Maps navigation link | `admin`, `crew` |
| `GET` | `/api/v1/factors` | Get spatial MCDA factor weights | Public |
| `POST` | `/api/v1/suggestions/generate` | Generate AI siting recommendation | Non-Viewer |
| `GET` | `/api/v1/suggestions/{id}` | Get siting recommendation | Public |
| `POST` | `/api/v1/ai/predict-yield` | ML yield inference | Non-Viewer |
| `POST` | `/api/v1/ai/aquifer-depletion-risk` | Aquifer depletion simulation | Non-Viewer |
| `POST` | `/api/v1/ai/siting-tasks/async` | Dispatch async siting task | Non-Viewer |
| `GET` | `/api/v1/tasks/{id}` | Query async task status | Public |
| `POST` | `/api/v1/callbacks/ai/siting-complete` | Webhook callback for AI worker | Public |
| `POST` | `/api/v1/ai/training-data/borehole-logs` | Ingest empirical drilling logs | `admin`, `crew` |
| `POST` | `/api/v1/ai/training-data/yield-maps` | Ingest GIS yield raster layers | `admin`, `crew` |
| `POST` | `/api/v1/ai/routes/terrain-feasibility` | Assess drilling rig terrain feasibility | Non-Viewer |

---

## 7. Documentation & Handover Index

For comprehensive engineering specifications, runbooks, and test evidence, refer to:
- **[Architecture Specification](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/architecture.md):** Clean layered architecture, component flow, concurrency, and memory isolation.
- **[Security & RBAC Specification](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/security.md):** PBKDF2 key derivation, JWT RFC 7519, 5-tier RBAC matrix, and DoS defenses.
- **[Production Deployment Guide](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/deployment.md):** Production runbook, build commands, environment variables, and health probes.
- **[Operations & Maintenance Guide](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/operations.md):** Day-2 operations, failure detection, secret rotation, and incident handling.
- **[OpenAPI 3.0 Specification](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/openapi.yaml):** Canonical API schemas, endpoints, request bodies, and response codes.
- **[Automated Test Evidence](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/test-evidence.md):** Complete evidence report for all 152 automated test assertions (100% pass).
- **[Handover Checklist](file:///c:/Users/Rauna/Desktop/Equiwell%2002/docs/handover-checklist.md):** Engineering release verification and sign-off tracking.
- **[Release Notes](file:///c:/Users/Rauna/Desktop/Equiwell%2002/RELEASE_NOTES.md):** Release 1.0.0 highlights, build metadata, and architectural advisories.
- **[Changelog](file:///c:/Users/Rauna/Desktop/Equiwell%2002/CHANGELOG.md):** Historical hardening and security milestone changelog.
