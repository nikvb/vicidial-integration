#!/bin/bash

################################################################################
# VICIdial DID Optimizer - AGI Installation Script
#
# This script installs the vicidial-did-optimizer.agi script and its
# dependencies on a VICIdial server.
#
# Usage: sudo ./install-agi.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGI_DIR="/var/lib/asterisk/agi-bin"
AGI_SCRIPT="vicidial-did-optimizer.agi"
AGI_SOURCE="https://raw.githubusercontent.com/nikvb/vicidial-integration/main/agi/vicidial-did-optimizer.agi"
CONFIG_FILE="/etc/asterisk/dids.conf"
LOG_DIR="/var/log/astguiclient"
ASTERISK_USER="asterisk"
ASTERISK_GROUP="asterisk"

# Required Perl modules (including HTTPS support)
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
    echo -e "${BLUE}  VICIdial DID Optimizer - AGI Installation${NC}"
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

check_vicidial() {
    if [ ! -d "$AGI_DIR" ]; then
        print_error "VICIdial AGI directory not found: $AGI_DIR"
        print_info "This script should be run on a VICIdial server"
        exit 1
    fi
    print_step "VICIdial AGI directory found"
}

check_perl() {
    if ! command -v perl &> /dev/null; then
        print_error "Perl is not installed"
        exit 1
    fi
    print_step "Perl is installed ($(perl -v | grep -oP 'v\d+\.\d+\.\d+' | head -1))"
}

