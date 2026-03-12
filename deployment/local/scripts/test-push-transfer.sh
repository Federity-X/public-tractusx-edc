#!/bin/bash
set -e

# ============================================================
#  HttpData-PUSH Transfer Test
#  Provider pushes data to a webhook endpoint
# ============================================================

PROVIDER_MGMT="http://localhost:19193/management"
CONSUMER_MGMT="http://localhost:29193/management"
API_KEY="testkey"
PROVIDER_DSP="http://provider-cp:8084/api/v1/dsp"
PROVIDER_DID="did:web:provider-ih:provider"
PROVIDER_BPN="BPNL000000000001"
CX_NS="https://w3id.org/catenax/2025/9/policy/"
WEBHOOK="http://209.38.170.63:8084/83ef68c8-6cef-4f59-910d-627490b713f0"

PUSH_ASSET="push-test-asset-$(date +%s)"
PUSH_ACCESS_POL="push-access-pol-$(date +%s)"
PUSH_CONTRACT_POL="push-contract-pol-$(date +%s)"
PUSH_CONTRACT_DEF="push-contract-def-$(date +%s)"

echo "============================================"
echo "  HttpData-PUSH Transfer Test"
echo "  Webhook: $WEBHOOK"
echo "  Asset:   $PUSH_ASSET"
echo "============================================"
echo ""

# --- Step 1: Create Asset ---
echo "=== Step 1: Create Asset ==="
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROVIDER_MGMT/v3/assets" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
    "@id": "'"$PUSH_ASSET"'",
    "properties": {
      "name": "Push Transfer Test Asset",
      "description": "Asset for HttpData-PUSH to webhook"
    },
    "dataAddress": {
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/users",
      "proxyPath": "false",
      "proxyQueryParams": "false"
    }
  }')
echo "  HTTP $HTTP"
[ "$HTTP" = "200" ] || { echo "FAIL: Asset creation"; exit 1; }

# --- Step 2: Create Access Policy (unrestricted) ---
echo "=== Step 2: Create Access Policy (unrestricted) ==="
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROVIDER_MGMT/v3/policydefinitions" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/","odrl":"http://www.w3.org/ns/odrl/2/"},
    "@id": "'"$PUSH_ACCESS_POL"'",
    "policy": {
      "@type": "odrl:Set",
      "odrl:permission": [],
      "odrl:prohibition": [],
      "odrl:obligation": []
    }
  }')
echo "  HTTP $HTTP"
[ "$HTTP" = "200" ] || { echo "FAIL: Access policy creation"; exit 1; }

# --- Step 3: Create Contract Policy (FrameworkAgreement + UsagePurpose) ---
echo "=== Step 3: Create Contract Policy ==="
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROVIDER_MGMT/v3/policydefinitions" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab":"https://w3id.org/edc/v0.0.1/ns/",
      "odrl":"http://www.w3.org/ns/odrl/2/",
      "cx-policy":"'"$CX_NS"'"
    },
    "@id": "'"$PUSH_CONTRACT_POL"'",
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
  }')
echo "  HTTP $HTTP"
[ "$HTTP" = "200" ] || { echo "FAIL: Contract policy creation"; exit 1; }

# --- Step 4: Create Contract Definition ---
echo "=== Step 4: Create Contract Definition ==="
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROVIDER_MGMT/v3/contractdefinitions" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
    "@id": "'"$PUSH_CONTRACT_DEF"'",
    "accessPolicyId": "'"$PUSH_ACCESS_POL"'",
    "contractPolicyId": "'"$PUSH_CONTRACT_POL"'",
    "assetsSelector": [{"operandLeft":"https://w3id.org/edc/v0.0.1/ns/id","operator":"=","operandRight":"'"$PUSH_ASSET"'"}]
  }')
echo "  HTTP $HTTP"
[ "$HTTP" = "200" ] || { echo "FAIL: Contract definition creation"; exit 1; }

# --- Step 5: Browse Catalog ---
echo "=== Step 5: Browse Catalog ==="
CATALOG=$(curl -s -X POST "$CONSUMER_MGMT/v3/catalog/request" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
    "counterPartyAddress": "'"$PROVIDER_DSP"'",
    "counterPartyId": "'"$PROVIDER_DID"'",
    "protocol": "dataspace-protocol-http",
    "querySpec": {"filterExpression":[{"operandLeft":"https://w3id.org/edc/v0.0.1/ns/id","operator":"=","operandRight":"'"$PUSH_ASSET"'"}]}
  }')

# Handle both single dataset and array
DATASET=$(echo "$CATALOG" | jq '[.["dcat:dataset"]] | flatten | .[0]')
ASSET_ID=$(echo "$DATASET" | jq -r '.["@id"]')
OFFER=$(echo "$DATASET" | jq '[.["odrl:hasPolicy"]] | flatten | .[0]')
OFFER_ID=$(echo "$OFFER" | jq -r '.["@id"]')
echo "  Asset ID: $ASSET_ID"
echo "  Offer ID: $OFFER_ID"

if [ -z "$OFFER_ID" ] || [ "$OFFER_ID" = "null" ]; then
  echo "ERROR: No offer found in catalog!"
  echo "$CATALOG" | jq .
  exit 1
fi

