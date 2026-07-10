> This document defines the formal API contract, transport protocols,
> request schemas, latency budgets, and error handler configurations for
> the EquiWell Central API Gateway (Orchestrator).

# Architectural Style s HTTP Method Selection

## API Type: REST (Representational State Transfer)

> The EquiWell Gateway is designed as a **RESTful API** (conforming to
> REST architectural constraints).

- **Statelessness:** The gateway does not retain client-conversational
  states in memory. Each HTTP request contains all necessary data
  (prompt, session, token) for the gateway to execute the transaction,
  enabling low-memory footprint and parallel scalability.

- **Uniform Interface:** Employs standard HTTP paths and serialization
  types (application/json) to ensure it can be consumed easily by any
  web or mobile client.

## HTTP Methods Justification

> Gateway will use specific HTTP methods to represent operations on its
> resources:

- **GET (**Used on **/health, /agents, /metrics):** Standard HTTP method
  for retrieving data. It is **safe** and **idempotent** - querying
  these endpoints will never alter the state of the backend agents or
  Gateway configurations.

- **POST (**Used on **/prompt):** Standard HTTP method for submitting
  payloads to trigger backend actions. Since prompt submission is
  **non-idempotent** (triggers token-consuming AI model operations and
  updates conversational memory contexts) and carries a request body
  payload, POST is the semantically correct choice.

- **OPTIONS (Used on all paths):** Handles preflight requests generated
  by browsers to validate CORS credentials before actual data
  transmission.

#### Excluded Methods:

- **PUT / PATCH (Update):** Clients do not have permission to modify
  gateway configurations or alter agent priorities directly, so update
  operations are blocked.

- **DELETE:** Clients cannot delete cluster definitions, metrics, or
  server logs, so delete operations are blocked.

- **MOVE:** A WebDAV extension verb that is blocked to minimize the
  gateway’s security attack surface.

# The 5-Section API Reference Contract

## Section 1: Resource Description

