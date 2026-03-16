#!/usr/bin/env bash
#
# Bootstrap script for EDC Local DCP Deployment (Per-Company Architecture)
#
# Architecture:
#   Provider Stack: provider-vault, provider-postgres, provider-ih, provider-cp, provider-dp
#   Consumer Stack: consumer-vault, consumer-postgres, consumer-ih, consumer-cp, consumer-dp
#   Issuer Stack:   issuer-vault, issuer-postgres, issuerservice
#   Central:        bdrs-server
#
# This script:
#   1. Creates provider participant in provider-ih
#   2. Creates consumer participant in consumer-ih
#   3. Stores secrets in per-company vaults
#   4. Creates issuer participant in issuerservice
#   5. Registers holders (provider, consumer) in issuerservice
#   6. Adds CredentialService + DataService endpoints to provider/consumer DID documents
#   7. Adds IssuerService endpoint to issuer DID document
#   8. Creates attestation + credential definitions in issuerservice
#   9. Requests credentials (MembershipCredential, BpnCredential, DataExchangeGovernanceCredential)
#  10. Fixes credential vc_format and usage in holder databases
#  11. Seeds BDRS
#  12. Creates asset, policies, and contract definitions on provider
#  13. Verifies catalog access from consumer
#  14. Negotiates contract and initiates data transfer (full E2E test)
#
# Prerequisites:
#   - Issuer stack running (issuer-postgres, issuer-vault, issuerservice)
#   - EDC stack running (provider-vault, consumer-vault, provider-postgres,
#                        consumer-postgres, provider-ih, consumer-ih, bdrs-server)
#     Connectors (CP/DP) can be started after bootstrap.
#
set -euo pipefail

# ========================================
# Configuration
# ========================================
SUPERUSER_KEY="c3VwZXItdXNlcg==.superuserkey"

# Per-company IdentityHub endpoints (host-mapped)
PROVIDER_IH_IDENTITY="http://localhost:7151/api/identity"
PROVIDER_IH_STS="http://localhost:7292/api/sts"
PROVIDER_IH_HEALTH="http://localhost:7181/api/check/health"

CONSUMER_IH_IDENTITY="http://localhost:8152/api/identity"
CONSUMER_IH_STS="http://localhost:8293/api/sts"
CONSUMER_IH_HEALTH="http://localhost:8182/api/check/health"

# Per-company Vault endpoints (host-mapped)
PROVIDER_VAULT_URL="http://localhost:8201"
CONSUMER_VAULT_URL="http://localhost:8202"
ISSUER_VAULT_URL="http://localhost:8200"
VAULT_TOKEN="root"

# Issuer Service endpoints (host-mapped)
IS_ADMIN_URL="http://localhost:15152/api/issuer"
IS_HEALTH="http://localhost:18181/api/check/health"

# BDRS Server (host-mapped)
BDRS_MGMT_URL="http://localhost:8581/api/management"
BDRS_API_KEY="testkey"

# Participants
PROVIDER_BPN="BPNL000000000001"
CONSUMER_BPN="BPNL000000000002"
PROVIDER_DID="did:web:provider-ih:provider"
CONSUMER_DID="did:web:consumer-ih:consumer"
ISSUER_DID="did:web:issuerservice:issuer"

# Base64 encodings (for IH API paths)
PROVIDER_B64=$(printf 'provider' | base64)
CONSUMER_B64=$(printf 'consumer' | base64)
ISSUER_B64=$(printf 'issuer' | base64)

echo ""
echo "================================================================="
echo " EDC Local DCP Deployment — Bootstrap (Per-Company Architecture)"
echo "================================================================="
echo ""

# ========================================
# Helper functions
# ========================================
wait_for_service() {
    local url="$1"
    local name="$2"
    local max_attempts="${3:-30}"
    local extra_header="${4:-}"
    local attempt=0
    echo -n "  Waiting for ${name}..."
    while true; do
        if [ -n "${extra_header}" ]; then
            http_code=$(curl -sf -o /dev/null -w '%{http_code}' -H "${extra_header}" "${url}" 2>/dev/null) || http_code="000"
        else
            http_code=$(curl -sf -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null) || http_code="000"
        fi
        [[ "$http_code" =~ ^2 ]] && break
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo " FAILED (after ${max_attempts} attempts)"
            exit 1
        fi
        sleep 2
        echo -n "."
    done
    echo " OK"
}

store_vault_secret() {
    local vault_url="$1"
    local key="$2"
    local value="$3"
    # Use jq to safely construct JSON payload (handles embedded quotes in JWK values)
    local payload
    payload=$(jq -n --arg v "$value" '{"data": {"content": $v}}')
    curl -sf -X PUT "${vault_url}/v1/secret/data/${key}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${payload}" > /dev/null
    echo "  Stored: ${key} → ${vault_url##*/localhost}"
}

# ========================================
# Step 0: Check prerequisites
# ========================================
echo "Step 0: Checking prerequisites..."
wait_for_service "${PROVIDER_VAULT_URL}/v1/sys/health" "Provider Vault"
wait_for_service "${CONSUMER_VAULT_URL}/v1/sys/health" "Consumer Vault"
wait_for_service "${ISSUER_VAULT_URL}/v1/sys/health" "Issuer Vault"
wait_for_service "${PROVIDER_IH_HEALTH}" "Provider IdentityHub" 60
wait_for_service "${CONSUMER_IH_HEALTH}" "Consumer IdentityHub" 60
wait_for_service "${IS_HEALTH}" "Issuer Service" 60
wait_for_service "http://localhost:8581/api/management/bpn-directory" "BDRS Server" 15 "x-api-key: testkey"
echo ""

# ========================================
# Step 0b: Create BDRS database on issuer-postgres (idempotent)
# ========================================
echo "Step 0b: Ensuring BDRS database exists on issuer-postgres..."
docker exec issuer-postgres psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='bdrs'" | grep -q 1 \
    || docker exec issuer-postgres psql -U postgres -c "CREATE USER bdrs WITH PASSWORD 'bdrs';" 2>/dev/null
docker exec issuer-postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='bdrs'" | grep -q 1 \
    || docker exec issuer-postgres psql -U postgres -c "CREATE DATABASE bdrs OWNER bdrs;" 2>/dev/null
echo "  BDRS database ready."

# ========================================
# Step 0c: Store BDRS management API key in issuer-vault
# ========================================
echo "Step 0c: Storing BDRS mgmt API key in issuer-vault..."
store_vault_secret "${ISSUER_VAULT_URL}" "bdrs-mgmt-api-key" "${BDRS_API_KEY}"
echo ""

