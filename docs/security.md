# EquiWell Security & Role-Based Access Control Specification

## 1. Password Storage & Key Derivation

EquiWell enforces modern salted **PBKDF2-HMAC-SHA256** key derivation for password security:
- **Iteration Count:** 10,000 rounds.
- **Salt Length:** 16 cryptographic bytes.
- **Derived Key Length:** 32 bytes (256-bit).
- **Storage Format:** Standard modular crypt format:
  ```
  pbkdf2$10000$<hex_salt>$<hex_derived_key>
  ```
- **Legacy Fallback:** Transparent backward-compatible verification for historical test hashes during system upgrades.

---

## 2. JWT Authentication (RFC 7519)

- **Algorithm:** HMAC-SHA256 (`HS256`).
- **Signature Payload:**
  - `sub`: User ID (`USR-XXX`)
  - `name`: Display name
  - `email`: User email address
  - `role`: Assigned RBAC role
  - `iat`: Issued-at timestamp
  - `exp`: Expiration timestamp (default: 3600 seconds = 1 hour)
- **Secret Management:** Loaded via `JWT_SECRET` environment variable at startup, never hard-coded in source code.

---

## 3. Role-Based Access Control (RBAC) Matrix

The system implements 5 granular security roles:

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

## 4. HTTP Status Code Enforcement

- `401 Unauthorized`: Missing, invalid, or expired JWT Bearer token.
- `403 Forbidden`: Authenticated user lacks permission for the requested resource.
- `400 Bad Request`: Schema validation failure or malformed payload.
- `404 Not Found`: Target entity or route does not exist.
- `409 Conflict`: Unique constraint violation (e.g. email already registered).
