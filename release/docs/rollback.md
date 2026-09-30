# EquiWell Deterministic Rollback Runbook

## 1. Overview & Objectives

This runbook specifies the exact, deterministic 12-step rollback procedure for the **EquiWell Enterprise Backend (`Equiwell_02`)** on Windows target environments.

When an unexpected regression, crash loop, security anomaly, or critical failure is detected following a deployment, operators must execute this procedure immediately to restore the verified previous baseline.

---

## 2. Rollback Triggers

Operators must trigger an immediate rollback if any of the following conditions persist for > 60 seconds post-deployment:

1. **Process Crash Loop:** Process fails to start or crashes repeatedly upon launch.
2. **Readiness Probe Failure:** `GET /api/v1/health/ready` returns non-`200 OK` or fails to respond.
3. **Elevated Error Rate:** HTTP `5xx` error rate exceeds `0.5%` of total incoming requests.
4. **Authentication Breakdown:** Valid JWT tokens are rejected or authentication returns persistent `500 Internal Server Error`.
5. **Data Inconsistency Detected:** Dashboard summary reports invariant violations (`total != working + broken + maintenance_required`).
6. **Port Binding Failure:** Winsock error 10048 (`WSAEADDRINUSE`) prevents socket binding.

---

## 3. The 12-Step Deterministic Rollback Procedure

```
  [1. Declare Emergency] ───> [2. Isolate Traffic] ───> [3. Terminate Process] ───> [4. Verify Port]
                                                                                            │
  [8. Verify Readiness] <─── [7. Cold Start] <─── [6. Restore Config] <─── [5. Swap Binary] ◄┘
         │
         └───> [9. Regression Suites] ───> [10. Re-introduce Traffic] ───> [11. Confirm SLA] ───> [12. Post-Mortem]
```

### Step 1: Declare Rollback & Assign Incident Commander
- Notify engineering and operations teams.
- Assign a dedicated Incident Commander to lead execution.

### Step 2: Isolate Traffic at the Reverse Proxy / Load Balancer
- Direct public traffic to a maintenance page or secondary healthy instance:
  ```powershell
  # Example: Remove node from load balancer pool or set upstream to maintenance
  ```

### Step 3: Force Terminate the Faulty Process
- Terminate the running `Equiwell_02.exe` instance:
  ```powershell
  Stop-Process -Name "Equiwell_02" -Force -ErrorAction SilentlyContinue
  ```

### Step 4: Verify TCP Port Release
- Ensure port `8080` (or configured `$env:PORT`) is completely closed and released:
  ```powershell
  Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
  ```
- *If any connection remains in `TIME_WAIT` or `CLOSE_WAIT`, wait 5 seconds and re-verify.*

### Step 5: Swap Executable with Verified Previous Release Binary
- Replace the failed executable with the archived, verified release artifact:
  ```powershell
  # Backup the failed binary for post-mortem forensics
  Copy-Item .\zig-out\bin\Equiwell_02.exe .\failed_deployment_Equiwell_02.exe -Force
  
  # Restore the verified production binary from release package
  Copy-Item .\release\Equiwell_02.exe .\zig-out\bin\Equiwell_02.exe -Force
  ```

### Step 6: Restore Previous Environment Configuration
- Revert environment variables to known-stable production values:
  ```powershell
  $env:HOST = "0.0.0.0"
  $env:PORT = "8080"
  $env:ENVIRONMENT = "production"
  $env:JWT_SECRET = "<VERIFIED_PRODUCTION_JWT_SECRET>"
  $env:DATABASE_URL = "inmemory://"
  ```

### Step 7: Perform Cold Process Startup
- Launch the verified executable:
  ```powershell
  Start-Process -FilePath ".\zig-out\bin\Equiwell_02.exe" -NoNewWindow
  ```
- *Verify startup console banner displays `EquiWell Enterprise Backend (Zig v0.17)`.*

### Step 8: Probe Liveness and Readiness Endpoints
- Poll health probe endpoints until `200 OK` is returned:
  ```powershell
  curl -s http://127.0.0.1:8080/api/v1/health/live
  curl -s http://127.0.0.1:8080/api/v1/health/ready
  ```
- Expected readiness output: `{"status":"READY","database":"connected","version":"1.0.0"}`.

### Step 9: Execute Automated Smoke & Regression Tests
- Run all test suites against the rolled-back instance:
  ```powershell
  python test_api_suite.py
  python tests/http_security_suite.py
  python tests/input_validation_security_suite.py
  python tests/concurrency_state_integrity_suite.py
  ```
- Confirm **152 / 152 Assertions Passed**.

### Step 10: Re-introduce Production Traffic
- Re-enable the backend instance in the load balancer / reverse proxy pool.
- Monitor incoming request logs in real time.

### Step 11: Monitor System Metrics for 15 Minutes
- Verify that request latency, memory usage, and HTTP status codes (`200`, `201`, `204`) are within normal operational limits.
- Confirm zero unexpected `5xx` errors.

### Step 12: Archive Incident Evidence & Conduct Post-Mortem
- Save console logs, memory dumps, and the faulty binary (`failed_deployment_Equiwell_02.exe`).
- Schedule a formal blameless post-mortem within 48 hours.

---

## 4. Rollback Verification Checklist

| Step | Action | Status | Operator Signature |
| :--- | :--- | :---: | :--- |
| 1 | Faulty process terminated and confirmed stopped | [ ] | |
| 2 | Port 8080 verified released | [ ] | |
| 3 | Verified binary (`release/Equiwell_02.exe`) in place | [ ] | |
| 4 | Environment variables restored | [ ] | |
| 5 | Startup banner verified in logs | [ ] | |
| 6 | `/api/v1/health/ready` returns `200 OK` | [ ] | |
| 7 | Full 152/152 regression suite passed | [ ] | |
| 8 | Load balancer traffic restored | [ ] | |
