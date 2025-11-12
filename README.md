# VICIdial DID Optimizer - Integration Package

**Public Integration Package** for connecting VICIdial call centers with DID Optimizer Pro service.

This is the **standalone public integration repository**. The main DID Optimizer application is proprietary software available at https://dids.amdy.io

> **📦 Repository**: https://github.com/nikvb/vicidial-integration
> **🌐 Web Application**: https://dids.amdy.io
> **📖 Full Documentation**: https://docs.amdy.io

## 📁 Repository Contents

### Core AGI Script
- **`agi/vicidial-did-optimizer.agi`** - Production AGI script for real-time DID selection
  - Runs during call flow in Asterisk
  - Reads configuration from `/etc/asterisk/dids.conf`
  - Makes API requests to DID Optimizer for optimal DID selection
  - Sets `${OPTIMIZER_DID}` channel variable
  - Comprehensive logging and error handling
  - File-based caching for performance

### Call Results Sync
- **`scripts/AST_DID_optimizer_sync.pl`** - Syncs VICIdial call outcomes to DID Optimizer
  - Polls `vicidial_log` table every minute
  - Reports call results (answered, busy, no-answer, etc.)
  - Tracks call duration and disposition
  - Used for AI training and performance analytics
  - Auto-configured from VICIdial database
  - Installs to `/usr/share/astguiclient/` (standard VICIdial location)

### Installation Scripts
- **`scripts/install-agi.sh`** - One-command AGI installer
- **`scripts/install-call-results-sync.sh`** - One-command sync installer
- **`scripts/install-vicidial-integration.sh`** - Complete installation

### Configuration Templates
- **`config/dids.conf`** - API credentials and settings template
- **`config/vicidial-dialplan-agi.conf`** - Dialplan integration example
- **`config/vicidial-dialplan-simple.conf`** - Simple dialplan example

### Documentation
- **`docs/CENTOS7_INSTALLATION.md`** - CentOS 7 specific instructions
- **`docs/CENTOS7_QUICKSTART.md`** - Quick start for CentOS 7

## 🚀 Quick Installation (10-15 Minutes)

### Method 1: Web-Based Setup (Recommended)

**⚠️ IMPORTANT**: Complete steps 1-3 in the web interface first, then proceed with command-line installation.

#### Step 1: Configure VICIdial API User (2 minutes)

Log in to VICIdial Admin interface:

1. Go to **Admin → Users**
2. Create or modify API user:
   - **User Level**: 8 or higher
   - **User Group**: Default or custom
   - Enable **"View Reports"** permission
3. Go to **Admin → User Groups**
4. Edit the user group
5. Set **Allowed Campaigns** to exactly: **`-ALL`**
   - ⚠️ Must be exactly `-ALL` (including the dash)
   - This grants access to all campaigns

#### Step 2: Connect VICIdial in Web Interface (2 minutes)

1. Log in to **https://dids.amdy.io**
2. Navigate to **Settings → VICIdial Integration**
3. Enter VICIdial connection details:
   - **Server Address**: Your VICIdial hostname or IP
   - **Username**: API user created in Step 1
   - **Password**: API user password
4. Click **Test Connection** button
5. Once connected, click **Sync Campaigns** button
6. Verify campaigns appear in the interface

#### Step 3: Download Configuration File (1 minute)

1. In **Settings → VICIdial Integration**, scroll to **"Step 1: Download Configuration"**
2. Click **Download dids.conf** button
3. Upload to your VICIdial server:
   ```bash
   # Upload the file
   scp dids.conf root@your-vicidial-server:/etc/asterisk/dids.conf

   # Set proper permissions (important!)
   sudo chmod 600 /etc/asterisk/dids.conf
   sudo chown asterisk:asterisk /etc/asterisk/dids.conf
   ```

#### Step 4: Install AGI Script (3 minutes)

On your VICIdial server, run:

```bash
cd /tmp
wget https://raw.githubusercontent.com/nikvb/vicidial-integration/main/scripts/install-agi.sh
chmod +x install-agi.sh
sudo ./install-agi.sh
```

