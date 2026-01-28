# ClawdBot + LLM Proxy Migration to Headless Mac Mini

## Context

### Original Request
Migrate ClawdBot and LLM Proxy to a new Mac Mini that will run headless (no monitor/keyboard). Requires full permissions pre-configured and remote accessibility via Tailscale.

### Interview Summary
**Key Discussions**:
- Mac Mini not yet purchased (planning ahead for setup)
- No MDM enrollment (personal Mac) - manual permission grants required
- Tailscale chosen for remote access
- Browser automation needed (Playwright) - requires Screen Recording + HDMI dummy plug
- Full migration preserving all sessions, credentials, and configurations
- Dedicated ClawdBot server (no other services)

**Research Findings**:
- ClawdBot: Multi-channel AI assistant gateway (`clawdbot@2026.1.16-2`)
- LLM Proxy: Custom FastAPI application with key rotation (`Mirrowel/LLM-API-Key-Proxy`)
- Both run as LaunchAgents (require user session, hence auto-login)
- TCC permissions cannot be pre-granted without MDM - must click "Allow" with display connected
- HDMI dummy plug required for GPU driver activation on headless Mac

### Metis Review
**Identified Gaps** (addressed):
- Service startup ordering: ClawdBot depends on LLM Proxy being available
- Username path dependency: LaunchAgent plists have hardcoded paths to `/Users/joshuashin/`
- OAuth re-authentication: May need manual token refresh on new machine
- Tailscale key expiration: Default 180-day expiry needs disabling
- Power failure during migration: Use rsync with resume capability
- macOS updates breaking TCC: Pin macOS version, disable auto-updates

---

## Work Objectives

### Core Objective
Migrate ClawdBot gateway and LLM API Key Proxy to a new headless Mac Mini with full remote accessibility via Tailscale, preserving all existing sessions, credentials, and configurations. Additionally, set up Superset for parallel agent orchestration, accessible via low-latency Parsec remote desktop.

### Concrete Deliverables
- Mac Mini running headless with both services auto-starting on boot
- Remote access via Tailscale (SSH + Parsec for low-latency GUI control)
- All TCC permissions granted (Accessibility, Screen Recording, Full Disk Access)
- All existing ClawdBot sessions and credentials preserved
- All LLM Proxy API keys and configurations preserved
- Playwright browser automation functional without display
- **Parsec** installed and configured for frictionless remote desktop access
- **Superset** installed for parallel agent orchestration (Claude Code, OpenCode)

