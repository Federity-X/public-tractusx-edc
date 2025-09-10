#!/bin/bash

# Systematic EDC API Testing Script
# Tests all API endpoints methodically with detailed logging

echo "🧪 Systematic EDC API Testing"
echo "=============================="
echo "$(date)"
echo ""

# Configuration
API_KEY="password"
MANAGEMENT_URL="http://localhost:8181/management"
PROTOCOL_URL="http://localhost:8080/api"
DATAPLANE_URL="http://localhost:8081"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test counter
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Function to log test results
log_test() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    local description="$4"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    echo -e "${BLUE}Test $TEST_COUNT: $test_name${NC}"
    echo "Description: $description"
    echo "Expected: $expected"
    echo "Actual: $actual"
    
    if [[ "$actual" == *"$expected"* ]] || [[ "$expected" == "any" && "$actual" != "" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}❌ FAIL${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
}

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local url="$3"
    local headers="$4"
    local body="$5"
    local expected_status="$6"
    local description="$7"
    
    echo -e "${PURPLE}Testing: $name${NC}"
    echo "URL: $url"
    echo "Method: $method"
    if [[ -n "$body" ]]; then
        echo "Body: $body"
    fi
    
    # Build curl command
    local curl_cmd="curl -s -w \"\\nHTTP_STATUS:%{http_code}\\nTIME:%{time_total}\" -X $method"
    
    if [[ -n "$headers" ]]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    if [[ -n "$body" ]]; then
        curl_cmd="$curl_cmd -d '$body'"
    fi
    
    curl_cmd="$curl_cmd \"$url\""
    
    echo "Command: $curl_cmd"
    echo ""
    
    # Execute and capture response
    local response=$(eval $curl_cmd 2>/dev/null)
    local http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    local time_taken=$(echo "$response" | grep "TIME:" | cut -d: -f2)
    local body_response=$(echo "$response" | sed '/HTTP_STATUS:/,$d')
    
    # Log results
    if [[ -n "$http_status" ]]; then
        log_test "$name" "$expected_status" "$http_status" "$description"
        
        # Show response body if interesting
        if [[ "$http_status" == "200" && -n "$body_response" && "$body_response" != "[]" ]]; then
            echo "Response Preview:"
            echo "$body_response" | head -5
            echo ""
        elif [[ "$http_status" != "200" && -n "$body_response" ]]; then
            echo "Error Response:"
            echo "$body_response" | head -3
            echo ""
        fi
        
        echo "Response Time: ${time_taken}s"
    else
        log_test "$name" "$expected_status" "CONNECTION_FAILED" "$description"
        echo "Error: Could not connect to endpoint"
    fi
    
    echo "----------------------------------------"
}

# Standard QuerySpec for listing operations
QUERY_SPEC='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "QuerySpec",
  "limit": 5
}'

echo -e "${YELLOW}📋 PHASE 1: BASIC CONNECTIVITY TESTS${NC}"
echo "Testing if EDC services are running and reachable"
echo ""

# Test 1: Management API Root (should fail - no root endpoint)
test_endpoint "Management API Root" "GET" "$MANAGEMENT_URL" "-H 'X-Api-Key: $API_KEY'" "" "404" "Verify management API is running"

# Test 2: Management API without Auth (should fail with 401)
test_endpoint "No Authentication" "POST" "$MANAGEMENT_URL/v3/assets/request" "-H 'Content-Type: application/json'" "$QUERY_SPEC" "401" "Verify authentication is required"

# Test 3: Protocol API Root
test_endpoint "Protocol API Root" "GET" "$PROTOCOL_URL" "" "" "any" "Check if protocol API is accessible"

# Test 4: Data Plane API Root  
test_endpoint "Data Plane API Root" "GET" "$DATAPLANE_URL" "" "" "any" "Check if data plane is accessible"

echo -e "${YELLOW}📋 PHASE 2: ASSET MANAGEMENT TESTS${NC}"
echo "Testing Asset CRUD operations"
echo ""

# Test 5: List Assets (Empty)
test_endpoint "List Assets (Empty)" "POST" "$MANAGEMENT_URL/v3/assets/request" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$QUERY_SPEC" "200" "List existing assets (should be empty initially)"

# Test 6: Create First Asset
ASSET_1_BODY='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "dct": "http://purl.org/dc/terms/"
  },
  "@type": "Asset",
  "@id": "test-asset-1",
  "properties": {
    "name": "Test Asset 1",
    "description": "First test asset for systematic testing",
    "dct:type": "test-data",
    "contenttype": "application/json"
  },
  "dataAddress": {
    "@type": "DataAddress",
    "type": "HttpData",
    "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
  }
}'

test_endpoint "Create Asset 1" "POST" "$MANAGEMENT_URL/v3/assets" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$ASSET_1_BODY" "200" "Create first test asset"

# Test 7: List Assets (Should show 1)
test_endpoint "List Assets (1 Expected)" "POST" "$MANAGEMENT_URL/v3/assets/request" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$QUERY_SPEC" "200" "Verify asset was created"

# Test 8: Get Specific Asset
test_endpoint "Get Asset by ID" "GET" "$MANAGEMENT_URL/v3/assets/test-asset-1" "-H 'X-Api-Key: $API_KEY'" "" "200" "Retrieve specific asset by ID"

# Test 9: Create Second Asset (Different type)
ASSET_2_BODY='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "Asset",
  "@id": "test-asset-2",
  "properties": {
    "name": "CSV Test Asset",
    "description": "CSV data asset for testing",
    "contenttype": "text/csv",
    "category": "sample-data"
  },
  "dataAddress": {
    "@type": "DataAddress",
    "type": "HttpData",
    "baseUrl": "https://people.sc.fsu.edu/~jburkardt/data/csv/cities.csv"
  }
}'

