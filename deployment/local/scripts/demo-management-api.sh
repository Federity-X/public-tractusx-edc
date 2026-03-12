#!/usr/bin/env bash
#
# Comprehensive EDC Management API Demo
#
# Demonstrates ALL key management API operations for a local DCP deployment:
#   1.  Health checks
#   2.  Asset CRUD (create, query, get by id)
#   3.  Policy Definition CRUD (access + contract policies, query)
#   4.  Contract Definition CRUD (create, query)
#   5.  Catalog browsing (request, filtered request)
#   6.  Contract Negotiation (initiate, poll, finalize)
#   7.  Contract Agreement query
#   8.  Transfer Process — HttpData-PULL (initiate, poll)
#   9.  EDR retrieval and data pull
#   10. EDR cache query
#   11. Transfer suspend and terminate
#   12. Cleanup (optional)
#
# Prerequisites:
#   - All services running (bootstrap.sh completed)
#   - OR at minimum: IH stack + EDC connectors + credentials issued
#
# Usage:
#   ./demo-management-api.sh              # Full demo (creates new assets)
#   ./demo-management-api.sh --cleanup    # Run cleanup at the end
#   ./demo-management-api.sh --skip-setup # Skip asset/policy creation (use existing)
#
set -euo pipefail

# ========================================
# Configuration
# ========================================
PROVIDER_MGMT="http://localhost:19193/management"
CONSUMER_MGMT="http://localhost:29193/management"
PROVIDER_DEFAULT="http://localhost:19191/api"
CONSUMER_DEFAULT="http://localhost:29191/api"
PROVIDER_DSP="http://provider-cp:8084/api/v1/dsp"
PROVIDER_DID="did:web:provider-ih:provider"
PROVIDER_BPN="BPNL000000000001"
API_KEY="testkey"

# Parse arguments
CLEANUP=false
SKIP_SETUP=false
for arg in "$@"; do
    case "$arg" in
        --cleanup) CLEANUP=true ;;
        --skip-setup) SKIP_SETUP=true ;;
    esac
done

# Helper: pretty-print JSON (truncated)
pp() { jq '.' 2>/dev/null | head -c 2000; }
# Helper: section header
section() {
    echo ""
    echo "================================================================="
    echo " $1"
    echo "================================================================="
    echo ""
}
# Helper: step label
step() { echo ">>> $1"; }
# Helper: sub-step
substep() { echo "    $1"; }
# Helper: result
result() { echo "    ✓ $1"; }
# Helper: fail and exit
fail() { echo "    ✗ FAIL: $1"; exit 1; }
# Helper: separator
sep() { echo "    ---"; }

# Track IDs created during the demo for cleanup
DEMO_ASSET_ID="demo-asset-$(date +%s)"
DEMO_ACCESS_POLICY_ID="demo-access-policy-$(date +%s)"
DEMO_CONTRACT_POLICY_ID="demo-contract-policy-$(date +%s)"
DEMO_CONTRACT_DEF_ID="demo-contract-def-$(date +%s)"
CX_POLICY_NS="https://w3id.org/catenax/2025/9/policy/"

section "EDC Management API — Comprehensive Demo"
echo "Provider Management: ${PROVIDER_MGMT}"
echo "Consumer Management: ${CONSUMER_MGMT}"
echo "Provider DSP:        ${PROVIDER_DSP}"
echo ""

# ==========================================
# 1. HEALTH CHECKS
# ==========================================
section "1. Health Checks"

for label_url in \
    "Provider CP:${PROVIDER_DEFAULT}/check/health" \
    "Provider DP:http://localhost:19196/api/check/health" \
    "Consumer CP:${CONSUMER_DEFAULT}/check/health" \
    "Consumer DP:http://localhost:29196/api/check/health"; do
    label="${label_url%%:*}"
    # The URL contains colons, so split on first colon only
    url="${label_url#*:}"
    if curl -sf "${url}" > /dev/null 2>&1; then
        result "${label}: healthy"
    else
        fail "${label} is not healthy at ${url}"
    fi