### Definition of Done
- [ ] Both services respond correctly from Tailscale-connected device
- [ ] Telegram bot responds to `/ping` command
- [ ] LLM Proxy responds to authenticated curl (retrieve key from .env, don't hardcode)
- [ ] Playwright screenshot test passes without physical display
- [ ] **Parsec connection from main Mac to Mac Mini is responsive (< 20ms input lag)**
- [ ] **Superset launches and can spawn Claude Code agents in isolated worktrees**
- [ ] 24-hour soak test passes:
  - swap used < 1GB
  - memory_pressure shows "OK"
  - no unexpected service restarts
- [ ] 7-day extended soak test passes (before decommissioning old machine)

### Must Have
- Same username `joshuashin` on new machine (avoids path changes)
- HDMI dummy plug for GPU activation
- Tailscale with disabled key expiry
- Auto-login configured for LaunchAgents
- All sleep modes disabled
- Screen Recording permission for Terminal, Node.js, Chromium browser, AND **Parsec**
- **FileVault DISABLED** (required for unattended boot - see below)
- **Parsec** installed on both Macs (host on Mac Mini, client on main Mac)
- **Superset** installed on Mac Mini with Claude Code configured

### FileVault Decision (CRITICAL for Unattended Boot)

**CHOSEN POLICY: FileVault MUST be DISABLED on the Mac Mini.**

**Rationale:**
- This plan requires unattended boot after power failure (auto-power-on + auto-login + LaunchAgents)
- FileVault requires password entry at pre-boot (before macOS loads, before auto-login)
- With FileVault enabled, any power failure = machine stuck at pre-boot password prompt = services down until manual intervention

**If you require encryption:**
- Accept that reboots/power-loss require physical presence or KVM-over-IP to enter password
- This changes the availability model from "fully unattended" to "requires manual intervention on boot"
- Update Definition of Done accordingly

**For this plan: FileVault is DISABLED, enabling fully unattended operation.**

### Must NOT Have (Guardrails)
- NO containerization (Docker/Podman) - adds unnecessary complexity
- NO binding LLM Proxy to 0.0.0.0 without firewall rules
- NO macOS auto-updates enabled
- NO running both Telegram bots simultaneously (same token)
- NO deleting old machine data until 7-day soak test passes
- NO monitoring/alerting setup (defer to post-migration)
- NO cloud backup automation (defer to post-migration)
- NO FileVault encryption (conflicts with unattended boot requirement)

---

## API Key Mapping (CRITICAL)

### LLM Proxy Authentication

The LLM Proxy uses `PROXY_API_KEY` in its `.env` file to authenticate incoming requests. Clients use `LLM_PROXY_API_KEY` environment variable.

**Key Mapping:**
```
PROXY_API_KEY (in .env)     = <your-key>  ← Server-side, read by proxy at startup
LLM_PROXY_API_KEY (shell)   = <your-key>  ← Client-side, used by OpenCode and curl
```

**Both must have the same value.** The proxy expects `Authorization: Bearer <your-key>` in requests.

**Source of truth:** The actual key value is in `~/Projects/LLM-API-Key-Proxy/.env` as `PROXY_API_KEY=<value>`.

**Where to set `LLM_PROXY_API_KEY`:**
- Shell profile: `~/.zshrc` or `~/.bash_profile` (for interactive SSH sessions)
- LaunchAgent plist: Under `EnvironmentVariables` key (for LaunchAgent-spawned processes)

### Verification Commands (with auth)

All LLM Proxy verification commands MUST retrieve the token from source files at runtime:
```bash
# Correct (retrieve key from .env, NEVER hardcode):
PROXY_KEY=$(grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)
curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models

# Incorrect (will fail with 401 Unauthorized):
curl http://127.0.0.1:8000/v1/models
```

**SECURITY RULE:** Never embed actual token values in this plan or any documentation. Always retrieve from source files at execution time.

---

## Migration Artifacts Inventory (CRITICAL)

### LLM Proxy Files to Migrate

| File/Directory | Type | Description |
|----------------|------|-------------|
| `/Users/joshuashin/Projects/LLM-API-Key-Proxy/.env` | **SECRET** | All provider API keys (Anthropic, OpenAI, Gemini, etc.) |
| `/Users/joshuashin/Projects/LLM-API-Key-Proxy/oauth_creds/` | **SECRET** | OAuth tokens (may be empty, check before migration) |
| `/Users/joshuashin/Projects/LLM-API-Key-Proxy/key_usage.json` | State | API key usage tracking and rate limit state |
| `/Users/joshuashin/Projects/LLM-API-Key-Proxy/launcher_config.json` | Config | Proxy launch settings (host, port, logging) |
| `/Users/joshuashin/Projects/LLM-API-Key-Proxy/requirements.txt` | Deps | Python dependencies |
| `/Users/joshuashin/Projects/LLM-API-Key-Proxy/src/` | Code | Application source code |
| `/Users/joshuashin/Library/LaunchAgents/com.llm-api-key-proxy.plist` | Service | macOS daemon configuration |

**NOTE:** Do NOT migrate the `venv/` directory. Recreate it on the target machine (venv paths are machine-specific).

**Version Pinning (capture before migration):**
The LLM-API-Key-Proxy is a local clone from `Mirrowel/LLM-API-Key-Proxy`. To ensure reproducibility:
```bash
# On SOURCE machine, capture the exact commit hash
cd ~/Projects/LLM-API-Key-Proxy
git rev-parse HEAD > .migration-commit-hash
git log -1 --oneline >> .migration-commit-hash

# This file will be transferred with rsync and serves as the version reference
# If issues arise on the new machine, you can checkout the exact same commit
```

### ClawdBot Files to Migrate

| File/Directory | Type | Description |
|----------------|------|-------------|
| `/Users/joshuashin/.clawdbot/clawdbot.json` | **SECRET** | Main config with Telegram bot token |
| `/Users/joshuashin/.clawdbot/credentials/` | **SECRET** | Channel credentials (WhatsApp, etc.) |
| `/Users/joshuashin/.clawdbot/agents/main/sessions/` | State | Active session data |
| `/Users/joshuashin/.clawdbot/agents/main/agent/auth-profiles.json` | **SECRET** | AI provider auth profiles |
| `/Users/joshuashin/.clawdbot/logs/` | Logs | Gateway logs (optional, can skip) |
| `/Users/joshuashin/clawd/` | Workspace | Agent workspace (AGENTS.md, skills/, jobs/) |
| `/Users/joshuashin/.config/opencode/opencode.json` | Config | OpenCode IDE integration |
| `/Users/joshuashin/Library/LaunchAgents/com.clawdbot.gateway.plist` | Service | macOS daemon configuration |

### ClawdBot Gateway Token Location

The gateway auth token is stored in:
1. **LaunchAgent plist**: `/Users/joshuashin/Library/LaunchAgents/com.clawdbot.gateway.plist` (as `CLAWDBOT_GATEWAY_TOKEN` env var)
2. **Config file**: `/Users/joshuashin/.clawdbot/clawdbot.json` (under `gateway.auth.token`)

**To retrieve the token for verification commands:**
```bash
# From LaunchAgent plist:
grep -A1 CLAWDBOT_GATEWAY_TOKEN ~/Library/LaunchAgents/com.clawdbot.gateway.plist

# Or from config file:
jq '.gateway.auth.token' ~/.clawdbot/clawdbot.json
```

**IMPORTANT**: Never embed tokens in documentation. Always retrieve from source files at execution time.

---

## Ports and Network Security Inventory

### Expected Open Ports (localhost only)

| Service | Port | Bind Address | Protocol | Purpose |
|---------|------|--------------|----------|---------|
| LLM Proxy | 8000 | `127.0.0.1` | HTTP | OpenAI/Anthropic-compatible API |
| ClawdBot Gateway | 18789 | `127.0.0.1` | HTTP/WS | Gateway control plane |
| Tailscale | 41641 | `0.0.0.0` | UDP | WireGuard tunnel |
| SSH | 22 | `0.0.0.0` | TCP | Remote shell access |

### Security Posture

**Externally Accessible (via Tailscale):**
- SSH (port 22) - Tailscale ACLs + SSH keys protect access
- Screen Sharing (port 5900) - Only via Tailscale tunnel
- Tailscale itself (UDP 41641) - Encrypted WireGuard

**Localhost Only (NOT externally accessible):**
- LLM Proxy (8000) - Contains API keys, must stay on loopback
  - **Config location**: `/Users/joshuashin/Projects/LLM-API-Key-Proxy/launcher_config.json` → `host` field
- ClawdBot Gateway (18789) - Internal control plane
  - **Config location**: `/Users/joshuashin/.clawdbot/clawdbot.json` → `gateway.bind` field
  - **Verify on target**: `jq '.gateway.bind' ~/.clawdbot/clawdbot.json` should show `"loopback"`

**Verification Commands:**
```bash
# Check what's listening and where
sudo lsof -i -P | grep LISTEN

# Expected output should show:
# - Port 8000 bound to 127.0.0.1 (NOT 0.0.0.0)
# - Port 18789 bound to 127.0.0.1 (NOT 0.0.0.0)
# - Port 22 bound to 0.0.0.0 (SSH)

# Verify LLM Proxy is NOT externally accessible
curl http://$(tailscale ip -4):8000/v1/models  # Should fail (connection refused)
```

**macOS Firewall:**
- Enable via System Settings → Network → Firewall
- Block all incoming except SSH and Tailscale
- Both LLM Proxy and ClawdBot should be "Allow incoming" = OFF (they're localhost-only anyway)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: N/A (infrastructure migration)
- **User wants tests**: Manual verification with explicit commands
- **Framework**: Manual execution verification at each phase

### Manual QA Approach
Each TODO includes detailed verification procedures with:
- Specific commands to run
- Expected outputs
- Screenshot/evidence where applicable

---

## Task Flow

```
Phase 0 (Purchase) → Phase 1 (Initial Setup) → Phase 2 (Headless Config)
                                                        ↓
Phase 7 (Cleanup) ← Phase 6 (Workflow) ← Phase 5 (Verify + Superset) ← Phase 4 (Migration) ← Phase 3 (Remote + Parsec)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 3a, 3b, 3c | Remote access, permissions, and Parsec can be done in parallel |

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | 0 | Need Mac Mini before setup |
| 2 | 1 | Need macOS configured before headless settings |
| 3 | 2 | Need auto-login before permissions (for LaunchAgents) |
| 4 | 3 | Need permissions granted before migrating services |
| 5a, 5b | 4 | Need services running before headless verification |
| 5c | 5b | Install Superset after soak test passes |
| 6 | 5c | Configure workflow after Superset is working |
| 7 | 6 | Cleanup after 7-day operation |

---

## TODOs

### Phase 0: Hardware Acquisition

- [ ] 0. Purchase Mac Mini and HDMI Dummy Plug

  **What to do**:
  - Purchase Mac Mini (M4 recommended, 16GB+ RAM for Playwright)
  - Purchase HDMI dummy plug (4K headless display emulator)
  - Purchase ethernet cable (more reliable than WiFi for server)
  
  **Recommended Products (with URLs)**:
  - Mac Mini: Apple M4 or M4 Pro with 16GB+ RAM
    - URL: https://www.apple.com/shop/buy-mac/mac-mini
    - Minimum SKU: MQT83LL/A (M4, 16GB, 256GB)
  - HDMI Dummy Plug: 4K Headless Display Emulator
    - Amazon ASIN: B06XT1Z9TF or B07FB8GJ1Z
    - Search: "HDMI Dummy Plug 4K Display Emulator"
    - Price: $7-20
  - Ethernet cable: Cat6 or better (any reputable brand)

  **Must NOT do**:
  - Don't buy 8GB RAM model (insufficient for Playwright + ClawdBot)

  **Parallelizable**: NO (must complete before any other task)

  **References**:
  - Apple Mac Mini: https://www.apple.com/mac-mini/
  - HDMI Dummy Plug example: https://www.amazon.com/dp/B06XT1Z9TF

  **Acceptance Criteria**:
  - [ ] Mac Mini received and unboxed
  - [ ] HDMI dummy plug received
  - [ ] Ethernet cable available

  **Commit**: NO

---

### Phase 1: Initial macOS Setup (WITH DISPLAY CONNECTED)

- [ ] 1. Configure macOS on Mac Mini with display attached

  **What to do**:
  1. Connect Mac Mini to monitor, keyboard, mouse
  2. Complete macOS setup wizard
  3. **CRITICAL**: Create user account with username `joshuashin` (matches source paths)
  4. Skip Apple ID sign-in (optional, can add later)
  5. **SKIP FileVault** - Do NOT enable encryption (required for unattended boot - see "FileVault Decision" section above)
  6. Install Homebrew
  7. Install required runtimes:
     - Node.js v25.2.1 (exact version)
     - Bun (latest)
     - Python 3.12+
  8. Verify installations

  **Must NOT do**:
  - Don't create a different username (paths in plists are hardcoded)
  - Don't enable automatic macOS updates
  - **Don't enable FileVault** (conflicts with unattended boot requirement)

  **Parallelizable**: NO (depends on Phase 0)

  **References**:
  - Source machine: Node version `node --version`
  - Source machine: Bun version `bun --version`
  - Homebrew: https://brew.sh

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Using terminal:
    - Command: `whoami`
    - Expected output: `joshuashin`
  - [ ] Using terminal:
    - Command: `node --version`
    - Expected output: `v25.2.1` (or your exact current version)
  - [ ] Using terminal:
    - Command: `bun --version`
    - Expected output: `1.x.x` (current version)
  - [ ] Using terminal:
    - Command: `python3 --version`
    - Expected output: `Python 3.12.x`
  - [ ] Using terminal:
    - Command: `brew --version`
    - Expected output: `Homebrew 4.x.x`

  **Commands to run**:
  ```bash
  # Install Homebrew
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH (Apple Silicon)
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  
  # Install Node.js via Homebrew (for consistent /opt/homebrew/bin/node path)
  # CRITICAL: The ClawdBot LaunchAgent plist hardcodes /opt/homebrew/bin/node
  # We MUST use Homebrew's Node to match the plist path
  brew install node
  
  # Verify Node installation and path
  which node  # MUST be /opt/homebrew/bin/node
  node --version  # Note the version (may differ from source machine)
  
  # If you need exact version pinning AND want to use Homebrew path:
  # Option: Use brew's versioned formula if available
  # brew install node@22  # Example for LTS
  # brew link --overwrite node@22
  
  # CRITICAL: The ClawdBot plist uses /opt/homebrew/bin/node
  # Verify this is the actual binary that will run:
  ls -la /opt/homebrew/bin/node  # Must exist and be executable
  
  # Install Bun
  curl -fsSL https://bun.sh/install | bash
  source ~/.zshrc  # or restart terminal
  bun --version
  
  # Install Python 3.12
  brew install python@3.12
  
  # CRITICAL: Verify python3 points to 3.12, NOT system Python (often 3.9)
  python3 --version  # Must show Python 3.12.x
  
  # If python3 shows older version, use explicit Homebrew path:
  /opt/homebrew/bin/python3.12 --version
  
  # Add alias if needed:
  echo 'alias python3="/opt/homebrew/bin/python3.12"' >> ~/.zshrc
  source ~/.zshrc
  
  # Final verification - ALL must pass
  which node        # MUST be /opt/homebrew/bin/node (matches LaunchAgent plist)
  node --version    # Note version
  bun --version     # 1.x
  python3 --version # Python 3.12.x (NOT 3.9 or older)
  ```
  
  **CRITICAL: Node Binary Path Consistency**
  The ClawdBot LaunchAgent plist (`com.clawdbot.gateway.plist`) has a hardcoded `ProgramArguments[0]` of `/opt/homebrew/bin/node`.
  - **You MUST ensure Node is installed at `/opt/homebrew/bin/node`** (Homebrew's default)
  - **TCC permissions for Node MUST be granted to `/opt/homebrew/bin/node`**
  - If you use a different Node manager (fnm, nvm), you must UPDATE the plist ProgramArguments to match AND grant TCC to that binary instead
  
  **Verification after reboot:**
  ```bash
  # Confirm Node binary location matches plist expectation
  which node  # Must show /opt/homebrew/bin/node
  grep -A1 ProgramArguments ~/Library/LaunchAgents/com.clawdbot.gateway.plist | head -3
  # The path in plist must match `which node`
  ```
  
  **IMPORTANT for later venv creation:**
  When creating Python virtual environments, explicitly use the Homebrew Python:
  ```bash
  /opt/homebrew/bin/python3.12 -m venv venv
  ```

  **Commit**: NO

---

### Phase 2: Headless Configuration

- [ ] 2. Configure Mac Mini for headless operation

  **What to do**:
  1. Disable all sleep modes
  2. Configure auto-login
  3. Enable auto-power-on after power failure
  4. Disable App Nap system-wide
  5. Disable automatic macOS updates
  6. Cancel scheduled power events

  **Must NOT do**:
  - Don't enable any sleep modes
  - Don't leave auto-updates enabled

  **Parallelizable**: NO (depends on Phase 1)

  **References**:
  - Research findings: `pmset` commands for headless Macs
  - Apple docs: Power management settings

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Using terminal:
    - Command: `pmset -g | grep -E "(sleep|displaysleep|disksleep|hibernatemode|disablesleep)"`
    - Expected output contains: `sleep 0`, `displaysleep 0`, `disablesleep 1`
  - [ ] Using terminal:
    - Command: `sudo systemsetup -getcomputersleep`
    - Expected output: `Computer Sleep: Never`
  - [ ] Using terminal:
    - Command: `defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser`
    - Expected output: `joshuashin`
  - [ ] Using terminal:
    - Command: `sudo nvram AutoBoot`
    - Expected output: `AutoBoot %01` (auto power on enabled)

  **Commands to run**:
  ```bash
  # Disable all sleep modes
  sudo pmset -a sleep 0 disksleep 0 displaysleep 0 hibernatemode 0 disablesleep 1
  sudo systemsetup -setcomputersleep Never
  
  # Enable auto-power-on after power failure
  sudo nvram AutoBoot=%01
  
  # Disable App Nap
  defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
  
  # Disable automatic updates
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool NO
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool NO
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool NO
  sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool NO
  
  # Cancel any scheduled power events
  sudo pmset schedule cancelall
  
  # Verify sleep settings
  pmset -g
  ```

  **Auto-Login Configuration (CRITICAL - Must use GUI)**:
  
  The `defaults write` command for auto-login is UNRELIABLE on modern macOS.
  You MUST configure auto-login through the GUI:
  
  1. Open **System Settings** → **Users & Groups**
  2. Click the **Info (i)** button next to your username
  3. Toggle **"Log in automatically"** to ON
  4. Enter your password when prompted
  5. If FileVault is enabled, you'll need to disable it first OR configure the FileVault pre-boot authentication to auto-unlock
  
  **FileVault + Auto-Login Conflict:**
  - FileVault requires password at boot (before auto-login can occur)
  - Options:
    a) Disable FileVault (less secure, but simpler)
    b) Keep FileVault, accept that you'll need password on reboot (can still SSH after)
    c) Use FileVault institutional recovery key (complex enterprise setup)
  
  **Verify Auto-Login is Configured:**
  ```bash
  # This should return your username
  defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser
  
  # If it returns an error, auto-login is NOT configured - use GUI method above
  ```
  
  **Test Auto-Login:**
  ```bash
  # Reboot and verify you land at desktop without password prompt
  sudo reboot
  
  # After reboot, SSH in and verify uptime shows recent boot
  uptime
  ```

  **Commit**: NO

---

### Phase 3: Remote Access and Permissions

- [ ] 3a. Set up Tailscale and SSH for remote access

  **What to do**:
  1. Install Tailscale
  2. **INTERACTIVE APPROVAL REQUIRED**: Approve Tailscale system extension in System Settings
  3. Authenticate with Tailscale account
  4. Enable Tailscale SSH
  5. Disable key expiry in Tailscale admin console
  6. Configure SSH key-based authentication
  7. **INTERACTIVE APPROVAL REQUIRED**: Enable macOS Screen Sharing via GUI

  **Must NOT do**:
  - Don't skip disabling Tailscale key expiry
  - Don't use password-only SSH authentication

  **Parallelizable**: YES (with 3b)
  
  **macOS Interactive Approvals (expect these prompts):**
  - Tailscale: After `brew install tailscale`, you may see "System Extension Blocked" notification
    - Action: Open System Settings → Privacy & Security → scroll to bottom → click "Allow" for Tailscale
    - Verify: `tailscale status` succeeds (not "tailscaled not running")
  - Screen Sharing: Command-line enablement may fail on modern macOS
    - Action: Use GUI: System Settings → General → Sharing → Screen Sharing → toggle ON
    - Verify: `sudo lsof -i :5900 | grep LISTEN` shows screensharing process

  **References**:
  - Tailscale docs: https://tailscale.com/kb/
  - Source machine SSH keys: `~/.ssh/id_ed25519.pub`

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Using terminal:
    - Command: `tailscale status`
    - Expected output contains: Machine name, Tailscale IP (100.x.x.x)
  - [ ] From another Tailscale device:
    - Command: `ssh joshuashin@<tailscale-ip>`
    - Expected: SSH session opens successfully
  - [ ] From another Tailscale device:
    - Command: `tailscale ssh joshuashin@<machine-name>`
    - Expected: Tailscale SSH session opens
  - [ ] Verify in Tailscale admin console:
    - Expected: "Disable key expiry" is enabled for this device
  - [ ] **Screen Sharing verification (CRITICAL for headless recovery):**
    - From another Mac on Tailscale, open Finder → Go → Connect to Server
    - Enter: `vnc://<tailscale-ip>` (e.g., `vnc://100.101.102.103`)
    - Expected: macOS login prompt appears, then desktop view loads after auth
    - Alternative: Use "Screen Sharing" app and connect to Tailscale IP

  **Commands to run**:
  ```bash
  # Install Tailscale
  brew install tailscale
  
  # Start Tailscale with SSH enabled
  sudo tailscale up --ssh
  
  # Follow the authentication URL in browser
  
  # Enable Screen Sharing (Method 1: GUI - RECOMMENDED)
  # Open System Settings → General → Sharing → Screen Sharing → Toggle ON
  # This is more reliable than the command-line method below
  
  # Enable Screen Sharing (Method 2: Command line - may not work on all macOS versions)
  sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false
  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
  
  # Verify Screen Sharing is enabled
  sudo launchctl list | grep screensharing
  # Expected: Shows a PID number (not "-") for com.apple.screensharing
  
  # Alternative verification - check if VNC port 5900 is listening
  sudo lsof -i :5900 | grep LISTEN
  # Expected: Shows "screenshar" process listening
  
  # Configure SSH for key-based auth
  # Copy your public key from source machine to ~/.ssh/authorized_keys
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  # Then paste your public key into authorized_keys
  
  # Record the Tailscale IP
  tailscale ip -4
  ```

  **If Screen Sharing command-line method fails:**
  Screen Sharing enablement varies by macOS version. If the launchctl method doesn't work:
  1. Use GUI: System Settings → General → Sharing → Screen Sharing (toggle ON)
  2. Allow "All users" or specific users
  3. Verify: `sudo lsof -i :5900 | grep LISTEN` should show the screensharing process
  
  **TEST Screen Sharing before going headless:**
  From another Mac on your Tailscale network:
  ```bash
  open vnc://$(tailscale ip -4 | head -1)
  ```
  You should see the Mac Mini's desktop. This is your recovery mechanism if SSH fails.

  **Post-Setup (Tailscale Admin)**:
  1. Go to https://login.tailscale.com/admin/machines
  2. Find the new Mac Mini
  3. Click "..." → "Disable key expiry"

  **Commit**: NO

---

- [ ] 3b. Grant TCC Permissions (Accessibility, Screen Recording, Full Disk Access)

  **What to do**:
  1. Open System Settings → Privacy & Security
  2. Grant permissions to Terminal (and iTerm if used):
     - Accessibility
     - Screen Recording
     - Full Disk Access
  3. Grant permissions to Node.js (for Playwright/ClawdBot browser automation):
     - Accessibility
     - Screen Recording
  4. Grant permissions to Chromium browser (installed by Playwright):
     - Screen Recording
  5. Take screenshots of permission screens for documentation

  **Must NOT do**:
  - Don't skip Screen Recording for Node.js (Playwright runs via Node, not Python)
  - Don't rush - click through each permission carefully

  **Parallelizable**: YES (with 3a)

  **References**:
  - System Settings → Privacy & Security
  - Node.js path: `/opt/homebrew/bin/node`
  - Chromium path: After `npx playwright install chromium`, located at:
    `~/Library/Caches/ms-playwright/chromium-*/chrome-mac/Chromium.app`

  **Exact Binaries Requiring TCC Permissions (Apple Silicon / arm64):**
  
  | Binary | Path (Apple Silicon) | Permissions Needed |
  |--------|---------------------|-------------------|
  | Terminal.app | `/System/Applications/Utilities/Terminal.app` | Accessibility, Screen Recording, Full Disk Access |
  | node | `/opt/homebrew/bin/node` | Accessibility, Screen Recording |
  | Chromium | `~/Library/Caches/ms-playwright/chromium-*/chrome-mac-arm64/Chromium.app` | Screen Recording |

  **IMPORTANT for Chromium:** On Apple Silicon (M1/M2/M3/M4), Playwright installs arm64 Chromium to `chrome-mac-arm64/`, NOT `chrome-mac/`. The exact path varies by version number.

  **How to discover exact Chromium path:**
  ```bash
  # Run AFTER installing Playwright
  find ~/Library/Caches/ms-playwright -name "Chromium.app" 2>/dev/null
  # Example output: /Users/joshuashin/Library/Caches/ms-playwright/chromium-1208/chrome-mac-arm64/Chromium.app
  ```

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Open System Settings → Privacy & Security → Accessibility
    - Expected: Terminal.app shows checkmark
    - Expected: `/opt/homebrew/bin/node` shows checkmark
  - [ ] Open System Settings → Privacy & Security → Screen Recording
    - Expected: Terminal.app shows checkmark
    - Expected: `/opt/homebrew/bin/node` shows checkmark
    - Expected: Chromium.app shows checkmark (after Playwright install)
  - [ ] Open System Settings → Privacy & Security → Full Disk Access
    - Expected: Terminal.app shows checkmark
  - [ ] Screenshot saved to `~/.sisyphus/evidence/tcc-permissions.png`

  **Steps**:
  1. System Settings → Privacy & Security → Accessibility
     - Click "+" → Navigate to `/System/Applications/Utilities/Terminal.app` (Cmd+Shift+G to type path)
     - Click "+" → Navigate to `/opt/homebrew/bin/node`
  
  2. System Settings → Privacy & Security → Screen Recording
     - Click "+" → Add Terminal.app (same path as above)
     - Click "+" → Add node (same path as above)
     - Click "+" → Add Chromium.app (run `find ~/Library/Caches/ms-playwright -name "Chromium.app"` to get exact path AFTER Playwright install)
  
  3. System Settings → Privacy & Security → Full Disk Access
     - Click "+" → Add Terminal.app

  4. Take screenshot:
     ```bash
     mkdir -p ~/.sisyphus/evidence
     screencapture ~/.sisyphus/evidence/tcc-permissions.png
     ```

  **Note**: The Chromium path includes version number (e.g., `chromium-1208`). This changes with Playwright updates. Always discover the path dynamically after `npx playwright install chromium`.

  **Commit**: NO

---

- [ ] 3c. Install and Configure Parsec for Low-Latency Remote Desktop

  **What to do**:
  1. Create Parsec account at https://parsec.app (if you don't have one)
  2. Install Parsec on Mac Mini (host)
  3. Install Parsec on your main Mac (client)
  4. Grant Screen Recording permission to Parsec on Mac Mini
  5. Configure Parsec to run at login on Mac Mini
  6. Test connection quality over Tailscale
  7. Configure display resolution for HDMI dummy plug

  **Why Parsec over VNC:**
  - Uses hardware-accelerated H.265 encoding (like game streaming)
  - Sub-20ms input latency vs 100-200ms for VNC
  - Feels like the window is local, not remote
  - Works great over Tailscale's encrypted tunnel

  **Must NOT do**:
  - Don't skip Screen Recording permission (Parsec won't capture screen without it)
  - Don't use Parsec without Tailscale (adds unnecessary exposure)

  **Parallelizable**: YES (with 3a, 3b)

  **References**:
  - Parsec download: https://parsec.app/downloads
  - Parsec docs: https://support.parsec.app/hc/en-us

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Parsec installed on Mac Mini:
    - Command: `ls /Applications/Parsec.app`
    - Expected: Application exists
  - [ ] Parsec has Screen Recording permission:
    - System Settings → Privacy & Security → Screen Recording
    - Expected: Parsec.app shows checkmark
  - [ ] Parsec configured to run at login:
    - System Settings → General → Login Items
    - Expected: Parsec listed
  - [ ] From main Mac, connect to Mac Mini via Parsec:
    - Open Parsec → Select Mac Mini → Connect
    - Expected: Desktop appears with minimal lag (< 20ms)
  - [ ] Test input responsiveness:
    - Move mouse, type text
    - Expected: Feels immediate, no perceptible delay

  **Commands to run on Mac Mini**:
  ```bash
  # Download and install Parsec (or use browser: https://parsec.app/downloads)
  # After installation, open Parsec and log in to your account

  # Verify installation
  ls /Applications/Parsec.app

  # Grant Screen Recording permission:
  # System Settings → Privacy & Security → Screen Recording → Add Parsec.app

  # Configure run at login:
  # System Settings → General → Login Items → Add Parsec
  # OR via Parsec app settings → "Run when my computer starts"

  # Configure HDMI dummy plug resolution (optional, for better quality)
  # In Parsec host settings, set resolution to match your preferred working resolution
  # Common choices: 1920x1080 (1080p) or 2560x1440 (1440p)
  ```

  **Commands to run on your main Mac**:
  ```bash
  # Install Parsec client
  # Download from https://parsec.app/downloads or:
  brew install --cask parsec

  # Open Parsec and log in with the same account
  # The Mac Mini should appear in your computer list

  # Connect and verify responsiveness
  ```

  **Commit**: NO

---

### Phase 4: Service Migration

- [ ] 4a. Migrate LLM API Key Proxy

  **What to do**:
  1. Transfer proxy directory (EXCLUDE venv/, recreate on target)
  2. Transfer critical files explicitly: `.env`, `key_usage.json`, `launcher_config.json`, `oauth_creds/`
  3. Copy LaunchAgent plist
  4. Validate plist
  5. Recreate Python virtual environment on target
  6. Install dependencies
  7. Set shell environment variable (LLM_PROXY_API_KEY = PROXY_API_KEY value)
  8. Load and start service
  9. Verify with authenticated curl

  **Must NOT do**:
  - Don't transfer venv/ (paths are machine-specific, recreate instead)
  - Don't transfer .env via unencrypted channel (use scp or rsync over SSH/Tailscale)
  - Don't modify proxy to bind to 0.0.0.0
  - Don't skip key_usage.json (preserves rate limit state)

  **Parallelizable**: NO (depends on Phase 3)

  **References** (exact files to migrate):
  - `/Users/joshuashin/Projects/LLM-API-Key-Proxy/.env` — **SECRET**: All provider API keys
  - `/Users/joshuashin/Projects/LLM-API-Key-Proxy/key_usage.json` — Rate limit state
  - `/Users/joshuashin/Projects/LLM-API-Key-Proxy/launcher_config.json` — Launch settings
  - `/Users/joshuashin/Projects/LLM-API-Key-Proxy/oauth_creds/` — OAuth tokens (may be empty)
  - `/Users/joshuashin/Projects/LLM-API-Key-Proxy/src/` — Application source
  - `/Users/joshuashin/Projects/LLM-API-Key-Proxy/requirements.txt` — Dependencies
  - `/Users/joshuashin/Library/LaunchAgents/com.llm-api-key-proxy.plist` — Daemon config

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Using terminal:
    - Command: `launchctl list | grep llm-api-key-proxy`
    - Expected output contains: PID number and `com.llm-api-key-proxy`
  - [ ] Using terminal (retrieve key at runtime, NEVER hardcode):
    - Command: `PROXY_KEY=$(grep '^PROXY_API_KEY=' ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2) && curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/`
    - Expected output: Server response (not connection refused or 401)
  - [ ] Using terminal (retrieve key at runtime):
    - Command: `PROXY_KEY=$(grep '^PROXY_API_KEY=' ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2) && curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models`
    - Expected output: JSON with model list
  - [ ] Using terminal:
    - Command: `tail -20 ~/Library/Logs/llm-api-key-proxy.log`
    - Expected: Recent log entries showing "Proxy API Key: ✓ <your-key>" (the actual key value from .env)
  - [ ] Verify key_usage.json transferred:
    - Command: `cat ~/Projects/LLM-API-Key-Proxy/key_usage.json`
    - Expected: JSON with usage tracking data (or {} if fresh)

  **Commands to run on SOURCE machine**:
  ```bash
  # From source machine, rsync to new Mac Mini
  # EXCLUDE venv/ - will recreate on target
  rsync -avz --progress --exclude='venv/' ~/Projects/LLM-API-Key-Proxy/ joshuashin@<tailscale-ip>:~/Projects/LLM-API-Key-Proxy/
  
  # Copy LaunchAgent plist
  scp ~/Library/LaunchAgents/com.llm-api-key-proxy.plist joshuashin@<tailscale-ip>:~/Library/LaunchAgents/
  ```

  **Commands to run on NEW Mac Mini**:
  ```bash
  # Verify critical files transferred
  ls -la ~/Projects/LLM-API-Key-Proxy/.env
  ls -la ~/Projects/LLM-API-Key-Proxy/key_usage.json
  ls -la ~/Projects/LLM-API-Key-Proxy/launcher_config.json
  
  # CRITICAL: Recreate Python venv at EXACT same path as in plist
  # The LaunchAgent plist references: ~/Projects/LLM-API-Key-Proxy/venv/bin/python
  cd ~/Projects/LLM-API-Key-Proxy
  
  # IMPORTANT: Use explicit Homebrew Python 3.12 path to avoid system Python
  # Verify correct Python version first:
  /opt/homebrew/bin/python3.12 --version  # Must show Python 3.12.x
  
  # Create venv with explicit Python path
  /opt/homebrew/bin/python3.12 -m venv venv
  source venv/bin/activate
  
  # Verify venv Python is correct
  python --version  # Should show Python 3.12.x
  
  pip install -r requirements.txt
  
  # Verify venv path matches what plist expects
  grep -A2 ProgramArguments ~/Library/LaunchAgents/com.llm-api-key-proxy.plist
  # Confirm the python path in plist matches: /Users/joshuashin/Projects/LLM-API-Key-Proxy/venv/bin/python
  
  # Validate plist syntax
  plutil -lint ~/Library/LaunchAgents/com.llm-api-key-proxy.plist
  
  # IMPORTANT: Shell profiles (~/.zshrc) are NOT read by LaunchAgents!
  # For interactive SSH sessions, add to shell profile:
  echo 'export LLM_PROXY_API_KEY="$(grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)"' >> ~/.zshrc
  source ~/.zshrc
  
  # The LaunchAgent itself gets env vars from the plist (already configured) or from the proxy's .env file
  
  # Load LaunchAgent (try legacy method first)
  launchctl load ~/Library/LaunchAgents/com.llm-api-key-proxy.plist
  
  # Wait 5 seconds for startup
  sleep 5
  
  # Get the actual proxy API key from .env for verification
  PROXY_KEY=$(grep '^PROXY_API_KEY=' ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)
  
  # Verify basic connectivity (retrieve key from source, don't hardcode)
  curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models
  
  # If you see "Unauthorized", check that PROXY_API_KEY in .env is correctly set
  ```
  
  **If `launchctl load` fails (modern macOS fallback):**
  ```bash
  # Get your user ID (usually 501 for first user)
  id -u  # e.g., 501
  
  # Use bootstrap instead of load (modern macOS)
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.llm-api-key-proxy.plist
  
  # To stop/restart, use bootout instead of unload:
  launchctl bootout gui/$(id -u)/com.llm-api-key-proxy
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.llm-api-key-proxy.plist
  
  # Verify service domain and state
  launchctl print gui/$(id -u)/com.llm-api-key-proxy
  ```
  
  **Real Request Verification (proves proxy actually works):**
  ```bash
  PROXY_KEY=$(grep '^PROXY_API_KEY=' ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)
  
  # Make a real API request to verify end-to-end functionality
  # This tests that the proxy can reach an actual LLM provider
  curl -X POST http://127.0.0.1:8000/v1/chat/completions \
    -H "Authorization: Bearer $PROXY_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Say hello"}], "max_tokens": 10}'
  
  # Expected: HTTP 200 with JSON response containing "choices"
  # If 401: PROXY_API_KEY mismatch
  # If connection error: service not running (check logs)
  # If provider error: check ~/Library/Logs/llm-api-key-proxy.log for details
  ```
  
  **OAuth Providers Note:**
  The `oauth_creds/` directory is migrated but may be empty. OAuth-backed providers (if configured) may require re-authentication on the new machine. For Definition of Done: **API-key-based providers must work; OAuth providers are optional unless specifically required by your workflows.**
  
  **NOTE on LaunchAgent Environment Variables:**
  LaunchAgents do NOT inherit shell profile variables (`~/.zshrc`, `~/.bash_profile`). 
  If the LaunchAgent needs env vars, they must be:
  1. Set in the plist under `<key>EnvironmentVariables</key>`, OR
  2. Loaded from a file at runtime by the application (LLM Proxy reads from `.env`)

  **Commit**: NO

---

- [ ] 4b. Migrate ClawdBot Gateway

  **What to do**:
  1. Install ClawdBot globally (pinned version)
  2. Use rsync to transfer config directories
  3. Copy LaunchAgent plist
  4. Validate plist
  5. **IMPORTANT**: Stop ClawdBot on OLD machine first (Telegram bot conflict)
  6. Verify LLM Proxy is running (ClawdBot depends on it)
  7. Load and start service on new machine
  8. Verify Telegram connectivity

  **Must NOT do**:
  - Don't run both old and new ClawdBot with same Telegram token simultaneously
  - Don't use `npm install -g clawdbot` without version pin
  - Don't start ClawdBot before verifying LLM Proxy is healthy

  **Parallelizable**: NO (depends on 4a - LLM Proxy must be running first)

  **References** (exact files to migrate):
  - `/Users/joshuashin/.clawdbot/clawdbot.json` — **SECRET**: Main config with Telegram bot token
  - `/Users/joshuashin/.clawdbot/credentials/` — **SECRET**: Channel credentials
  - `/Users/joshuashin/.clawdbot/agents/main/sessions/` — Session state
  - `/Users/joshuashin/.clawdbot/agents/main/agent/auth-profiles.json` — **SECRET**: AI provider auth
  - `/Users/joshuashin/clawd/` — Agent workspace
  - `/Users/joshuashin/.config/opencode/opencode.json` — OpenCode IDE config
  - `/Users/joshuashin/Library/LaunchAgents/com.clawdbot.gateway.plist` — Daemon config
  - ClawdBot version: `2026.1.16-2`

  **Gateway Token Location (retrieve at runtime, NEVER embed in docs):**
  The gateway auth token for health checks is in:
  - LaunchAgent plist: `CLAWDBOT_GATEWAY_TOKEN` env var
  - Config file: `~/.clawdbot/clawdbot.json` → `gateway.auth.token`
  
  **To retrieve token for verification:**
  ```bash
  jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json
  ```

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Using terminal:
    - Command: `launchctl list | grep clawdbot`
    - Expected output contains: PID number and `com.clawdbot.gateway`
  - [ ] Using terminal (retrieve token at runtime, NEVER hardcode):
    - Command: `GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json) && curl -H "Authorization: Bearer $GATEWAY_TOKEN" http://127.0.0.1:18789/health`
    - Expected output: Health check response (200 OK)
  - [ ] Using Telegram:
    - Send `/ping` to your bot from @chugget
    - Expected: Bot responds
  - [ ] Using terminal:
    - Command: `tail -20 ~/.clawdbot/logs/gateway.log`
    - Expected: Recent log entries, "Telegram connected" message
  - [ ] Verify sessions transferred:
    - Command: `ls ~/.clawdbot/agents/main/sessions/`
    - Expected: Session files present

  **Commands to run on SOURCE machine**:
  ```bash
  # FIRST: Stop ClawdBot on old machine to free Telegram token
  # Try legacy unload first (works on older macOS)
  launchctl unload ~/Library/LaunchAgents/com.clawdbot.gateway.plist
  
  # If unload fails with "Could not find specified service", use modern bootout:
  launchctl bootout gui/$(id -u)/com.clawdbot.gateway 2>/dev/null || true
  
  # Verify it's stopped
  launchctl list | grep clawdbot  # Should return nothing
  
  # Transfer config directories
  rsync -avz --progress ~/.clawdbot/ joshuashin@<tailscale-ip>:~/.clawdbot/
  rsync -avz --progress ~/clawd/ joshuashin@<tailscale-ip>:~/clawd/
  
  # Transfer OpenCode config (ensure directory exists first)
  ssh joshuashin@<tailscale-ip> "mkdir -p ~/.config/opencode"
  rsync -avz --progress ~/.config/opencode/ joshuashin@<tailscale-ip>:~/.config/opencode/
  
  # Copy LaunchAgent plist
  scp ~/Library/LaunchAgents/com.clawdbot.gateway.plist joshuashin@<tailscale-ip>:~/Library/LaunchAgents/
  ```

  **Commands to run on NEW Mac Mini**:
  ```bash
  # Install ClawdBot (pinned version)
  bun add -g clawdbot@2026.1.16-2
  
  # Verify installation
  clawdbot --version  # Should show 2026.1.16-2
  
  # CRITICAL: Verify plist ProgramArguments match actual bun global install path
  # The plist references a specific path to clawdbot entry.js
  grep -A5 ProgramArguments ~/Library/LaunchAgents/com.clawdbot.gateway.plist
  
  # Find where bun actually installed clawdbot
  bun pm ls -g | grep clawdbot
  ls ~/.bun/install/global/node_modules/clawdbot/dist/entry.js
  
  # If paths don't match, UPDATE THE PLIST before loading:
  # Edit ~/Library/LaunchAgents/com.clawdbot.gateway.plist to match actual path
  
  # Validate plist syntax
  plutil -lint ~/Library/LaunchAgents/com.clawdbot.gateway.plist
  
  # CRITICAL: Verify LLM Proxy is running first
  PROXY_KEY=$(grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)
  curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models
  # Must succeed before continuing
  
  # Load ClawdBot LaunchAgent (try legacy method first)
  launchctl load ~/Library/LaunchAgents/com.clawdbot.gateway.plist
  
  # Wait 10 seconds for startup
  sleep 10
  
  # Verify service is running
  launchctl list | grep clawdbot
  
  # Get gateway token from config (DON'T hardcode tokens in commands)
  GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json)
  
  # Check health endpoint
  curl -H "Authorization: Bearer $GATEWAY_TOKEN" http://127.0.0.1:18789/health
  
  # Verify bind address is loopback (security check)
  jq '.gateway.bind' ~/.clawdbot/clawdbot.json  # Should show "loopback"
  
  # Check logs for successful Telegram connection
  tail -20 ~/.clawdbot/logs/gateway.log | grep -i telegram
  ```
  
  **If `launchctl load` fails (modern macOS fallback):**
  ```bash
  # Get your user ID (usually 501 for first user)
  id -u  # e.g., 501
  
  # Use bootstrap instead of load (modern macOS)
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.clawdbot.gateway.plist
  
  # To stop/restart, use bootout instead of unload:
  launchctl bootout gui/$(id -u)/com.clawdbot.gateway
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.clawdbot.gateway.plist
  
  # Verify service domain and state
  launchctl print gui/$(id -u)/com.clawdbot.gateway
  ```
  
  **NOTE on LaunchAgent Path Verification:**
  The ClawdBot plist contains hardcoded paths to:
  - `/opt/homebrew/bin/node` (Node.js)
  - `~/.bun/install/global/node_modules/clawdbot/dist/entry.js` (ClawdBot entry)
  
  If bun installs to a different location on the new machine, UPDATE THE PLIST before loading.

  **Service Startup Ordering on Unattended Boot:**
  
  Both LaunchAgents have `RunAtLoad=true`, but ClawdBot depends on LLM Proxy being available.
  
  **Expected behavior on reboot:**
  - Both services start simultaneously (no launchd-level dependency)
  - ClawdBot may fail initial LLM Proxy connection attempts
  - ClawdBot should retry and recover once LLM Proxy is ready (within ~30 seconds)
  
  **Verification after reboot (test this during Phase 5a):**
  ```bash
  # After reboot, check both services started
  launchctl list | grep -E "(clawdbot|llm-api-key-proxy)"
  # Both should show PID numbers
  
  # Check ClawdBot logs for recovery pattern
  grep -i "retry\|reconnect\|proxy" ~/.clawdbot/logs/gateway.log | tail -10
  
  # Verify ClawdBot is healthy (may take 30-60 seconds after boot)
  GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json)
  curl -H "Authorization: Bearer $GATEWAY_TOKEN" http://127.0.0.1:18789/health
  ```
  
  **If ClawdBot doesn't recover automatically:**
  - This indicates ClawdBot doesn't have built-in retry logic for LLM Proxy
  - Manual recovery: `launchctl kickstart -k gui/$(id -u)/com.clawdbot.gateway`
  - Consider adding a delayed-start wrapper or launchd ThrottleInterval if this is a persistent issue

  **Commit**: NO

---

### Phase 5: Headless Verification

- [ ] 5a. Test services with HDMI dummy plug (no monitor)

  **What to do**:
  1. Disconnect physical monitor
  2. Connect HDMI dummy plug
  3. Reboot Mac Mini
  4. Connect via Tailscale SSH
  5. Verify all services auto-started
  6. Run Playwright screenshot test
  7. Verify Telegram bot responds

  **Must NOT do**:
  - Don't skip the dummy plug - GPU driver issues will occur
  - Don't reconnect monitor if something fails (fix via SSH)

  **Parallelizable**: NO (depends on Phase 4)

  **References**:
  - Tailscale IP from Phase 3a
  - Service status commands from Phase 4

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] After reboot, via SSH:
    - Command: `launchctl list | grep -E "(clawdbot|llm-api-key-proxy)"`
    - Expected: Both services show PID (running)
  - [ ] Via SSH (retrieve key from source, don't hardcode):
    - Command: `PROXY_KEY=$(grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2) && curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models`
    - Expected: Model list JSON (NOT 401 Unauthorized)
  - [ ] Via SSH (retrieve gateway token from source):
    - Command: `GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json) && curl -H "Authorization: Bearer $GATEWAY_TOKEN" http://127.0.0.1:18789/health`
    - Expected: Health check success (200 OK)
  - [ ] Via Telegram:
    - Send message to bot from @chugget
    - Expected: Bot responds correctly
  - [ ] Via SSH, Playwright test:
    - Command: `node ~/playwright-test/screenshot.js`
    - Expected: "Screenshot captured successfully!" + screenshot.png exists

  **Commands**:
  ```bash
  # From another machine, after Mac Mini reboots
  ssh joshuashin@<tailscale-ip>
  
  # Verify services
  launchctl list | grep -E "(clawdbot|llm-api-key-proxy)"
  
  # Test LLM Proxy (retrieve key from .env, never hardcode)
  PROXY_KEY=$(grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)
  curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models
  
  # Test ClawdBot health (retrieve token from config, never hardcode)
  GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json)
  curl -H "Authorization: Bearer $GATEWAY_TOKEN" http://127.0.0.1:18789/health
  
  # Check logs
  tail -20 ~/.clawdbot/logs/gateway.log
  
  # Test Playwright (create a simple test if needed)
  cd ~
  mkdir -p playwright-test && cd playwright-test
  npm init -y
  npm install playwright
  npx playwright install chromium
  
  # IMPORTANT: After installing Chromium, add it to Screen Recording permission!
  # Find the actual path (ARM64 Macs use chrome-mac-arm64):
  find ~/Library/Caches/ms-playwright -name "Chromium.app" 2>/dev/null
  # Add that exact path to System Settings → Privacy & Security → Screen Recording
  
  # Create simple screenshot test
  cat > screenshot.js << 'EOF'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('https://example.com');
  await page.screenshot({ path: 'screenshot.png' });
  await browser.close();
  console.log('Screenshot captured successfully!');
})();
EOF
  
  node screenshot.js
  
  # Verify screenshot was created
  ls -la screenshot.png
  ```

  **Commit**: NO

---

- [ ] 5b. 24-hour soak test

  **What to do**:
  1. Leave Mac Mini running headless for 24+ hours
  2. Check service status periodically
  3. Monitor memory usage
  4. Verify logs for errors
  5. Test Telegram responsiveness at different times

  **Must NOT do**:
  - Don't decommission old machine yet
  - Don't consider migration complete until soak test passes

  **Parallelizable**: NO (depends on 5a)

  **References**:
  - Log locations: `~/.clawdbot/logs/`, `~/Library/Logs/llm-api-key-proxy.log`

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] At T+24h via SSH:
    - Command: `uptime`
    - Expected: 24+ hours uptime
  - [ ] At T+24h via SSH:
    - Command: `launchctl list | grep -E "(clawdbot|llm-api-key-proxy)"`
    - Expected: Both services show PID (still running, no "-" in PID column)
  - [ ] At T+24h via SSH (objective memory check):
    - Command: `sysctl vm.swapusage`
    - Expected: swap used < 1GB (ideally 0)
    - Command: `memory_pressure`
    - Expected: "System-wide memory status: OK" (NOT "WARN" or "CRITICAL")
  - [ ] At T+24h via SSH:
    - Command: `grep -i error ~/.clawdbot/logs/gateway.log | tail -20`
    - Expected: No critical/fatal errors (warnings are acceptable)
  - [ ] At T+24h via SSH:
    - Command: `launchctl print gui/$(id -u)/com.clawdbot.gateway | grep -E "(runs|last exit)"`
    - Expected: No unexpected restarts (runs count should be 1 or low)
  - [ ] At T+24h via Telegram:
    - Send message to bot from @chugget
    - Expected: Bot responds correctly

  **Monitoring Schedule**:
  - T+1h: Quick check (services running, basic health endpoints respond)
  - T+4h: Check logs for errors, check memory_pressure
  - T+12h: Check swap usage, verify no service restarts
  - T+24h: Full verification (all criteria above)

  **After 24-hour soak test passes:**
  Continue monitoring for 7 days before decommissioning old machine (see Phase 7).

  **Commit**: NO

