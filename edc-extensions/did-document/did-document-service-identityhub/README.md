# did-document-service-identityhub

## Overview

This extension provides a `DidDocumentServiceClient` backed by the **IdentityHub Identity Admin API**.
It enables automatic registration and deregistration of DSP service endpoints in a connector's DID Document
when using Eclipse Tractus-X IdentityHub as the wallet solution.

## How It Works

The extension calls the IdentityHub Identity Admin API to manage `service` entries in the DID Document:

- **`update(service)`** — Delete-then-create pattern: removes any existing entry, then creates a new one.
  - 404 on delete is tolerated (endpoint may not exist yet).
  - 409 on create is tolerated (idempotent).
- **`deleteById(id)`** — Removes a service entry by ID.
  - 404 is tolerated (already removed).

### API Endpoints

| Operation | Method | URL Pattern |
|-----------|--------|-------------|
| Create | `POST` | `{apiUrl}/v1alpha/participants/{contextIdB64}/dids/{didB64}/endpoints?autoPublish=true` |
| Delete | `DELETE` | `{apiUrl}/v1alpha/participants/{contextIdB64}/dids/{didB64}/endpoints?serviceId={id}&autoPublish=true` |

Path parameters `contextIdB64` and `didB64` are URL-safe Base64 (without padding) encodings of the participant context ID and DID respectively.

## Activation

This extension activates when **all** of the following conditions are met:

1. `tx.edc.did.service.client.type` is set to `identityhub`
2. `tx.edc.ih.identity.api.url` is configured
3. `tx.edc.ih.identity.api.key.alias` is configured and resolvable from the Vault
4. `tx.edc.ih.participant.context.id` is configured
5. `edc.iam.issuer.id` is configured

If any condition is not met, the extension logs an informational message and does not register a client.

## Configuration

| Property | Required | Description |
|----------|----------|-------------|
| `tx.edc.did.service.client.type` | No | Must be set to `identityhub` to activate this extension |
| `tx.edc.ih.identity.api.url` | No | Base URL of the IdentityHub Identity Admin API (e.g. `https://ih.example.com:15151/api/identity`) |
| `tx.edc.ih.identity.api.key.alias` | No | Vault alias for the API key used in the `x-api-key` header |
| `tx.edc.ih.participant.context.id` | No | IdentityHub participant context ID (e.g. `provider`) |
| `edc.iam.issuer.id` | No | The DID of this connector (e.g. `did:web:example.com:provider`) |

> All properties are marked `required = false` because the extension performs its own validation and
> gracefully skips registration if any setting is missing.

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
    clientType: "identityhub"
    selfRegistration:
      enabled: true
      id: "did:web:example.com:provider#DataService"
    identityHub:
      apiUrl: "https://ih.example.com:15151/api/identity"
      apiKeyAlias: "ih-identity-api-key"
      participantContextId: "provider"
```
