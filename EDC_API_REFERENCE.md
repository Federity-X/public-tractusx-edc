# Tractus-X EDC API Reference - Complete Curl Commands

This document provides comprehensive curl commands for all available EDC API endpoints.

## 🚀 Configuration

```bash
# API Configuration
API_KEY="password"
MANAGEMENT_URL="http://localhost:8181/management"
PROTOCOL_URL="http://localhost:8080/api"
DATAPLANE_URL="http://localhost:8081"
```

## 📋 MANAGEMENT API ENDPOINTS (Port 8181)

All Management API calls require the `X-Api-Key: password` header.

### 1. Asset Management

#### List All Assets

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "QuerySpec",
    "limit": 50
  }' \
  "http://localhost:8181/management/v3/assets/request"
```

#### Create New Asset

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "dct": "http://purl.org/dc/terms/"
    },
    "@type": "Asset",
    "@id": "my-asset-id",
    "properties": {
      "name": "My Test Asset",
      "description": "A sample asset for testing",
      "dct:type": {"@id": "cx-taxo:ReadAccessOnly"},
      "contenttype": "application/json"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/posts"
    }
  }' \
  "http://localhost:8181/management/v3/assets"
```

#### Get Specific Asset

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/assets/{asset-id}"
```

#### Update Asset

```bash
curl -X PUT \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "Asset",
    "@id": "{asset-id}",
    "properties": {
      "name": "Updated Asset Name",
      "description": "Updated description"
    }
  }' \
  "http://localhost:8181/management/v3/assets/{asset-id}"
```

#### Delete Asset

```bash
curl -X DELETE \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/assets/{asset-id}"
```

### 2. Policy Management

#### List All Policy Definitions

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "QuerySpec",
    "limit": 50
  }' \
  "http://localhost:8181/management/v3/policydefinitions/request"
```

#### Create New Policy Definition

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "odrl": "http://www.w3.org/ns/odrl/2/"
    },
    "@type": "PolicyDefinition",
    "@id": "my-policy-id",
    "policy": {
      "@type": "odrl:Set",
      "odrl:permission": [{
        "odrl:action": {
          "odrl:type": "http://www.w3.org/ns/odrl/2/use"
        },
        "odrl:constraint": [{
          "odrl:leftOperand": "BusinessPartnerNumber",
          "odrl:operator": "odrl:eq",
          "odrl:rightOperand": "BPNL000000000000"
        }]
      }]
    }
  }' \
  "http://localhost:8181/management/v3/policydefinitions"
```

#### Get Specific Policy Definition

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/policydefinitions/{policy-id}"
```

#### Update Policy Definition

```bash
curl -X PUT \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "odrl": "http://www.w3.org/ns/odrl/2/"
    },
    "@type": "PolicyDefinition",
    "@id": "{policy-id}",
    "policy": {
      "@type": "odrl:Set",
      "odrl:permission": [{
        "odrl:action": {
          "odrl:type": "http://www.w3.org/ns/odrl/2/use"
        }
      }]
    }
  }' \
  "http://localhost:8181/management/v3/policydefinitions/{policy-id}"
```

#### Delete Policy Definition

```bash
curl -X DELETE \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/policydefinitions/{policy-id}"
```

### 3. Contract Definition Management

#### List All Contract Definitions

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "QuerySpec",
    "limit": 50
  }' \
  "http://localhost:8181/management/v3/contractdefinitions/request"
```

#### Create New Contract Definition

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "ContractDefinition",
    "@id": "my-contract-def-id",
    "accessPolicyId": "access-policy-id",
    "contractPolicyId": "contract-policy-id",
    "assetsSelector": [{
      "@type": "Criterion",
      "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
      "operator": "=",
      "operandRight": "asset-id"
    }]
  }' \
  "http://localhost:8181/management/v3/contractdefinitions"
```

#### Get Specific Contract Definition

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/contractdefinitions/{contract-def-id}"
```

#### Update Contract Definition

```bash
curl -X PUT \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "ContractDefinition",
    "@id": "{contract-def-id}",
    "accessPolicyId": "updated-access-policy-id",
    "contractPolicyId": "updated-contract-policy-id"
  }' \
  "http://localhost:8181/management/v3/contractdefinitions/{contract-def-id}"
```

#### Delete Contract Definition

```bash
curl -X DELETE \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/contractdefinitions/{contract-def-id}"
```

### 4. Contract Negotiation Management

#### List All Contract Negotiations

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "QuerySpec",
    "limit": 50
  }' \
  "http://localhost:8181/management/v3/contractnegotiations/request"
```