---

- [ ] 5c. Install Superset for Parallel Agent Orchestration

  **What to do**:
  1. Install Superset desktop app on Mac Mini
  2. Install Claude Code CLI on Mac Mini
  3. Configure Superset with a test project
  4. Verify agent spawning and git worktree creation
  5. Test parallel agent execution

  **Why Superset:**
  - Orchestrates multiple Claude Code (or OpenCode) agents in parallel
  - Each agent runs in an isolated git worktree (no merge conflicts)
  - Notifications when agents finish or need input
  - Agent-agnostic — works with any CLI coding tool

  **Must NOT do**:
  - Don't run Superset before verifying core services work
  - Don't run agents without git worktree isolation

  **Parallelizable**: NO (depends on 5b - run after soak test passes)

  **References**:
  - Superset: https://superset.sh
  - GitHub: https://github.com/superset-sh/superset
  - Claude Code: Already installed via ClawdBot ecosystem

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [ ] Superset installed:
    - Command: `ls /Applications/Superset.app` or check via Finder
    - Expected: Application exists
  - [ ] Claude Code CLI available:
    - Command: `which claude` or `claude --version`
    - Expected: Claude CLI found and version displayed
  - [ ] Open Superset and create a test workspace:
    - Open Superset → Create new workspace from a git repo
    - Expected: Workspace created successfully
  - [ ] Spawn a test agent:
    - In Superset, start a new agent with a simple task
    - Expected: Agent spawns in isolated worktree, begins working
  - [ ] Verify git worktree isolation:
    - Command: `git worktree list` (in the project directory)
    - Expected: Shows main worktree + Superset-created worktrees
  - [ ] Access via Parsec from main Mac:
    - Connect via Parsec → Open Superset → Manage agents
    - Expected: Responsive UI, can monitor and interact with agents

  **Commands to run on Mac Mini**:
  ```bash
  # Install Superset (download from website or use brew if available)
  # Visit https://superset.sh and download the macOS app
  # Drag to /Applications/

  # Verify Claude Code is available (should be from ClawdBot setup)
  which claude || echo "Claude CLI not found - install separately"
  claude --version

  # If Claude Code not installed, install it:
  # npm install -g @anthropic-ai/claude-code
  # OR
  # bun add -g @anthropic-ai/claude-code

  # Launch Superset
  open /Applications/Superset.app

  # First launch:
  # 1. Complete onboarding
  # 2. Point to a git repository to use as a workspace
  # 3. Configure your preferred agent (Claude Code)

  # Test worktree creation
  cd ~/your-project
  git worktree list  # Should show any Superset-created worktrees
  ```

  **Configuration Tips**:
  - In Superset settings, configure the agent command (e.g., `claude` for Claude Code)
  - Set up `.superset/config.json` in your project for environment setup/teardown
  - Consider setting up project-specific environment variables in Superset

  **Commit**: NO

