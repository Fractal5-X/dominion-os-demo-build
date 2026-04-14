#!/bin/bash
# 🔍 PERFECT OPERATIONS VERIFICATION SCRIPT
# Dominion OS - PHI Sovereign AI Verification
# Checks implementation status of hardening measures

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Scoring variables
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_CHECKS++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

check() {
    ((TOTAL_CHECKS++))
    echo -n "Checking $1... "
}

# SSH Security Checks
check_ssh_security() {
    log "🔐 Checking SSH Security Configuration"

    check "SSH root login disabled"
    if sudo grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
        success "SSH root login disabled"
    else
        warning "SSH root login not disabled"
    fi

    check "SSH password authentication disabled"
    if sudo grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        success "SSH password authentication disabled"
    else
        warning "SSH password authentication not disabled"
    fi

    check "SSH public key authentication enabled"
    if sudo grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        success "SSH public key authentication enabled"
    else
        warning "SSH public key authentication not enabled"
    fi
}

# Firewall Checks
check_firewall() {
    log "🔥 Checking Firewall Configuration"

    check "UFW firewall active"
    if sudo ufw status | grep -q "Status: active" 2>/dev/null; then
        success "UFW firewall active"
    else
        error "UFW firewall not active"
    fi

    check "SSH port allowed"
    if sudo ufw status | grep -q "22/tcp" 2>/dev/null; then
        success "SSH port allowed"
    else
        warning "SSH port not explicitly allowed"
    fi

    check "Web service ports allowed"
    if sudo ufw status | grep -q "8080\|8081\|5000:5005" 2>/dev/null; then
        success "Web service ports allowed"
    else
        warning "Web service ports not configured"
    fi
}

# Kernel Security Checks
check_kernel_security() {
    log "🧠 Checking Kernel Security Parameters"

    check "Address space randomization"
    if sysctl kernel.randomize_va_space | grep -q "= 2" 2>/dev/null; then
        success "Address space randomization enabled"
    else
        warning "Address space randomization not optimal"
    fi

    check "TCP SYN cookies"
    if sysctl net.ipv4.tcp_syncookies | grep -q "= 1" 2>/dev/null; then
        success "TCP SYN cookies enabled"
    else
        warning "TCP SYN cookies not enabled"
    fi

    check "Reverse path filtering"
    if sysctl net.ipv4.conf.all.rp_filter | grep -q "= 1" 2>/dev/null; then
        success "Reverse path filtering enabled"
    else
        warning "Reverse path filtering not enabled"
    fi
}

# File Permissions Checks
check_file_permissions() {
    log "📁 Checking File Permissions"

    check "Script execute permissions"
    if find /workspaces/dominion-os-demo-build -name "*.sh" -perm 755 | wc -l | grep -q "^[1-9]"; then
        success "Script execute permissions correct"
    else
        warning "Some scripts may not have execute permissions"
    fi

    check "Python file permissions"
    if find /workspaces/dominion-os-demo-build -name "*.py" -perm 644 | wc -l | grep -q "^[1-9]"; then
        success "Python file permissions correct"
    else
        warning "Some Python files may have incorrect permissions"
    fi
}

# Backup System Checks
check_backup_system() {
    log "💾 Checking Backup System"

    check "Backup directories exist"
    if [ -d "/opt/dominion/backups/daily" ] && [ -d "/opt/dominion/backups/weekly" ] && [ -d "/opt/dominion/backups/monthly" ]; then
        success "Backup directories exist"
    else
        error "Backup directories missing"
    fi

    check "Backup script exists and executable"
    if [ -x "/opt/dominion/backup.sh" ]; then
        success "Backup script exists and executable"
    else
        error "Backup script missing or not executable"
    fi

    check "Backup cron job configured"
    if sudo crontab -l | grep -q "backup.sh" 2>/dev/null; then
        success "Backup cron job configured"
    else
        warning "Backup cron job not configured"
    fi
}

# Monitoring Checks
check_monitoring() {
    log "📊 Checking Monitoring Systems"

    check "Live Ops Monitor operational"
    if timeout 10 bash /workspaces/dominion-os-demo-build/scripts/live_ops_monitor.sh >/dev/null 2>&1; then
        success "Live Ops Monitor operational"
    else
        error "Live Ops Monitor not operational"
    fi

    check "Log directories exist"
    if [ -d "/var/log/dominion" ]; then
        success "Log directories exist"
    else
        warning "Log directories missing"
    fi

    check "Log rotation configured"
    if [ -f "/etc/logrotate.d/dominion" ]; then
        success "Log rotation configured"
    else
        warning "Log rotation not configured"
    fi
}

