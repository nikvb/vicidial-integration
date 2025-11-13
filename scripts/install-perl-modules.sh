#!/bin/bash

################################################################################
# Perl Modules Installer for VICIdial DID Optimizer
#
# Installs all required Perl modules with HTTPS support on AlmaLinux/RHEL/CentOS
#
# Usage: sudo ./install-perl-modules.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Required Perl modules
PERL_MODULES=(
    "LWP::UserAgent"
    "LWP::Protocol::https"
    "JSON"
    "URI::Escape"
    "Cache::FileCache"
    "Asterisk::AGI"
    "Time::HiRes"
    "DBI"
    "DBD::mysql"
    "HTTP::Request"
    "HTTP::Response"
    "IO::Socket::SSL"
    "Mozilla::CA"
    "Net::SSLeay"
)

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Perl Modules Installer - VICIdial DID Optimizer${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        print_step "Detected OS: $PRETTY_NAME"
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

check_perl() {
    if ! command -v perl &> /dev/null; then
        print_error "Perl is not installed"
        print_info "Installing Perl..."

        if command -v dnf &> /dev/null; then
            dnf install -y perl perl-core
        elif command -v yum &> /dev/null; then
            yum install -y perl perl-core
        else
            print_error "Cannot install Perl - no package manager found"
            exit 1
        fi
    fi

    PERL_VERSION=$(perl -v | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    print_step "Perl is installed ($PERL_VERSION)"
}

install_system_dependencies() {
    print_info "Installing system dependencies for HTTPS and MySQL..."

    # Essential packages for HTTPS support and Perl module compilation
    PACKAGES=(
        "perl-CPAN"
        "perl-App-cpanminus"
        "gcc"
        "make"
        "openssl"
        "openssl-devel"
        "perl-devel"
        "mysql-devel"
        "mariadb-devel"
        "perl-IO-Socket-SSL"
        "perl-Net-SSLeay"
        "perl-Mozilla-CA"
        "perl-LWP-Protocol-https"
        "ca-certificates"
    )

    if command -v dnf &> /dev/null; then
        dnf install -y "${PACKAGES[@]}" 2>&1 | grep -v "already installed" || true
    elif command -v yum &> /dev/null; then
        yum install -y "${PACKAGES[@]}" 2>&1 | grep -v "already installed" || true
    fi

    print_step "System dependencies installed"
}

update_ca_certificates() {
    print_info "Updating CA certificates for HTTPS..."

    if command -v update-ca-trust &> /dev/null; then
        update-ca-trust force-enable
        update-ca-trust extract
        print_step "CA certificates updated"
    fi
}

install_cpanm() {
    if ! command -v cpanm &> /dev/null; then
        print_info "Installing cpanminus (faster CPAN client)..."

        # Try system package first
        if command -v dnf &> /dev/null; then
            dnf install -y perl-App-cpanminus 2>/dev/null || {
                # Fall back to CPAN installation
                curl -L https://cpanmin.us | perl - --self-upgrade
            }
        elif command -v yum &> /dev/null; then
            yum install -y perl-App-cpanminus 2>/dev/null || {
                curl -L https://cpanmin.us | perl - --self-upgrade
            }
        else
            curl -L https://cpanmin.us | perl - --self-upgrade
        fi

        print_step "cpanminus installed"
    else
        print_step "cpanminus already installed"
    fi
}

check_module() {
    local module=$1
    if perl -M"$module" -e 'exit 0' 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

install_perl_modules() {
    print_info "Checking and installing Perl modules..."
    echo ""

    local installed=0
    local already_installed=0
    local failed=0

    for module in "${PERL_MODULES[@]}"; do
        echo -n "  Checking $module... "

        if check_module "$module"; then
            echo -e "${GREEN}already installed${NC}"
            ((already_installed++))
        else
            echo -e "${YELLOW}installing...${NC}"

            # Try cpanm first (faster, quieter)
            if command -v cpanm &> /dev/null; then
                if cpanm --notest --quiet "$module" 2>&1 | grep -q "Successfully installed"; then
                    echo -e "    ${GREEN}✓ Installed successfully${NC}"
                    ((installed++))
                else
                    # Try with cpan as fallback
                    echo -e "    ${YELLOW}Retrying with CPAN...${NC}"
                    if yes '' | cpan -T "$module" 2>&1 | grep -q "OK"; then
                        echo -e "    ${GREEN}✓ Installed successfully (via CPAN)${NC}"
                        ((installed++))
                    else
                        echo -e "    ${RED}✗ Failed to install${NC}"
                        ((failed++))
                    fi
                fi
            else
                # Use cpan directly
                if yes '' | cpan -T "$module" 2>&1 | grep -q "OK"; then
                    echo -e "    ${GREEN}✓ Installed successfully${NC}"
                    ((installed++))
                else
                    echo -e "    ${RED}✗ Failed to install${NC}"
                    ((failed++))
                fi
            fi
        fi
    done

    echo ""
    print_step "Module installation summary:"
    echo "  - Already installed: $already_installed"
    echo "  - Newly installed: $installed"
    if [ $failed -gt 0 ]; then
        echo -e "  - ${RED}Failed: $failed${NC}"
    fi
}

test_https_support() {
    print_info "Testing HTTPS support..."

    local test_script=$(cat <<'PERL'
use strict;
use warnings;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new(
    timeout => 10,
    ssl_opts => { verify_hostname => 1 }
);

my $response = $ua->get('https://dids.amdy.io/api/v1/health');

if ($response->is_success || $response->code == 401) {
    print "HTTPS_OK\n";
    exit 0;
} else {
    print "HTTPS_FAILED: " . $response->status_line . "\n";
    exit 1;
}
PERL
)

    if echo "$test_script" | perl 2>&1 | grep -q "HTTPS_OK"; then
        print_step "HTTPS support is working correctly"
        return 0
    else
        print_warning "HTTPS test did not complete successfully"
        print_info "This may be normal if the API endpoint requires authentication"
        return 1
    fi
}

test_all_modules() {
    print_info "Verifying all modules are loadable..."
    echo ""

    local all_ok=true

    for module in "${PERL_MODULES[@]}"; do
        echo -n "  Testing $module... "
        if perl -M"$module" -e 'exit 0' 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
            all_ok=false
        fi
    done

    echo ""
    if [ "$all_ok" = true ]; then
        print_step "All modules are working correctly"
        return 0
    else
        print_error "Some modules failed to load"
        return 1
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Installed modules:"
    for module in "${PERL_MODULES[@]}"; do
        echo "  ✓ $module"
    done
    echo ""
    print_step "You can now run the VICIdial DID Optimizer AGI script"
    echo ""
}

################################################################################
# Main Installation Process
################################################################################

main() {
    print_header

    check_root
    detect_os
    check_perl
    install_system_dependencies
    update_ca_certificates
    install_cpanm
    install_perl_modules
    test_all_modules
    test_https_support
    print_summary
}

# Run installation
main

exit 0