---

### Phase 6: Agent Workflow Setup (Optional Enhancement)

- [ ] 6. Configure Optimal Agent Workflow

  **What to do**:
  1. Set up shared git repository accessible from both Macs
  2. Configure Superset workspace for your main project(s)
  3. Establish workflow: create tasks on main Mac → agents execute on Mac Mini → review/merge
  4. Document your personal agent orchestration workflow

  **Workflow Pattern**:
  ```
  ┌─────────────────┐                           ┌─────────────────┐
  │   Your Mac      │                           │   Mac Mini      │
  │   (Planning)    │                           │   (Execution)   │
  │                 │      Parsec / SSH         │                 │
  │  • Plan tasks   │ ─────────────────────────▶│  • Superset     │
  │  • Write specs  │                           │  • Claude Code  │
  │  • Review PRs   │◀───── git push ──────────│  • Git worktrees│
  └─────────────────┘                           └─────────────────┘
  ```

  **Parallelizable**: YES (can be done alongside extended monitoring)

  **Acceptance Criteria**:
  - [ ] Can create agent tasks from main Mac via Parsec
  - [ ] Agents complete work and push to shared repo
  - [ ] Can review agent work via git diff/PR on main Mac
  - [ ] Workflow documented for future reference

  **Commit**: NO

---

