# Stage 1: Build Wolfi system CA bundle with Homelab Root CA appended.
# This bundle is used by APK, curl, and other TLS clients in Wolfi-based images.
FROM nexus.gillouche.homelab/cgr-proxy/chainguard/wolfi-base:latest@sha256:9925d3017788558fa8f27e8bb160b791e56202b60c91fbcc5c867de3175986c8 AS wolfi
COPY nexus-ca.crt /tmp/nexus-ca.crt
RUN cat /tmp/nexus-ca.crt >> /etc/ssl/certs/ca-certificates.crt

# Stage 2: Build Java truststore with Homelab Root CA.
# Bazel's embedded JVM and other Java tools use their own cacerts and ignore
# the OS trust store, so we need a JKS truststore that includes the Homelab Root CA.
FROM nexus.gillouche.homelab/docker-hub/eclipse-temurin:21-jre AS java
COPY nexus-ca.crt /tmp/nexus-ca.crt
RUN keytool -importcert -cacerts -storepass changeit -noprompt \
      -alias homelab-root-ca -file /tmp/nexus-ca.crt

# Stage 3: Minimal output image containing only cert artifacts.
# Consumer images use COPY --from= to pull exactly the files they need.
#
# Available artifacts:
#   /certs/nexus-ca.crt                  - Raw PEM certificate
#   /certs/wolfi-ca-certificates.crt     - Wolfi CA bundle with Homelab Root CA
#   /certs/java-cacerts                  - Java JKS truststore with Homelab Root CA
FROM scratch

COPY nexus-ca.crt /certs/nexus-ca.crt
COPY --from=wolfi /etc/ssl/certs/ca-certificates.crt /certs/wolfi-ca-certificates.crt
COPY --from=java /opt/java/openjdk/lib/security/cacerts /certs/java-cacerts

LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Homelab TLS certificate bundle (system CA, Java truststore)"
