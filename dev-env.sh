# Development Environment Variables
# Source this file before running development scripts: source dev-env.sh

# PostgreSQL Development Database
export DEV_POSTGRES_HOST="localhost"
export DEV_POSTGRES_PORT="5433"
export DEV_POSTGRES_DB="edc"
export DEV_POSTGRES_URL="jdbc:postgresql://${DEV_POSTGRES_HOST}:${DEV_POSTGRES_PORT}/${DEV_POSTGRES_DB}"

# Development credentials (DEV-ONLY)
export DEV_DB_USER="user"
export DEV_DB_PASSWORD="password"
export DEV_API_KEY="password"
export DEV_VAULT_TOKEN="root"

echo "✅ Development environment variables loaded"
echo "📋 Database URL: ${DEV_POSTGRES_URL}"
echo "⚠️  WARNING: These are development-only credentials!"