install_system_dependencies() {
    print_info "Installing system dependencies for HTTPS and MySQL..."

    # Essential packages for HTTPS support and Perl module compilation
    local packages=(
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

    # Try dnf first, then yum, then apt-get
    if command -v dnf &> /dev/null; then
        for pkg in "${packages[@]}"; do
            dnf install -y "$pkg" 2>&1 | grep -q "already installed\|Complete" || true
        done
    elif command -v yum &> /dev/null; then
        for pkg in "${packages[@]}"; do
            yum install -y "$pkg" 2>&1 | grep -q "already installed\|Complete" || true
        done
    elif command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y build-essential libssl-dev libmysqlclient-dev \
            libwww-perl libnet-ssleay-perl libio-socket-ssl-perl \
            libmozilla-ca-perl cpanminus ca-certificates 2>&1 | grep -v "already"
    fi

    # Update CA certificates
    if command -v update-ca-trust &> /dev/null; then
        update-ca-trust force-enable 2>/dev/null
        update-ca-trust extract 2>/dev/null
    elif command -v update-ca-certificates &> /dev/null; then
        update-ca-certificates 2>/dev/null
    fi

    print_step "System dependencies installed"
}

install_perl_modules() {
    print_info "Checking Perl module dependencies..."

    local missing_modules=()

    for module in "${PERL_MODULES[@]}"; do
        if ! perl -M"$module" -e 1 2>/dev/null; then
            missing_modules+=("$module")
        else
            print_step "$module is installed"
        fi
    done

    if [ ${#missing_modules[@]} -eq 0 ]; then
        print_step "All Perl modules are installed"
        return 0
    fi

    print_warning "Missing Perl modules: ${missing_modules[*]}"
    print_info "Installing missing modules..."

    # Install cpanminus if not available (much faster than cpan)
    if ! command -v cpanm &> /dev/null; then
        print_info "Installing cpanminus..."
        if command -v dnf &> /dev/null; then
            dnf install -y perl-App-cpanminus 2>/dev/null || {
                # Fall back to curl installation
                curl -L https://cpanmin.us | perl - --self-upgrade 2>/dev/null
            }
        elif command -v yum &> /dev/null; then
            yum install -y perl-App-cpanminus 2>/dev/null || {
                curl -L https://cpanmin.us | perl - --self-upgrade 2>/dev/null
            }
        elif command -v apt-get &> /dev/null; then
            apt-get install -y cpanminus 2>/dev/null
        else
            curl -L https://cpanmin.us | perl - --self-upgrade 2>/dev/null
        fi
    fi

    # Try cpanm first (faster and quieter), fall back to cpan
    if command -v cpanm &> /dev/null; then
        for module in "${missing_modules[@]}"; do
            print_info "Installing $module..."
            if cpanm --notest --quiet "$module" 2>&1 | grep -q "Successfully installed\|is up to date"; then
                print_step "$module installed successfully"
            else
                # Try with cpan as fallback
                print_warning "Retrying $module with CPAN..."
                if yes '' | cpan -T "$module" 2>&1 | grep -q "OK\|up to date"; then
                    print_step "$module installed successfully (via CPAN)"
                else
                    print_error "Failed to install $module"
                    return 1
                fi
            fi
        done
    else
        # Use cpan directly
        for module in "${missing_modules[@]}"; do
            print_info "Installing $module..."
            if yes '' | cpan -T "$module" 2>&1 | grep -q "OK\|up to date"; then
                print_step "$module installed successfully"
            else
                print_error "Failed to install $module"
                return 1
            fi
        done
    fi

    print_step "All Perl modules installed successfully"
}

download_agi_script() {
    print_info "Downloading AGI script..."

    # If running from the repo directory, copy locally
    if [ -f "./vicidial-did-optimizer.agi" ]; then
        print_info "Using local copy of AGI script"
        cp "./vicidial-did-optimizer.agi" "$AGI_DIR/$AGI_SCRIPT"
    elif [ -f "../vicidial-integration/vicidial-did-optimizer.agi" ]; then
        print_info "Using local copy from vicidial-integration directory"
        cp "../vicidial-integration/vicidial-did-optimizer.agi" "$AGI_DIR/$AGI_SCRIPT"
    else
        # Download from GitHub
        print_info "Downloading from GitHub..."
        if command -v wget &> /dev/null; then
            wget -q -O "$AGI_DIR/$AGI_SCRIPT" "$AGI_SOURCE" || {
                print_error "Failed to download AGI script"
                exit 1
            }
        elif command -v curl &> /dev/null; then
            curl -s -o "$AGI_DIR/$AGI_SCRIPT" "$AGI_SOURCE" || {
                print_error "Failed to download AGI script"
                exit 1
            }
        else
            print_error "Neither wget nor curl is available"
            exit 1
        fi
    fi

    print_step "AGI script downloaded to $AGI_DIR/$AGI_SCRIPT"
}

set_permissions() {
    print_info "Setting file permissions..."

    # Make AGI script executable
    chmod 755 "$AGI_DIR/$AGI_SCRIPT"
    # Note: VICIdial runs as root, no need to change ownership

    print_step "Permissions set (755)"
}

create_log_directory() {
    if [ ! -d "$LOG_DIR" ]; then
        print_info "Creating log directory: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi

    chmod 755 "$LOG_DIR"
    # Note: VICIdial runs as root, no need to change ownership

    print_step "Log directory ready: $LOG_DIR"
}

verify_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_warning "Configuration file not found: $CONFIG_FILE"
        print_info "Please download dids.conf from the DID Optimizer web interface"
        print_info "and place it at: $CONFIG_FILE"
        print_info "Then run: sudo chmod 600 $CONFIG_FILE"
    else
        print_step "Configuration file exists: $CONFIG_FILE"

        # Check permissions
        local perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %OLp "$CONFIG_FILE" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            print_warning "Configuration file permissions should be 600 (currently: $perms)"
            chmod 600 "$CONFIG_FILE"
            print_step "Corrected permissions to 600"
        fi

        # Note: VICIdial runs as root, no need to change ownership
    fi
}

test_installation() {
    print_info "Testing AGI script..."

    # Basic syntax check
    if perl -c "$AGI_DIR/$AGI_SCRIPT" 2>&1 | grep -q "syntax OK"; then
        print_step "Perl syntax check passed"
    else
        print_error "Perl syntax check failed"
        perl -c "$AGI_DIR/$AGI_SCRIPT"
        return 1
    fi

    # Test HTTPS support
    print_info "Testing HTTPS/SSL support..."
    local https_test=$(cat <<'PERL'
use strict;
use warnings;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new(
    timeout => 10,
    ssl_opts => { verify_hostname => 1 }
);

my $response = $ua->get('https://dids.amdy.io/api/v1/health');

if ($response->is_success || $response->code == 401 || $response->code == 404) {
    print "HTTPS_OK\n";
    exit 0;
} else {
    print "HTTPS_FAILED: " . $response->status_line . "\n";
    exit 1;
}
PERL
)

    if echo "$https_test" | perl 2>&1 | grep -q "HTTPS_OK"; then
        print_step "HTTPS support is working correctly"
    else
        local error_msg=$(echo "$https_test" | perl 2>&1)
        if echo "$error_msg" | grep -q "Protocol scheme 'https' is not supported"; then
            print_error "HTTPS not supported - missing LWP::Protocol::https module"
            print_info "This should have been installed. Please check the error messages above."
            return 1
        elif echo "$error_msg" | grep -q "SSL"; then
            print_warning "SSL verification issue - may be normal for self-signed certificates"
        else
            print_warning "HTTPS test inconclusive: $error_msg"
            print_info "This may be normal if the API requires authentication"
        fi
    fi
}

download_test_script() {
    print_info "Downloading integration test script..."

    TEST_SCRIPT="/tmp/test-did-optimizer.sh"
    TEST_URL="https://raw.githubusercontent.com/nikvb/vicidial-integration/main/scripts/test-did-optimizer.sh"

    if wget -q -O "$TEST_SCRIPT" "$TEST_URL" 2>/dev/null; then
        chmod +x "$TEST_SCRIPT"
        print_step "Test script downloaded to $TEST_SCRIPT"

        echo ""
        read -p "Would you like to run the integration test now? (y/n): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            print_info "Running integration test..."
            echo ""
            bash "$TEST_SCRIPT"
            echo ""
        else
            print_info "You can run the test later with: bash $TEST_SCRIPT"
        fi
    else
        print_warning "Failed to download test script"
        print_info "You can download it manually:"
        print_info "wget $TEST_URL"
        print_info "bash test-did-optimizer.sh"
    fi
}

print_next_steps() {
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"

    echo -e "${BLUE}Next Steps:${NC}\n"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "1. ${YELLOW}Download dids.conf${NC}"
        echo -e "   - Log in to DID Optimizer web interface"
        echo -e "   - Go to Settings → VICIdial Integration"
        echo -e "   - Copy the configuration and paste into: ${CONFIG_FILE}"
        echo -e "   - Run: ${BLUE}sudo chmod 600 $CONFIG_FILE${NC}\n"
    fi

    echo -e "2. ${YELLOW}Configure Dialplan in VICIdial Admin${NC}"
    echo -e "   ${RED}⚠️  DO NOT edit /etc/asterisk/extensions.conf directly!${NC}"
    echo -e "   Instead, use VICIdial Admin interface:\n"
    echo -e "   - Go to: ${BLUE}Admin → Carriers${NC}"
    echo -e "   - Click on your outbound carrier"
    echo -e "   - Scroll to ${BLUE}\"Dialplan Entry\"${NC} section"
    echo -e "   - Add BEFORE your Dial() command:\n"
    echo -e "   ${BLUE}exten => _91NXXNXXXXXX,n,AGI(vicidial-did-optimizer.agi)${NC}"
    echo -e "   ${BLUE}exten => _91NXXNXXXXXX,n,Set(CALLERID(num)=\${OPTIMIZER_DID})${NC}\n"
    echo -e "   - Click ${BLUE}\"Submit\"${NC} to save\n"

    echo -e "3. ${YELLOW}Test Integration${NC}"
    echo -e "   Run automated test script:"
    echo -e "   ${BLUE}wget https://raw.githubusercontent.com/nikvb/vicidial-integration/main/scripts/test-did-optimizer.sh${NC}"
    echo -e "   ${BLUE}bash test-did-optimizer.sh${NC}\n"

    echo -e "4. ${YELLOW}Monitor${NC}"
    echo -e "   - Make a test call"
    echo -e "   - Monitor logs: ${BLUE}tail -f $LOG_DIR/did-optimizer.log${NC}"
    echo -e "   - Check DID Optimizer dashboard for call activity\n"

    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
}

################################################################################
# Main Installation Process
################################################################################

main() {
    print_header

    check_root
    check_vicidial
    check_perl
    install_system_dependencies
    install_perl_modules
    download_agi_script
    set_permissions
    create_log_directory
    verify_config
    test_installation
    download_test_script
    print_next_steps
}

# Run installation
main

exit 0
