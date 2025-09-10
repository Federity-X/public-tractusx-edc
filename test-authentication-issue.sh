#!/bin/bash

# Authentication Test Script - Production Parity Issue
# This script demonstrates the authentication bypass issue in Tractus-X EDC

echo "🔒 Testing EDC Authentication Behavior"
echo "======================================"
echo

echo "📋 Issue Summary:"
echo "The Tractus-X EDC includes both 'auth-tokenbased' and 'auth-delegated' extensions."
echo "Delegated authentication has higher priority and overrides API key authentication."
echo "This causes permissive behavior where requests succeed without proper authentication."
echo

# Test 1: No authentication header
echo "🧪 Test 1: Request WITHOUT authentication header"
echo "Expected in production: 401 Unauthorized"
echo "Actual result in current setup:"
response1=$(curl -s -w "HTTP Status: %{http_code}" -X POST "http://localhost:8181/management/v3/assets/request" \
  -H "Content-Type: application/json" \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}}')
echo "$response1"
echo

# Test 2: Wrong API key
echo "🧪 Test 2: Request WITH WRONG API key"
echo "Expected in production: 401 Unauthorized"
echo "Actual result in current setup:"
response2=$(curl -s -w "HTTP Status: %{http_code}" -X POST "http://localhost:8181/management/v3/assets/request" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: wrong-api-key" \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}}')
echo "$response2"
echo

# Test 3: Correct API key
echo "🧪 Test 3: Request WITH CORRECT API key"
echo "Expected: Request processed (400 due to body format, not auth failure)"
echo "Actual result:"
response3=$(curl -s -w "HTTP Status: %{http_code}" -X POST "http://localhost:8181/management/v3/assets/request" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: secure-development-key-2024" \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}}')
echo "$response3"
echo

# Analysis
echo "📊 Analysis:"
echo "============"
if [[ "$response1" == *"400"* && "$response2" == *"400"* && "$response3" == *"400"* ]]; then
    echo "❌ AUTHENTICATION BYPASS CONFIRMED"
    echo "   All three requests return the same HTTP status (400 Bad Request)"
    echo "   This indicates authentication is NOT being enforced"
    echo "   Delegated authentication is allowing all requests through"
elif [[ "$response1" == *"401"* && "$response2" == *"401"* && "$response3" == *"400"* ]]; then
    echo "✅ AUTHENTICATION WORKING CORRECTLY"
    echo "   Unauthorized requests return 401"
    echo "   Authorized request returns 400 (request body issue, not auth)"
else
    echo "🤔 MIXED RESULTS - Need further investigation"
fi

echo
echo "🔧 Root Cause:"
echo "   - Both 'auth-tokenbased' and 'auth-delegated' extensions are loaded"
echo "   - Delegated authentication has higher priority"
echo "   - No JWT audience configured, defaulting to permissive behavior"
echo "   - API key authentication is being bypassed"

echo
echo "💡 Solutions for Production Parity:"
echo "   1. Disable delegated authentication in development"
echo "   2. Configure proper JWT-based delegated authentication"
echo "   3. Use custom build excluding delegated auth extension"
echo "   4. Set proper audience configuration for delegated auth"

echo
echo "🔍 For more details, see: PRODUCTION_PARITY_GUIDE.md"
