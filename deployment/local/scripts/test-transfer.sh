#!/usr/bin/env bash
#
# End-to-end test: Catalog → Negotiate → Transfer → Pull Data
#
# Prerequisites:
#   - All services running (IH stack + EDC stack + connectors)
#   - Bootstrap completed (bootstrap.sh)
#   - Asset, policies, and contract definitions already created (bootstrap Step 13)
#
# Usage:
#   ./test-transfer.sh
#
set -euo pipefail

# ========================================
# Configuration
# ========================================
CONSUMER_MGMT="http://localhost:29193/management"
API_KEY="testkey"
PROVIDER_DID="did:web:provider-ih:provider"
PROVIDER_BPN="BPNL000000000001"
PROVIDER_DSP="http://provider-cp:8084/api/v1/dsp"

echo ""
echo "================================================================="
echo " EDC Local DCP — End-to-End Transfer Test"
echo "================================================================="
echo ""

# ========================================
# Step 1: Health checks
# ========================================
echo "Step 1: Health checks..."
HEALTH_OK=true
for svc in "provider-cp:http://localhost:19191/api/check/health" \
           "provider-dp:http://localhost:19196/api/check/health" \
           "consumer-cp:http://localhost:29191/api/check/health" \
           "consumer-dp:http://localhost:29196/api/check/health"; do
    name="${svc%%:*}"
    url="${svc#*:}"
    if curl -sf "${url}" > /dev/null 2>&1; then
        echo "  ${name}: OK"
    else
        echo "  ${name}: FAILED"
        HEALTH_OK=false
    fi
done
if [ "${HEALTH_OK}" = false ]; then
    echo "  ERROR: Not all services healthy. Aborting."
    exit 1
fi
echo ""

# ========================================
# Step 2: Request catalog
# ========================================
echo "Step 2: Requesting catalog..."

CATALOG=$(curl -sf -X POST "${CONSUMER_MGMT}/v3/catalog/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
      "counterPartyAddress": "'"${PROVIDER_DSP}"'",
      "counterPartyId": "'"${PROVIDER_DID}"'",
      "protocol": "dataspace-protocol-http"
    }')

if ! echo "${CATALOG}" | jq -e '.["dcat:dataset"]' > /dev/null 2>&1; then
    echo "  FAIL: No datasets in catalog."
    echo "  Response: $(echo "${CATALOG}" | head -c 500)"
    exit 1
fi

OFFER_ID=$(echo "${CATALOG}" | jq -r '.["dcat:dataset"]["odrl:hasPolicy"]["@id"]')
ASSET_ID=$(echo "${CATALOG}" | jq -r '.["dcat:dataset"]["@id"]')
echo "  OK — Asset: ${ASSET_ID}, Offer: ${OFFER_ID}"
echo ""

# ========================================
# Step 3: Negotiate contract
# ========================================
echo "Step 3: Negotiating contract..."

# IMPORTANT: The negotiation policy must match the catalog offer exactly:
#   - odrl:action must use {"@id": "odrl:use"} (expands to full IRI)
#   - odrl:leftOperand must use full IRIs (not compact cx-policy:... form)
#   - odrl:assigner must be the provider's BPN (not DID)
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
                "odrl:leftOperand": {"@id": "https://w3id.org/catenax/2025/9/policy/FrameworkAgreement"},
                "odrl:operator": {"@id": "odrl:eq"},
                "odrl:rightOperand": "DataExchangeGovernance:1.0"
              },
              {
                "odrl:leftOperand": {"@id": "https://w3id.org/catenax/2025/9/policy/UsagePurpose"},
                "odrl:operator": {"@id": "odrl:isAnyOf"},
                "odrl:rightOperand": "cx.core.industrycore:1"
              }
            ]
          }
        }],
        "odrl:prohibition": [],
        "odrl:obligation": []
      }
    }')

NEGOTIATION_ID=$(echo "${NEGOTIATION}" | jq -r '.["@id"]')
if [ -z "${NEGOTIATION_ID}" ] || [ "${NEGOTIATION_ID}" = "null" ]; then
    echo "  FAIL: Could not start negotiation."
    echo "  Response: ${NEGOTIATION}"
    exit 1
