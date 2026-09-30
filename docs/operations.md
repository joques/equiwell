# EquiWell Operations Runbook & Maintenance Guide

## 1. Process Startup

### Starting the Production Service
To start the EquiWell backend on Windows:

```powershell
# Set production environment variables
$env:HOST = "0.0.0.0"
$env:PORT = "8080"
$env:ENVIRONMENT = "production"
$env:JWT_SECRET = "<YOUR_PRODUCTION_JWT_SECRET>"
$env:GOOGLE_MAPS_API_KEY = "<YOUR_GOOGLE_MAPS_KEY>"

# Launch the executable
.\zig-out\bin\Equiwell_02.exe
```

Expected startup banner output:
```text
=======================================================
  EquiWell Enterprise Backend (Zig v0.17)
  Listening on http://0.0.0.0:8080
  API Base: /api/v1 (Canonical) + Legacy Root
  Worker Pool: 16 Threads (Bounded Capacity 256)
  Max Request Body: 10 MB | Socket Timeout: 5000ms
  Architecture: Modular Layered Clean Enterprise
=======================================================
```

---

## 2. Health Monitoring & Probes

Operators and orchestrators (e.g. Kubernetes, Windows Service Monitors, Load Balancers) can query the following health endpoints:

### Liveness Probe
```bash
curl -s http://127.0.0.1:8080/api/v1/health/live
```
**Expected Response:** `200 OK`
```json
{"status":"UP","checks":{"service":"equiwell-api","uptime":"OK"}}
```

### Readiness Probe
```bash
curl -s http://127.0.0.1:8080/api/v1/health/ready
```
**Expected Response:** `200 OK`
```json
{"status":"READY","database":"connected","version":"1.0.0"}
```

### Metrics Scrape Probe (CR-001)
```bash
curl -s http://127.0.0.1:8080/api/v1/metrics
```
**Expected Response:** `200 OK` (JSON snapshot of atomic counters, latency, uptime, and throughput). See `docs/observability.md` for full schema details.

---

## 3. Failure Detection & Status Codes

| Symptom / Status Code | Likely Root Cause | Operator Remediation |
| :--- | :--- | :--- |
| `SocketBindFailed` on startup | Port `8080` already occupied by another process. | Run `Get-NetTCPConnection -LocalPort 8080` to locate and terminate the conflicting process or change `$env:PORT`. |
| `WinsockInitFailed` on startup | Windows Socket subsystem initialization error. | Verify TCP/IP stack health and restart Windows networking service. |
| `401 Unauthorized` | Missing, expired, or signature-invalid JWT Bearer token. | Verify client authentication credentials and token expiration (`exp`). |
| `403 Forbidden` | Authenticated user lacks required RBAC role. | Verify user role in JWT claims against the required endpoint role in `docs/security.md`. |
| `400 Bad Request` | Malformed JSON, out-of-range coordinates, invalid enum, or invalid date format. | Inspect client request payload against OpenAPI schema in `docs/openapi.yaml`. |
| `413 Payload Too Large` | Request body exceeds hard limit of 10 MB. | Ensure clients do not send oversized bulk payloads exceeding 10 MB. |
| `431 Request Header Fields Too Large` | Request header section exceeds 8 KB. | Reduce header sizes and cookie sizes sent by client. |
| `503 Service Unavailable` | Worker pool queue saturation (256 queued connections). | Scale horizontally behind an enterprise load balancer. |

---

## 4. Safe Restart Procedure

When performing maintenance or updating configuration:

1. **Stop Incoming Traffic:** Temporarily remove the instance from the load balancer pool.
2. **Terminate Process:**
   ```powershell
   Stop-Process -Name "Equiwell_02" -Force
   ```
3. **Verify Port Release:**
   ```powershell
   Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
   ```
4. **Update Configuration / Binary:** Update environment variables or executable binary.
5. **Start Process:** Run `.\zig-out\bin\Equiwell_02.exe`.
6. **Verify Readiness:** Check `GET /api/v1/health/ready` returns `200 OK`.
7. **Resume Traffic:** Re-enable the instance in the load balancer pool.

---

## 5. Secret & Credential Rotation

### Rotating the JWT Secret Key
1. Generate a secure 32+ character random string.
2. Update the `$env:JWT_SECRET` environment variable in the deployment environment.
3. Restart the backend process following the Safe Restart Procedure.
4. *Note:* Existing tokens signed with the previous secret will be invalidated; active users will need to log in again.

### Rotating External API Keys
1. Update `$env:GOOGLE_MAPS_API_KEY` with the newly generated API key from Google Cloud Console.
2. Restart the process to apply the updated environment variable.

---

## 6. Log Review Guidelines

Operators should periodically monitor console output and standard error streams:
- **`[INFO]`**: Normal request routing, lifecycle milestones, and worker pool operations.
- **`[WARN]`**: Minor unexpected input or non-critical recoverable conditions.
- **`[ERROR]`**: Failed socket operations, database allocation errors, or unhandled exceptions.

---

## 7. Incident Handling Procedure

In the event of an operational anomaly:
1. **Preserve Logs:** Capture active console logs and recent system event logs.
2. **Record Timestamp:** Note the exact UTC timestamp of the incident.
3. **Identify Endpoint:** Determine which specific route (`/api/v1/...`) experienced the anomaly.
4. **Identify HTTP Status:** Note the returned HTTP status code (`500`, `503`, `400`, `401`, `403`).
5. **Determine Authentication Context:** Check whether the request was authenticated and note the caller's role.
6. **Isolate Component:** Determine whether the failure originated in networking, service logic, or an external adapter.
7. **Restart Carefully:** If memory corruption or deadlock is suspected, execute the Safe Restart Procedure.
8. **Preserve Evidence:** Retain logs, request payloads, and timestamps for post-incident review.
