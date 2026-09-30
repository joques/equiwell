# EquiWell Maintenance Register & Technical Debt Backlog

## 1. Overview & Purpose

This register documents known architectural constraints, technical debt items, and maintenance progress for the **EquiWell Enterprise Backend (`Equiwell_02`)**.

All items listed below are managed under formal Change Request (CR) governance.

---

## 2. Technical Debt & Maintenance Register

### Item M-01: Persistent Storage Backend Integration
- **Category:** Category E (Storage & State)
- **Status:** BACKLOG / PLANNED
- **Current State:** The backend operates with high-performance, thread-safe in-memory repositories protected by `std.Thread.RwLock` and atomic counters. State resets upon process termination unless external backups are used.
- **Target Enhancement:** Introduce SQLite or PostgreSQL database adapters conforming to the existing repository interfaces (`user_repository.zig`, `borehole_repository.zig`).
- **Target Release:** `v1.2.0`
- **Priority:** MEDIUM
- **Dependencies:** Requires persistent schema migration scripts and transactional ACID integration tests.

---

### Item M-02: Reverse Proxy & Automated TLS 1.3 Termination
- **Category:** Category B (Maintenance)
- **Status:** PLANNED
- **Current State:** EquiWell operates as a zero-dependency HTTP server on Winsock TCP. TLS termination is handled by an enterprise reverse proxy (Caddy / NGINX / IIS) or Cloudflare Tunnel.
- **Target Enhancement:** Provide standardized Docker Compose and Caddyfile configurations with automated Let's Encrypt TLS certificate provisioning.
- **Target Release:** `v1.1.1`
- **Priority:** HIGH (Operational Deployment)
- **Dependencies:** None.

---

### Item M-03: External AI Worker & Google Maps Circuit Breaker
- **Category:** Category D (API Contract & Resiliency)
- **Status:** BACKLOG / PLANNED
- **Current State:** Siting tasks and logistics directions use asynchronous task IDs and fallback algorithms when external services are unreachable.
- **Target Enhancement:** Implement an active circuit breaker pattern (Closed -> Open -> Half-Open) with exponential backoff and jitter for external HTTP calls to `$env:AI_WORKER_URL` and Google Maps API.
- **Target Release:** `v1.2.0`
- **Priority:** MEDIUM
- **Dependencies:** Thread-safe circuit breaker state tracking.

---

### Item M-04: Windows Service Daemonization & Lifecycle Management
- **Category:** Category B (Maintenance)
- **Status:** PLANNED
- **Current State:** Executable runs via console or PowerShell process runner.
- **Target Enhancement:** Bundle native Windows Service wrapper scripts (e.g. using NSSM or Windows Service API) enabling auto-restart on failure, scheduled restarts, and Windows Event Log forwarding.
- **Target Release:** `v1.1.1`
- **Priority:** LOW
- **Dependencies:** PowerShell administration scripts.

---

### Item M-05: Centralized Metrics & Observability Subsystem (CR-001)
- **Category:** Category B / Category D
- **Status:** **COMPLETED (CR-001)**
- **Implemented State:** High-performance, lock-free metrics engine (`src/observability/metrics.zig`) with 18 atomic counters, monotonic latency timing (Win32 QPC), byte counters, active connection tracking, and JSON endpoints (`/metrics`, `/api/v1/metrics`). Fully verified with 14 automated observability assertions (100% PASS).
- **Target Release:** `v1.1.0-rc1`
- **Priority:** COMPLETED

---

## 3. Maintenance Item Review Schedule

The Maintenance Register is reviewed bi-weekly by the Lead Systems Architect and Security Officer during sprint planning to evaluate which items qualify for formal Change Request (CR) prioritization.
