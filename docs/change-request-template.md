# Change Request (CR) Template — EquiWell Backend

Use this template to submit formal Change Requests (CR) for the EquiWell Enterprise Backend (`Equiwell_02`). All sections are mandatory unless marked optional.

---

## Change Request Header

- **CR ID:** `CR-YYYYMMDD-###` *(e.g. CR-20261001-001)*
- **Title:** `[Brief Descriptive Title of the Change]`
- **Requester / Author:** `[Name and Role]`
- **Date Submitted:** `YYYY-MM-DD`
- **Target Release / Version:** `vX.Y.Z`
- **Change Category:** `[Category A: Documentation | Category B: Maintenance | Category C: Security | Category D: API Contract | Category E: Storage & State | Category F: Architectural]`
- **Risk Level:** `[LOW | MEDIUM | HIGH | CRITICAL]`

---

## 1. Executive Summary & Problem Statement

### 1.1 Problem Statement
*Describe the issue, limitation, vulnerability, or operational requirement prompting this change.*

### 1.2 Proposed Solution Summary
*High-level summary of the proposed technical remediation.*

---

## 2. Technical Scope & Affected Components

### 2.1 File & Module Modifications
List all specific source files, headers, configurations, and documentation affected:
- `[NEW | MODIFY | DELETE]` `src/path/to/file.zig`
- `[NEW | MODIFY | DELETE]` `docs/path/to/doc.md`

### 2.2 Endpoint & Interface Impact
- Does this modify existing endpoint request/response contracts? `[YES / NO]`
- If yes, provide OpenAPI / JSON contract diffs.

### 2.3 Memory & Concurrency Considerations
- Does this introduce new heap allocations or modify Arena/GPA ownership?
- Does this alter repository locks (`std.Thread.RwLock`) or state synchronization?

---

## 3. Security & Compliance Review

### 3.1 Security Control Evaluation
- **Authentication:** Does this touch JWT or PBKDF2 logic? `[YES / NO]`
- **Authorization (RBAC):** Are role permissions strictly enforced (`admin`, `health_inspector`, `maintenance_crew`, `community_leader`, `viewer`)? `[YES / NO]`
- **Input Validation:** Are input types, string lengths, coordinate bounds, enum strings, and dates validated before consumption? `[YES / NO]`
- **HTTP / Network Defense:** Does this respect the 10 MB body limit, 8 KB header limit, and 5000ms socket timeouts? `[YES / NO]`

### 3.2 Threat Model Assessment
*Describe potential attack vectors (e.g. DoS, race conditions, mass assignment, injection) and mitigation controls.*

---

## 4. Verification & Testing Plan

### 4.1 Automated Test Execution Evidence
Attach execution logs verifying the full regression gate:
- [ ] `zig test src/root.zig` (5/5 PASS)
- [ ] `zig build test` (PASS)
- [ ] `python test_api_suite.py` (39/39 PASS)
- [ ] `python tests/http_security_suite.py` (18/18 PASS)
- [ ] `python tests/input_validation_security_suite.py` (57/57 PASS)
- [ ] `python tests/concurrency_state_integrity_suite.py` (33/33 PASS)
- **Total:** 152 / 152 Assertions PASS

### 4.2 New Test Additions
*Detail any new automated tests introduced specifically for this change.*

---

## 5. Rollback Plan

### 5.1 Rollback Trigger Conditions
*Define explicit criteria that trigger an immediate rollback (e.g. process crash on startup, 5xx error rate > 0.5%, failed health readiness probe).*

### 5.2 Step-by-Step Rollback Execution
1. Stop incoming traffic at the load balancer / reverse proxy.
2. Terminate running process: `Stop-Process -Name "Equiwell_02" -Force`.
3. Restore previous verified binary: `Copy-Item .\backup\Equiwell_02.exe .\zig-out\bin\Equiwell_02.exe -Force`.
4. Restore configuration / environment variables if modified.
5. Launch previous binary and verify `/api/v1/health/ready` returns `200 OK`.
6. Execute regression test suites to confirm full operational restoration.
7. Re-enable traffic at load balancer.

---

## 6. Approvals & Sign-Off Matrix

| Role | Reviewer Name | Decision (`Approved` / `Rejected` / `Deferred`) | Signature / Date |
| :--- | :--- | :--- | :--- |
| **Lead Backend Engineer** | | | |
| **Lead Systems Architect** | | | |
| **Security Officer / Auditor** | | | |
| **Operations / DevOps Lead** | | | |

---

## 7. Post-Deployment Verification & Closure

- **Deployment Timestamp:** `YYYY-MM-DD HH:MM:SS UTC`
- **Health Check Status:** `[200 OK - READY]`
- **Error Rate Post-Launch:** `0.0%`
- **CR Final Status:** `[CLOSED - SUCCESSFUL | ROLLED BACK]`
