# 🧪 Tractus-X EDC Manual Testing Guide

This guide provides step-by-step instructions for manually testing your Tractus-X EDC connector, including **extension functionality testing** and **production-ready validation**. Follow these steps to verify everything is working correctly and learn how to use the APIs.

**✅ INCLUDES**: Live data masking extension testing and transformer integration validation.

---

## ⚠️ Security Notice

**This guide uses development credentials that should NEVER be used in production:**

- API Key: `password`
- Database password: `password`
- Vault root token: `root`

These are intentionally weak credentials for local development only. In production, use strong, randomly generated credentials stored securely.

---

## 📋 Prerequisites

Before starting, ensure:

- ✅ Your EDC is running (check terminal for "Runtime ready" message)
- ✅ PostgreSQL and Vault containers are running
- ✅ You have `curl` and `jq` installed (optional for pretty JSON formatting)
- ✅ **Production runtime**: Using `edc-controlplane-postgresql-hashicorp-vault` (160+ extensions loaded)
- ✅ **Extensions**: Verify your extensions are loaded in startup logs

**Quick Status Check:**

```bash
# Check if containers are running
docker ps

# Test basic connectivity
curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/management/v3/assets/request
# Should return 401 (needs API key) or 400 (needs request body)

# ⭐ NEW: Check extension loading (should show 160+ extensions for production runtime)
grep "service extensions" logs/runtime.log
grep "Data Masking Extension" logs/runtime.log  # If using data masking extension
```

---

## 🔐 HashiCorp Vault Operations

Your EDC setup includes HashiCorp Vault running in development mode for storing secrets. Here's how to interact with it:

### Vault Connection Details

- **URL**: http://localhost:8200
- **Root Token**: `root` (development mode only)
- **Status**: Running in development mode (not for production)

### Sign in to Vault

#### Option 1: Web UI

1. Open your browser and go to http://localhost:8200
2. Select "Token" as the authentication method
3. Enter `root` as the token
4. Click "Sign In"

#### Option 2: Command Line (using Docker)

```bash
# Access Vault CLI inside the container
docker exec -it tractusx-edc-vault vault auth -method=token token=root

# Or set environment variables and use vault CLI
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="root"

# Test connection
curl -H "X-Vault-Token: root" http://localhost:8200/v1/sys/health
```

#### Option 3: Install Vault CLI locally

If you have Vault CLI installed on your machine:

```bash
export VAULT_ADDR="http://localhost:8200"
vault auth -method=token token=root
```

### Common Vault Operations

#### Check Vault Status

```bash
curl -s http://localhost:8200/v1/sys/health | jq .
```

#### Store a Secret (for EDC)

```bash
# Store a database password
curl -H "X-Vault-Token: root" -H "Content-Type: application/json" \
  -X POST -d '{"data":{"password":"my-secret-password"}}' \
  http://localhost:8200/v1/secret/data/database

# Store API keys
curl -H "X-Vault-Token: root" -H "Content-Type: application/json" \
  -X POST -d '{"data":{"api-key":"my-api-key","client-secret":"my-client-secret"}}' \
  http://localhost:8200/v1/secret/data/oauth
```

#### Retrieve a Secret

```bash
# Get database password
curl -H "X-Vault-Token: root" \
  http://localhost:8200/v1/secret/data/database | jq .

# Get specific field
curl -H "X-Vault-Token: root" \
  http://localhost:8200/v1/secret/data/database | jq -r '.data.data.password'
```

#### List All Secrets

```bash
curl -H "X-Vault-Token: root" \
  http://localhost:8200/v1/secret/metadata | jq .
```

### Configure EDC to Use Vault Secrets

Update your `dataspaceconnector-configuration.properties` to use Vault for sensitive data:

```properties
# Instead of storing passwords directly
edc.datasource.default.password=password

# Store password in Vault and reference it
edc.vault.hashicorp.url=http://localhost:8200
edc.vault.hashicorp.token=root
edc.datasource.default.password.vault.key=database/password
```

### Test Vault Integration with EDC

1. **Store database credentials in Vault:**

```bash
curl -H "X-Vault-Token: root" -H "Content-Type: application/json" \
  -X POST -d '{"data":{"url":"jdbc:postgresql://localhost:5433/edc","user":"user","password":"password"}}' \
  http://localhost:8200/v1/secret/data/edc-database
```

