# EquiWell Security & Role-Based Access Control Specification

## 1. Authentication & Key Derivation

### PBKDF2-HMAC-SHA256 Password Storage
EquiWell enforces modern salted **PBKDF2-HMAC-SHA256** key derivation for password security:
- **Iteration Count:** 10,000 rounds.
- **Salt Length:** 16 cryptographic bytes.
- **Derived Key Length:** 32 bytes (256-bit).
- **Storage Format:** Standard modular crypt format:
  ```text
  pbkdf2$10000$<hex_salt>$<hex_derived_key>
  ```
- **Password Constraints:** Minimum 8 characters, maximum 128 characters (eliminates computational PBKDF2 CPU-exhaustion DoS attacks).
- **Migration Fallback:** Transparent backward-compatible verification for historical hashes during phased upgrades.

### JWT Session Tokens (RFC 7519)
- **Algorithm:** HMAC-SHA256 (`HS256`).
- **Signature Payload:**
  - `sub`: Unique User ID (`USR-001`)
  - `name`: Full display name
  - `email`: User email address
  - `role`: Canonical RBAC role
  - `iat`: Issued-at Unix timestamp
  - `exp`: Expiration Unix timestamp (default: 3600 seconds = 1 hour)
- **Secret Management:** Dynamically loaded via `JWT_SECRET` environment variable at startup, never hard-coded in source code.

---

## 2. Role-Based Access Control (RBAC) Matrix

The system enforces 5 distinct roles via constant-time enum dispatch tables:

| API Action / Domain | `admin` | `health_inspector` | `maintenance_crew` | `community_leader` | `viewer` |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **View Dashboard & Factors** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **View Public Boreholes** | ✅ | ✅ | ✅ | ✅ | ✅ (Visible only) |
| **Create / Update Boreholes** | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Delete Boreholes** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Manage Users & Roles** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Record Water Lab Tests** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **View Lab Tests & Quotas** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Ingest IoT Telemetry** | ✅ | ❌ | ✅ | ❌ | ❌ |
| **View Alerts & History** | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Submit Community Request** | ✅ | ❌ | ❌ | ✅ | ❌ |
| **Calculate Logistics Routes**| ✅ | ❌ | ✅ | ❌ | ❌ |
| **Run AI Yield Prediction** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Ingest Geological Logs** | ✅ | ❌ | ✅ | ❌ | ❌ |

---

## 3. HTTP & Network Defense Controls

- **Bounded Worker Pool:** 16 worker threads processing a 256-slot ring buffer backed by Windows OS kernel semaphore (`CreateSemaphoreW` / `WaitForSingleObject`). Prevents thread exhaustion and thread-bombing attacks.
- **Socket Timeouts:** 5,000 ms read and write socket timeouts (`SO_RCVTIMEO` and `SO_SNDTIMEO`) neutralize Slowloris and incomplete HTTP stream attacks.
- **Payload Ceiling:** Hard 10 MB (`10,485,760 bytes`) limit checked on `Content-Length` before heap buffer allocation (`413 Payload Too Large`).
- **Header Limits:** 8 KB (`8,192 bytes`) buffer capacity (`431 Request Header Fields Too Large`).
- **Request Smuggling Mitigation:** Case-insensitive header parser detects and rejects conflicting duplicate `Content-Length` headers (`400 Bad Request`).
- **CORS Handling:** Standards-compliant preflight `OPTIONS` handling returning `204 No Content` with configurable `Access-Control-Allow-*` headers.

---

## 4. Input Validation & Data Integrity Controls

- **Finite Floating-Point Enforcement:** Numeric inputs (coordinates, depths, concentrations, flow rates) are strictly validated with `!std.math.isNan(x) && !std.math.isInf(x)`.
- **Geographic Coordinate Validation:** Latitude must reside in `[-90.0, 90.0]`, Longitude in `[-180.0, 180.0]`.
- **Gregorian Calendar & Leap Year Validation:** ISO 8601 `YYYY-MM-DD` strings are strictly checked for valid month lengths and leap years (`2024-02-29` accepted, `2025-02-29` and `2026-02-29` rejected, `2026-04-31` rejected).
- **Strict Enum Matching:** Invalid enum strings return `400 Bad Request` immediately without silent fallback to defaults.
- **Mass Assignment Immunity:** Modifying user profiles via `PUT /users/{id}` strictly whitelists editable fields (`name`, `email`), ignoring `role` and `id` tampering.

---

## 5. Concurrency & State Integrity

- **Repository Spinlock Mutex:** In-memory tables are protected by an atomic spinlock with `std.atomic.spinLoopHint()` to prevent CPU starvation.
- **Atomic Monotonic Sequences:** Store entities generate strictly unique identifiers concurrently via `std.atomic.Value(usize).fetchAdd(1, .monotonic)`, eliminating ID collisions.
- **Registration Race Isolation:** Uniqueness check for email registration executes inside the repository mutex lock, eliminating Time-of-Check to Time-of-Use (TOCTOU) races.
- **Single-Pass Snapshot Consistency:** Dashboard statistics are calculated under a single mutex lock, enforcing the invariant:
  $$\text{total\_boreholes} = \text{working\_boreholes} + \text{maintenance\_required\_boreholes} + \text{broken\_boreholes}$$
- **Arena Memory Isolation:** Each HTTP request executes inside an ephemeral `std.heap.ArenaAllocator` that is completely freed upon socket completion. Persistent records are deep-copied into database allocator memory, guaranteeing zero use-after-free.

---

## 6. Secret Management & Production Hardening

- **No Hardcoded Secrets:** Production environments must set `JWT_SECRET` via environment variables.
- **Third-Party Keys:** External integration credentials (e.g. `GOOGLE_MAPS_API_KEY`) must be supplied via environment variables.
- **TLS Termination:** The server operates as a plaintext HTTP socket server; production traffic must be fronted by a reverse proxy terminating TLS 1.3 on port 443.
