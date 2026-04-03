# Local DCP Deployment — Issues, Fixes & Changes

This document captures every issue encountered while building the local DCP deployment for
Tractus-X EDC (v0.12.0-SNAPSHOT / EDC 0.15.1) with per-company Identity Hubs, and the
exact fix applied for each one.

---

## Table of Contents

1. [Architecture: Shared vs Per-Company Identity Hub](#1-architecture-shared-vs-per-company-identity-hub)
2. [VP Cache Audience Mismatch (`edc.participant.id`)](#2-vp-cache-audience-mismatch)
3. [Stale Data Plane Registrations (localhost URLs)](#3-stale-data-plane-registrations)
4. [Data Plane Hostname Resolution (`edc.hostname`)](#4-data-plane-hostname-resolution)
5. [Transfer Proxy Key Format (Raw Hex → EC P-256 JWK)](#5-transfer-proxy-key-format)
6. [Credential Definition Mapping Format](#6-credential-definition-mapping-format)
7. [JWT VC Signature Algorithm (`Ed25519` vs `EdDSA`)](#7-jwt-vc-signature-algorithm)
8. [Credential `vc_format` and `usage` Flags](#8-credential-vc_format-and-usage-flags)
9. [DataExchangeGovernanceCredential Missing from Trusted Issuer Types](#9-dataexchangegovernancecredential-missing)
10. [Policy Assigner: BPN vs DID](#10-policy-assigner-bpn-vs-did)
11. [JSON-LD `IRI_CONFUSED_WITH_PREFIX` — Compact IRIs in leftOperand](#11-json-ld-iri_confused_with_prefix)
12. [Policy Action Type Mismatch (`"use"` vs `"odrl:use"`)](#12-policy-action-type-mismatch)
13. [Diagnostic Logging in `VerifiablePresentationCacheImpl`](#13-diagnostic-logging)
14. [Bootstrap Script — Full E2E Automation](#14-bootstrap-script)
15. [DataService Self-Registration Timing Issue](#15-dataservice-self-registration-timing-issue)
16. [BDRS Server Unhealthy — Missing Default Web Context](#16-bdrs-server-unhealthy)
17. [PostgreSQL `json` vs `jsonb` Cast in DID Document Updates](#17-postgresql-json-vs-jsonb-cast)
18. [Stale Issuer DB Volume on Fresh Restart](#18-stale-issuer-db-volume-on-fresh-restart)
19. [EDC 0.15.1 Catalog Context Merged into Management](#19-edc-0151-catalog-context-merged-into-management)
20. [IdentityHub 0.15.1 `participantcontextconfig` Datasource](#20-identityhub-0151-participantcontextconfig-datasource)
21. [BDRS Image Healthcheck Reports Unhealthy (Wrong Endpoint)](#21-bdrs-image-healthcheck-reports-unhealthy)
22. [Data Plane Self-Registration Race Condition](#22-data-plane-self-registration-race-condition)
23. [Data Plane Callback Failure — Missing `edc.control.endpoint`](#23-data-plane-callback-failure--missing-edccontrolendpoint)

---

## 1. Architecture: Shared vs Per-Company Identity Hub

**Problem:** The original Identity Hub deployment plan used a single shared `identityhub`
container managing both provider and consumer participants. The DIDs were
`did:web:identityhub:provider` and `did:web:identityhub:consumer`. This worked for basic
identity, but the DCP authentication flow requires each connector to have its own STS
(Security Token Service) endpoint and its own credential store.

**Fix:** Moved to a **per-company architecture** where each company (provider, consumer) has
its own IdentityHub instance, Vault, and PostgreSQL database:

| Component      | Provider Stack               | Consumer Stack                |
|----------------|------------------------------|-------------------------------|
| Identity Hub   | `provider-ih` (:7181/7292)   | `consumer-ih` (:8182/8293)    |
| Vault          | `provider-vault` (:8201)     | `consumer-vault` (:8202)      |
| PostgreSQL     | `provider-postgres` (:6432)  | `consumer-postgres` (:6433)   |

**DIDs changed to:**
- Provider: `did:web:provider-ih:provider`
- Consumer: `did:web:consumer-ih:consumer`
- Issuer: `did:web:issuerservice:issuer` (on the shared issuer stack)

**Files created:**
- `deployment/local/docker-compose.yaml` — 14 containers across provider, consumer, issuer, and BDRS stacks
- `deployment/local/config/provider-ih.properties`, `consumer-ih.properties` — per-company IH configuration

---

## 2. VP Cache Audience Mismatch

**Problem:** After the catalog request succeeded, VP (Verifiable Presentation) validation
failed with:

```
Token audience claim (aud -> [did:web:consumer-ih:consumer]) did not contain
expected audience: consumer
```

The VP token's `aud` claim contained the full DID (`did:web:consumer-ih:consumer`),
but the connector was configured with `edc.participant.id=consumer` (short name),
so the audience comparison failed.

**Root Cause:** The `credentialValidationService.validate()` method resolves the
`ownDid` from `edc.participant.id` and checks it against the JWT `aud` claim. When
`edc.participant.id` is a short name rather than the full DID, the audience check fails.

**Fix:** Set `edc.participant.id` to the **full DID** on control planes:

```properties
# provider-cp.properties
edc.participant.id=did:web:provider-ih:provider

# consumer-cp.properties
edc.participant.id=did:web:consumer-ih:consumer
```

Data planes keep the short name (they don't participate in DCP VP validation):
```properties
# provider-dp.properties / consumer-dp.properties
edc.participant.id=provider
```

A separate property `edc.participant.context.id` carries the short name for
participant-context-scoped operations:
```properties
edc.participant.context.id=provider
```

**Files changed:**
- `deployment/local/config/provider-cp.properties` — `edc.participant.id=did:web:provider-ih:provider`
- `deployment/local/config/consumer-cp.properties` — `edc.participant.id=did:web:consumer-ih:consumer`

---

## 3. Stale Data Plane Registrations

**Problem:** After restarting data planes with updated configuration, transfers failed
because the `edc_data_plane_instance` table in each CP's database still contained old
registrations pointing to `localhost` URLs from a previous run.

**Root Cause:** Data plane self-registration persists in PostgreSQL. Restarting a DP with
a new hostname doesn't remove the old registration — it adds a new one, potentially
causing the CP to route to the stale entry.

**Fix:** Manually deleted stale registrations from both CP databases before restarting:

```sql
DELETE FROM edc_data_plane_instance
WHERE url LIKE '%localhost%';
```

Then restarted data planes so they re-registered with the correct Docker hostnames.

**Prevention:** The bootstrap script now ensures connectors start fresh. In a clean
deployment, this is not an issue since the databases start empty.

---

## 4. Data Plane Hostname Resolution

**Problem:** After transfer initiation, the provider CP tried to contact the provider DP
at `localhost:19196` (host-mapped port) instead of `provider-dp:8084` (Docker internal).
This failed because inside the Docker network, `localhost` doesn't resolve to the
host machine.

**Root Cause:** Without explicitly setting `edc.hostname`, the data plane self-registers
using the system's hostname, which inside Docker resolves to a container ID or `localhost`.
The CP then tries to proxy requests to this address.

**Fix:** Added `edc.hostname` to both data plane configurations:

```properties
# provider-dp.properties
edc.hostname=provider-dp

# consumer-dp.properties
edc.hostname=consumer-dp
```

This ensures the DP registers itself with the Docker container name, which is resolvable
from any container on the `edc-net` network.

**Files changed:**
- `deployment/local/config/provider-dp.properties` — added `edc.hostname=provider-dp`
- `deployment/local/config/consumer-dp.properties` — added `edc.hostname=consumer-dp`

---

## 5. Transfer Proxy Key Format

**Problem:** Data transfers reached `STARTED` state, but the EDR (Endpoint Data Reference)
contained an invalid access token. Data pull requests returned authentication errors.

**Root Cause:** The transfer proxy signing key was stored in Vault as a **raw hex string**.
EDC 0.15.1 expects the transfer proxy key to be an **EC P-256 JWK (JSON Web Key)** in
JSON format. The key parser silently failed or produced garbage tokens.

**Fix:** Generated proper EC P-256 JWK keys and stored them as JSON in Vault:

```json
// Provider transfer proxy key
{
  "kty": "EC",
  "crv": "P-256",
  "x": "Wpd-wxJHzg88SJI_6zE4S6EPwQiuosxvE_XI4n5dWWQ",
  "y": "kd2DdngBbh3eBC2TYrTnz2mUF35UoXGl2Bg-85E_bPg",
  "d": "9SZ3iNHpAWy6L_L6AuTqXEzkUI8rdT5Q9dDfHexMcZk",
  "kid": "provider-transfer-proxy-key"
}
```

The Vault storage function was also updated to use `jq` for safe JSON construction,
since the JWK value contains embedded quotes that break naive string interpolation:

```bash
store_vault_secret() {
    local payload
    payload=$(jq -n --arg v "$value" '{"data": {"content": $v}}')
    curl -sf -X PUT "${vault_url}/v1/secret/data/${key}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d "${payload}" > /dev/null
}
```

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — JWK keys in Step 3 (vault secret storage), `store_vault_secret()` uses `jq`

---

## 6. Credential Definition Mapping Format

**Problem:** Credential issuance failed when requesting `BpnCredential` and
`DataExchangeGovernanceCredential`. The issuer service returned errors about invalid
credential definition mappings.

**Root Cause:** The credential definition mapping format in the Issuer Service API
requires `input`/`output`/`required` fields, not the simpler format we initially used.

**Fix:** Used the correct mapping format in the bootstrap script:

```json
{
  "input": "holderIdentifier",
  "output": "credentialSubject.holderIdentifier",
  "required": false
}
```

For BPN credentials:
```json
[
  {"input": "holderIdentifier", "output": "credentialSubject.holderIdentifier", "required": false},
  {"input": "bpn", "output": "credentialSubject.id", "required": false}
]
```

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 9 (credential + attestation definitions)

---

## 7. JWT VC Signature Algorithm

**Problem:** Verifiable Credential validation failed during VP verification. The JWT VCs
issued by the issuer service could not be verified.

**Root Cause:** The issuer uses an Ed25519 key. The JWT header for VCs must specify
`"alg": "Ed25519"` (the key type identifier), **not** `"alg": "EdDSA"` (the generic
algorithm family). The EDC credential validation code specifically checks for `"Ed25519"`.

**Fix:** Ensured the issuer's signing key and VC issuance configuration use `"Ed25519"` as
the algorithm identifier. The bootstrap script constructs JWTs with:

```json
{"kid": "did:web:issuerservice:issuer#issuer-key", "alg": "Ed25519"}
```

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 10 (credential request JWT construction)

---

## 8. Credential `vc_format` and `usage` Flags

**Problem:** After credentials were issued and stored in the holder Identity Hubs, catalog
requests still failed. VPs were empty — no credentials were being selected for presentation.

**Root Cause:** Credentials stored in the holder's database had incorrect metadata:
- `vc_format = 0` (unknown) instead of `vc_format = 1` (JWT)
- `usage = 0` or `null` instead of the value indicating "available for holder presentation"

The credential query filtered by these fields, so credentials with wrong values were never
included in VPs.

**Fix:** Added a post-issuance fixup step in bootstrap that directly updates the holder databases:

```sql
-- Fix credentials in provider-ih's database
UPDATE credential SET vc_format = 1 WHERE vc_format != 1;
UPDATE credential SET usage = 'Holder' WHERE usage IS NULL OR usage != 'Holder';

-- Same for consumer-ih's database
```

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 11b (fix credential vc_format and usage)

---

## 9. DataExchangeGovernanceCredential Missing from Trusted Issuer Types

**Problem:** Contract negotiations failed with policy evaluation errors. The policy required
a `DataExchangeGovernanceCredential`, but this credential type was not being requested
during DCP authentication.

**Root Cause:** The `edc.iam.trusted-issuer.issuer.supportedtypes` property on control
planes only listed `MembershipCredential` and `BpnCredential`. The
`DataExchangeGovernanceCredential` was missing, so the VP request never asked for it,
and the returned VP didn't include it.

**Fix:** Added `DataExchangeGovernanceCredential` to the supported types on both CPs:

```properties
edc.iam.trusted-issuer.issuer.supportedtypes=["MembershipCredential","BpnCredential","DataExchangeGovernanceCredential"]
```

**Files changed:**
- `deployment/local/config/provider-cp.properties`
- `deployment/local/config/consumer-cp.properties`

**Note:** The data plane configuration files still only list `MembershipCredential` and
`BpnCredential` since DPs don't evaluate contract policies.

---

## 10. Policy Assigner: BPN vs DID

**Problem:** Contract negotiations returned `400 — Policy not fulfilled`. The consumer's
negotiation request was rejected by the provider because the policy didn't match.

**Root Cause:** The `odrl:assigner` field in the negotiation request was set to the
provider's DID (`did:web:provider-ih:provider`). However, the provider's contract
policy has `assigner = BPNL000000000001` (the BPN). In DSP v0.8, the
`BpnExtractionFunction` maps the provider's identity to its BPN for policy comparison,
so the assigner must match the BPN, not the DID.

**Fix:** Use the provider's BPN as the assigner in negotiation requests:

```json
{
  "odrl:assigner": {"@id": "BPNL000000000001"}
}
```

**NOT** `{"@id": "did:web:provider-ih:provider"}`.

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 15 (contract negotiation)
- `deployment/local/scripts/test-transfer.sh` — Step 3 (negotiation)

---

## 11. JSON-LD `IRI_CONFUSED_WITH_PREFIX`

**Problem:** After CP restart, new contract negotiations failed with:

```
Failed to compact JSON-LD: When compacting an IRI would result in an IRI which
could be confused with a compact IRI [code=IRI_CONFUSED_WITH_PREFIX].
```

The error occurred in `TitaniumJsonLd.compact()` during serialization of the outgoing
DSP contract request message on the consumer CP.

**Root Cause:** The `leftOperand` value in the stored policy was a **compact IRI**
(`cx-policy:FrameworkAgreement`) instead of the **full IRI**
(`https://w3id.org/catenax/2025/9/policy/FrameworkAgreement`).

When the `JsonObjectFromPolicyTransformer` built the JSON-LD for the DSP message, it
placed this compact IRI directly as `{"@id": "cx-policy:FrameworkAgreement"}`. During
compaction, the DSP v0.8 scope's context includes `cx-policy` as a registered prefix
(mapped to `https://w3id.org/catenax/policy/` — the **old** deprecated URL). The
Titanium JSON-LD library detected that compacting the IRI would produce an ambiguous
result and threw `IRI_CONFUSED_WITH_PREFIX`.

**Why the compact IRI was stored:** When the negotiation request body used
`"odrl:leftOperand": "cx-policy:FrameworkAgreement"`, the management API did **not**
expand this value into a full IRI, even when `cx-policy` was included in the request
`@context`. This is because the ODRL context defines `leftOperand` with
`"@type": "@vocab"`, and the EDC management API processes the embedded policy using
a nested context (`cx-odrl.jsonld`) that doesn't include the `cx-policy` prefix mapping
from the top-level request context.

**Additional complication:** The codebase has two different `cx-policy` namespace URLs:
- `CX_POLICY_NS = "https://w3id.org/catenax/policy/"` — old, deprecated (registered for DSP v0.8 scope)
- `CX_POLICY_2025_09_NS = "https://w3id.org/catenax/2025/9/policy/"` — new (used in context document `cx-policy-v1.jsonld`)

This asymmetry in `CxJsonLdExtension.java` means the DSP v0.8 scope maps `cx-policy` to
the old URL, while the JSON-LD context document maps it to the new URL.

**Fix:** Use **full IRIs** for `leftOperand` values in negotiation requests, wrapped in
`{"@id": "..."}`:

```json
{
  "odrl:leftOperand": {"@id": "https://w3id.org/catenax/2025/9/policy/FrameworkAgreement"},
  "odrl:operator": {"@id": "odrl:eq"},
  "odrl:rightOperand": "DataExchangeGovernance:1.0"
}
```

**NOT** `"odrl:leftOperand": "cx-policy:FrameworkAgreement"`.

**Related upstream issue:** [eclipse-edc/Connector#4160](https://github.com/eclipse-edc/Connector/issues/4160)
and [PR #4235](https://github.com/eclipse-edc/Connector/pull/4235) — same error pattern,
fixed with `MissingPrefixes` validator (already in 0.15.1), but that fix only covers
incoming expansion, not outgoing compaction of stored compact IRIs.

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 15 (uses full IRIs)
- `deployment/local/scripts/test-transfer.sh` — Step 3 (uses full IRIs)

---

## 12. Policy Action Type Mismatch

**Problem:** After fixing the IRI issue (Issue #11), negotiations progressed further but
were then rejected by the consumer with:

```
Policy in the contract agreement is not equal to the one in the contract offer
```

**Root Cause:** The negotiation request used `"odrl:action": "use"` (plain string).
The consumer management API stored this as `action.type = "use"`. However, the provider
received and expanded the DSP message, storing `action.type = "http://www.w3.org/ns/odrl/2/use"`
(full IRI). When the provider sent the agreement back, the consumer's DSP endpoint
expanded it to the full IRI form.

`PolicyEquality` (in `control-plane-contract`) compares policies by serializing both to
Jackson JSON trees and doing structural comparison. Since
`"use" != "http://www.w3.org/ns/odrl/2/use"`, the comparison failed.

**Fix:** Use `{"@id": "odrl:use"}` for the action, which gets properly expanded to the
full IRI `http://www.w3.org/ns/odrl/2/use` during management API processing:

```json
{
  "odrl:permission": [{
    "odrl:action": {"@id": "odrl:use"},
    ...
  }]
}
```

**NOT** `"odrl:action": "use"`.

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 15
- `deployment/local/scripts/test-transfer.sh` — Step 3

---

## 13. Diagnostic Logging in `VerifiablePresentationCacheImpl`

**Problem:** VP validation failures produced no logs at all. The original code used a
functional chain (`compose`) that swallowed failure details, making it impossible to
determine which validation step failed.

**Fix:** Replaced the functional chain with explicit step-by-step validation, logging
each step's pass/fail status:

```java
// BEFORE (original code)
return validateRequestedCredentials(presentations, scopes)
        .compose(ignore -> credentialValidationService.validate(...))
        .compose(ignore -> verifyPresentationIssuer(...))
        .succeeded();

// AFTER (with diagnostics)
var step1 = validateRequestedCredentials(presentations, scopes);
if (step1.failed()) {
    monitor.warning("VP validation FAILED at step 1 (validateRequestedCredentials): "
        + step1.getFailureDetail());
    return false;
}
monitor.warning("VP validation PASSED step 1 (validateRequestedCredentials)");

var step2 = credentialValidationService.validate(presentations, ownDid, Collections.emptyList());
if (step2.failed()) {
    monitor.warning("VP validation FAILED at step 2 for ownDid=%s: %s"
        .formatted(ownDid, step2.getFailureDetail()));
    return false;
}
// ... step 3 ...
```

This was critical for diagnosing Issue #2 (audience mismatch).

**Files changed:**
- `edc-extensions/dcp/verifiable-presentation-cache/src/main/java/org/eclipse/tractusx/edc/iam/dcp/cache/VerifiablePresentationCacheImpl.java`

---

## 14. Bootstrap Script — Full E2E Automation

**Problem:** There was no automated way to set up the complete DCP deployment. Each step
(participant creation, credential issuance, vault seeding, etc.) had to be done manually,
with many subtle ordering requirements and format expectations.

**Fix:** Created a comprehensive bootstrap script (`bootstrap.sh`) that automates the
entire setup in 16 steps:

| Step  | Description |
|-------|-------------|
| 0     | Check prerequisites (health checks for IH, Vault, DB) |
| 0b    | Create BDRS database on issuer-postgres |
| 0c    | Store BDRS management API key in issuer-vault |
| 1     | Create provider participant in provider-ih |
| 2     | Create consumer participant in consumer-ih |
| 3     | Store secrets in per-company vaults (STS secrets, transfer proxy JWK keys, IH API keys) |
| 4     | Verify STS token acquisition |
| 5     | Create issuer participant in issuerservice |
| 6     | Register holders (provider, consumer) in issuerservice |
| 7     | Fix key IDs to full DID URL format |
| 8     | Add CredentialService + DataService + IssuerService endpoints to DID documents |
| 9     | Create attestation + credential definitions |
| 10    | Request credentials via DCP (Membership, BPN, DataExchangeGovernance) |
| 11    | Verify credentials (expecting 3 each) |
| 11b   | Fix credential `vc_format` and `usage` flags |
| 12    | Seed BDRS server (BPN↔DID mappings) |
| 13    | Create asset, policies, and contract definitions on provider |
| 14    | Verify catalog access from consumer |
| 15    | Negotiate contract (with full IRIs and correct action format) |
| 16    | Start data transfer and pull data (full E2E verification) |

Also created `test-transfer.sh` — a standalone E2E test that runs Steps 14–16 on an
already-bootstrapped deployment.

**Files created:**
- `deployment/local/scripts/bootstrap.sh` (~1068 lines)
- `deployment/local/scripts/test-transfer.sh` (~237 lines)

---

## Summary of All Changed/Created Files

### New Files (entire `deployment/local/` directory)

| File | Purpose |
|------|---------|
| `deployment/local/docker-compose.yaml` | 14-container Docker Compose with per-company architecture |
| `deployment/local/Dockerfile` | Multi-stage build for EDC connector images |
| `deployment/local/README.md` | Deployment documentation |
| `deployment/local/config/provider-cp.properties` | Provider control plane configuration |
| `deployment/local/config/provider-dp.properties` | Provider data plane configuration |
| `deployment/local/config/consumer-cp.properties` | Consumer control plane configuration |
| `deployment/local/config/consumer-dp.properties` | Consumer data plane configuration |
| `deployment/local/config/provider-ih.properties` | Provider Identity Hub configuration |
| `deployment/local/config/consumer-ih.properties` | Consumer Identity Hub configuration |
| `deployment/local/config/provider-init.sql` | Provider PostgreSQL init (creates EDC + IH databases) |
| `deployment/local/config/consumer-init.sql` | Consumer PostgreSQL init (creates EDC + IH databases) |
| `deployment/local/config/ih-logging.properties` | Identity Hub logging configuration |
| `deployment/local/scripts/bootstrap.sh` | Full bootstrap automation (1068 lines) |
| `deployment/local/scripts/test-transfer.sh` | E2E transfer test script (237 lines) |
| `deployment/local/scripts/seed-vault.sh` | Vault seeding helper |
| `docs/development/local-dcp-deployment-plan.md` | Architecture and deployment plan |

### Modified Files (from `dcp` branch)

| File | Change |
|------|--------|
| `edc-extensions/dcp/verifiable-presentation-cache/src/main/java/.../VerifiablePresentationCacheImpl.java` | Added diagnostic logging to `areCredentialsValid()` — breaks out functional chain into step-by-step validation with WARN-level logging for each step |

---

## Key Configuration Requirements (Quick Reference)

| Property | Required Value | Why |
|----------|---------------|-----|
| `edc.participant.id` (CP) | Full DID (e.g., `did:web:provider-ih:provider`) | VP audience validation |
| `edc.participant.id` (DP) | Short name (e.g., `provider`) | Not used for DCP auth |
| `edc.participant.context.id` | Short name (e.g., `provider`) | Participant context scoping |
| `edc.hostname` (DP) | Docker container name (e.g., `provider-dp`) | DP self-registration URL |
| `edc.iam.trusted-issuer.issuer.supportedtypes` | Include `DataExchangeGovernanceCredential` | Policy evaluation needs this VC |
| Transfer proxy key (Vault) | EC P-256 JWK JSON | EDR token signing/verification |
| `odrl:assigner` (negotiation) | Provider BPN, not DID | DSP v0.8 BPN extraction |
| `odrl:action` (negotiation) | `{"@id": "odrl:use"}` | Policy comparison requires full IRI |
| `odrl:leftOperand` (negotiation) | Full IRI with `{"@id": "..."}` | Avoids `IRI_CONFUSED_WITH_PREFIX` |

---

## 15. DataService Self-Registration Timing Issue

**Problem:** After deploying all containers fresh, the BDRS connector discovery API
returned 400 — "No connector endpoints found for counterPartyId did:web:provider-ih:provider".
The DID document had `CredentialService` but **no `DataService`** entry. Without a
`DataService` entry, the provider's DSP endpoint cannot be discovered from its DID.

**Root Cause:** The connector self-registration feature
(`tx.edc.did.service.self.registration.enabled=true`) runs at **connector startup**.
However, it needs the IH API key from Vault (`provider-ih-api-key`), which is only seeded
in bootstrap Step 3 — **after** the containers have already started.

Log evidence:
```
IdentityHub DidDocumentServiceClient will not be registered:
could not resolve API key from vault alias 'provider-ih-api-key'
```
```
Did Document Service Client not available or not enabled, skipping self-registration
```

**Fix:** Added explicit DataService registration in `bootstrap.sh` Step 8+, using the
IdentityHub Identity Admin API:

```bash
# Register DataService for provider
curl -sf -X POST "http://localhost:7151/api/identity/v1alpha/participants/${PROVIDER_B64}/dids/${PROVIDER_DID_B64}/endpoints?autoPublish=true" \
  -H "x-api-key: ${IH_SUPERUSER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "did:web:provider-ih:provider#DataService",
    "type": "DataService",
    "serviceEndpoint": "http://provider-cp:8084/api/v1/dsp/.well-known/dspace-version"
  }'
```

The self-registration properties remain in the CP configuration so that it **will** work
correctly if the connector is restarted after bootstrap (since Vault keys are then available).

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Step 8 (DataService registration for provider and consumer)

---

## 16. BDRS Server Unhealthy — Missing Default Web Context

**Problem:** After deployment, `docker ps` showed `bdrs-server` as `(unhealthy)`. All other
containers with health checks showed `(healthy)`.

**Root Cause:** The `tractusx/bdrs-server:latest` Docker image has a **built-in health check**:
```
HEALTHCHECK CMD curl --fail http://localhost:8080/api/check/health
```

The health check targets port 8080 (EDC's default web context). However, the docker-compose
configuration only defined the BDRS-specific ports (8580 for directory API, 8581 for
management API) and did **not** configure the standard EDC default web context. Without
`WEB_HTTP_PORT` and `WEB_HTTP_PATH`, port 8080 had no listener, and the health check
returned "connection refused" (exit code 7).

**Fix:** Added the default web context configuration to the BDRS service in
`docker-compose.yaml`:

```yaml
bdrs-server:
  environment:
    WEB_HTTP_PORT: "8080"
    WEB_HTTP_PATH: "/api"
```

This enables the standard EDC web module on port 8080, which serves the
`/api/check/health` endpoint that the built-in health check expects.

**Files changed:**
- `deployment/local/docker-compose.yaml` — Added `WEB_HTTP_PORT` and `WEB_HTTP_PATH` to BDRS environment

---

## 17. PostgreSQL `json` vs `jsonb` Cast in DID Document Updates

**Problem:** Bootstrap Steps 7 and 8 update DID documents stored in PostgreSQL using
`jsonb_set()`. The SQL failed with:
```
ERROR: function jsonb_set(json, text[], jsonb) does not exist
```

**Root Cause:** The `did_document` column in the IdentityHub database uses the `json` type
(not `jsonb`). PostgreSQL's `jsonb_set()` function requires `jsonb` input. The column
needed to be cast to `jsonb` for manipulation, then cast back to `json` for storage.

**Fix:** Added explicit casts in all `UPDATE` statements in Steps 7 and 8:

```sql
-- Before (fails)
UPDATE did_document
SET did_document = jsonb_set(did_document, '{verificationMethod,0,id}', ...);

-- After (works)
UPDATE did_document
SET did_document = jsonb_set(did_document::jsonb, '{verificationMethod,0,id}', ...)::json;
```

**Files changed:**
- `deployment/local/scripts/bootstrap.sh` — Steps 7 and 8 (all 6+ UPDATE statements)

---

## 18. Stale Issuer DB Volume on Fresh Restart

**Symptom:** After a fresh restart, credential issuance fails silently — `bootstrap.sh`
Step 11 shows `Total: 0` credentials for both provider and consumer. Issuer logs contain:

```
JWSSigner cannot be generated for private key 'issuer-key':
Private key with ID 'issuer-key' not found in Config
```

**Root cause:** The deployment uses two separate Docker Compose files:
- **EDC stack** (`tractusx-edc/deployment/local/docker-compose.yaml`) — 11 services
- **Issuer stack** (`tractusx-identityhub/deployment/local/docker-compose.yaml`) — 3 services

Running `docker compose down -v` on only the EDC stack removes EDC volumes but leaves the
issuer PostgreSQL volume (`issuer-postgres-data`) intact. Meanwhile, `issuer-vault` runs in
HashiCorp Vault **dev mode** (in-memory) — all secrets are lost on restart.

On the next `docker compose up`, issuer-postgres still has the old participant context and
keypair DB records (including `issuer-key`), but the actual private key no longer exists in
the fresh vault. When the issuer attempts to sign VCs, it finds the keypair reference in the
DB but cannot locate the corresponding secret in vault, causing issuance to fail with
state 300 (ERROR).

**Fix:** Always tear down **both** compose stacks with `-v`:

```bash
# 1. Stop issuer stack first
cd /path/to/tractusx-identityhub/deployment/local
docker compose down -v

# 2. Stop EDC stack
cd /path/to/tractusx-edc/deployment/local
docker compose down -v
```

**Files changed:**
- `deployment/local/README.md` — Updated "Clean up" section with warning about both stacks

---

## 19. EDC 0.15.1 Catalog Context Merged into Management

**Problem:** After upgrading to EDC 0.15.1 (via PR#8 v2 rebase), both control planes
crashed at startup with:

```
java.lang.IllegalArgumentException: No PortMapping for contextName 'catalog' found
```

**Root Cause:** Prior to EDC 0.15.1, the catalog API was a separate web context
(`web.http.catalog.*` on port 8085). In 0.15.1, `CatalogApiExtension` was refactored to
register under the `"management"` web context instead. The DSP catalog endpoints
(`DspCatalogApiV08Extension`) register under the `"protocol"` context.

With the old `web.http.catalog.port=8085` / `web.http.catalog.path=/api/v1/catalog`
entries still present, the `WebServiceConfigurerImpl` tried to create a port mapping for
a `"catalog"` context that no extension registered under, triggering the error.

**Discovery:** Decompiled `CatalogApiExtension.class` from the 0.15.1 JARs — confirmed
`@WebService(contextAlias = "management")` annotation on the REST controller.

**Fix:** Removed all `web.http.catalog.*` properties from both CP config files, and
removed the corresponding port 8085 mapping from docker-compose.yaml:

```properties
# REMOVED from provider-cp.properties and consumer-cp.properties:
# web.http.catalog.port=8085
# web.http.catalog.path=/api/v1/catalog
# web.http.catalog.auth.type=tokenbased
# web.http.catalog.auth.key=testkey
```

```yaml
# REMOVED from docker-compose.yaml:
# provider-cp:  - "19195:8085"  # catalog
# consumer-cp:  - "29195:8085"  # catalog
```

Catalog endpoints are now accessed via the management port (8081 → host 19193/29193).

**Files changed:**
- `deployment/local/config/provider-cp.properties` — Removed `web.http.catalog.*` (4 lines)
- `deployment/local/config/consumer-cp.properties` — Removed `web.http.catalog.*` (4 lines)
- `deployment/local/docker-compose.yaml` — Removed port 8085 mappings for both CPs

---

## 20. IdentityHub 0.15.1 `participantcontextconfig` Datasource

**Problem:** After upgrading to IdentityHub 0.15.1, both provider-ih and consumer-ih
crashed at startup with:

```
ERROR: relation "edc_participant_context_config" does not exist
```

The Flyway migration for the `participantcontextconfig` store ran but could not find
a configured datasource, causing the `ParticipantContextConfigMigrationExtension` to
fail during schema creation.

**Root Cause:** IdentityHub 0.15.1 added a new SQL store subsystem —
`participantcontext-config-store-sql` — that persists participant context configuration
in a dedicated table (`edc_participant_context_config`). This requires both:

1. A named datasource: `edc.datasource.participantcontextconfig.url/user/password`
2. A store mapping: `edc.sql.store.participantcontextconfig.datasource=default`

These entries were present in the `issuerservice.properties` (which was updated as part
of the IdentityHub repo changes) but were missing from `provider-ih.properties` and
`consumer-ih.properties` (which live in the EDC repo and were written before 0.15.1).

**Discovery:** Compared the working `issuerservice.properties` against the failing
`provider-ih.properties` — diffed datasource entries to find the missing one.

**Fix:** Added the `participantcontextconfig` datasource and store mapping to both
IH config files:

```properties
# Added to provider-ih.properties
edc.datasource.participantcontextconfig.url=jdbc:postgresql://provider-postgres:5432/provider
edc.datasource.participantcontextconfig.user=provider
edc.datasource.participantcontextconfig.password=provider
edc.sql.store.participantcontextconfig.datasource=default

# Added to consumer-ih.properties (with consumer credentials)
edc.datasource.participantcontextconfig.url=jdbc:postgresql://consumer-postgres:5432/consumer
edc.datasource.participantcontextconfig.user=consumer
edc.datasource.participantcontextconfig.password=consumer
edc.sql.store.participantcontextconfig.datasource=default
```

**Files changed:**
- `deployment/local/config/provider-ih.properties` — Added 4 lines for `participantcontextconfig`
- `deployment/local/config/consumer-ih.properties` — Added 4 lines for `participantcontextconfig`

---

## 21. BDRS Image Healthcheck Reports Unhealthy (Wrong Endpoint)

**Symptom:** After `docker compose up -d`, `docker ps` shows `bdrs-server` as `(unhealthy)`
even though `docker logs bdrs-server` confirms "42 service extensions started" and
"Runtime ready".

**Root Cause:** The upstream `tractusx/bdrs-server:latest` image has a **built-in
healthcheck** that runs `curl --fail http://localhost:8080/api/check/health`. However,
this endpoint returns **404 Not Found** — it does not exist in the BDRS server runtime.

The correct health endpoints are:
- `/api/check/startup` → 200
- `/api/check/liveness` → 200
- `/api/check/readiness` → 200

The docker-compose did not override the image's default healthcheck, so Docker kept
reporting the container as unhealthy despite the runtime being fully functional.

**Fix:** Added a `healthcheck` override to the BDRS service in `docker-compose.yaml`
that uses the working `/api/check/liveness` endpoint:

```yaml
bdrs-server:
  image: tractusx/bdrs-server:latest
  ...
  healthcheck:
    test: ["CMD-SHELL", "curl --fail http://localhost:8080/api/check/liveness || exit 1"]
    interval: 5s
    timeout: 5s
    retries: 10
```

**Files changed:**
- `deployment/local/docker-compose.yaml` — Added `healthcheck` override to `bdrs-server` service

---

## 22. Data Plane Self-Registration Race Condition

**Symptom:** On a completely fresh `docker compose up -d`, `consumer-dp` (and sometimes
`provider-dp`) fails to start with:

```
EdcException: Cannot register data plane to the control plane:
An unknown error happened, HTTP Status = 405.
  URI: http://consumer-cp:8083/control/v1/dataplanes
  STATUS: 405
  MESSAGE: HTTP method POST is not supported by this URL
```

The data plane runtime exits fatally and Docker marks it as `unhealthy`.

**Root Cause:** The data plane's `DataplaneSelfRegistrationExtension` POSTs to the
control plane's `/control/v1/dataplanes` endpoint during startup. However, the
docker-compose only had `depends_on` for postgres and vault — **not** on the control
plane being healthy. In a cold start the data plane could boot and attempt registration
before the control plane's Jetty server had bound its `/control` context, resulting in
a 405 "Method Not Allowed" (Jetty's default response to an unregistered servlet path).

**Fix:** Added `depends_on` on the control plane with `condition: service_healthy` to
both data plane services:

```yaml
provider-dp:
  depends_on:
    provider-cp:
      condition: service_healthy
    provider-postgres:
      condition: service_healthy
    provider-vault:
      condition: service_healthy

consumer-dp:
  depends_on:
    consumer-cp:
      condition: service_healthy
    consumer-postgres:
      condition: service_healthy
    consumer-vault:
      condition: service_healthy
```

This ensures data planes only start after their control plane is fully healthy and
accepting requests on all web contexts.

**Files changed:**
- `deployment/local/docker-compose.yaml` — Added `provider-cp` / `consumer-cp`
  dependencies to `provider-dp` / `consumer-dp` services

---

## 21. BDRS Image Healthcheck Reports Unhealthy

**Symptom:** `docker ps` shows `bdrs-server` as **(unhealthy)** despite the
runtime starting normally (logs show "42 service extensions started" and
"Runtime ready").

**Root cause:** The upstream `tractusx/bdrs-server:latest` image has a built-in
Docker `HEALTHCHECK` that probes `http://localhost:8080/api/check/health`. This
endpoint returns **404 Not Found** — the image does not expose `/api/check/health`.

The correct EDC health endpoints are:

| Endpoint | Status |
|----------|--------|
| `/api/check/health` | 404 (broken) |
| `/api/check/startup` | 200 |
| `/api/check/liveness` | 200 |
| `/api/check/readiness` | 200 |

Because our `docker-compose.yaml` did **not** override the image healthcheck,
Docker continuously probed the broken endpoint and marked the container unhealthy
after 10 retries.

**Fix:** Added an explicit `healthcheck` override in `docker-compose.yaml` for
the `bdrs-server` service, targeting `/api/check/liveness` instead:

```yaml
  bdrs-server:
    image: tractusx/bdrs-server:latest
    # ... environment, ports ...
    healthcheck:
      test: ["CMD-SHELL", "curl --fail http://localhost:8080/api/check/liveness || exit 1"]
      interval: 5s
      timeout: 5s
      retries: 10
```

**Files changed:**
- `deployment/local/docker-compose.yaml` — Added `healthcheck` block to `bdrs-server` service

---

## 23. Data Plane Callback Failure — Missing `edc.control.endpoint`

**Symptom:** PUSH transfers complete data delivery to the consumer's HTTP endpoint
(e.g., webhook.site receives the data), but the transfer process stays stuck in
`STARTED` state and never transitions to `COMPLETED`. Data Plane logs show:

```
Failed to send callback request: HTTP Status = 0
```

**Root cause:** Without `edc.control.endpoint` explicitly configured, the connector
defaults to a `localhost`-based callback URL (e.g., `http://localhost:8083/control`).
In Docker, `localhost` resolves to the container itself — so when the Data Plane
tries to signal transfer completion back to the Control Plane, the HTTP request goes
to the DP container's own loopback interface, which has nothing listening on port 8083.
The result is a connection refused → `HTTP Status = 0`.

This affects all four containers (both CPs and both DPs) because both the Control Plane
and Data Plane need to know each other's control endpoint for bidirectional signaling:
- **DP → CP**: Transfer completion callbacks (STARTED → COMPLETED)
- **CP → DP**: Transfer lifecycle commands (suspend, resume, terminate)

**Fix:** Added `edc.control.endpoint` to all four properties files using Docker
container hostnames:

```properties
# provider-cp.properties
edc.control.endpoint=http://provider-cp:8083/control

# provider-dp.properties
edc.control.endpoint=http://provider-dp:8084/api/control

# consumer-cp.properties
edc.control.endpoint=http://consumer-cp:8083/control

# consumer-dp.properties
edc.control.endpoint=http://consumer-dp:8084/api/control
```

**Side effect fixed:** With callbacks now working, finite PUSH transfers (like our
test asset) transition to COMPLETED immediately after data delivery. This meant the
Postman collection's Folder 12 (Transfer Lifecycle — suspend/resume) could no longer
operate on the PUSH transfer (you can't suspend a COMPLETED transfer). The fix was to
switch Folder 12's suspend/resume operations to use the PULL transfer ID instead, since
PULL transfers remain in STARTED state indefinitely (waiting for consumer to fetch data).

**Files changed:**
- `deployment/local/config/provider-cp.properties` — Added `edc.control.endpoint`
- `deployment/local/config/provider-dp.properties` — Added `edc.control.endpoint`
- `deployment/local/config/consumer-cp.properties` — Added `edc.control.endpoint`
- `deployment/local/config/consumer-dp.properties` — Added `edc.control.endpoint`
- `deployment/local/postman/EDC_Management_API_DCP.postman_collection.json` — Folder 12 switched from `pushTransferId` to `transferId` (PULL)
