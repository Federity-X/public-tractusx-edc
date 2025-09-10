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

**Tractus-X EDC** is an automotive in---

## ⚠️ **Critical Security & Production Parity Issue**

### **Authentication Bypass Discovered**

**IMPORTANT**: The development environment has an authentication issue that does NOT reflect production behavior.

**Problem**: Both authentication extensions are loaded, causing delegated auth to bypass API key validation:

- `auth-tokenbased` (API key authentication)
- `auth-delegated` (JWT-based authentication) ← **Higher priority, misconfigured**

**Evidence**: Run `./test-authentication-issue.sh` - all requests succeed regardless of API key validity.

**Impact**:

- ❌ False confidence in development
- ❌ Authentication bugs not caught until production
- ❌ Security vulnerabilities in deployed code

**Solutions**: See `PRODUCTION_PARITY_GUIDE.md` for detailed fixes including:

1. Disabling delegated authentication for development
2. Configuring proper JWT authentication
3. Custom build excluding problematic extensions

**Quick Test**:

```bash
./test-authentication-issue.sh  # Shows authentication bypass
```

---

## 🎉 Conclusion

You now have a fully functional Tractus-X EDC development environment with:

✅ **Infrastructure**: PostgreSQL + HashiCorp Vault  
✅ **EDC Runtime**: Memory-based development setup  
✅ **Sample Data**: Assets, policies, and contract definitions  
✅ **API Access**: Management and protocol endpoints  
✅ **Build System**: Gradle with extension support  
✅ **Complete Testing Suite**: 5 testing tools for different scenarios  
✅ **Comprehensive Documentation**: Step-by-step guides and API references  
⚠️ **Security Analysis**: Authentication issue identified with solutions providedace implementation based on the Eclipse Dataspace Connector. It's specifically designed for the **Catena-X** automotive ecosystem - a collaborative data space for the automotive value chain.

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

---

## 🧪 Testing Documentation & Scripts

We've created multiple testing resources for different use cases:

### 📋 **Testing Files Overview**

| File                        | Purpose                             | Best For                          |
| --------------------------- | ----------------------------------- | --------------------------------- |
| **MANUAL_TESTING_GUIDE.md** | 68-step comprehensive testing guide | Learning EDC, thorough validation |
| **test-endpoints.sh**       | Automated endpoint health checks    | Quick validation, CI/CD pipelines |
| **test-api.sh**             | Simple command reference generator  | Fast command lookup               |
| **EDC_API_REFERENCE.md**    | Complete curl command documentation | Complete API reference            |

### 🎯 **When to Use Each Testing Tool**

#### **MANUAL_TESTING_GUIDE.md** - Comprehensive Learning & Validation

- ✅ **68 detailed steps** with explanations and expected results
- ✅ **Phase-based approach**: Connectivity → Resources → Verification → Advanced → Error handling
- ✅ **HashiCorp Vault integration** testing (secrets, OAuth configs)
- ✅ **Troubleshooting guide** with common issues and solutions
- ✅ **Testing checklist** to track progress
- 🎯 **Use for**: First-time setup, comprehensive system validation, learning EDC architecture

#### **test-endpoints.sh** - Quick Health Checks

```bash
./test-endpoints.sh  # Automated testing of all endpoints
```

- ✅ **Automated connectivity checks** for all major endpoints
- ✅ **Color-coded output** (🟢 success, 🟡 expected errors, 🔴 failures)
- ✅ **HTTP status validation** with proper interpretation
- ✅ **Three test categories**: Management API, Protocol (DSP), Data Plane
- 🎯 **Use for**: Daily development, CI/CD validation, endpoint discovery

#### **test-api.sh** - Quick Command Reference

```bash
./test-api.sh  # Display ready-to-use curl commands
```

- ✅ **Configuration display** (API keys, URLs)
- ✅ **Copy-paste ready commands** for basic operations
- ✅ **Points to complete documentation**
- 🎯 **Use for**: Quick command lookup, developer onboarding

#### **EDC_API_REFERENCE.md** - Complete API Documentation

