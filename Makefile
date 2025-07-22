# Makefile for Tractus-X EDC Runtime Management
# It provides convenient targets for the EDC runtime

.PHONY: build start stop logs help

# Default target
help:
	@echo "Tractus-X EDC Runtime Management"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  build    - Build the EDC runtime Docker image"
	@echo "  start    - Start the EDC runtime container"
	@echo "  stop     - Stop and remove the EDC runtime container"
	@echo "  logs     - Show container logs"
	@echo "  help     - Show this help message (default)"
	@echo ""
	@echo "Usage:"
	@echo "  make build    # Build Docker image"
	@echo "  make start    # Start EDC runtime"
	@echo "  make stop     # Stop EDC runtime"
	@echo "  make logs     # Show container logs"
	@echo "  make help     # Show this help"

# Build the EDC runtime Docker image
build:
	@echo "Building EDC runtime Docker image..."
	@./gradlew :edc-controlplane:edc-runtime-memory:dockerize

# Start the EDC runtime
start:
	@echo "Starting Tractus-X EDC Runtime..."
	@CONFIGURATION_PROPERTIES_FILE="$(PWD)/configuration.properties" && \
	docker run \
		-d \
		--name tractus-x-edc-runtime \
		-e EDC_VAULT_SECRETS="key1:secret1;key2:secret2" \
		-p 8080:8080 -p 8181:8181 -p 8282:8282 -p 9090:9090 -p 9999:9999 \
		-v "$${CONFIGURATION_PROPERTIES_FILE}:/app/configuration.properties" \
		edc-runtime-memory:latest

# Stop the EDC runtime
stop:
	@echo "Stopping Tractus-X EDC Runtime..."
	@if docker ps -q --filter name=tractus-x-edc-runtime | grep -q .; then \
		echo "Found running EDC runtime container: tractus-x-edc-runtime"; \
		echo "Stopping container..."; \
		docker stop tractus-x-edc-runtime; \
		echo "Removing container..."; \
		docker rm tractus-x-edc-runtime; \
		echo "EDC runtime container stopped and removed successfully."; \
	elif docker ps -aq --filter name=tractus-x-edc-runtime | grep -q .; then \
		echo "Found stopped EDC container: tractus-x-edc-runtime"; \
		echo "Removing stopped container..."; \
		docker rm tractus-x-edc-runtime; \
		echo "Stopped EDC container removed successfully."; \
	else \
		echo "No EDC runtime container found with name: tractus-x-edc-runtime"; \
	fi
	@echo "Done."

# Show container logs
logs:
	@echo "Showing EDC runtime container logs..."
	@if docker ps -q --filter name=tractus-x-edc-runtime | grep -q .; then \
		echo "Container name: tractus-x-edc-runtime"; \
		docker logs -f tractus-x-edc-runtime; \
	else \
		echo "No running EDC runtime container found with name: tractus-x-edc-runtime"; \
	fi