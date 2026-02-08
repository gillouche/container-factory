IMAGES := $(shell ls images)

.PHONY: build-all $(IMAGES)

setup:
	chmod +x ci/*.sh

# Example: make build-python-distroless
build-%:
	./ci/build.sh $*

build-all:
	@for img in $(IMAGES); do \
		./ci/build.sh $$img; \
	done

# Enable scanning without pushing
test-%:
	SCAN_IMAGES=true ./ci/build.sh $*

test-all:
	@for img in $(IMAGES); do \
		SCAN_IMAGES=true ./ci/build.sh $$img; \
	done