test_endpoint "Create Asset 2 (CSV)" "POST" "$MANAGEMENT_URL/v3/assets" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$ASSET_2_BODY" "200" "Create second asset with different content type"

# Test 10: Duplicate Asset ID (Should fail)
test_endpoint "Duplicate Asset ID" "POST" "$MANAGEMENT_URL/v3/assets" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$ASSET_1_BODY" "400" "Verify duplicate IDs are rejected"

echo -e "${YELLOW}📋 PHASE 3: POLICY MANAGEMENT TESTS${NC}"
echo "Testing Policy CRUD operations"
echo ""

# Test 11: List Policies (Empty)
test_endpoint "List Policies (Empty)" "POST" "$MANAGEMENT_URL/v3/policydefinitions/request" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$QUERY_SPEC" "200" "List existing policies"

# Test 12: Create Access Policy
ACCESS_POLICY_BODY='{
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
}'

test_endpoint "Create Access Policy" "POST" "$MANAGEMENT_URL/v3/policydefinitions" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$ACCESS_POLICY_BODY" "200" "Create open access policy"

# Test 13: Create Contract Policy
CONTRACT_POLICY_BODY='{
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
}'

test_endpoint "Create Contract Policy" "POST" "$MANAGEMENT_URL/v3/policydefinitions" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$CONTRACT_POLICY_BODY" "200" "Create contract policy"

# Test 14: Get Specific Policy
test_endpoint "Get Policy by ID" "GET" "$MANAGEMENT_URL/v3/policydefinitions/open-access-policy" "-H 'X-Api-Key: $API_KEY'" "" "200" "Retrieve specific policy by ID"

echo -e "${YELLOW}📋 PHASE 4: CONTRACT DEFINITION TESTS${NC}"
echo "Testing Contract Definition operations"
echo ""

# Test 15: List Contract Definitions (Empty)
test_endpoint "List Contract Definitions (Empty)" "POST" "$MANAGEMENT_URL/v3/contractdefinitions/request" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$QUERY_SPEC" "200" "List existing contract definitions"

# Test 16: Create Contract Definition
CONTRACT_DEF_BODY='{
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
}'

test_endpoint "Create Contract Definition" "POST" "$MANAGEMENT_URL/v3/contractdefinitions" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$CONTRACT_DEF_BODY" "200" "Create contract definition linking asset and policies"

echo -e "${YELLOW}📋 PHASE 5: CATALOG TESTS${NC}"
echo "Testing Catalog functionality"
echo ""

# Test 17: Request Own Catalog
CATALOG_REQUEST='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "CatalogRequest",
  "counterPartyAddress": "http://localhost:8080/api/dsp",
  "protocol": "dataspace-protocol-http"
}'

test_endpoint "Request Own Catalog" "POST" "$MANAGEMENT_URL/v3/catalog/request" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$CATALOG_REQUEST" "200" "Request catalog to see available data offers"

echo -e "${YELLOW}📋 PHASE 6: DSP PROTOCOL TESTS${NC}"
echo "Testing Dataspace Protocol endpoints"
echo ""

# Test 18: DSP Catalog Request
DSP_CATALOG_REQUEST='{
  "@context": [
    "https://w3id.org/dspace/2024/1/context.json"
  ],
  "@type": "dspace:CatalogRequestMessage",
  "dspace:filter": {}
}'

test_endpoint "DSP Catalog Request" "POST" "$PROTOCOL_URL/dsp/catalog/request" "-H 'Content-Type: application/json'" "$DSP_CATALOG_REQUEST" "200" "Test DSP catalog endpoint"

echo -e "${YELLOW}📋 PHASE 7: ERROR HANDLING TESTS${NC}"
echo "Testing various error conditions"
echo ""

# Test 19: Invalid JSON
test_endpoint "Invalid JSON" "POST" "$MANAGEMENT_URL/v3/assets/request" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "invalid-json" "400" "Test malformed JSON handling"

# Test 20: Missing Required Fields
INVALID_ASSET='{
  "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
  "@type": "Asset"
}'

test_endpoint "Missing Required Fields" "POST" "$MANAGEMENT_URL/v3/assets" "-H 'X-Api-Key: $API_KEY' -H 'Content-Type: application/json'" "$INVALID_ASSET" "400" "Test validation error handling"

# Test 21: Non-existent Resource
test_endpoint "Get Non-existent Asset" "GET" "$MANAGEMENT_URL/v3/assets/non-existent-id" "-H 'X-Api-Key: $API_KEY'" "" "404" "Test 404 handling for missing resources"

echo ""
echo "🏁 TEST SUMMARY"
echo "==============="
echo -e "Total Tests: ${BLUE}$TEST_COUNT${NC}"
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Your EDC is working correctly.${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests failed. Check the details above.${NC}"
fi

echo ""
echo "📋 Quick Status Check Commands:"
echo "curl -H 'X-Api-Key: password' -H 'Content-Type: application/json' -X POST -d '$QUERY_SPEC' '$MANAGEMENT_URL/v3/assets/request'"
echo "curl -H 'X-Api-Key: password' -H 'Content-Type: application/json' -X POST -d '$QUERY_SPEC' '$MANAGEMENT_URL/v3/policydefinitions/request'"
echo "curl -H 'X-Api-Key: password' -H 'Content-Type: application/json' -X POST -d '$QUERY_SPEC' '$MANAGEMENT_URL/v3/contractdefinitions/request'"
echo ""
echo "✅ Systematic testing complete!"
