#!/usr/bin/env bash

set -uo pipefail

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

CURL_IMAGE="${CURL_IMAGE:-curlimages/curl:latest}"
ALPINE_IMAGE="${ALPINE_IMAGE:-alpine:latest}"
CHECK_EGRESS="${CHECK_EGRESS:-0}"


pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '[PASS] %s\n' "$1"
}


fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[FAIL] %s\n' "$1"
}


skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf '[SKIP] %s\n' "$1"
}


ensure_image() {
    local image="$1"

    if ! docker image inspect "${image}" >/dev/null 2>&1; then
        printf 'Pulling required test image: %s\n' "${image}"

        if ! docker pull "${image}"; then
            printf 'Unable to pull required image: %s\n' "${image}"
            exit 1
        fi
    fi
}


check_value() {
    local name="$1"
    local actual="$2"
    local expected="$3"

    if [[ "${actual}" == "${expected}" ]]; then
        pass "${name}"
    else
        fail "${name} (expected=${expected}, actual=${actual})"
    fi
}


check_healthy() {
    local service="$1"
    local container_id
    local status

    container_id="$(docker compose ps -q "${service}")"

    if [[ -z "${container_id}" ]]; then
        fail "${service} container exists"
        return
    fi

    status="$(
        docker inspect \
            --format '{{.State.Health.Status}}' \
            "${container_id}" 2>/dev/null || true
    )"

    check_value "${service} is healthy" "${status}" "healthy"
}


expect_host_http_allowed() {
    local name="$1"
    local url="$2"

    if curl \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 8 \
        "${url}" >/dev/null 2>&1; then
        pass "${name}"
    else
        fail "${name}"
    fi
}


expect_http_allowed() {
    local name="$1"
    local network="$2"
    local url="$3"

    if docker run --rm \
        --network "${network}" \
        "${CURL_IMAGE}" \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 8 \
        "${url}" >/dev/null 2>&1; then
        pass "${name}"
    else
        fail "${name}"
    fi
}


expect_http_blocked() {
    local name="$1"
    local network="$2"
    local url="$3"

    if docker run --rm \
        --network "${network}" \
        "${CURL_IMAGE}" \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 8 \
        "${url}" >/dev/null 2>&1; then
        fail "${name}"
    else
        pass "${name}"
    fi
}


expect_tcp_allowed() {
    local name="$1"
    local network="$2"
    local host="$3"
    local port="$4"

    if docker run --rm \
        --network "${network}" \
        "${ALPINE_IMAGE}" \
        sh -c "nc -z -w 3 '${host}' '${port}'" \
        >/dev/null 2>&1; then
        pass "${name}"
    else
        fail "${name}"
    fi
}


expect_tcp_blocked() {
    local name="$1"
    local network="$2"
    local host="$3"
    local port="$4"

    if docker run --rm \
        --network "${network}" \
        "${ALPINE_IMAGE}" \
        sh -c "nc -z -w 3 '${host}' '${port}'" \
        >/dev/null 2>&1; then
        fail "${name}"
    else
        pass "${name}"
    fi
}


expect_namespace_tcp_allowed() {
    local name="$1"
    local container_id="$2"
    local host="$3"
    local port="$4"

    if docker run --rm \
        --network "container:${container_id}" \
        "${ALPINE_IMAGE}" \
        sh -c "nc -z -w 3 '${host}' '${port}'" \
        >/dev/null 2>&1; then
        pass "${name}"
    else
        fail "${name}"
    fi
}


expect_namespace_tcp_blocked() {
    local name="$1"
    local container_id="$2"
    local host="$3"
    local port="$4"

    if docker run --rm \
        --network "container:${container_id}" \
        "${ALPINE_IMAGE}" \
        sh -c "nc -z -w 3 '${host}' '${port}'" \
        >/dev/null 2>&1; then
        fail "${name}"
    else
        pass "${name}"
    fi
}


expect_namespace_http_allowed() {
    local name="$1"
    local container_id="$2"
    local url="$3"

    if docker run --rm \
        --network "container:${container_id}" \
        "${CURL_IMAGE}" \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 8 \
        "${url}" >/dev/null 2>&1; then
        pass "${name}"
    else
        fail "${name}"
    fi
}


expect_namespace_http_blocked() {
    local name="$1"
    local container_id="$2"
    local url="$3"

    if docker run --rm \
        --network "container:${container_id}" \
        "${CURL_IMAGE}" \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 8 \
        "${url}" >/dev/null 2>&1; then
        fail "${name}"
    else
        pass "${name}"
    fi
}


printf 'Preparing segmented network test environment...\n'

ensure_image "${CURL_IMAGE}"
ensure_image "${ALPINE_IMAGE}"