#### Initiate Contract Negotiation

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "ContractRequest",
    "counterPartyAddress": "http://provider-connector:8080/api/dsp",
    "protocol": "dataspace-protocol-http",
    "policy": {
      "@id": "offer-id",
      "@type": "Offer",
      "assigner": "provider-bpn",
      "target": "asset-id",
      "permission": [{
        "action": "use",
        "constraint": []
      }]
    }
  }' \
  "http://localhost:8181/management/v3/contractnegotiations"
```

#### Get Contract Negotiation Details

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/contractnegotiations/{negotiation-id}"
```

#### Terminate Contract Negotiation

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "TerminateNegotiation",
    "reason": "Cancelled by user"
  }' \
  "http://localhost:8181/management/v3/contractnegotiations/{negotiation-id}/terminate"
```

### 5. Transfer Process Management

#### List All Transfer Processes

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "QuerySpec",
    "limit": 50
  }' \
  "http://localhost:8181/management/v3/transferprocesses/request"
```

#### Initiate Data Transfer

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "TransferRequest",
    "counterPartyAddress": "http://provider-connector:8080/api/dsp",
    "contractId": "contract-agreement-id",
    "assetId": "asset-id",
    "protocol": "dataspace-protocol-http",
    "dataDestination": {
      "@type": "DataAddress",
      "type": "HttpProxy"
    }
  }' \
  "http://localhost:8181/management/v3/transferprocesses"
```

#### Get Transfer Process Details

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/transferprocesses/{transfer-id}"
```

#### Terminate Transfer Process

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "TerminateTransfer",
    "reason": "Transfer cancelled by user"
  }' \
  "http://localhost:8181/management/v3/transferprocesses/{transfer-id}/terminate"
```

### 6. EDR (Endpoint Data Reference) Management

#### List All EDR Entries

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "QuerySpec",
    "limit": 50
  }' \
  "http://localhost:8181/management/v3/edrs/request"
```

#### Get EDR for Transfer Process

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/edrs/{transfer-process-id}"
```

#### Delete EDR Entry

```bash
curl -X DELETE \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/edrs/{transfer-process-id}"
```

### 7. Catalog Management

#### Request External Catalog

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "CatalogRequest",
    "counterPartyAddress": "http://provider-connector:8080/api/dsp",
    "protocol": "dataspace-protocol-http",
    "querySpec": {
      "@type": "QuerySpec",
      "limit": 50
    }
  }' \
  "http://localhost:8181/management/v3/catalog/request"
```

### 8. Business Partner Groups (Tractus-X Extension)

#### List Business Partner Groups

```bash
curl -X GET \
  -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/business-partner-groups"
```

#### Create Business Partner Group

```bash
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{
    "businessPartnerNumber": "BPNL1234567890AB",
    "groups": ["supplier", "tier1"]
  }' \
  "http://localhost:8181/management/v3/business-partner-groups"
```

## 🌐 PROTOCOL API ENDPOINTS (Port 8080)

These endpoints are for inter-connector communication using the Dataspace Protocol (DSP).

### 9. DSP Catalog Request

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "@context": [
      "https://w3id.org/dspace/2024/1/context.json"
    ],
    "@type": "dspace:CatalogRequestMessage",
    "dspace:filter": {},
    "counterPartyAddress": "http://localhost:8080/api/dsp"
  }' \
  "http://localhost:8080/api/dsp/catalog/request"
```

### 10. DSP Contract Negotiation

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "@context": [
      "https://w3id.org/dspace/2024/1/context.json"
    ],
    "@type": "dspace:ContractRequestMessage",
    "dspace:processId": "negotiation-process-id",
    "dspace:offer": {
      "@type": "dspace:Offer",
      "dspace:offerId": "offer-id",
      "dspace:assetId": "asset-id"
    }
  }' \
  "http://localhost:8080/api/dsp/negotiations/{process-id}/request"
```

## 🔄 DATA PLANE API ENDPOINTS (Port 8081)

Data Plane endpoints require EDR tokens for authentication.

### 11. Access Data via Data Plane

```bash
# First, get EDR token from a successful transfer process
curl -X GET \
  -H "Authorization: Bearer {edr-token}" \
  -H "Accept: application/json" \
  "http://localhost:8081/public/{data-path}"
```

### 12. Send Data via Data Plane

