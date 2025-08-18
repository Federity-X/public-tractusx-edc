# Developer Quick Start Guide

## 🚀 Development Environment Setup

The Tractus-X EDC uses a **two-script architecture** for secure development:

### 📋 Scripts Overview

| Script             | Purpose               | Usage                | Contains             |
| ------------------ | --------------------- | -------------------- | -------------------- |
| `setup-dev-env.sh` | Start infrastructure  | `./setup-dev-env.sh` | Docker orchestration |
| `dev-env.sh`       | Environment variables | `source dev-env.sh`  | Credentials & config |
| `stop-dev-env.sh`  | Stop infrastructure   | `./stop-dev-env.sh`  | Cleanup commands     |

### 🔄 Complete Workflow

```bash
# 1. 🚀 Start infrastructure (PostgreSQL + Vault)
./setup-dev-env.sh

# 2. 🔧 Load environment variables
source dev-env.sh

# 3. ▶️ Run your application
./edc-demo.sh

# 4. 🛑 Stop infrastructure when done
./stop-dev-env.sh
```

### 📊 What Gets Started

After running `setup-dev-env.sh`, you'll have:

- **PostgreSQL Database**: `localhost:5433`

  - Database: `edc`
  - User: `user`
  - Password: `password`

- **HashiCorp Vault**: `http://localhost:8200`
  - Root Token: `root`

### ✅ **Extension Development Support**

This infrastructure supports full Tractus-X extension development including:

- **Data Masking Extension**: Successfully integrated and tested
- **160+ Service Extensions**: Complete Tractus-X ecosystem
- **Production APIs**: Management (8181), Protocol (8282), Public (8185)

### 🎯 Why This Architecture?

1. **🔐 Security**: No hardcoded credentials in scripts
2. **🚫 CI Clean**: Resolves TruffleHog false positives
3. **🔧 Flexibility**: Infrastructure and config are separate
4. **📚 Standards**: Follows Unix philosophy (one tool, one job)

### 🆘 Troubleshooting

#### Docker not running

```bash
# Start Docker Desktop or Docker daemon first
docker info  # Should show Docker status
```

#### Services not starting

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs postgresql
docker-compose logs vault
```

#### Environment variables not loaded

```bash
# Make sure to source (not execute) dev-env.sh
source dev-env.sh    # ✅ Correct
./dev-env.sh         # ❌ Wrong - won't set variables in current shell

# Verify variables are loaded
echo $DEV_POSTGRES_URL
```

#### Port conflicts

```bash
# Check what's using the ports
lsof -i :5433  # PostgreSQL
lsof -i :8200  # Vault

# Stop conflicting services or change ports in docker-compose.yml
```

### 🔍 Verification

Check that everything is working:

```bash
# 1. Verify environment variables are loaded
echo "Database URL: $DEV_POSTGRES_URL"

# 2. Test database connection
docker-compose exec postgresql pg_isready -U user -d edc

# 3. Test Vault connection
curl -s http://localhost:8200/v1/sys/health | jq .
```

### 🔗 Related Files

- **Infrastructure**: `docker-compose.yml`
- **Demo Script**: `edc-demo.sh`
- **Documentation**: `TRUFFLEHOG_FALSE_POSITIVES.md`
- **CI/CD**: `.github/workflows/`

---

_For more advanced configurations and troubleshooting, see [TRUFFLEHOG_FALSE_POSITIVES.md](TRUFFLEHOG_FALSE_POSITIVES.md)_