### Phase 7: Cleanup and Decommission

- [ ] 7. Document and decommission old machine

  **What to do**:
  1. Document all steps taken for future reference
  2. After 7-day successful operation, decommission old services
  3. Keep old machine data as backup for 30 days
  4. Update any DNS/references to point to new machine's Tailscale hostname

  **Must NOT do**:
  - Don't delete old data immediately
  - Don't rush decommissioning

  **Parallelizable**: NO (depends on 5b)

  **References**:
  - This plan document
  - Evidence screenshots

  **Acceptance Criteria**:

  **Manual Verification:**
  - [ ] New Mac Mini has been running successfully for 7+ days
  - [ ] Old machine services stopped (verify with `launchctl list | grep -E "(clawdbot|llm-api)"`)
  - [ ] Old machine data backed up (optional)
  - [ ] Documentation saved

  **Commands on OLD machine (after 7 days)**:
  ```bash
  # Stop services on old machine
  # Try legacy unload first
  launchctl unload ~/Library/LaunchAgents/com.clawdbot.gateway.plist 2>/dev/null
  launchctl unload ~/Library/LaunchAgents/com.llm-api-key-proxy.plist 2>/dev/null
  
  # If unload fails (modern macOS), use bootout
  launchctl bootout gui/$(id -u)/com.clawdbot.gateway 2>/dev/null || true
  launchctl bootout gui/$(id -u)/com.llm-api-key-proxy 2>/dev/null || true
  
  # Verify services are stopped
  launchctl list | grep -E "(clawdbot|llm-api)"  # Should return nothing
  
  # Optional: Create backup archive
  tar -czvf clawdbot-backup-$(date +%Y%m%d).tar.gz ~/.clawdbot ~/clawd ~/Projects/LLM-API-Key-Proxy
  ```

  **Commit**: NO