done

if [ "${SKIP_SETUP}" = true ]; then
    echo ""
    echo "(Skipping setup — using existing assets/policies)"
    # Use the IDs from bootstrap
    DEMO_ASSET_ID="test-asset-1"
    DEMO_ACCESS_POLICY_ID="access-policy-1"
    DEMO_CONTRACT_POLICY_ID="contract-policy-1"
    DEMO_CONTRACT_DEF_ID="contract-def-1"
else

# ==========================================
# 2. ASSET MANAGEMENT (Provider side)
# ==========================================
section "2. Asset Management (Provider)"

step "2a. Create asset: ${DEMO_ASSET_ID}"
ASSET_RESP=$(curl -sf -X POST "${PROVIDER_MGMT}/v3/assets" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {
        "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
        "dct": "http://purl.org/dc/terms/"
      },
      "@type": "Asset",
      "@id": "'"${DEMO_ASSET_ID}"'",
      "properties": {
        "name": "Demo API Asset",
        "dct:type": {"@id": "https://w3id.org/catenax/taxonomy#DemoData"},
        "contenttype": "application/json",
        "description": "A demo asset for management API walkthrough"
      },
      "dataAddress": {
        "@type": "DataAddress",
        "type": "HttpData",
        "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
      }
    }') || fail "Asset creation failed"
result "Created: $(echo "${ASSET_RESP}" | jq -r '.["@id"]')"
sep

step "2b. Query all assets on provider"
ASSETS=$(curl -sf -X POST "${PROVIDER_MGMT}/v3/assets/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "offset": 0,
      "limit": 50
    }') || fail "Asset query failed"
ASSET_COUNT=$(echo "${ASSETS}" | jq 'length')
result "Found ${ASSET_COUNT} asset(s)"
echo "${ASSETS}" | jq -r '.[] | "      - \(.["@id"]) (\(.properties.name // "unnamed"))"'
sep

step "2c. Query assets with filter (id = ${DEMO_ASSET_ID})"
FILTERED=$(curl -sf -X POST "${PROVIDER_MGMT}/v3/assets/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "filterExpression": [
        {"operandLeft": "https://w3id.org/edc/v0.0.1/ns/id", "operator": "=", "operandRight": "'"${DEMO_ASSET_ID}"'"}
      ]
    }') || fail "Filtered asset query failed"
result "Matched: $(echo "${FILTERED}" | jq 'length') asset(s)"

# ==========================================
# 3. POLICY DEFINITION MANAGEMENT (Provider side)
# ==========================================
section "3. Policy Definition Management (Provider)"

step "3a. Create access policy: ${DEMO_ACCESS_POLICY_ID} (unrestricted)"
curl -sf -X POST "${PROVIDER_MGMT}/v3/policydefinitions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
      "@id": "'"${DEMO_ACCESS_POLICY_ID}"'",
      "policy": {
        "@type": "odrl:Set",
        "odrl:permission": [],
        "odrl:prohibition": [],
        "odrl:obligation": []
      }
    }' > /dev/null || fail "Access policy creation failed"
result "Created access policy (unrestricted — visible to all)"
sep

step "3b. Create contract policy: ${DEMO_CONTRACT_POLICY_ID}"
echo "    (FrameworkAgreement = DataExchangeGovernance:1.0 AND UsagePurpose = cx.core.industrycore:1)"
curl -sf -X POST "${PROVIDER_MGMT}/v3/policydefinitions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {
        "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
        "odrl": "http://www.w3.org/ns/odrl/2/",
        "cx-policy": "'"${CX_POLICY_NS}"'"
      },
      "@id": "'"${DEMO_CONTRACT_POLICY_ID}"'",
      "policy": {
        "@type": "odrl:Set",
        "odrl:permission": [{
          "odrl:action": {"@id": "odrl:use"},
          "odrl:constraint": {
            "odrl:and": [
              {
                "odrl:leftOperand": {"@id": "cx-policy:FrameworkAgreement"},
                "odrl:operator": {"@id": "odrl:eq"},
                "odrl:rightOperand": "DataExchangeGovernance:1.0"
              },
              {
                "odrl:leftOperand": {"@id": "cx-policy:UsagePurpose"},
                "odrl:operator": {"@id": "odrl:isAnyOf"},
                "odrl:rightOperand": "cx.core.industrycore:1"
              }
            ]
          }
        }],
        "odrl:prohibition": [],
        "odrl:obligation": []
      }
    }' > /dev/null || fail "Contract policy creation failed"