# ========================================
# Step 1: Create provider participant in provider-ih
# ========================================
echo "Step 1: Creating provider participant in provider-ih..."
PROVIDER_RESP=$(curl -sf -X POST "${PROVIDER_IH_IDENTITY}/v1alpha/participants" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"participantContextId\": \"provider\",
      \"did\": \"${PROVIDER_DID}\",
      \"active\": true,
      \"key\": {
        \"keyId\": \"provider-key\",
        \"privateKeyAlias\": \"provider-alias\",
        \"keyGeneratorParams\": {
          \"algorithm\": \"EdDSA\",
          \"curve\": \"Ed25519\"
        }
      },
      \"roles\": []
    }" 2>&1) || {
    echo "  WARNING: Provider creation failed (may already exist)."
    PROVIDER_RESP=""
}
PROVIDER_CLIENT_SECRET=""
if [ -n "${PROVIDER_RESP}" ]; then
    PROVIDER_CLIENT_SECRET=$(echo "${PROVIDER_RESP}" | jq -r '.clientSecret // empty')
    echo "  Created. clientSecret: ${PROVIDER_CLIENT_SECRET:0:8}..."
fi
echo ""

# ========================================
# Step 2: Create consumer participant in consumer-ih
# ========================================
echo "Step 2: Creating consumer participant in consumer-ih..."
CONSUMER_RESP=$(curl -sf -X POST "${CONSUMER_IH_IDENTITY}/v1alpha/participants" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"participantContextId\": \"consumer\",
      \"did\": \"${CONSUMER_DID}\",
      \"active\": true,
      \"key\": {
        \"keyId\": \"consumer-key\",
        \"privateKeyAlias\": \"consumer-alias\",
        \"keyGeneratorParams\": {
          \"algorithm\": \"EdDSA\",
          \"curve\": \"Ed25519\"
        }
      },
      \"roles\": []
    }" 2>&1) || {
    echo "  WARNING: Consumer creation failed (may already exist)."
    CONSUMER_RESP=""
}
CONSUMER_CLIENT_SECRET=""
if [ -n "${CONSUMER_RESP}" ]; then
    CONSUMER_CLIENT_SECRET=$(echo "${CONSUMER_RESP}" | jq -r '.clientSecret // empty')
    echo "  Created. clientSecret: ${CONSUMER_CLIENT_SECRET:0:8}..."
fi
echo ""

# ========================================
# Step 3: Store secrets in per-company vaults
# ========================================
echo "Step 3: Storing secrets in vaults..."

echo "  --- Provider Vault ---"
if [ -n "${PROVIDER_CLIENT_SECRET}" ]; then
    store_vault_secret "${PROVIDER_VAULT_URL}" "provider-sts-secret" "${PROVIDER_CLIENT_SECRET}"
else
    echo "  SKIPPED: provider-sts-secret (no clientSecret)"
fi

# Transfer proxy keys must be EC P-256 JWK (not raw hex), because the
# DataPlane's JwsSignerProvider needs a parseable private key format.
echo "  Generating EC P-256 JWK transfer proxy keys..."
PROVIDER_PROXY_JWK=$(python3 -c "
import subprocess, json, base64
def b64url(d): return base64.urlsafe_b64encode(d).rstrip(b'=').decode()
def gen():
    r=subprocess.run(['openssl','ecparam','-name','prime256v1','-genkey','-noout'],capture_output=True,text=True)
    r2=subprocess.run(['openssl','ec','-text','-noout'],input=r.stdout,capture_output=True,text=True)
    t=r2.stdout+r2.stderr; secs={}; cur=None; hx=[]
    for l in t.split(chr(10)):
        s=l.strip()
        if s.startswith('priv:'): cur='priv'; hx=[]
        elif s.startswith('pub:'):
            if cur=='priv': secs['priv']=hx
            cur='pub'; hx=[]
        elif s.startswith('ASN1') or s.startswith('NIST') or s=='':
            if cur and hx: secs[cur]=hx
            cur=None
        elif cur: hx.append(s.replace(':',''))
    if cur and hx: secs[cur]=hx
    ph=''.join(secs.get('priv',[])); pu=''.join(secs.get('pub',[]))
    d=bytes.fromhex(ph)
    if len(d)>32: d=d[-32:]
    elif len(d)<32: d=b'\\x00'*(32-len(d))+d
    pb=bytes.fromhex(pu)
    return json.dumps({'kty':'EC','crv':'P-256','x':b64url(pb[1:33]),'y':b64url(pb[33:65]),'d':b64url(d),'kid':'transfer-proxy-key'})
print(gen())
")
store_vault_secret "${PROVIDER_VAULT_URL}" "provider-transfer-proxy-key" "${PROVIDER_PROXY_JWK}"

# IH Identity API key — needed by the DidDocumentServiceIdentityHubClient
store_vault_secret "${PROVIDER_VAULT_URL}" "provider-ih-api-key" "${SUPERUSER_KEY}"
echo "  Stored provider-ih-api-key in provider vault."

echo "  --- Consumer Vault ---"
if [ -n "${CONSUMER_CLIENT_SECRET}" ]; then
    store_vault_secret "${CONSUMER_VAULT_URL}" "consumer-sts-secret" "${CONSUMER_CLIENT_SECRET}"
else
    echo "  SKIPPED: consumer-sts-secret (no clientSecret)"
fi
CONSUMER_PROXY_JWK=$(python3 -c "
import subprocess, json, base64
def b64url(d): return base64.urlsafe_b64encode(d).rstrip(b'=').decode()
def gen():
    r=subprocess.run(['openssl','ecparam','-name','prime256v1','-genkey','-noout'],capture_output=True,text=True)
    r2=subprocess.run(['openssl','ec','-text','-noout'],input=r.stdout,capture_output=True,text=True)
    t=r2.stdout+r2.stderr; secs={}; cur=None; hx=[]
    for l in t.split(chr(10)):
        s=l.strip()
        if s.startswith('priv:'): cur='priv'; hx=[]
        elif s.startswith('pub:'):
            if cur=='priv': secs['priv']=hx
            cur='pub'; hx=[]
        elif s.startswith('ASN1') or s.startswith('NIST') or s=='':
            if cur and hx: secs[cur]=hx
            cur=None
        elif cur: hx.append(s.replace(':',''))
    if cur and hx: secs[cur]=hx
    ph=''.join(secs.get('priv',[])); pu=''.join(secs.get('pub',[]))
    d=bytes.fromhex(ph)
    if len(d)>32: d=d[-32:]
    elif len(d)<32: d=b'\\x00'*(32-len(d))+d
    pb=bytes.fromhex(pu)
    return json.dumps({'kty':'EC','crv':'P-256','x':b64url(pb[1:33]),'y':b64url(pb[33:65]),'d':b64url(d),'kid':'transfer-proxy-key'})
print(gen())
")
store_vault_secret "${CONSUMER_VAULT_URL}" "consumer-transfer-proxy-key" "${CONSUMER_PROXY_JWK}"

# IH Identity API key — needed by the DidDocumentServiceIdentityHubClient
store_vault_secret "${CONSUMER_VAULT_URL}" "consumer-ih-api-key" "${SUPERUSER_KEY}"
echo "  Stored consumer-ih-api-key in consumer vault."
echo ""

# ========================================
# Step 4: Verify STS token acquisition
# ========================================
if [ -n "${PROVIDER_CLIENT_SECRET}" ]; then
    echo "Step 4: Verifying STS token from provider-ih..."
    STS_RESP=$(curl -sf -X POST "${PROVIDER_IH_STS}/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials&client_id=${PROVIDER_DID}&client_secret=${PROVIDER_CLIENT_SECRET}&audience=${CONSUMER_DID}" 2>&1) || STS_RESP=""
    if [ -n "${STS_RESP}" ]; then
        STS_TOKEN=$(echo "${STS_RESP}" | jq -r '.access_token // empty' | head -c 40)
        echo "  STS token (first 40 chars): ${STS_TOKEN}..."
        echo "  STS OK"
    else
        echo "  WARNING: STS token request failed"
    fi
else
    echo "Step 4: SKIPPED STS verification (no provider clientSecret)"
fi
echo ""

# ========================================
# Step 5: Create issuer participant in Issuer Service
# ========================================
echo "Step 5: Creating issuer participant in Issuer Service..."
# IS identity API is on port 15151 inside the container. Not exposed to host separately.
# Use docker exec to reach it.
ISSUER_RESP=$(docker exec issuerservice sh -c "
    wget -qO- --post-data='{
      \"participantContextId\": \"issuer\",
      \"did\": \"${ISSUER_DID}\",
      \"active\": true,
      \"key\": {
        \"keyId\": \"issuer-key\",
        \"privateKeyAlias\": \"issuer-key\",
        \"keyGeneratorParams\": {
          \"algorithm\": \"EdDSA\",
          \"curve\": \"Ed25519\"
        }
      },
      \"roles\": []
    }' --header='Content-Type: application/json' --header='x-api-key: ${SUPERUSER_KEY}' 'http://localhost:15151/api/identity/v1alpha/participants'