> The gateway exposes the /**prompt resource**, which serves as the
> entry point for routing client queries to the AI agent cluster.
>
> This resource supports both **text prompts** and **multimodal image
> prompts** (where clients send a picture for analysis). It also
> supports receiving both **text results** and **generated images** from
> the backend AI agents.

## Section 2: Endpoints and Methods

> *Endpoint: **POST /api/v1/prompt***
>
> Dispatches a client prompt or image to the agent cluster with fallback
> protection.

- **Host:** localhost:8080 (or target Gateway server IP)

- **Method:** POST

- **Authentication:** Secured (Requires **Authorization: Bearer
  \<key\>** in request header).

- **CORS Support:** Employs standard **OPTIONS** headers handling.

## Section 3: Parameters

#### Header Parameters

<table style="width:96%;">
<colgroup>
<col style="width: 15%" />
<col style="width: 7%" />
<col style="width: 11%" />
<col style="width: 43%" />
<col style="width: 18%" />
</colgroup>
<thead>
<tr>
<th><blockquote>
<p><strong>Parameter</strong></p>
</blockquote></th>
<th><strong>Type</strong></th>
<th><blockquote>
<p><strong>Required</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>Expected Format</strong></p>
</blockquote></th>
<th style="text-align: left;"><blockquote>
<p><strong>Description</strong></p>
</blockquote></th>
</tr>
</thead>
<tbody>
<tr>
<td><blockquote>
<p>Content-Type</p>
</blockquote></td>
<td>String</td>
<td><blockquote>
<p><strong>Yes</strong></p>
</blockquote></td>
<td><blockquote>
<p>application/Json or multipart/form-data</p>
</blockquote></td>
<td style="text-align: left;"><blockquote>
<p>Dictates the serialisation format of the</p>
<p>request body (See</p>
</blockquote></td>
</tr>
</tbody>
</table>

<table style="width:96%;">
<colgroup>
<col style="width: 15%" />
<col style="width: 7%" />
<col style="width: 11%" />
<col style="width: 43%" />
<col style="width: 18%" />
</colgroup>
<thead>
<tr>
<th><blockquote>
<p><strong>Parameter</strong></p>
</blockquote></th>
<th><strong>Type</strong></th>
<th><blockquote>
<p><strong>Required</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>Expected Format</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>Description</strong></p>
</blockquote></th>
</tr>
</thead>
<tbody>
<tr>
<td></td>
<td></td>
<td></td>
<td></td>
<td><blockquote>
<p>Section 4.6).</p>
</blockquote></td>
</tr>
<tr>
<td><blockquote>
<p>Authorization</p>
</blockquote></td>
<td style="text-align: center;">String</td>
<td style="text-align: center;"><blockquote>
<p><strong>Yes</strong></p>
</blockquote></td>
<td><blockquote>
<p>Bearer &lt;token&gt;</p>
</blockquote></td>
<td><blockquote>
<p>Token-based security credentials matching the pre-shared API key.</p>
</blockquote></td>
</tr>
</tbody>
</table>

> **Request Body Parameters (JSON Payload - application/json)**

<table style="width:96%;">
<colgroup>
<col style="width: 18%" />
<col style="width: 9%" />
<col style="width: 12%" />
<col style="width: 22%" />
<col style="width: 33%" />
</colgroup>
<thead>
<tr>
<th><blockquote>
<p><strong>Parameter</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>Type</strong></p>
</blockquote></th>
<th style="text-align: center;"><blockquote>
<p><strong>Required</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>Size Constraints</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>Description</strong></p>
</blockquote></th>
</tr>
</thead>
<tbody>
<tr>
<td><blockquote>
<p>prompt</p>
</blockquote></td>
<td><blockquote>
<p>String</p>
</blockquote></td>
<td><blockquote>
<p>No</p>
</blockquote></td>
<td><blockquote>
<p>0 ≤ 𝐿 ≤ 16,384 bytes</p>
</blockquote></td>
<td><blockquote>
<p>The text query to be processed by the target AI agent. Optional if an
image payload is provided.</p>
</blockquote></td>
</tr>
<tr>
<td><blockquote>
<p>session_id</p>
</blockquote></td>
<td><blockquote>
<p>String</p>
</blockquote></td>
<td style="text-align: center;"><blockquote>
<p>No</p>
</blockquote></td>
<td><blockquote>
<p>0 ≤ 𝐿 ≤ 128 bytes</p>
</blockquote></td>
<td><blockquote>
<p>Unique ID for conversation thread tracking.</p>
</blockquote></td>
</tr>
<tr>
<td><blockquote>
<p>target_agent_id</p>
</blockquote></td>
<td><blockquote>
<p>String</p>
</blockquote></td>
<td style="text-align: center;"><blockquote>
<p>No</p>
</blockquote></td>
<td><blockquote>
<p>0 ≤ 𝐿 ≤ 64 bytes</p>
</blockquote></td>
<td><blockquote>
<p>Direct request to target a specific agent (e.g. agent-2).</p>
</blockquote></td>
</tr>
<tr>
<td><blockquote>
<p>image</p>
</blockquote></td>
<td><blockquote>
<p>Object</p>
</blockquote></td>
<td style="text-align: center;"><blockquote>
<p>No</p>
</blockquote></td>
<td><blockquote>
<p><em>See constraints below</em></p>
</blockquote></td>
<td><blockquote>
<p>Optional multimodal input containing image data.</p>
</blockquote></td>
</tr>
<tr>
<td><blockquote>
<p>image.data</p>
</blockquote></td>
<td><blockquote>
<p>String</p>
</blockquote></td>
<td style="text-align: center;"><blockquote>
<p>Yes (if image present)</p>
</blockquote></td>
<td><blockquote>
<p>1 ≤ 𝐿 ≤ 5 MB (Base64)</p>
</blockquote></td>
<td><blockquote>
<p>Base64-encoded representation of the binary image data.</p>
</blockquote></td>
</tr>
<tr>
<td><blockquote>
<p>image.mime_type</p>
</blockquote></td>
<td><blockquote>
<p>String</p>
</blockquote></td>
<td style="text-align: center;"><blockquote>
<p>Yes (if image present)</p>
</blockquote></td>
<td><blockquote>
<p>image/png, image/jpeg</p>
</blockquote></td>
<td><blockquote>
<p>The media format type of the uploaded image.</p>
</blockquote></td>
</tr>
</tbody>
</table>

## Section 4: Request Examples

> ***Example 4.1: Text Prompt Request (application/json)***
>
> curl -X POST "<http://localhost:8080/api/v1/prompt>" \\
>
> -H "Content-Type: application/json" \\
>
> -H "Authorization: Bearer equiwell-secret-key-12345" \\
>
> -d '{
>
> "prompt": "Recommend a daily grooming routine for an active horse.",
> "session_id": "sess-uuid-998877"
>
> }'

#### Example 4.2: Multimodal Image Input Request (BaseC4 JSON)

> curl -X POST "<http://localhost:8080/api/v1/prompt>" \\
>
> -H "Content-Type: application/json" \\
>
> -H "Authorization: Bearer equiwell-secret-key-12345" \\
>
> -d '{
>
> "prompt": "Analyze this skin patch for signs of infection.", "image":
> {
>
> "mime_type": "image/jpeg",
>
> "data":
> "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP////////////////////////////////////////
>
> //////////////////////////////////////////////wgALCAAEAAQBAREA/8QAFBABAAAAAAAAAAAAAAAAAAA
> AAP/aAAgBAQABPxA="
>
> }
>
> }'
>
> ***Example 4.3: Binary Multipart Image Upload (multipart/form-data)***
>
> To bypass Base64 encoding overhead (see Section 4.6), clients can send
> raw binary data:
>
> curl -X POST "<http://localhost:8080/api/v1/prompt>" \\
>
> -H "Authorization: Bearer equiwell-secret-key-12345" \\
>
> -F "prompt=Analyze this skin patch for signs of infection." \\
>
> -F "image=@/path/to/image.jpg;type=image/jpeg" \\
>
> -F "session_id=sess-uuid-998877"

# Section 5: Response Example and Schema

### Success Response Example (AI generates a text result)

> {
>
> "success": **true**,
>
> "request_id": "req-1720000000000-0", "served_by": "agent-1",
>
> "data": {
>
> "result": "Grooming should start with curry combing...",
> "tokens_used": 185
>
> }
>
> }

### Success Response Example (AI generates an image result)

> {
>
> "success": **true**,
>
> "request_id": "req-1720000000001-0", "served_by": "agent-2",
>
> "data": { "tokens_used": 512, "generated_image": {
>
> "mime_type": "image/png",
>
> "data": "iVBORw0KGgoAAAANSUhEUgAAAAUA..."
>
> }
>
> }
>
> }

### Success Response Schema

- **Success** (boolean, required)**:** Always true for valid agent
  execution and false for failed agent execution.

- **request_id** (string, required)**:** A unique, gateway-generated
  transaction ID.

- **served_by** (string, required)**:** The ID of the agent node that
  successfully handled the prompt.

- **Data** (object, required)**:**

  - **result** (string, optional): The generated text answer from the
    AI.

  - **tokens_used** (integer, optional): Token count consumed by the
    backend model.

  - **generated_image** (object, optional): Object containing generated
    binary media.

  - **data** (string, required): Base64-encoded string representing the
    generated binary image.

  - **mime_type** (string, required): Media type (e.g. image/png).

# Advanced API Design s Gateway Policies

> This section details critical gateway policies addressing versioning,
> security, rate limiting, request tracking, file negotiations, and
> latency budgets.

## API Versioning s Lifecycle Strategy

> The gateway implements path-based versioning **(/api/v1/)**.

1.  **SemVer Mapping:** Minor enhancements and backward-compatible
    changes (e.g., adding an optional field to a response) preserve the
    /v1/ prefix. Major breaking alterations (e.g., deleting a parameter
    or rewriting the response payload) require spinning up a /api/v2/
    namespace.

2.  **Deprecation Policy:** When a version is marked for
    decommissioning, the gateway appends two standard headers to all
    requests: \* Deprecation: true \* Sunset: Tue, 01 Jun 2027 23:59:59
    GMT (indicates the exact termination date).

## Authentication s Token Management Policy

> To satisfy different environments, the gateway supports two
> authentication modes:

1.  **Static Pre-Shared Key (Server-to-Server):** Used for secure
    internal microservice integrations where the client passes the
    static token loaded from config.json.

2.  **Dynamic OAuth2 Integration (External Clients):** For public-facing
    apps, clients should authenticate against an external Identity
    Provider (IdP) to receive a JSON Web Token (JWT). The Gateway
    validates the JWT signatures offline using standard RS256 JWKS
    endpoints, verifying key expiration times (exp) and resource scopes
    (scp).

## CORS (Cross-Origin Resource Sharing) Header Specifics

> To facilitate safe browser integration (websites, dashboards), the
> gateway handles **OPTIONS** requests by returning **HTTP 204** No
> Content with these headers:
>
> **Access-Control-Allow-Origin: \***
>
> **Access-Control-Allow-Methods: GET, POST, OPTIONS**
>
> **Access-Control-Allow-Headers: Content-Type, Authorization,
> X-Request-Id Access-Control-Max-Age: 86400**

- Access-Control-Max-Age: 86400 ensures browsers cache the CORS
  permission for exactly **24 hours**, eliminating redundant options
  requests and reducing network overhead.

## Rate Limiting s Traffic Shaping Policy

> To prevent abuse and brute-force key attacks, the gateway enforces a
> **Token Bucket rate-limiting algorithm** tracked per API Key (or
> fallback Client IP):

### Standard Rate: 120 requests per minute.

- **Burst Capacity:** Up to **20 requests**.

- **Rate Limit Response Headers:** All secured responses append standard
  metrics:

  - X-RateLimit-Limit: 120 (maximum transactions allowed per window).

  - X-RateLimit-Remaining: 114 (requests left in current window).

  - X-RateLimit-Reset: 42 (seconds remaining until bucket refills).

- **Exceeded Limit:** If the remaining count hits 0, the gateway rejects
  requests immediately with **HTTP 42G Too Many Requests** and returns a
  Retry-After: 42 header.

## Request ID Generation s Traceability

> Every transaction crossing the gateway receives a unique trace ID.
>
> **Format:**
> req-\<timestamp_millis\>-\<monotonically_increasing_sequence\> (e.g.
> req-1720000000000-41).
>
> **Guarantees:** Cryptographically secure timestamp seeding guarantees
> global uniqueness.
>
> **Client Header Override:** If the client passes a header named
> X-Request-Id (e.g. UUIDv4), the gateway adopts it to maintain
> end-to-end tracing across the system stack, returning the matching ID
> in the JSON body.

4.  **Content-Type Negotiation (application/json vs
    multipart/form-data)**

> Encoding images to Base64 adds a **33% bandwidth and CPU processing
> overhead**. To optimize performance:

1.  **application/json:** Preferred for text-only queries and small
    images (\< 100 KB).

2.  **multipart/form-data:** Highly recommended for large image uploads
    (1 MB to 5 MB). The gateway parses the multipart boundary, streams
    the raw binary image straight to the target agent, and avoids
    allocating memory for a large Base64 text string.

## Latency Budget Breakdown Analysis

> To maintain an average processing latency under **100ms** (for active
> nodes), the total Gateway timing budget is categorized as follows:
>
> \[ Client Request \] ────\> ( Network Transit: 5 - 40ms )

│

▼

> \[ EquiWell Gateway \]
>
> ├─ Auth & CORS Check: \<0.5ms
>
> ├─ Body Parser & JSON Validate: \<2.0ms
>
> └─ Agent Selection: \<0.1ms

│

▼

> ( Gateway-to-Agent Socket Handshake: \<10ms ) (Timeout: 500ms)

│

▼

> \[ Upstream AI Agent Node \]
>
> └─ Model Execution & Output Write: 300 - 1500ms (Timeout: 2000ms)

│

▼

> \[ EquiWell Gateway \]
>
> └─ Client Response Write: \<2.0ms

│

▼

> \[ Client Response \] \<─── ( Network Transit: 5 - 40ms )

# Detailed Developer Error Reference Guide

> If a request fails, the Gateway intercepts the error and returns a
> structured JSON payload containing an optional **error_details** array
> for debugging:
>
> {
>
> "success": **false**,
>
> "request_id": "req-1720000000000-0", "error_code": "INVALID_PAYLOAD",
>
> "error_message": "Validation failed for request parameters.",
> "error_details": \[
>
> {
>
> "field": "prompt",
>
> "issue": "Field is required when no image object is provided."
>
> }
>
> \]
>
> }

## Error Descriptions

- **401 Unauthorized (UNAUTHORIZED):**

  - *Trigger:* Invalid Bearer Token.

  - *Mitigation:* Verify header syntax matches Authorization: Bearer
    \<key\>.

- **400 Bad Request (INVALID_PAYLOAD):**

  - *Trigger:* Broken JSON schema, missing prompt, or exceeded size
    limits.

  - *Mitigation:* Check validation logs in the error_details array.

- **503 Service Unavailable (NO_AGENTS_AVAILABLE):**

  - *Trigger:* Downstream nodes degraded; circuit breaker tripped.

  - *Mitigation:* Wait 30 seconds for the cooldown to reset.

- **503 Service Unavailable (ALL_AGENTS_FAILED):**

  - *Trigger:* Socket connection errors on all paths.

  - *Mitigation:* Check target agent host bounds.

- **502 Bad Gateway (AGENT_BAD_GATEWAY):**

  - *Trigger:* Downstream agent crashes or returns non-JSON.

  - *Mitigation:* Debug the target agent server output.

# Auxiliary Resources Reference

## GET /api/v1/health (Liveness s Dependency Probe)

- **Description:** Public endpoint reporting Gateway liveness and
  backend agent connection health.

**Response (JSON):**

> {
>
> "status": "up",
>
> "service": "equiwell-api-orchestrator", "version": "0.1.0",
>
> "dependencies": {
>
> "agent-1": "reachable", "agent-2": "unreachable", "agent-3":
> "reachable"
>
> }
>
> }

## 6. Advanced Gateway Features

> Advanced architectural patterns to ensure high performance and
> scalability for AI interactions**:**

## 6.1 Server-Sent Events (SSE) Streaming

> For complex AI operations that take a long time to generate, the
> Gateway supports Server-Sent Events (SSE) and WebSockets. This allows
> the AI to stream its text response back to the client token-by-token,
> drastically reducing perceived latency and providing a fluid User
> Experience (UX) .
>
> A user asks the AI to write a story. Instead of staring at a loading
> spinner for 10 seconds, they see the words appearing instantly:
> **"Once"** $`\mathbf{\rightarrow}`$ **"upon"**
> $`\mathbf{\rightarrow}`$ **"a"** $`\mathbf{\rightarrow}`$
> **"time..."**

## 6.2 Asynchronous Webhook Processing for Images

> The gateway handles standard image payloads up to 5MB synchronously.
> But complex and high-resolution image generation can take several
> minutes. To prevent connection timeouts, the **client** includes a
> **callback_url** in their request. The **API** immediately **accepts
> the request, returns a job_id,** and later pushes the finished image
> directly to that URL once processing is complete.
>
> A client requests a highly complex medical image analysis and provides
> a **callback URL (myapp.com/receive).** The API responds instantly
> with an **"Accepted" status**. Five minutes later, the API
> automatically sends the finished image data to **myapp.com/receive.**

## 6.3 Formal API Versioning and Deprecation

> The Gateway uses specific paths for versioning ( /api/v1/). When a
> major update requires a new version (/api/v2/), the old version begins
> returning an HTTP Sunset header. This acts as a formal timer, giving
> clients exactly 6 months to update their integrations before the old
> version is permanently disabled.
>
> If a developer's app continues to hit **/api/v1/** after **/api/v2/**
> is released, their server responses will include a header like
> ***Sunset: Tue, 01 Jun 2027***. This tells them exactly when their
> current code will stop working if they don't upgrade.

## 6.4 Cursor-Based Pagination

> When fetching massive, unbounded datasets (like a user's entire prompt
> history), asking a database to skip to "Page 10,000" causes
> performance issues. Instead, the Gateway uses cursors. By asking for
> the items immediately following a specific record's ID, the database
> doesn't have to count from the beginning, ensuring fast retrieval
> speeds regardless of how much data exists.
>
> Instead of requesting **?page=50**, the client requests
> **?limit=50&after=cursor_uuid**. The database instantly locates the
> row with **cursor_uuid** and grabs the next **50 rows**.

## 6.5 Binary Content Negotiation

> To optimize bandwidth for mobile clients on slower 3G/4G networks, the
> Gateway supports binary data serialization. Clients can use the
> Accept: application/msgpack header, which reduces payload size by
> approximately 33% compared to standard Base64-encoded JSON.
>
> A mobile app includes the header **Accept: application/msgpack** in
> its request. The Gateway acknowledges this and responds with compacted
> binary data instead of bulky text, saving the user's mobile data and
> speeding up the transfer.
