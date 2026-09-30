# EquiWell Production Deployment Guide

## 1. Requirements

### Operating System & Hardware
- **Target OS:** Windows Server 2019 / 2022 or Windows 10 / 11 (`x86_64-windows-gnu` / MSVC ABI).
- **Runtime Dependencies:** Zero external dependencies (uses native Windows `ws2_32.dll` and `kernel32.dll`).
- **Memory:** Minimum 512 MB RAM (1 GB recommended for high-throughput concurrency).
- **CPU:** Minimum 2 cores (4+ cores recommended for optimal worker pool thread scaling).

### Build Prerequisites
- **Compiler:** Zig `0.17` (e.g. `0.17.0-dev.813+2153f8143`).
- **Python (Optional, for Verification):** Python 3.8+ (standard library only).

---

## 2. Configuration & Environment Variables

All operational settings can be configured via standard OS environment variables with secure defaults:

| Environment Variable | Default Value | Description | Sensitivity |
| :--- | :--- | :--- | :---: |
| `HOST` | `127.0.0.1` | Network interface address to bind | Normal |
| `PORT` | `8080` | TCP port number for HTTP listener | Normal |
| `JWT_SECRET` | *(dynamic key)* | HMAC-SHA256 cryptographic signing secret | **CRITICAL** |
| `ENVIRONMENT` | `development` | Environment mode (`development`, `staging`, `production`) | Normal |
| `DATABASE_URL` | `inmemory://` | Storage backend connection string | Normal |
| `GOOGLE_MAPS_API_KEY`| `""` | Google Maps Directions API integration key | **HIGH** |
| `AI_WORKER_URL` | `http://127.0.0.1:5000` | Background AI siting compute worker endpoint | Normal |

### Hardened Operational Limits
- **Maximum Request Body:** 10 MB (`10,485,760` bytes) evaluated before heap allocation.
- **Maximum Request Headers:** 8 KB (`8,192` bytes) buffer capacity.
- **Socket Timeouts:** 5,000 ms (`SO_RCVTIMEO` and `SO_SNDTIMEO`) for Slowloris mitigation.
- **Worker Thread Pool:** 16 worker threads processing a 256-socket bounded ring buffer.

---

## 3. Build Procedure

To compile the release candidate binary:

```powershell
# Clean release build with safety checks enabled
zig build -Doptimize=ReleaseSafe

# Alternatively, for maximum performance in production:
zig build -Doptimize=ReleaseFast
```

The compiled binary will be placed at:
```text
zig-out/bin/Equiwell_02.exe
```

---

## 4. Run & Execution

### Setting Environment Variables (PowerShell)
```powershell
$env:HOST = "0.0.0.0"
$env:PORT = "8080"
$env:ENVIRONMENT = "production"
$env:JWT_SECRET = "production-cryptographic-random-secret-key-min-32-chars-long!"
$env:GOOGLE_MAPS_API_KEY = "AIzaSyProductionKeyExample"
```

### Starting the Server
```powershell
.\zig-out\bin\Equiwell_02.exe
```

Expected startup console banner:
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

## 5. Health Checks & Probes

The backend provides three dedicated health probes for orchestrators (Kubernetes / Windows Services / Load Balancers):

| Probe Path | HTTP Method | Expected Status | Purpose |
| :--- | :---: | :---: | :--- |
| `/api/v1/health` | `GET` | `200 OK` | General service health check |
| `/api/v1/health/live` | `GET` | `200 OK` | Process liveness probe |
| `/api/v1/health/ready` | `GET` | `200 OK` | Dependency and repository readiness probe |

---

## 6. Shutdown Procedure

### Interactive Console
- Press `Ctrl + C` in the running terminal.

### Process Management / Windows Service
```powershell
# Graceful process termination via PowerShell
Stop-Process -Name "Equiwell_02" -Force
```
Upon shutdown, the listener socket is closed immediately and the bounded worker threads terminate safely.

---

## 7. Verification & Smoke Testing

To verify the running release candidate:

```powershell
# Run the 39-endpoint integration test suite
python test_api_suite.py

# Run the HTTP & network security hardening suite
python tests/http_security_suite.py

# Run the input validation and data integrity suite
python tests/input_validation_security_suite.py

# Run the concurrency and state integrity suite
python tests/concurrency_state_integrity_suite.py
```

Expected output: **152 / 152 Passed (100% Success Rate)**.

---

## 8. Troubleshooting

### 1. `SocketBindFailed` / Port Already in Use
- **Cause:** Another process is bound to port `8080`.
- **Remedy:** Check active listeners using `Get-NetTCPConnection -LocalPort 8080` and terminate the conflicting process or change `$env:PORT`.

### 2. `WinsockInitFailed`
- **Cause:** Failure initializing Windows Socket Subsystem.
- **Remedy:** Verify Windows networking stack and TCP/IP service (`wuauserv`, `netman`).

### 3. Missing `JWT_SECRET` in Production
- **Cause:** Environment variable not exported.
- **Remedy:** Export a secure random string (minimum 32 characters) in `$env:JWT_SECRET`.

---

## 9. Security Best Practices

1. **Protect Production Secrets:** Never commit production `JWT_SECRET` or API keys to version control.
2. **Reverse Proxy & TLS:** Deploy behind an enterprise reverse proxy (e.g., IIS, Caddy, NGINX, or Cloudflare Tunnel) terminating TLS 1.3 on HTTPS port 443.
3. **Firewall & Port Exposure:** Expose only ports 443/80 to public clients. Keep internal orchestration ports restricted to the internal VPC/subnet.
4. **Credential Rotation:** Rotate `JWT_SECRET` keys periodically in accordance with corporate security policy.