**What it does:**
- ✅ Checks VICIdial environment
- ✅ Installs required Perl modules (LWP::UserAgent, JSON, etc.)
- ✅ Downloads AGI script to `/var/lib/asterisk/agi-bin/`
- ✅ Sets proper permissions (755)
- ✅ Creates log directory
- ✅ Verifies installation

#### Step 5: Generate Modified Dialplan (2 minutes)

**⚠️ CRITICAL**: Use the web-based dialplan generator - **DO NOT edit dialplan files manually!**

1. In **VICIdial Admin**, go to **Admin → Carriers**
2. Select your carrier
3. **Copy the entire Dialplan Entry** content
4. Go to **https://dids.amdy.io** → **Settings → VICIdial Integration**
5. Scroll to **"Step 2: Generate Modified Dialplan"**
6. **Paste** your carrier's dialplan into the text area
7. Click **Generate Modified Dialplan** button
8. The generator automatically inserts AGI calls at the correct position
9. Click **Copy** button to copy generated dialplan
10. Return to **VICIdial Admin → Carriers**
11. **Replace** your carrier's Dialplan Entry with generated version
12. Click **Submit**

**Why use the generator?**
- ✅ Automatically inserts AGI calls at correct position
- ✅ Preserves all existing VICIdial functionality
- ✅ Handles different dialplan patterns
- ✅ No syntax errors
- ✅ Includes proper variable passing

**VICIdial automatically reloads the dialplan** - no Asterisk restart needed!

#### Step 6: Test Integration (2 minutes)

```bash
# Monitor logs in real-time
tail -f /var/log/astguiclient/did-optimizer.log

# Make a test call through VICIdial
# You should see logs showing DID selection

# Verify in dashboard
# Go to https://dids.amdy.io dashboard
# Check for call records appearing
```

#### Step 7: Install Call Results Sync (Optional - Recommended)

**This syncs VICIdial call outcomes back to DID Optimizer for AI training and performance analytics.**

One-line installer:
```bash
curl -fsSL https://raw.githubusercontent.com/nikvb/vicidial-integration/main/scripts/install-call-results-sync.sh | sudo bash
```

**What it does:**
- Installs Perl dependencies (DBI, DBD::mysql, LWP::UserAgent, JSON)
- Downloads sync script to `/usr/share/astguiclient/`
- Creates cron job (runs every minute)
- Reads config from `/etc/asterisk/dids.conf`
- Logs to `/var/log/astguiclient/did-optimizer-sync.log`

**Monitor sync activity:**
```bash
# View real-time sync logs
tail -f /var/log/astguiclient/did-optimizer-sync.log

# Check recent syncs
grep 'Summary:' /var/log/astguiclient/did-optimizer-sync.log | tail -5

# Check for errors
grep 'ERROR\|Failed' /var/log/astguiclient/did-optimizer-sync.log
```

### Method 2: Command Line Installation (Advanced)

For advanced users who prefer command-line configuration:

1. **Install AGI Script**
   ```bash
   cd /tmp
   wget https://raw.githubusercontent.com/nikvb/vicidial-integration/main/scripts/install-agi.sh
   chmod +x install-agi.sh
   sudo ./install-agi.sh
   ```

2. **Get API Key from Website**
   - Log in to https://dids.amdy.io
   - Go to **Settings → API Keys**
   - Click **Create API Key**
   - Copy the generated key (save it - shown only once!)

3. **Configure dids.conf**
   ```bash
   sudo nano /etc/asterisk/dids.conf
   ```

   Update required settings:
   ```ini
   [general]
   api_base_url=https://dids.amdy.io
   api_key=did_YOUR_ACTUAL_API_KEY_HERE
   fallback_did=+18005551234

   # Database settings (usually auto-detected from /etc/astguiclient.conf)
   db_host=localhost
   db_user=cron
   db_pass=1234
   db_name=asterisk
   ```

4. **Generate Dialplan Using Website**

   Even for command-line installation, **use the web-based dialplan generator**!

   - Go to https://dids.amdy.io → **Settings → VICIdial Integration**
   - Copy your carrier's dialplan from **VICIdial Admin → Carriers**
   - Paste into dialplan generator
   - Click **Generate Modified Dialplan**
   - Copy generated dialplan back to VICIdial Admin
   - Click **Submit**

   **DO NOT manually edit dialplan files** - the generator ensures correct integration.

