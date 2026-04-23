#!/usr/bin/env bash
set -euo pipefail

DAEMON_JSON="/etc/docker/daemon.json"
LOG_FILE="/tmp/dockerd-repair-optimal.log"
PID_FILE="/tmp/dockerd-repair-optimal.pid"
CANARY_OUT="/tmp/docker-repair-canary.out"
CANARY_ERR="/tmp/docker-repair-canary.err"
DOCKER_CONTEXT_OVERRIDE=""

have() {
  command -v "$1" >/dev/null 2>&1
}

in_container() {
  [[ -f /.dockerenv || -f /run/.containerenv ]]
}

docker_cmd() {
  if [[ -n "${DOCKER_CONTEXT_OVERRIDE}" ]]; then
    env -u DOCKER_HOST docker --context "${DOCKER_CONTEXT_OVERRIDE}" "$@"
  else
    docker "$@"
  fi
}

need_sudo() {
  if ! sudo -n true >/dev/null 2>&1; then
    echo "[repair] passwordless sudo is required for daemon repair in this runtime." >&2
    exit 1
  fi
}

write_daemon_config() {
  sudo mkdir -p /etc/docker
  cat <<'JSON' | sudo tee "$DAEMON_JSON" >/dev/null
{
  "iptables": false,
  "ip6tables": false,
  "bridge": "none",
  "ip-forward": false,
  "ip-masq": false,
  "features": {
    "buildkit": true
  }
}
JSON
}

restart_daemon() {
  sudo pkill -f '^dockerd' >/dev/null 2>&1 || true
  sleep 1
  sudo nohup dockerd >"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
}

wait_for_daemon() {
  local i
  for i in $(seq 1 20); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

probe_contexts() {
  local ctx
  for ctx in default desktop; do
    if env -u DOCKER_HOST docker --context "${ctx}" info >/dev/null 2>&1; then
      DOCKER_CONTEXT_OVERRIDE="${ctx}"
      return 0
    fi
  done
  return 1
}

check_unshare() {
  if unshare -m true >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

canary_run() {
  rm -f "${CANARY_OUT}" "${CANARY_ERR}"
  if docker_cmd run --rm --pull=missing hello-world >"${CANARY_OUT}" 2>"${CANARY_ERR}"; then
    return 0
  fi
  if grep -Eqi 'operation not permitted|unshare|failed to (register|extract) layer|driver not supported|mount.*permission denied' "${CANARY_ERR}"; then
    return 2
  fi
  return 1
}

main() {
  if ! have docker; then
    echo "[repair] docker CLI is not installed." >&2
    exit 1
  fi

  if probe_contexts; then
    echo "[repair] found reachable docker context: ${DOCKER_CONTEXT_OVERRIDE}"
    if [[ "${DOCKER_CONTEXT_OVERRIDE}" != "default" ]]; then
      echo "[repair] note: this context is not selected by DOCKER_HOST. Use:"
      echo "  env -u DOCKER_HOST docker --context ${DOCKER_CONTEXT_OVERRIDE} ..."
    fi
  else
    need_sudo
    echo "[repair] no reachable context found; repairing local dockerd"
    echo "[repair] applying container-safe Docker daemon config"
    write_daemon_config
    echo "[repair] restarting dockerd"
    restart_daemon

    if ! wait_for_daemon; then
      echo "[repair] dockerd failed to become ready. Recent log:" >&2
      tail -n 80 "$LOG_FILE" >&2 || true
      exit 1
    fi
  fi

  echo "[repair] docker daemon reachable"
  docker_cmd version --format 'client={{.Client.Version}} server={{.Server.Version}}'

  if docker_cmd compose version >/dev/null 2>&1; then
    docker_cmd compose version
  elif have docker-compose; then
    docker-compose version
  fi

  canary_rc=0
  if canary_run; then
    echo "[repair] container run canary passed (hello-world)."
    exit 0
  else
    canary_rc=$?
  fi

  if [[ "${canary_rc}" -eq 1 ]]; then
    echo "[repair] canary failed for a non-permission reason (network/auth/image availability)."
    echo "[repair] stderr preview:"
    sed -n '1,40p' "${CANARY_ERR}" || true
    exit 3
  fi

  if in_container && ! check_unshare; then
    echo "[repair] host restriction detected: unshare is blocked in this container runtime."
    echo "[repair] docker API is available, but pulling/running nested containers can fail without extra host privileges."
    echo "[repair] to fully enable nested containers, run this workspace with --privileged or mount a host docker socket."
    exit 2
  fi

  echo "[repair] container run failed due permission restrictions in current runtime."
  exit 2
}

main "$@"
