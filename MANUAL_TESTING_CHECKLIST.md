# 🧪 Manual API Testing Checklist

# Step-by-Step EDC API Endpoint Testing

## 📋 **Testing Instructions**

Copy and paste each command into your terminal. Check the expected results after each step.

---

## **🚀 STEP 1: Basic Connectivity Test**

**Description**: Test if EDC Management API is running and accessible  
**Expected Result**: Empty array `[]` (no assets exist yet)

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}' \
  "http://localhost:8181/management/v3/assets/request"
```

**✅ PASS if**: Returns `[]`  
**❌ FAIL if**: Connection refused, 401 error, or timeout

---

## **📜 STEP 2: List Existing Policies**

**Description**: Check if any policies already exist  
**Expected Result**: Empty array `[]` (no policies exist yet)

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}' \
  "http://localhost:8181/management/v3/policydefinitions/request"
```

**✅ PASS if**: Returns `[]`  
**❌ FAIL if**: Error or unexpected response

---

## **📋 STEP 3: List Existing Contract Definitions**

**Description**: Check if any contract definitions already exist  
**Expected Result**: Empty array `[]` (no contract definitions exist yet)

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}' \
  "http://localhost:8181/management/v3/contractdefinitions/request"
```

**✅ PASS if**: Returns `[]`  
**❌ FAIL if**: Error or unexpected response

---

## **📄 STEP 4: Create First Test Asset**

**Description**: Create a test asset with JSON data  
**Expected Result**: IdResponse with `"@id": "test-asset-1"` and `createdAt` timestamp

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{
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
  }' \
  "http://localhost:8181/management/v3/assets"
```

**✅ PASS if**: Returns IdResponse like:

```json
{
  "@type": "IdResponse",
  "@id": "test-asset-1",
  "createdAt": 1694234567890,
  "@context": {...}
}
```

**❌ FAIL if**: Error about validation, duplicate ID, or malformed request

---

## **🔍 STEP 5: Verify Asset Creation**

**Description**: List assets again to confirm the asset was created  
**Expected Result**: Array with 1 asset containing your test asset

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}' \
  "http://localhost:8181/management/v3/assets/request"
```

**✅ PASS if**: Returns array with 1 asset object containing `"@id": "test-asset-1"`  
**❌ FAIL if**: Still returns empty array or error

---

## **🎯 STEP 6: Get Specific Asset by ID**

**Description**: Retrieve the specific asset using its ID  
**Expected Result**: Full asset object with all properties

```bash
curl -H "X-Api-Key: password" \
  "http://localhost:8181/management/v3/assets/test-asset-1"
```

**✅ PASS if**: Returns complete asset object with properties and dataAddress  
**❌ FAIL if**: 404 error or asset not found

---

## **📜 STEP 7: Create Access Policy**

**Description**: Create an open access policy using ODRL format  
**Expected Result**: IdResponse with policy ID

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
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
  "http://localhost:8181/management/v3/policydefinitions"
```

**✅ PASS if**: Returns IdResponse with `"@id": "open-access-policy"`  
**❌ FAIL if**: Policy validation error or malformed ODRL

---

## **📜 STEP 8: Create Contract Policy**

**Description**: Create a contract policy (can be same as access policy for testing)  
**Expected Result**: IdResponse with contract policy ID

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
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
  "http://localhost:8181/management/v3/policydefinitions"
```

**✅ PASS if**: Returns IdResponse with `"@id": "simple-contract-policy"`  
**❌ FAIL if**: Policy validation error

---

## **🔍 STEP 9: Verify Policies Created**

**Description**: List all policies to confirm both were created  
**Expected Result**: Array with 2 policy objects

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}' \
  "http://localhost:8181/management/v3/policydefinitions/request"
```

**✅ PASS if**: Returns array with 2 policies: `open-access-policy` and `simple-contract-policy`  
**❌ FAIL if**: Wrong number of policies or missing policies

---

## **📋 STEP 10: Create Contract Definition**

**Description**: Link the asset with policies via a contract definition  
**Expected Result**: IdResponse with contract definition ID

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{
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
  }' \
  "http://localhost:8181/management/v3/contractdefinitions"
```

**✅ PASS if**: Returns IdResponse with `"@id": "test-contract-def-1"`  
**❌ FAIL if**: Validation error about missing policies or malformed selector

---

## **🔍 STEP 11: Verify Contract Definition**

**Description**: List contract definitions to confirm creation  
**Expected Result**: Array with 1 contract definition

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":5}' \
  "http://localhost:8181/management/v3/contractdefinitions/request"
```

**✅ PASS if**: Returns array with 1 contract definition object  
**❌ FAIL if**: Empty array or error

---

## **📚 STEP 12: Request Own Catalog**

**Description**: Request the connector's catalog to see available data offers  
**Expected Result**: Catalog object containing dataset offers

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
    },
    "@type": "CatalogRequest",
    "counterPartyAddress": "http://localhost:8080/api/dsp",
    "protocol": "dataspace-protocol-http"
  }' \
  "http://localhost:8181/management/v3/catalog/request"
```

**✅ PASS if**: Returns catalog object with `dcat:dataset` array containing your asset  
**❌ FAIL if**: Empty catalog or error

---

## **🌐 STEP 13: Test DSP Catalog Endpoint**

**Description**: Test the Dataspace Protocol catalog endpoint (inter-connector communication)  
**Expected Result**: DSP-formatted catalog response

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{
    "@context": [
      "https://w3id.org/dspace/2024/1/context.json"
    ],
    "@type": "dspace:CatalogRequestMessage",
    "dspace:filter": {}
  }' \
  "http://localhost:8080/api/dsp/catalog/request"
```

**✅ PASS if**: Returns catalog in DSP format  
**❌ FAIL if**: Error or malformed response

---

## **❌ STEP 14: Test Error Handling - No API Key**

**Description**: Test what happens when API key is missing  
**Expected Result**: 401 Unauthorized error

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}' \
  "http://localhost:8181/management/v3/assets/request"
```

**✅ PASS if**: Returns 401 Unauthorized or authentication error  
**❌ FAIL if**: Request succeeds without API key

---

## **❌ STEP 15: Test Error Handling - Duplicate Asset**

**Description**: Try to create asset with same ID (should fail)  
**Expected Result**: 400 Bad Request or validation error

```bash
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "test-asset-1",
    "properties": {"name": "Duplicate Asset"},
    "dataAddress": {"@type": "DataAddress", "type": "HttpData", "baseUrl": "http://example.com"}
  }' \
  "http://localhost:8181/management/v3/assets"
```

**✅ PASS if**: Returns 400 error about duplicate ID or conflict  
**❌ FAIL if**: Creates duplicate asset successfully

---

## **🎉 Testing Complete!**

If all 15 steps passed, your EDC is working correctly! You have successfully:

✅ **Verified API connectivity**  
✅ **Created and managed assets**  
✅ **Created and managed policies**  
✅ **Created contract definitions**  
✅ **Tested catalog functionality**  
✅ **Tested DSP protocol endpoints**  
✅ **Verified error handling**

## **📋 Quick Status Commands**

After testing, you can use these commands to check your EDC state:

```bash
# Count assets
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}' \
  "http://localhost:8181/management/v3/assets/request" | jq length

# Count policies
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}' \
  "http://localhost:8181/management/v3/policydefinitions/request" | jq length

# Count contract definitions
curl -X POST -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}' \
  "http://localhost:8181/management/v3/contractdefinitions/request" | jq length
```

**Expected Results**: 1 asset, 2 policies, 1 contract definition

Your EDC is now ready for data sharing scenarios! 🚀
