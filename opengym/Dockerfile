# Repackages upstream openGym (gitlab.com/DuarteSantos8/opengym) — a two-container
# (web+api) + optional MCP app — as a single Home Assistant App image, three s6
# services sharing one process namespace and one /data. Nothing in openGym's own
# source changes; this only adapts how it's built and supervised.
#
# OPENGYM_REF pins the upstream ref this image is built from. TEMPORARY default:
# the validated commit from MR !86 (gitlab.com/DuarteSantos8/opengym/-/merge_requests/86),
# not `main` — `main` still only has the old stdio-only MCP (no mcp/src/http.js,
# no api/state-store.js), so this image cannot build against it at all yet, MCP
# service aside. Once !86 merges, change this default to `main` (or a release tag)
# and drop this comment.
#
# BUILD_FROM needs a real default here: the home-assistant/builder composite actions
# (actions/build-image) only inject BUILD_ARCH/BUILD_VERSION as build-args, never
# BUILD_FROM — reading base images from build.yaml is the deprecated path (the
# home-assistant/actions info helper prints "build.yaml is deprecated, move base
# image ... to Dockerfile" and never wires build_from into the build at all in this
# newer toolchain). Left blank, ${BUILD_FROM} resolved to nothing and every CI build
# failed with "base name (${BUILD_FROM}) should not be blank". `ghcr.io/home-assistant/base`
# is HA's current multi-arch (amd64+aarch64) Alpine base — a single tag resolves the
# right platform automatically on each matrix runner, no per-arch selection needed.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24
ARG OPENGYM_REF=22e80b8fe8703449dcada96d1d99a589e8fb7282

FROM node:22-alpine AS source
ARG OPENGYM_REF
RUN apk add --no-cache git
WORKDIR /src
# TEMPORARY: the default OPENGYM_REF above only exists on the fork (MR !86 isn't merged
# yet), not upstream — switch this URL back to https://gitlab.com/DuarteSantos8/opengym.git
# once it is. Full clone + checkout (not --depth 1 --branch) because the default ref is a
# raw commit SHA, not a branch/tag name a shallow clone can fetch directly.
RUN git clone https://gitlab.com/mzspicoli/opengym.git . && git checkout "${OPENGYM_REF}"

# Static frontend build — arch-independent output, so this always runs on the
# build host's native node:22-alpine rather than under aarch64 QEMU emulation.
FROM source AS frontend-build
WORKDIR /src/frontend
RUN npm ci 2>/dev/null || npm install
RUN npm run build

FROM source AS api-deps
WORKDIR /src/api
RUN npm install --omit=dev && npm cache clean --force

FROM source AS mcp-deps
WORKDIR /src/mcp
RUN npm ci --omit=dev && npm cache clean --force

FROM ${BUILD_FROM}

# HA base images are Alpine but ship no app runtime or web server by default.
# Plain apk nodejs/npm (not a pinned node:22-alpine copy-in) — openGym's own
# dependencies are pure JS (see CONTRIBUTING.md's dependency-light constraint),
# so there is nothing here that's sensitive to the exact Node minor version.
RUN apk add --no-cache nodejs npm nginx git gettext

# Alpine's nginx package logs to files under /var/log/nginx by default. Inside
# a container that's a dead end: HA's own "Log" tab only captures stdout/
# stderr, so access/error logs would be invisible there and lost on every
# restart (nothing under /data). Redirect both to the standard streams
# instead, the normal container-logging convention.
RUN sed -i \
      -e 's#access_log /var/log/nginx/access.log main;#access_log /dev/stdout main;#' \
      -e 's#error_log /var/log/nginx/error.log warn;#error_log /dev/stderr warn;#' \
      /etc/nginx/nginx.conf \
    && grep -Fq 'access_log /dev/stdout main;' /etc/nginx/nginx.conf \
    && grep -Fq 'error_log /dev/stderr warn;' /etc/nginx/nginx.conf

# --- web (frontend + nginx) ---
COPY --from=frontend-build /src/frontend/dist /usr/share/nginx/html
COPY --from=source /src/web/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY nginx/mcp-shared.conf /tmp/mcp-shared.conf
# Single-container: every process is 127.0.0.1, not a separate compose service name.
# The final sed's `r` command splices this repo's own nginx/mcp-shared.conf
# (see its header comment) in right after `set $mcp_backend ...;`, inline —
# `r` reads a plain file, no embedded-newline/line-continuation portability
# risk the way sed's `a` command would have across GNU vs BusyBox sed. Those
# extra locations proxy the rest of the MCP route surface onto this same
# origin, for operators who leave mcp_origin blank (same-domain MCP mode).
RUN sed -i \
      -e 's/mcp:3001/127.0.0.1:3001/' \
      -e 's/X-Frame-Options "DENY"/X-Frame-Options "SAMEORIGIN"/g' \
      -e "s/frame-ancestors 'none'/frame-ancestors 'self'/g" \
      -e '/set \$mcp_backend 127.0.0.1:3001;/r /tmp/mcp-shared.conf' \
      /etc/nginx/templates/default.conf.template \
    && rm /tmp/mcp-shared.conf \
    && ! grep -Fq "frame-ancestors 'none'" /etc/nginx/templates/default.conf.template \
    && grep -Fq 'X-Frame-Options "SAMEORIGIN"' /etc/nginx/templates/default.conf.template \
    && grep -Fq "frame-ancestors 'self'" /etc/nginx/templates/default.conf.template \
    && grep -Fq 'location ^~ /mcp {' /etc/nginx/templates/default.conf.template
# Packaging-only framing adaptation: upstream correctly denies embedding on a
# normal standalone deployment, but HA Ingress is itself a same-origin iframe.
# SAMEORIGIN + frame-ancestors 'self' keeps cross-site framing blocked while
# allowing the Supervisor's authenticated /api/hassio_ingress/... wrapper.
# Alpine's nginx package ships its own welcome-page vhost here; remove it so it
# can't conflict with (or shadow) the one rendered at container start.
RUN rm -f /etc/nginx/http.d/default.conf

# --- api ---
COPY --from=source /src/api/*.js /opt/opengym/api/
COPY --from=api-deps /src/api/node_modules /opt/opengym/api/node_modules

# --- mcp (optional, gated by the mcp_enabled option at runtime) ---
# api/state-store.js is already covered above by the api/*.js wildcard — mcp/src
# imports it via a relative ../../api path, so it needs to land at that same spot
# relative to mcp/src, which /opt/opengym/{api,mcp}/ as siblings already gives it.
COPY --from=source /src/mcp/src /opt/opengym/mcp/src
COPY --from=source /src/frontend/src /opt/opengym/frontend/src
COPY --from=mcp-deps /src/mcp/node_modules /opt/opengym/mcp/node_modules

COPY rootfs /

LABEL \
    io.hass.type="addon" \
    io.hass.arch="amd64|aarch64"
