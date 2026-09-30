import http.client
import json
import socket
import sys
import threading
import time

BASE_HOST = "127.0.0.1"
BASE_PORT = 8080
BASE_URL = f"http://{BASE_HOST}:{BASE_PORT}"

def http_get(path, headers=None):
    conn = http.client.HTTPConnection(BASE_HOST, BASE_PORT, timeout=5)
    req_headers = headers or {}
    conn.request("GET", path, headers=req_headers)
    res = conn.getresponse()
    data = res.read().decode('utf-8')
    conn.close()
    return res.status, data

def http_post(path, body, headers=None):
    conn = http.client.HTTPConnection(BASE_HOST, BASE_PORT, timeout=5)
    req_headers = headers or {"Content-Type": "application/json"}
    conn.request("POST", path, body=body, headers=req_headers)
    res = conn.getresponse()
    data = res.read().decode('utf-8')
    conn.close()
    return res.status, data

def get_metrics():
    status, body = http_get("/api/v1/metrics")
    assert status == 200, f"Expected 200 from /api/v1/metrics, got {status}"
    return json.loads(body)

def run_observability_suite():
    passed = 0
    total = 0

    print("==================================================================")
    print(" RUNNING CR-001 NATIVE METRICS & OBSERVABILITY VERIFICATION SUITE ")
    print("==================================================================")

    # 1. Structure & Field Validation
    print("\n--- 1. Testing Metrics Snapshot Schema & Fields ---")
    
    total += 1
    status, body = http_get("/metrics")
    if status == 200:
        print(" [PASS] GET /metrics -> 200 OK")
        passed += 1
    else:
        print(f" [FAIL] GET /metrics failed with {status}")

    total += 1
    status_v1, body_v1 = http_get("/api/v1/metrics")
    if status_v1 == 200:
        print(" [PASS] GET /api/v1/metrics -> 200 OK")
        passed += 1
    else:
        print(f" [FAIL] GET /api/v1/metrics failed with {status_v1}")

    total += 1
    m = json.loads(body_v1)
    required_fields = [
        "uptime_seconds", "total_requests", "successful_requests",
        "client_error_requests", "server_error_requests",
        "authentication_failures", "authorization_denials", "validation_failures",
        "rate_or_security_rejections", "active_requests", "peak_active_requests",
        "average_latency_ms", "total_request_duration_ms", "total_request_bytes",
        "total_response_bytes", "worker_tasks_completed", "worker_tasks_failed",
        "queue_rejections"
    ]
    all_fields_present = all(f in m for f in required_fields)
    if all_fields_present:
        print(f" [PASS] All {len(required_fields)} required metric counters present in JSON snapshot")
        passed += 1
    else:
        missing = [f for f in required_fields if f not in m]
        print(f" [FAIL] Missing required fields: {missing}")

    total += 1
    if m["uptime_seconds"] >= 0 and m["average_latency_ms"] >= 0.0 and m["total_request_duration_ms"] >= 0.0:
        print(" [PASS] Monotonic timing metrics are strictly non-negative (no underflow)")
        passed += 1
    else:
        print(" [FAIL] Monotonic timing metric underflow detected")

    # 2. Status Code Categorization & Counter Verification
    print("\n--- 2. Testing Status Code Categorization & Counter Increments ---")
    
    # Baseline snapshot
    m0 = get_metrics()

    # 2.1 Successful 200 Request
    total += 1
    st_200, _ = http_get("/api/v1/health")
    m1 = get_metrics()
    # Note: m1 includes the health check and the get_metrics call itself
    if st_200 == 200 and m1["successful_requests"] > m0["successful_requests"]:
        print(" [PASS] 200 OK increments successful_requests counter")
        passed += 1
    else:
        print(" [FAIL] 200 OK failed to increment successful_requests")

    # 2.2 400 Bad Request (Validation failure)
    total += 1
    m_before_400 = get_metrics()
    st_400, _ = http_post("/api/v1/users/register", json.dumps({"name": "Test", "email": "invalid-email-address", "password": "123"}))
    m_after_400 = get_metrics()
    if st_400 == 400 and m_after_400["validation_failures"] > m_before_400["validation_failures"]:
        print(" [PASS] 400 Bad Request increments validation_failures counter")
        passed += 1
    else:
        print(f" [FAIL] 400 validation failure not counted (st={st_400})")

    # 2.3 401 Unauthorized
    total += 1
    m_before_401 = get_metrics()
    st_401, _ = http_get("/api/v1/users") # requires auth
    m_after_401 = get_metrics()
    if st_401 == 401 and m_after_401["authentication_failures"] > m_before_401["authentication_failures"]:
        print(" [PASS] 401 Unauthorized increments authentication_failures counter")
        passed += 1
    else:
        print(f" [FAIL] 401 failure not counted (st={st_401})")

    # 2.4 403 Forbidden (RBAC denial)
    total += 1
    # Login as viewer
    st_login, login_data = http_post("/api/v1/users/login", json.dumps({"email": "viewer@equiwell.nam", "password": "SecurePassword123!"}))
    viewer_token = json.loads(login_data)["token"]
    
    m_before_403 = get_metrics()
    st_403, _ = http_get("/api/v1/users", headers={"Authorization": f"Bearer {viewer_token}"})
    m_after_403 = get_metrics()
    if st_403 == 403 and m_after_403["authorization_denials"] > m_before_403["authorization_denials"]:
        print(" [PASS] 403 Forbidden increments authorization_denials counter")
        passed += 1
    else:
        print(f" [FAIL] 403 denial not counted (st={st_403})")

    # 2.5 413 Payload Too Large (Security rejection)
    total += 1
    m_before_413 = get_metrics()
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((BASE_HOST, BASE_PORT))
    s.sendall(b"POST /api/v1/boreholes HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nContent-Length: 10485761\r\n\r\n")
    s_res = s.recv(1024).decode('utf-8', errors='ignore')
    s.close()
    m_after_413 = get_metrics()
    if "413" in s_res and m_after_413["rate_or_security_rejections"] > m_before_413["rate_or_security_rejections"]:
        print(" [PASS] 413 Payload Too Large increments rate_or_security_rejections counter")
        passed += 1
    else:
        print(f" [FAIL] 413 rejection not counted: {s_res[:30]}")

    # 2.6 431 Request Header Fields Too Large
    total += 1
    m_before_431 = get_metrics()
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((BASE_HOST, BASE_PORT))
    oversized_headers = "X-Large-Header: " + ("A" * 9000) + "\r\n"
    s.sendall(f"GET /api/v1/health HTTP/1.1\r\nHost: 127.0.0.1:8080\r\n{oversized_headers}\r\n".encode('utf-8'))
    s_res_431 = s.recv(1024).decode('utf-8', errors='ignore')
    s.close()
    m_after_431 = get_metrics()
    if "431" in s_res_431 and m_after_431["rate_or_security_rejections"] > m_before_431["rate_or_security_rejections"]:
        print(" [PASS] 431 Header Fields Too Large increments rate_or_security_rejections counter")
        passed += 1
    else:
        print(f" [FAIL] 431 rejection not counted: {s_res_431[:30]}")

    # 3. High-Concurrency Stress & Counter Consistency
    print("\n--- 3. Testing High-Concurrency Stress & Atomic Integrity ---")
    
    total += 1
    m_before_burst = get_metrics()
    concurrent_threads = 50
    results = []
    
    def worker():
        try:
            st, _ = http_get("/api/v1/dashboard/summary")
            results.append(st)
        except Exception as e:
            results.append(str(e))

    threads = [threading.Thread(target=worker) for _ in range(concurrent_threads)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    success_count = results.count(200)
    m_after_burst = get_metrics()
    
    if success_count == concurrent_threads:
        print(f" [PASS] 50 Concurrent Client Requests -> {success_count}/{concurrent_threads} Succeeded (200 OK)")
        passed += 1
    else:
        print(f" [FAIL] Concurrency failures: {results}")

    total += 1
    # Total requests should have grown by at least 50 plus the metrics call
    delta_requests = m_after_burst["total_requests"] - m_before_burst["total_requests"]
    if delta_requests >= 50 and m_after_burst["peak_active_requests"] >= 1:
        print(f" [PASS] Atomic total_requests (+{delta_requests}) and peak_active_requests ({m_after_burst['peak_active_requests']}) coherent")
        passed += 1
    else:
        print(f" [FAIL] Atomic counter discrepancy: delta={delta_requests}")

    # 4. Security & Credential Isolation
    print("\n--- 4. Testing Security, Credential Isolation & Payload Boundaries ---")
    
    total += 1
    raw_metrics_json = body_v1.lower()
    forbidden_terms = ["jwt_secret", "password", "hash", "private_key", "bearer ", "token_expiry"]
    leaked = [t for t in forbidden_terms if t in raw_metrics_json]
    if len(leaked) == 0:
        print(" [PASS] Zero credentials, secrets, tokens or hashes leaked in metrics payload")
        passed += 1
    else:
        print(f" [FAIL] Sensitive terms leaked in metrics JSON: {leaked}")

    total += 1
    if len(body_v1) < 2048:
        print(f" [PASS] Metrics response is bounded and compact ({len(body_v1)} bytes < 2KB)")
        passed += 1
    else:
        print(f" [FAIL] Metrics response oversized: {len(body_v1)} bytes")

    print("\n==================================================================")
    print(f" TOTAL RESULTS: {passed}/{total} Passed ({(passed/total)*100:.1f}% Success Rate)")
    print("==================================================================")
    
    if passed == total:
        print(" ALL OBSERVABILITY & METRICS TESTS PASSED")
        return 0
    else:
        print(" OBSERVABILITY TEST SUITE REPORTED FAILURES")
        return 1

if __name__ == "__main__":
    sys.exit(run_observability_suite())