2. **Store OAuth client secrets:**

```bash
curl -H "X-Vault-Token: root" -H "Content-Type: application/json" \
  -X POST -d '{"data":{"client-id":"my-client","client-secret":"super-secret-key"}}' \
  http://localhost:8200/v1/secret/data/oauth-client
```

3. **Verify secrets are stored:**

```bash
curl -H "X-Vault-Token: root" http://localhost:8200/v1/secret/data/edc-database | jq .data.data
curl -H "X-Vault-Token: root" http://localhost:8200/v1/secret/data/oauth-client | jq .data.data
```

### Vault Security Notes

⚠️ **Important Security Considerations:**

- The current setup uses Vault in **development mode** with a static root token
- Development mode stores data in memory (not persistent)
- For production, you should:
  - Use proper Vault initialization and unsealing
  - Configure authentication methods (LDAP, OIDC, etc.)
  - Set up proper policies and access controls
  - Use persistent storage backends
  - Enable TLS/SSL encryption

### Troubleshooting Vault

#### Vault Container Not Running

```bash
# Check container status
docker ps | grep vault

# Restart vault container
docker-compose restart vault

# Check vault logs
docker logs tractusx-edc-vault
```

#### Vault Connection Issues

```bash
# Test connectivity
curl -s -o /dev/null -w "%{http_code}" http://localhost:8200/v1/sys/health
# Should return 200

# Check if port is accessible
telnet localhost 8200
```

#### Vault UI Not Accessible

- Ensure no firewall is blocking port 8200
- Check if another service is using port 8200
- Verify the container is running with: `docker ps`

---

## 🚀 Phase 1: Basic API Connectivity Tests

### Step 1.1: Test Management API Access

Test if the Management API is accessible:

```bash
# This should return 401 Unauthorized (expected - no API key)
curl -X POST http://localhost:8181/management/v3/assets/request

# This should return 400 Bad Request (expected - no request body)
curl -X POST -H 'X-Api-Key: password' http://localhost:8181/management/v3/assets/request
```

**Expected Results:**

- First command: HTTP 401 or error about missing API key
- Second command: HTTP 400 or error about missing request body
- ✅ **Pass**: Both commands return errors (this confirms the API is running)
- ❌ **Fail**: Connection refused or timeout (EDC not running)

### Step 1.2: Test Basic Query

Test a proper API call:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request
```

**Expected Result:**

- ✅ **Pass**: Returns `[]` (empty array) - no assets created yet
- ❌ **Fail**: Error message or connection issue

---

## 🏗️ Phase 2: Create Basic Resources

### Step 2.1: Create Your First Asset

Copy and run this command to create a test asset:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "dct": "http://purl.org/dc/terms/"
    },
    "@type": "Asset",
    "@id": "my-first-asset",
    "properties": {
      "dct:type": "test-data",
      "name": "My First Asset",
      "description": "This is my first asset for testing",
      "version": "1.0",
      "contenttype": "application/json"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
    }
  }' \
  http://localhost:8181/management/v3/assets
```

**Expected Result:**

```json
{
  "@type": "IdResponse",
  "@id": "my-first-asset",
  "createdAt": 1755175853445,
  "@context": {
    "tx": "https://w3id.org/tractusx/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

✅ **Pass**: Asset created successfully with ID response  
❌ **Fail**: Error message about validation or format

### Step 2.2: Verify Asset Creation

Check if your asset was created:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request | jq .
```

**Expected Result:**

- You should see an array with one asset object
- The asset should have ID `"my-first-asset"`
- Properties should match what you created

### Step 2.3: Create an Access Policy

Create a policy that allows anyone to access data:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
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
  }' \
  http://localhost:8181/management/v3/policydefinitions
```

**Expected Result:**

- Should return `IdResponse` with ID `"open-access-policy"`

### Step 2.4: Create a Contract Policy

Create a contract policy (can be the same as access policy for testing):

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
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
  }' \
  http://localhost:8181/management/v3/policydefinitions
```

### Step 2.5: Verify Policies

