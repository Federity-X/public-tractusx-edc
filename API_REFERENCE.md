# Tractus-X EDC API Reference Card

## 🚀 Your EDC is running successfully!

### 📋 Quick Status Check

- **Control Plane**: ✅ Running on ports 8080 (Protocol), 8181 (Management)
- **Data Plane**: ✅ Running on port 8081 (Public), 8186 (Consumer Proxy)
- **PostgreSQL**: ✅ Running on port 5433
- **HashiCorp Vault**: ✅ Running on port 8200

---

## 🔧 API Endpoints

### Management API (Port 8181)

**Base URL**: `http://localhost:8181/management`
**Auth**: `X-Api-Key: password`

| Resource              | Endpoint                           | Method        |
| --------------------- | ---------------------------------- | ------------- |
| Assets                | `/v3/assets/request`               | POST (list)   |
| Assets                | `/v3/assets`                       | POST (create) |
| Policies              | `/v3/policydefinitions/request`    | POST (list)   |
| Policies              | `/v3/policydefinitions`            | POST (create) |
| Contract Definitions  | `/v3/contractdefinitions/request`  | POST (list)   |
| Contract Definitions  | `/v3/contractdefinitions`          | POST (create) |
| Transfer Processes    | `/v3/transferprocesses/request`    | POST (list)   |
| Contract Negotiations | `/v3/contractnegotiations/request` | POST (list)   |
| EDRs                  | `/v3/edrs/request`                 | POST (list)   |

### Protocol API (Port 8080)

**Base URL**: `http://localhost:8080/api`

| Resource    | Endpoint               | Method |
| ----------- | ---------------------- | ------ |
| DSP Catalog | `/dsp/catalog/request` | POST   |

---

## 🛠️ Quick Commands

### 1. List All Assets

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request
```

### 2. Create a Test Asset

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
    "@type": "Asset",
    "@id": "my-test-asset",
    "properties": {
      "name": "My Test Asset",
      "description": "A test asset for demo"
    },
    "dataAddress": {
      "@type": "DataAddress",
      "type": "HttpData",
      "baseUrl": "https://jsonplaceholder.typicode.com/todos/1"
    }
  }' \
  http://localhost:8181/management/v3/assets
```

### 3. Create a Simple Policy

```bash
curl -X POST -H 'X-Api-Key: password' -H 'Content-Type: application/json' \
  -d '{
    "@context": {
      "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
      "odrl": "http://www.w3.org/ns/odrl/2/"
    },
    "@type": "PolicyDefinition",
    "@id": "allow-all-policy",
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

---

## 🎯 Testing Scripts Available

1. **`./test-endpoints.sh`** - Test all API endpoints
2. **`./edc-demo.sh`** - Complete demo creating assets, policies, and contract definitions
3. **`./setup-dev-env.sh`** - Start PostgreSQL and Vault services
4. **`./stop-dev-env.sh`** - Stop the services

---

## 📚 Documentation Links

- [Tractus-X EDC Control Plane API](https://eclipse-tractusx.github.io/tractusx-edc/openapi/control-plane-api/)
- [Tractus-X EDC Data Plane API](https://eclipse-tractusx.github.io/tractusx-edc/openapi/data-plane-api/)
- [Management API Walkthrough](./docs/usage/management-api-walkthrough/README.md)

---

## 🔍 Key Concepts

- **Assets**: Data or services you want to share
- **Policies**: Rules governing access (access policy) and usage (contract policy)
- **Contract Definitions**: Connect assets with policies to create data offers
- **Catalog**: Publicly visible data offers that consumers can negotiate for
- **EDRs**: Endpoint Data References - tokens for accessing data after successful negotiation

---

## 🛑 Troubleshooting

- **Database issues**: Check if PostgreSQL is running on port 5433
- **Vault issues**: Check if HashiCorp Vault is running on port 8200
- **API not responding**: Ensure the EDC application is running (check terminal)
- **Invalid JSON-LD**: Make sure to include proper `@context` in request bodies

---

✅ **Your Tractus-X EDC is ready for data sharing!**
