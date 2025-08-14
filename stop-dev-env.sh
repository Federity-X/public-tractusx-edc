#!/bin/bash

# Stop script for Tractus-X EDC local development environment

echo "🛑 Stopping Tractus-X EDC local development environment..."

# Function to use either docker-compose or docker compose
run_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

run_docker_compose down

echo "✅ Development environment stopped!"
echo ""
echo "To start the environment again, run:"
echo "  ./setup-dev-env.sh"