Check your created policies:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/policydefinitions/request | jq .
```

**Expected Result:**

- Should show 2 policies: `open-access-policy` and `simple-contract-policy`

### Step 2.6: Create a Contract Definition

Connect your asset with the policies:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "ContractDefinition",
    "@id": "my-first-contract-definition",
    "accessPolicyId": "open-access-policy",
    "contractPolicyId": "simple-contract-policy",
    "assetsSelector": [{
      "@type": "Criterion",
      "operandLeft": "id",
      "operator": "=",
      "operandRight": "my-first-asset"
    }]
  }' \
  http://localhost:8181/management/v3/contractdefinitions
```

**Expected Result:**

- Should return `IdResponse` with ID `"my-first-contract-definition"`

---

## 🔍 Phase 3: Verification Tests

### Step 3.1: Check All Resources

Verify all resources were created:

```bash
echo "=== ASSETS ==="
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request | jq .[].\"@id\"

echo -e "\n=== POLICIES ==="
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/policydefinitions/request | jq .[].\"@id\"

echo -e "\n=== CONTRACT DEFINITIONS ==="
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/contractdefinitions/request | jq .[].\"@id\"
```

**Expected Result:**

```
=== ASSETS ===
"my-first-asset"

=== POLICIES ===
"open-access-policy"
"simple-contract-policy"

=== CONTRACT DEFINITIONS ===
"my-first-contract-definition"
```

### Step 3.2: Test Catalog Request

Request your own catalog to see the data offer:

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{
    "@context": ["https://w3id.org/dspace/2024/1/context.json"],
    "@type": "dspace:CatalogRequestMessage",
    "dspace:filter": {}
  }' \
  http://localhost:8080/api/dsp/catalog/request | jq .
```

**Expected Result:**

- Should return a catalog with your asset as a `dcat:Dataset`
- The dataset should reference your asset and policies

---

## 🧪 Phase 7: Extension Functionality Testing ⭐ **NEW**

### Step 7.1: Test Data Masking Extension (if enabled)

If you have the data masking extension loaded, test its functionality:

#### Create Asset with Sensitive Data

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "dct": "http://purl.org/dc/terms/"
    },
    "@type": "Asset",
    "@id": "sensitive-data-asset",
    "properties": {
      "dct:type": "sensitive-data",
      "name": "Asset with Sensitive Information",
      "description": "Testing data masking functionality",
      "businessPartnerNumber": "BPN123456789",
      "email": "john.doe@sensitive.com",
      "phone": "+1-555-123-4567",
      "creditCard": "4532-1234-5678-9012"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/users/1"
    }
  }' \
  http://localhost:8181/management/v3/assets
```

#### Verify Data Masking in API Response

```bash
# Retrieve the asset - sensitive data should be masked
curl -X GET "http://localhost:8181/management/v3/assets/sensitive-data-asset" \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" | jq '."https://w3id.org/edc/v0.0.1/ns/properties"'
```

**Expected Results for Data Masking:**

```json
{
  "businessPartnerNumber": "B***9",
  "email": "j***@s***.com",
  "phone": "+***7",
  "creditCard": "4***2",
  "name": "Asset with Sensitive Information",
  "description": "Testing data masking functionality"
}
```

✅ **Pass**: Sensitive fields are masked (BPN, email, phone, creditCard)  
❌ **Fail**: Sensitive data appears unmasked

#### Test Different Masking Scenarios

```bash
# Create asset with various sensitive patterns
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "masking-test-asset",
    "properties": {
      "name": "Masking Test Asset",
      "customerEmail": "customer@company.com",
      "supportEmail": "support@example.org",
      "businessPartnerNumber": "BPNL000000000123",
      "alternativeContact": "contact@business.de",
      "publicInfo": "This should not be masked"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://httpbin.org/json"
    }
  }' \
  http://localhost:8181/management/v3/assets

# Verify masking
curl -X GET "http://localhost:8181/management/v3/assets/masking-test-asset" \
  -H "X-Api-Key: password" | jq '."https://w3id.org/edc/v0.0.1/ns/properties"'
```

### Step 7.2: Test Extension Configuration

Verify extension configuration is working:

```bash
# Check if data masking configuration is loaded
grep "datamasking" logs/runtime.log
grep "PARTIAL\|FULL\|NONE" logs/runtime.log

# Test configuration values through runtime behavior
echo "Testing extension configuration through API responses..."
```

### Step 7.3: Test Extension Integration

Verify extension integrates properly with EDC:

