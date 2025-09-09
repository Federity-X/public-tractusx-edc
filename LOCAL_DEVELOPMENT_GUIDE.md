# Tractus-X EDC Local Development Guide

_A comprehensive guide for setting up and working with the Tractus-X Eclipse Dataspace Connector (EDC) locally_

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Prerequisites](#-prerequisites)
- [Step-by-Step Setup](#-step-by-step-setup)
- [What We Built](#-what-we-built)
- [Key Learning Points](#-key-learning-points)
- [Development Workflow](#-development-workflow)
- [Next Steps](#-next-steps)
- [Troubleshooting](#-troubleshooting)
- [Resources](#-resources)

## 🏗️ Project Overview

### What is Tractus-X EDC?

**Tractus-X EDC** is an automotive industry dataspace implementation based on the Eclipse Dataspace Connector. It's specifically designed for the **Catena-X** automotive ecosystem - a collaborative data space for the automotive value chain.

### Core Architecture

The EDC follows a **distributed architecture** with two main components:

#### 1. **Control Plane**

- **Management Layer**: Handles resource management, contract negotiation, and data transfer coordination
- **Key Responsibilities**:
  - Asset, Policy & Contract Definition CRUD operations
  - Contract offering & negotiation via Dataspace Protocol (DSP)
  - Data transfer orchestration
  - Identity and access management

#### 2. **Data Plane**

- **Data Transfer Engine**: Handles the actual data movement
- **Key Responsibilities**:
  - Physical data transfer between systems
  - Data proxy functionality for secure access
  - Support for multiple data sources (HTTP, S3, Azure Blob, etc.)

### Technology Stack

- **Java 17+** (we used Java 24)
- **Gradle with Kotlin DSL** for build management
- **Jersey (JAX-RS)** for REST APIs
- **PostgreSQL** for persistence
- **HashiCorp Vault** for secrets management
- **Docker & Kubernetes** for containerization
- **OpenTelemetry** for observability

## 🛠️ Prerequisites

Before starting, ensure you have:

- **Docker Desktop** running
- **Java 17+** installed (we verified Java 24 works)
- **Git** for version control
- **curl** for API testing
- **jq** (optional) for JSON formatting

### Verification Commands

```bash
# Check Docker
docker --version && docker info

# Check Java
java --version

# Check Gradle (uses project wrapper)
./gradlew --version
```

## 🚀 Step-by-Step Setup

### Step 1: Infrastructure Setup

The project uses a **secure two-script architecture** for development environment management:

#### Start Infrastructure Services

```bash
# 1. Start PostgreSQL and HashiCorp Vault
./setup-dev-env.sh
```

This script:

- ✅ Validates Docker is running
- 🚀 Starts PostgreSQL (port 5433) and HashiCorp Vault (port 8200)
- ⏳ Waits for services to be healthy
- 📊 Provides connection details

**Expected Output:**

```
🎉 Setup complete! Services are running:
  📊 PostgreSQL: localhost:5433
    - Database: edc
    - User: user
    - Password: password
  🔐 HashiCorp Vault: http://localhost:8200
    - Root Token: root
```

#### Verify Services

```bash
# Check running containers
docker compose ps

# Test database connection
docker compose exec postgresql pg_isready -U user -d edc

# Test Vault connection
curl -s http://localhost:8200/v1/sys/health
```

### Step 2: Load Development Environment

```bash
# 2. Load environment variables
source dev-env.sh
```

This loads development credentials and database connection strings:

- `DEV_POSTGRES_URL`: JDBC connection string
- `DEV_DB_USER` & `DEV_DB_PASSWORD`: Database credentials
- `DEV_API_KEY`: API authentication key
- `DEV_VAULT_TOKEN`: Vault access token

⚠️ **Warning**: These are development-only credentials!

### Step 3: Build EDC Components

```bash
# Build memory runtime (for quick development)
./gradlew :edc-controlplane:edc-runtime-memory:build

# Build PostgreSQL runtime (for realistic testing)
./gradlew :edc-controlplane:edc-controlplane-postgresql-hashicorp-vault:build
```

**Build Success Indicators:**

- `BUILD SUCCESSFUL` message
- JAR files created in `build/libs/` directories
- No compilation errors

### Step 4: Run EDC Connector

```bash
# Option 1: Memory runtime (simpler, faster startup)
java -jar edc-controlplane/edc-runtime-memory/build/libs/edc-runtime-memory.jar

# Option 2: Run in background
java -jar edc-controlplane/edc-runtime-memory/build/libs/edc-runtime-memory.jar > edc.log 2>&1 &
```

**Startup Success Indicators:**

```
INFO Runtime test-runtime ready
INFO 148 service extensions started
```

### Step 5: Verify EDC is Running

```bash
# Check listening ports
lsof -i :8181 -i :8080 -i :8081

# Test Management API (basic connectivity)
curl -H "X-Api-Key: password" \
  http://localhost:8181/management/v3/assets/request \
  -X POST -H "Content-Type: application/json" \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}'
```

### Step 6: Run Demo Script

```bash
# Execute comprehensive API demonstration
./edc-demo.sh
```

This script demonstrates:

- Creating assets with data addresses
- Setting up access and contract policies
- Creating contract definitions
- Querying the catalog
- Listing resources via Management API

## 🎯 What We Built

### 1. **Infrastructure Layer**

- **PostgreSQL Database**: Persistent storage for EDC entities
- **HashiCorp Vault**: Secure secrets management
- **Docker Network**: Isolated development environment

### 2. **EDC Runtime**

- **Control Plane**: Management APIs and protocol endpoints
- **In-Memory Storage**: Quick development setup
- **Multiple API Endpoints**: Management, Protocol, Data Plane

### 3. **Sample Data**

- **Demo Asset**: HTTP data source pointing to JSONPlaceholder
- **Access Policy**: ODRL-based permission rules
- **Contract Policy**: Usage constraints and obligations
- **Contract Definition**: Linking assets to policies

### 4. **API Endpoints**

| Port | Endpoint       | Purpose                       |
| ---- | -------------- | ----------------------------- |
| 8181 | Management API | CRUD operations for resources |
| 8080 | Protocol API   | DSP communication             |
| 8081 | Data Plane API | Data transfer operations      |
| 8084 | DSP Protocol   | Inter-connector communication |

## 🎓 Key Learning Points

### 1. **EDC Architecture Understanding**

- **Separation of Concerns**: Control vs Data plane responsibilities
- **API-Driven**: Everything managed through REST APIs
- **Standards-Based**: ODRL policies, JSON-LD contexts, DSP protocol

### 2. **Resource Management**

- **Assets**: Data source definitions with metadata and data addresses
- **Policies**: ODRL-based access and usage rules
- **Contract Definitions**: Binding assets to policies for offers

### 3. **JSON-LD Context**

- All API requests use JSON-LD format
- Context definitions for semantic interoperability
- Proper namespace handling for Tractus-X extensions

### 4. **Development Practices**

- **Secure Credentials Management**: Separate infrastructure from config
- **Gradle Build System**: Multi-module project structure
- **Extension Architecture**: Modular, pluggable components

### 5. **Authentication & Authorization**

- **API Key Authentication**: Simple development setup
- **Policy-Based Access Control**: ODRL constraint evaluation
- **Verifiable Credentials**: DID-based identity (in production)

## 🔄 Development Workflow

### Daily Development Cycle

```bash
# 1. Start development environment
./setup-dev-env.sh
source dev-env.sh

# 2. Make changes to code
# Edit files in edc-extensions/ or other modules

# 3. Build specific modules
./gradlew :edc-extensions:cx-policy:build

# 4. Run tests
./gradlew :edc-extensions:cx-policy:test

# 5. Rebuild and restart EDC
./gradlew :edc-controlplane:edc-runtime-memory:build
# Stop existing EDC process
java -jar edc-controlplane/edc-runtime-memory/build/libs/edc-runtime-memory.jar

# 6. Test changes
./edc-demo.sh
```

### Clean Shutdown

```bash
# Stop EDC process
kill %1  # or specific PID

# Stop infrastructure
./stop-dev-env.sh
```

## 🚀 Next Steps

### 1. **Explore Extensions** (Immediate)

- **Policy Validation**: Study `edc-extensions/cx-policy/`
- **BPN Validation**: Examine `edc-extensions/bpn-validation/`
- **Data Plane Proxy**: Investigate `edc-extensions/dataplane/`

### 2. **Build Custom Extensions** (Short Term)

```bash
# Create new extension module
mkdir -p edc-extensions/my-extension/src/main/java
# Follow existing extension patterns
# Implement ServiceExtension interface
```

### 3. **Advanced Configuration** (Medium Term)

- **PostgreSQL Runtime**: Switch from memory to persistent storage
- **HashiCorp Vault Integration**: Use real secrets management
- **Multi-Connector Setup**: Test inter-connector communication

### 4. **Production Preparation** (Long Term)

- **Identity Trust Setup**: DID-based authentication
- **Policy Compliance**: Catena-X framework policies
- **Kubernetes Deployment**: Helm charts for production

### 5. **Testing & Quality**

- **Unit Tests**: Extend test coverage for new features
- **Integration Tests**: End-to-end workflow testing
- **DSP Compatibility**: Multi-version protocol testing

## 🔧 Troubleshooting

### Common Issues

#### 1. **Docker Not Running**

```bash
# Error: Docker is not running
docker info  # Should show Docker status
# Solution: Start Docker Desktop
```

#### 2. **Port Conflicts**

```bash
# Check what's using ports
lsof -i :5433  # PostgreSQL
lsof -i :8200  # Vault
lsof -i :8181  # EDC Management

# Solution: Stop conflicting services or change ports in docker-compose.yml
```

#### 3. **Environment Variables Not Loaded**

```bash
# Wrong: This won't set variables in current shell
./dev-env.sh

# Correct: Source the script
source dev-env.sh

# Verify variables are loaded
echo $DEV_POSTGRES_URL
```

#### 4. **EDC Startup Issues**

```bash
# Check logs
tail -f edc.log

# Common issues:
# - Missing dependencies (rebuild)
# - Port conflicts (check lsof)
# - Configuration errors (check environment variables)
```

#### 5. **API Authentication Errors**

```bash
# All Management API requests need API key
curl -H "X-Api-Key: password" http://localhost:8181/management/...

# Check if correct port is being used (8181 for management)
```

#### 6. **Management API 404 Errors**

**Root Cause**: There is **NO root `/management/` endpoint** in EDC. The management API only exposes **specific resource endpoints**.

```bash
# ❌ These will return 404 (Not Found):
curl -H "X-Api-Key: password" http://localhost:8181/management/
curl -H "X-Api-Key: password" http://localhost:8181/management/health
curl -H "X-Api-Key: password" http://localhost:8181/management/version

# ✅ These work correctly (resource-specific endpoints):
curl -H "X-Api-Key: password" -X POST \
  -H "Content-Type: application/json" \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/assets/request

curl -H "X-Api-Key: password" -X POST \
  -H "Content-Type: application/json" \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "@type": "QuerySpec"}' \
  http://localhost:8181/management/v3/policydefinitions/request
```

**Available Management API Endpoints:**

- `/management/v3/assets/request` - List assets
- `/management/v3/policydefinitions/request` - List policies
- `/management/v3/contractdefinitions/request` - List contract definitions
- `/management/v3/contractnegotiations/request` - List negotiations
- `/management/v3/transferprocesses/request` - List transfers
- `/management/v3/edrs/request` - List EDR entries

**Note**: EDC uses **resource-specific endpoints** with versioning (v3) rather than a general API root.

### Verification Commands

```bash
# Full environment check
echo "=== Docker Services ==="
docker compose ps

echo "=== EDC Process ==="
ps aux | grep java | grep edc-runtime

echo "=== Listening Ports ==="
lsof -i :8181 -i :8080 -i :8081

echo "=== Environment Variables ==="
echo "Database: $DEV_POSTGRES_URL"
echo "API Key: $DEV_API_KEY"
```

## 📚 Resources

### Documentation

- [EDC Official Documentation](https://eclipse-edc.github.io/docs/)
- [Tractus-X EDC Repository](https://github.com/eclipse-tractusx/tractusx-edc)
- [Catena-X Standards](https://catena-x.net/en/standard-library)

### Key Files in Project

- `README.md` - Project overview and quick start
- `DEVELOPER_GUIDE.md` - Development environment details
- `docker-compose.yml` - Infrastructure setup
- `build.gradle.kts` - Main build configuration
- `gradle/libs.versions.toml` - Dependency versions

### API Documentation

- **Management API**: `http://localhost:8181/management/v3/{resource}/request` (resource-specific endpoints)
- **Protocol API**: `http://localhost:8080/api/dsp/` (DSP endpoints)
- **Data Plane API**: `http://localhost:8081/public/` (data transfer)
- **OpenAPI specs**: Generated during build in `resources/openapi/yaml`

**Important**: There is no root `/management/` endpoint - EDC only exposes specific resource endpoints!

### Extension Examples

- **Policy Validation**: `/edc-extensions/cx-policy/`
- **BPN Validation**: `/edc-extensions/bpn-validation/`
- **Dataplane Proxy**: `/edc-extensions/dataplane/`
- **Event Subscriber**: `/edc-extensions/event-subscriber/`

---

## 🎉 Conclusion

You now have a fully functional Tractus-X EDC development environment with:

✅ **Infrastructure**: PostgreSQL + HashiCorp Vault  
✅ **EDC Runtime**: Memory-based development setup  
✅ **Sample Data**: Assets, policies, and contract definitions  
✅ **API Access**: Management and protocol endpoints  
✅ **Build System**: Gradle with extension support

**Happy Coding!** 🚀

---

_Last Updated: September 9, 2025_  
_Environment: macOS with Docker Desktop_  
_EDC Version: 0.11.0-SNAPSHOT_
