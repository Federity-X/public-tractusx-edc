# Tractus-X EDC Developer Documentation

**🎯 Complete Developer Guide Hub** - Your starting point for Tractus-X EDC development

The Tractus-X EDC repository creates runnable applications out of EDC extensions from the
[EDC Connector](https://github.com/eclipse-edc/Connector) platform.

This documentation collection includes **production-ready guides**, **live examples**, and **complete workflows** for developing extensions that integrate with the full Tractus-X ecosystem.

When running an EDC connector from the Tractus-X EDC repository there are three different setups to choose from. They
only vary by using different extensions for

- Resolving of Connector-Identities
- Persistence of the Control-Plane-State
- Persistence of Secrets (Vault)

## Connector Setup

The three supported setups are.

- Setup 1: Pure in Memory **Not intended for production use!**
  - In Memory persistence
  - In Memory KeyVault with seedable secrets.
  - Planes:
    - [Control Plane](../edc-controlplane/edc-runtime-memory/README.md)
    - [Data Plane](../edc-dataplane/edc-dataplane-base/README.md)
- Setup 2: PostgreSQL & HashiCorp Vault ⭐ **RECOMMENDED FOR PRODUCTION**
  - PostgreSQL persistence
  - HashiCorp Vault
  - **160+ extensions including all Tractus-X components**
  - Planes:
    - [Control Plane](../edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/README.md)
    - [Data Plane](../edc-dataplane/edc-dataplane-hashicorp-vault/README.md)

## 🚀 Quick Start for Developers

### New to Tractus-X EDC Extension Development?

**Start here:** [Extension Creation Guide](EXTENSION_CREATION_GUIDE.md) - Complete step-by-step tutorial

### Need Quick Reference?

**Go here:** [Extension Quick Reference](EXTENSION_QUICK_REFERENCE.md) - Templates and patterns

### Want to See a Working Example?

**Check this:** [Data Masking Extension](../edc-extensions/data-masking/README.md) ✅ - Production-ready example with live API masking

## 📚 Complete Documentation Collection

### 🎯 Essential Developer Guides

| Guide                                                                    | Purpose                        | When to Use                          |
| ------------------------------------------------------------------------ | ------------------------------ | ------------------------------------ |
| [**Extension Creation Guide**](EXTENSION_CREATION_GUIDE.md)              | Complete tutorial from scratch | Building your first extension        |
| [**Extension Quick Reference**](EXTENSION_QUICK_REFERENCE.md)            | Templates and patterns         | Quick development                    |
| [**Developer Guide**](../DEVELOPER_GUIDE.md)                             | Environment setup              | Setting up development workflow      |
| [**Master Integration Guide**](../TRACTUS_X_INTEGRATION_MASTER_GUIDE.md) | All guides overview            | Understanding the complete ecosystem |

### 📖 Specialized Documentation

| Guide                                                                         | Focus Area                | Contains                                      |
| ----------------------------------------------------------------------------- | ------------------------- | --------------------------------------------- |
| [**Step-by-Step Data Masking**](../STEP_BY_STEP_GUIDE_DATA_MASKING.md)        | Real-world implementation | Complete journey from idea to production      |
| [**Data Masking Developer Guide**](../DATA_MASKING_PLUGIN_DEVELOPER_GUIDE.md) | Production example        | Live API masking with transformer integration |
| [Development Workflow](development/README.md)                                 | Build and test processes  | Development best practices                    |
| [Migration Guides](migration)                                                 | Version upgrades          | Updating existing extensions                  |

## Recommended Documentation

### 🔗 External Resources

- [MXD: Minimum viable tractusX Dataspace](https://github.com/eclipse-tractusx/tutorial-resources/tree/main/mxd)
- [Eclipse Dataspace Components](https://eclipse-edc.github.io/docs/#/)

### 🏗️ Infrastructure Documentation

- [Application: Control Plane](../edc-controlplane)
- [Application: Data Plane](../edc-dataplane)
- [Chart Documentation](../charts/README.md)

## Available Extensions

### 🔒 Security & Privacy Extensions

- **[Data Masking Extension](../edc-extensions/data-masking/README.md)** ✅ **PRODUCTION-READY**
  - Automatically masks sensitive data in API responses
  - Transformer integration with EDC TypeTransformerRegistry
  - Live example: businessPartnerNumber: "BPN123456789" → "B\*\*\*9"
  - Configurable masking strategies (PARTIAL, FULL, NONE)
- [BPN Validation](../edc-extensions/bpn-validation/README.md) - Business Partner Number validation

### 📊 Data Management Extensions

- [Agreements Retirement](../edc-extensions/agreements/README.md) - Contract agreement lifecycle management
- [EDR (Endpoint Data Reference)](../edc-extensions/edr/) - Token and reference management

### ⚙️ Infrastructure Extensions

- [Event Subscriber](../edc-extensions/event-subscriber/) - Event handling and monitoring
- [Data Flow Properties Provider](../edc-extensions/data-flow-properties-provider/) - Data transfer configuration

### 🔧 Development Extensions

- [DCP (Dataspace Protocol)](../edc-extensions/dcp/) - Protocol implementation extensions
- [Federated Catalog](../edc-extensions/federated-catalog/) - Catalog federation capabilities

## 🎯 Success Stories

### ✅ **Data Masking Extension - Production Success**

**Complete implementation from concept to live API masking:**

- **160+ extensions loaded** in production runtime
- **Live API responses** showing masked sensitive data
- **Transformer integration** with EDC's JSON-LD processing
- **Production configuration** with PostgreSQL + Vault
- **Comprehensive documentation** for replication

**Live Example:**

```bash
# API Response with masked data
{
  "@id": "sensitive-data-asset",
  "https://w3id.org/edc/v0.0.1/ns/properties": {
    "businessPartnerNumber": "B***9",
    "email": "j***@s***.com"
  }
}
```

## 🛠️ Development Workflow

### For New Extensions:

1. **📚 Read**: [Extension Creation Guide](EXTENSION_CREATION_GUIDE.md)
2. **⚡ Quick Start**: [Extension Quick Reference](EXTENSION_QUICK_REFERENCE.md)
3. **🔧 Setup**: [Developer Guide](../DEVELOPER_GUIDE.md)
4. **🧪 Test**: Follow production runtime testing patterns
5. **📖 Study**: [Data Masking Extension](../edc-extensions/data-masking/README.md) as reference
6. **✅ Validate**: Run [Final Success Report](../FINAL-SUCCESS-REPORT.sh) for comprehensive validation

### For Production Integration:

1. **Use PostgreSQL + Vault runtime** (edc-controlplane-postgresql-hashicorp-vault)
2. **Test with 160+ extensions** to ensure compatibility
3. **Implement transformer integration** for API processing (if needed)
4. **Follow EDC namespace compliance** for JSON-LD processing
5. **Validate with live API calls** before deployment
6. **Run comprehensive validation** using `./FINAL-SUCCESS-REPORT.sh`

## 💡 Key Development Insights

### ⚠️ Critical Requirements for Production Extensions:

1. **Runtime Selection**: Use `edc-controlplane-postgresql-hashicorp-vault` (not memory runtime)
2. **Infrastructure**: PostgreSQL + HashiCorp Vault required
3. **Transformer Integration**: Essential for API response processing
4. **EDC Namespace Compliance**: Must use `EDC_NAMESPACE + "properties"` for JSON-LD
5. **Live API Testing**: Unit tests alone are insufficient for validation

### 🎯 Success Patterns:

- **Follow the Data Masking Extension** as reference implementation
- **Study transformer integration** for API processing needs
- **Use production runtime** from development start
- **Test with full Tractus-X stack** (160+ extensions)
- **Implement proper service registration** with META-INF

## NOTICE

This work is licensed under the [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0).

- SPDX-License-Identifier: Apache-2.0
- SPDX-FileCopyrightText: 2021,2022,2023 Contributors to the Eclipse Foundation
- Source URL: <https://github.com/eclipse-tractusx/tractusx-edc>
