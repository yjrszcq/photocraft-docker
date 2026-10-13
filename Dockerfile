# syntax=docker/dockerfile:1
ARG NGINX_IMAGE=nginx:1.28-alpine

# The official Web release is architecture-independent; download it on the runner's platform.
FROM --platform=$BUILDPLATFORM ${NGINX_IMAGE} AS download
RUN apk add --no-cache curl unzip gzip
ARG PHOTOCRAFT_VERSION=0.8.2
ARG PHOTOCRAFT_SHA256=490e4f3c242f2eee42f58446db8e7d468ac7abae3548b31a477e7fd43a7e92f4
ARG PHOTOCRAFT_COMMIT=d43db3e153c76aefce9b32cef9099e458eaf17a8
WORKDIR /tmp/release
RUN set -eu; \
    printf '%s\n' "$PHOTOCRAFT_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$'; \
    printf '%s\n' "$PHOTOCRAFT_COMMIT" | grep -Eq '^[0-9a-f]{40}$'; \
    archive="photocraft-web-${PHOTOCRAFT_VERSION}.zip"; \
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
      "https://github.com/storytold/photocraft/releases/download/v${PHOTOCRAFT_VERSION}/${archive}" \
      --output "$archive"; \
    if test -n "$PHOTOCRAFT_SHA256"; then \
      printf '%s\n' "$PHOTOCRAFT_SHA256" | grep -Eq '^[0-9a-f]{64}$'; \
      printf '%s  %s\n' "$PHOTOCRAFT_SHA256" "$archive" > checksum.txt; \
    else \
      curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        "https://github.com/storytold/photocraft/releases/download/v${PHOTOCRAFT_VERSION}/SHA256SUMS.txt" \
        --output SHA256SUMS.txt; \
      awk -v name="$archive" '$2 == name || $2 == "*" name' SHA256SUMS.txt > checksum.txt; \
      test "$(wc -l < checksum.txt)" -eq 1; \
    fi; \
    sha256sum -c checksum.txt; \
    unzip -q "$archive"; \
    mv "photocraft-web-${PHOTOCRAFT_VERSION}" /site; \
    test -s /site/index.html; \
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
      "https://codeload.github.com/storytold/photocraft/tar.gz/${PHOTOCRAFT_COMMIT}" \
      --output notices.tar.gz; \
    mkdir -p /tmp/upstream /site/licenses; \
    tar -xzf notices.tar.gz --strip-components=1 -C /tmp/upstream; \
    cp /tmp/upstream/LICENSE-MIT /tmp/upstream/LICENSE-APACHE \
      /tmp/upstream/NOTICE /tmp/upstream/ATTRIBUTION.md /site/; \
    find /tmp/upstream/assets /tmp/upstream/crates/ui-egui/src -type f \
      \( -name 'LICENSE*.txt' -o -name 'OFL*.txt' \) \
      -exec cp {} /site/licenses/ \;; \
    test -s /site/LICENSE-MIT; \
    test -s /site/LICENSE-APACHE; \
    test -s /site/NOTICE; \
    test -s /site/ATTRIBUTION.md; \
    found_wasm=0; \
    for asset in /site/*.wasm /site/*.js /site/index.html; do \
      test -f "$asset" || continue; \
      case "$asset" in *.wasm) found_wasm=1 ;; esac; \
      gzip -9 -n -f -k "$asset"; \
    done; \
    test "$found_wasm" -eq 1; \
    find /site -type d -exec chmod 755 {} +; \
    find /site -type f -exec chmod 644 {} +

FROM ${NGINX_IMAGE} AS runtime
ARG PHOTOCRAFT_VERSION=0.8.2
ARG PHOTOCRAFT_SHA256=490e4f3c242f2eee42f58446db8e7d468ac7abae3548b31a477e7fd43a7e92f4
ARG PHOTOCRAFT_COMMIT=d43db3e153c76aefce9b32cef9099e458eaf17a8
LABEL org.opencontainers.image.title="PhotoCraft Web" \
      org.opencontainers.image.version="${PHOTOCRAFT_VERSION}" \
      org.opencontainers.image.url="https://github.com/storytold/photocraft" \
      org.opencontainers.image.licenses="MIT OR Apache-2.0" \
      io.photocraft.release.sha256="${PHOTOCRAFT_SHA256}" \
      io.photocraft.upstream.commit="${PHOTOCRAFT_COMMIT}"
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=download /site/ /usr/share/nginx/html/
USER nginx
EXPOSE 8080
ENTRYPOINT []
CMD ["nginx", "-g", "daemon off;"]
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