" 2>&1) || {
    echo "  WARNING: Issuer creation failed (may already exist)."
    ISSUER_RESP=""
}
if [ -n "${ISSUER_RESP}" ]; then
    echo "  Issuer participant created."
fi
echo ""

# ========================================
# Step 6: Register holders in Issuer Service
# ========================================
echo "Step 6: Registering holders in Issuer Service..."

curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/holders" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"holderId\": \"provider\", \"did\": \"${PROVIDER_DID}\", \"name\": \"Provider\"}" \
    > /dev/null 2>&1 && echo "  Provider registered as holder." || echo "  WARNING: Provider holder registration failed."

curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/holders" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"holderId\": \"consumer\", \"did\": \"${CONSUMER_DID}\", \"name\": \"Consumer\"}" \
    > /dev/null 2>&1 && echo "  Consumer registered as holder." || echo "  WARNING: Consumer holder registration failed."
echo ""

# ========================================
# Step 7: Fix key IDs to full DID URL format
# ========================================
echo "Step 7: Fixing key IDs to full DID URL format..."

# IdentityHub stores key IDs as simple names (e.g. "provider-key") but DCP
# validation requires them to be full DID key IDs (e.g. "did:web:provider-ih:provider#provider-key").
# Fix in provider-postgres:
echo "  Fixing provider key IDs in provider-postgres..."
docker exec provider-postgres psql -U provider -d provider -c "
  UPDATE keypair_resource SET key_id = '${PROVIDER_DID}#provider-key'
    WHERE key_id = 'provider-key';
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{verificationMethod,0,id}', '\"${PROVIDER_DID}#provider-key\"'
  )::json WHERE did IS NOT NULL;
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{verificationMethod,0,publicKeyJwk,kid}', '\"${PROVIDER_DID}#provider-key\"'
  )::json WHERE did IS NOT NULL;
" > /dev/null 2>&1 && echo "  Provider key IDs fixed." || echo "  WARNING: Provider key fix failed."

echo "  Fixing consumer key IDs in consumer-postgres..."
docker exec consumer-postgres psql -U consumer -d consumer -c "
  UPDATE keypair_resource SET key_id = '${CONSUMER_DID}#consumer-key'
    WHERE key_id = 'consumer-key';
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{verificationMethod,0,id}', '\"${CONSUMER_DID}#consumer-key\"'
  )::json WHERE did IS NOT NULL;
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{verificationMethod,0,publicKeyJwk,kid}', '\"${CONSUMER_DID}#consumer-key\"'
  )::json WHERE did IS NOT NULL;
" > /dev/null 2>&1 && echo "  Consumer key IDs fixed." || echo "  WARNING: Consumer key fix failed."

echo "  Fixing issuer key IDs in issuer-postgres..."
docker exec issuer-postgres psql -U postgres -d issuerservice -c "
  UPDATE keypair_resource SET key_id = '${ISSUER_DID}#issuer-key'
    WHERE key_id = 'issuer-key';
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{verificationMethod,0,id}', '\"${ISSUER_DID}#issuer-key\"'
  )::json WHERE did IS NOT NULL;
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{verificationMethod,0,publicKeyJwk,kid}', '\"${ISSUER_DID}#issuer-key\"'
  )::json WHERE did IS NOT NULL;
" > /dev/null 2>&1 && echo "  Issuer key IDs fixed." || echo "  WARNING: Issuer key fix failed."
echo ""

# ========================================
# Step 8: Add service endpoints to DID documents
# ========================================
# NOTE: DataService endpoints must be registered in bootstrap because the
# connector's self-registration feature requires IH API key vault secrets
# which are only seeded in Step 3 — after the connectors have already started.
# The self-registration will work on subsequent restarts but not on first boot.
echo "Step 8: Adding service endpoints to DID documents..."

