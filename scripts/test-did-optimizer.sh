#!/bin/bash
#
# VICIdial DID Optimizer - Integration Test Script
# Download: wget https://dids.amdy.io/test-did-optimizer.sh
# Run: bash test-did-optimizer.sh
#

echo "=========================================="
echo "VICIdial DID Optimizer - Integration Test"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Test 1: Check if AGI script exists
echo "1️⃣  Checking AGI script installation..."
if [ -f "/var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi" ]; then
    echo -e "${GREEN}✅ AGI script found: /var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌ AGI script not found${NC}"
    echo "   Install with: wget https://raw.githubusercontent.com/nikvb/vicidial-integration/main/scripts/install-agi.sh && bash install-agi.sh"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Check AGI script permissions
echo "2️⃣  Checking AGI script permissions..."
if [ -f "/var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi" ]; then
    PERMS=$(stat -c '%a' /var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi)
    if [ "$PERMS" = "755" ] || [ "$PERMS" = "775" ]; then
        echo -e "${GREEN}✅ Permissions correct: $PERMS${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  Permissions: $PERMS (should be 755)${NC}"
        echo "   Fix with: chmod 755 /var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}❌ Cannot check permissions - file not found${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: Check config file
echo "3️⃣  Checking configuration file..."
if [ -f "/etc/asterisk/dids.conf" ]; then
    echo -e "${GREEN}✅ Config file found: /etc/asterisk/dids.conf${NC}"

    # Check for API key
    if grep -q "api_key=did_" /etc/asterisk/dids.conf; then
        API_KEY=$(grep "api_key=" /etc/asterisk/dids.conf | cut -d'=' -f2)
        echo -e "${GREEN}✅ API key configured: ${API_KEY:0:12}...${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ API key not found or invalid${NC}"
        echo "   Download from: https://dids.amdy.io/settings (VICIdial tab)"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}❌ Config file not found${NC}"
    echo "   Download from: https://dids.amdy.io/settings (VICIdial tab)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 4: Check required Perl modules
echo "4️⃣  Checking Perl modules..."
MODULES=("LWP::UserAgent" "JSON" "URI::Escape" "DBI" "DBD::mysql" "Asterisk::AGI" "Time::HiRes" "Cache::FileCache")
ALL_MODULES_OK=true

for module in "${MODULES[@]}"; do
    if perl -M"$module" -e 'exit 0' 2>/dev/null; then
        echo -e "${GREEN}✅ $module${NC}"
    else
        echo -e "${RED}❌ $module (missing)${NC}"
        ALL_MODULES_OK=false
    fi
done

if [ "$ALL_MODULES_OK" = true ]; then
    PASSED=$((PASSED + 1))
else
    echo -e "${YELLOW}⚠️  Install missing modules with: bash install-agi.sh${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Test API connectivity
echo "5️⃣  Testing API connectivity..."
if [ -f "/etc/asterisk/dids.conf" ] && grep -q "api_key=did_" /etc/asterisk/dids.conf; then
    API_KEY=$(grep "api_key=" /etc/asterisk/dids.conf | cut -d'=' -f2)
    API_URL=$(grep "api_base_url=" /etc/asterisk/dids.conf | cut -d'=' -f2)

    # Test API endpoint
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "x-api-key: $API_KEY" \
        "$API_URL/api/v1/health" 2>/dev/null)

    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ API connection successful (HTTP $RESPONSE)${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ API connection failed (HTTP $RESPONSE)${NC}"
        echo "   Check API key and network connectivity"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠️  Skipped - no API key configured${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: Test DID selection
echo "6️⃣  Testing DID selection API..."
if [ -f "/etc/asterisk/dids.conf" ] && grep -q "api_key=did_" /etc/asterisk/dids.conf; then
    API_KEY=$(grep "api_key=" /etc/asterisk/dids.conf | cut -d'=' -f2)
    API_URL=$(grep "api_base_url=" /etc/asterisk/dids.conf | cut -d'=' -f2)

    # Test DID selection endpoint
    RESPONSE=$(curl -s \
        -H "x-api-key: $API_KEY" \
        "$API_URL/api/v1/dids/next?campaign_id=TEST&agent_id=1001&customer_phone=5551234567&customer_state=CA" 2>/dev/null)

    if echo "$RESPONSE" | grep -q "success"; then
        SELECTED_DID=$(echo "$RESPONSE" | grep -o '"phoneNumber":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✅ DID selection working${NC}"
        if [ -n "$SELECTED_DID" ]; then
            echo -e "   Selected DID: ${GREEN}$SELECTED_DID${NC}"
        fi
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ DID selection failed${NC}"
        echo "   Response: $RESPONSE"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠️  Skipped - no API key configured${NC}"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 7: Check log directory
echo "7️⃣  Checking log directory..."
if [ -d "/var/log/astguiclient" ]; then
    echo -e "${GREEN}✅ Log directory exists: /var/log/astguiclient${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌ Log directory not found${NC}"
    echo "   Create with: mkdir -p /var/log/astguiclient && chmod 755 /var/log/astguiclient"
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Integration is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Configure dialplan in VICIdial Admin → Carriers"
    echo "  2. Add AGI call before Dial() command"
    echo "  3. Make test calls to verify"
    echo "  4. Monitor logs: tail -f /var/log/astguiclient/did-optimizer.log"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please fix the issues above.${NC}"
    echo ""
    echo "Need help? Check:"
    echo "  • Installation guide: https://dids.amdy.io/installation/vicidial"
    echo "  • GitHub: https://github.com/nikvb/vicidial-integration"
    exit 1
fi