```bash
# List all assets and verify masking is applied consistently
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request | jq '.[] | {"id": ."@id", "properties": ."https://w3id.org/edc/v0.0.1/ns/properties"}'

# Test that non-sensitive data remains unchanged
curl -X GET "http://localhost:8181/management/v3/assets/my-first-asset" \
  -H "X-Api-Key: password" | jq '."https://w3id.org/edc/v0.0.1/ns/properties"'
```

**Extension Integration Success Indicators:**

- ✅ Sensitive data is consistently masked across all API responses
- ✅ Non-sensitive data remains unchanged
- ✅ Extension configuration is properly loaded
- ✅ No errors in extension initialization logs
- ✅ Transformer integration working (JsonObjectAssetMaskingTransformer registered)

---

## 🏗️ Phase 8: Production Runtime Validation ⭐ **NEW**

### Step 4.1: Create Additional Assets

Create a few more assets with different properties:

```bash
# Asset 2: Different type
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "csv-data-asset",
    "properties": {
      "name": "CSV Dataset",
      "description": "Sample CSV data",
      "contenttype": "text/csv",
      "category": "sample-data"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://people.sc.fsu.edu/~jburkardt/data/csv/cities.csv"
    }
  }' \
  http://localhost:8181/management/v3/assets

# Asset 3: With private properties
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "private-asset",
    "properties": {
      "name": "Asset with Private Properties",
      "description": "This asset has private properties"
    },
    "privateProperties": {
      "internalId": "INTERNAL-123",
      "owner": "test-department",
      "classification": "internal-use-only"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/posts/1"
    }
  }' \
  http://localhost:8181/management/v3/assets
```

### Step 4.2: Test Filtering

Test filtering assets by properties:

```bash
# Find assets by name pattern
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "QuerySpec",
    "filterExpression": [{
      "operandLeft": "name",
      "operator": "like",
      "operandRight": ".*CSV.*"
    }]
  }' \
  http://localhost:8181/management/v3/assets/request | jq .

# Find assets by content type
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "QuerySpec",
    "filterExpression": [{
      "operandLeft": "contenttype",
      "operator": "=",
      "operandRight": "application/json"
    }]
  }' \
  http://localhost:8181/management/v3/assets/request | jq .
```

### Step 4.3: Test Limit and Offset

Test pagination:

```bash
# Get first 2 assets
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "QuerySpec",
    "limit": 2,
    "offset": 0
  }' \
  http://localhost:8181/management/v3/assets/request | jq length

# Get next assets
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "QuerySpec",
    "limit": 2,
    "offset": 2
  }' \
  http://localhost:8181/management/v3/assets/request | jq length
```

### Step 8.1: Verify Production Runtime

Confirm you're running the full Tractus-X production stack:

```bash
# Check extension count (should be 160+ for production runtime)
grep "Starting [0-9]* service extensions" logs/runtime.log

# Verify critical Tractus-X extensions are loaded
grep -E "(BPN|Agreement|Policy|Vault|PostgreSQL)" logs/runtime.log

# Check database connectivity
grep "DataSource" logs/runtime.log
grep "PostgreSQL" logs/runtime.log

# Check vault integration
grep -i vault logs/runtime.log
```

**Expected Production Indicators:**

- ✅ 160+ service extensions loaded
- ✅ PostgreSQL DataSource initialized successfully
- ✅ HashiCorp Vault integration active
- ✅ BPN validation extension loaded
- ✅ Agreement retirement extension loaded
- ✅ All Tractus-X specific extensions operational

### Step 8.2: Test Full Stack Integration

Test integration between all components:

```bash
# Test database persistence (create and restart to verify persistence)
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "persistence-test-asset",
    "properties": {"name": "Database Persistence Test"},
    "dataAddress": {"@type": "DataAddress", "type": "HttpData", "baseUrl": "http://example.com"}
  }' \
  http://localhost:8181/management/v3/assets

echo "Asset created. Restart EDC and verify it persists..."
```

### Step 8.3: Performance Testing

Test performance with production runtime:

```bash
# Create multiple assets quickly
for i in {1..10}; do
  curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
    -d "{
      \"@context\": {\"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\"},
      \"@type\": \"Asset\",
      \"@id\": \"perf-test-asset-$i\",
      \"properties\": {\"name\": \"Performance Test Asset $i\"},
      \"dataAddress\": {\"@type\": \"DataAddress\", \"type\": \"HttpData\", \"baseUrl\": \"http://example.com/$i\"}
    }" \
    http://localhost:8181/management/v3/assets &
done
wait

# Test query performance
time curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request >/dev/null
```

