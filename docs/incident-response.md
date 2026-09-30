# EquiWell Incident Response Playbooks

## 1. Severity Levels & SLA Matrix

| Severity | Definition | Target Response Time | Target Resolution SLA | Escalation Path |
| :--- | :--- | :--- | :--- | :--- |
| **SEV-1 (Critical)** | Production outage, complete API unavailability, auth bypass, data corruption, or active exploit. | < 15 Minutes | < 2 Hours | Lead Architect + Security Officer + Operations Lead |
| **SEV-2 (High)** | Degradation of core features (e.g. telemetry ingestion failing, elevated 500 error rate > 1%, Slowloris starvation). | < 30 Minutes | < 6 Hours | Lead Backend Engineer + Operations Lead |
| **SEV-3 (Medium)** | Non-critical feature degradation (e.g. external AI worker unavailable, Google Maps latency high). | < 2 Hours | < 24 Hours | Backend Engineering On-Call |
| **SEV-4 (Low)** | Minor cosmetic or documentation issues, isolated client input errors. | < 8 Hours | Next Release Cycle | Issue Tracker Backlog |

---

## 2. Dedicated Incident Playbooks

### Playbook 1: `JWT_SECRET` Key Compromise or Mass Token Revocation
- **Symptoms:** Unauthorized API calls with forged tokens, suspicious administrative actions, or credential leakage reported.
- **Immediate Action Steps:**
  1. Generate a new high-entropy 64-character secret key:
     ```powershell
     $NewSecret = [Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))
     ```
  2. Set `$env:JWT_SECRET = $NewSecret` on the production server.
  3. Execute Safe Restart:
     ```powershell
     Stop-Process -Name "Equiwell_02" -Force
     Start-Process -FilePath ".\zig-out\bin\Equiwell_02.exe" -NoNewWindow
     ```
  4. All existing tokens are immediately invalidated; clients will receive `401 Unauthorized` and must re-authenticate.
  5. Audit user accounts and revoke any suspicious accounts created during the incident window.

---

### Playbook 2: In-Memory State Corruption / Invariant Violation
- **Symptoms:** Dashboard returns status counts where `total_boreholes != working + broken + maintenance_required`, or entity lookups fail inconsistently.
- **Immediate Action Steps:**
  1. Query `/api/v1/health/ready` to evaluate repository state.
  2. If state inconsistency is confirmed, initiate safe cold restart to re-initialize deterministic state.
  3. Replay recent mutation transaction logs / external backups if persistent database adapter is active.
  4. Run `python tests/concurrency_state_integrity_suite.py` to confirm state invariants are preserved.

---

### Playbook 3: HTTP Worker Pool Saturation / Connection Exhaustion
- **Symptoms:** Client requests return `503 Service Unavailable`, connection timeouts, or socket queue capacity (256) exceeded.
- **Immediate Action Steps:**
  1. Inspect network traffic to identify source IPs generating high-volume concurrent connections.
  2. Apply firewall / reverse proxy IP throttling or rate limiting at edge (e.g. Cloudflare / Caddy).
  3. Verify that socket timeouts (`5000ms`) are actively disconnecting stalled clients.
  4. If load is legitimate traffic spike, scale instances horizontally behind the reverse proxy.

---

### Playbook 4: External AI Worker Outage / Siting Task Failure
- **Symptoms:** `POST /api/v1/ai/siting-tasks/async` completes, but background computation worker times out or returns `502 Bad Gateway`.
- **Immediate Action Steps:**
  1. Inspect status of external AI worker at `$env:AI_WORKER_URL` (default `http://127.0.0.1:5000`).
  2. Verify that EquiWell returns non-blocking `202 Accepted` and handles task failure callbacks gracefully.
  3. Restart external AI Python worker process if unresponsive.
  4. Fall back to internal deterministic MCDA scoring algorithms if external compute is offline.

---

### Playbook 5: Google Maps API Outage / Key Expiration / Quota Exhaustion
- **Symptoms:** `POST /api/v1/logistics/directions` returns simulated routing or error status due to invalid Google Maps key.
- **Immediate Action Steps:**
  1. Check Google Cloud Console API quota and billing status for Maps Directions API.
  2. Generate new API key or replenish quota.
  3. Update `$env:GOOGLE_MAPS_API_KEY` and execute safe restart.
  4. Verify that EquiWell's built-in fallback distance algorithm continues serving approximate logistics routes without crashing.

---

### Playbook 6: Winsock Error 10048 (`WSAEADDRINUSE`) on Startup
- **Symptoms:** Server logs `SocketBindFailed` upon startup.
- **Immediate Action Steps:**
  1. Identify the conflicting process holding port 8080:
     ```powershell
     Get-NetTCPConnection -LocalPort 8080 | Format-Table OwningProcess, State
     ```
  2. Terminate the orphan process:
     ```powershell
     Stop-Process -Id <PID> -Force
     ```
  3. Re-launch `Equiwell_02.exe` and confirm clean binding.

---

## 3. Incident Post-Mortem & Review Process

Within 48 hours of resolving any SEV-1 or SEV-2 incident, the Incident Commander must produce a formal Post-Mortem Report covering:
1. **Incident Timeline:** Detailed chronology from detection to resolution.
2. **Root Cause Analysis (5 Whys):** Technical underlying defect or operational gap.
3. **Impact Assessment:** User requests affected, downtime duration, data integrity status.
4. **Corrective Actions:** Specific Jira/Git issues created to prevent recurrence.
5. **Documentation Updates:** Runbook or architectural documentation improvements.
