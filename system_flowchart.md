# Equi Well System Flow Diagram

You can use the following flowchart in your presentation to perfectly explain how the system works. It outlines exactly how the Dashboard, the Light Data Store, and the AI Model interact using the API methods we designed.

```mermaid
graph TD
    %% Define Styles
    classDef dashboard fill:#2d3436,stroke:#74b9ff,stroke-width:2px,color:#fff;
    classDef api fill:#0984e3,stroke:#fff,stroke-width:2px,color:#fff;
    classDef ai fill:#6c5ce7,stroke:#fff,stroke-width:2px,color:#fff;
    classDef iot fill:#00b894,stroke:#fff,stroke-width:2px,color:#fff;
    
    %% Nodes
    Dashboard[💻 User Dashboard Map]:::dashboard
    LightDB[(🗄️ API Light Data Store)]:::api
    AIModel[🧠 Third-Party AI Model]:::ai
    IoTSensors[📡 Borehole IoT Sensors]:::iot

    %% Standard Flow (Dashboard to API)
    Dashboard -- "GET /dashboard/summary" --> LightDB
    Dashboard -- "GET /boreholes (Map Data)" --> LightDB
    Dashboard -- "GET /maintenance-alerts" --> LightDB
    Dashboard -- "PATCH /boreholes/{id} (Hide/Update)" --> LightDB
    Dashboard -- "GET /boreholes/{id}/usage-quotas" --> LightDB
    
    %% IoT Flow
    IoTSensors -- "POST /telemetry (Water Level, EC, Runs)" --> LightDB

    %% Complex Flow (Dashboard -> API -> AI)
    Dashboard -- "1. POST /suggestions/generate" --> LightDB
    LightDB -- "2. Bundle Historical Data & Factors" --> AIModel
    AIModel -- "3. Process Spatial Routing & Fairness" --> AIModel
    AIModel -- "4. Return Siting Coordinates" --> LightDB
    LightDB -- "5. GET /suggestions/{id}" --> Dashboard
    
    Dashboard -- "POST /routes/calculate" --> LightDB
    LightDB -- "Fetch Terrain Factors" --> AIModel
    AIModel -- "Return 4x4 Safe Route" --> LightDB
```