---

## Commit Strategy

This is an infrastructure migration - no git commits required. All changes are system configuration.

| After Task | Action | Notes |
|------------|--------|-------|
| All phases | N/A | Infrastructure changes, not code |

---

## Success Criteria

### Verification Commands (from Tailscale-connected device)
```bash
# SSH to Mac Mini
ssh joshuashin@<tailscale-ip-or-hostname>

# Check services running
launchctl list | grep -E "(clawdbot|llm-api-key-proxy)"
# Expected: Both show PID numbers

# Test LLM Proxy (retrieve key from source, NEVER hardcode tokens)
PROXY_KEY=$(grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env | cut -d= -f2)
curl -H "Authorization: Bearer $PROXY_KEY" http://127.0.0.1:8000/v1/models
# Expected: JSON model list (NOT 401 Unauthorized)

# Test ClawdBot health (retrieve token from source, NEVER hardcode)
GATEWAY_TOKEN=$(jq -r '.gateway.auth.token' ~/.clawdbot/clawdbot.json)
curl -H "Authorization: Bearer $GATEWAY_TOKEN" http://127.0.0.1:18789/health
# Expected: Health check success (200 OK)

# Test ClawdBot logs
tail -5 ~/.clawdbot/logs/gateway.log
# Expected: Recent activity, "Telegram connected", no errors

# Test Playwright (headless)
node ~/playwright-test/screenshot.js
# Expected: "Screenshot captured successfully!"

# Verify nothing is listening on 0.0.0.0 for LLM Proxy/ClawdBot
sudo lsof -i :8000 | grep -v 127.0.0.1  # Should return nothing
sudo lsof -i :18789 | grep -v 127.0.0.1  # Should return nothing

# Check memory health (objective criteria)
sysctl vm.swapusage  # swap used should be < 1GB
memory_pressure      # should show "OK"
```

