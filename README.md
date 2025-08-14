# Tractus-X EDC (Eclipse Dataspace Connector)

[![Contributors][contributors-shield]][contributors-url]
[![Stargazers][stars-shield]][stars-url]
[![Apache 2.0 License][license-shield]][license-url]
[![Latest Release][release-shield]][release-url]

[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=eclipse-tractusx_tractusx-edc&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=eclipse-tractusx_tractusx-edc)

Container images and deployments of the Eclipse Dataspace Components for the Tractus-X project.

Please also refer to:

- [Our docs](https://github.com/eclipse-tractusx/tractusx-edc/tree/main/docs)
- [Our Releases](https://github.com/eclipse-tractusx/tractusx-edc/releases)
- [Eclipse Dataspace Components](https://github.com/eclipse-edc/Connector)
- [Report Bug / Request Feature](https://github.com/eclipse-tractusx/tractusx-edc/issues)

## About The Project

The project provides pre-built control- and data-plane [docker](https://www.docker.com/) images
and [helm](https://helm.sh/) charts of
the [Eclipse DataSpaceConnector Project](https://github.com/eclipse-edc/Connector).

## Inventory

The eclipse data space connector is split up into Control-Plane and Data-Plane, whereas the Control-Plane functions as
administration layer and has responsibility of resource management, contract negotiation and administer data transfer.
The Data-Plane does the heavy lifting of transferring and receiving data streams.

Control-Plane distribution:

- [edc-controlplane-postgresql-hashicorp-vault](edc-controlplane/edc-controlplane-postgresql-hashicorp-vault) with
  dependency onto
  - [Hashicorp Vault](https://www.vaultproject.io/)
  - [PostgreSQL 8.2 or newer](https://www.postgresql.org/)

Data-Plane distribution:

- [edc-dataplane-hashicorp-vault](edc-dataplane/edc-dataplane-hashicorp-vault) with dependency onto
  - [Hashicorp Vault](https://www.vaultproject.io/)

For testing/development purposes:

- [edc-runtime-memory](edc-controlplane/edc-runtime-memory)

## Getting Started

### Build

Build Tractus-X EDC together with its Container Images

```shell
./gradlew dockerize
```

### 🔧 Development Environment Setup

The project uses a **two-script architecture** for secure development environment management:

#### Quick Start

```bash
# 1. Start infrastructure (PostgreSQL, HashiCorp Vault)
./setup-dev-env.sh

# 2. Load development environment variables
source dev-env.sh

# 3. Run your EDC application
./edc-demo.sh

# 4. Stop infrastructure when done
./stop-dev-env.sh
```

#### Script Responsibilities

- **`setup-dev-env.sh`** - Starts Docker containers (PostgreSQL on port 5433, Vault on port 8200)
- **`dev-env.sh`** - Provides environment variables for database connection and credentials
- **`edc-demo.sh`** - Runs the EDC connector using the environment variables
- **`stop-dev-env.sh`** - Stops and cleans up Docker containers

This architecture ensures credentials are managed as environment variables rather than hardcoded in scripts, improving security and resolving TruffleHog false positives.

## ⚠️ Security Notice for Development Setup

This repository contains development and testing files with **development credentials** that should **NEVER be used in production**:

- `dev-env.sh` - Contains development environment variables and credentials
- `docker-compose.yml` - Contains development database passwords and Vault tokens
- `dataspaceconnector-configuration.properties` - Contains development API keys and credentials
- `edc-demo.sh`, `test-endpoints.sh` - Scripts that use development credentials
- Various test files and configurations

These credentials (like `password`, `root`) are **intentionally weak** and designed only for local development environments.

**Development Architecture**: The project separates infrastructure setup (`setup-dev-env.sh`) from credential management (`dev-env.sh`) to improve security and resolve CI security scan issues.

**For production deployments:**

- Use strong, randomly generated passwords and tokens
- Store credentials in secure secret management systems (HashiCorp Vault, Kubernetes Secrets, etc.)
- Follow the production deployment guides in the [documentation](docs/)
- Never commit real credentials to version control

**Note**: If CI security scans fail due to development JDBC URLs being flagged as secrets, see [TRUFFLEHOG_FALSE_POSITIVES.md](TRUFFLEHOG_FALSE_POSITIVES.md) for comprehensive solutions.

## Known Incompatibilities

- Hashicorp Vault 1.18.1 is not compatible with the EDC due to a bug in the vault concerning path handling
  - [Internal Issue](https://github.com/eclipse-tractusx/tractusx-edc/issues/1772)
  - [Hashicorp Vault Issue](https://github.com/hashicorp/vault/issues/29357)

## License

Distributed under the Apache 2.0 License.
See [LICENSE](https://github.com/eclipse-tractusx/tractusx-edc/blob/main/LICENSE) for more information.

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-shield]: https://img.shields.io/github/contributors/eclipse-tractusx/tractusx-edc.svg?style=for-the-badge
[contributors-url]: https://github.com/eclipse-tractusx/tractusx-edc/graphs/contributors
[stars-shield]: https://img.shields.io/github/stars/eclipse-tractusx/tractusx-edc.svg?style=for-the-badge
[stars-url]: https://github.com/eclipse-tractusx/tractusx-edc/stargazers
[license-shield]: https://img.shields.io/github/license/eclipse-tractusx/tractusx-edc.svg?style=for-the-badge
[license-url]: https://github.com/eclipse-tractusx/tractusx-edc/blob/main/LICENSE
[release-shield]: https://img.shields.io/github/v/release/eclipse-tractusx/tractusx-edc.svg?style=for-the-badge
[release-url]: https://github.com/eclipse-tractusx/tractusx-edc/releases
