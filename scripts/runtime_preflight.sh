#!/bin/bash
set -euo pipefail

GITHUB_API_URL_DEFAULT="${GITHUB_API_URL_DEFAULT:-https://api.github.com}"
GITHUB_GOVERNOR_MAX_REQUESTS_PER_MINUTE="${GITHUB_GOVERNOR_MAX_REQUESTS_PER_MINUTE:-15}"
GITHUB_GOVERNOR_STATE_DIR="${GITHUB_GOVERNOR_STATE_DIR:-/tmp/dominion-github-governor}"
GITHUB_NO_PROXY_HOSTS=(
    "github.com"
    "api.github.com"
    "api.githubcopilot.com"
    "copilot-proxy.githubusercontent.com"
    "copilot-telemetry.githubusercontent.com"
    "githubusercontent.com"
)

docker_cli_available() {
    command -v docker >/dev/null 2>&1
}

docker_daemon_available() {
    docker_cli_available && docker info >/dev/null 2>&1
}

docker_runtime_blocked() {
    if ! docker_cli_available; then
        return 0
    fi

    if docker_daemon_available; then
        return 1
    fi

    case "$(docker info 2>&1 || true)" in
        *"Cannot connect to the Docker daemon"*)
            return 0
            ;;
    esac

    return 1
}

print_docker_runtime_note() {
    local context="${1:-docker operations}"

    cat <<EOF
[RUNTIME LIMITATION]
$context requires a reachable Docker daemon.
Docker CLI is present, but this runtime cannot connect to docker.sock.
Use local non-Docker verification here, or rerun on a Docker-enabled host.
EOF
}

github_no_proxy_value() {
    local existing="${NO_PROXY:-${no_proxy:-}}"
    local combined="$existing"
    local host

    for host in "${GITHUB_NO_PROXY_HOSTS[@]}"; do
        case ",${combined}," in
            *",${host},"*)
                ;;
            *)
                if [ -n "$combined" ]; then
                    combined="${combined},${host}"
                else
                    combined="${host}"
                fi
                ;;
        esac
    done

    printf '%s\n' "$combined"
}

export_github_no_proxy() {
    local combined
    combined="$(github_no_proxy_value)"
    export NO_PROXY="$combined"
    export no_proxy="$combined"
}

github_governor_state_file() {
    mkdir -p "$GITHUB_GOVERNOR_STATE_DIR"
    printf '%s\n' "${GITHUB_GOVERNOR_STATE_DIR}/requests.log"
}

github_governor_lock_file() {
    mkdir -p "$GITHUB_GOVERNOR_STATE_DIR"
    printf '%s\n' "${GITHUB_GOVERNOR_STATE_DIR}/requests.lock"
}

github_governor_prune_requests() {
    local state_file
    local now
    local tmp_file

    state_file="$(github_governor_state_file)"
    now="$(date +%s)"
    tmp_file="$(mktemp)"

    touch "$state_file"
    awk -v cutoff="$((now - 60))" 'NF && $1 >= cutoff { print $1 }' "$state_file" > "$tmp_file"
    mv "$tmp_file" "$state_file"
}

github_governor_reserve_request_slot() {
    local state_file
    local lock_file
    local request_count
    local oldest_request
    local now
    local sleep_for

    state_file="$(github_governor_state_file)"
    lock_file="$(github_governor_lock_file)"

    while true; do
        if command -v flock >/dev/null 2>&1; then
            exec 9>"$lock_file"
            flock 9
        fi

        github_governor_prune_requests
        request_count="$(wc -l < "$state_file" | tr -d ' ')"

        if [ "${request_count:-0}" -lt "$GITHUB_GOVERNOR_MAX_REQUESTS_PER_MINUTE" ]; then
            printf '%s\n' "$(date +%s)" >> "$state_file"
            if command -v flock >/dev/null 2>&1; then
                flock -u 9
            fi
            return 0
        fi

        oldest_request="$(head -n 1 "$state_file")"
        now="$(date +%s)"
        sleep_for="$((oldest_request + 61 - now))"

        if [ "$sleep_for" -lt 1 ]; then
            sleep_for=1
        fi

        echo "GitHub governor pausing ${sleep_for}s to stay below ${GITHUB_GOVERNOR_MAX_REQUESTS_PER_MINUTE} requests/minute" >&2
        sleep "$sleep_for"

        if command -v flock >/dev/null 2>&1; then
            flock -u 9
        fi
    done
}

github_gh_api() {
    github_governor_reserve_request_slot
    gh api "$@"
}

github_api_preflight() {
    local api_url="${1:-${GITHUB_API_URL:-$GITHUB_API_URL_DEFAULT}}"
    local probe_url="${api_url%/}/rate_limit"
    local auth_header=()
    local curl_output=""
    local http_code=""

    export_github_no_proxy
    github_governor_reserve_request_slot

    if ! command -v curl >/dev/null 2>&1; then
        echo "GitHub API preflight requires curl" >&2
        return 1
    fi

    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    curl_output="$(
        curl \
            --silent \
            --show-error \
            --location \
            --connect-timeout 5 \
            --max-time 20 \
            --retry 2 \
            --retry-delay 1 \
            --retry-connrefused \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "${auth_header[@]}" \
            -w '\n%{http_code}' \
            "$probe_url"
    )" || return 1

    http_code="${curl_output##*$'\n'}"

    case "$http_code" in
        200|401|403)
            return 0
            ;;
    esac

    echo "GitHub API preflight failed for ${probe_url} with HTTP ${http_code}" >&2
    return 1
}
