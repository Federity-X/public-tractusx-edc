#!/bin/bash

# Test script for Tractus-X EDC endpoints
# This script tests the various API endpoints exposed by the EDC

echo "🧪 Testing Tractus-X EDC Endpoints"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local method=$3
    local headers=$4
    local body=$5
    
    echo -e "${BLUE}Testing: $name${NC}"
    echo "URL: $url"
    
    local curl_cmd="curl -s -w \"HTTP_STATUS:%{http_code}\" -X $method"
    
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    if [ -n "$body" ]; then
        curl_cmd="$curl_cmd -d '$body'"
    fi
    
    curl_cmd="$curl_cmd \"$url\""
    
    response=$(eval $curl_cmd)
    http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
    body_response=$(echo "$response" | sed -e 's/HTTP_STATUS:.*//g')
    
    if [ "$http_status" -eq 200 ] || [ "$http_status" -eq 204 ]; then
        echo -e "${GREEN}✅ Status: $http_status${NC}"
        if [ -n "$body_response" ] && [ "$body_response" != "null" ] && [ "$body_response" != "[]" ]; then
            echo "Response:" 
            echo "$body_response" | jq . 2>/dev/null || echo "$body_response"
        fi
    elif [ "$http_status" -eq 400 ] || [ "$http_status" -eq 401 ] || [ "$http_status" -eq 404 ]; then
        echo -e "${YELLOW}⚠️  Status: $http_status (Expected - endpoint exists but may need proper request)${NC}"
        if [ -n "$body_response" ]; then
            echo "Response: $body_response" | head -5
        fi
    else
        echo -e "${RED}❌ Status: $http_status${NC}"
        if [ -n "$body_response" ]; then
            echo "Error: $body_response" | head -3
        fi
    fi
    echo ""
}

# Standard QuerySpec for EDC API calls
QUERY_SPEC='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "QuerySpec"
}'

echo -e "${YELLOW}1. Testing Management API Endpoints${NC}"
echo "----------------------------------"

# Test Assets endpoint with proper request format
test_endpoint "Assets List" "http://localhost:8181/management/v3/assets/request" "POST" "-H 'X-Api-Key: password' -H 'Content-Type: application/json'" "$QUERY_SPEC"

# Test Policies endpoint
test_endpoint "Policies List" "http://localhost:8181/management/v3/policydefinitions/request" "POST" "-H 'X-Api-Key: password' -H 'Content-Type: application/json'" "$QUERY_SPEC"

# Test Contract Definitions
test_endpoint "Contract Definitions List" "http://localhost:8181/management/v3/contractdefinitions/request" "POST" "-H 'X-Api-Key: password' -H 'Content-Type: application/json'" "$QUERY_SPEC"

# Test Transfer Processes
test_endpoint "Transfer Processes List" "http://localhost:8181/management/v3/transferprocesses/request" "POST" "-H 'X-Api-Key: password' -H 'Content-Type: application/json'" "$QUERY_SPEC"

# Test EDRs
test_endpoint "EDRs List" "http://localhost:8181/management/v3/edrs/request" "POST" "-H 'X-Api-Key: password' -H 'Content-Type: application/json'" "$QUERY_SPEC"

echo -e "${YELLOW}2. Testing Protocol (DSP) Endpoints${NC}"
echo "---------------------------------"

# Catalog request format for DSP
CATALOG_REQUEST='{
  "@context": [
    "https://w3id.org/dspace/2024/1/context.json"
  ],
  "@type": "dspace:CatalogRequestMessage",
  "dspace:filter": {}
}'

# Test DSP Catalog endpoint 
test_endpoint "DSP Catalog Request" "http://localhost:8080/api/dsp/catalog/request" "POST" "-H 'Content-Type: application/json'" "$CATALOG_REQUEST"

# Test if we can reach the DSP root endpoint
test_endpoint "DSP Root" "http://localhost:8080/api/dsp" "GET" "" ""

echo -e "${YELLOW}3. Testing Data Plane Endpoints${NC}"
echo "------------------------------"

# Test Public API (Data Plane)
test_endpoint "Public API Root" "http://localhost:8081/public" "GET" "" ""

# Test the consumer proxy endpoint (will fail without proper EDRs but shows if endpoint exists)
ASSET_REQUEST='{
  "assetId": "test-asset",
  "providerId": "test-provider"
}'

test_endpoint "Consumer Data Plane Proxy" "http://localhost:8186/aas/request" "POST" "-H 'Content-Type: application/json'" "$ASSET_REQUEST"

echo ""
echo "🎯 Working Examples for Testing:"
echo "================================"
echo ""
echo -e "${GREEN}1. List all assets:${NC}"
echo "curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \\"
echo "  -d '$QUERY_SPEC' \\"
echo "  http://localhost:8181/management/v3/assets/request"
echo ""
echo -e "${GREEN}2. Create a new asset:${NC}"
echo 'curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \'
echo '  -d '"'"'{'
echo '    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},'
echo '    "@type": "Asset",'
echo '    "@id": "test-asset-1",'
echo '    "properties": {"name": "Test Asset", "description": "A test asset"},'
echo '    "dataAddress": {"@type": "DataAddress", "type": "HttpData", "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"}'
echo '  }'"'"' \'
echo '  http://localhost:8181/management/v3/assets'
echo ""
echo -e "${GREEN}3. Request catalog from another connector:${NC}"
echo "curl -X POST -H 'Content-Type: application/json' \\"
echo "  -d '$CATALOG_REQUEST' \\"
echo "  http://localhost:8080/api/dsp/catalog/request"
echo ""
echo -e "${GREEN}4. Test with a Data Plane request (after you have EDRs):${NC}"
echo "curl -X POST -H 'Content-Type: application/json' \\"
echo "  -d '$ASSET_REQUEST' \\"
echo "  http://localhost:8186/aas/request"
echo ""
echo "📚 For detailed API documentation, visit:"
echo "- Control Plane API: https://eclipse-tractusx.github.io/tractusx-edc/openapi/control-plane-api/"
echo "- Data Plane API: https://eclipse-tractusx.github.io/tractusx-edc/openapi/data-plane-api/"