---

## 🧪 Phase 4: Advanced Testing (Enhanced)

### Step 5.1: Test Invalid Requests

Test how the API handles errors:

```bash
# Missing API key
curl -X POST -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request

# Invalid JSON
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d 'invalid-json' \
  http://localhost:8181/management/v3/assets/request

# Missing required fields
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset"
  }' \
  http://localhost:8181/management/v3/assets
```

**Expected Results:**

- Should return appropriate HTTP error codes (401, 400, etc.)
- Error messages should be descriptive

### Step 5.2: Test Duplicate IDs

Try to create an asset with an existing ID:

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "my-first-asset",
    "properties": {"name": "Duplicate Asset"},
    "dataAddress": {"@type": "DataAddress", "type": "HttpData", "baseUrl": "http://example.com"}
  }' \
  http://localhost:8181/management/v3/assets
```

**Expected Result:**

- Should return an error about duplicate ID or existing resource

---

## 📊 Phase 6: Resource Management

### Step 6.1: Get Individual Resources

Test retrieving specific resources by ID:

```bash
# Get specific asset
curl -H 'X-Api-Key: password' \
  http://localhost:8181/management/v3/assets/my-first-asset

# Get specific policy
curl -H 'X-Api-Key: password' \
  http://localhost:8181/management/v3/policydefinitions/open-access-policy

# Get specific contract definition
curl -H 'X-Api-Key: password' \
  http://localhost:8181/management/v3/contractdefinitions/my-first-contract-definition
```

### Step 6.2: Update Resources (if supported)

Test updating an asset:

```bash
curl -X PUT -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "my-first-asset",
    "properties": {
      "name": "My Updated First Asset",
      "description": "This asset has been updated",
      "version": "2.0"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
    }
  }' \
  http://localhost:8181/management/v3/assets
```

### Step 6.3: Delete Resources

Test deleting resources:

```bash
# Delete an asset (be careful!)
curl -X DELETE -H 'X-Api-Key: password' \
  http://localhost:8181/management/v3/assets/csv-data-asset

# Verify deletion
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request | jq 'length'
```

---

## ✅ Testing Checklist (Updated)

Use this checklist to track your progress:

### Basic Functionality

- [ ] Management API responds to requests
- [ ] Can create assets successfully
- [ ] Can create policies successfully
- [ ] Can create contract definitions successfully
- [ ] Can list all resource types
- [ ] Resources appear in catalog

### Extension Functionality ⭐ **NEW**

- [ ] Data masking extension loaded (if applicable)
- [ ] Sensitive data is masked in API responses
- [ ] businessPartnerNumber masking works (BPN123456789 → B\*\*\*9)
- [ ] Email masking works (test@example.com → t**_@e_**.com)
- [ ] Non-sensitive data remains unchanged
- [ ] Extension configuration loaded correctly
- [ ] Transformer integration working (JsonObjectAssetMaskingTransformer)

### Production Runtime Validation ⭐ **NEW**

- [ ] 160+ service extensions loaded
- [ ] PostgreSQL database connectivity confirmed
- [ ] HashiCorp Vault integration active
- [ ] BPN validation extension operational
- [ ] Agreement retirement extension loaded
- [ ] All Tractus-X extensions functional
- [ ] Database persistence working
- [ ] Performance acceptable under load

### Advanced Features

- [ ] Filtering works correctly
- [ ] Pagination (limit/offset) works
- [ ] Private properties are handled correctly
- [ ] Different data address types work

### Error Handling

- [ ] Invalid API key returns 401
- [ ] Malformed JSON returns 400
- [ ] Missing required fields return validation errors
- [ ] Duplicate IDs are handled appropriately

### Resource Management

- [ ] Individual resources can be retrieved
- [ ] Resources can be updated (if supported)
- [ ] Resources can be deleted
- [ ] Deletions are reflected in listings

---

## 🚨 Common Issues and Solutions

### Issue: "Connection refused"

**Solution:** Check if EDC is running and PostgreSQL/Vault containers are up

```bash
docker ps
ps aux | grep java
```

### Issue: "Invalid JSON-LD context"

**Solution:** Make sure to include proper `@context` in all requests

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  }
}
```

### Issue: Policy validation errors

