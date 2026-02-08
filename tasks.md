# Container Factory - Improvement Tasks

## Critical

- [x] Replace curl|sh Trivy install with pinned GitHub Action or versioned release
- [x] Pin all GitHub Actions by full commit SHA (checkout, login-action, setup-buildx-action)
- [x] Fix `latest` tag logic - currently last variant processed wins, should only tag highest version or remove entirely
- [x] Add image signing with cosign after push
- [x] Add SBOM generation (--sbom flag or syft)

## High

- [ ] Add `SCAN_IMAGES: true` unconditionally in CI so feature branches are scanned
- [ ] Add `permissions: contents: read` to workflow
- [ ] Add `timeout-minutes` to workflow job
- [ ] Add concurrency control to workflow to prevent parallel builds stomping on each other
- [ ] Switch to CI matrix strategy for parallel image builds (dynamically discover images)
- [ ] Add Docker layer caching (--cache-from / --cache-to) to buildx commands
- [ ] Move buildx builder creation outside the for loop in build.sh
- [ ] Replace hardcoded smoke test mapping with convention-based discovery (e.g. images/$IMAGE_NAME/test.sh)
- [ ] Add --provenance=true to buildx commands for SLSA provenance attestation
- [ ] Fix dry-run multi-arch build (currently produces nothing - add --output or skip)
- [ ] Remove unnecessary pip/setuptools/wheel upgrade from Dockerfile donor stage
- [ ] Add .dockerignore to each image directory
- [ ] Add real assertions to smoke test (non-root check, version validation, stdlib imports)
- [ ] Ensure CI workflow also triggers on pull_request so automerged PRs are tested
- [ ] Add explicit `USER nonroot` directive in Dockerfile final stage

## Medium

- [ ] Add git SHA tag to built images for traceability (--tag $IMAGE:$VERSION-$SHORT_SHA)
- [ ] Add OCI build-date and vcs-ref labels at build time
- [ ] Add `--link` flag to COPY --from=donor in Dockerfile
- [ ] Add `org.opencontainers.image.version` label to Dockerfile
- [ ] Pin distroless base image by SHA digest
- [ ] Add missing .PHONY declarations (setup, test-%, test-all) in Makefile
- [ ] Remove setup target - handle chmod via git update-index --chmod=+x
- [ ] Add help target to Makefile
- [ ] Add clean target to Makefile
- [ ] Fix build-all/test-all to fail fast instead of continuing on error
- [ ] Fix .gitignore: .envrc is both tracked and ignored, add .DS_Store and IDE files
- [ ] Update Renovate config: replace deprecated config:base with config:recommended
- [ ] Add Renovate regexManagers to manage VARIANTS files
- [ ] Add platformAutomerge: true to Renovate config
- [ ] Add workflow path triggers for Makefile, tests/**, and workflow file changes
- [ ] Add build status badge to README

## Low

- [x] Add hadolint, shellcheck, dive, cosign to Nix flake devShell
- [x] Add pre-commit hooks (shellcheck on ci/*.sh, hadolint on Dockerfiles)
- [x] Add .github/CODEOWNERS file
