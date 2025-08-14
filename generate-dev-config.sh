#!/bin/bash
# generate-dev-config.sh
# Dynamic configuration generator for Tractus-X EDC development environment
# This script demonstrates the Dynamic Masking approach for managing dev credentials

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
OUTPUT_DIR="${SCRIPT_DIR}"

# Default development values (can be overridden by environment variables)
export EDC_DATASOURCE_EDC_URL="${EDC_DATASOURCE_EDC_URL:-jdbc:postgresql://localhost:5433/edc}"
export EDC_DATASOURCE_EDC_USER="${EDC_DATASOURCE_EDC_USER:-edc}"
export EDC_DATASOURCE_EDC_PASSWORD="${EDC_DATASOURCE_EDC_PASSWORD:-password}"

export EDC_VAULT_HASHICORP_URL="${EDC_VAULT_HASHICORP_URL:-http://localhost:8201}"
export EDC_VAULT_HASHICORP_TOKEN="${EDC_VAULT_HASHICORP_TOKEN:-dev_token_12345}"

export EDC_API_AUTH_KEY="${EDC_API_AUTH_KEY:-ApiKeyDefaultValue}"
export EDC_RECEIVER_HTTP_ENDPOINT="${EDC_RECEIVER_HTTP_ENDPOINT:-http://localhost:4000/receiver/urn:connector:provider/callback}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Create templates directory if it doesn't exist
mkdir -p "${TEMPLATE_DIR}"

# Function to generate configuration from template
generate_config() {
    local template_file="$1"
    local output_file="$2"
    
    if [[ ! -f "${template_file}" ]]; then
        warn "Template file ${template_file} not found, skipping..."
        return 0
    fi
    
    log "Generating ${output_file} from ${template_file}"
    
    # Use envsubst to replace environment variables in template
    envsubst < "${template_file}" > "${output_file}"
    
    # Make scripts executable
    if [[ "${output_file}" == *.sh ]]; then
        chmod +x "${output_file}"
    fi
    
    log "Generated ${output_file} successfully"
}

# Function to create template files if they don't exist
create_templates() {
    log "Creating template files..."
    
    # edc-demo.sh template
    cat > "${TEMPLATE_DIR}/edc-demo.sh.template" << 'EOF'
#!/bin/bash
# EDC Demo Script - Generated from template
# WARNING: This file contains development credentials only!
# DO NOT use these values in production environments.

set -euo pipefail

# Development Database Configuration (DEV-ONLY)
export EDC_DATASOURCE_EDC_URL="${EDC_DATASOURCE_EDC_URL}"
export EDC_DATASOURCE_EDC_USER="${EDC_DATASOURCE_EDC_USER}" 
export EDC_DATASOURCE_EDC_PASSWORD="${EDC_DATASOURCE_EDC_PASSWORD}"

# HashiCorp Vault Configuration (DEV-ONLY)
export EDC_VAULT_HASHICORP_URL="${EDC_VAULT_HASHICORP_URL}"
export EDC_VAULT_HASHICORP_TOKEN="${EDC_VAULT_HASHICORP_TOKEN}"

# API Configuration (DEV-ONLY)
export EDC_API_AUTH_KEY="${EDC_API_AUTH_KEY}"
export EDC_RECEIVER_HTTP_ENDPOINT="${EDC_RECEIVER_HTTP_ENDPOINT}"

echo "🚀 Starting EDC Demo Environment..."
echo "📊 Database: ${EDC_DATASOURCE_EDC_URL}"
echo "🔐 Vault: ${EDC_VAULT_HASHICORP_URL}"
echo ""
echo "⚠️  WARNING: Development credentials in use!"
echo "   Do not use these values in production!"
echo ""

# Your demo script logic here...
# docker-compose up -d
# or java -jar your-connector.jar
EOF

    # docker-compose.yml template  
    cat > "${TEMPLATE_DIR}/docker-compose.yml.template" << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: edc
      POSTGRES_USER: ${EDC_DATASOURCE_EDC_USER}
      POSTGRES_PASSWORD: ${EDC_DATASOURCE_EDC_PASSWORD}
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      
  vault:
    image: hashicorp/vault:latest
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: ${EDC_VAULT_HASHICORP_TOKEN}
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    ports:
      - "8201:8200"
    cap_add:
      - IPC_LOCK

volumes:
  postgres_data:
EOF

    log "Template files created successfully"
}

# Function to validate environment
validate_environment() {
    log "Validating environment configuration..."
    
    # Check required variables
    local required_vars=("EDC_DATASOURCE_EDC_URL" "EDC_DATASOURCE_EDC_USER" "EDC_DATASOURCE_EDC_PASSWORD")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required environment variable ${var} is not set"
        fi
    done
    
    # Validate URL formats
    if [[ ! "${EDC_DATASOURCE_EDC_URL}" =~ ^jdbc: ]]; then
        error "EDC_DATASOURCE_EDC_URL must be a valid JDBC URL"
    fi
    
    # Warn about default values
    if [[ "${EDC_DATASOURCE_EDC_PASSWORD}" == "password" ]]; then
        warn "Using default password 'password' - consider setting EDC_DATASOURCE_EDC_PASSWORD"
    fi
    
    log "Environment validation passed"
}

# Function to clean up generated files
cleanup() {
    log "Cleaning up generated configuration files..."
    
    local files=("edc-demo.sh" "docker-compose.yml")
    
    for file in "${files[@]}"; do
        if [[ -f "${OUTPUT_DIR}/${file}" ]]; then
            rm -f "${OUTPUT_DIR}/${file}"
            log "Removed ${file}"
        fi
    done
}

# Main execution
main() {
    log "🔧 Dynamic Configuration Generator for Tractus-X EDC"
    log "================================================="
    
    case "${1:-generate}" in
        "generate")
            validate_environment
            create_templates
            generate_config "${TEMPLATE_DIR}/edc-demo.sh.template" "${OUTPUT_DIR}/edc-demo.sh"
            generate_config "${TEMPLATE_DIR}/docker-compose.yml.template" "${OUTPUT_DIR}/docker-compose.yml"
            log "✅ Configuration generation completed!"
            log "📝 Generated files: edc-demo.sh, docker-compose.yml"
            log "🚀 Run './edc-demo.sh' to start the development environment"
            ;;
        "clean")
            cleanup
            log "✅ Cleanup completed!"
            ;;
        "validate")
            validate_environment
            log "✅ Validation completed!"
            ;;
        *)
            echo "Usage: $0 [generate|clean|validate]"
            echo ""
            echo "Commands:"
            echo "  generate  - Generate configuration files from templates (default)"
            echo "  clean     - Remove generated configuration files"
            echo "  validate  - Validate environment variables"
            echo ""
            echo "Environment Variables:"
            echo "  EDC_DATASOURCE_EDC_URL      - Database connection URL"
            echo "  EDC_DATASOURCE_EDC_USER     - Database username"
            echo "  EDC_DATASOURCE_EDC_PASSWORD - Database password"
            echo "  EDC_VAULT_HASHICORP_URL     - Vault server URL"
            echo "  EDC_VAULT_HASHICORP_TOKEN   - Vault dev token"
            echo "  EDC_API_AUTH_KEY            - API authentication key"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
