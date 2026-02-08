IMAGES := $(shell ls images)

.PHONY: help build-all test-all clean $(addprefix build-,$(IMAGES)) $(addprefix test-,$(IMAGES))

help: ## Show available targets
	@grep -E '^[a-zA-Z_%-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'

build-%: ## Build a specific image (e.g., make build-python-distroless)
	./ci/build.sh $*

build-all: $(addprefix build-,$(IMAGES)) ## Build all images

test-%: ## Test a specific image (e.g., make test-python-distroless)
	SCAN_IMAGES=true ./ci/build.sh $*

test-all: $(addprefix test-,$(IMAGES)) ## Test all images

clean: ## Clean up local scan images and buildx builders
	@echo "Cleaning local scan images..."
	@docker images --filter "reference=local-scan-*" -q 2>/dev/null | xargs -r docker rmi || true
	@echo "Removing buildx builder..."
	@docker buildx rm homelab-builder 2>/dev/null || true
	@echo "Clean complete."
