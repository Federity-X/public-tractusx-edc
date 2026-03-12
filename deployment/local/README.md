# Local DCP Deployment — Tractus-X EDC Connectors

Production-like local Docker deployment of **Tractus-X EDC connectors** with full
**Decentralized Claims Protocol (DCP)** authentication, per-company Identity Hubs,
Verifiable Credentials, and sovereign data exchange.

## What This Deploys

- **Provider + Consumer** EDC connector pair (Control Plane + Data Plane each)
- **Per-company Identity Hubs** (wallet/DID/VC management)
- **Issuer Service** (issues Membership, BPN, and DataExchangeGovernance credentials)
- **BDRS Server** (BPN ↔ DID resolution directory)
- **PostgreSQL** databases (one per company + issuer)
- **HashiCorp Vault** instances (one per company + issuer)
- **14 Docker containers** total on a shared `edc-net` bridge network

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Container Topology](#container-topology)
- [DCP Authentication Flow](#dcp-authentication-flow)
- [Data Transfer Patterns](#data-transfer-patterns)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Port Mappings](#port-mappings)
- [DID & Identity Configuration](#did--identity-configuration)
- [API Keys](#api-keys)
- [Available Scripts](#available-scripts)
- [Postman Collection](#postman-collection)
- [Troubleshooting](#troubleshooting)
- [Known Issues & Fixes](#known-issues--fixes)
- [Related Repositories](#related-repositories)

---

## Architecture Overview

The deployment follows a **per-company architecture** modeled after the
[Minimum Viable Dataspace (MXD)](https://github.com/eclipse-edc/MinimumViableDataspace)
reference. Each company (provider, consumer) has its own complete stack — IdentityHub,
Vault, and PostgreSQL — just like in production.

```mermaid
graph TB
    subgraph "Issuer Stack (from IdentityHub repo)"
        issuer-vault["issuer-vault<br/>HashiCorp Vault<br/>:8200"]
        issuer-postgres["issuer-postgres<br/>PostgreSQL 16<br/>:5432"]
        issuerservice["issuerservice<br/>IdentityHub (Issuer)<br/>:18181 Identity API<br/>:18292 STS<br/>:19999 Issuance"]
        issuerservice --> issuer-vault
        issuerservice --> issuer-postgres
    end

    subgraph "Provider Company Stack"
        provider-vault["provider-vault<br/>HashiCorp Vault<br/>:8201"]
        provider-postgres["provider-postgres<br/>PostgreSQL 16<br/>:6432"]
        provider-ih["provider-ih<br/>IdentityHub<br/>:7181 Identity API<br/>:7292 STS"]
        provider-cp["provider-cp<br/>EDC Control Plane<br/>:19193 Management API<br/>:19194 DSP Protocol"]
        provider-dp["provider-dp<br/>EDC Data Plane<br/>:19197 Public API"]
        provider-cp --> provider-vault
        provider-cp --> provider-postgres
        provider-dp --> provider-vault
        provider-dp --> provider-postgres
        provider-ih --> provider-vault
        provider-ih --> provider-postgres
        provider-cp --> provider-ih
        provider-dp --> provider-cp
    end

    subgraph "Consumer Company Stack"
        consumer-vault["consumer-vault<br/>HashiCorp Vault<br/>:8202"]
        consumer-postgres["consumer-postgres<br/>PostgreSQL 16<br/>:6433"]
        consumer-ih["consumer-ih<br/>IdentityHub<br/>:8182 Identity API<br/>:8293 STS"]
        consumer-cp["consumer-cp<br/>EDC Control Plane<br/>:29193 Management API<br/>:29194 DSP Protocol"]
        consumer-dp["consumer-dp<br/>EDC Data Plane<br/>:29197 Public API"]
        consumer-cp --> consumer-vault
        consumer-cp --> consumer-postgres
        consumer-dp --> consumer-vault
        consumer-dp --> consumer-postgres
        consumer-ih --> consumer-vault
        consumer-ih --> consumer-postgres
        consumer-cp --> consumer-ih
        consumer-dp --> consumer-cp
    end

    subgraph "Central Services"
        bdrs["bdrs-server<br/>BDRS Directory<br/>:8580 Resolver<br/>:8581 Management"]
    end

    consumer-cp -- "DSP Protocol<br/>(catalog, negotiation, transfer)" --> provider-cp
    provider-cp -- "DID resolution" --> consumer-ih
    consumer-cp -- "DID resolution" --> provider-ih
    consumer-cp -- "BPN↔DID lookup" --> bdrs
    provider-cp -- "BPN↔DID lookup" --> bdrs
    issuerservice -- "Issues VCs to" --> provider-ih
    issuerservice -- "Issues VCs to" --> consumer-ih
```

### Component Roles

| Component | Role |
|-----------|------|
| **Control Plane (CP)** | Orchestrates catalog browsing, contract negotiation, transfer initiation. Hosts the Management API for external clients and the DSP endpoint for connector-to-connector protocol. |
| **Data Plane (DP)** | Handles actual data transfer — serves data for PULL requests (via EDR tokens) and pushes data to webhooks for PUSH transfers. |
| **IdentityHub (IH)** | Per-company wallet. Manages DIDs, stores Verifiable Credentials, provides STS (Security Token Service) for DCP authentication. |
| **Issuer Service** | Trusted credential issuer. Issues MembershipCredential, BpnCredential, and DataExchangeGovernanceCredential to participants. |
| **BDRS Server** | Central directory mapping BPNs (Business Partner Numbers) to DIDs. Used during DCP authentication to resolve participant identities. |
| **Vault** | HashiCorp Vault for secret management — stores STS client secrets, transfer proxy signing keys (EC P-256 JWK), and API credentials. |
| **PostgreSQL** | Persistent storage for connector state (assets, policies, agreements, transfers), IdentityHub state (credentials, DIDs), and BDRS mappings. |

---

## Container Topology

All 14 containers run on a single Docker bridge network (`edc-net`):

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    edc-net (bridge)                                     │
│                                                                                         │
│   ┌─ Issuer Stack ──────────────┐  ┌─ Provider Company ──────────────────────────────┐  │
│   │ issuer-vault    (:8200)     │  │ provider-vault    (:8201)                       │  │
│   │ issuer-postgres (:5432)     │  │ provider-postgres (:6432)                       │  │
│   │ issuerservice   (:18181)    │  │ provider-ih       (:7181 identity, :7292 STS)   │  │
│   └─────────────────────────────┘  │ provider-cp       (:19193 mgmt, :19194 DSP)     │  │
│                                    │ provider-dp       (:19197 public data)           │  │
│   ┌─ Central ───────────────────┐  └─────────────────────────────────────────────────┘  │
│   │ bdrs-server (:8580/:8581)   │                                                       │
│   └─────────────────────────────┘  ┌─ Consumer Company ──────────────────────────────┐  │
│                                    │ consumer-vault    (:8202)                        │  │
│                                    │ consumer-postgres (:6433)                        │  │
│                                    │ consumer-ih       (:8182 identity, :8293 STS)    │  │
│                                    │ consumer-cp       (:29193 mgmt, :29194 DSP)      │  │
│                                    │ consumer-dp       (:29197 public data)            │  │
│                                    └─────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## DCP Authentication Flow

When the consumer requests the provider's catalog, a full DCP authentication flow occurs:

```mermaid
sequenceDiagram
    participant Client as Client (curl/Postman)
    participant ConsumerCP as Consumer CP
    participant BDRS as BDRS Server
    participant ConsumerIH as Consumer IH (Wallet)
    participant ProviderCP as Provider CP
    participant ProviderIH as Provider IH (Wallet)

    Client->>ConsumerCP: POST /v3/catalog/request
    Note over ConsumerCP: Resolve provider identity
    ConsumerCP->>BDRS: Lookup BPN → DID
    BDRS-->>ConsumerCP: did:web:provider-ih:provider

    Note over ConsumerCP: Get Self-Issued Token (SI Token)
    ConsumerCP->>ConsumerIH: POST /api/sts/token<br/>(client_credentials + audience)
    ConsumerIH-->>ConsumerCP: SI Token (JWT signed by consumer key)

    Note over ConsumerCP: Send DSP Catalog Request with SI Token
    ConsumerCP->>ProviderCP: POST /api/v1/dsp/catalog/request<br/>Authorization: Bearer <SI-Token>

    Note over ProviderCP: Verify consumer identity
    ProviderCP->>ConsumerIH: GET /.well-known/did.json<br/>(resolve consumer DID)
    ConsumerIH-->>ProviderCP: DID Document (with verification keys)

    Note over ProviderCP: Request Verifiable Presentation
    ProviderCP->>ConsumerIH: POST /api/v1/presentations/query<br/>(request MembershipCredential, BpnCredential, etc.)
    ConsumerIH-->>ProviderCP: VP containing requested VCs

    Note over ProviderCP: Validate VP + evaluate access policy
    ProviderCP-->>ConsumerCP: DCAT Catalog (filtered by access policy)
    ConsumerCP-->>Client: Catalog response with datasets & offers
```

### Key Identity Concepts

| Concept | Example | Purpose |
|---------|---------|---------|
| **DID** | `did:web:provider-ih:provider` | Decentralized Identifier — resolves to a DID Document via HTTP |
| **BPN** | `BPNL000000000001` | Business Partner Number — business-level identity in Catena-X |
| **SI Token** | JWT signed by connector's key | Short-lived token proving the caller's identity to the counterparty |
| **VP** | Verifiable Presentation | Container for VCs, presented to prove claims |
| **VC** | MembershipCredential, BpnCredential | Verifiable Credential — signed assertion by a trusted issuer |

---

## Data Transfer Patterns

This deployment supports both data transfer modes:

### HttpData-PULL (Consumer fetches data)

```mermaid
sequenceDiagram
    participant Client as Client
    participant ConsumerCP as Consumer CP
    participant ProviderCP as Provider CP
    participant ProviderDP as Provider DP
    participant DataSource as Data Source

    Client->>ConsumerCP: POST /v3/transferprocesses<br/>(transferType: HttpData-PULL)
    ConsumerCP->>ProviderCP: DSP TransferRequest
    ProviderCP->>ProviderDP: Provision EDR
    ProviderDP-->>ConsumerCP: EDR (endpoint + token)
    Note over ConsumerCP: Transfer state → STARTED

    Client->>ConsumerCP: GET /v3/edrs/{id}/dataaddress
    ConsumerCP-->>Client: {endpoint, authorization token}

    Client->>ProviderDP: GET {endpoint}<br/>Authorization: Bearer {token}
    ProviderDP->>DataSource: Fetch data
    DataSource-->>ProviderDP: Data
    ProviderDP-->>Client: Data response
```

### HttpData-PUSH (Provider pushes data to webhook)

```mermaid
sequenceDiagram
    participant Client as Client
    participant ConsumerCP as Consumer CP
    participant ProviderCP as Provider CP
    participant ProviderDP as Provider DP
    participant DataSource as Data Source
    participant Webhook as Webhook Endpoint

    Client->>ConsumerCP: POST /v3/transferprocesses<br/>(transferType: HttpData-PUSH,<br/>dataDestination: webhook URL)
    ConsumerCP->>ProviderCP: DSP TransferRequest
    ProviderCP->>ProviderDP: Push data to destination
    ProviderDP->>DataSource: Fetch data
    DataSource-->>ProviderDP: Data
    ProviderDP->>Webhook: POST data to webhook
    Note over ConsumerCP: Transfer state → STARTED
```

---

## Prerequisites

### 1. Identity Hub + Issuer Stack (from separate repo)

The issuer stack (issuerservice, issuer-vault, issuer-postgres) must be running on the
`edc-net` Docker network **before** starting the EDC stack.

**IdentityHub Repository:**
[Federity-X/public-tractusx-identityhub (branch: dcp-flow-local-deployment-with-upstream-0.15.1)](https://github.com/Federity-X/public-tractusx-identityhub/tree/dcp-flow-local-deployment-with-upstream-0.15.1)

```bash
# Clone the IdentityHub repo
git clone -b dcp-flow-local-deployment-with-upstream-0.15.1 \
  https://github.com/Federity-X/public-tractusx-identityhub.git
cd public-tractusx-identityhub

# Build the IdentityHub Docker image
docker build -t identityhub:local runtimes/identityhub/

# Start the issuer stack
cd deployment/local
docker compose up -d
```

See the [IdentityHub deployment README](https://github.com/Federity-X/public-tractusx-identityhub/tree/dcp-flow-local-deployment-with-upstream-0.15.1/deployment/local) for full setup instructions.

### 2. Docker & Docker Compose

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Docker Compose v2+

### 3. Java 21

Required for building the EDC shadow JARs:
```bash
java -version  # Should show 21+
```

### 4. Tools

- `curl` — API calls
- `jq` — JSON parsing
- `openssl` — key generation (used by bootstrap script)

---

## Quick Start

```bash
# 1. Ensure the issuer stack is running (from the IdentityHub repo)
docker ps | grep issuerservice  # Should show issuerservice container

# 2. Build EDC shadow JARs (from tractusx-edc repo root)
cd /path/to/tractusx-edc
./gradlew :edc-controlplane:edc-controlplane-postgresql-hashicorp-vault:shadowJar \
          :edc-dataplane:edc-dataplane-hashicorp-vault:shadowJar

# 3. Build EDC Docker images
docker build -t edc-controlplane:local \
  --build-arg JAR=edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build/libs/edc-controlplane-postgresql-hashicorp-vault.jar \
  -f deployment/local/Dockerfile .

docker build -t edc-dataplane:local \
  --build-arg JAR=edc-dataplane/edc-dataplane-hashicorp-vault/build/libs/edc-dataplane-hashicorp-vault.jar \
  -f deployment/local/Dockerfile .

# 4. Start infrastructure + connectors
cd deployment/local
docker compose up -d

# 5. Run bootstrap (participant creation, vault seeding, credential issuance,
#    BDRS seeding, asset + policy creation, E2E verification)
bash scripts/bootstrap.sh

# 6. Run end-to-end test (catalog → negotiate → transfer → pull data)
bash scripts/test-transfer.sh
```

---

## Port Mappings

### Issuer Stack (from IdentityHub repo)

| Container | Host Port | Purpose |
|-----------|-----------|---------|
| issuer-vault | 8200 | HashiCorp Vault (issuer secrets) |
| issuer-postgres | 5432 | PostgreSQL (issuer + BDRS databases) |
| issuerservice | 18181 | Identity API |
| issuerservice | 18292 | STS (Security Token Service) |
| issuerservice | 13132 | Resolution API |
| issuerservice | 15152 | Issuance Endpoint |
| issuerservice | 19999 | Credential Issuance API |

### Provider Stack

| Container | Host Port | Purpose |
|-----------|-----------|---------|
| provider-vault | 8201 | HashiCorp Vault |
| provider-postgres | 6432 | PostgreSQL (connector + IH databases) |
| provider-ih | 7181 | Identity API (DID, credentials) |
| provider-ih | 7292 | STS (Security Token Service) |
| provider-ih | 7131 | Resolution API |
| provider-ih | 7151 | IH Presentation API |
| provider-ih | 7100 | DID Document (`.well-known`) |
| provider-cp | 19191 | Default API (health check) |
| provider-cp | 19192 | Control API |
| provider-cp | 19193 | **Management API** (primary interaction endpoint) |
| provider-cp | 19194 | DSP Protocol (connector-to-connector) |
| provider-cp | 19195 | Catalog API |
| provider-dp | 19196 | Default API (health check) |
| provider-dp | 19197 | **Public API** (data transfer endpoint) |
| provider-dp | 19198 | Control API |

### Consumer Stack

| Container | Host Port | Purpose |
|-----------|-----------|---------|
| consumer-vault | 8202 | HashiCorp Vault |
| consumer-postgres | 6433 | PostgreSQL (connector + IH databases) |
| consumer-ih | 8182 | Identity API |
| consumer-ih | 8293 | STS |
| consumer-ih | 8132 | Resolution API |
| consumer-ih | 8152 | Presentation API |
| consumer-ih | 8100 | DID Document |
| consumer-cp | 29191 | Default API (health check) |
| consumer-cp | 29192 | Control API |
| consumer-cp | 29193 | **Management API** |
| consumer-cp | 29194 | DSP Protocol |
| consumer-cp | 29195 | Catalog API |
| consumer-dp | 29196 | Default API (health check) |
| consumer-dp | 29197 | **Public API** |
| consumer-dp | 29198 | Control API |

### Central Services

| Container | Host Port | Purpose |
|-----------|-----------|---------|
| bdrs-server | 8580 | BPN ↔ DID resolution (directory lookup) |
| bdrs-server | 8581 | BDRS Management API |

---

## DID & Identity Configuration

| Entity | DID | BPN |
|--------|-----|-----|
| Provider | `did:web:provider-ih:provider` | `BPNL000000000001` |
| Consumer | `did:web:consumer-ih:consumer` | `BPNL000000000002` |
| Issuer | `did:web:issuerservice:issuer` | — |

### Verifiable Credentials Issued

Each participant (provider, consumer) receives 3 VCs from the issuer:

| Credential Type | Purpose |
|----------------|---------|
| `MembershipCredential` | Proves active Catena-X membership |
| `BpnCredential` | Binds BPN to DID identity |
| `DataExchangeGovernanceCredential` | Authorizes data exchange under framework agreements |

---

## API Keys

| Service | Header | Value |
|---------|--------|-------|
| Connector Management API | `x-api-key` | `testkey` |
| IdentityHub / Issuer Service | `x-api-key` | `c3VwZXItdXNlcg==.superuserkey` |
| BDRS Management API | `x-api-key` | `testkey` |

---

## Available Scripts

| Script | Purpose |
|--------|---------|
| [`scripts/bootstrap.sh`](scripts/bootstrap.sh) | Full environment bootstrap (16 steps): participant creation, vault seeding, credential issuance, BDRS seeding, asset/policy setup, E2E verification |
| [`scripts/test-transfer.sh`](scripts/test-transfer.sh) | E2E transfer test: catalog → negotiate → PULL transfer → pull data |
| [`scripts/test-push-transfer.sh`](scripts/test-push-transfer.sh) | E2E PUSH transfer test: asset creation → negotiate → PUSH data to webhook |
| [`scripts/demo-management-api.sh`](scripts/demo-management-api.sh) | Comprehensive 20-operation Management API demo covering all endpoints |

---

## Postman Collection

A fully dynamic Postman collection is available at:

```
postman/EDC_Management_API_DCP.postman_collection.json
```

**Features:**
- **13 folders**, **33 requests** covering the complete E2E flow
- Auto-generated unique resource IDs (no conflicts between runs)
- Variable chaining — offer IDs, agreement IDs, transfer IDs, EDR tokens auto-extracted
- Retry loops for polling (negotiation + transfer status)
- Both **PULL** and **PUSH** transfer patterns
- Rich documentation on every request
- Can be run via [newman](https://www.npmjs.com/package/newman):

```bash
npm install -g newman
newman run postman/EDC_Management_API_DCP.postman_collection.json \
  --delay-request 3000 --timeout-request 30000
```

---

## Troubleshooting

### Check all containers are running

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | sort
# All 14 containers should show "Up"
```

### View connector logs

```bash
docker logs provider-cp -f --tail 100   # Provider Control Plane
docker logs consumer-cp -f --tail 100   # Consumer Control Plane
docker logs provider-dp -f --tail 100   # Provider Data Plane
docker logs provider-ih -f --tail 100   # Provider Identity Hub
docker logs issuerservice -f --tail 100 # Issuer Service
```

### Health checks

```bash
# EDC connectors
curl -s http://localhost:19191/api/check/health | jq .  # Provider CP
curl -s http://localhost:19196/api/check/health | jq .  # Provider DP
curl -s http://localhost:29191/api/check/health | jq .  # Consumer CP
curl -s http://localhost:29196/api/check/health | jq .  # Consumer DP

# Identity Hubs
curl -s http://localhost:7100/provider/did.json | jq .  # Provider DID Document
curl -s http://localhost:8100/consumer/did.json | jq .  # Consumer DID Document
curl -s http://localhost:18100/issuer/did.json | jq .   # Issuer DID Document

# BDRS
curl -s http://localhost:8581/api/management/bpn-directory \
  -H "x-api-key: testkey" | jq .
```

### Common issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Catalog returns empty | Access policy mismatch or missing VCs | Check `docker logs consumer-cp` for DCP auth errors |
| Negotiation TERMINATED | Policy action format wrong | Use `{"@id": "odrl:use"}` not `"use"` |
| 401 on DSP endpoint | SI token audience mismatch | Verify `edc.participant.id` = full DID on CPs |
| Transfer stuck at REQUESTED | Data plane not reachable | Check `edc.hostname` on DP config |
| EDR token invalid | Transfer proxy key format | Must be EC P-256 JWK in Vault |
| `IRI_CONFUSED_WITH_PREFIX` | Compact IRI in leftOperand | Use full IRI: `https://w3id.org/catenax/2025/9/policy/...` |

### Clean up

```bash
# Stop and remove EDC stack (preserves issuer stack)
cd deployment/local
docker compose down -v

# Full cleanup including issuer stack (from IdentityHub repo)
cd /path/to/public-tractusx-identityhub/deployment/local
docker compose down -v
```

---

## Known Issues & Fixes

See [docs/development/local-dcp-issues-and-fixes.md](../../docs/development/local-dcp-issues-and-fixes.md)
for a comprehensive catalog of all 14 issues encountered during setup and their exact fixes.

---

## Related Repositories

| Repository | Branch | Purpose |
|------------|--------|---------|
| [tractusx-edc](https://github.com/Federity-X/public-tractusx-edc/tree/dcp) (this repo) | `dcp` | EDC Connectors + Data Planes + CX extensions |
| [public-tractusx-identityhub](https://github.com/Federity-X/public-tractusx-identityhub/tree/dcp-flow-local-deployment-with-upstream-0.15.1) | `dcp-flow-local-deployment-with-upstream-0.15.1` | Identity Hub + Issuer Service (DID, VC, STS) |
| [MinimumViableDataspace](https://github.com/eclipse-edc/MinimumViableDataspace) | `main` | Reference architecture this deployment is modeled after |

---

## Directory Structure

```
deployment/local/
├── README.md                      ← This file
├── PRODUCTION_DEPLOYMENT_GUIDE.md ← What to change for production (infra team reference)
├── Dockerfile                     ← Multi-stage Docker build for CP and DP
├── docker-compose.yaml            ← 11 containers (provider, consumer, BDRS)
├── config/
│   ├── provider-cp.properties     ← Provider Control Plane config
│   ├── provider-dp.properties     ← Provider Data Plane config
│   ├── provider-ih.properties     ← Provider Identity Hub config
│   ├── provider-init.sql          ← Provider PostgreSQL init (creates edc + ih DBs)
│   ├── consumer-cp.properties     ← Consumer Control Plane config
│   ├── consumer-dp.properties     ← Consumer Data Plane config
│   ├── consumer-ih.properties     ← Consumer Identity Hub config
│   ├── consumer-init.sql          ← Consumer PostgreSQL init
│   └── ih-logging.properties      ← Identity Hub logging config
├── scripts/
│   ├── bootstrap.sh               ← Full bootstrap (16 steps, ~1068 lines)
│   ├── test-transfer.sh           ← E2E PULL transfer test
│   ├── test-push-transfer.sh      ← E2E PUSH transfer test
│   └── demo-management-api.sh     ← Comprehensive 20-operation API demo
└── postman/
    └── EDC_Management_API_DCP.postman_collection.json  ← 33-request dynamic collection
```