## 🔧 Configuration Reference

### Required Settings (in `/etc/asterisk/dids.conf`)

```ini
[general]
# API Configuration (REQUIRED)
api_base_url=https://dids.amdy.io
api_key=did_YOUR_API_KEY_HERE
api_timeout=10
max_retries=3

# Fallback DID (REQUIRED - used when API unavailable)
fallback_did=+18005551234

# Logging
log_file=/var/log/astguiclient/did-optimizer.log
debug=1

# Database Configuration (usually auto-detected from /etc/astguiclient.conf)
db_host=localhost
db_user=cron
db_pass=1234
db_name=asterisk
db_port=3306

# Performance Settings
daily_usage_limit=200
max_distance_miles=500

# Geographic Settings
enable_geographic_routing=1
enable_state_fallback=1
enable_area_code_detection=1
```

## 📊 How It Works

### Call Flow

1. **Customer call initiated** through VICIdial
2. **Asterisk executes dialplan** which calls the AGI script
3. **AGI script reads configuration** from `/etc/asterisk/dids.conf`
4. **API request made** to DID Optimizer with:
   - Customer phone number
   - Campaign ID
   - Agent ID (if available)
   - Customer state/ZIP (from VICIdial database)
5. **Optimal DID selected** based on:
   - Geographic proximity to customer
   - Rotation rules and daily limits
   - Reputation scores
   - Campaign-specific settings
6. **Caller ID set** to selected DID via `${OPTIMIZER_DID}` variable
7. **Call proceeds** with optimized caller ID
8. **Call tracked** in DID Optimizer dashboard

### Data Used for DID Selection

- **Customer Phone Number**: Area code and geographic detection
- **Campaign ID**: Campaign-specific rotation rules
- **Agent ID**: Agent-specific tracking
- **Customer Location**: State and ZIP code (from VICIdial database)
- **Time of Day**: For pattern analysis
- **Call History**: Previous outcomes and performance
- **DID Reputation**: Spam scores and carrier filtering status

## 🧪 Testing & Verification

### Test AGI Script
```bash
# Test with sample data
sudo -u asterisk /var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi TEST001 1001 4155551234

# Expected output: Selected DID and debug information
```

### Monitor Logs
```bash
# Real-time log monitoring
tail -f /var/log/astguiclient/did-optimizer.log

# Search for errors
grep ERROR /var/log/astguiclient/did-optimizer.log

# View recent DID selections
grep "Selected DID" /var/log/astguiclient/did-optimizer.log | tail -20
```

### Test API Connection
```bash
curl -H "x-api-key: did_YOUR_API_KEY" https://dids.amdy.io/api/v1/health
```

### Verify in VICIdial
1. Make a test call through VICIdial
2. Check Asterisk logs: `asterisk -rx "core show channels verbose"`
3. Verify caller ID shows optimized DID
4. Check DID Optimizer dashboard for call record at https://dids.amdy.io

## 🔥 Troubleshooting

### AGI Script Not Running

**Check AGI script exists and is executable:**
```bash
ls -la /var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi
# Should show: -rwxr-xr-x (755 permissions)
```

**Check Perl modules:**
```bash
perl -e 'use LWP::UserAgent; use JSON; use URI::Escape; use Cache::FileCache; use Asterisk::AGI; print "OK\n"'
```

**Check logs:**
```bash
tail -100 /var/log/astguiclient/did-optimizer.log
```

### API Connection Failed

**Verify configuration:**
```bash
grep -E "^(api_base_url|api_key)" /etc/asterisk/dids.conf
```

**Test connectivity:**
```bash
curl -v -H "x-api-key: YOUR_API_KEY" https://dids.amdy.io/api/v1/health
```

**Check firewall:**
```bash
# Ensure outbound HTTPS (port 443) is allowed
sudo iptables -L OUTPUT -n | grep 443
```

### No DIDs Returned

