import os
import sys
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn, nsdecls

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=120, right=120):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

core_endpoints = [
    ("POST /users/register", "User Management", "Public / All Users (Defaults to Viewer)", "No"),
    ("POST /users/login", "User Management", "Public / All Registered Users", "No"),
    ("GET /users", "User Management", "Admin", "YES (Admin Only)"),
    ("GET /users/{userId}", "User Management", "Account Owner, Admin", "No"),
    ("PUT /users/{userId}", "User Management", "Account Owner, Admin", "No"),
    ("DELETE /users/{userId}", "User Management", "Admin", "YES (Admin Only)"),
    ("PATCH /users/{userId}/role", "User Management", "Admin", "YES (Admin Only)"),
    
    ("GET /dashboard/summary", "Dashboard Summary", "All Roles (Admin, Health, Maintenance, Community, Viewer)", "No"),
    
    ("GET /boreholes", "Borehole Management", "All Roles (Viewers only see is_visible=true)", "No"),
    ("POST /boreholes", "Borehole Management", "Admin, Maintenance Lead", "No"),
    ("GET /boreholes/{boreholeId}", "Borehole Management", "All Roles", "No"),
    ("PUT /boreholes/{boreholeId}", "Borehole Management", "Admin", "YES (Admin Only)"),
    ("PATCH /boreholes/{boreholeId}", "Borehole Management", "Admin, Maintenance Crew", "No"),
    ("DELETE /boreholes/{boreholeId}", "Borehole Management", "Admin", "YES (Admin Only)"),
    
    ("GET /boreholes/{id}/lab-tests", "Health Inspection", "Health Inspector, Admin", "No"),
    ("POST /boreholes/{id}/lab-tests", "Health Inspection", "Health Inspector, Admin", "No"),
    ("GET /boreholes/{id}/usage-quotas", "Health Inspection", "Health Inspector, Admin", "No"),
    
    ("POST /boreholes/{id}/telemetry", "Maintenance & IoT", "Maintenance Crew, Field Technicians, Admin", "No"),
    ("GET /maintenance-alerts", "Maintenance & IoT", "Maintenance Crew, Admin", "No"),
    ("GET /boreholes/{id}/history", "Maintenance & IoT", "Maintenance Crew, Admin", "No"),
    
    ("GET /allocation-metrics", "Fair Allocation", "Community Leader, Admin, Viewer", "No"),
    ("GET /community-requests", "Fair Allocation", "Community Leader, Admin", "No"),
    ("POST /community-requests", "Fair Allocation", "Community Leader, Admin", "No"),
    
    ("GET /boreholes/{id}/logistics", "Logistics & Routing", "Maintenance Crew, Field Drivers, Admin", "No"),
    ("POST /routes/calculate", "Logistics & Routing", "Maintenance Crew, Field Drivers, Admin", "No"),
    
    ("GET /factors", "AI Siting & Factors", "All Roles (Admin, Researchers, Community, Viewer)", "No"),
    ("POST /suggestions/generate", "AI Siting & Factors", "Community Leader, Maintenance Lead, Admin", "No"),
    ("GET /suggestions/{suggestionId}", "AI Siting & Factors", "Community Leader, Maintenance Lead, Admin", "No")
]

proposed_endpoints = [
    ("POST /routes/google-maps-directions", "Logistics & Routing", "Maintenance Crew, Field Drivers, Admin", "No", 
     "Calls Google Maps Directions API to return turn-by-turn navigation, travel duration, and a direct google_maps_url deep link for field teams."),
    
    ("POST /ai/predict-yield", "AI Siting & Yield", "Hydrogeologists, Field Engineers, Admin", "No", 
     "Direct ML inference using model trained on drilling logs and underground yield maps to predict water yield (L/h) and strike depth."),
    
    ("POST /ai/aquifer-depletion-risk", "AI Siting & Yield", "Health Inspector, Hydrogeologists, Admin", "No", 
     "Simulates 5-10 year multi-year aquifer sustainability under planned daily pumping extraction volumes."),
    
    ("POST /ai/siting-tasks/async", "AI Siting & Yield", "Siting Planners, AI Engine, Admin", "No", 
     "Submits asynchronous high-compute spatial siting optimization across large bounding polygons."),
    
    ("POST /callbacks/ai/siting-complete", "AI Siting & Yield", "Internal AI Compute Cluster, Admin", "No", 
     "Secure internal webhook receiver where the AI cluster pushes completed spatial optimization results back to EquiWell API."),
    
    ("POST /ai/training-data/borehole-logs", "AI Siting & Yield", "Field Data Collection Team, Admin", "No", 
     "Ingests raw field drilling logs (lithology strata, casing depth, water strike levels) directly into the AI training database during data collection rounds."),
    
    ("POST /ai/training-data/yield-maps", "AI Siting & Yield", "GIS / AI Engineers, Admin", "No", 
     "Ingests updated GIS raster/vector groundwater yield maps and fault line layers into the AI geospatial database."),
    
    ("POST /ai/routes/terrain-feasibility", "AI Siting & Yield", "Rig Drivers, Logistics Planners, Admin", "No", 
     "Evaluates off-road slope gradient, soil load capacity, and sand entrapment risk specifically for heavy 20-ton drilling rigs.")
]