result "Created contract policy (CX framework constraints)"
sep

step "3c. Query all policy definitions on provider"
POLICIES=$(curl -sf -X POST "${PROVIDER_MGMT}/v3/policydefinitions/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "offset": 0,
      "limit": 50
    }') || fail "Policy query failed"
POLICY_COUNT=$(echo "${POLICIES}" | jq 'length')
result "Found ${POLICY_COUNT} policy definition(s)"
echo "${POLICIES}" | jq -r '.[] | "      - \(.["@id"])"'

# ==========================================
# 4. CONTRACT DEFINITION MANAGEMENT (Provider side)
# ==========================================
section "4. Contract Definition Management (Provider)"

step "4a. Create contract definition: ${DEMO_CONTRACT_DEF_ID}"
echo "    (links access policy + contract policy → asset)"
curl -sf -X POST "${PROVIDER_MGMT}/v3/contractdefinitions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "@id": "'"${DEMO_CONTRACT_DEF_ID}"'",
      "accessPolicyId": "'"${DEMO_ACCESS_POLICY_ID}"'",
      "contractPolicyId": "'"${DEMO_CONTRACT_POLICY_ID}"'",
      "assetsSelector": {
        "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
        "operator": "=",
        "operandRight": "'"${DEMO_ASSET_ID}"'"
      }
    }' > /dev/null || fail "Contract definition creation failed"
result "Created — asset '${DEMO_ASSET_ID}' is now visible in the dataspace"
sep

step "4b. Query all contract definitions on provider"
CDEFS=$(curl -sf -X POST "${PROVIDER_MGMT}/v3/contractdefinitions/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "offset": 0,
      "limit": 50
    }') || fail "Contract definition query failed"
CDEF_COUNT=$(echo "${CDEFS}" | jq 'length')
result "Found ${CDEF_COUNT} contract definition(s)"
echo "${CDEFS}" | jq -r '.[] | "      - \(.["@id"]) → access:\(.accessPolicyId) contract:\(.contractPolicyId)"'

fi  # end of SKIP_SETUP block

# ==========================================
# 5. CATALOG BROWSING (Consumer side)
# ==========================================
section "5. Catalog Browsing (Consumer → Provider)"

step "5a. Request full catalog from provider"
CATALOG=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/catalog/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
      "counterPartyAddress": "'"${PROVIDER_DSP}"'",
      "counterPartyId": "'"${PROVIDER_DID}"'",
      "protocol": "dataspace-protocol-http"
    }') || fail "Catalog request failed"

# Handle both single dataset and array
DATASETS=$(echo "${CATALOG}" | jq '[.["dcat:dataset"]] | flatten')
DATASET_COUNT=$(echo "${DATASETS}" | jq 'length')
result "Catalog contains ${DATASET_COUNT} dataset(s)"
echo "${DATASETS}" | jq -r '.[] | "      - \(.["@id"]) (offers: \([.["odrl:hasPolicy"]] | flatten | length))"'
sep

step "5b. Request catalog with filter (only our demo asset)"
FILTERED_CAT=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/catalog/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
      "counterPartyAddress": "'"${PROVIDER_DSP}"'",
      "counterPartyId": "'"${PROVIDER_DID}"'",
      "protocol": "dataspace-protocol-http",
      "querySpec": {
        "filterExpression": [
          {"operandLeft": "https://w3id.org/edc/v0.0.1/ns/id", "operator": "=", "operandRight": "'"${DEMO_ASSET_ID}"'"}
        ]
      }
    }') || fail "Filtered catalog request failed"
