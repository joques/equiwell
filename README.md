# Equi Well: Borehole Management & Fair Allocation API

## Project Overview
**Equi Well** is a comprehensive software dashboard and API architecture designed to manage water infrastructure in the Kunene Region of Namibia. This project addresses the unique geographical, logistical, and socio-economic challenges of providing sustainable water access in an arid, mountainous environment.

The core objective of this project is to facilitate **fair borehole allocation** and proactive maintenance through data-driven insights.

## System Architecture
The system acts as a middleware connecting the user-facing Dashboard to backend resources. 
*   **Light Data Store:** The API directly manages a localized database for immediate queries (e.g., fetching map coordinates, logging IoT telemetry, fetching maintenance alerts).
*   **Third-Party AI Integration:** For complex, high-latency tasks—such as calculating optimal geographical coordinates for new boreholes or plotting off-road logistical routes—the API bundles environmental factors and community data, sending them to an external AI model for inference.

## API Documentation (OpenAPI/Swagger)
The complete RESTful API specification is defined in the `swagger.yaml` file in this repository. You can view it by copying the contents of `swagger.yaml` into [editor.swagger.io](https://editor.swagger.io/).

### Key Features Designed in the API:
1.  **Dynamic Map Visualization:** Endpoints return GeoJSON and Lat/Lng coordinates to plot all operational and broken boreholes on the dashboard map.
2.  **Energy & Pump Classification:** The API explicitly tracks the `pump_type` (Solar PV, Diesel, Windmill, Hand Pump) to help managers track fuel costs versus sustainable extraction.
3.  **IoT Telemetry & Lab Testing:** 
    *   Automated sensors can push real-time data (`POST /telemetry`) regarding dynamic water drawdown, recovery rates, and Electrical Conductivity (Salinity).
    *   Health inspectors can manually upload physical water quality reports (`POST /lab-tests`) for bacteria (E. coli) or heavy metals (Arsenic/Fluoride).
4.  **Logistics & AI Routing:** Recognizing the extreme terrain of the Kunene Region, the API tracks accessibility (e.g., "High-clearance 4x4 Mandatory") and interfaces with an AI model to calculate safe off-road routes avoiding flooded ephemeral rivers.
5.  **Usage Quotas & Fair Allocation:** The system tracks community water usage against sustainable aquifer limits and logs formal community requests to ensure AI-driven siting suggestions are truly equitable.

## Project Resources
*   `equiwell_api_spec.md`: A human-readable markdown specification of the API methodology.
*   `swagger.yaml`: The machine-readable OpenAPI 3.0 specification.
