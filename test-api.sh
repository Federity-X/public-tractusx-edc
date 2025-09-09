#!/bin/bash

# EDC API Test Script
# This script demonstrates how to use the API reference commands

echo "🚀 EDC API Test Script"
echo "======================"
echo ""

# Configuration
API_KEY="password"
MANAGEMENT_URL="http://localhost:8181/management"

echo "📋 Testing EDC API Endpoints"
echo "Using Management URL: $MANAGEMENT_URL"
echo "API Key: $API_KEY"
echo ""

echo "✅ Ready to test! Use these sample commands:"
echo ""

echo "1. List Assets:"
echo "curl -H \"X-Api-Key: $API_KEY\" -H \"Content-Type: application/json\" -X POST -d '{\"@context\":{\"@vocab\":\"https://w3id.org/edc/v0.0.1/ns/\"},\"@type\":\"QuerySpec\",\"limit\":5}' \"$MANAGEMENT_URL/v3/assets/request\""
echo ""

echo "2. List Policies:" 
echo "curl -H \"X-Api-Key: $API_KEY\" -H \"Content-Type: application/json\" -X POST -d '{\"@context\":{\"@vocab\":\"https://w3id.org/edc/v0.0.1/ns/\"},\"@type\":\"QuerySpec\",\"limit\":5}' \"$MANAGEMENT_URL/v3/policydefinitions/request\""
echo ""

echo "3. List Contract Definitions:"
echo "curl -H \"X-Api-Key: $API_KEY\" -H \"Content-Type: application/json\" -X POST -d '{\"@context\":{\"@vocab\":\"https://w3id.org/edc/v0.0.1/ns/\"},\"@type\":\"QuerySpec\",\"limit\":5}' \"$MANAGEMENT_URL/v3/contractdefinitions/request\""
echo ""

echo "4. Create Test Asset:"
echo "ASSET_ID=\"test-asset-\$(date +%s)\""
echo "curl -H \"X-Api-Key: $API_KEY\" -H \"Content-Type: application/json\" -X POST -d \"{\\\"@context\\\":{\\\"@vocab\\\":\\\"https://w3id.org/edc/v0.0.1/ns/\\\"},\\\"@type\\\":\\\"Asset\\\",\\\"@id\\\":\\\"\$ASSET_ID\\\",\\\"properties\\\":{\\\"name\\\":\\\"Test Asset\\\"},\\\"dataAddress\\\":{\\\"@type\\\":\\\"DataAddress\\\",\\\"type\\\":\\\"HttpData\\\",\\\"baseUrl\\\":\\\"https://jsonplaceholder.typicode.com/posts\\\"}}\" \"$MANAGEMENT_URL/v3/assets\""
echo ""

echo "🔍 For the complete API reference, see: EDC_API_REFERENCE.md"
echo ""

echo "🌟 Key Points:"
echo "• All Management API calls need X-Api-Key: password header"
echo "• Use JSON-LD format with proper @context"
echo "• Replace {asset-id}, {policy-id} etc. with real IDs"
echo "• EDC must be running on ports 8181 (management) and 8080 (protocol)"
echo ""

echo "✅ Your EDC is ready for API interactions!"