FILTERED_DS=$(echo "${FILTERED_CAT}" | jq '[.["dcat:dataset"]] | flatten')
result "Filtered catalog: $(echo "${FILTERED_DS}" | jq 'length') dataset(s)"
sep

step "5c. Extract offer details for negotiation"
# Get the first matching dataset
DATASET=$(echo "${FILTERED_DS}" | jq '.[0]')
ASSET_ID=$(echo "${DATASET}" | jq -r '.["@id"]')
OFFER=$(echo "${DATASET}" | jq '[.["odrl:hasPolicy"]] | flatten | .[0]')
OFFER_ID=$(echo "${OFFER}" | jq -r '.["@id"]')
result "Asset ID:  ${ASSET_ID}"
result "Offer ID:  ${OFFER_ID}"

if [ "${OFFER_ID}" = "null" ] || [ -z "${OFFER_ID}" ]; then
    fail "No offer found for asset ${DEMO_ASSET_ID}"
fi

echo ""
echo "    Offer policy details:"
echo "${OFFER}" | jq '.' | sed 's/^/      /' | head -30

# ==========================================
# 6. CONTRACT NEGOTIATION (Consumer side)
# ==========================================
section "6. Contract Negotiation (Consumer → Provider)"

step "6a. Initiate negotiation"
echo "    IMPORTANT: Policy must match catalog offer exactly."
echo "    Key rules:"
echo "      - odrl:assigner = provider BPN (not DID)"
echo "      - odrl:action   = {\"@id\": \"odrl:use\"} (full IRI form)"
echo "      - leftOperand   = full IRI in {\"@id\": \"...\"}"

NEGOTIATION=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/contractnegotiations" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {
        "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
        "odrl": "http://www.w3.org/ns/odrl/2/"
      },
      "counterPartyAddress": "'"${PROVIDER_DSP}"'",
      "counterPartyId": "'"${PROVIDER_DID}"'",
      "protocol": "dataspace-protocol-http",
      "policy": {
        "@type": "odrl:Offer",
        "@id": "'"${OFFER_ID}"'",
        "odrl:assigner": {"@id": "'"${PROVIDER_BPN}"'"},
        "odrl:target": {"@id": "'"${ASSET_ID}"'"},
        "odrl:permission": [{
          "odrl:action": {"@id": "odrl:use"},
          "odrl:constraint": {
            "odrl:and": [
              {
                "odrl:leftOperand": {"@id": "'"${CX_POLICY_NS}"'FrameworkAgreement"},
                "odrl:operator": {"@id": "odrl:eq"},
                "odrl:rightOperand": "DataExchangeGovernance:1.0"
              },
              {
                "odrl:leftOperand": {"@id": "'"${CX_POLICY_NS}"'UsagePurpose"},
                "odrl:operator": {"@id": "odrl:isAnyOf"},
                "odrl:rightOperand": "cx.core.industrycore:1"
              }
            ]
          }
        }],
        "odrl:prohibition": [],
        "odrl:obligation": []
      }
    }') || fail "Negotiation initiation failed"

NEGOTIATION_ID=$(echo "${NEGOTIATION}" | jq -r '.["@id"]')
result "Negotiation ID: ${NEGOTIATION_ID}"
sep

step "6b. Poll negotiation status"
AGREEMENT_ID=""
for i in $(seq 1 30); do
    sleep 2
    NEG_STATUS=$(curl -sf "${CONSUMER_MGMT}/v3/contractnegotiations/${NEGOTIATION_ID}" \
        -H "x-api-key: ${API_KEY}") || continue
    STATE=$(echo "${NEG_STATUS}" | jq -r '.state')
    substep "Attempt ${i}: state = ${STATE}"

    if [ "${STATE}" = "FINALIZED" ]; then
        AGREEMENT_ID=$(echo "${NEG_STATUS}" | jq -r '.contractAgreementId')
        result "FINALIZED — Agreement ID: ${AGREEMENT_ID}"
        break
    elif [ "${STATE}" = "TERMINATED" ]; then
        ERROR=$(echo "${NEG_STATUS}" | jq -r '.errorDetail // "unknown"')
        fail "Negotiation TERMINATED: ${ERROR}"
    fi
