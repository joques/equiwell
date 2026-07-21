# Equi Well System Flow Diagram

This diagram illustrates the core API architecture. It maps the data flow between the User Dashboard, the API's Light Data Store, automated IoT sensors, and the external AI routing/allocation models.

```mermaid
graph LR
    %% Define Styles for High Visibility
    classDef dashboard fill:#2d3436,stroke:#74b9ff,stroke-width:3px,color:#fff,font-weight:bold;
    classDef api fill:#0984e3,stroke:#fff,stroke-width:3px,color:#fff,font-weight:bold;
    classDef ai fill:#6c5ce7,stroke:#fff,stroke-width:3px,color:#fff,font-weight:bold;
    classDef iot fill:#00b894,stroke:#fff,stroke-width:3px,color:#fff,font-weight:bold;
    
    %% Nodes
    Dashboard[💻 User Dashboard]:::dashboard
    LightDB[(🗄️ API Database)]:::api
    AIModel[🧠 Third-Party AI]:::ai
    IoTSensors[📡 IoT Sensors]:::iot

    %% Standard Flow (Dashboard to API)
    Dashboard -->|"1. GET /dashboard/summary"| LightDB
    Dashboard -->|"2. GET /boreholes"| LightDB
    Dashboard -->|"3. PATCH /boreholes/id"| LightDB
    
    %% IoT Flow (Sensors to API)
    IoTSensors == "POST /telemetry" ==> LightDB

    %% Complex Flow (Dashboard -> API -> AI)
    Dashboard -. "POST /suggestions/generate" .-> LightDB
    LightDB -. "Bundle Factors & History" .-> AIModel
    AIModel -. "Calculate Coordinates" .-> LightDB
    LightDB -. "GET /suggestions/id" .-> Dashboard
    
    %% Routing Flow
    Dashboard == "POST /routes/calculate" ==> LightDB
    LightDB == "Request Terrain Route" ==> AIModel
    AIModel == "Return 4x4 Safe Route" ==> LightDB
```