```bash
curl -X POST \
  -H "Authorization: Bearer {edr-token}" \
  -H "Content-Type: application/json" \
  -d '{
    "data": "your data payload"
  }' \
  "http://localhost:8081/public/{data-path}"
```

## 🔧 Testing with Demo Data

### Test Complete Flow

```bash
# 1. Create Asset
ASSET_ID="test-asset-$(date +%s)"
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d "{
    \"@context\": {
      \"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\"
    },
    \"@type\": \"Asset\",
    \"@id\": \"$ASSET_ID\",
    \"properties\": {
      \"name\": \"Test Asset\",
      \"description\": \"Asset for API testing\"
    },
    \"dataAddress\": {
      \"@type\": \"DataAddress\",
      \"type\": \"HttpData\",
      \"baseUrl\": \"https://jsonplaceholder.typicode.com/posts\"
    }
  }" \
  "http://localhost:8181/management/v3/assets"

# 2. Create Policy
POLICY_ID="test-policy-$(date +%s)"
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d "{
    \"@context\": {
      \"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\",
      \"odrl\": \"http://www.w3.org/ns/odrl/2/\"
    },
    \"@type\": \"PolicyDefinition\",
    \"@id\": \"$POLICY_ID\",
    \"policy\": {
      \"@type\": \"odrl:Set\",
      \"odrl:permission\": [{
        \"odrl:action\": {
          \"odrl:type\": \"http://www.w3.org/ns/odrl/2/use\"
        }
      }]
    }
  }" \
  "http://localhost:8181/management/v3/policydefinitions"

# 3. Create Contract Definition
CONTRACT_DEF_ID="test-contract-def-$(date +%s)"
curl -X POST \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d "{
    \"@context\": {
      \"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\"
    },
    \"@type\": \"ContractDefinition\",
    \"@id\": \"$CONTRACT_DEF_ID\",
    \"accessPolicyId\": \"$POLICY_ID\",
    \"contractPolicyId\": \"$POLICY_ID\",
    \"assetsSelector\": [{
      \"@type\": \"Criterion\",
      \"operandLeft\": \"https://w3id.org/edc/v0.0.1/ns/id\",
      \"operator\": \"=\",
      \"operandRight\": \"$ASSET_ID\"
    }]
  }" \
  "http://localhost:8181/management/v3/contractdefinitions"

# 4. Verify Resources Created
echo "Verifying Asset: $ASSET_ID"
curl -X GET -H "X-Api-Key: password" "http://localhost:8181/management/v3/assets/$ASSET_ID"

echo "Verifying Policy: $POLICY_ID"
curl -X GET -H "X-Api-Key: password" "http://localhost:8181/management/v3/policydefinitions/$POLICY_ID"

echo "Verifying Contract Definition: $CONTRACT_DEF_ID"
curl -X GET -H "X-Api-Key: password" "http://localhost:8181/management/v3/contractdefinitions/$CONTRACT_DEF_ID"
```

## 📝 Important Notes

1. **Authentication**: All Management API calls require `X-Api-Key: password` header
2. **Data Plane Access**: Requires EDR tokens obtained through successful transfer processes
3. **JSON-LD Context**: Always include proper `@context` for semantic compatibility
4. **URL Placeholders**: Replace `{asset-id}`, `{policy-id}`, etc. with actual resource IDs
5. **Protocol**: DSP endpoints are for connector-to-connector communication
6. **Business Partner Numbers**: Use valid BPN format (BPNL followed by 12 characters)
7. **Asset Types**: Use Catena-X taxonomy types like `cx-taxo:ReadAccessOnly`

## 🚀 Quick Start Commands

```bash
# Check EDC is running
curl -H "X-Api-Key: password" "http://localhost:8181/management/v3/assets/request" -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":1}' -H "Content-Type: application/json" -X POST

# List all resources quickly
echo "=== ASSETS ==="
curl -s -H "X-Api-Key: password" -H "Content-Type: application/json" -X POST -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":10}' "http://localhost:8181/management/v3/assets/request" | jq .

echo "=== POLICIES ==="
curl -s -H "X-Api-Key: password" -H "Content-Type: application/json" -X POST -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":10}' "http://localhost:8181/management/v3/policydefinitions/request" | jq .

echo "=== CONTRACT DEFINITIONS ==="
curl -s -H "X-Api-Key: password" -H "Content-Type: application/json" -X POST -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":10}' "http://localhost:8181/management/v3/contractdefinitions/request" | jq .
```

This reference covers all major EDC API endpoints with complete, working curl commands. Use it as your go-to guide for EDC API interactions!
