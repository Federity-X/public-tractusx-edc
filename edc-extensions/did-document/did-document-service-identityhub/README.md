# did-document-service-identityhub

## Overview

This extension provides a client for managing DID Document Service entries using the
IdentityHub Identity Admin API. It enables secure and programmatic updates to DID Documents
for organizations using IdentityHub as their wallet solution.

The client's purpose is to be injected in the `did-document-service-self-registration`
extension by implementing the `DidDocumentServiceClient` SPI.

## Prerequisites

- An IdentityHub instance (v0.15.1+) accessible via the Identity Admin API
- An API key stored in the EDC Vault for authentication
- A configured participant context in IdentityHub

## Configuration

| Property | Required | Description |
|---|---|---|
| `tx.edc.did.service.client.type` | yes | Must be set to `"identityhub"` to activate this extension |
| `tx.edc.ih.identity.api.url` | yes | IdentityHub Identity Admin API base URL (including base path, e.g. `http://identityhub:15151/api/identity`) |
| `tx.edc.ih.identity.api.key.alias` | yes | Vault alias for the X-Api-Key secret used to authenticate with IdentityHub |
| `tx.edc.ih.participant.context.id` | yes | IdentityHub participant context ID |
| `edc.participant.id` | yes | This connector's DID |

## API Contract

The extension uses the IdentityHub DID Management API (unstable v1alpha):

### Add Service Endpoint
```
POST /v1alpha/participants/{base64url(contextId)}/dids/{base64url(did)}/endpoints?autoPublish=true
```
Request body: JSON-serialized `Service` object (`id`, `type`, `serviceEndpoint`).

### Remove Service Endpoint
```
DELETE /v1alpha/participants/{base64url(contextId)}/dids/{base64url(did)}/endpoints?serviceId={id}&autoPublish={true|false}
```
- `autoPublish=false` during `update()` (the subsequent POST publishes both changes)
- `autoPublish=true` during standalone `deleteById()` (e.g. deregistration on shutdown)

### Update Strategy

The `update()` method uses DELETE+POST (not PATCH) to handle both first-time registration
and update scenarios idempotently:
1. DELETE existing service endpoint (400 tolerated — service not yet in DID)
2. POST new service endpoint (409 tolerated — already exists)

Authentication is via `x-api-key` header with a static key resolved from the Vault at startup.
