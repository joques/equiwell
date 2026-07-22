# Equi Well API Specification
**Version:** 1.0.0
**Target Region:** Kunene Region, Namibia
**Architecture:** RESTful API documented via OpenAPI (Swagger)

---

> [!NOTE] 
> **Architectural Concept:** This API acts as the middleware connecting the User Dashboard to backend resources. To maintain efficiency, the API manages a **light data store** to process standard, immediate requests (like fetching mapped boreholes or basic factors). For more complex queries-specifically those generating new borehole site suggestions or routing-the API interacts with **third-party components (AI algorithms and models)**.

> [!TIP]
> **Primary Aim:** The core focus of this system is **water management using borehole siting**, with a specific emphasis on **fair borehole allocation**. The endpoints below are designed to make all information related to fair allocation, maintenance, logistics, and community needs accessible.

---

## 1. Dashboard Summary & Map Data Endpoints

These endpoints provide the high-level data needed to render the primary dashboard interface.

### `GET /api/v1/dashboard/summary`
*   **Purpose:** Retrieve a high-level statistical summary for the dashboard landing page.
*   **Reason:** Instead of the frontend calculating everything, this endpoint returns quick stats (e.g., total active boreholes, total broken, communities currently at risk) to populate the summary widgets at the top of the dashboard.

### `GET /api/v1/boreholes`
*   **Purpose:** Retrieve all mapped boreholes for dashboard visualization.
*   **Query Parameters:** 
    *   `?is_visible=true` (Hides decommissioned sites)
    *   `?pump_type=solar` (Filters by energy type: `solar`, `diesel`, `windmill`, `hand_pump`)
*   **Reason:** Populates the interactive dashboard map with map markers, coordinates, operational status, and water yield.

### `GET /api/v1/boreholes/{boreholeId}`
*   **Purpose:** Get detailed metrics on a specific borehole.
*   **Reason:** Fetches specific details for dashboard popups.

---

## 2. Borehole Management & Upkeep

### `POST /api/v1/boreholes`
*   **Purpose:** Register a newly sited and drilled borehole.
*   **Reason:** Updates the database map to reflect new infrastructure.

### `PATCH /api/v1/boreholes/{boreholeId}`
*   **Purpose:** Partially update borehole attributes.
*   **Reason:** Quickly toggle a borehole to **"not working"** or switch `is_visible` to `false` to hide it from the map without deleting the historical data.

### `GET /api/v1/maintenance-alerts`
*   **Purpose:** Fetch a list of boreholes flagged for immediate repair.
*   **Reason:** Allows the dashboard to highlight red "broken" or "at-risk" zones on the map.

---

## 3. Water Quality & Usage Quotas (NEW)

Real-world water management requires ensuring the water is safe to drink and that the aquifer isn't being drained unfairly.

### `POST /api/v1/boreholes/{boreholeId}/lab-tests`
*   **Purpose:** Upload formal laboratory water quality results.
*   **Reason:** If manual lab testing finds E. coli, Arsenic, or extreme Fluoride levels, this endpoint allows a health inspector to log the official report, which can automatically trigger a "DO NOT DRINK" warning on the dashboard map.

### `GET /api/v1/boreholes/{boreholeId}/usage-quotas`
*   **Purpose:** Track community water consumption against sustainable limits.
*   **Reason:** To enforce "Fairness", this endpoint compares how much water has been pumped this month against the sustainable quota of the aquifer, preventing a single farm or community from draining the resource dry.

---

## 4. Logistics & Accessibility Endpoints

Kunene is characterized by rugged, mountainous terrain and ephemeral riverbeds. Standard vehicles cannot reach most boreholes, and heavy drilling rigs require highly specific routing. 

### `GET /api/v1/boreholes/{boreholeId}/logistics`
*   **Purpose:** Retrieve the accessibility details and road conditions for a specific borehole.
*   **Reason:** Before a maintenance crew or a heavy drilling rig is dispatched, the dashboard uses this endpoint to display vehicle requirements (e.g., "High-clearance 4x4 Mandatory") and seasonal warnings.

### `POST /api/v1/routes/calculate`
*   **Purpose:** Calculate a safe logistical route to a borehole.
*   **Reason:** The API interacts with a third-party mapping/AI model to calculate a route that avoids fragile desert ecosystems, impassable mountains, and soft sand, returning a safe path to plot on the dashboard map.

---

## 5. IoT Telemetry & Advanced Monitoring Endpoints

### `POST /api/v1/boreholes/{boreholeId}/telemetry`
*   **Purpose:** Receive automated sensor data from the borehole.
*   **Reason:** Allows IoT devices attached to the pump to report critical health metrics directly to the server's light data store.

---

## 6. Fair Allocation & Community Endpoints

### `GET /api/v1/allocation-metrics`
*   **Purpose:** Retrieve demographic and water-scarcity metrics for specific zones.
*   **Reason:** Shows the ratio of population to working boreholes, ensuring allocation is data-driven and fair.

### `POST /api/v1/community-requests`
*   **Purpose:** Submit a formal request from a community for water assistance.
*   **Reason:** Allows local leaders to report extreme scarcity, ensuring their region is heavily prioritized when the AI calculates fair allocation.

---

## 7. Third-Party AI & Suggestion Endpoints

### `GET /api/v1/factors`
*   **Purpose:** Retrieve the environmental and geological factors the system evaluates for siting.
*   **Reason:** Shows users the criteria used for decision-making. 

### `POST /api/v1/suggestions/generate`
*   **Purpose:** Request an optimal, fair borehole location suggestion.
*   **Payload Example:** `{ "target_area": "Okangwati", "required_yield": "moderate", "priority_metric": "fair_allocation_distance" }`
*   **Reason:** The API bundles the relevant factors, historical trends, and community requests from its light data store, sending them to the AI model. The AI processes these complex variables and returns geographical coordinates.

### `GET /api/v1/suggestions/{suggestionId}`
*   **Purpose:** Retrieve the results of a previously requested AI suggestion.
*   **Reason:** Because interactions with third-party models take time, this endpoint allows the dashboard to fetch the final recommended site coordinates and the justification once ready.