done
if [ -z "${AGREEMENT_ID}" ]; then
    fail "Negotiation timed out (last state: ${STATE})"
fi

# ==========================================
# 7. CONTRACT AGREEMENT QUERY
# ==========================================
section "7. Contract Agreement Query"

step "7a. Get agreement by ID: ${AGREEMENT_ID}"
AGREEMENT=$(curl -sf "${CONSUMER_MGMT}/v3/contractagreements/${AGREEMENT_ID}" \
    -H "x-api-key: ${API_KEY}") || fail "Agreement fetch failed"
result "Agreement details:"
substep "Asset:     $(echo "${AGREEMENT}" | jq -r '.assetId')"
substep "Provider:  $(echo "${AGREEMENT}" | jq -r '.providerId')"
substep "Consumer:  $(echo "${AGREEMENT}" | jq -r '.consumerId')"
substep "Signed at: $(echo "${AGREEMENT}" | jq -r '.contractSigningDate')"
sep

step "7b. Query all agreements on consumer"
AGREEMENTS=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/contractagreements/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "offset": 0,
      "limit": 50
    }') || fail "Agreement query failed"
AGREEMENT_COUNT=$(echo "${AGREEMENTS}" | jq 'length')
result "Found ${AGREEMENT_COUNT} agreement(s) on consumer"
echo "${AGREEMENTS}" | jq -r '.[] | "      - \(.["@id"]) → asset: \(.assetId)"'

# ==========================================
# 8. TRANSFER PROCESS — HttpData-PULL
# ==========================================
section "8. Transfer Process — HttpData-PULL"

step "8a. Initiate transfer"
TRANSFER=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/transferprocesses" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "counterPartyAddress": "'"${PROVIDER_DSP}"'",
      "counterPartyId": "'"${PROVIDER_DID}"'",
      "protocol": "dataspace-protocol-http",
      "contractId": "'"${AGREEMENT_ID}"'",
      "assetId": "'"${ASSET_ID}"'",
      "transferType": "HttpData-PULL"
    }') || fail "Transfer initiation failed"

TRANSFER_ID=$(echo "${TRANSFER}" | jq -r '.["@id"]')
result "Transfer ID: ${TRANSFER_ID}"
sep

step "8b. Poll transfer status"
for i in $(seq 1 30); do
    sleep 2
    TP_STATUS=$(curl -sf "${CONSUMER_MGMT}/v3/transferprocesses/${TRANSFER_ID}" \
        -H "x-api-key: ${API_KEY}") || continue
    STATE=$(echo "${TP_STATUS}" | jq -r '.state')
    substep "Attempt ${i}: state = ${STATE}"

    if [ "${STATE}" = "STARTED" ]; then
        result "Transfer STARTED — EDR available"
        break
    elif [ "${STATE}" = "TERMINATED" ]; then
        ERROR=$(echo "${TP_STATUS}" | jq -r '.errorDetail // "unknown"')
        fail "Transfer TERMINATED: ${ERROR}"
    fi
done
if [ "${STATE}" != "STARTED" ]; then
    fail "Transfer timed out (last state: ${STATE})"
fi

# ==========================================
# 9. EDR RETRIEVAL & DATA PULL
# ==========================================
section "9. EDR Retrieval & Data Pull"

step "9a. Get EDR (Endpoint Data Reference)"
EDR=$(curl -sf "${CONSUMER_MGMT}/v3/edrs/${TRANSFER_ID}/dataaddress" \
    -H "x-api-key: ${API_KEY}") || fail "EDR retrieval failed"

