# EquiWell Versioning & Release Governance Policy

## 1. Semantic Versioning Specification

The EquiWell Enterprise Backend (`Equiwell_02`) adheres strictly to **Semantic Versioning 2.0.0** (`MAJOR.MINOR.PATCH`).

```
  v MAJOR . MINOR . PATCH
     │        │       │
     │        │       └── Incremented for backward-compatible bug fixes, security patches, maintenance.
     │        └────────── Incremented for backward-compatible feature additions or data model expansions.
     └─────────────────── Incremented for incompatible / breaking API changes or architectural overhauls.
```

- **Current Baseline Release:** `v1.0.0`
- **Compiler Target:** Zig `0.17.0-dev.813+2153f8143`
- **Target Architecture:** Windows `x86_64-windows-gnu` / MSVC ABI

---

## 2. Version Increment Rules

### 2.1 MAJOR Version (`X.0.0`)
A MAJOR increment is required when:
- Any existing endpoint path, HTTP method, or canonical route is removed or altered incompatibly.
- Request/response JSON schema fields are removed, renamed, or modified in type.
- The RBAC role model or security authorization rules are fundamentally changed.
- The underlying transport or concurrency model is overhauled (e.g. migrating from synchronous Winsock socket worker pool to async I/O / IOCP).
- Breaking storage layer migrations occur that cannot automatically backward-reconcile previous data schemas.

### 2.2 MINOR Version (`1.X.0`)
A MINOR increment is required when:
- New API endpoints are introduced under `/api/v1/` without modifying existing routes.
- New optional query parameters or optional request body fields are added.
- New response payload fields are added (provided clients ignore unknown fields).
- New analytics, machine learning, or geospatial helper algorithms are added.
- Internal performance optimizations that preserve 100% backward contract compatibility.

### 2.3 PATCH Version (`1.0.X`)
A PATCH increment is required when:
- Security vulnerabilities or bug fixes are applied with zero API contract changes.
- Input validation boundaries or sanitizers are tightened without breaking valid RFC-compliant requests.
- Memory leak fixes, arena optimization, or lock contention tuning is applied.
- Documentation, operational runbooks, or test suite coverage is expanded.

---

## 3. Git Branching & Tagging Strategy

```
  main (FROZEN PRODUCTION) ──────────────●──────────────────────────● (v1.0.1 Tag)
                                         ▲                          │
                                         │ Merge PR (Post Gate)     │
                                 ┌───────┴────────┐                 │
  release/v1.0.x (Hotfix)        │ cr/sec-fix-01  │                 │
                                 └────────────────┘                 ▼
                                                            Release Artifact Bundle
```

### 3.1 Branching Rules
- **`main`**: The protected production branch. Direct commits are strictly disabled. Only merges with approved CRs and 100% passing release gates are permitted.
- **`release/vX.Y.Z`**: Stabilization branch for building and validating release candidates.
- **`cr/<category>-<cr-id>`**: Feature or patch branch created for a specific Change Request.

### 3.2 Release Tagging
Every production release must be tagged with an annotated, signed Git tag:
```powershell
git tag -a v1.0.0 -m "EquiWell Enterprise Backend v1.0.0 Production Release"
```

---

## 4. Release Cadence & Support Lifecycle

| Release Type | Frequency | Review Requirement | Rollback Window |
| :--- | :--- | :--- | :--- |
| **Regular Maintenance (PATCH)** | Bi-weekly / Monthly | Standard CR + 152/152 Gate | 14 Days |
| **Feature Release (MINOR)** | Quarterly | Full Architecture Review + 152/152 Gate | 30 Days |
| **Major Evolution (MAJOR)** | Annual / Milestone | Change Advisory Board + Full Security Audit | 90 Days |
| **Emergency Hotfix (PATCH)** | As Needed (Immediate) | Expedited CR + Dual Sign-off + 152/152 Gate | 24 Hours |

---

## 5. Deprecation Policy

Before any endpoint, query parameter, or feature is removed or altered in a MAJOR release:
1. **Deprecation Notice:** Must be marked with `@deprecated` in OpenAPI and docstrings for at least one full MINOR release cycle.
2. **Response Header:** Deprecated endpoints must include the `Deprecation: @<timestamp>` HTTP header.
3. **Migration Guide:** A dedicated migration guide must be published in `docs/` detailing client transition steps.