**Solution:** Ensure policies use `odrl:Set` type and proper action format

```json
{
  "@type": "odrl:Set",
  "odrl:permission": [
    {
      "odrl:action": {
        "odrl:type": "http://www.w3.org/ns/odrl/2/use"
      }
    }
  ]
}
```

### Issue: Data masking not working ⭐ **NEW**

**Solution:** Check extension loading and transformer registration

```bash
# Check if data masking extension loaded
grep "Data Masking Extension" logs/runtime.log

# Check transformer registration
grep "JsonObjectAssetMaskingTransformer" logs/runtime.log
grep "TypeTransformerRegistry" logs/runtime.log

# Verify configuration
grep "datamasking" logs/runtime.log
```

### Issue: Extension not loading ⭐ **NEW**

**Solution:** Verify extension registration and dependencies

```bash
# Check META-INF service registration
find edc-extensions -name "org.eclipse.edc.spi.system.ServiceExtension" -exec cat {} \;

# Check build configuration
grep "runtimeOnly.*data-masking" edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build.gradle.kts

# Check settings.gradle.kts includes extension
grep "data-masking" settings.gradle.kts
```

### Issue: Wrong runtime type ⭐ **NEW**

**Solution:** Ensure using production runtime, not memory runtime

```bash
# Check which runtime you're using
ps aux | grep java | grep -E "(memory|postgresql|vault)"

# Should be using: edc-controlplane-postgresql-hashicorp-vault
# Should NOT be using: edc-runtime-memory
```

---

## 🎯 Success Criteria (Enhanced)

After completing this guide, you should have:

1. ✅ Successfully created assets, policies, and contract definitions
2. ✅ Verified all resources appear in API responses
3. ✅ Tested filtering and pagination
4. ✅ Confirmed your data offers appear in the catalog
5. ✅ Handled various error conditions gracefully
6. ✅ Demonstrated CRUD operations on resources
7. ✅ **NEW**: Validated extension functionality (data masking)
8. ✅ **NEW**: Confirmed production runtime (160+ extensions)
9. ✅ **NEW**: Verified transformer integration working
10. ✅ **NEW**: Tested live API masking with sensitive data

**Production Success Indicators:**

- ✅ businessPartnerNumber: "BPN123456789" → "B\*\*\*9"
- ✅ email: "test@example.com" → "t**_@e_**.com"
- ✅ PostgreSQL persistence working
- ✅ HashiCorp Vault integration active
- ✅ All Tractus-X extensions operational

**Congratulations!** 🎉 Your Tractus-X EDC is **production-ready** and fully functional for data sharing scenarios with advanced extension capabilities.

## 🎯 Comprehensive System Validation

For complete system validation and detailed success metrics, run the comprehensive validation script:

```bash
./FINAL-SUCCESS-REPORT.sh
```

**This validation script provides:**

- 📊 Complete infrastructure health checks (PostgreSQL, Vault, all EDC APIs)
- 🔧 Extension loading verification (160+ service extensions)
- 🧪 Live API testing with real data masking examples
- 📋 Production readiness assessment
- 🏆 Comprehensive achievement summary
- 🔐 Security feature validation

**Sample validation output includes:**

- Real data masking examples: `BPN123456789 → B***9`
- API endpoint testing across all management interfaces
- Extension capability verification
- Performance and scalability metrics

---

## 📚 Next Steps (Enhanced)

### Extension Development

- Explore developing your own extensions using our [Extension Creation Guide](docs/EXTENSION_CREATION_GUIDE.md)
- Study the [Data Masking Extension](edc-extensions/data-masking/README.md) as a reference implementation
- Follow [Extension Quick Reference](docs/EXTENSION_QUICK_REFERENCE.md) for patterns and templates

### Advanced Integration

- Explore connecting to another EDC connector
- Test contract negotiation workflows
- Implement data transfer scenarios with masked data
- Add more complex policies with constraints
- Integrate with real data sources

### Production Deployment

- Configure production-grade PostgreSQL database
- Set up production HashiCorp Vault with proper authentication
- Implement proper TLS/SSL certificates
- Configure monitoring and logging
- Test with real Tractus-X network participants

**Happy Testing!** 🚀

---

**🎯 Pro Tip**: The data masking extension showcased in this guide demonstrates a complete production-ready extension with transformer integration - use it as your reference for developing similar extensions!
