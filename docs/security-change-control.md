# EquiWell Security Change Management Policy

## 1. Zero-Regression Security Baseline

The EquiWell Enterprise Backend (`Equiwell_02`) has completed five comprehensive security audit and hardening phases (Phases 1 through 5).

Any future change to this codebase must adhere to the **Zero-Regression Principle**:
> *No modification shall weaken, bypass, degrade, or introduce regressions into any verified security control established in Phases 1 through 5.*

---

## 2. Inviolable Security Controls Summary

| Security Layer | Hardened Control | Inviolable Rules |
| :--- | :--- | :--- |
| **Phase 1: Authentication** | PBKDF2 HMAC-SHA256 & JWT HMAC-SHA256 | - Passwords hashed with PBKDF2 (10,000 iterations, 16-byte random salt, constant-time verification).<br>- JWT tokens signed with SHA-256 HMAC; secret enforced at runtime.<br>- Constant-time MAC comparison prevents timing side-channels.<br>- Strict token expiry (`exp`) enforcement. |
| **Phase 2: Authorization (RBAC)** | Role-Based Access Control Matrix | - 5 Canonical Roles: `admin`, `health_inspector`, `maintenance_crew`, `community_leader`, `viewer`.<br>- Non-registered / fallback roles strictly rejected with `400 Bad Request`.<br>- Unprivileged users cannot elevate roles or modify protected administrative resources (`403 Forbidden`).<br>- Mass-assignment protection prevents overriding sensitive fields (`id`, `role`, `created_at`). |
| **Phase 3: HTTP & Network Defense** | Socket Hardening & DoS Mitigations | - Maximum request body limit: **10 MB** (`10,485,760` bytes) checked before memory allocation.<br>- Maximum request header limit: **8 KB** (`8,192` bytes) buffer.<br>- Socket timeout: **5,000 ms** (`SO_RCVTIMEO` / `SO_SNDTIMEO`) mitigating Slowloris.<br>- Worker Pool: **16 threads** with bounded **256 queue** preventing thread-exhaustion DoS.<br>- Smuggling Defense: Conflicting `Content-Length` headers rejected with `400 Bad Request`. |
| **Phase 4: Input Validation & Integrity** | Strict Boundary & Type Enforcement | - Geographic bounds: Latitude `[-90.0, 90.0]`, Longitude `[-180.0, 180.0]`.<br>- Positive finite measurements: Depth `(0.0, 2000.0]`, Battery `[0, 100]`, Flow rate `> 0`.<br>- Strict Enums: Zero silent fallback; unknown enum values immediately return `400 Bad Request`.<br>- Strict ISO-8601 Calendar Dates: Strict calendar arithmetic rejecting impossible days (e.g. `2026-04-31`) and validating leap years (`2024-02-29` vs `2026-02-29`).<br>- Sanitized path parameters (max length 50 chars). |
| **Phase 5: Concurrency & State Integrity** | Synchronized State & Mutation Atomicity | - Thread-safe repositories protected with `std.Thread.RwLock`.<br>- Atomic counters (`std.atomic.Value`) guarantee strictly unique entity IDs under high concurrent load.<br>- Concurrent registration email race defense (atomic CAS / write lock).<br>- Strict state invariants preserved: `total_boreholes == working + broken + maintenance_required`. |

---

## 3. Mandatory Security Review Requirements

Every Change Request impacting application logic, API endpoints, request parsing, authentication, authorization, or data storage must complete the following Security Review Checklist:

### 3.1 Threat Modeling Checklist
- [ ] **STRIDE Assessment:** Evaluated for Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege.
- [ ] **Resource Allocation:** All heap allocations bounded with explicit size limits.
- [ ] **Locking & Deadlock:** Read/write lock acquire and release semantics verified; no locks held across blocking I/O.
- [ ] **Error Handling:** Errors handled gracefully with secure HTTP error codes; no stack traces or internal secrets leaked to client responses.

### 3.2 Security Regression Verification
Before merging any change, the Security Officer must verify:
```powershell
# 1. Native Zig unit tests (Crypto, JWT, Gini, MCDA, Validation)
zig test src/root.zig

# 2. HTTP Security hardening suite (18/18 PASS)
python tests/http_security_suite.py

# 3. Input Validation & Data Integrity suite (57/57 PASS)
python tests/input_validation_security_suite.py

# 4. Concurrency & Race Integrity suite (33/33 PASS)
python tests/concurrency_state_integrity_suite.py
```

---

## 4. Vulnerability Disclosure & Patch SLA

| Severity | Definition | Target Triage Time | Target Patch SLA |
| :--- | :--- | :--- | :--- |
| **CRITICAL** | Remote code execution, auth bypass, arbitrary data modification without auth. | < 2 Hours | < 24 Hours |
| **HIGH** | Privilege elevation within authenticated session, DoS crashing the server process. | < 6 Hours | < 72 Hours |
| **MEDIUM** | Information leakage of non-critical metadata, non-crashing resource exhaustion. | < 24 Hours | < 7 Days |
| **LOW** | Minor parsing inconsistencies, documentation security gaps. | < 48 Hours | < 30 Days |
