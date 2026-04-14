#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
JAVA_SITE_ROOT="$REPO_ROOT/java-site"
JAVA_SRC_ROOT="$JAVA_SITE_ROOT/src"
JAVA_BUILD_ROOT="$JAVA_SITE_ROOT/build/classes"
MAIN_CLASS="com.dominion.liveops.JavaLiveOpsSite"
PID_FILE="$SCRIPT_DIR/logs/Java-LiveOps-Site.pid"
LOG_FILE="$SCRIPT_DIR/logs/Java-LiveOps-Site.log"
DETACHED_EXEC_SCRIPT="$SCRIPT_DIR/detached_exec.sh"
PORT="${JAVA_SITE_PORT:-${PORT:-8090}}"

JAVA_OPTS_DEFAULT="-XX:+UseG1GC -XX:MaxRAMPercentage=70 -Dfile.encoding=UTF-8 -Djava.net.preferIPv4Stack=true"
JAVA_OPTS="${JAVA_SITE_JAVA_OPTS:-$JAVA_OPTS_DEFAULT}"

mkdir -p "$SCRIPT_DIR/logs" "$JAVA_BUILD_ROOT"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

ensure_java() {
    if ! command -v javac >/dev/null 2>&1; then
        echo "javac not found. Install OpenJDK 17+ to continue." >&2
        exit 1
    fi

    if ! command -v java >/dev/null 2>&1; then
        echo "java runtime not found. Install OpenJDK 17+ to continue." >&2
        exit 1
    fi
}

source_files() {
    find "$JAVA_SRC_ROOT" -type f -name '*.java' | sort
}

needs_compile() {
    local class_marker="$JAVA_BUILD_ROOT/com/dominion/liveops/JavaLiveOpsSite.class"

    if [ ! -f "$class_marker" ]; then
        return 0
    fi

    local src
    while IFS= read -r src; do
        if [ "$src" -nt "$class_marker" ]; then
            return 0
        fi
    done < <(source_files)

    return 1
}

build_service() {
    ensure_java

    local files=()
    while IFS= read -r src; do
        files+=("$src")
    done < <(source_files)

    if [ ${#files[@]} -eq 0 ]; then
        echo "No Java source files found in $JAVA_SRC_ROOT" >&2
        exit 1
    fi

    if needs_compile; then
        log "Compiling Java live-ops site..."
        javac -Xlint:all -d "$JAVA_BUILD_ROOT" "${files[@]}"
        log "Compilation complete"
    else
        log "Compilation skipped (classes are up to date)"
    fi
}

is_running() {
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -z "$pid" ]; then
        return 1
    fi

    if ps -p "$pid" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

wait_for_health() {
    local timeout_seconds="${JAVA_SITE_HEALTH_TIMEOUT_SECONDS:-20}"
    local elapsed=0

    while [ "$elapsed" -lt "$timeout_seconds" ]; do
        if curl -fsS "http://127.0.0.1:$PORT/ready" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 1
}

start_service() {
    build_service

    if is_running; then
        log "Java live-ops site already running (PID $(cat "$PID_FILE"))"
        return 0
    fi

    log "Starting Java live-ops site on port $PORT"
    local pid
    pid=$(bash "$DETACHED_EXEC_SCRIPT" "$PID_FILE" "$LOG_FILE" "java $JAVA_OPTS -cp '$JAVA_BUILD_ROOT' '$MAIN_CLASS'")

    if wait_for_health; then
        log "Java live-ops site is healthy (PID $pid)"
    else
        echo "Java live-ops site failed to become healthy. Check $LOG_FILE" >&2
        return 1
    fi
}

stop_service() {
    if ! is_running; then
        log "Java live-ops site is not running"
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    log "Stopping Java live-ops site (PID $pid)"
    kill "$pid" >/dev/null 2>&1 || true

    local elapsed=0
    while ps -p "$pid" >/dev/null 2>&1 && [ "$elapsed" -lt 10 ]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if ps -p "$pid" >/dev/null 2>&1; then
        log "Force stopping Java live-ops site (PID $pid)"
        kill -9 "$pid" >/dev/null 2>&1 || true
    fi

    rm -f "$PID_FILE"
    log "Java live-ops site stopped"
}

status_service() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
            log "Java live-ops site is RUNNING and HEALTHY (PID $pid, port $PORT)"
        else
            log "Java live-ops site is RUNNING but health check failed (PID $pid, port $PORT)"
            return 1
        fi
    else
        log "Java live-ops site is STOPPED"
        return 1
    fi
}

verify_service() {
    local endpoints=(
        "/health"
        "/ready"
        "/metrics"
        "/api/v1/topology"
    )

    local endpoint
    for endpoint in "${endpoints[@]}"; do
        if curl -fsS "http://127.0.0.1:$PORT$endpoint" >/dev/null 2>&1; then
            log "PASS $endpoint"
        else
            echo "FAIL $endpoint" >&2
            return 1
        fi
    done

    log "Java live-ops verification complete"
}

usage() {
    cat <<USAGE
Usage: $(basename "$0") <build|start|stop|restart|status|verify>

Commands:
  build    Compile Java live-ops site classes
  start    Build (if needed) and start service in background
  stop     Stop running service
  restart  Restart service
  status   Show service status
  verify   Probe critical health and topology endpoints
USAGE
}

main() {
    local cmd="${1:-}"

    case "$cmd" in
        build)
            build_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            stop_service
            start_service
            ;;
        status)
            status_service
            ;;
        verify)
            verify_service
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
