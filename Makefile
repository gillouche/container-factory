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
