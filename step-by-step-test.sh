#!/bin/bash

# Step-by-Step EDC API Testing
# Test endpoints one by one with clear output

echo "🧪 Step-by-Step EDC API Testing"
echo "==============================="
echo ""

# Configuration
API_KEY="password"
MANAGEMENT_URL="http://localhost:8181/management"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue to next test...${NC}"
    read
}

# Function to test single endpoint
test_single() {
    local step="$1"
    local description="$2"
    local curl_command="$3"
    
    echo -e "${BLUE}===== STEP $step =====>${NC}"
    echo -e "${BLUE}$description${NC}"
    echo ""
    echo "Command to execute:"
    echo "$curl_command"
    echo ""
    echo "Executing..."
    
    # Execute the command and show results
    eval "$curl_command"
    local exit_code=$?
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Command executed successfully${NC}"
    else
        echo -e "${RED}❌ Command failed with exit code: $exit_code${NC}"
    fi
    echo ""
    wait_for_user
}

echo "Starting systematic API testing..."
echo "Each test will be executed step by step."
echo ""
wait_for_user

# Standard QuerySpec
QUERY_SPEC='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'

# Step 1: Basic Connectivity
test_single "1" "Test basic Management API connectivity (should return empty array [])" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'"'"' \
  "http://localhost:8181/management/v3/assets/request"'

# Step 2: List Policies  
test_single "2" "List existing policies (should return empty array [])" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'"'"' \
  "http://localhost:8181/management/v3/policydefinitions/request"'

# Step 3: List Contract Definitions
test_single "3" "List existing contract definitions (should return empty array [])" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'"'"' \
  "http://localhost:8181/management/v3/contractdefinitions/request"'

# Step 4: Create First Asset
test_single "4" "Create first test asset (should return IdResponse with createdAt timestamp)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "dct": "http://purl.org/dc/terms/"
    },
    "@type": "Asset",
    "@id": "test-asset-1",
    "properties": {
      "name": "Test Asset 1",
      "description": "First systematic test asset",
      "dct:type": "test-data",
      "contenttype": "application/json"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
    }
  }'"'"' \
  "http://localhost:8181/management/v3/assets"'

# Step 5: Verify Asset Creation
test_single "5" "Verify asset was created (should show 1 asset in array)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'"'"' \
  "http://localhost:8181/management/v3/assets/request"'

# Step 6: Get Specific Asset
test_single "6" "Get specific asset by ID (should return full asset object)" \
'curl -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/assets/test-asset-1"'

# Step 7: Create Access Policy
test_single "7" "Create access policy (should return IdResponse)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "odrl": "http://www.w3.org/ns/odrl/2/"
    },
    "@type": "PolicyDefinition",
    "@id": "open-access-policy",
    "policy": {
      "@type": "odrl:Set",
      "odrl:permission": [{
        "odrl:action": {
          "odrl:type": "http://www.w3.org/ns/odrl/2/use"
        }
      }]
    }
  }'"'"' \
  "http://localhost:8181/management/v3/policydefinitions"'

# Step 8: Create Contract Policy
test_single "8" "Create contract policy (should return IdResponse)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "odrl": "http://www.w3.org/ns/odrl/2/"
    },
    "@type": "PolicyDefinition",
    "@id": "simple-contract-policy",
    "policy": {
      "@type": "odrl:Set",
      "odrl:permission": [{
        "odrl:action": {
          "odrl:type": "http://www.w3.org/ns/odrl/2/use"
        }
      }]
    }
  }'"'"' \
  "http://localhost:8181/management/v3/policydefinitions"'

# Step 9: Verify Policies Created
test_single "9" "Verify policies were created (should show 2 policies)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'"'"' \
  "http://localhost:8181/management/v3/policydefinitions/request"'

# Step 10: Create Contract Definition
test_single "10" "Create contract definition linking asset and policies (should return IdResponse)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "ContractDefinition",
    "@id": "test-contract-def-1",
    "accessPolicyId": "open-access-policy",
    "contractPolicyId": "simple-contract-policy",
    "assetsSelector": [{
      "@type": "Criterion",
      "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
      "operator": "=",
      "operandRight": "test-asset-1"
    }]
  }'"'"' \
  "http://localhost:8181/management/v3/contractdefinitions"'

# Step 11: Verify Contract Definition
test_single "11" "Verify contract definition was created (should show 1 contract definition)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}'"'"' \
  "http://localhost:8181/management/v3/contractdefinitions/request"'

# Step 12: Request Own Catalog
test_single "12" "Request own catalog to see data offers (should show catalog with dataset)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "CatalogRequest",
    "counterPartyAddress": "http://localhost:8080/api/dsp",
    "protocol": "dataspace-protocol-http"
  }'"'"' \
  "http://localhost:8181/management/v3/catalog/request"'

# Step 13: Test DSP Catalog Endpoint
test_single "13" "Test DSP catalog endpoint (inter-connector communication)" \
'curl -X POST -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": [
      "https://w3id.org/dspace/2024/1/context.json"
    ],
    "@type": "dspace:CatalogRequestMessage",
    "dspace:filter": {}
  }'"'"' \
  "http://localhost:8080/api/dsp/catalog/request"'

# Step 14: Test Error Handling - No API Key
test_single "14" "Test error handling - missing API key (should return 401 Unauthorized)" \
'curl -X POST -H "Content-Type: application/json" \
  -d '"'"'{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}'"'"' \
  "http://localhost:8181/management/v3/assets/request"'

# Step 15: Test Error Handling - Duplicate Asset
test_single "15" "Test error handling - duplicate asset ID (should return 400 Bad Request)" \
'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '"'"'{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "test-asset-1",
    "properties": {"name": "Duplicate Asset"},
    "dataAddress": {"@type": "DataAddress", "type": "HttpData", "baseUrl": "http://example.com"}
  }'"'"' \
  "http://localhost:8181/management/v3/assets"'

echo -e "${GREEN}🎉 Systematic testing complete!${NC}"
echo ""
echo "Summary of what we tested:"
echo "✅ Basic API connectivity"
echo "✅ Asset creation and retrieval"  
echo "✅ Policy creation and management"
echo "✅ Contract definition linking"
echo "✅ Catalog functionality"
echo "✅ DSP protocol endpoints"
echo "✅ Error handling scenarios"
echo ""
echo "Your EDC appears to be working correctly if all steps succeeded!"
