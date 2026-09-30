# Changelog

All notable changes to the EquiWell Enterprise Backend (`Equiwell_02`) are documented in this file.

---

## [1.0.0] - 2026-09-29

### Security
- Implemented modern salted PBKDF2-HMAC-SHA256 password hashing (10,000 iterations, 16-byte salt, 32-byte derived key).
- Added password length ceiling (maximum 128 characters) to prevent CPU-exhaustion DoS attacks against the PBKDF2 engine.
- Configured dynamic JWT secrets loaded via `JWT_SECRET` environment variable at startup.
- Implemented constant-time 5-tier Role-Based Access Control (`admin`, `health_inspector`, `maintenance_crew`, `community_leader`, `viewer`).

### HTTP & Network Hardening
- Replaced synchronous single-threaded socket loops with a bounded 16-worker thread pool backed by a 256-connection ring buffer and Windows OS kernel semaphore (`CreateSemaphoreW`).
- Added 5,000ms receive and send socket timeouts (`SO_RCVTIMEO` / `SO_SNDTIMEO`) to neutralize Slowloris stalled client attacks.
- Enforced hard 10 MB payload ceiling (`413 Payload Too Large`) evaluated before heap allocation.
- Enforced 8 KB header buffer limit (`431 Request Header Fields Too Large`).
- Implemented RFC-7230 compliant case-insensitive header scanning and rejected duplicate conflicting `Content-Length` headers (`400 Bad Request`) to mitigate HTTP request smuggling.
- Added standards-compliant CORS preflight handling (`OPTIONS` returning `204 No Content`).

### Input Validation & Data Integrity
- Implemented finite floating-point checks (`!std.math.isNan` and `!std.math.isInf`) on all coordinate and physical depth/flow parameters.
- Enforced strict GPS coordinate boundaries: Latitude $\in [-90, 90]$, Longitude $\in [-180, 180]$.
- Added strict Gregorian calendar date validation (`YYYY-MM-DD`) with accurate leap year rules (`2024-02-29` accepted, non-leap Feb 29 rejected, 30-day month overruns rejected).
- Enforced strict enum parsing on `pump_type`, `status`, and `urgency`, returning `400 Bad Request` on invalid inputs with zero silent fallbacks.
- Hardened user update routes against mass assignment and unauthorized privilege elevation.

### Concurrency & State Integrity
- Added atomic monotonic sequence counters (`std.atomic.Value(usize).fetchAdd`) for collision-free entity ID generation across boreholes, users, lab tests, telemetry, community requests, suggestions, and drilling logs.
- Added spinlock mutex protection (`SpinMutex` with `std.atomic.spinLoopHint`) across all database mutations and reads.
- Eliminated user registration TOCTOU races by performing uniqueness validation inside the repository mutex.
- Implemented single-pass atomic calculation in `BoreholeRepository.getSummaryStats`, strictly preserving the invariant:
  $$\text{total\_boreholes} = \text{working\_boreholes} + \text{maintenance\_required\_boreholes} + \text{broken\_boreholes}$$

### Memory Safety & Resource Management
- Enforced strict per-request `std.heap.ArenaAllocator` lifecycles that deallocate memory deterministically upon socket completion.
- Implemented deep string copying (`dupe`) into long-lived database memory for all persisted entities, preventing request-arena memory escapes and use-after-free bugs.

### Configuration
- Implemented dynamic Win32 environment variable loading in `Config.initFromEnv` for `HOST`, `PORT`, `JWT_SECRET`, `ENVIRONMENT`, `DATABASE_URL`, `GOOGLE_MAPS_API_KEY`, and `AI_WORKER_URL`.

### Testing
- Created native Zig unit tests covering JWT, PBKDF2, Gini coefficient, MCDA suitability, and validation utilities (5/5 PASS).
- Created automated HTTP & network security suite (`tests/http_security_suite.py`, 18/18 PASS).
- Created automated input validation security suite (`tests/input_validation_security_suite.py`, 57/57 PASS).
- Created automated concurrency and state integrity suite (`tests/concurrency_state_integrity_suite.py`, 33/33 PASS).
- Maintained 100% pass rate across the full 39-endpoint API integration test suite (`test_api_suite.py`, 39/39 PASS).
- Total automated test assertions verified: **152 / 152 (100.0% PASS)**.

### Documentation & Deployment
- Authored canonical Production Deployment Guide (`docs/deployment.md`).
- Authored Operations Runbook & Incident Handling Guide (`docs/operations.md`).
- Authored Automated Test Evidence Report (`docs/test-evidence.md`).
- Authored Handover Checklist (`docs/handover-checklist.md`).
- Authored Release Notes (`RELEASE_NOTES.md`).
- Synchronized OpenAPI 3.0 specification (`docs/openapi.yaml`) and Architecture specification (`docs/architecture.md`).