**Possible causes:**
1. No DIDs loaded in DID Optimizer database
2. All DIDs at daily usage limit (200 calls/day default)
3. Reputation scores too low (< 50 filtered out)
4. Geographic filters too restrictive

**Check in DID Optimizer:**
- Go to **DID Management** page at https://dids.amdy.io
- Verify DIDs are active and have good reputation scores
- Check usage statistics

### Configuration File Issues

```bash
# Verify file exists with correct permissions
ls -la /etc/asterisk/dids.conf
# Should show: -rw------- (600 permissions)

# Re-download from web interface if missing
# Or get template: https://github.com/nikvb/vicidial-integration/blob/main/config/dids.conf
```

### Database Connection Issues

**Check VICIdial database config:**
```bash
cat /etc/astguiclient.conf | grep VARDB
```

**Test database connection:**
```bash
mysql -h localhost -u cron -p1234 asterisk -e "SELECT COUNT(*) FROM vicidial_list LIMIT 1"
```

### Call Results Sync Issues

**Check if sync is installed:**
```bash
ls -la /usr/share/astguiclient/AST_DID_optimizer_sync.pl
crontab -l | grep AST_DID_optimizer_sync
```

**Monitor sync activity:**
```bash
# View real-time logs
tail -f /var/log/astguiclient/did-optimizer-sync.log

# Check recent syncs
grep 'Summary:' /var/log/astguiclient/did-optimizer-sync.log | tail -10
```

**Manual test:**
```bash
sudo perl /usr/share/astguiclient/AST_DID_optimizer_sync.pl
```

## 📝 File Locations

After installation:

**Core Files:**
- **AGI Script**: `/var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi`
- **Configuration**: `/etc/asterisk/dids.conf`
- **Logs**: `/var/log/astguiclient/did-optimizer.log`
- **Cache**: `/tmp/did_optimizer/` (auto-created)

**Call Results Sync (if installed):**
- **Sync Script**: `/usr/share/astguiclient/AST_DID_optimizer_sync.pl`
- **Sync Logs**: `/var/log/astguiclient/did-optimizer-sync.log`
- **State File**: `/tmp/did-optimizer-last-check.txt`
- **Cron Job**: Runs every minute via root crontab

## ✅ Verification Checklist

Installation complete when:

**Web Interface Setup:**
- [ ] VICIdial API user created (level 8+)
- [ ] Allowed Campaigns set to `-ALL`
- [ ] VICIdial connection tested in web interface
- [ ] Campaigns synced from VICIdial
- [ ] dids.conf downloaded from web interface

**Server Installation:**
- [ ] dids.conf uploaded to `/etc/asterisk/dids.conf`
- [ ] dids.conf permissions set to 600
- [ ] AGI script installed at `/var/lib/asterisk/agi-bin/vicidial-did-optimizer.agi`
- [ ] AGI script has 755 permissions
- [ ] Perl dependencies installed successfully

**Dialplan Integration:**
- [ ] Dialplan generated using web interface
- [ ] Generated dialplan applied in VICIdial Carriers
- [ ] Test call completed successfully
- [ ] Logs showing DID selection activity

**Verification:**
- [ ] Dashboard showing call records at https://dids.amdy.io
- [ ] Caller ID showing optimized DIDs on test calls

**Optional (Recommended):**
- [ ] Call results sync installed
- [ ] Sync cron job running every minute
- [ ] Sync logs showing successful uploads

## 📞 Support & Documentation

- **📖 Full Documentation**: https://docs.amdy.io
- **🌐 Web Application**: https://dids.amdy.io
- **💻 GitHub Repository**: https://github.com/nikvb/vicidial-integration
- **🐛 Report Issues**: https://github.com/nikvb/vicidial-integration/issues
- **📧 Email Support**: support@amdy.io

## 📄 License

This integration package is open source and available for use with the DID Optimizer Pro service.

The main DID Optimizer application is proprietary software. For pricing and access:
- Visit: https://dids.amdy.io
- Sign up for a free trial
- Plans start at $99/month

---

**Installation Time**: 10-15 minutes with web-based setup

Your VICIdial system will automatically optimize caller ID selection for improved answer rates and call performance! 🚀
