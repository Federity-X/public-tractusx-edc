#!/bin/bash

# Comprehensive EDC API Examples
# This script demonstrates how to create and manage resources in Tractus-X EDC

set -e

API_KEY="password"  # DEV-ONLY: This is a development credential, not for production
MANAGEMENT_URL="http://localhost:8181/management"
PROTOCOL_URL="http://localhost:8080/api"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Comprehensive EDC API Demo${NC}"
echo "=============================="
echo ""

# Helper function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${YELLOW}$description${NC}"
    echo "API: $method $endpoint"
    
    if [ -n "$data" ]; then
        echo "Body: $data"
        response=$(curl -s -X $method -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" -d "$data" "$endpoint")
    else
        response=$(curl -s -X $method -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" "$endpoint")
    fi
    
    echo "Response:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
}

# Standard QuerySpec for listing resources
QUERY_SPEC='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "QuerySpec"
}'

echo -e "${GREEN}1. Working with Assets${NC}"
echo "====================="

# Create an Asset
ASSET_DATA='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "dct": "http://purl.org/dc/terms/"
  },
  "@type": "Asset",
  "@id": "demo-asset-1",
  "properties": {
    "dct:type": "demo-data",
    "name": "Demo Asset",
    "description": "A demo asset for testing",
    "version": "1.0"
  },
  "dataAddress": {
    "@type": "DataAddress",
    "type": "HttpData",
    "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
  }
}'

api_call "POST" "$MANAGEMENT_URL/v3/assets" "$ASSET_DATA" "Creating an asset"

# List Assets
api_call "POST" "$MANAGEMENT_URL/v3/assets/request" "$QUERY_SPEC" "Listing all assets"

echo -e "${GREEN}2. Working with Policies${NC}"
echo "======================"

# Create an Access Policy (allowing access to anyone)
ACCESS_POLICY='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@type": "PolicyDefinition",
  "@id": "demo-access-policy",
  "policy": {
    "@type": "odrl:Set",
    "odrl:permission": [{
      "odrl:action": {
        "odrl:type": "http://www.w3.org/ns/odrl/2/use"
      }
    }]
  }
}'

api_call "POST" "$MANAGEMENT_URL/v3/policydefinitions" "$ACCESS_POLICY" "Creating an access policy"

# Create a Contract Policy (same as access for demo)
CONTRACT_POLICY='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@type": "PolicyDefinition",
  "@id": "demo-contract-policy",
  "policy": {
    "@type": "odrl:Set",
    "odrl:permission": [{
      "odrl:action": {
        "odrl:type": "http://www.w3.org/ns/odrl/2/use"
      }
    }]
  }
}'

api_call "POST" "$MANAGEMENT_URL/v3/policydefinitions" "$CONTRACT_POLICY" "Creating a contract policy"

# List Policies
api_call "POST" "$MANAGEMENT_URL/v3/policydefinitions/request" "$QUERY_SPEC" "Listing all policies"

echo -e "${GREEN}3. Working with Contract Definitions${NC}"
echo "===================================="

# Create a Contract Definition
CONTRACT_DEFINITION='{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "ContractDefinition",
  "@id": "demo-contract-definition",
  "accessPolicyId": "demo-access-policy",
  "contractPolicyId": "demo-contract-policy",
  "assetsSelector": [{
    "@type": "Criterion",
    "operandLeft": "id",
    "operator": "=",
    "operandRight": "demo-asset-1"
  }]
}'

api_call "POST" "$MANAGEMENT_URL/v3/contractdefinitions" "$CONTRACT_DEFINITION" "Creating a contract definition"

# List Contract Definitions  
api_call "POST" "$MANAGEMENT_URL/v3/contractdefinitions/request" "$QUERY_SPEC" "Listing all contract definitions"

echo -e "${GREEN}4. Querying the Catalog${NC}"
echo "========================"

# Request the catalog (should show our asset as a data offer)
CATALOG_REQUEST='{
  "@context": [
    "https://w3id.org/dspace/2024/1/context.json"
  ],
  "@type": "dspace:CatalogRequestMessage",
  "dspace:filter": {},
  "counterPartyAddress": "http://localhost:8080/api/dsp"
}'

# Note: This will make a self-request to the same connector
api_call "POST" "$PROTOCOL_URL/dsp/catalog/request" "$CATALOG_REQUEST" "Requesting catalog from self"

echo -e "${GREEN}5. Additional Queries${NC}"
echo "===================="

# List Transfer Processes
api_call "POST" "$MANAGEMENT_URL/v3/transferprocesses/request" "$QUERY_SPEC" "Listing transfer processes"

# List Contract Negotiations
api_call "POST" "$MANAGEMENT_URL/v3/contractnegotiations/request" "$QUERY_SPEC" "Listing contract negotiations"

# List EDRs
api_call "POST" "$MANAGEMENT_URL/v3/edrs/request" "$QUERY_SPEC" "Listing EDR entries"

echo -e "${BLUE}✅ Demo Complete!${NC}"
echo ""
echo "Summary of what we created:"
echo "- 1 Asset: demo-asset-1"
echo "- 2 Policies: demo-access-policy, demo-contract-policy" 
echo "- 1 Contract Definition: demo-contract-definition"
echo ""
echo "You can now:"
echo "1. Use another EDC connector to negotiate for this asset"
echo "2. Test data transfer once you have a contract agreement"
echo "3. Use the Management API to manage these resources"
echo ""
echo "For cleanup, you can delete resources using DELETE requests to:"
echo "- $MANAGEMENT_URL/v3/assets/{id}"
echo "- $MANAGEMENT_URL/v3/policydefinitions/{id}"  
echo "- $MANAGEMENT_URL/v3/contractdefinitions/{id}"