fi
echo "  Negotiation ID: ${NEGOTIATION_ID}"

echo -n "  Waiting for finalization"
AGREEMENT_ID=""
for i in $(seq 1 30); do
    sleep 2
    echo -n "."
    STATE=$(curl -sf "${CONSUMER_MGMT}/v3/contractnegotiations/${NEGOTIATION_ID}" \
        -H "x-api-key: ${API_KEY}" | jq -r '.state') || STATE=""
    if [ "${STATE}" = "FINALIZED" ]; then
        AGREEMENT_ID=$(curl -sf "${CONSUMER_MGMT}/v3/contractnegotiations/${NEGOTIATION_ID}" \
            -H "x-api-key: ${API_KEY}" | jq -r '.contractAgreementId')
        echo " FINALIZED"
        echo "  Agreement: ${AGREEMENT_ID}"
        break
    elif [ "${STATE}" = "TERMINATED" ]; then
        ERROR=$(curl -sf "${CONSUMER_MGMT}/v3/contractnegotiations/${NEGOTIATION_ID}" \
            -H "x-api-key: ${API_KEY}" | jq -r '.errorDetail // "unknown"')
        echo " FAILED"
        echo "  Error: ${ERROR}"
        exit 1
    fi
done
if [ -z "${AGREEMENT_ID}" ]; then
    echo " TIMEOUT (state: ${STATE})"
    exit 1
fi
echo ""

# ========================================
# Step 4: Start transfer
# ========================================
echo "Step 4: Starting HttpData-PULL transfer..."

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
    }')

TRANSFER_ID=$(echo "${TRANSFER}" | jq -r '.["@id"]')
if [ -z "${TRANSFER_ID}" ] || [ "${TRANSFER_ID}" = "null" ]; then
    echo "  FAIL: Could not start transfer."
    exit 1
fi
echo "  Transfer ID: ${TRANSFER_ID}"

echo -n "  Waiting for EDR"
for i in $(seq 1 30); do
    sleep 2
    echo -n "."
    STATE=$(curl -sf "${CONSUMER_MGMT}/v3/transferprocesses/${TRANSFER_ID}" \
        -H "x-api-key: ${API_KEY}" | jq -r '.state') || STATE=""
    if [ "${STATE}" = "STARTED" ]; then
        echo " STARTED"
        break
    elif [ "${STATE}" = "TERMINATED" ]; then
        echo " FAILED"
        exit 1
    fi
done
if [ "${STATE}" != "STARTED" ]; then
    echo " TIMEOUT (state: ${STATE})"
    exit 1
fi
echo ""

# ========================================
# Step 5: Pull data via EDR
# ========================================
echo "Step 5: Pulling data..."

EDR=$(curl -sf "${CONSUMER_MGMT}/v3/edrs/${TRANSFER_ID}/dataaddress" \
    -H "x-api-key: ${API_KEY}")

ENDPOINT=$(echo "${EDR}" | jq -r '.endpoint')
AUTH_TOKEN=$(echo "${EDR}" | jq -r '.authorization')

# Replace Docker hostname with localhost mapped port
HOST_ENDPOINT=$(echo "${ENDPOINT}" | sed 's|http://provider-dp:8081|http://localhost:19197|')

DATA=$(curl -sf "${HOST_ENDPOINT}" -H "Authorization: ${AUTH_TOKEN}") || {
    echo "  FAIL: Data pull failed."
    exit 1
}

echo "  Response: ${DATA}"
echo ""
echo "================================================================="
echo " E2E TEST PASSED"
echo "================================================================="
echo ""
echo " Results:"
echo "   [OK] Catalog request"
echo "   [OK] Contract negotiation → ${AGREEMENT_ID}"
echo "   [OK] Data transfer → ${TRANSFER_ID}"
echo "   [OK] Data pull → $(echo "${DATA}" | head -c 80)"
echo ""