# Provider DID: add CredentialService endpoint
PROVIDER_DID_B64=$(printf "${PROVIDER_DID}" | base64)
echo "  Adding CredentialService to provider DID..."
curl -sf -X POST "${PROVIDER_IH_IDENTITY}/v1alpha/participants/${PROVIDER_B64}/dids/${PROVIDER_DID_B64}/endpoints?autoPublish=true" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"id\": \"credential-service\", \"type\": \"CredentialService\", \"serviceEndpoint\": \"http://provider-ih:13131/api/credentials/v1/participants/${PROVIDER_B64}\"}" \
    > /dev/null 2>&1 && echo "  Provider CredentialService added." || echo "  WARNING: Provider CredentialService failed."

# Provider DID: add DataService endpoint (DSP well-known version endpoint)
echo "  Adding DataService to provider DID..."
curl -sf -X POST "${PROVIDER_IH_IDENTITY}/v1alpha/participants/${PROVIDER_B64}/dids/${PROVIDER_DID_B64}/endpoints?autoPublish=true" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"id\": \"${PROVIDER_DID}#DataService\", \"type\": \"DataService\", \"serviceEndpoint\": \"http://provider-cp:8084/api/v1/dsp/.well-known/dspace-version\"}" \
    > /dev/null 2>&1 && echo "  Provider DataService added." || echo "  WARNING: Provider DataService failed."

# Consumer DID: add CredentialService endpoint
CONSUMER_DID_B64=$(printf "${CONSUMER_DID}" | base64)
echo "  Adding CredentialService to consumer DID..."
curl -sf -X POST "${CONSUMER_IH_IDENTITY}/v1alpha/participants/${CONSUMER_B64}/dids/${CONSUMER_DID_B64}/endpoints?autoPublish=true" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"id\": \"credential-service\", \"type\": \"CredentialService\", \"serviceEndpoint\": \"http://consumer-ih:13131/api/credentials/v1/participants/${CONSUMER_B64}\"}" \
    > /dev/null 2>&1 && echo "  Consumer CredentialService added." || echo "  WARNING: Consumer CredentialService failed."

# Consumer DID: add DataService endpoint (DSP well-known version endpoint)
echo "  Adding DataService to consumer DID..."
curl -sf -X POST "${CONSUMER_IH_IDENTITY}/v1alpha/participants/${CONSUMER_B64}/dids/${CONSUMER_DID_B64}/endpoints?autoPublish=true" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"id\": \"${CONSUMER_DID}#DataService\", \"type\": \"DataService\", \"serviceEndpoint\": \"http://consumer-cp:8084/api/v1/dsp/.well-known/dspace-version\"}" \
    > /dev/null 2>&1 && echo "  Consumer DataService added." || echo "  WARNING: Consumer DataService failed."

# Issuer DID: add IssuerService endpoint (via DB since IS identity API isn't exposed to host)
echo "  Adding IssuerService endpoint to issuer DID..."
docker exec issuer-postgres psql -U postgres -d issuerservice -c "
  UPDATE did_resources SET did_document = jsonb_set(
    did_document::jsonb, '{service}',
    COALESCE(did_document::jsonb->'service', '[]'::jsonb) || '[{\"id\":\"issuer-service\",\"type\":\"IssuerService\",\"serviceEndpoint\":\"http://issuerservice:13132/api/issuance/v1alpha/participants/${ISSUER_B64}\"}]'::jsonb
  )::json WHERE did IS NOT NULL;
" > /dev/null 2>&1 && echo "  Issuer IssuerService endpoint added." || echo "  WARNING: Issuer IssuerService endpoint failed."
echo ""

# ========================================
# Step 9: Create attestation + credential definitions
# ========================================
echo "Step 9: Creating attestation and credential definitions..."

echo "  Creating MembershipCredential attestation definition..."
curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/attestations" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "id": "membership-attestation",
      "attestationType": "database",
      "configuration": {
        "dataSourceName": "default",
        "tableName": "membership_attestation",
        "idColumn": "holder_id"
      }
    }' > /dev/null 2>&1 && echo "  membership-attestation created." || echo "  WARNING: membership-attestation failed."

echo "  Creating BpnCredential attestation definition..."
curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/attestations" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "id": "bpn-attestation",
      "attestationType": "database",
      "configuration": {
        "dataSourceName": "default",
        "tableName": "bpn_attestation",
        "idColumn": "holder_id"
      }
    }' > /dev/null 2>&1 && echo "  bpn-attestation created." || echo "  WARNING: bpn-attestation failed."

echo "  Creating attestation data tables in issuer-postgres..."
docker exec issuer-postgres psql -U postgres -d issuerservice -c "
  CREATE TABLE IF NOT EXISTS membership_attestation (
    holder_id VARCHAR(255) PRIMARY KEY,
    membership_type VARCHAR(255) NOT NULL,
    holder_identifier VARCHAR(255),
    status VARCHAR(64) NOT NULL DEFAULT 'active',
    since TIMESTAMP NOT NULL DEFAULT NOW()
  );
  CREATE TABLE IF NOT EXISTS bpn_attestation (
    holder_id VARCHAR(255) PRIMARY KEY,
    bpn VARCHAR(64) NOT NULL,
    holder_identifier VARCHAR(255),
    status VARCHAR(64) NOT NULL DEFAULT 'active'
  );
  INSERT INTO membership_attestation (holder_id, membership_type, holder_identifier) VALUES
    ('provider', 'Full', '${PROVIDER_BPN}'), ('consumer', 'Full', '${CONSUMER_BPN}')
    ON CONFLICT DO NOTHING;
  INSERT INTO bpn_attestation (holder_id, bpn, holder_identifier) VALUES
    ('provider', '${PROVIDER_BPN}', '${PROVIDER_BPN}'), ('consumer', '${CONSUMER_BPN}', '${CONSUMER_BPN}')
    ON CONFLICT DO NOTHING;
" > /dev/null 2>&1 && echo "  Attestation tables created and seeded." || echo "  WARNING: Attestation table creation failed."

MEMBERSHIP_DEF_ID=""
BPN_DEF_ID=""
DEG_DEF_ID=""

echo "  Creating MembershipCredential definition..."
MEMBERSHIP_DEF_RESP=$(curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/credentialdefinitions" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "credentialType": "MembershipCredential",
      "format": "VC1_0_JWT",
      "jsonSchemaUrl": "https://example.com/schemas/membership.json",
      "validity": 31536000,
      "attestations": ["membership-attestation"],
      "mappings": [
        {"input": "membership_type", "output": "credentialSubject.membershipType", "required": false},
        {"input": "status", "output": "credentialSubject.status", "required": false},
        {"input": "holder_identifier", "output": "credentialSubject.holderIdentifier", "required": false}
      ],
      "rules": []
    }' 2>&1) || {
    echo "  WARNING: MembershipCredential definition failed."
    MEMBERSHIP_DEF_RESP=""
}
if [ -n "${MEMBERSHIP_DEF_RESP}" ]; then
    MEMBERSHIP_DEF_ID=$(echo "${MEMBERSHIP_DEF_RESP}" | jq -r '.id // empty' 2>/dev/null || echo "")
    echo "  MembershipCredential definition created: ${MEMBERSHIP_DEF_ID}"
