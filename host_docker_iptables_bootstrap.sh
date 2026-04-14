#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGED_CHAIN="PHI-HOST-INPUT"
DEFAULT_ALLOWED_TCP_PORTS=(22 80 443 3000 5000 5001 5002 5003 5004 5005 5432 6379 8000 8080 8081 9090)

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}WARNING:${NC} $*" >&2
}

fail() {
    echo -e "${RED}ERROR:${NC} $*" >&2
    exit 1
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        fail "Run this script as root on the host OS."
    fi
}

ensure_not_container() {
    if [[ -f /.dockerenv ]]; then
        fail "Detected a containerized environment. Run this script on the host OS, not inside a container."
    fi
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
        return
    fi

    if command -v dnf >/dev/null 2>&1; then
        echo "dnf"
        return
    fi

    if command -v yum >/dev/null 2>&1; then
        echo "yum"
        return
    fi

    if command -v zypper >/dev/null 2>&1; then
        echo "zypper"
        return
    fi

    fail "Unsupported host package manager. Install Docker and iptables manually."
}

install_packages_apt() {
    export DEBIAN_FRONTEND=noninteractive
    log "Installing Docker Engine and iptables via apt"
    apt-get update
    apt-get install -y docker.io iptables iptables-persistent
}

install_packages_dnf() {
    log "Installing Docker Engine and iptables via dnf"
    dnf install -y docker iptables iptables-services
}

install_packages_yum() {
    log "Installing Docker Engine and iptables via yum"
    yum install -y docker iptables iptables-services
}

install_packages_zypper() {
    log "Installing Docker Engine and iptables via zypper"
    zypper --non-interactive install docker iptables
}

ensure_packages() {
    local manager
    manager="$(detect_package_manager)"

    case "${manager}" in
        apt)
            install_packages_apt
            ;;
        dnf)
            install_packages_dnf
            ;;
        yum)
            install_packages_yum
            ;;
        zypper)
            install_packages_zypper
            ;;
        *)
            fail "Unhandled package manager: ${manager}"
            ;;
    esac
}

enable_service_if_available() {
    local service_name=$1

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now "${service_name}"
        return
    fi

    if command -v service >/dev/null 2>&1; then
        service "${service_name}" start
        return
    fi

    warn "No supported service manager found. Start ${service_name} manually."
}

service_is_active() {
    local service_name=$1

    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet "${service_name}"
        return
    fi

    if command -v service >/dev/null 2>&1; then
        service "${service_name}" status >/dev/null 2>&1
        return
    fi

    return 1
}

configure_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        fail "Docker CLI is still unavailable after package installation."
    fi

    log "Enabling Docker service"
    enable_service_if_available docker

    if getent group docker >/dev/null 2>&1 && [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "${SUDO_USER}" || warn "Failed to add ${SUDO_USER} to docker group"
    fi

    docker --version
    if ! service_is_active docker; then
        warn "Docker service manager reported inactive. Verify daemon startup on the host."
    fi
}

iptables_rule_exists() {
    local table=$1
    shift
    iptables -t "${table}" -C "$@" >/dev/null 2>&1
}

append_iptables_rule() {
    local table=$1
    shift

    if ! iptables_rule_exists "${table}" "$@"; then
        iptables -t "${table}" -A "$@"
    fi
}

ensure_chain_exists() {
    local table=$1
    local chain=$2

    if ! iptables -t "${table}" -nL "${chain}" >/dev/null 2>&1; then
        iptables -t "${table}" -N "${chain}"
    fi
}

resolve_allowed_ports() {
    if [[ -n "${ALLOWED_TCP_PORTS:-}" ]]; then
        echo "${ALLOWED_TCP_PORTS}"
        return
    fi

    printf '%s ' "${DEFAULT_ALLOWED_TCP_PORTS[@]}"
}

configure_firewall_services() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files | grep -q '^iptables\.service'; then
            systemctl enable --now iptables
        fi
        if systemctl list-unit-files | grep -q '^netfilter-persistent\.service'; then
            systemctl enable --now netfilter-persistent
        fi
    fi
}

configure_iptables() {
    if ! command -v iptables >/dev/null 2>&1; then
        fail "iptables is still unavailable after package installation."
    fi

    local port
    local allowed_ports

    allowed_ports="$(resolve_allowed_ports)"
    log "Applying managed host iptables rules to chain ${MANAGED_CHAIN}"

    ensure_chain_exists filter "${MANAGED_CHAIN}"
    iptables -t filter -F "${MANAGED_CHAIN}"

    append_iptables_rule filter "${MANAGED_CHAIN}" -i lo -j ACCEPT
    append_iptables_rule filter "${MANAGED_CHAIN}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    for port in ${allowed_ports}; do
        append_iptables_rule filter "${MANAGED_CHAIN}" -p tcp --dport "${port}" -j ACCEPT
    done

    append_iptables_rule filter "${MANAGED_CHAIN}" -j RETURN
    if ! iptables_rule_exists filter INPUT -j "${MANAGED_CHAIN}"; then
        iptables -t filter -I INPUT 1 -j "${MANAGED_CHAIN}"
    fi

    if ip link show docker0 >/dev/null 2>&1; then
        append_iptables_rule filter FORWARD -i docker0 -o docker0 -j ACCEPT
        append_iptables_rule filter FORWARD -i docker0 ! -o docker0 -j ACCEPT
        append_iptables_rule filter FORWARD ! -i docker0 -o docker0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    else
        warn "docker0 bridge not present yet; forwarding rules will be added on a later rerun after Docker creates the bridge."
    fi
}

persist_iptables_rules() {
    if command -v netfilter-persistent >/dev/null 2>&1; then
        log "Persisting iptables rules with netfilter-persistent"
        netfilter-persistent save
        return
    fi

    if command -v service >/dev/null 2>&1 && service iptables save >/dev/null 2>&1; then
        log "Persisted iptables rules with iptables service"
        return
    fi

    if [[ -d /etc/iptables ]]; then
        log "Persisting iptables rules to /etc/iptables/rules.v4"
        iptables-save > /etc/iptables/rules.v4
        return
    fi

    warn "Unable to persist iptables rules automatically. Save them manually for your distro."
}

main() {
    require_root
    ensure_not_container
    ensure_packages
    configure_docker
    configure_iptables
    configure_firewall_services
    persist_iptables_rules

    log "Docker and iptables are installed and configured on the host OS"
    log "Managed script path: ${SCRIPT_DIR}/$(basename "$0")"
    log "Allowed TCP ports: $(resolve_allowed_ports)"
}

main "$@"
