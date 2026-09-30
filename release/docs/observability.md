# EquiWell Observability & Operational Metrics Guide

## 1. Overview & Architecture

The EquiWell Enterprise Backend (`Equiwell_02`) includes a high-performance, native, zero-dependency observability and metrics engine implemented in `src/observability/metrics.zig`.

All metrics collection uses **lock-free atomic primitives** (`std.atomic.Value`) and **monotonic clock timings** (via Windows `QueryPerformanceCounter`), ensuring zero heap allocations on request recording hot paths and complete immunity to wall-clock time skew or race conditions.

---

## 2. Exposed Metrics Endpoints

Operational metrics are accessible via standard HTTP GET endpoints:

| Endpoint | Method | Authentication | Response Content-Type | Purpose |
| :--- | :---: | :---: | :---: | :--- |
| `/metrics` | `GET` | Optional / Proxy Gateway | `application/json` | Primary metrics scrape endpoint |
| `/api/v1/metrics` | `GET` | Optional / Proxy Gateway | `application/json` | Canonical API base metrics endpoint |

> [!NOTE]
> In production environments, `/metrics` should be protected or scraped internally via an authenticated management interface or enterprise reverse proxy (Caddy / NGINX / IIS).

---

## 3. Metrics Schema & Counter Definitions

A sample JSON snapshot returned by `GET /api/v1/metrics`:

```json
{
  "uptime_seconds": 1845,
  "total_requests": 1520,
  "successful_requests": 1490,
  "client_error_requests": 28,
  "server_error_requests": 2,
  "authentication_failures": 12,
  "authorization_denials": 6,
  "validation_failures": 10,
  "rate_or_security_rejections": 4,
  "active_requests": 0,
  "peak_active_requests": 16,
  "average_latency_ms": 0.4521,
  "total_request_duration_ms": 687.1920,
  "total_request_bytes": 142850,
  "total_response_bytes": 624190,
  "worker_tasks_completed": 1520,
  "worker_tasks_failed": 0,
  "queue_rejections": 0
}
```

### Detailed Field Descriptions

| Metric Field | Type | Unit | Description |
| :--- | :---: | :---: | :--- |
| `uptime_seconds` | `u64` | seconds | Total continuous process runtime derived from monotonic clock. |
| `total_requests` | `u64` | count | Total count of all incoming TCP socket requests processed. |
| `successful_requests` | `u64` | count | Count of HTTP `2xx` responses (`200 OK`, `201 Created`, `202 Accepted`, `204 No Content`). |
| `client_error_requests` | `u64` | count | Count of HTTP `4xx` responses (`400`, `401`, `403`, `404`, `413`, `431`). |
| `server_error_requests` | `u64` | count | Count of HTTP `5xx` responses (`500 Internal Error`, `503 Service Unavailable`). |
| `authentication_failures` | `u64` | count | Count of HTTP `401 Unauthorized` responses (missing, malformed, or expired JWT). |
| `authorization_denials` | `u64` | count | Count of HTTP `403 Forbidden` responses (insufficient RBAC role permissions). |
| `validation_failures` | `u64` | count | Count of HTTP `400 Bad Request` responses due to malformed JSON, date/range bounds, or invalid enums. |
| `rate_or_security_rejections` | `u64` | count | Count of requests rejected by security gates (`413 Payload Too Large`, `431 Header Too Large`, smuggling duplicate `Content-Length`, or `503` queue saturation). |
| `active_requests` | `u64` | gauge | Current in-flight requests currently being processed across worker threads. |
| `peak_active_requests` | `u64` | gauge | Monotonically recorded historical maximum number of simultaneous active requests. |
| `average_latency_ms` | `f64` | ms | Cumulative average server processing duration per request. |
| `total_request_duration_ms` | `f64` | ms | Cumulative wall-clock processing time aggregated across all requests. |
| `total_request_bytes` | `u64` | bytes | Total raw incoming HTTP bytes received on the wire. |
| `total_response_bytes` | `u64` | bytes | Total raw outgoing HTTP bytes transmitted on the wire. |
| `worker_tasks_completed` | `u64` | count | Count of worker thread tasks completed without unhandled exceptions. |
| `worker_tasks_failed` | `u64` | count | Count of worker thread tasks that encountered unhandled connection exceptions. |
| `queue_rejections` | `u64` | count | Count of incoming client connections rejected due to worker pool queue capacity saturation (256). |

---

## 4. Health vs. Metrics Separation

EquiWell strictly separates **Service Health Probes** from **Operational Metrics**:

```
+-----------------------------------------------------------------------------------------+
|                               HEALTH VS. METRICS SEPARATION                             |
+-----------------------------------------------------------------------------------------+
| Endpoint             | Purpose                          | Response Characteristic       |
+-----------------------------------------------------------------------------------------+
| /api/v1/health/live  | Process Liveness Probe           | Ultra-lightweight JSON (UP)   |
| /api/v1/health/ready | Dependency & Repository Readiness| Checks DB state (READY)       |
| /api/v1/metrics      | Diagnostic Observability Data    | Full atomic metrics snapshot  |
+-----------------------------------------------------------------------------------------+
```

---

## 5. Security & Isolation Guarantees

1. **Zero Secret Leakage:** Metrics contain strictly numerical aggregates. Secrets, passwords, JWT tokens, hashes, API keys, Authorization headers, and request bodies are never stored, parsed into metrics, or exposed.
2. **Fixed Cardinality:** Metric keys are static compile-time constants. No user-controlled query strings or request headers are dynamically used as metric labels, eliminating metric-cardinality DoS attacks.
3. **Lock-Free Concurrency:** All counter increments and snapshot reads execute atomically without locking application state or blocking request threads.