fi

echo "  Creating BpnCredential definition..."
BPN_DEF_RESP=$(curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/credentialdefinitions" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "credentialType": "BpnCredential",
      "format": "VC1_0_JWT",
      "jsonSchemaUrl": "https://example.com/schemas/bpn.json",
      "validity": 31536000,
      "attestations": ["bpn-attestation"],
      "mappings": [
        {"input": "bpn", "output": "credentialSubject.bpn", "required": false},
        {"input": "holder_identifier", "output": "credentialSubject.holderIdentifier", "required": false}
      ],
      "rules": []
    }' 2>&1) || {
    echo "  WARNING: BpnCredential definition failed."
    BPN_DEF_RESP=""
}
if [ -n "${BPN_DEF_RESP}" ]; then
    BPN_DEF_ID=$(echo "${BPN_DEF_RESP}" | jq -r '.id // empty' 2>/dev/null || echo "")
    echo "  BpnCredential definition created: ${BPN_DEF_ID}"
fi

echo "  Creating DataExchangeGovernanceCredential attestation definition..."
curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/attestations" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "id": "data-exchange-governance-attestation",
      "attestationType": "database",
      "configuration": {
        "dataSourceName": "default",
        "tableName": "data_exchange_governance_attestation",
        "idColumn": "holder_id"
      }
    }' > /dev/null 2>&1 && echo "  data-exchange-governance-attestation created." || echo "  WARNING: data-exchange-governance-attestation failed."

echo "  Creating DataExchangeGovernance attestation table..."
docker exec issuer-postgres psql -U postgres -d issuerservice -c "
  CREATE TABLE IF NOT EXISTS data_exchange_governance_attestation (
    holder_id VARCHAR(255) PRIMARY KEY,
    governance_type VARCHAR(255) NOT NULL,
    version VARCHAR(64) NOT NULL DEFAULT '1.0',
    holder_identifier VARCHAR(255),
    status VARCHAR(64) NOT NULL DEFAULT 'active'
  );
  INSERT INTO data_exchange_governance_attestation (holder_id, governance_type, version, holder_identifier) VALUES
    ('provider', 'DataExchangeGovernance', '1.0', '${PROVIDER_BPN}'),
    ('consumer', 'DataExchangeGovernance', '1.0', '${CONSUMER_BPN}')
    ON CONFLICT DO NOTHING;
" > /dev/null 2>&1 && echo "  DataExchangeGovernance attestation table created and seeded." || echo "  WARNING: DataExchangeGovernance attestation table failed."

echo "  Creating DataExchangeGovernanceCredential definition..."
DEG_DEF_RESP=$(curl -sf -X POST "${IS_ADMIN_URL}/v1alpha/participants/${ISSUER_B64}/credentialdefinitions" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "credentialType": "DataExchangeGovernanceCredential",
      "format": "VC1_0_JWT",
      "jsonSchemaUrl": "https://example.com/schemas/data-exchange-governance.json",
      "validity": 31536000,
      "attestations": ["data-exchange-governance-attestation"],
      "mappings": [
        {"input": "governance_type", "output": "credentialSubject.governanceType", "required": false},
        {"input": "version", "output": "credentialSubject.contractVersion", "required": false},
        {"input": "holder_identifier", "output": "credentialSubject.holderIdentifier", "required": false}
      ],
      "rules": []
    }' 2>&1) || {
    echo "  WARNING: DataExchangeGovernanceCredential definition failed."
    DEG_DEF_RESP=""
}
if [ -n "${DEG_DEF_RESP}" ]; then
    DEG_DEF_ID=$(echo "${DEG_DEF_RESP}" | jq -r '.id // empty' 2>/dev/null || echo "")
    echo "  DataExchangeGovernanceCredential definition created: ${DEG_DEF_ID}"
fi
echo ""

# ========================================
# Step 10: Request credentials via DCP
# ========================================
echo "Step 10: Requesting credentials via DCP..."

# Credential requests need definition IDs from Step 9 and use 'type' (not 'credentialType')
if [ -z "${MEMBERSHIP_DEF_ID}" ] || [ -z "${BPN_DEF_ID}" ] || [ -z "${DEG_DEF_ID}" ]; then
    echo "  WARNING: Missing credential definition IDs from Step 9. Querying from DB..."
    MEMBERSHIP_DEF_ID=$(docker exec issuer-postgres psql -U postgres -d issuerservice -t -c \
      "SELECT id FROM credential_definitions WHERE credential_type='MembershipCredential';" 2>/dev/null | tr -d ' \n')
    BPN_DEF_ID=$(docker exec issuer-postgres psql -U postgres -d issuerservice -t -c \
      "SELECT id FROM credential_definitions WHERE credential_type='BpnCredential';" 2>/dev/null | tr -d ' \n')
    DEG_DEF_ID=$(docker exec issuer-postgres psql -U postgres -d issuerservice -t -c \
      "SELECT id FROM credential_definitions WHERE credential_type='DataExchangeGovernanceCredential';" 2>/dev/null | tr -d ' \n')
    echo "  MembershipCredential def: ${MEMBERSHIP_DEF_ID}"
    echo "  BpnCredential def: ${BPN_DEF_ID}"
    echo "  DataExchangeGovernanceCredential def: ${DEG_DEF_ID}"
fi

echo "  Requesting MembershipCredential for provider..."
curl -sf -X POST "${PROVIDER_IH_IDENTITY}/v1alpha/participants/${PROVIDER_B64}/credentials/request" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"issuerDid\": \"${ISSUER_DID}\",
      \"holderPid\": \"provider-membership-request\",
      \"credentials\": [{
        \"format\": \"VC1_0_JWT\",
        \"type\": \"MembershipCredential\",
        \"id\": \"${MEMBERSHIP_DEF_ID}\"
      }]
    }" > /dev/null 2>&1 && echo "  Provider MembershipCredential requested." || echo "  WARNING: Provider MembershipCredential request failed."

