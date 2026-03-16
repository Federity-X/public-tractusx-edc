# did-document-service-dim

## Overview
This extension provides a client for managing DID Document Service entries using the DIM (Decentralized Identity Management) API.
It enables secure and programmatic updates to DID Documents for organizations using the TractusX ecosystem.
The client's purpose is to be injected in the `did-document-service-self-registration` extension by implementing the `DidDocumentServiceClient` SPI.

## API Details

### 1. Add DID Document Service
- **Endpoint:** `PATCH {dimUrl}/api/v2.0.0/companyIdentities/{companyIdentityId}`
- **Description:** Adds or replaces a service entry in the DID Document.
- **Sample Request:**

```json
{
  "didDocUpdates": {
    "addServices": [
      {
        "id": "did:web:example.com:123#DataService",
        "serviceEndpoint": "https://edc.com/edc/.well-known/dspace-version",
        "type": "DataService"
      }
    ]
  }
}
```
- **Sample Response:**
```json
{
  "updateDidRequest": {
    "didDocUpdates": {
      "addServices": [
        {
          "id": "did:web:example.com:123#DataService",
          "serviceEndpoint": "https://edc.com/edc/.well-known/dspace-version",
          "type": "DataService"
        }
      ]
    },
    "success": true
  }
}
```

### 2. Delete DID Document Service
- **Endpoint:** `PATCH {dimUrl}/api/v2.0.0/companyIdentities/{companyIdentityId}`
- **Description:** Removes a service entry from the DID Document.
- **Sample Request:**
```json
{
  "didDocUpdates": {
    "removeServices": [
      "did:web:example.com:123#DataService"
    ]
  }
}
```
- **Sample Response:**
```json
{
  "updateDidRequest": {
    "didDocUpdates": {
      "removeServices": [
        "did:web:example.com:123#DataService"
      ]
    },
    "success": true
  }
}
```

### 3. Update Patch Status
- **Endpoint:** `PATCH {dimUrl}/api/v2.0.0/companyIdentities/{companyIdentityId}/status`
- **Description:** Finalizes the update operation for the DID Document. This API call must be made after adding or deleting services.
- **Sample Response:**
```json
{
  "operation": "update",
  "status": "successful"
}
```

### 4. Resolve Company Identity
- **Endpoint:** `GET {dimUrl}/api/v2.0.0/companyIdentities?$filter=issuerDID eq "{ownDid}"`
- **Description:** Resolves the company identity ID for the given DID. All DID Document Service operations require the company identity ID.
- **Sample Response:**
```json
{
  "count": 1,
  "data": [
    {
      "id": "ddfdcbad-44b2-43b5-b49f-6347ec2e586a",
      "issuerDID": "did:web:example.com:ABC123",
      "isPrivate": false,
      "name": "ABC123",
      "lastOperationStatus": {
        "lastChanged": "2025-12-09T10:28:27.828Z",
        "operation": "update",
        "status": "successful"
      },
      "allOperationStatuses": [],
      "downloadURL": "https://div.example.com/did-document/91f6954d-b3c8-474a-ad97-59b52cff1f60/did-web/bf618a73df14b6da49c41215fcd920516ad2dbab6922568dc78c59100ec98d9b",
      "application": [
        "provider"
      ],
      "isSelfHosted": true
    }
  ]
}
```
> All APIs require authentication using an authentication token generated via DIM.

## Activation

This extension activates when **all** of the following conditions are met:

1. `tx.edc.did.service.client.type` is set to `dim`
2. `tx.edc.iam.sts.dim.url` is configured
3. A `DimOauth2Client` implementation is available

If any condition is not met, the extension logs an informational or warning message and does not register a client.

## Configuration

| Property | Required | Description |
|----------|----------|-------------|
| `tx.edc.did.service.client.type` | No | Must be set to `dim` to activate this extension |
| `tx.edc.iam.sts.dim.url` | No | STS DIM endpoint URL |
| `edc.participant.id` | Yes | The DID / participant ID of this connector |

> All optional properties participate in the extension's own validation logic.
> The extension gracefully skips registration if any required setting is missing.

## Client Type Selector

The property `tx.edc.did.service.client.type` controls which `DidDocumentServiceClient` implementation is active.
Both the DIM and IdentityHub extensions read this property:

- `tx.edc.did.service.client.type=dim` → DIM client activates.
- `tx.edc.did.service.client.type=identityhub` → IdentityHub client activates.
- Not set → no client is registered, self-registration is a no-op.

This design ensures clean separation: each extension only checks its own type and config,
with no cross-references to other extensions' settings.

## Helm Configuration

```yaml
iatp:
  didService:
    clientType: "dim"
    selfRegistration:
      enabled: true
      id: "did:web:example.com:connector#DataService"
```