ENDPOINT=$(echo "${EDR}" | jq -r '.endpoint')
AUTH_TOKEN=$(echo "${EDR}" | jq -r '.authorization')
REFRESH_EP=$(echo "${EDR}" | jq -r '.["tx-auth:refreshEndpoint"] // "none"')
EXPIRES_IN=$(echo "${EDR}" | jq -r '.["tx-auth:expiresIn"] // "unknown"')

result "EDR details:"
substep "Endpoint:     ${ENDPOINT}"
substep "Token:        ${AUTH_TOKEN:0:50}..."
substep "Refresh EP:   ${REFRESH_EP}"
substep "Expires in:   ${EXPIRES_IN}s"
sep

step "9b. Pull data from provider data plane"
# Rewrite Docker hostname → localhost for host access
HOST_ENDPOINT=$(echo "${ENDPOINT}" | sed 's|http://provider-dp:8081|http://localhost:19197|')
substep "Calling: ${HOST_ENDPOINT}"

DATA=$(curl -sf "${HOST_ENDPOINT}" -H "Authorization: ${AUTH_TOKEN}") || fail "Data pull failed"
result "Response:"
echo "${DATA}" | jq '.' 2>/dev/null | sed 's/^/      /' || echo "      ${DATA}"

# ==========================================
# 10. EDR CACHE QUERY
# ==========================================
section "10. EDR Cache Query"

step "10a. Query EDR cache by asset ID"
EDR_CACHE=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/edrs/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "filterExpression": [
        {"operandLeft": "assetId", "operator": "=", "operandRight": "'"${ASSET_ID}"'"}
      ]
    }') || fail "EDR cache query failed"
EDR_COUNT=$(echo "${EDR_CACHE}" | jq 'length')
result "Found ${EDR_COUNT} EDR(s) for asset '${ASSET_ID}'"
echo "${EDR_CACHE}" | jq -r '.[] | "      - transfer: \(.transferProcessId) | agreement: \(.agreementId)"'
sep

step "10b. Query EDR cache by agreement ID"
EDR_BY_AGR=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/edrs/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "filterExpression": [
        {"operandLeft": "agreementId", "operator": "=", "operandRight": "'"${AGREEMENT_ID}"'"}
      ]
    }') || fail "EDR cache query by agreement failed"
result "Found $(echo "${EDR_BY_AGR}" | jq 'length') EDR(s) for agreement '${AGREEMENT_ID}'"

# ==========================================
# 11. TRANSFER LIFECYCLE (suspend/terminate)
# ==========================================
section "11. Transfer Lifecycle Management"

step "11a. Query all transfer processes on consumer"
TRANSFERS=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/transferprocesses/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "offset": 0,
      "limit": 50
    }') || fail "Transfer query failed"
TP_COUNT=$(echo "${TRANSFERS}" | jq 'length')
result "Found ${TP_COUNT} transfer process(es)"
echo "${TRANSFERS}" | jq -r '.[] | "      - \(.["@id"]) | state: \(.state) | asset: \(.assetId)"'
sep

step "11b. Suspend the active transfer: ${TRANSFER_ID}"
SUSPEND_RESP=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/transferprocesses/${TRANSFER_ID}/suspend" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{}' 2>&1) && result "Suspend requested" || substep "(Suspend may not be supported for this transfer type)"

sleep 2
STATE=$(curl -sf "${CONSUMER_MGMT}/v3/transferprocesses/${TRANSFER_ID}" \
    -H "x-api-key: ${API_KEY}" | jq -r '.state') || STATE="unknown"
substep "Current state: ${STATE}"
sep

step "11c. Terminate the transfer: ${TRANSFER_ID}"
curl -sf -X POST "${CONSUMER_MGMT}/v3/transferprocesses/${TRANSFER_ID}/terminate" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "reason": "Demo completed"}' \
    > /dev/null 2>&1 && result "Terminate requested" || substep "(Already terminated or not terminable)"