echo "  Requesting MembershipCredential for consumer..."
curl -sf -X POST "${CONSUMER_IH_IDENTITY}/v1alpha/participants/${CONSUMER_B64}/credentials/request" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"issuerDid\": \"${ISSUER_DID}\",
      \"holderPid\": \"consumer-membership-request\",
      \"credentials\": [{
        \"format\": \"VC1_0_JWT\",
        \"type\": \"MembershipCredential\",
        \"id\": \"${MEMBERSHIP_DEF_ID}\"
      }]
    }" > /dev/null 2>&1 && echo "  Consumer MembershipCredential requested." || echo "  WARNING: Consumer MembershipCredential request failed."

echo "  Requesting BpnCredential for provider..."
curl -sf -X POST "${PROVIDER_IH_IDENTITY}/v1alpha/participants/${PROVIDER_B64}/credentials/request" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"issuerDid\": \"${ISSUER_DID}\",
      \"holderPid\": \"provider-bpn-request\",
      \"credentials\": [{
        \"format\": \"VC1_0_JWT\",
        \"type\": \"BpnCredential\",
        \"id\": \"${BPN_DEF_ID}\"
      }]
    }" > /dev/null 2>&1 && echo "  Provider BpnCredential requested." || echo "  WARNING: Provider BpnCredential request failed."

echo "  Requesting BpnCredential for consumer..."
curl -sf -X POST "${CONSUMER_IH_IDENTITY}/v1alpha/participants/${CONSUMER_B64}/credentials/request" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"issuerDid\": \"${ISSUER_DID}\",
      \"holderPid\": \"consumer-bpn-request\",
      \"credentials\": [{
        \"format\": \"VC1_0_JWT\",
        \"type\": \"BpnCredential\",
        \"id\": \"${BPN_DEF_ID}\"
      }]
    }" > /dev/null 2>&1 && echo "  Consumer BpnCredential requested." || echo "  WARNING: Consumer BpnCredential request failed."

echo "  Requesting DataExchangeGovernanceCredential for provider..."
curl -sf -X POST "${PROVIDER_IH_IDENTITY}/v1alpha/participants/${PROVIDER_B64}/credentials/request" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"issuerDid\": \"${ISSUER_DID}\",
      \"holderPid\": \"provider-deg-request\",
      \"credentials\": [{
        \"format\": \"VC1_0_JWT\",
        \"type\": \"DataExchangeGovernanceCredential\",
        \"id\": \"${DEG_DEF_ID}\"
      }]
    }" > /dev/null 2>&1 && echo "  Provider DataExchangeGovernanceCredential requested." || echo "  WARNING: Provider DataExchangeGovernanceCredential request failed."

echo "  Requesting DataExchangeGovernanceCredential for consumer..."
curl -sf -X POST "${CONSUMER_IH_IDENTITY}/v1alpha/participants/${CONSUMER_B64}/credentials/request" \
    -H "x-api-key: ${SUPERUSER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"issuerDid\": \"${ISSUER_DID}\",
      \"holderPid\": \"consumer-deg-request\",
      \"credentials\": [{
        \"format\": \"VC1_0_JWT\",
        \"type\": \"DataExchangeGovernanceCredential\",
        \"id\": \"${DEG_DEF_ID}\"
      }]
    }" > /dev/null 2>&1 && echo "  Consumer DataExchangeGovernanceCredential requested." || echo "  WARNING: Consumer DataExchangeGovernanceCredential request failed."

echo "  Waiting for DCP issuance protocol (15 seconds)..."
sleep 15
echo ""

# ========================================
# Step 11: Verify credentials
# ========================================
echo "Step 11: Verifying credentials (expecting 3 each: Membership, BPN, DataExchangeGovernance)..."

echo "  Provider credentials:"
PROV_CREDS=$(curl -sf "${PROVIDER_IH_IDENTITY}/v1alpha/participants/${PROVIDER_B64}/credentials" \
    -H "x-api-key: ${SUPERUSER_KEY}" 2>&1) || PROV_CREDS=""
if [ -n "${PROV_CREDS}" ]; then
    echo "${PROV_CREDS}" | jq -r '.[] | "    - \(.verifiableCredential.credential.type[-1]) (\(.state))"' 2>/dev/null || echo "    (unable to parse)"
    PROV_COUNT=$(echo "${PROV_CREDS}" | jq 'length' 2>/dev/null || echo "0")
    echo "  Total: ${PROV_COUNT}"
else
    echo "    (no credentials found)"
fi

echo "  Consumer credentials:"
CONS_CREDS=$(curl -sf "${CONSUMER_IH_IDENTITY}/v1alpha/participants/${CONSUMER_B64}/credentials" \
    -H "x-api-key: ${SUPERUSER_KEY}" 2>&1) || CONS_CREDS=""
if [ -n "${CONS_CREDS}" ]; then
    echo "${CONS_CREDS}" | jq -r '.[] | "    - \(.verifiableCredential.credential.type[-1]) (\(.state))"' 2>/dev/null || echo "    (unable to parse)"
    CONS_COUNT=$(echo "${CONS_CREDS}" | jq 'length' 2>/dev/null || echo "0")
    echo "  Total: ${CONS_COUNT}"
else
    echo "    (no credentials found)"
fi
echo ""

# ========================================
# Step 11b: Fix credential vc_format and usage in holder databases
# ========================================
# The DCP issuance protocol may store credentials with vc_format=0 (unknown)
# and usage=null. EDC connectors require vc_format=1 (JWT) and usage='Holder'.
echo "Step 11b: Fixing credential vc_format and usage in holder databases..."

docker exec provider-postgres psql -U provider -d provider -c "
  UPDATE credential_resource SET vc_format = 1 WHERE vc_format != 1;
  UPDATE credential_resource SET usage = 'Holder' WHERE usage IS NULL OR usage != 'Holder';
" > /dev/null 2>&1 && echo "  Provider credentials fixed (vc_format=1, usage=Holder)." \
  || echo "  WARNING: Provider credential fix failed."

docker exec consumer-postgres psql -U consumer -d consumer -c "
  UPDATE credential_resource SET vc_format = 1 WHERE vc_format != 1;
  UPDATE credential_resource SET usage = 'Holder' WHERE usage IS NULL OR usage != 'Holder';
" > /dev/null 2>&1 && echo "  Consumer credentials fixed (vc_format=1, usage=Holder)." \
  || echo "  WARNING: Consumer credential fix failed."
echo ""

# ========================================
# Step 12: Seed BDRS server
# ========================================
echo "Step 12: Seeding BDRS server..."

