# Makefile for Incus Appliance Registry

.PHONY: all build clean test publish serve help validate lint list

APPLIANCES := $(shell find appliances -maxdepth 1 -mindepth 1 -type d ! -name '_base' -exec basename {} \; 2>/dev/null | sort)
ARCH ?= $(shell uname -m)
REGISTRY_DIR := registry
BUILD_DIR := .build

# Default target
all: help

## Build targets

build: ## Build all appliances
	@for app in $(APPLIANCES); do \
		if [ -f "appliances/$$app/image.yaml" ]; then \
			$(MAKE) build-$$app; \
		fi; \
	done

build-%: ## Build specific appliance (e.g., make build-nginx)
	@./bin/build-appliance.sh $* $(ARCH)

build-all-arch: ## Build all appliances for all architectures
	@for app in $(APPLIANCES); do \
		for arch in amd64 arm64; do \
			echo "Building $$app for $$arch..."; \
			$(MAKE) build-$$app ARCH=$$arch || true; \
		done; \
	done

## Validation

validate: ## Validate all appliance templates
	@./bin/validate.sh

lint: ## Lint YAML files
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint appliances/ profiles/ 2>/dev/null || true; \
	else \
		echo "yamllint not installed, skipping lint check"; \
	fi

## Testing

test: ## Run integration tests
	@./bin/test-all.sh

test-%: ## Test specific appliance (e.g., make test-nginx)
	@./bin/test-appliance.sh $*

## Registry management

serve: ## Start local HTTPS server for testing
	@./scripts/serve-local.sh

publish: ## Publish registry to production server
	@./scripts/publish.sh

## Cleanup

clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)

clean-all: clean ## Remove build artifacts and registry
	rm -rf $(REGISTRY_DIR)

## Information

list: ## List available appliances
	@echo "Available appliances:"
	@for app in $(APPLIANCES); do \
		if [ -f "appliances/$$app/appliance.yaml" ]; then \
			desc=$$(grep '^description:' "appliances/$$app/appliance.yaml" | cut -d'"' -f2); \
			printf "  %-15s %s\n" "$$app" "$$desc"; \
		else \
			printf "  %-15s %s\n" "$$app" "(no metadata)"; \
		fi; \
	done

registry-list: ## List images in registry
	@if [ -d "$(REGISTRY_DIR)" ]; then \
		incus-simplestreams list $(REGISTRY_DIR) 2>/dev/null || echo "Registry empty or not initialized"; \
	else \
		echo "Registry directory not found. Run 'make build' first."; \
	fi

help: ## Show this help
	@echo "Incus Appliance Registry"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