if ! docker compose up -d --wait --wait-timeout 120; then
    printf '[FATAL] The Compose application did not become healthy.\n'
    docker compose ps
    docker compose logs --tail=100
    exit 1
fi

GATEWAY_ID="$(docker compose ps -q gateway)"
API_ID="$(docker compose ps -q api)"
DATABASE_ID="$(docker compose ps -q database)"

printf '\nService health\n'
check_healthy gateway
check_healthy api
check_healthy database

printf '\nNetwork configuration\n'

EDGE_INTERNAL="$(
    docker network inspect segment_edge \
        --format '{{.Internal}}'
)"

APP_INTERNAL="$(
    docker network inspect segment_app \
        --format '{{.Internal}}'
)"

DATA_INTERNAL="$(
    docker network inspect segment_data \
        --format '{{.Internal}}'
)"

check_value "segment_edge permits external routing" \
    "${EDGE_INTERNAL}" "false"

check_value "segment_app is internal" \
    "${APP_INTERNAL}" "true"

check_value "segment_data is internal" \
    "${DATA_INTERNAL}" "true"

printf '\nHost port configuration\n'

GATEWAY_PORT="$(
    docker compose port gateway 8080 2>/dev/null || true
)"

API_PORT="$(
    docker inspect \
        --format '{{range .NetworkSettings.Ports}}{{if .}}published{{end}}{{end}}' \
        "$(docker compose ps -q api)"
)"

DATABASE_PORT="$(
    docker inspect \
        --format '{{range .NetworkSettings.Ports}}{{if .}}published{{end}}{{end}}' \
        "$(docker compose ps -q database)"
)"

check_value "gateway binds only to host loopback" \
    "${GATEWAY_PORT}" "127.0.0.1:8080"

check_value "API has no published host port" \
    "${API_PORT}" ""

check_value "database has no published host port" \
    "${DATABASE_PORT}" ""

printf '\nAllowed connectivity\n'

expect_host_http_allowed \
    "host loopback can reach gateway" \
    "http://127.0.0.1:8080/healthz"

expect_http_allowed \
    "edge network can reach gateway" \
    "segment_edge" \
    "http://gateway:8080/healthz"

expect_http_allowed \
    "application network can reach API" \
    "segment_app" \
    "http://api:8000/health"

expect_tcp_allowed \
    "data network can reach PostgreSQL" \
    "segment_data" \
    "database" \
    "5432"

expect_namespace_tcp_allowed \
    "API can reach PostgreSQL" \
    "${API_ID}" \
    "172.28.30.30" \
    "5432"

expect_host_http_allowed \
    "gateway can proxy API health" \
    "http://127.0.0.1:8080/api/health"

expect_host_http_allowed \
    "gateway can proxy API database check" \
    "http://127.0.0.1:8080/api/database-health"

expect_http_allowed \
    "data-network members can reach API data interface" \
    "segment_data" \
    "http://api:8000/health"

printf '\nBlocked connectivity\n'

expect_http_blocked \
    "edge network cannot resolve or reach API by service name" \
    "segment_edge" \
    "http://api:8000/health"

expect_http_blocked \
    "edge network cannot reach API application address" \
    "segment_edge" \
    "http://172.28.20.20:8000/health"

expect_tcp_blocked \
    "edge network cannot reach PostgreSQL" \
    "segment_edge" \
    "172.28.30.30" \
    "5432"

expect_tcp_blocked \
    "application network cannot directly reach PostgreSQL" \
    "segment_app" \
    "172.28.30.30" \
    "5432"

expect_namespace_tcp_blocked \
    "gateway cannot directly reach PostgreSQL" \
    "${GATEWAY_ID}" \
    "172.28.30.30" \
    "5432"

if [[ "${CHECK_EGRESS}" == "1" ]]; then
    printf '\nLive egress checks\n'

    expect_namespace_http_allowed \
        "gateway can reach the public internet through edge network" \
        "${GATEWAY_ID}" \
        "https://example.com"

    expect_namespace_http_blocked \
        "API cannot directly reach the public internet" \
        "${API_ID}" \
        "https://example.com"

    expect_namespace_http_blocked \
        "database cannot directly reach the public internet" \
        "${DATABASE_ID}" \
        "https://example.com"
else
    printf '\nLive egress checks\n'
    skip "gateway public-internet test; run with CHECK_EGRESS=1"
    skip "API public-internet test; run with CHECK_EGRESS=1"
    skip "database public-internet test; run with CHECK_EGRESS=1"
fi

printf '\nTest summary\n'
printf 'Passed:  %d\n' "${PASS_COUNT}"
printf 'Failed:  %d\n' "${FAIL_COUNT}"
printf 'Skipped: %d\n' "${SKIP_COUNT}"

if (( FAIL_COUNT > 0 )); then
    printf '\nNetwork verification failed.\n'
    exit 1
fi