- ✅ **60+ complete curl commands** with proper headers and JSON-LD payloads
- ✅ **All endpoint categories**: Assets, Policies, Contracts, Transfers, EDRs, DSP
- ✅ **Authentication examples** (Management API keys, Data Plane tokens)
- ✅ **Testing flows** showing complete lifecycle scenarios
- 🎯 **Use for**: Complete API interactions, production integration

### 🚀 **Recommended Testing Workflow**

```bash
# 1. Quick health check (30 seconds)
./test-endpoints.sh

# 2. Get basic commands (instant reference)
./test-api.sh

# 3. Comprehensive testing (first time or thorough validation)
# Follow MANUAL_TESTING_GUIDE.md step by step

# 4. API development (ongoing work)
# Use EDC_API_REFERENCE.md for complete curl commands
```

### 💡 **Quick API Test Examples**

```bash
# List all assets
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec","limit":10}' \
  "http://localhost:8181/management/v3/assets/request"

# Create a test asset
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},
    "@type":"Asset",
    "@id":"test-asset-123",
    "properties":{"name":"Test Asset"},
    "dataAddress":{"@type":"DataAddress","type":"HttpData","baseUrl":"https://jsonplaceholder.typicode.com/posts"}
  }' \
  "http://localhost:8181/management/v3/assets"

# Quick endpoint health check
./test-endpoints.sh | grep "✅\|❌\|⚠️"
```

**📄 See EDC_API_REFERENCE.md for:**

- ✅ Complete curl commands for all 60+ endpoints
- ✅ JSON-LD request/response examples
- ✅ Authentication headers and token usage
- ✅ DSP protocol endpoints for connector communication
- ✅ Data plane endpoints with EDR token authentication
- ✅ Business Partner Group management (Tractus-X extension)
- ✅ Complete testing flows with sample data creation

### Extension Examples

- **Policy Validation**: `/edc-extensions/cx-policy/`
- **BPN Validation**: `/edc-extensions/bpn-validation/`
- **Dataplane Proxy**: `/edc-extensions/dataplane/`
- **Event Subscriber**: `/edc-extensions/event-subscriber/`

---

## � **Next Steps & Recommended Actions**

After completing this setup, here's your recommended path:

### **Immediate Next Steps**

```bash
# 1. Verify everything works (30 seconds)
./test-endpoints.sh

# 2. Get familiar with basic commands
./test-api.sh

# 3. Run comprehensive validation (30 minutes)
# Open and follow MANUAL_TESTING_GUIDE.md
```

### **Development Workflow**

1. **Daily Development**: Use `./test-endpoints.sh` for quick health checks
2. **Learning Mode**: Follow `MANUAL_TESTING_GUIDE.md` step-by-step (68 detailed steps)
3. **API Integration**: Reference `EDC_API_REFERENCE.md` for complete curl commands
4. **Quick Commands**: Use `./test-api.sh` for instant command lookup

### **What You Can Do Now**

- ✅ **Explore Management API** at http://localhost:8181/management/v3/
- ✅ **Test Protocol API** at http://localhost:8080/api/dsp/
- ✅ **Access Data Plane** at http://localhost:8081/public/
- ✅ **View logs** with `tail -f edc.log`
- ✅ **Create assets, policies, contracts** using provided curl commands
- ✅ **Test complete data sharing workflows**

---

## �🎉 Conclusion

You now have a fully functional Tractus-X EDC development environment with:

✅ **Infrastructure**: PostgreSQL + HashiCorp Vault  
✅ **EDC Runtime**: Memory-based development setup  
✅ **Sample Data**: Assets, policies, and contract definitions  
✅ **API Access**: Management and protocol endpoints  
✅ **Build System**: Gradle with extension support  
✅ **Complete Testing Suite**: 4 testing tools for different scenarios  
✅ **Comprehensive Documentation**: Step-by-step guides and API references

**Ready for EDC development!** 🚀

---

_Last Updated: September 9, 2025_  
_Environment: macOS with Docker Desktop_  
_EDC Version: 0.11.0-SNAPSHOT_
