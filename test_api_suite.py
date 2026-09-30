"""
==============================================================================
  EquiWell API Automated Integration Test Suite
  Region: Kunene Region, Namibia
  Framework: Native Python standard library (urllib.request + json)
  Scope: 39 Assertions covering 39 Endpoints & 5 RBAC Security Roles
==============================================================================
"""

import urllib.request
import urllib.error
import json
import time
import sys

BASE_URL = "http://127.0.0.1:8080"

def request(method, path, body=None, token=None):
    """
    Sends an HTTP request to the running EquiWell backend server and returns (status_code, response_json).
    """
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode("utf-8")
            return response.status, json.loads(res_body) if res_body else {}
    except urllib.error.HTTPError as e:
        res_body = e.read().decode("utf-8")
        return e.code, json.loads(res_body) if res_body else {}

def run_tests():
    """
    Executes the complete test suite across all 8 modules and asserts expected responses.
    """
    print("==========================================================")
    print("  RUNNING COMPLETE EQUIWELL API TEST SUITE (ZIG BACKEND)")
    print("==========================================================")
    
    passed = 0
    total = 0

    def assert_test(name, condition, details=""):
        nonlocal passed, total
        total += 1
        if condition:
            print(f" [PASS] {name}")
            passed += 1
        else:
            print(f" [FAIL] {name} - {details}")

    # ----------------------------------------------------
    # 1. DASHBOARD SUMMARY
    # ----------------------------------------------------
    status, res = request("GET", "/dashboard/summary")
    assert_test(
        "GET /dashboard/summary",
        status == 200 and "total_boreholes" in res and "latest_borehole_implemented_date" in res,
        f"Status: {status}, Response: {res}"
    )

    # ----------------------------------------------------
    # 2. USER REGISTRATION & AUTHENTICATION
    # ----------------------------------------------------
    test_email = f"tester_{int(time.time())}@equiwell.nam"
    status, res = request("POST", "/users/register", {
        "name": "Integration Tester",
        "email": test_email,
        "password": "SecurePassword123!"
    })
    target_user_id = res.get("user_id")
    assert_test("POST /users/register", status == 201 and target_user_id is not None, f"Status: {status}")

    # Login as Admin
    status, res = request("POST", "/users/login", {
        "email": "rndevahoma@equiwell.nam",
        "password": "SecurePassword123!"
    })
    admin_token = res.get("token")
    assert_test("POST /users/login (Admin)", status == 200 and admin_token is not None)

    # Login as Viewer
    status, res = request("POST", "/users/login", {
        "email": "viewer@equiwell.nam",
        "password": "SecurePassword123!"
    })
    viewer_token = res.get("token")
    assert_test("POST /users/login (Viewer)", status == 200 and viewer_token is not None)

    # ----------------------------------------------------
    # 3. RBAC SECURITY BOUNDARY CHECKS
    # ----------------------------------------------------
    status, _ = request("GET", "/users", token=viewer_token)
    assert_test("RBAC: GET /users blocked for Viewer (403)", status == 403, f"Status: {status}")

    status, res = request("GET", "/users", token=admin_token)
    assert_test("RBAC: GET /users allowed for Admin (200)", status == 200 and isinstance(res, list))

    # User Profile Operations
    status, res = request("GET", "/users/USR-001", token=admin_token)
    assert_test("GET /users/{id}", status == 200 and res.get("id") == "USR-001")

    status, res = request("PUT", f"/users/{target_user_id}", {"name": "Updated Tester", "email": f"updated_{test_email}"}, token=admin_token)
    assert_test("PUT /users/{id}", status == 200)

    status, res = request("PATCH", f"/users/{target_user_id}/role", {"role": "health_inspector"}, token=admin_token)
    assert_test("PATCH /users/{id}/role (Admin)", status == 200)

    # Delete User
    status, res = request("DELETE", f"/users/{target_user_id}", token=admin_token)
    assert_test("DELETE /users/{id} (Admin)", status == 200)

    # ----------------------------------------------------
    # 4. BOREHOLES MODULE WITH COMMISSIONING DATE
    # ----------------------------------------------------
    status, res = request("GET", "/boreholes")
    assert_test("GET /boreholes (with implemented_date)", status == 200 and isinstance(res, list) and len(res) > 0 and "implemented_date" in res[0])

    status, res = request("GET", "/boreholes/BH-1002")
    assert_test("GET /boreholes/BH-1002", status == 200 and res.get("id") == "BH-1002" and res.get("implemented_date") == "2024-03-15")

    # Create Borehole
    status, res = request("POST", "/boreholes", {
        "name": "Kunene Test Site 9",
        "lat": -18.5500,
        "lng": 13.9200,
        "depth_m": 105.0,
        "pump_type": "solar",
        "yield_lph": 2800,
        "implemented_date": "2026-08-19"
    }, token=admin_token)
    new_bh_id = res.get("borehole_id")
    assert_test("POST /boreholes (Admin)", status == 201 and new_bh_id is not None)

    # Update Borehole
    status, res = request("PUT", f"/boreholes/{new_bh_id}", {
        "name": "Kunene Test Site 9 (Upgraded)",
        "depth_m": 115.0,
        "pump_type": "hybrid",
        "yield_lph": 3200,
        "implemented_date": "2026-08-20"
    }, token=admin_token)
    assert_test("PUT /boreholes/{id} (Admin)", status == 200)

    # Patch Borehole Status
    status, res = request("PATCH", f"/boreholes/{new_bh_id}", {"status": "maintenance_required", "is_visible": True}, token=admin_token)
    assert_test("PATCH /boreholes/{id} (Admin)", status == 200)

    # RBAC Deletion Check
    status, _ = request("DELETE", f"/boreholes/{new_bh_id}", token=viewer_token)
    assert_test("RBAC: DELETE /boreholes/{id} blocked for Viewer (403)", status == 403)

    status, _ = request("DELETE", f"/boreholes/{new_bh_id}", token=admin_token)
    assert_test("RBAC: DELETE /boreholes/{id} allowed for Admin (200)", status == 200)

    # ----------------------------------------------------
    # 5. HEALTH & WATER QUALITY MODULE
    # ----------------------------------------------------
    status, res = request("POST", "/boreholes/BH-1002/lab-tests", {
        "test_date": "2026-08-19",
        "e_coli_detected": False,
        "arsenic_mg_l": 0.002,
        "fluoride_mg_l": 0.9,
        "is_safe_for_consumption": True
    }, token=admin_token)
    assert_test("POST /boreholes/BH-1002/lab-tests", status == 201 and "test_id" in res)

    status, res = request("GET", "/boreholes/BH-1002/lab-tests", token=admin_token)
    assert_test("GET /boreholes/BH-1002/lab-tests", status == 200 and isinstance(res, list) and len(res) > 0)

    status, res = request("GET", "/boreholes/BH-1002/usage-quotas", token=admin_token)
    assert_test("GET /boreholes/BH-1002/usage-quotas", status == 200 and "monthly_quota_liters" in res)

    # ----------------------------------------------------
    # 6. MAINTENANCE & TELEMETRY MODULE
    # ----------------------------------------------------
    status, res = request("POST", "/boreholes/BH-1002/telemetry", {
        "drawdown_m": 3.1,
        "recovery_time_mins": 38,
        "solar_battery_level": 94,
        "flow_rate_lpm": 25.0
    }, token=admin_token)
    assert_test("POST /boreholes/BH-1002/telemetry", status == 201 and "telemetry_id" in res)

    status, res = request("GET", "/maintenance-alerts", token=admin_token)
    assert_test("GET /maintenance-alerts", status == 200 and isinstance(res, list))

    status, res = request("GET", "/boreholes/BH-1002/history", token=admin_token)
    assert_test("GET /boreholes/BH-1002/history", status == 200 and "yearly_average_yield" in res)

    # ----------------------------------------------------
    # 7. ALLOCATION & COMMUNITY REQUESTS MODULE
    # ----------------------------------------------------
    status, res = request("GET", "/allocation-metrics")
    assert_test("GET /allocation-metrics", status == 200 and "fairness_gini_coefficient" in res)

    status, res = request("POST", "/community-requests", {
        "community_name": "Sesfontein West",
        "contact_person": "Councillor Katjiuanjo",
        "contact_phone": "+264 81 777 8899",
        "issue": "Community solar inverter failure; 450 households without potable water.",
        "urgency": "critical"
    }, token=admin_token)
    assert_test("POST /community-requests", status == 201 and "request_id" in res)

    status, res = request("GET", "/community-requests", token=admin_token)
    assert_test("GET /community-requests", status == 200 and isinstance(res, list))

    # ----------------------------------------------------
    # 8. LOGISTICS & GOOGLE MAPS NAVIGATION MODULE
    # ----------------------------------------------------
    status, res = request("GET", "/boreholes/BH-1002/logistics", token=admin_token)
    assert_test("GET /boreholes/BH-1002/logistics", status == 200 and "terrain_difficulty" in res)

    status, res = request("POST", "/routes/calculate", {
        "start_coordinates": "-18.0583,13.8402",
        "destination_borehole_id": "BH-1002",
        "vehicle_type": "light_4x4"
    }, token=admin_token)
    assert_test("POST /routes/calculate", status == 200 and "distance_km" in res)

    status, res = request("POST", "/routes/google-maps-directions", {
        "origin_lat": -18.0583,
        "origin_lng": 13.8402,
        "destination_borehole_id": "BH-1002",
        "destination_lat": -18.2341,
        "destination_lng": 13.8821
    }, token=admin_token)
    assert_test("POST /routes/google-maps-directions", status == 200 and "google_maps_url" in res and "steps" in res)

    # ----------------------------------------------------
    # 9. AI SITING & HYDROGEOLOGY MODULE (EXTENSIONS)
    # ----------------------------------------------------
    status, res = request("GET", "/factors")
    assert_test("GET /factors", status == 200 and "geological_factors" in res)

    status, res = request("POST", "/suggestions/generate", {
        "target_area": "Sesfontein",
        "required_yield": "high",
        "priority_metric": "fair_allocation_distance"
    }, token=admin_token)
    sug_id = res.get("suggestion_id")
    assert_test("POST /suggestions/generate", status == 201 and sug_id is not None)

    status, res = request("GET", f"/suggestions/{sug_id}")
    assert_test("GET /suggestions/{id}", status == 200 and res.get("status") == "complete")

    status, res = request("POST", "/ai/predict-yield", {
        "latitude": -18.2341,
        "longitude": 13.8821,
        "target_aquifer_depth_m": 85.0
    }, token=admin_token)
    assert_test("POST /ai/predict-yield (ML)", status == 200 and "predicted_yield_lph" in res)

    status, res = request("POST", "/ai/aquifer-depletion-risk", {
        "borehole_id": "BH-1002",
        "planned_daily_extraction_liters": 25000,
        "simulation_horizon_years": 10
    }, token=admin_token)
    assert_test("POST /ai/aquifer-depletion-risk", status == 200 and "sustainability_status" in res)

    status, res = request("POST", "/ai/siting-tasks/async", {
        "target_area": "Epupa",
        "required_yield": "moderate",
        "priority_metric": "geological_recharge"
    }, token=admin_token)
    assert_test("POST /ai/siting-tasks/async", status == 202 and "task_id" in res)

    status, res = request("POST", "/callbacks/ai/siting-complete", {
        "task_id": "TASK-AI-7721",
        "status": "SUCCESS"
    })
    assert_test("POST /callbacks/ai/siting-complete", status == 200 and res.get("acknowledged") is True)

    status, res = request("POST", "/ai/training-data/borehole-logs", {
        "borehole_code": "BH-FIELD-KUNENE-001",
        "lat": -18.2341,
        "lng": 13.8821,
        "total_depth_m": 88.5,
        "water_strike_depth_m": 54.0,
        "tested_yield_lph": 2100,
        "static_water_level_m": 16.8
    }, token=admin_token)
    assert_test("POST /ai/training-data/borehole-logs", status == 201 and "log_id" in res)

    status, res = request("POST", "/ai/training-data/yield-maps", {
        "layer_name": "kunene_fracture_density_2026.tif",
        "resolution_m": 30
    }, token=admin_token)
    assert_test("POST /ai/training-data/yield-maps", status == 201 and "layer_id" in res)

    status, res = request("POST", "/ai/routes/terrain-feasibility", {
        "origin_coordinates": "-18.0583,13.8402",
        "destination_coordinates": "-18.2341,13.8821",
        "vehicle_type": "20_ton_drilling_rig"
    }, token=admin_token)
    assert_test("POST /ai/routes/terrain-feasibility", status == 200 and "is_feasible" in res)

    print("==========================================================")
    print(f"  TOTAL RESULTS: {passed}/{total} Passed ({int(passed/total*100)}% Success Rate)")
    print("==========================================================")

    if passed != total:
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