curl -sf -X POST "${BDRS_MGMT_URL}/bpn-directory" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${BDRS_API_KEY}" \
    -d "{\"bpn\": \"${PROVIDER_BPN}\", \"did\": \"${PROVIDER_DID}\"}" > /dev/null 2>&1 \
    && echo "  ${PROVIDER_BPN} → ${PROVIDER_DID}" \
    || echo "  WARNING: Failed to seed provider BPN mapping."

curl -sf -X POST "${BDRS_MGMT_URL}/bpn-directory" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${BDRS_API_KEY}" \
    -d "{\"bpn\": \"${CONSUMER_BPN}\", \"did\": \"${CONSUMER_DID}\"}" > /dev/null 2>&1 \
    && echo "  ${CONSUMER_BPN} → ${CONSUMER_DID}" \
    || echo "  WARNING: Failed to seed consumer BPN mapping."
echo ""

# ========================================
# Step 13: Create asset and policies on provider
# ========================================
echo "Step 13: Creating asset and policies on provider..."

PROVIDER_MGMT_URL="http://localhost:19193/management"
CONSUMER_MGMT_URL="http://localhost:29193/management"
CONNECTOR_API_KEY="testkey"
CX_POLICY_NS="https://w3id.org/catenax/2025/9/policy/"

# Create asset
curl -sf -X POST "${PROVIDER_MGMT_URL}/v3/assets" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CONNECTOR_API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "@id": "test-asset-1",
      "properties": {"name": "Test Asset", "contenttype": "application/json"},
      "dataAddress": {
        "type": "HttpData",
        "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
      }
    }' > /dev/null 2>&1 \
    && echo "  Asset 'test-asset-1' created" \
    || echo "  Asset 'test-asset-1' already exists or failed"

# Create access policy (unrestricted)
curl -sf -X POST "${PROVIDER_MGMT_URL}/v3/policydefinitions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CONNECTOR_API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
      "@id": "access-policy-1",
      "policy": {
        "@type": "odrl:Set",
        "odrl:permission": [],
        "odrl:prohibition": [],
        "odrl:obligation": []
      }
    }' > /dev/null 2>&1 \
    && echo "  Access policy 'access-policy-1' created" \
    || echo "  Access policy 'access-policy-1' already exists or failed"

# Create contract policy (FrameworkAgreement + UsagePurpose)
curl -sf -X POST "${PROVIDER_MGMT_URL}/v3/policydefinitions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CONNECTOR_API_KEY}" \
    -d '{
      "@context": {
        "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
        "odrl": "http://www.w3.org/ns/odrl/2/",
        "cx-policy": "https://w3id.org/catenax/2025/9/policy/"
      },
      "@id": "contract-policy-1",
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
    }' > /dev/null 2>&1 \
    && echo "  Contract policy 'contract-policy-1' created" \
    || echo "  Contract policy 'contract-policy-1' already exists or failed"

# Create contract definition
curl -sf -X POST "${PROVIDER_MGMT_URL}/v3/contractdefinitions" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CONNECTOR_API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
      "@id": "contract-def-1",
      "accessPolicyId": "access-policy-1",
      "contractPolicyId": "contract-policy-1",
      "assetsSelector": {
        "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
        "operator": "=",
        "operandRight": "test-asset-1"
      }
    }' > /dev/null 2>&1 \
    && echo "  Contract definition 'contract-def-1' created" \
    || echo "  Contract definition 'contract-def-1' already exists or failed"
echo ""

# ========================================
# Step 14: Verify catalog access
# ========================================
echo "Step 14: Verifying catalog access from consumer..."

CATALOG_RESPONSE=$(curl -sf -X POST "${CONSUMER_MGMT_URL}/v3/catalog/request" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CONNECTOR_API_KEY}" \
    -d '{
      "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
      "counterPartyAddress": "http://provider-cp:8084/api/v1/dsp",
      "counterPartyId": "'"${PROVIDER_DID}"'",
      "protocol": "dataspace-protocol-http"
    }' 2>/dev/null) || true

if echo "${CATALOG_RESPONSE}" | jq -e '.["dcat:dataset"]' > /dev/null 2>&1; then
    OFFER_ID=$(echo "${CATALOG_RESPONSE}" | jq -r '.["dcat:dataset"]["odrl:hasPolicy"]["@id"]')
    echo "  Catalog OK — Offer ID: ${OFFER_ID}"
else
    echo "  WARNING: Catalog request failed or returned no datasets."
    echo "  Check that provider-cp and consumer-cp are running."
    OFFER_ID=""
fi
echo ""

