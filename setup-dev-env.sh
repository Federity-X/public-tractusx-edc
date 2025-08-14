#!/bin/bash

# Setup script for Tractus-X EDC local development environment
# This script sets up PostgreSQL and HashiCorp Vault for local development

echo "🚀 Setting up Tractus-X EDC local development environment..."

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Error: docker-compose is not available. Please install Docker Compose."
    exit 1
fi

# Function to use either docker-compose or docker compose
run_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

echo "📋 Starting PostgreSQL and HashiCorp Vault..."
run_docker_compose up -d

echo "⏳ Waiting for services to be ready..."

# Wait for PostgreSQL to be ready
echo "🔄 Waiting for PostgreSQL to be healthy..."
while ! run_docker_compose exec -T postgresql pg_isready -U user -d edc &>/dev/null; do
    sleep 2
    echo -n "."
done
echo ""
echo "✅ PostgreSQL is ready!"

# Wait for Vault to be ready
echo "🔄 Waiting for HashiCorp Vault to be ready..."
while ! curl -s http://localhost:8200/v1/sys/health &>/dev/null; do
    sleep 2
    echo -n "."
done
echo ""
echo "✅ HashiCorp Vault is ready!"

echo ""
echo "🎉 Setup complete! Services are running:"
echo "  📊 PostgreSQL: localhost:5433"
echo "    - Database: edc"
echo "    - User: user"
echo "    - Password: password"
echo ""
echo "  🔐 HashiCorp Vault: http://localhost:8200"
echo "    - Root Token: root"
echo ""
echo "You can now run your Tractus-X EDC application!"
echo ""
echo "To stop the services, run:"
echo "  ./stop-dev-env.sh"
echo ""
echo "To check service status:"
if command -v docker-compose &> /dev/null; then
    echo "  docker-compose ps"
else
    echo "  docker compose ps"
fi