sleep 2
STATE=$(curl -sf "${CONSUMER_MGMT}/v3/transferprocesses/${TRANSFER_ID}" \
    -H "x-api-key: ${API_KEY}" | jq -r '.state') || STATE="unknown"
substep "Final state: ${STATE}"

# ==========================================
# 12. CLEANUP (optional)
# ==========================================
if [ "${CLEANUP}" = true ] && [ "${SKIP_SETUP}" = false ]; then
    section "12. Cleanup"

    step "12a. Delete contract definition: ${DEMO_CONTRACT_DEF_ID}"
    curl -sf -X DELETE "${PROVIDER_MGMT}/v3/contractdefinitions/${DEMO_CONTRACT_DEF_ID}" \
        -H "x-api-key: ${API_KEY}" > /dev/null 2>&1 \
        && result "Deleted" || substep "Could not delete (may already be gone)"

    step "12b. Delete policies"
    for pid in "${DEMO_ACCESS_POLICY_ID}" "${DEMO_CONTRACT_POLICY_ID}"; do
        curl -sf -X DELETE "${PROVIDER_MGMT}/v3/policydefinitions/${pid}" \
            -H "x-api-key: ${API_KEY}" > /dev/null 2>&1 \
            && result "Deleted ${pid}" || substep "Could not delete ${pid}"
    done

    step "12c. Delete asset: ${DEMO_ASSET_ID}"
    curl -sf -X DELETE "${PROVIDER_MGMT}/v3/assets/${DEMO_ASSET_ID}" \
        -H "x-api-key: ${API_KEY}" > /dev/null 2>&1 \
        && result "Deleted" || substep "Could not delete (may have active agreements)"
fi

# ==========================================
# SUMMARY
# ==========================================
section "Demo Complete — Summary"

echo " APIs demonstrated:"
echo "   [✓] POST   /v3/assets                        — Create asset"
echo "   [✓] POST   /v3/assets/request                 — Query assets"
echo "   [✓] POST   /v3/policydefinitions              — Create policy"
echo "   [✓] POST   /v3/policydefinitions/request      — Query policies"
echo "   [✓] POST   /v3/contractdefinitions            — Create contract def"
echo "   [✓] POST   /v3/contractdefinitions/request    — Query contract defs"
echo "   [✓] POST   /v3/catalog/request                — Browse catalog"
echo "   [✓] POST   /v3/catalog/request (filtered)     — Filtered catalog"
echo "   [✓] POST   /v3/contractnegotiations           — Initiate negotiation"
echo "   [✓] GET    /v3/contractnegotiations/{id}      — Poll negotiation"
echo "   [✓] GET    /v3/contractagreements/{id}        — Get agreement"
echo "   [✓] POST   /v3/contractagreements/request     — Query agreements"
echo "   [✓] POST   /v3/transferprocesses              — Start transfer"
echo "   [✓] GET    /v3/transferprocesses/{id}         — Poll transfer"
echo "   [✓] POST   /v3/transferprocesses/request      — Query transfers"
echo "   [✓] POST   /v3/transferprocesses/{id}/suspend — Suspend transfer"
echo "   [✓] POST   /v3/transferprocesses/{id}/terminate — Terminate transfer"
echo "   [✓] GET    /v3/edrs/{id}/dataaddress          — Get EDR"
echo "   [✓] POST   /v3/edrs/request                   — Query EDR cache"
echo "   [✓] GET    <dataplane>/public/...             — Pull data via EDR"
echo ""
echo " Resources created:"
echo "   Asset:           ${DEMO_ASSET_ID}"
echo "   Access Policy:   ${DEMO_ACCESS_POLICY_ID}"
echo "   Contract Policy: ${DEMO_CONTRACT_POLICY_ID}"
echo "   Contract Def:    ${DEMO_CONTRACT_DEF_ID}"
echo "   Negotiation:     ${NEGOTIATION_ID}"
echo "   Agreement:       ${AGREEMENT_ID}"
echo "   Transfer:        ${TRANSFER_ID}"
echo ""