# ========================================
# Step 15: Negotiate contract
# ========================================
if [ -n "${OFFER_ID}" ]; then
    echo "Step 15: Negotiating contract..."

    NEGOTIATE_RESPONSE=$(curl -sf -X POST "${CONSUMER_MGMT_URL}/v3/contractnegotiations" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${CONNECTOR_API_KEY}" \
        -d '{
          "@context": {
            "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
            "odrl": "http://www.w3.org/ns/odrl/2/"
          },
          "counterPartyAddress": "http://provider-cp:8084/api/v1/dsp",
          "counterPartyId": "'"${PROVIDER_DID}"'",
          "protocol": "dataspace-protocol-http",
          "policy": {
            "@type": "odrl:Offer",
            "@id": "'"${OFFER_ID}"'",
            "odrl:assigner": {"@id": "'"${PROVIDER_BPN}"'"},
            "odrl:target": {"@id": "test-asset-1"},
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
        }' 2>/dev/null) || true

    NEGOTIATION_ID=$(echo "${NEGOTIATE_RESPONSE}" | jq -r '.["@id"]' 2>/dev/null)
    if [ -n "${NEGOTIATION_ID}" ] && [ "${NEGOTIATION_ID}" != "null" ]; then
        echo "  Negotiation started: ${NEGOTIATION_ID}"

        # Wait for FINALIZED state
        echo -n "  Waiting for finalization"
        for i in $(seq 1 30); do
            sleep 2
            echo -n "."
            NEG_STATE=$(curl -sf "${CONSUMER_MGMT_URL}/v3/contractnegotiations/${NEGOTIATION_ID}" \
                -H "x-api-key: ${CONNECTOR_API_KEY}" 2>/dev/null | jq -r '.state' 2>/dev/null) || NEG_STATE=""
            if [ "${NEG_STATE}" = "FINALIZED" ]; then
                AGREEMENT_ID=$(curl -sf "${CONSUMER_MGMT_URL}/v3/contractnegotiations/${NEGOTIATION_ID}" \
                    -H "x-api-key: ${CONNECTOR_API_KEY}" 2>/dev/null | jq -r '.contractAgreementId' 2>/dev/null)
                echo " FINALIZED"
                echo "  Agreement ID: ${AGREEMENT_ID}"
                break
            elif [ "${NEG_STATE}" = "TERMINATED" ]; then
                ERROR=$(curl -sf "${CONSUMER_MGMT_URL}/v3/contractnegotiations/${NEGOTIATION_ID}" \
                    -H "x-api-key: ${CONNECTOR_API_KEY}" 2>/dev/null | jq -r '.errorDetail // "unknown"' 2>/dev/null)
                echo " FAILED (TERMINATED)"
                echo "  Error: ${ERROR}"
                AGREEMENT_ID=""
                break
            fi
        done
        if [ "${NEG_STATE}" != "FINALIZED" ] && [ "${NEG_STATE}" != "TERMINATED" ]; then
            echo " TIMEOUT (state: ${NEG_STATE})"
            AGREEMENT_ID=""
        fi
    else
        echo "  WARNING: Failed to start negotiation."
        AGREEMENT_ID=""
    fi
else
    echo "Step 15: Skipping negotiation — no offer available."
    AGREEMENT_ID=""
fi
echo ""

# ========================================
# Step 16: Transfer data (HttpData-PULL)
# ========================================
if [ -n "${AGREEMENT_ID:-}" ]; then
    echo "Step 16: Starting data transfer..."

    TRANSFER_RESPONSE=$(curl -sf -X POST "${CONSUMER_MGMT_URL}/v3/transferprocesses" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${CONNECTOR_API_KEY}" \
        -d '{
          "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
          "counterPartyAddress": "http://provider-cp:8084/api/v1/dsp",
          "counterPartyId": "'"${PROVIDER_DID}"'",
          "protocol": "dataspace-protocol-http",
          "contractId": "'"${AGREEMENT_ID}"'",
          "assetId": "test-asset-1",
          "transferType": "HttpData-PULL"
        }' 2>/dev/null) || true

    TRANSFER_ID=$(echo "${TRANSFER_RESPONSE}" | jq -r '.["@id"]' 2>/dev/null)
    if [ -n "${TRANSFER_ID}" ] && [ "${TRANSFER_ID}" != "null" ]; then
        echo "  Transfer started: ${TRANSFER_ID}"

        # Wait for STARTED state + EDR
        echo -n "  Waiting for EDR"
        for i in $(seq 1 30); do
            sleep 2
            echo -n "."
            XFER_STATE=$(curl -sf "${CONSUMER_MGMT_URL}/v3/transferprocesses/${TRANSFER_ID}" \
                -H "x-api-key: ${CONNECTOR_API_KEY}" 2>/dev/null | jq -r '.state' 2>/dev/null) || XFER_STATE=""
            if [ "${XFER_STATE}" = "STARTED" ]; then
                echo " STARTED"
                # Get EDR
                EDR=$(curl -sf "${CONSUMER_MGMT_URL}/v3/edrs/${TRANSFER_ID}/dataaddress" \
                    -H "x-api-key: ${CONNECTOR_API_KEY}" 2>/dev/null) || EDR=""
                if [ -n "${EDR}" ]; then
                    ENDPOINT=$(echo "${EDR}" | jq -r '.endpoint' 2>/dev/null)
                    AUTH_TOKEN=$(echo "${EDR}" | jq -r '.authorization' 2>/dev/null)
                    # Replace Docker hostname with localhost mapped port for host access
                    HOST_ENDPOINT=$(echo "${ENDPOINT}" | sed 's|http://provider-dp:8081|http://localhost:19197|')
                    echo "  Endpoint: ${HOST_ENDPOINT}"
                    echo "  Pulling data..."
                    DATA=$(curl -sf "${HOST_ENDPOINT}" -H "Authorization: ${AUTH_TOKEN}" 2>/dev/null) || DATA=""
                    if [ -n "${DATA}" ]; then
                        echo "  DATA: ${DATA}"
                        echo ""
                        echo "  *** FULL E2E SUCCESS ***"
                    else
                        echo "  WARNING: Data pull returned empty response."
                    fi
                else
                    echo "  WARNING: Could not retrieve EDR."
                fi
                break
            elif [ "${XFER_STATE}" = "TERMINATED" ]; then
                echo " FAILED"
                break
            fi
        done
        if [ "${XFER_STATE}" != "STARTED" ] && [ "${XFER_STATE}" != "TERMINATED" ]; then
            echo " TIMEOUT (state: ${XFER_STATE})"
        fi
    else
        echo "  WARNING: Failed to start transfer."
    fi
else
    echo "Step 16: Skipping transfer — no agreement available."
fi
echo ""

# ========================================
# Summary
# ========================================
echo "================================================================="
echo " Bootstrap Complete!"
echo "================================================================="
echo ""
echo " Provider Stack:"
echo "   DID:   ${PROVIDER_DID}"
echo "   BPN:   ${PROVIDER_BPN}"
echo "   Vault: provider-vault (:8201)"
echo "   DB:    provider-postgres (:6432)"
echo "   IH:    provider-ih (:7181 health, :7292 STS, :7151 identity)"
echo ""
echo " Consumer Stack:"
echo "   DID:   ${CONSUMER_DID}"
echo "   BPN:   ${CONSUMER_BPN}"
echo "   Vault: consumer-vault (:8202)"
echo "   DB:    consumer-postgres (:6433)"
echo "   IH:    consumer-ih (:8182 health, :8293 STS, :8152 identity)"
echo ""
echo " Issuer:  ${ISSUER_DID}"
echo ""
echo " Important connector configuration requirements:"
echo "   - edc.participant.id must be set to the FULL DID (e.g. did:web:provider-ih:provider)"
echo "   - edc.hostname must be the Docker container name (e.g. provider-dp) on data planes"
echo "   - Management API is on port 8081 (provider: 19193, consumer: 29193)"
echo "   - DSP API is on port 8084 (provider: 19194, consumer: 29194)"
echo "   - odrl:assigner in negotiations must be the provider's BPN, not DID"
echo "   - odrl:action must be {\"@id\": \"odrl:use\"} (not plain 'use') for policy comparison"
echo "   - odrl:leftOperand must use full IRI (https://w3id.org/catenax/2025/9/policy/...)"
echo "   - Transfer proxy keys must be EC P-256 JWK JSON format"
echo ""
echo " Next steps:"
echo "   1. Start connectors: docker compose up -d provider-cp provider-dp consumer-cp consumer-dp"
echo "   2. Test: bash scripts/test-transfer.sh"
echo ""
