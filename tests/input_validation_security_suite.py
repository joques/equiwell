"""
==============================================================================
  EquiWell Phase 4 Application Input Validation & Data Integrity Test Suite
  Comprehensive Verification for Zig 0.17 Enterprise Backend
==============================================================================
"""

import urllib.request
import urllib.error
import json
import time
import sys

BASE_URL = "http://127.0.0.1:8080"

def make_request(method, path, body=None, token=None, raw_body=None):
    """
    Sends an HTTP request and returns (status_code, response_json_or_text).
    """
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    if raw_body is not None:
        data = raw_body.encode("utf-8") if isinstance(raw_body, str) else raw_body
    elif body is not None:
        data = json.dumps(body).encode("utf-8")
    else:
        data = None

    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
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

def run_suite():
    print("==================================================================")
    print(" RUNNING PHASE 4 APPLICATION INPUT VALIDATION & INTEGRITY SUITE   ")
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
        viewer_email = f"viewer_suite_{int(time.time())}@equiwell.nam"
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
    # 1. FLOAT & COORDINATE RANGE BOUNDS
    # ----------------------------------------------------
    print("\n--- 1. Testing Float & Coordinate Boundaries ---")

    # A. Latitude > 90.0
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Invalid Lat North",
        "lat": 95.0,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Latitude > 90.0 (lat=95.0) -> 400", status == 400, f"Got status {status}")

    # B. Latitude < -90.0
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Invalid Lat South",
        "lat": -95.0,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Latitude < -90.0 (lat=-95.0) -> 400", status == 400, f"Got status {status}")

    # C. Longitude > 180.0
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Invalid Lng East",
        "lat": -18.5,
        "lng": 185.0,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Longitude > 180.0 (lng=185.0) -> 400", status == 400, f"Got status {status}")

    # D. Longitude < -180.0
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Invalid Lng West",
        "lat": -18.5,
        "lng": -185.0,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Longitude < -180.0 (lng=-185.0) -> 400", status == 400, f"Got status {status}")

    # E. Negative Depth on Borehole Creation
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Negative Depth Borehole",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": -50.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Negative Depth (depth_m=-50.0) -> 400", status == 400, f"Got status {status}")

    # F. Zero Depth on Borehole Creation
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Zero Depth Borehole",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 0.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Zero Depth (depth_m=0.0) -> 400", status == 400, f"Got status {status}")

    # G. Excessive Depth (>2000m)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Unrealistic Depth Borehole",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 5000.0,
        "pump_type": "solar",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Unrealistic Depth (>2000m) -> 400", status == 400, f"Got status {status}")

    # H. Invalid Coordinates in Google Maps Directions
    status, _ = make_request("POST", "/api/v1/routes/google-maps-directions", {
        "origin_lat": -95.0,
        "origin_lng": 13.5,
        "destination_lat": -18.5,
        "destination_lng": 14.2
    }, token=admin_token)
    check("Reject Out-of-Bounds Coordinates in Directions -> 400", status == 400, f"Got status {status}")

    # I. Negative Chemical Concentrations (Arsenic/Fluoride)
    status, _ = make_request("POST", "/api/v1/boreholes/BH-1002/lab-tests", {
        "test_date": "2026-08-19",
        "e_coli_detected": False,
        "arsenic_mg_l": -0.05,
        "fluoride_mg_l": 1.2,
        "is_safe_for_consumption": True
    }, token=admin_token)
    check("Reject Negative Arsenic Concentration -> 400", status == 400, f"Got status {status}")

    # J. Negative Telemetry Drawdown / Flow Rate
    status, _ = make_request("POST", "/api/v1/boreholes/BH-1002/telemetry", {
        "drawdown_m": -2.5,
        "recovery_time_mins": 45,
        "solar_battery_level": 85,
        "flow_rate_lpm": 40.0
    }, token=admin_token)
    check("Reject Negative Drawdown Measurement -> 400", status == 400, f"Got status {status}")

    # K. AI Prediction Coordinates & Depth Range
    status, _ = make_request("POST", "/api/v1/ai/predict-yield", {
        "latitude": 92.0,
        "longitude": 13.5,
        "target_aquifer_depth_m": 80.0
    }, token=admin_token)
    check("Reject Invalid Latitude in Predict Yield -> 400", status == 400, f"Got status {status}")

    # L. Drilling Log Strike Depth > Total Depth
    status, _ = make_request("POST", "/api/v1/ai/training-data/borehole-logs", {
        "borehole_code": "BH-DRILL-99",
        "lat": -18.5,
        "lng": 13.5,
        "total_depth_m": 100.0,
        "water_strike_depth_m": 120.0,  # Impossible: strike deeper than total depth
        "tested_yield_lph": 2500,
        "static_water_level_m": 45.0
    }, token=admin_token)
    check("Reject Water Strike Depth > Total Depth -> 400", status == 400, f"Got status {status}")

    # ----------------------------------------------------
    # 2. PERCENTAGE & INTEGER BOUNDS
    # ----------------------------------------------------
    print("\n--- 2. Testing Percentage & Integer Bounds ---")

    # A. Battery level > 100% (e.g. 150)
    status, _ = make_request("POST", "/api/v1/boreholes/BH-1002/telemetry", {
        "drawdown_m": 4.2,
        "recovery_time_mins": 45,
        "solar_battery_level": 150,
        "flow_rate_lpm": 40.0
    }, token=admin_token)
    check("Reject Battery Level > 100% (battery=150) -> 400", status == 400, f"Got status {status}")

    # B. Depletion Simulation Horizon = 0
    status, _ = make_request("POST", "/api/v1/ai/aquifer-depletion-risk", {
        "borehole_id": "BH-1002",
        "planned_daily_extraction_liters": 5000,
        "simulation_horizon_years": 0
    }, token=admin_token)
    check("Reject Depletion Horizon = 0 years -> 400", status == 400, f"Got status {status}")

    # C. Depletion Simulation Horizon > 100
    status, _ = make_request("POST", "/api/v1/ai/aquifer-depletion-risk", {
        "borehole_id": "BH-1002",
        "planned_daily_extraction_liters": 5000,
        "simulation_horizon_years": 150
    }, token=admin_token)
    check("Reject Depletion Horizon > 100 years -> 400", status == 400, f"Got status {status}")

    # D. Depletion Extraction = 0 liters
    status, _ = make_request("POST", "/api/v1/ai/aquifer-depletion-risk", {
        "borehole_id": "BH-1002",
        "planned_daily_extraction_liters": 0,
        "simulation_horizon_years": 10
    }, token=admin_token)
    check("Reject Depletion Extraction = 0 L -> 400", status == 400, f"Got status {status}")

    # ----------------------------------------------------
    # 3. ENUM INTEGRITY & STRICT VALIDATION
    # ----------------------------------------------------
    print("\n--- 3. Testing Enum Integrity & Silent Fallback Rejection ---")

    # A. Invalid Pump Type on Borehole Creation (MUST NOT fall back to solar)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Invalid Pump Site",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "nuclear_fusion_turbine",
        "yield_lph": 2500
    }, token=admin_token)
    check("Reject Invalid Pump Type ('nuclear_fusion_turbine') -> 400", status == 400, f"Got status {status}")

    # B. Invalid Pump Type on Borehole Update
    status, _ = make_request("PUT", "/api/v1/boreholes/BH-1002", {
        "name": "Upgraded Site",
        "depth_m": 100.0,
        "pump_type": "quantum_drive",
        "yield_lph": 3000
    }, token=admin_token)
    check("Reject Invalid Pump Type on Update -> 400", status == 400, f"Got status {status}")

    # C. Invalid Borehole Status on Patch
    status, _ = make_request("PATCH", "/api/v1/boreholes/BH-1002", {
        "status": "vaporized"
    }, token=admin_token)
    check("Reject Invalid Status ('vaporized') on Patch -> 400", status == 400, f"Got status {status}")

    # D. Invalid User Role on Role Patch
    status, _ = make_request("PATCH", "/api/v1/users/USR-001/role", {
        "role": "supreme_overlord"
    }, token=admin_token)
    check("Reject Invalid User Role ('supreme_overlord') -> 400", status == 400, f"Got status {status}")

    # E. Invalid Urgency in Community Request
    status, _ = make_request("POST", "/api/v1/community-requests", {
        "community_name": "Sesfontein North",
        "contact_person": "Jafet Ndalila",
        "contact_phone": "+264 81 123 4567",
        "issue": "Primary solar pump controller damaged by lightning strike.",
        "urgency": "apocalyptic_danger"
    }, token=admin_token)
    check("Reject Invalid Urgency ('apocalyptic_danger') -> 400", status == 400, f"Got status {status}")

    # F. Invalid Query Parameters on GET /boreholes
    status, _ = make_request("GET", "/api/v1/boreholes?status=nonexistent_status")
    check("Reject Invalid status Query Parameter -> 400", status == 400, f"Got status {status}")

    status, _ = make_request("GET", "/api/v1/boreholes?pump_type=nonexistent_pump")
    check("Reject Invalid pump_type Query Parameter -> 400", status == 400, f"Got status {status}")

    # ----------------------------------------------------
    # 4. STRING LENGTH & FORMAT BOUNDARIES
    # ----------------------------------------------------
    print("\n--- 4. Testing String Length & Format Boundaries ---")

    # A. Empty / Whitespace-only User Name on Register
    status, _ = make_request("POST", "/api/v1/users/register", {
        "name": "   ",
        "email": f"test_empty_{int(time.time())}@equiwell.nam",
        "password": "SecurePassword123!"
    })
    check("Reject Whitespace-only User Name -> 400", status == 400, f"Got status {status}")

    # B. Short Password (<8 chars)
    status, _ = make_request("POST", "/api/v1/users/register", {
        "name": "Valid Name",
        "email": f"test_short_{int(time.time())}@equiwell.nam",
        "password": "short"
    })
    check("Reject Password < 8 characters -> 400", status == 400, f"Got status {status}")

    # C. Oversized Password (>128 chars to prevent PBKDF2 DoS)
    status, _ = make_request("POST", "/api/v1/users/register", {
        "name": "Valid Name",
        "email": f"test_oversized_{int(time.time())}@equiwell.nam",
        "password": "P" * 200
    })
    check("Reject Password > 128 characters -> 400", status == 400, f"Got status {status}")

    # D. Invalid Email (No @)
    status, _ = make_request("POST", "/api/v1/users/register", {
        "name": "Valid Name",
        "email": "invalid-email-address",
        "password": "SecurePassword123!"
    })
    check("Reject Email without @ -> 400", status == 400, f"Got status {status}")

    # E. Invalid Email (Consecutive Dots)
    status, _ = make_request("POST", "/api/v1/users/register", {
        "name": "Valid Name",
        "email": "user@domain..com",
        "password": "SecurePassword123!"
    })
    check("Reject Email with Consecutive Dots -> 400", status == 400, f"Got status {status}")

    # F. Invalid Phone Format in Community Request
    status, _ = make_request("POST", "/api/v1/community-requests", {
        "community_name": "Sesfontein North",
        "contact_person": "Jafet Ndalila",
        "contact_phone": "INVALID_PHONE_LETTERS",
        "issue": "Primary solar pump controller damaged by lightning strike.",
        "urgency": "critical"
    }, token=admin_token)
    check("Reject Invalid Phone Format -> 400", status == 400, f"Got status {status}")

    # ----------------------------------------------------
    # 5. ISO DATE SYNTAX & CALENDAR BOUNDARIES (LEAP YEARS)
    # ----------------------------------------------------
    print("\n--- 5. Testing Calendar Date Validation & Leap Years ---")

    # A. Invalid Date Syntax (Slashes instead of dashes)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Date Test Borehole",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026/08/19"
    }, token=admin_token)
    check("Reject Date with Slashes ('2026/08/19') -> 400", status == 400, f"Got status {status}")

    # B. Invalid Month (Month 13)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Date Test Borehole 2",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-13-19"
    }, token=admin_token)
    check("Reject Invalid Month ('2026-13-19') -> 400", status == 400, f"Got status {status}")

    # C. Invalid Day (Day 35)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Date Test Borehole 3",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-08-35"
    }, token=admin_token)
    check("Reject Invalid Day ('2026-08-35') -> 400", status == 400, f"Got status {status}")

    # D. Non-Leap Year Feb 29: 2026-02-29
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Feb 29 Non-Leap 2026",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-02-29"
    }, token=admin_token)
    check("Reject Non-Leap Feb 29 ('2026-02-29') -> 400", status == 400, f"Got status {status}")

    # E. Non-Leap Year Feb 29: 2025-02-29
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Feb 29 Non-Leap 2025",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2025-02-29"
    }, token=admin_token)
    check("Reject Non-Leap Feb 29 ('2025-02-29') -> 400", status == 400, f"Got status {status}")

    # F. Impossible April 31: 2026-04-31 (April has 30 days)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "April 31 Impossible",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-04-31"
    }, token=admin_token)
    check("Reject Impossible Calendar Date ('2026-04-31') -> 400", status == 400, f"Got status {status}")

    # G. Impossible June 31: 2026-06-31 (June has 30 days)
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "June 31 Impossible",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-06-31"
    }, token=admin_token)
    check("Reject Impossible Calendar Date ('2026-06-31') -> 400", status == 400, f"Got status {status}")

    # H. Month 00
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Month 00 Impossible",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-00-15"
    }, token=admin_token)
    check("Reject Month 00 ('2026-00-15') -> 400", status == 400, f"Got status {status}")

    # I. Day 00
    status, _ = make_request("POST", "/api/v1/boreholes", {
        "name": "Day 00 Impossible",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2026-05-00"
    }, token=admin_token)
    check("Reject Day 00 ('2026-05-00') -> 400", status == 400, f"Got status {status}")

    # J. Valid Leap Year Feb 29: 2024-02-29 (Must be accepted!)
    status, res = make_request("POST", "/api/v1/boreholes", {
        "name": "Feb 29 Valid Leap 2024",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 80.0,
        "pump_type": "solar",
        "yield_lph": 2500,
        "implemented_date": "2024-02-29"
    }, token=admin_token)
    check("Accept Valid Leap Year Date ('2024-02-29') -> 201", status == 201, f"Got status {status}")

    # ----------------------------------------------------
    # 6. IDENTIFIERS & PATH PARAMETERS
    # ----------------------------------------------------
    print("\n--- 6. Testing Identifier & Path Parameter Handling ---")

    # A. Nonexistent Borehole ID
    status, _ = make_request("GET", "/api/v1/boreholes/BH-NONEXISTENT-999")
    check("Nonexistent Borehole ID -> 404 Not Found", status == 404, f"Got status {status}")

    # B. Nonexistent User ID
    status, _ = make_request("GET", "/api/v1/users/USR-NONEXISTENT-999", token=admin_token)
    check("Nonexistent User ID -> 404 Not Found", status == 404, f"Got status {status}")

    # C. Oversized ID Parameter (>50 chars)
    oversized_id = "A" * 100
    status, _ = make_request("GET", f"/api/v1/boreholes/{oversized_id}")
    check("Reject Oversized Path ID (>50 chars) -> 400", status == 400, f"Got status {status}")

    # ----------------------------------------------------
    # 7. MASS ASSIGNMENT & PRIVILEGE ELEVATION PROTECTION
    # ----------------------------------------------------
    print("\n--- 7. Testing Mass Assignment & Privilege Elevation Protection ---")

    # A. User Update attempting to inject "role": "admin" or "password_hash"
    # Create normal test user
    test_email = f"mass_assign_{int(time.time())}@equiwell.nam"
    status, reg_res = make_request("POST", "/api/v1/users/register", {
        "name": "Mass Assign Target",
        "email": test_email,
        "password": "Password123!"
    })
    target_user_id = reg_res.get("user_id")

    # Attempt mass assignment on PUT /users/{id}
    status, _ = make_request("PUT", f"/api/v1/users/{target_user_id}", {
        "name": "Tampered Name",
        "role": "admin",
        "password_hash": "evil_injected_hash",
        "id": "USR-HIJACKED",
        "created_at": "1990-01-01T00:00:00Z"
    }, token=admin_token)
    check("PUT /users/{id} processes cleanly without crash", status == 200, f"Got status {status}")

    # Verify role was NOT elevated to admin
    status, user_obj = make_request("GET", f"/api/v1/users/{target_user_id}", token=admin_token)
    check("Mass Assignment: role is still viewer (not elevated)", user_obj.get("role") == "viewer", f"Role was: {user_obj.get('role')}")
    check("Mass Assignment: id was not hijacked", user_obj.get("id") == target_user_id, f"ID was: {user_obj.get('id')}")

    # B. Non-Admin attempting to call PATCH /users/{id}/role
    status, _ = make_request("PATCH", f"/api/v1/users/{target_user_id}/role", {
        "role": "admin"
    }, token=viewer_token)
    check("Viewer role change blocked by RBAC -> 403 Forbidden", status == 403, f"Got status {status}")

    # ----------------------------------------------------
    # 8. MALFORMED JSON, TYPE MISMATCHES & EMPTY PAYLOADS
    # ----------------------------------------------------
    print("\n--- 8. Testing Malformed JSON, Type Mismatches & Empty Payloads ---")

    # A. String passed where Float expected
    status, _ = make_request("POST", "/api/v1/boreholes", raw_body='{"name":"Site","lat":"south","lng":13.5,"depth_m":80.0,"pump_type":"solar","yield_lph":2500}', token=admin_token)
    check("Reject String for Float Field -> 400", status == 400, f"Got status {status}")

    # B. Array passed where String expected
    status, _ = make_request("POST", "/api/v1/boreholes", raw_body='{"name":["Site"],"lat":-18.5,"lng":13.5,"depth_m":80.0,"pump_type":"solar","yield_lph":2500}', token=admin_token)
    check("Reject Array for String Field -> 400", status == 400, f"Got status {status}")

    # C. Empty JSON Object on Required Fields
    status, _ = make_request("POST", "/api/v1/boreholes", raw_body='{}', token=admin_token)
    check("Reject Empty Object on POST /boreholes -> 400", status == 400, f"Got status {status}")

    # D. Empty Patch Request
    status, _ = make_request("PATCH", "/api/v1/boreholes/BH-1002", raw_body='{}', token=admin_token)
    check("Reject Empty PATCH Body -> 400", status == 400, f"Got status {status}")

    # E. Malformed JSON Syntax (Unclosed Brace)
    status, _ = make_request("POST", "/api/v1/boreholes", raw_body='{"name": "Broken JSON"', token=admin_token)
    check("Reject Malformed JSON Syntax -> 400", status == 400, f"Got status {status}")

    # ----------------------------------------------------
    # 9. VALID BOUNDARY ACCEPTANCE (NO FALSE POSITIVES)
    # ----------------------------------------------------
    print("\n--- 9. Testing Valid Boundary Acceptance ---")

    # A. Valid Extreme Coordinates: -90.0 and 180.0
    status, res = make_request("POST", "/api/v1/boreholes", {
        "name": "Extreme Coordinate Borehole",
        "lat": -90.0,
        "lng": 180.0,
        "depth_m": 120.0,
        "pump_type": "hybrid",
        "yield_lph": 4500,
        "implemented_date": "2026-09-29"
    }, token=admin_token)
    check("Accept Valid Boundary Coordinates (lat=-90.0, lng=180.0) -> 201", status == 201, f"Got status {status}")

    # B. Valid Battery Percentage 100%
    status, res = make_request("POST", "/api/v1/boreholes/BH-1002/telemetry", {
        "drawdown_m": 3.5,
        "recovery_time_mins": 30,
        "solar_battery_level": 100,
        "flow_rate_lpm": 45.0
    }, token=admin_token)
    check("Accept Valid Battery Level 100% -> 201", status == 201, f"Got status {status}")

    # C. Valid Battery Percentage 0%
    status, res = make_request("POST", "/api/v1/boreholes/BH-1002/telemetry", {
        "drawdown_m": 0.0,
        "recovery_time_mins": 10,
        "solar_battery_level": 0,
        "flow_rate_lpm": 0.0
    }, token=admin_token)
    check("Accept Valid Battery Level 0% -> 201", status == 201, f"Got status {status}")

    # D. Valid Community Request with All Proper Types
    status, res = make_request("POST", "/api/v1/community-requests", {
        "community_name": "Opuwo Rural Settlement",
        "contact_person": "Counselor Tjivikua",
        "contact_phone": "+264 (65) 273-100",
        "issue": "Submersible pump motor failed after sand ingress.",
        "urgency": "high"
    }, token=admin_token)
    check("Accept Valid Community Request -> 201", status == 201, f"Got status {status}")

    # E. Valid Month Endings: 2026-04-30 (30 days) and 2026-12-31 (31 days)
    status, res = make_request("POST", "/api/v1/boreholes", {
        "name": "Month End Valid Borehole 1",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 75.0,
        "pump_type": "solar",
        "yield_lph": 1800,
        "implemented_date": "2026-04-30"
    }, token=admin_token)
    check("Accept Valid Month End ('2026-04-30') -> 201", status == 201, f"Got status {status}")

    status, res = make_request("POST", "/api/v1/boreholes", {
        "name": "Month End Valid Borehole 2",
        "lat": -18.5,
        "lng": 13.5,
        "depth_m": 75.0,
        "pump_type": "solar",
        "yield_lph": 1800,
        "implemented_date": "2026-12-31"
    }, token=admin_token)
    check("Accept Valid Month End ('2026-12-31') -> 201", status == 201, f"Got status {status}")

    print("==================================================================")
    print(f" TOTAL RESULTS: {passed}/{total} Passed ({(passed/total)*100:.0f}% Success Rate)")
    print("==================================================================")

    if passed == total:
        print(" ALL INPUT VALIDATION & DATA INTEGRITY TESTS PASSED")
        sys.exit(0)
    else:
        print(" SOME INPUT VALIDATION TESTS FAILED")
        sys.exit(1)

if __name__ == "__main__":
    run_suite()