# --- Step 6: Negotiate Contract ---
echo "=== Step 6: Negotiate Contract ==="
NEG_RESP=$(curl -s -X POST "$CONSUMER_MGMT/v3/contractnegotiations" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/","odrl":"http://www.w3.org/ns/odrl/2/"},
    "counterPartyAddress": "'"$PROVIDER_DSP"'",
    "counterPartyId": "'"$PROVIDER_DID"'",
    "protocol": "dataspace-protocol-http",
    "policy": {
      "@type": "odrl:Offer",
      "@id": "'"$OFFER_ID"'",
      "odrl:assigner": {"@id": "'"$PROVIDER_BPN"'"},
      "odrl:target": {"@id": "'"$ASSET_ID"'"},
      "odrl:permission": [{
        "odrl:action": {"@id": "odrl:use"},
        "odrl:constraint": {
          "odrl:and": [
            {
              "odrl:leftOperand": {"@id": "'"${CX_NS}"'FrameworkAgreement"},
              "odrl:operator": {"@id": "odrl:eq"},
              "odrl:rightOperand": "DataExchangeGovernance:1.0"
            },
            {
              "odrl:leftOperand": {"@id": "'"${CX_NS}"'UsagePurpose"},
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
NEG_ID=$(echo "$NEG_RESP" | jq -r '.["@id"]')
echo "  Negotiation ID: $NEG_ID"

if [ -z "$NEG_ID" ] || [ "$NEG_ID" = "null" ]; then
  echo "ERROR: Negotiation initiation failed!"
  echo "$NEG_RESP" | jq .
  exit 1
fi

# --- Step 7: Poll Negotiation ---
echo "=== Step 7: Poll Negotiation ==="
AGREEMENT_ID=""
for i in $(seq 1 30); do
  sleep 2
  RESP=$(curl -s "$CONSUMER_MGMT/v3/contractnegotiations/$NEG_ID" -H "x-api-key: $API_KEY")
  STATE=$(echo "$RESP" | jq -r '.state')
  echo "  Poll $i: $STATE"
  if [ "$STATE" = "FINALIZED" ]; then
    AGREEMENT_ID=$(echo "$RESP" | jq -r '.contractAgreementId')
    echo "  Agreement ID: $AGREEMENT_ID"
    break
  fi
  if [ "$STATE" = "TERMINATED" ]; then
    echo "ERROR: Negotiation TERMINATED!"
    echo "$RESP" | jq .
    exit 1
  fi
done

if [ -z "$AGREEMENT_ID" ] || [ "$AGREEMENT_ID" = "null" ]; then
  echo "ERROR: Agreement not obtained!"
  exit 1
fi

echo ""
echo "============================================"
echo "  CONTRACT AGREED: $AGREEMENT_ID"
echo "  Now initiating HttpData-PUSH transfer..."
echo "  Destination: $WEBHOOK"
echo "============================================"
echo ""

# --- Step 8: Initiate PUSH Transfer ---
echo "=== Step 8: Initiate PUSH Transfer ==="
TRANSFER_RESP=$(curl -s -X POST "$CONSUMER_MGMT/v3/transferprocesses" \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
    "counterPartyAddress": "'"$PROVIDER_DSP"'",
    "connectorId": "'"$PROVIDER_DID"'",
    "protocol": "dataspace-protocol-http",
    "contractId": "'"$AGREEMENT_ID"'",
    "assetId": "'"$ASSET_ID"'",
    "transferType": "HttpData-PUSH",
    "dataDestination": {
      "type": "HttpData",
      "baseUrl": "'"$WEBHOOK"'"
    }
  }')
TRANSFER_ID=$(echo "$TRANSFER_RESP" | jq -r '.["@id"]')
echo "  Transfer ID: $TRANSFER_ID"

if [ -z "$TRANSFER_ID" ] || [ "$TRANSFER_ID" = "null" ]; then
  echo "ERROR: Transfer initiation failed!"
  echo "$TRANSFER_RESP" | jq .
  exit 1
fi

# --- Step 9: Poll Transfer Status ---
echo "=== Step 9: Poll Transfer Status ==="
FINAL_STATE=""
for i in $(seq 1 30); do
  sleep 3
  TRESP=$(curl -s "$CONSUMER_MGMT/v3/transferprocesses/$TRANSFER_ID" -H "x-api-key: $API_KEY")
  TSTATE=$(echo "$TRESP" | jq -r '.state')
  echo "  Poll $i: $TSTATE"
  if [ "$TSTATE" = "STARTED" ] || [ "$TSTATE" = "COMPLETED" ]; then
    FINAL_STATE="$TSTATE"
    break
  fi
  if [ "$TSTATE" = "TERMINATED" ]; then
    echo "ERROR: Transfer TERMINATED!"
    echo "$TRESP" | jq .
    exit 1
  fi
done

echo ""
if [ -n "$FINAL_STATE" ]; then
  echo "============================================"
  echo "  PUSH TRANSFER SUCCESSFUL!"
  echo "  State: $FINAL_STATE"
  echo ""
  echo "  The provider data plane pushed data to:"
  echo "  $WEBHOOK"
  echo ""
  echo "  Check your webhook site to see the data:"
  echo "  http://209.38.170.63:8084/#!/83ef68c8-6cef-4f59-910d-627490b713f0"
  echo "============================================"
else
  echo "WARNING: Transfer did not reach STARTED/COMPLETED after 30 polls"
  curl -s "$CONSUMER_MGMT/v3/transferprocesses/$TRANSFER_ID" -H "x-api-key: $API_KEY" | jq .
fi