def create_word_document(filename):
    doc = docx.Document()
    
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)
        
    title_style = doc.styles.add_style('DocTitle', docx.enum.style.WD_STYLE_TYPE.PARAGRAPH)
    title_style.font.name = 'Arial'
    title_style.font.size = Pt(22)
    title_style.font.bold = True
    title_style.font.color.rgb = RGBColor(15, 76, 129)
    
    h1_style = doc.styles['Heading 1']
    h1_style.font.name = 'Arial'
    h1_style.font.size = Pt(15)
    h1_style.font.bold = True
    h1_style.font.color.rgb = RGBColor(15, 76, 129)
    
    h2_style = doc.styles['Heading 2']
    h2_style.font.name = 'Arial'
    h2_style.font.size = Pt(12)
    h2_style.font.bold = True
    h2_style.font.color.rgb = RGBColor(41, 128, 185)
    
    # Document Header
    p_title = doc.add_paragraph('EquiWell API System Architecture & Role-Based Access Control Specification', style='DocTitle')
    p_sub = doc.add_paragraph('Technical Implementation Guide, Core Endpoints & Proposed Protocol Extensions')
    p_sub.runs[0].font.size = Pt(12)
    p_sub.runs[0].font.color.rgb = RGBColor(100, 110, 120)
    
    # Metadata Table
    meta_table = doc.add_table(rows=5, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.LEFT
    meta_data = [
        ("Project:", "EquiWell Borehole Management & Fair Allocation Platform"),
        ("Target Region:", "Kunene Region, Namibia"),
        ("Author / Student:", "Reinhold Ndevahoma (Software Engineering, NUST)"),
        ("Supervisor:", "Prof. Jose Quenum (Department of Software Engineering, NUST)"),
        ("Implementation Stack:", "Zig Backend Core API | OpenAPI 3.0 (v2) | Google Maps API | Hydro ML Subsystem")
    ]
    for i, (k, v) in enumerate(meta_data):
        row = meta_table.rows[i]
        c0, c1 = row.cells[0], row.cells[1]
        c0.width = Inches(1.8)
        c1.width = Inches(5.0)
        p0 = c0.paragraphs[0]
        r0 = p0.add_run(k)
        r0.bold = True
        r0.font.size = Pt(9.5)
        p1 = c1.paragraphs[0]
        r1 = p1.add_run(v)
        r1.font.size = Pt(9.5)
        set_cell_background(c0, "F2F5F8")
        set_cell_background(c1, "FFFFFF")
    
    doc.add_paragraph().paragraph_format.space_after = Pt(10)
    
    # Section 1: Executive Summary
    doc.add_heading('1. Executive Summary & Architecture Overview', level=1)
    doc.add_paragraph(
        "EquiWell is a distributed software platform and middleware API designed to manage physical water infrastructure, "
        "enforce equitable aquifer extraction quotas, calculate rugged off-road logistics, and perform predictive borehole siting "
        "in the arid, mountainous Kunene Region of Namibia.\n\n"
        "This specification establishes the technical implementation in the Zig programming language, introduces explicit Role-Based "
        "Access Control (RBAC) with cryptographic JSON Web Tokens (JWT), tracks historical borehole implementation/commissioning dates, "
        "and defines the proposed protocol extensions for a dedicated hydrogeological machine learning engine and Google Maps routing."
    )
    
    # Section 2: User Roles & Security
    doc.add_heading('2. User Roles & Security Architecture (RBAC in Zig)', level=1)
    doc.add_paragraph(
        "To ensure that each user role can only exercise designated actions and to protect critical public water assets against unauthorized "
        "tampering or deletion, the system enforces a strict Role-Based Access Control (RBAC) model:\n"
    )
    
    doc.add_heading('2.1 User Role Definitions & Privileges', level=2)
    roles = [
        ("1. System Administrator ('admin')", 
         "Has complete authority across all system resources. Admin is the ONLY role permitted to permanently delete records (DELETE /boreholes/{id}, DELETE /users/{id}), alter core engineering attributes (PUT /boreholes/{id}), or elevate/modify user roles (PATCH /users/{userId}/role)."),
        ("2. Health Inspector ('health_inspector')", 
         "Certified public health and water quality officer. Authorized to upload certified physical water lab reports (POST /boreholes/{id}/lab-tests) regarding biological (E. coli) and heavy metal (Arsenic, Fluoride) contaminants, and monitor monthly community extraction vs. sustainable aquifer quotas."),
        ("3. Maintenance Crew / Field Technician ('maintenance_crew')", 
         "Field technicians responsible for physical infrastructure upkeep. Authorized to ingest automated IoT sensor telemetry (POST /boreholes/{id}/telemetry), toggle operational status (working/broken via PATCH /boreholes/{id}), review active alerts, and generate Google Maps turn-by-turn navigation routes to sites."),
        ("4. Community Leader / Local Representative ('community_leader')", 
         "Verified local traditional authority or settlement representative. Authorized to submit emergency water scarcity assistance requests (POST /community-requests) and review regional demographic equity metrics."),
        ("5. Viewer / Public User ('viewer')", 
         "Public stakeholders, NGOs, and research viewers. Granted strictly read-only access to high-level dashboard summaries (GET /dashboard/summary), publicly visible boreholes (GET /boreholes?is_visible=true), and siting criteria factors.")
    ]
    for title, desc in roles:
        p_role = doc.add_paragraph()
        r_title = p_role.add_run(f"• {title}: ")
        r_title.bold = True
        r_title.font.color.rgb = RGBColor(15, 76, 129)
        p_role.add_run(desc)
        
    doc.add_heading('2.2 Security Enforcement & Cryptographic Token Flow in Zig', level=2)
    doc.add_paragraph(
        "1. Password Hashing: Encrypted using the memory-hard Argon2id hashing algorithm during user registration.\n"
        "2. JWT Authentication: Upon successful login (POST /users/login), the server issues a signed JWT containing cryptographic claims (user_id, role, exp).\n"
        "3. Middleware Authorization Interceptor: An HTTP request interceptor in Zig inspects the 'Authorization: Bearer <token>' header on every request, validates the HMAC-SHA256 signature, extracts the user role, and matches it against the Endpoint Access Control List (ACL)."
    )
    
    doc.add_heading('2.3 Principle of Least Privilege (Admin Restriction)', level=2)
    doc.add_paragraph(
        "The system strictly isolates destructive and mutative actions. If a non-admin role attempts a restricted action "
        "(e.g. deleting a borehole, deleting a user, or updating a role), the Zig middleware immediately aborts execution and responds with HTTP 403 Forbidden."
    )
    
    # Section 3: Master Method Table
    doc.add_heading('3. Master Method & User Role Authorization Matrix', level=1)
    doc.add_paragraph(
        "The tables below explicitly define every endpoint, its category, authorized invoking user role(s), "
        "and whether the action is restricted to Admin only."
    )
    
    # Subsection 3.1
    doc.add_heading('3.1 Core Operational Endpoints (Implemented in Zig)', level=2)
    tbl_core = doc.add_table(rows=len(core_endpoints) + 1, cols=4)
    tbl_core.alignment = WD_TABLE_ALIGNMENT.CENTER
    headers = ["API Endpoint & Method", "Category", "Authorized Invoking Role(s)", "Admin Only?"]
    hdr_row = tbl_core.rows[0]
    for j, h in enumerate(headers):
        cell = hdr_row.cells[j]
        cell.paragraphs[0].add_run(h).bold = True
        cell.paragraphs[0].runs[0].font.color.rgb = RGBColor(255, 255, 255)
        cell.paragraphs[0].runs[0].font.size = Pt(9)
        set_cell_background(cell, "0F4C81")
        set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
        
    for i, (ep, cat, roles, admin_only) in enumerate(core_endpoints):
        row = tbl_core.rows[i + 1]
        c0, c1, c2, c3 = row.cells[0], row.cells[1], row.cells[2], row.cells[3]
        
        p0 = c0.paragraphs[0]
        r0 = p0.add_run(ep)
        r0.font.name = 'Consolas'
        r0.font.size = Pt(8.5)
        r0.bold = True
        
        c1.paragraphs[0].add_run(cat).font.size = Pt(8.5)
        c2.paragraphs[0].add_run(roles).font.size = Pt(8.5)
        
        r3 = c3.paragraphs[0].add_run(admin_only)
        r3.font.size = Pt(8.5)
        if "YES" in admin_only:
            r3.bold = True
            r3.font.color.rgb = RGBColor(192, 57, 43)
            
        bg_hex = "F9FBFC" if i % 2 == 0 else "FFFFFF"
        for c in [c0, c1, c2, c3]:
            set_cell_background(c, bg_hex)
            set_cell_margins(c, top=60, bottom=60, left=80, right=80)
            
    doc.add_paragraph().paragraph_format.space_after = Pt(10)
    
    # Subsection 3.2
    doc.add_heading('3.2 Proposed Protocol Extension Endpoints (For Discussion & AI Integration)', level=2)
    doc.add_paragraph(
        "The endpoints below are proposed extensions for the next milestone to interface with external AI models, "
        "support active learning from field data collection, and integrate Google Maps routing:"
    )
    
    tbl_prop = doc.add_table(rows=len(proposed_endpoints) + 1, cols=4)
    tbl_prop.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr_row2 = tbl_prop.rows[0]
    for j, h in enumerate(headers):
        cell = hdr_row2.cells[j]
        cell.paragraphs[0].add_run(h).bold = True
        cell.paragraphs[0].runs[0].font.color.rgb = RGBColor(255, 255, 255)
        cell.paragraphs[0].runs[0].font.size = Pt(9)
        set_cell_background(cell, "0F4C81")
        set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
        
    for i, (ep, cat, roles, admin_only, desc) in enumerate(proposed_endpoints):
        row = tbl_prop.rows[i + 1]
        c0, c1, c2, c3 = row.cells[0], row.cells[1], row.cells[2], row.cells[3]
        
        p0 = c0.paragraphs[0]
        r0 = p0.add_run(ep)
        r0.font.name = 'Consolas'
        r0.font.size = Pt(8.5)
        r0.bold = True
        
        c1.paragraphs[0].add_run(cat).font.size = Pt(8.5)
        c2.paragraphs[0].add_run(roles).font.size = Pt(8.5)
        
        r3 = c3.paragraphs[0].add_run(admin_only)
        r3.font.size = Pt(8.5)
        if "YES" in admin_only:
            r3.bold = True
            r3.font.color.rgb = RGBColor(192, 57, 43)
            
        bg_hex = "F9FBFC" if i % 2 == 0 else "FFFFFF"
        for c in [c0, c1, c2, c3]:
            set_cell_background(c, bg_hex)
            set_cell_margins(c, top=60, bottom=60, left=80, right=80)
            
    doc.add_paragraph().paragraph_format.space_after = Pt(10)
    
    # Section 4: Core Functional Modules
    doc.add_heading('4. Core Operational Functional Modules (Implemented in Zig)', level=1)
    
    core_modules = [
        ("4.1 User Management & Role Administration",
         "Manages authentication, registration, profile updates, and role modifications.\n"
         "• POST /users/register: Open registration. Ingests user credentials.\n"
         "• POST /users/login: Verifies credentials, returns signed JWT with user role.\n"
         "• GET /users: (Admin Only) Lists all system users and permissions.\n"
         "• GET /users/{userId}: Fetches individual user profile details.\n"
         "• PUT /users/{userId}: (Account Owner or Admin) Updates user profile.\n"
         "• DELETE /users/{userId}: (Admin Only) Deactivates user accounts.\n"
         "• PATCH /users/{userId}/role: (Admin Only) Elevates roles (e.g. to health_inspector)."),
        
        ("4.2 Dashboard Summary & Implementation Timeline",
         "Provides fast statistical aggregates for dashboard landing widgets without client-side computation.\n"
         "• GET /dashboard/summary: Accessible by all roles. Returns total active, broken boreholes, communities at risk, "
         "recent installations this year, and the latest borehole implementation date (e.g. '2026-06-18')."),
        
        ("4.3 Borehole Infrastructure Management & Lifecycle",
         "Tracks physical infrastructure assets, pump types (solar, diesel, windmill, hand_pump), coordinates, and implementation dates.\n"
         "• GET /boreholes: Lists mapped boreholes including implementation date (implemented_date).\n"
         "• POST /boreholes: (Admin / Maintenance Lead) Registers new borehole with implementation date.\n"
         "• GET /boreholes/{boreholeId}: Fetches full physical metrics, depth, water quality, and implemented_date.\n"
         "• PUT /boreholes/{boreholeId}: (Admin Only) Fully modifies engineering attributes.\n"
         "• PATCH /boreholes/{boreholeId}: (Admin / Maintenance Crew) Toggles operational state (working/broken).\n"
         "• DELETE /boreholes/{boreholeId}: (Admin Only) Archives/removes borehole infrastructure."),
        
        ("4.4 Health Inspection & Water Safety Operations",
         "Restricted to Health Inspectors and Admins to ensure drinking water safety.\n"
         "• POST /boreholes/{boreholeId}/lab-tests: Ingests official certified lab results (E. coli, Fluoride, Arsenic) and safety flag.\n"
         "• GET /boreholes/{boreholeId}/lab-tests: Fetches historical lab results.\n"
         "• GET /boreholes/{boreholeId}/usage-quotas: Compares monthly extraction against sustainable aquifer limits."),
        
        ("4.5 Maintenance, IoT Telemetry & Proactive Alerts",
         "Enables field crews to push sensor telemetry and monitor breakdown alerts.\n"
         "• POST /boreholes/{boreholeId}/telemetry: (Maintenance Crew) Ingests automated sensor data (drawdown, recovery time, solar battery, flow rate).\n"
         "• GET /maintenance-alerts: (Maintenance Crew / Admin) Retrieves boreholes flagged for immediate repair.\n"
         "• GET /boreholes/{boreholeId}/history: Yield trend analytics over time."),
        
        ("4.6 Fair Allocation & Community Advocacy",
         "Captures community demand and assesses water equity.\n"
         "• GET /allocation-metrics: Demographic scarcity indicators and fairness scores.\n"
         "• GET /community-requests: Lists all submitted community requests.\n"
         "• POST /community-requests: (Community Leaders) Submits formal emergency water assistance requests."),
        
        ("4.7 Logistics & Internal Pathfinding",
         "Navigates maintenance teams across rugged Kunene terrain.\n"
         "• GET /boreholes/{boreholeId}/logistics: Returns vehicle requirements (e.g. 4x4 mandatory) and rain warnings.\n"
         "• POST /routes/calculate: Internal pathfinder avoiding flooded riverbeds and fragile terrain."),
        
        ("4.8 AI Siting Criteria & Suggestions Baseline",
         "Baseline endpoints for querying environmental factors and requesting AI suggestions.\n"
         "• GET /factors: Retrieves geological and environmental criteria.\n"
         "• POST /suggestions/generate: Submits regional criteria to trigger siting calculations.\n"
         "• GET /suggestions/{suggestionId}: Retrieves completed AI site recommendations.")
    ]
    for heading, text in core_modules:
        doc.add_heading(heading, level=2)
        doc.add_paragraph(text)
        
    # Section 5: Detailed Proposed Extensions
    doc.add_heading('5. Detailed Specification of Proposed Protocol Extensions', level=1)
    doc.add_paragraph(
        "The following subsections detail the architectural design, invocation rules, and payload structure for the 8 proposed extension endpoints:\n"
    )
    
    proposed_details = [
        ("5.1 Google Maps Navigation API Integration",
         "• POST /routes/google-maps-directions\n"
         "• Authorized Invoking User Role(s): Maintenance Crew, Field Drivers, Admin\n"
         "• Purpose: Calls Google Maps Directions API to compute turn-by-turn navigation from the vehicle's GPS position to an existing borehole or proposed drilling site. Returns polyline, waypoints, travel duration, and a ready-to-open 'google_maps_url' deep link for drivers."),
        
        ("5.2 AI Machine Learning Yield Prediction & Strike Depth",
         "• POST /ai/predict-yield\n"
         "• Authorized Invoking User Role(s): Hydrogeologists, Field Engineers, Admin\n"
         "• Purpose: Direct ML inference. Accepts exact coordinates and runs them against the trained drilling model and underground water yield maps to predict water yield (L/h), static water level, and expected strike depth."),
        
        ("5.3 Long-Term Aquifer Depletion & Recharge Risk Simulation",
         "• POST /ai/aquifer-depletion-risk\n"
         "• Authorized Invoking User Role(s): Health Inspector, Hydrogeologists, Admin\n"
         "• Purpose: Simulates multi-year (5-10 year) aquifer drawdown and depletion risk under projected daily pumping volumes and regional recharge rates."),
        
        ("5.4 Asynchronous Siting Optimization & Webhook Protocol",
         "• POST /ai/siting-tasks/async & POST /callbacks/ai/siting-complete\n"
         "• Authorized Invoking User Role(s): Siting Planners, AI Engine, Admin\n"
         "• Purpose: Non-blocking asynchronous protocol. Submits heavy multi-criteria spatial optimization jobs across large bounding polygons and allows the AI compute engine to push completed results back via a secure webhook."),
        
        ("5.5 Active Learning & Field Data Collection Ingestion (Borehole Logs)",
         "• POST /ai/training-data/borehole-logs\n"
         "• Authorized Invoking User Role(s): Field Data Collection Team, Admin\n"
         "• Purpose: Built specifically for the upcoming field data collection round to ingest raw lithological drilling logs (strata layers, casing depth, water strike depths, pump-tested yield) directly into the AI training database."),
        
        ("5.6 Geospatial Yield Maps & GIS Raster Ingestion",
         "• POST /ai/training-data/yield-maps\n"
         "• Authorized Invoking User Role(s): GIS / AI Engineers, Admin\n"
         "• Purpose: Ingests and updates GIS vector/raster groundwater yield maps and fault line layers into the AI spatial database."),
        
        ("5.7 Heavy 20-Ton Drilling Rig Terrain Feasibility",
         "• POST /ai/routes/terrain-feasibility\n"
         "• Authorized Invoking User Role(s): Rig Drivers, Logistics Planners, Admin\n"
         "• Purpose: Evaluates slope gradient, soil load-bearing capacity, and sand entrapment risk specifically for heavy 20-ton drilling rigs navigating the Kunene terrain.")
    ]
    for heading, text in proposed_details:
        doc.add_heading(heading, level=2)
        doc.add_paragraph(text)
        
    # Section 6: Field Data Collection Campaign
    doc.add_heading('6. Upcoming Field Data Collection Campaign Integration', level=1)
    doc.add_paragraph(
        "The proposed endpoints directly support the upcoming first round of data collection in the Kunene Region:\n"
        "1. Ingestion of Field Drilling Data: Field teams will log raw stratigraphy, casing depths, and water strike levels "
        "directly into the AI training database via POST /ai/training-data/borehole-logs.\n"
        "2. Water Quality Ingestion: Certified health inspectors log physical water test reports via POST /boreholes/{id}/lab-tests.\n"
        "3. IoT Telemetry Sync: Automated solar pump sensors push real-time dynamic drawdown and recovery metrics via POST /boreholes/{id}/telemetry."
    )
    
    # Section 7: Technical Stack in Zig
    doc.add_heading('7. Technical Stack & Deployment Architecture in Zig', level=1)
    doc.add_paragraph(
        "• Core Middleware: Implemented in Zig using std.http for zero garbage collection pauses and optimal memory predictability.\n"
        "• Database Layer: Operational light data store (PostgreSQL/SQLite) paired with an isolated Geospatial AI Database (PostGIS/Raster).\n"
        "• Security Standard: Argon2id password encryption, HMAC-SHA256 signed JWTs with role-scoped claims, and strict RBAC authorization middleware."
    )
    
    doc.save(filename)
    print(f"Word document saved to {filename}")

def create_pdf_document(filename):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )
    
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=colors.HexColor('#0F4C81'),
        spaceAfter=4
    )
    
    sub_style = ParagraphStyle(
        'DocSub',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13,
        textColor=colors.HexColor('#555555'),
        spaceAfter=10
    )
    
    h1_style = ParagraphStyle(
        'H1',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=11.5,
        leading=15,
        textColor=colors.HexColor('#0F4C81'),
        spaceBefore=11,
        spaceAfter=4,
        keepWithNext=True
    )
    
    h2_style = ParagraphStyle(
        'H2',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=9.5,
        leading=13,
        textColor=colors.HexColor('#2980B9'),
        spaceBefore=8,
        spaceAfter=3,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor('#222222'),
        spaceAfter=4
    )
    
    table_cell_style = ParagraphStyle(
        'TCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7,
        leading=9,
        textColor=colors.HexColor('#222222')
    )
    
    table_code_style = ParagraphStyle(
        'TCode',
        parent=styles['Normal'],
        fontName='Courier-Bold',
        fontSize=7,
        leading=8.5,
        textColor=colors.HexColor('#0F4C81')
    )
    
    table_hdr_style = ParagraphStyle(
        'THdr',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=10,
        textColor=colors.white
    )
    
    story = []
    
    # Title
    story.append(Paragraph("EquiWell API Architecture & RBAC Specification", title_style))
    story.append(Paragraph("Technical Implementation Guide, Core Endpoints & Proposed Protocol Extensions", sub_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#0F4C81'), spaceAfter=8))
    
    # Metadata Table
    meta_data = [
        [Paragraph("<b>Project:</b>", body_style), Paragraph("EquiWell Borehole Management & Fair Allocation Platform", body_style)],
        [Paragraph("<b>Target Region:</b>", body_style), Paragraph("Kunene Region, Namibia", body_style)],
        [Paragraph("<b>Author / Student:</b>", body_style), Paragraph("Reinhold Ndevahoma (Software Engineering, NUST)", body_style)],
        [Paragraph("<b>Supervisor:</b>", body_style), Paragraph("Prof. Jose Quenum (Department of Software Engineering, NUST)", body_style)],
        [Paragraph("<b>Stack:</b>", body_style), Paragraph("Zig Core API | OpenAPI 3.0 (v2) | Google Maps API | Hydro ML Subsystem", body_style)]
    ]
    t_meta = Table(meta_data, colWidths=[1.3*inch, 5.9*inch])
    t_meta.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 2),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2),
    ]))
    story.append(t_meta)
    story.append(Spacer(1, 6))
    
    # Section 1
    story.append(Paragraph("1. Executive Summary & Architecture Overview", h1_style))
    story.append(Paragraph(
        "<b>EquiWell</b> is an API middleware implemented in <b>Zig</b>. It manages water infrastructure in the Kunene Region, "
        "enforcing fair aquifer quotas, calculating off-road logistics, and interfacing with an external AI engine for hydrogeological siting.",
        body_style
    ))
    
    # Section 2
    story.append(Paragraph("2. User Roles & Security Architecture (RBAC in Zig)", h1_style))
    story.append(Paragraph("<b>2.1 User Role Definitions & Privileges</b>", h2_style))
    roles_summary = [
        "<b>• Admin ('admin'):</b> Full system authority. Exclusively authorized for deletions (DELETE), full data updates (PUT), and role elevations.",
        "<b>• Health Inspector ('health_inspector'):</b> Public health officer. Authorized to log water lab reports (POST /lab-tests) and monitor usage quotas.",
        "<b>• Maintenance Crew ('maintenance_crew'):</b> Field technicians. Authorized to push IoT telemetry, review alerts, update status (working/broken), and access Google Maps routing.",
        "<b>• Community Leader ('community_leader'):</b> Local representative. Authorized to submit water assistance requests and view fairness scores.",
        "<b>• Viewer / Public ('viewer'):</b> Public user. Read-only access to dashboard statistics and visible map markers."
    ]
    for r in roles_summary:
        story.append(Paragraph(r, body_style))
        
    story.append(Paragraph("<b>2.2 Security Enforcement & Least Privilege in Zig</b>", h2_style))
    story.append(Paragraph(
        "Passwords use Argon2id. Login generates signed JWTs. Zig middleware intercepts all calls to enforce role permissions. "
        "<b>Only Admin users are permitted to delete or alter core data (unauthorized attempts receive HTTP 403 Forbidden).</b>",
        body_style
    ))
    story.append(Spacer(1, 4))
    
    # Section 3
    story.append(Paragraph("3. Master Method & User Role Authorization Matrix", h1_style))
    story.append(Paragraph("<b>3.1 Core Operational Endpoints (Implemented in Zig)</b>", h2_style))
    
    tbl_core_data = [[
        Paragraph("<b>API Endpoint & Method</b>", table_hdr_style),
        Paragraph("<b>Category</b>", table_hdr_style),
        Paragraph("<b>Authorized Invoking Role(s)</b>", table_hdr_style),
        Paragraph("<b>Admin Only?</b>", table_hdr_style)
    ]]
    for ep, cat, roles, admin_only in core_endpoints:
        admin_p = Paragraph(f"<font color='#C0392B'><b>{admin_only}</b></font>" if "YES" in admin_only else admin_only, table_cell_style)
        tbl_core_data.append([
            Paragraph(ep, table_code_style),
            Paragraph(cat, table_cell_style),
            Paragraph(roles, table_cell_style),
            admin_p
        ])
    t_core = Table(tbl_core_data, colWidths=[2.3*inch, 1.1*inch, 2.7*inch, 1.1*inch])
    t_core.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#0F4C81')),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.HexColor('#F8FAFC'), colors.white])
    ]))
    story.append(t_core)
    story.append(Spacer(1, 6))
    
    story.append(Paragraph("<b>3.2 Proposed Protocol Extension Endpoints (For Discussion & AI Integration)</b>", h2_style))
    story.append(Paragraph("The following endpoints are proposed extensions for discussion to connect external AI models and Google Maps:", body_style))
    
    tbl_prop_data = [[
        Paragraph("<b>Proposed Endpoint & Method</b>", table_hdr_style),
        Paragraph("<b>Category</b>", table_hdr_style),
        Paragraph("<b>Authorized Invoking Role(s)</b>", table_hdr_style),
        Paragraph("<b>Admin Only?</b>", table_hdr_style)
    ]]
    for ep, cat, roles, admin_only, desc in proposed_endpoints:
        admin_p = Paragraph(f"<font color='#C0392B'><b>{admin_only}</b></font>" if "YES" in admin_only else admin_only, table_cell_style)
        tbl_prop_data.append([
            Paragraph(ep, table_code_style),
            Paragraph(cat, table_cell_style),
            Paragraph(roles, table_cell_style),
            admin_p
        ])
    t_prop = Table(tbl_prop_data, colWidths=[2.3*inch, 1.1*inch, 2.7*inch, 1.1*inch])
    t_prop.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#0F4C81')),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E2E8F0')),
        ('TOPPADDING', (0,0), (-1,-1), 1.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 1.5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.HexColor('#F8FAFC'), colors.white])
    ]))
    story.append(t_prop)
    story.append(Spacer(1, 8))
    
    # Section 4
    story.append(Paragraph("4. Core Operational Functional Modules (Implemented in Zig)", h1_style))
    core_modules_summary = [
        "<b>4.1 User Management:</b> Ingests registrations, validates credentials, returns JWT with role claims, and enforces Admin-only role modifications/deletions.",
        "<b>4.2 Dashboard Summary:</b> Fast aggregate stats including recent implementations and latest installation date (implemented_date).",
        "<b>4.3 Borehole Infrastructure:</b> CRUD operations tracking pump types, coordinates, and implemented_date. Only Admin can delete or alter data.",
        "<b>4.4 Health Inspection:</b> Ingests certified water quality lab tests (E. coli, Fluoride, Arsenic) and compares extraction vs. aquifer quotas.",
        "<b>4.5 Maintenance & IoT:</b> Logs automated sensor telemetry (drawdown, recovery, solar battery) and tracks maintenance alerts.",
        "<b>4.6 Fair Allocation:</b> Ingests community water requests and returns demographic parity and scarcity indicators.",
        "<b>4.7 Logistics & Pathfinding:</b> Tracks vehicle terrain requirements and calculates safe off-road tracks avoiding flooded rivers.",
        "<b>4.8 AI Siting Baseline:</b> Queries environmental criteria and retrieves AI-recommended borehole coordinates."
    ]
    for m in core_modules_summary:
        story.append(Paragraph(m, body_style))
    story.append(Spacer(1, 6))
    
    # Section 5
    story.append(Paragraph("5. Detailed Specification of Proposed Protocol Extensions", h1_style))
    for ep, cat, roles, admin_only, desc in proposed_endpoints:
        story.append(Paragraph(f"<b>• {ep}</b> (Invoked by: {roles})", body_style))
        story.append(Paragraph(f"  {desc}", body_style))
    story.append(Spacer(1, 6))
    
    # Section 6
    story.append(Paragraph("6. Upcoming Field Data Collection Campaign Integration", h1_style))
    story.append(Paragraph(
        "The proposed endpoints directly support the upcoming first round of data collection in the Kunene Region: "
        "field teams log drilling logs via POST /ai/training-data/borehole-logs, health inspectors record lab tests "
        "via POST /boreholes/{id}/lab-tests, and IoT pump sensors push telemetry via POST /boreholes/{id}/telemetry.",
        body_style
    ))
    
    # Section 7
    story.append(Paragraph("7. Technical Stack & Deployment Architecture in Zig", h1_style))
    story.append(Paragraph(
        "Core middleware in Zig with std.http, operational SQLite/PostgreSQL store paired with PostGIS AI database, "
        "and Argon2id + HMAC-SHA256 JWT security.",
        body_style
    ))
    
    doc.build(story)
    print(f"PDF document saved to {filename}")

if __name__ == "__main__":
    docx_primary = r"c:\Users\Rauna\Desktop\Equiwell 02\EquiWell_API_Implementation_and_RBAC_Specification.docx"
    docx_v2 = r"c:\Users\Rauna\Desktop\Equiwell 02\EquiWell_API_Implementation_and_RBAC_Specification_v2.docx"
    pdf_primary = r"c:\Users\Rauna\Desktop\Equiwell 02\EquiWell_API_Implementation_and_RBAC_Specification.pdf"
    
    try:
        create_word_document(docx_primary)
    except PermissionError:
        pass
        
    create_word_document(docx_v2)
    create_pdf_document(pdf_primary)