# Security Tools Checks
check_security_tools() {
    log "🛡️ Checking Security Tools"

    check "Fail2Ban installed"
    if command -v fail2ban-client >/dev/null 2>&1; then
        success "Fail2Ban installed"
    else
        warning "Fail2Ban not installed"
    fi

    check "Audit system active"
    if systemctl is-active auditd >/dev/null 2>&1; then
        success "Audit system active"
    else
        warning "Audit system not active"
    fi

    check "File integrity monitoring"
    if command -v aide >/dev/null 2>&1; then
        success "File integrity monitoring available"
    else
        warning "File integrity monitoring not available"
    fi
}

# Network Optimization Checks
check_network_optimization() {
    log "🌐 Checking Network Optimization"

    check "TCP window scaling"
    if sysctl net.ipv4.tcp_window_scaling | grep -q "= 1" 2>/dev/null; then
        success "TCP window scaling enabled"
    else
        warning "TCP window scaling not enabled"
    fi

    check "TCP buffer sizes optimized"
    if sysctl net.core.rmem_max | grep -q "16777216" 2>/dev/null; then
        success "TCP buffer sizes optimized"
    else
        warning "TCP buffer sizes not optimized"
    fi
}

# Service Health Checks
check_service_health() {
    log "🏥 Checking Service Health"

    check "SSH service running"
    if systemctl is-active sshd >/dev/null 2>&1; then
        success "SSH service running"
    else
        error "SSH service not running"
    fi

    check "Web services accessible"
    if curl -s http://localhost:8080 >/dev/null 2>&1 || curl -s http://localhost:8081 >/dev/null 2>&1; then
        success "Web services accessible"
    else
        warning "Web services not accessible"
    fi

    check "API services accessible"
    if curl -s http://localhost:5000 >/dev/null 2>&1 || curl -s http://localhost:5001 >/dev/null 2>&1; then
        success "API services accessible"
    else
        warning "API services not accessible"
    fi
}

# Compliance Checks
check_compliance() {
    log "📋 Checking Compliance Configuration"

    check "Compliance check script exists"
    if [ -x "/opt/dominion/compliance_check.sh" ]; then
        success "Compliance check script exists"
    else
        error "Compliance check script missing"
    fi

    check "Compliance cron job configured"
    if sudo crontab -l | grep -q "compliance_check.sh" 2>/dev/null; then
        success "Compliance cron job configured"
    else
        warning "Compliance cron job not configured"
    fi
}

# Calculate and display results
calculate_score() {
    local percentage=0
    if [ $TOTAL_CHECKS -gt 0 ]; then
        percentage=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    fi

    echo
    echo "========================================"
    echo "🏆 PERFECT OPERATIONS VERIFICATION RESULTS"
    echo "========================================"
    echo "Checks Passed: $PASSED_CHECKS/$TOTAL_CHECKS"
    echo "Success Rate: ${percentage}%"

    if [ $percentage -ge 90 ]; then
        echo -e "${GREEN}🎉 EXCELLENT: System meets Perfect Operations standards!${NC}"
    elif [ $percentage -ge 75 ]; then
        echo -e "${YELLOW}⚠️  GOOD: System mostly compliant, minor improvements needed${NC}"
    else
        echo -e "${RED}❌ NEEDS ATTENTION: Significant hardening required${NC}"
    fi

    echo
    echo "Next Steps:"
    if [ $percentage -lt 90 ]; then
        echo "1. Run: ./perfect_operations_implementation.sh"
        echo "2. Address any failed checks manually"
        echo "3. Re-run this verification script"
    fi
    echo "4. Review detailed logs in /var/log/dominion/"
    echo "5. Monitor PHI autonomous operations"
}

# Main execution
main() {
    log "🔍 Starting Perfect Operations Verification"
    log "Dominion OS - PHI Sovereign AI Security Audit"
    log "==============================================="

    # Run all checks
    check_ssh_security
    check_firewall
    check_kernel_security
    check_file_permissions
    check_backup_system
    check_monitoring
    check_security_tools
    check_network_optimization
    check_service_health
    check_compliance

    # Calculate and display results
    calculate_score

    log "Verification completed at $(date)"
}

# Execute main function
main "$@"