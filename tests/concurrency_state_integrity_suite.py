"""
==============================================================================
  EquiWell Phase 5 Concurrency, State Integrity & Synchronization Test Suite
  Windows Native Multi-Threaded Stress & Race Verification for Zig Backend
==============================================================================
"""

import urllib.request
import urllib.error
import json
import time
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_URL = "http://127.0.0.1:8080"

def make_request(method, path, body=None, token=None, timeout=10):
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            res_body = response.read().decode("utf-8")
            try:
                return response.status, json.loads(res_body) if res_body else {}
            except json.JSONDecodeError:
                return response.status, res_body
    except urllib.error.HTTPError as e:
        res_body = e.read().decode("utf-8")
        try:
            return e.code, json.loads(res_body) if res_body else {}
        except json.JSONDecodeError:
            return e.code, res_body
    except Exception as ex:
        return 500, str(ex)

def run_suite():
    print("==================================================================")
    print(" RUNNING PHASE 5 CONCURRENCY, STATE INTEGRITY & RACE AUDIT SUITE  ")
    print("==================================================================")

    passed = 0
    total = 0

    def check(name, condition, details=""):
        nonlocal passed, total
        total += 1
        if condition:
            print(f" [PASS] {name}")
            passed += 1
        else:
            print(f" [FAIL] {name} - {details}")

    # 0. Acquire Admin Token & Viewer Token
    status, res = make_request("POST", "/api/v1/users/login", {
        "email": "rndevahoma@equiwell.nam",
        "password": "SecurePassword123!"
    })
    admin_token = res.get("token")
    if not admin_token:
        print("[FATAL] Could not obtain admin token for testing.")
        sys.exit(1)

    status, res = make_request("POST", "/api/v1/users/login", {
        "email": "viewer@equiwell.nam",
        "password": "SecurePassword123!"
    })
    viewer_token = res.get("token")
    if not viewer_token:
        viewer_email = f"suite_viewer_{int(time.time())}@equiwell.nam"
        make_request("POST", "/api/v1/users/register", {
            "name": "Suite Viewer",
            "email": viewer_email,
            "password": "SecurePassword123!"
        })
        status, res = make_request("POST", "/api/v1/users/login", {
            "email": viewer_email,
            "password": "SecurePassword123!"
        })
        viewer_token = res.get("token")

    # ----------------------------------------------------
    # 1. CONCURRENT USER MUTATIONS & ISOLATION
    # ----------------------------------------------------
    print("\n--- 1. Testing Concurrent User Mutations & Race Isolation ---")

    # A. Concurrent Duplicate Email Registration Race (TOCTOU Elimination)
    dup_email = f"race_dup_{int(time.time())}@equiwell.nam"
    barrier_reg = threading.Barrier(10)

    def register_worker():
        barrier_reg.wait()
        return make_request("POST", "/api/v1/users/register", {
            "name": "Race User",
            "email": dup_email,
            "password": "SecurePassword123!"
        })

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(register_worker) for _ in range(10)]
        results = [f.result() for f in as_completed(futures)]

    success_count = sum(1 for status, _ in results if status == 201)
    conflict_count = sum(1 for status, _ in results if status == 400)
    check("Email Race: Exactly 1 registration succeeds (201)", success_count == 1, f"Success count: {success_count}")
    check("Email Race: 9 concurrent duplicate attempts rejected (400)", conflict_count == 9, f"Conflict count: {conflict_count}")

    # B. Concurrent Profile Update on Same User
    # Register target user
    u_email = f"target_mut_{int(time.time())}@equiwell.nam"
    status, reg_res = make_request("POST", "/api/v1/users/register", {
        "name": "Mutation Target",
        "email": u_email,
        "password": "SecurePassword123!"
    })
    target_uid = reg_res.get("user_id")

    barrier_upd = threading.Barrier(20)
    def update_worker(idx):
        barrier_upd.wait()
        return make_request("PUT", f"/api/v1/users/{target_uid}", {
            "name": f"Updated Name {idx}",
            "email": f"target_mut_{idx}_{int(time.time())}@equiwell.nam"
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(update_worker, i) for i in range(20)]
        upd_results = [f.result() for f in as_completed(futures)]

    all_200 = all(status == 200 for status, _ in upd_results)
    check("Concurrent User Profile Updates: All 20 requests succeeded (200)", all_200, f"Statuses: {[s for s, _ in upd_results]}")

    status, final_user = make_request("GET", f"/api/v1/users/{target_uid}", token=admin_token)
    check("User Structure Intact After 20 Concurrent Updates", status == 200 and "id" in final_user and "email" in final_user, f"User: {final_user}")

    # C. Concurrent PUT /users/{id} vs PATCH /users/{id}/role
    barrier_role = threading.Barrier(10)
    def patch_role_worker():
        barrier_role.wait()
        return make_request("PATCH", f"/api/v1/users/{target_uid}/role", {
            "role": "health_inspector"
        }, token=admin_token)

    def put_profile_worker():
        barrier_role.wait()
        return make_request("PUT", f"/api/v1/users/{target_uid}", {
            "name": "Tampered Name"
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=10) as executor:
        f_roles = [executor.submit(patch_role_worker) for _ in range(5)]
        f_puts = [executor.submit(put_profile_worker) for _ in range(5)]
        role_res = [f.result() for f in as_completed(f_roles)]
        put_res = [f.result() for f in as_completed(f_puts)]

    check("Concurrent Role & Profile Updates: All succeeded without crash", all(s == 200 for s, _ in role_res + put_res))
    status, user_after_role = make_request("GET", f"/api/v1/users/{target_uid}", token=admin_token)
    check("Role Update Integrity Preserved: User role is health_inspector", user_after_role.get("role") == "health_inspector", f"Role: {user_after_role.get('role')}")

    # ----------------------------------------------------
    # 2. CONCURRENT ENTITY CREATION & ID UNIQUENESS
    # ----------------------------------------------------
    print("\n--- 2. Testing Concurrent Entity Creation & Atomic ID Uniqueness ---")

    # A. 30 Concurrent Borehole Creations
    barrier_bh = threading.Barrier(30)
    def create_bh_worker(idx):
        barrier_bh.wait()
        return make_request("POST", "/api/v1/boreholes", {
            "name": f"Concurrent Well {idx}",
            "lat": -18.0 - (idx * 0.01),
            "lng": 13.5 + (idx * 0.01),
            "depth_m": 80.0 + idx,
            "pump_type": "solar",
            "yield_lph": 2000 + idx,
            "implemented_date": "2026-08-19"
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=30) as executor:
        futures = [executor.submit(create_bh_worker, i) for i in range(30)]
        bh_results = [f.result() for f in as_completed(futures)]

    all_bh_201 = all(status == 201 for status, _ in bh_results)
    bh_ids = [res.get("borehole_id") for status, res in bh_results if status == 201]
    unique_bh_ids = set(bh_ids)
    check("30 Concurrent Borehole Creations: 30/30 Succeeded (201)", all_bh_201 and len(bh_ids) == 30)
    check("30 Concurrent Boreholes: 30 Strictly Unique IDs (0 Collisions)", len(unique_bh_ids) == 30, f"Found {len(unique_bh_ids)} unique IDs")

    # B. 20 Concurrent Community Requests
    barrier_comm = threading.Barrier(20)
    def create_comm_worker(idx):
        barrier_comm.wait()
        return make_request("POST", "/api/v1/community-requests", {
            "community_name": f"Village {idx}",
            "contact_person": f"Elder {idx}",
            "contact_phone": f"+264 81 {idx:03d} 1122",
            "issue": f"Severe water shortage in zone {idx}",
            "urgency": "high"
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(create_comm_worker, i) for i in range(20)]
        comm_results = [f.result() for f in as_completed(futures)]

    all_comm_201 = all(status == 201 for status, _ in comm_results)
    comm_ids = [res.get("request_id") for status, res in comm_results if status == 201]
    check("20 Concurrent Community Requests: 20/20 Succeeded (201)", all_comm_201 and len(comm_ids) == 20)
    check("20 Concurrent Community Requests: 20 Strictly Unique IDs", len(set(comm_ids)) == 20, f"Unique IDs: {len(set(comm_ids))}")

    # C. 20 Concurrent AI Siting Suggestions
    barrier_sug = threading.Barrier(20)
    def create_sug_worker(idx):
        barrier_sug.wait()
        return make_request("POST", "/api/v1/suggestions/generate", {
            "target_area": f"Region Sector {idx}",
            "required_yield": "high",
            "priority_metric": "water_stress"
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(create_sug_worker, i) for i in range(20)]
        sug_results = [f.result() for f in as_completed(futures)]

    all_sug_201 = all(status == 201 for status, _ in sug_results)
    sug_ids = [res.get("suggestion_id") for status, res in sug_results if status == 201]
    check("20 Concurrent AI Suggestions: 20/20 Succeeded (201)", all_sug_201 and len(sug_ids) == 20)
    check("20 Concurrent AI Suggestions: 20 Strictly Unique IDs", len(set(sug_ids)) == 20, f"Unique: {len(set(sug_ids))}")

    # D. 20 Concurrent AI Drilling Log Ingestions
    barrier_dlog = threading.Barrier(20)
    def create_dlog_worker(idx):
        barrier_dlog.wait()
        return make_request("POST", "/api/v1/ai/training-data/borehole-logs", {
            "borehole_code": f"DLOG-SITE-{idx}",
            "lat": -18.2,
            "lng": 13.6,
            "total_depth_m": 120.0,
            "water_strike_depth_m": 85.0,
            "tested_yield_lph": 3000,
            "static_water_level_m": 25.0
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(create_dlog_worker, i) for i in range(20)]
        dlog_results = [f.result() for f in as_completed(futures)]

    all_dlog_201 = all(status == 201 for status, _ in dlog_results)
    dlog_ids = [res.get("log_id") for status, res in dlog_results if status == 201]
    check("20 Concurrent Drilling Logs: 20/20 Succeeded (201)", all_dlog_201 and len(dlog_ids) == 20)
    check("20 Concurrent Drilling Logs: 20 Strictly Unique IDs", len(set(dlog_ids)) == 20, f"Unique: {len(set(dlog_ids))}")

    # ----------------------------------------------------
    # 3. CONCURRENT TELEMETRY INGESTION & ALERTS
    # ----------------------------------------------------
    print("\n--- 3. Testing Concurrent Telemetry Ingestion & Alert Generation ---")

    # 30 Concurrent Telemetry Submissions on BH-1002
    barrier_tel = threading.Barrier(30)
    def create_tel_worker(idx):
        barrier_tel.wait()
        return make_request("POST", "/api/v1/boreholes/BH-1002/telemetry", {
            "drawdown_m": 12.5 + (idx * 0.1),
            "recovery_time_mins": 45 + idx,
            "solar_battery_level": (idx % 90) + 10,
            "flow_rate_lpm": 25.0 + idx
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=30) as executor:
        futures = [executor.submit(create_tel_worker, i) for i in range(30)]
        tel_results = [f.result() for f in as_completed(futures)]

    all_tel_201 = all(status == 201 for status, _ in tel_results)
    tel_ids = [res.get("telemetry_id") for status, res in tel_results if status == 201]
    check("30 Concurrent Telemetry Posts: 30/30 Succeeded (201)", all_tel_201 and len(tel_ids) == 30)
    check("30 Concurrent Telemetry Posts: 30 Unique Telemetry IDs", len(set(tel_ids)) == 30, f"Unique: {len(set(tel_ids))}")

    # Critical Telemetry Alert Trigger under Concurrency
    status, alert_res = make_request("POST", "/api/v1/boreholes/BH-1002/telemetry", {
        "drawdown_m": 50.0,
        "recovery_time_mins": 120,
        "solar_battery_level": 5, # Low battery (<10%) triggers alert
        "flow_rate_lpm": 0.0
    }, token=admin_token)
    check("Critical Telemetry Trigger -> 201 Created", status == 201)

    status, alerts = make_request("GET", "/api/v1/maintenance-alerts", token=admin_token)
    check("Maintenance Alert Created Successfully in Store", status == 200 and isinstance(alerts, list) and len(alerts) > 0)

    # ----------------------------------------------------
    # 4. CONCURRENT LAB TESTS & HEALTH QUOTAS
    # ----------------------------------------------------
    print("\n--- 4. Testing Concurrent Lab Tests & Usage Quotas ---")

    barrier_lab = threading.Barrier(20)
    def create_lab_worker(idx):
        barrier_lab.wait()
        return make_request("POST", "/api/v1/boreholes/BH-1002/lab-tests", {
            "test_date": "2026-08-19",
            "e_coli_detected": False,
            "arsenic_mg_l": 0.005 + (idx * 0.001),
            "fluoride_mg_l": 1.2,
            "is_safe_for_consumption": True
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(create_lab_worker, i) for i in range(20)]
        lab_results = [f.result() for f in as_completed(futures)]

    all_lab_201 = all(status == 201 for status, _ in lab_results)
    lab_ids = [res.get("test_id") for status, res in lab_results if status == 201]
    check("20 Concurrent Lab Tests: 20/20 Succeeded (201)", all_lab_201 and len(lab_ids) == 20)
    check("20 Concurrent Lab Tests: 20 Unique Lab IDs", len(set(lab_ids)) == 20, f"Unique: {len(set(lab_ids))}")

    # Concurrent Usage Quota Reads
    status, quota = make_request("GET", "/api/v1/boreholes/BH-1002/usage-quotas", token=admin_token)
    check("GET /boreholes/{id}/usage-quotas -> 200 OK", status == 200 and quota.get("borehole_id") == "BH-1002")

    # ----------------------------------------------------
    # 5. CONCURRENT READERS VS WRITERS & SNAPSHOT CONSISTENCY
    # ----------------------------------------------------
    print("\n--- 5. Testing Concurrent Readers vs Writers & Coherent Snapshot Integrity ---")

    # 40 Concurrent Mixed Requests: 20 GET /boreholes vs 20 POST /boreholes
    barrier_rw = threading.Barrier(40)
    def reader_worker():
        barrier_rw.wait()
        return make_request("GET", "/api/v1/boreholes")

    def writer_worker(idx):
        barrier_rw.wait()
        return make_request("POST", "/api/v1/boreholes", {
            "name": f"RW Well {idx}",
            "lat": -18.5,
            "lng": 13.8,
            "depth_m": 90.0,
            "pump_type": "solar",
            "yield_lph": 2500,
            "implemented_date": "2026-08-19"
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=40) as executor:
        f_reads = [executor.submit(reader_worker) for _ in range(20)]
        f_writes = [executor.submit(writer_worker, i) for i in range(20)]
        read_res = [f.result() for f in as_completed(f_reads)]
        write_res = [f.result() for f in as_completed(f_writes)]

    all_reads_valid = all(status == 200 and isinstance(res, list) for status, res in read_res)
    all_writes_valid = all(status == 201 for status, _ in write_res)
    check("Concurrent 20 Readers vs 20 Writers: All Readers Received Valid JSON (200)", all_reads_valid)
    check("Concurrent 20 Readers vs 20 Writers: All Writers Completed Successfully (201)", all_writes_valid)

    # Coherent Snapshot Verification on Dashboard Summary with 3 Canonical States
    # Create boreholes in all 3 states
    status, b_work = make_request("POST", "/api/v1/boreholes", {
        "name": "Snapshot Test Working", "lat": -18.1, "lng": 13.5, "depth_m": 80.0, "pump_type": "solar", "yield_lph": 2500
    }, token=admin_token)
    b_work_id = b_work.get("borehole_id")

    status, b_maint = make_request("POST", "/api/v1/boreholes", {
        "name": "Snapshot Test Maint", "lat": -18.2, "lng": 13.6, "depth_m": 90.0, "pump_type": "solar", "yield_lph": 1500
    }, token=admin_token)
    b_maint_id = b_maint.get("borehole_id")
    make_request("PATCH", f"/api/v1/boreholes/{b_maint_id}", {"status": "maintenance_required"}, token=admin_token)

    status, b_broken = make_request("POST", "/api/v1/boreholes", {
        "name": "Snapshot Test Broken", "lat": -18.3, "lng": 13.7, "depth_m": 100.0, "pump_type": "solar", "yield_lph": 0
    }, token=admin_token)
    b_broken_id = b_broken.get("borehole_id")
    make_request("PATCH", f"/api/v1/boreholes/{b_broken_id}", {"status": "broken"}, token=admin_token)

    # Concurrently mutate statuses while continuously reading dashboard summary
    barrier_snap = threading.Barrier(30)
    def mutator_worker(idx):
        barrier_snap.wait()
        target_id = b_work_id if idx % 3 == 0 else (b_maint_id if idx % 3 == 1 else b_broken_id)
        new_st = "working" if idx % 3 == 0 else ("maintenance_required" if idx % 3 == 1 else "broken")
        return make_request("PATCH", f"/api/v1/boreholes/{target_id}", {"status": new_st}, token=admin_token)

    def summary_reader_worker():
        barrier_snap.wait()
        return make_request("GET", "/api/v1/dashboard/summary")

    with ThreadPoolExecutor(max_workers=30) as executor:
        f_muts = [executor.submit(mutator_worker, i) for i in range(15)]
        f_sums = [executor.submit(summary_reader_worker) for _ in range(15)]
        mut_res = [f.result() for f in as_completed(f_muts)]
        sum_res = [f.result() for f in as_completed(f_sums)]

    check("Concurrent 3-State Mutations: 15/15 Status Patches Succeeded", all(s == 200 for s, _ in mut_res))
    all_sums_ok = all(s == 200 for s, _ in sum_res)
    check("Concurrent Dashboard Reads During State Race: 15/15 Succeeded (200)", all_sums_ok)

    # Invariant assertion across all 15 concurrent snapshots
    invariants_hold = True
    for s, summary_obj in sum_res:
        t = summary_obj.get("total_boreholes", 0)
        w = summary_obj.get("working_boreholes", 0)
        b = summary_obj.get("broken_boreholes", 0)
        m = summary_obj.get("maintenance_required_boreholes", 0)
        if t != (w + b + m):
            invariants_hold = False
            break

    check("Domain Invariant (total == working + broken + maintenance_required) Preserved Across All Snapshots", invariants_hold)

    # Allocation Metrics Consistency
    status, metrics = make_request("GET", "/api/v1/allocation-metrics")
    check("GET /allocation-metrics -> 200 OK", status == 200 and "fairness_gini_coefficient" in metrics)

    # ----------------------------------------------------
    # 6. CONCURRENT DELETE & DEPENDENT OPERATION SAFETY
    # ----------------------------------------------------
    print("\n--- 6. Testing Concurrent Delete & Referential Safety ---")

    # Create temporary borehole to delete concurrently
    status, tmp_bh = make_request("POST", "/api/v1/boreholes", {
        "name": "Delete Target Well",
        "lat": -18.5,
        "lng": 13.8,
        "depth_m": 90.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    del_bh_id = tmp_bh.get("borehole_id")

    barrier_del = threading.Barrier(10)
    def del_worker():
        barrier_del.wait()
        return make_request("DELETE", f"/api/v1/boreholes/{del_bh_id}", token=admin_token)

    def post_dep_worker():
        barrier_del.wait()
        return make_request("POST", f"/api/v1/boreholes/{del_bh_id}/telemetry", {
            "drawdown_m": 10.0,
            "recovery_time_mins": 30,
            "solar_battery_level": 80,
            "flow_rate_lpm": 20.0
        }, token=admin_token)

    with ThreadPoolExecutor(max_workers=10) as executor:
        f_dels = [executor.submit(del_worker) for _ in range(5)]
        f_deps = [executor.submit(post_dep_worker) for _ in range(5)]
        del_res = [f.result() for f in as_completed(f_dels)]
        dep_res = [f.result() for f in as_completed(f_deps)]

    # Exactly 1 delete succeeds with 200, remainder 404; dependent posts return 201 or 404 without server crash
    del_success = sum(1 for status, _ in del_res if status == 200)
    dep_valid = all(status in (201, 404) for status, _ in dep_res)
    check("Concurrent Delete: Exactly 1 DELETE succeeded with 200", del_success == 1, f"Deletes: {[s for s, _ in del_res]}")
    check("Concurrent Dependent Telemetry: Deterministic 201 or 404 (No Panics)", dep_valid, f"Telemetry statuses: {[s for s, _ in dep_res]}")

    # ----------------------------------------------------
    # 7. WORKER POOL 100+ BURST SATURATION STRESS TEST
    # ----------------------------------------------------
    print("\n--- 7. Testing Worker Pool 100+ Burst Concurrency Saturation ---")

    # 100 Concurrent Requests via ThreadPoolExecutor with a synchronized Barrier
    NUM_BURST = 100
    barrier_burst = threading.Barrier(NUM_BURST)

    def burst_worker(idx):
        barrier_burst.wait()
        if idx % 4 == 0:
            return make_request("GET", "/api/v1/health")
        elif idx % 4 == 1:
            return make_request("GET", "/api/v1/boreholes")
        elif idx % 4 == 2:
            return make_request("GET", "/api/v1/dashboard/summary")
        else:
            return make_request("POST", "/api/v1/routes/google-maps-directions", {
                "origin_lat": -18.0583,
                "origin_lng": 13.8402,
                "destination_lat": -18.2341,
                "destination_lng": 13.8821
            }, token=admin_token)

    with ThreadPoolExecutor(max_workers=NUM_BURST) as executor:
        futures = [executor.submit(burst_worker, i) for i in range(NUM_BURST)]
        burst_results = [f.result() for f in as_completed(futures)]

    burst_success = sum(1 for status, _ in burst_results if status in (200, 201, 204))
    check(f"100 Burst Concurrent Requests: All {NUM_BURST}/{NUM_BURST} Succeeded", burst_success == NUM_BURST, f"Success count: {burst_success}/{NUM_BURST}")

    # ----------------------------------------------------
    # 8. ASYNC TASKS, SITING & CALLBACK CONCURRENCY
    # ----------------------------------------------------
    print("\n--- 8. Testing Async Tasks & Callback Concurrency ---")

    status, task_res = make_request("POST", "/api/v1/ai/siting-tasks/async", {
        "target_area": "Epupa Basin",
        "required_yield": "high",
        "priority_metric": "water_stress"
    }, token=admin_token)
    check("POST /ai/siting-tasks/async -> 202 Accepted", status == 202 and "task_id" in task_res)
    task_id = task_res.get("task_id", "TASK-AI-7721")

    status, poll_res = make_request("GET", f"/api/v1/tasks/{task_id}")
    check("GET /tasks/{id} -> 200 OK", status == 200 and poll_res.get("task_id") == task_id)

    status, cb_res = make_request("POST", "/api/v1/callbacks/ai/siting-complete", {
        "task_id": task_id,
        "status": "SAVED"
    })
    check("POST /callbacks/ai/siting-complete -> 200 OK", status == 200 and cb_res.get("acknowledged") is True)

    # ----------------------------------------------------
    # FINAL RESULTS
    # ----------------------------------------------------
    print("\n==================================================================")
    print(f" TOTAL RESULTS: {passed}/{total} Passed ({int(passed/total*100)}% Success Rate)")
    print("==================================================================")

    if passed == total:
        print(" ALL PHASE 5 CONCURRENCY & STATE INTEGRITY TESTS PASSED\n")
        return 0
    else:
        print(" SOME CONCURRENCY TESTS FAILED\n")
        return 1

if __name__ == "__main__":
    sys.exit(run_suite())
