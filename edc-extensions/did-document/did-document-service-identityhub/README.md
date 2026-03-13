# did-document-service-identityhub

## Overview
This extension provides a client for managing DID Document Service entries using the **IdentityHub Identity API**.
It implements the `DidDocumentServiceClient` SPI, enabling the `did-document-service-self-registration` extension
to automatically register and deregister DSP endpoints in DID Documents for deployments that use
[Eclipse Tractus-X IdentityHub](https://github.com/eclipse-tractusx/tractusx-identityhub) as their wallet.

This is the alternative to the `did-document-service-dim` module, which targets SAP DIM wallets.

## API Details

### 1. Add DID Document Service (Create)
- **Endpoint:** `POST {identityApiUrl}/v1alpha/participants/{participantB64}/dids/{didB64}/endpoints?autoPublish=true`
- **Auth:** `x-api-key` header
- **Path parameters:** Standard Base64 encoding of participant context ID and DID
- **Description:** Creates a service entry in the DID Document. Returns 409 if the entry already exists (treated as success for idempotency).
- **Sample Request Body:**

```json
{
  "id": "dsp-endpoint",
  "type": "DataService",
  "serviceEndpoint": "https://connector.company.com/edc/.well-known/dspace-version"
}
```

### 2. Delete DID Document Service
- **Endpoint:** `DELETE {identityApiUrl}/v1alpha/participants/{participantB64}/dids/{didB64}/endpoints/{serviceId}?autoPublish=true`
- **Auth:** `x-api-key` header
- **Description:** Removes a service entry from the DID Document. Returns 404 if the entry does not exist (treated as success for idempotency).

### Update Behavior
The `update()` method performs a delete-then-create sequence, ensuring the endpoint URL is always current.
Both 404 on delete and 409 on create are tolerated for idempotent behavior.

## Configuration

| Property | Required | Default | Description |
|----------|----------|---------|-------------|
| `tx.edc.ih.api.url` | Yes | — | IdentityHub Identity API base URL (e.g., `http://provider-ih:15151/api/identity`) |
| `tx.edc.ih.api.key` | Yes | — | API key for IdentityHub Identity API authentication |
| `tx.edc.ih.participant.context.id` | Yes | — | IdentityHub participant context ID (short name, e.g., `provider`) |
| `edc.iam.issuer.id` | Yes | — | The DID of this connector's participant (e.g., `did:web:provider-ih:provider`) |

> **Note:** If `tx.edc.ih.api.url` is not configured, the extension logs an info message and does not register a client,
> allowing other implementations (e.g., the DIM client) to be used instead.

## Usage with Self-Registration

This module is designed to work with the `did-document-service-self-registration` extension.
Include both modules in your control plane build and configure the self-registration properties:

```properties
# Enable self-registration
tx.edc.did.service.self.registration.enabled=true
tx.edc.did.service.self.registration.id=dsp-endpoint
tx.edc.did.service.self.deregistration.enabled=true

# IdentityHub client settings
tx.edc.ih.api.url=http://provider-ih:15151/api/identity
tx.edc.ih.api.key=c3VwZXItdXNlcg==.superuserkey
tx.edc.ih.participant.context.id=provider
```

## Comparison with DIM Client

| Aspect | IdentityHub Client (this module) | DIM Client |
|--------|----------------------------------|------------|
| Wallet | Eclipse Tractus-X IdentityHub | SAP DIM (Decentralized Identity Management) |
| API | REST (POST/DELETE per endpoint) | PATCH (batch add/remove services + status update) |
| Auth | `x-api-key` header | OAuth2 token |
| Idempotency | Tolerates 409 on create, 404 on delete | Handled by DIM API |
| Use case | Local/dev deployments, open-source wallets | SAP-managed production environments |

## Module Dependencies

```kotlin
implementation(project(":spi:did-document-service-spi"))
implementation(libs.edc.runtime.metamodel)
implementation(libs.edc.spi.identity.did)
implementation(libs.edc.spi.http)
```