### Final Checklist
- [ ] All "Must Have" present:
  - [ ] Username is `joshuashin` (verify: `whoami`)
  - [ ] HDMI dummy plug connected
  - [ ] Tailscale key expiry disabled (verify in admin console)
  - [ ] Auto-login configured (verify: `defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser`)
  - [ ] All sleep modes disabled (verify: `pmset -g`)
  - [ ] Screen Recording permission granted to Terminal (`/System/Applications/Utilities/Terminal.app`), Node.js (`/opt/homebrew/bin/node`), AND Chromium (discovered via `find ~/Library/Caches/ms-playwright -name "Chromium.app"`)
- [ ] All "Must NOT Have" absent:
  - [ ] No macOS auto-updates enabled
  - [ ] No binding to 0.0.0.0 (verify: `sudo lsof -i :8000` and `:18789` show only 127.0.0.1)
  - [ ] Old machine stopped (Telegram token released)
- [ ] API key verified (retrieve from source, don't hardcode):
  - [ ] `grep PROXY_API_KEY ~/Projects/LLM-API-Key-Proxy/.env` shows the key
  - [ ] Authenticated curl to LLM Proxy succeeds
- [ ] LaunchAgent paths verified:
  - [ ] LLM Proxy plist points to existing venv/bin/python
  - [ ] ClawdBot plist points to existing bun global install
- [ ] 24-hour soak test passed:
  - [ ] swap used < 1GB
  - [ ] memory_pressure shows "OK"
  - [ ] no unexpected service restarts
- [ ] 7-day extended operation before decommissioning old machine
- [ ] Telegram bot responds correctly
- [ ] Playwright screenshot test works headless
