<div align="center">
  <h1>💧 Equi Well</h1>
  <p><b>Borehole Management & Fair Allocation API</b></p>
  <p><i>Target Region: Kunene Region, Namibia</i></p>
  <br />
</div>

## 🌍 Project Overview
**Equi Well** is a comprehensive software dashboard and API architecture designed to manage water infrastructure in the Kunene Region of Namibia. This project addresses the unique geographical, logistical, and socio-economic challenges of providing sustainable water access in an arid, mountainous environment.

The core objective of this project is to facilitate **fair borehole allocation** and proactive maintenance through data-driven insights.

---

## 🏗️ System Architecture
The system acts as a middleware connecting the user-facing Dashboard to backend resources. 
*   ⚡ **Light Data Store:** The API directly manages a localized database for immediate queries (e.g., fetching map coordinates, logging IoT telemetry, fetching maintenance alerts).
*   🧠 **Third-Party AI Integration:** For complex, high-latency tasks—such as calculating optimal geographical coordinates for new boreholes or plotting off-road logistical routes—the API bundles environmental factors and community data, sending them to an external AI model for inference.

---

## 📚 API Documentation (OpenAPI/Swagger)
The complete RESTful API specification is defined in the `swagger.yaml` file in this repository. You can view it by copying the contents of `swagger.yaml` into [editor.swagger.io](https://editor.swagger.io/).

> [!NOTE]
> Read our human-readable methodology in the **[`equiwell_api_spec.md`](./equiwell_api_spec.md)** file!

### 🔑 Key Features Designed in the API:
1.  📍 **Dynamic Map Visualization:** Endpoints return GeoJSON and Lat/Lng coordinates to plot all operational and broken boreholes on the dashboard map.
2.  ☀️ **Energy & Pump Classification:** The API explicitly tracks the `pump_type` (Solar PV, Diesel, Windmill, Hand Pump) to help managers track fuel costs versus sustainable extraction.
3.  📡 **IoT Telemetry & Lab Testing:** 
    *   Automated sensors push real-time data (`POST /telemetry`) regarding dynamic water drawdown, recovery rates, and Salinity.
    *   Health inspectors manually upload physical water quality reports (`POST /lab-tests`) for bacteria (E. coli) or heavy metals (Arsenic/Fluoride).
4.  🚜 **Logistics & AI Routing:** Recognizing the extreme terrain of the Kunene Region, the API tracks accessibility (e.g., "High-clearance 4x4 Mandatory") and interfaces with an AI model to calculate safe off-road routes avoiding flooded ephemeral rivers.
5.  ⚖️ **Usage Quotas & Fair Allocation:** The system tracks community water usage against sustainable aquifer limits and logs formal community requests to ensure AI-driven siting suggestions are truly equitable.

---

## 🛡️ Global Error Handling & Validation
The API implements a robust, unified error handling architecture via reusable OpenAPI components:
*   🔴 **`400 Bad Request`**: Strict validation for payload structure and `enum` values (e.g. invalid pump types).
*   🔒 **`401 Unauthorized` / `403 Forbidden`**: Role-based access control protecting Admin and Health Inspector routes.
*   🔍 **`404 Not Found`**: Standardized responses for missing borehole or user IDs.
*   ⚠️ **`500 Internal Server Error`**: Fail-safes for third-party AI model timeouts.

*(All endpoints are paired with realistic JSON examples for fast frontend integration!)*

---

## 📂 Project Resources
*   📄 **[`swagger.yaml`](./swagger.yaml)**: The machine-readable OpenAPI 3.0 specification.
*   📖 **[`equiwell_api_spec.md`](./equiwell_api_spec.md)**: A human-readable markdown specification of the API methodology.
