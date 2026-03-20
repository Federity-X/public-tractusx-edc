# DID Service Registration

## Decision

The controlplane will be enabled to register itself as `DataService` with the participant's did document. There will be
configuration variables to enable the feature, set an id for the DSP endpoint and point to the DID service's write-APIs.
There will not be an additional endpoint on the Management API - this logic is purely internal.

## Rationale

Standard CX-0001 describes the predominant method for discovering DSP endpoints as of CX release "Jupiter". It is a 
centralized service that is assumed to be a singleton.
Since the "Saturn" release, [CX-0018 section 2.6](https://catenax-ev.github.io/docs/next/standards/CX-0018-DataspaceConnectivity#26-participant-agent-management)
mandates that DID documents are used for discovery of DSP-endpoints based on DIDs. How that can be achieved is 
described in [DSP section 4](https://eclipse-dataspace-protocol-base.github.io/DataspaceProtocol/2025-1-err1/#discovery-of-service-endpoints)

Managing these `service` entries for DSP endpoints can become a chore: hosts may change, deployments may be 
deprovisioned. That's why there should be a solution that is extensible for each wallet implementation and smart enough 
to avoid creating duplicate `service` entries and manage itself.

## Approach

1. Introduce configuration options in application and helm chart.
2. Create a new SPI including an interface that represents the feature in an abstract manner.
3. Add an extension that will implement the lifecycle management logic.
4. Another extension implements the SPI's interface as client for [SAP DIV's write endpoint to the did document](https://api.sap.com/api/DIV/path/CompanyIdentityV2HttpController_updateCompanyIdentity_v2.0.0).
5. An additional extension implements the SPI's interface as client for the **IdentityHub Identity Admin API** (`/v1alpha/participants/{contextIdB64}/dids/{didB64}/endpoints`), enabling self-registration for deployments using Eclipse Tractus-X IdentityHub as their wallet.
6. A **client type selector** (`tx.edc.did.service.client.type`) explicitly chooses which wallet implementation is active (`div` or `identityhub`). Each extension only checks its own type value, avoiding cross-references between implementations and enabling clean extensibility for future wallet backends.

The lifecycle management logic is designed to ensure functional correctness while limiting outbound HTTP traffic on 
startup. It shall behave acoording to the following diagram:

```mermaid
flowchart TD
    J@{ shape: stadium, label: "Terminal point" }
    A@{ shape: circle, label: "Connector</br>starts up" }
    A --> H{reg-enabled}
    H -->|false| G
    H -->|true</br>serves id and url| E[delete and recreate existing entry with URL]
    E -->|shutdown| G{dereg-enabled}
    G -->|true| K[deregister]
    K --> J
    G -->|false| J
```

The SPI will look like

```java

public interface DidDocumentServiceClient {

    ServiceResult<Void> update(Service service);
    
    ServiceResult<Void> deleteById(String id);
}
```

## Scaling considerations

As this extension triggers a side-effect on the DID Service, one must consider the case of horizontally scaled runtimes.
When scaling down, the shutdown sequence must not affect the did document service entry if another container is still
running. Containers aren't natively aware of each other and making them would be disproportionate effort. If
deregistration is enabled, this is a very realistic scenario.

The container image should receive two new environment variables:
- `TX_EDC_DID_SERVICE_SELF_REGISTRATION_ENABLED` (labeled *reg-enabled* in flowchart)
- `TX_EDC_DID_SERVICE_SELF_DEREGISTRATION_ENABLED` (labeled *dereg-enabled* in flowchart)

At the same time, requiring an admin to consider this when deploying the helm chart is burdensome. That's why the
values yaml should look like:

```yaml
controlplane:
  didService:
    selfRegistration:
      # -- Whether Service Self Registration is enabled
      enabled: false
      # -- Unique id of connector to be used for register / unregister service inside did document (must be valid URI)
      id: "did:web:changeme"
```

The [deployment-controlplane.yaml](/charts/tractusx-connector/templates/deployment-controlplane.yaml) will infer `TX_EDC_DID_SERVICE_SELF_DEREGISTRATION_ENABLED`
by inspecting the scaling configuration like:

```yaml
- name: "TX_EDC_DID_SERVICE_SELF_DEREGISTRATION_ENABLED"
  value: {{ and (eq .Values.controlplane.replicacount 1) (not .Values.controlplane.autoscaling.enabled) }}
```

Disabling deregistration in the non-scaled case (`!controlplane.autoscaling.enabled` and `controlplane.replicacount==1`)
they can set `TX_EDC_DID_SERVICE_SELF_DEREGISTRATION_ENABLED=false` in the map `controlplane.env`.

This approach may result in dangling references from the did document to dead endpoints. Cleanup of those lies outside
tractusx-edc responsibility and should be done on the DID service directly. This state is more desirable than having 
available but undiscoverable endpoints as consequence of deletion from every container that shuts down.

## Wallet selection — alternatives considered

When multiple `DidDocumentServiceClient` implementations exist (DIV, IdentityHub, potentially others), the runtime
needs a mechanism to activate exactly one. Three approaches were evaluated:

| Option | Mechanism | Pros | Cons |
|--------|-----------|------|------|
| **A — Priority-based registry** | Extensions register with a numeric priority; the lifecycle extension picks the highest | Zero configuration, fully automatic; mirrors EDC's own service ranking patterns | Implicit — hard to predict which client wins without reading code; debugging activation order is non-trivial |
| **B — Explicit config selector** | A single property (`tx.edc.did.service.client.type`) selects the active implementation | Simple, explicit, easy to understand and debug; each extension is self-contained | Requires the deployer to set one extra property |
| **C — EDC `@Provider(isDefault=true)`** | Use EDC's built-in default-service mechanism | No custom code for selection | Not designed for conditional/multi-provider scenarios; limited control |

**Option B was chosen** for its simplicity, transparency, and debuggability. Each extension checks only its own type
value, so adding a new wallet backend in the future requires no changes to existing extensions.

If the number of wallet implementations grows significantly, Option A (priority-based registry) could be introduced as
a future enhancement to enable automatic selection without manual configuration.
