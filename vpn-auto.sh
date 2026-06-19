#!/usr/bin/env bash
# /usr/local/bin/vpn-auto.sh
# ProtonVPN Auto-selection and Connection Script
# Tailored for security, compliance, and custom state filtering.

set -euo pipefail

# Configuration
EXCLUDED_STATES="TX|FL|UT|LA"
FAVORED_STATES="WA|IL|NY|MA|CO"
LOG_FILE="/var/log/protonvpn-auto.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Parse command line options (e.g., --kill-switch=hard)
KILL_SWITCH_MODE="permanent"
for arg in "$@"; do
    case "$arg" in
        --kill-switch=hard)
            KILL_SWITCH_MODE="permanent"
            ;;
        --kill-switch=standard)
            KILL_SWITCH_MODE="standard"
            ;;
    esac
done

log "Starting ProtonVPN auto-connect script..."

# 1. Enforce the Kill Switch
if command -v protonvpn &>/dev/null; then
    log "Enforcing kill switch mode: $KILL_SWITCH_MODE via protonvpn"
    protonvpn config set kill-switch "$KILL_SWITCH_MODE" || true
elif command -v protonvpn-cli &>/dev/null; then
    log "Enforcing kill switch mode: $KILL_SWITCH_MODE via protonvpn-cli"
    # Older CLI / community versions
    if [ "$KILL_SWITCH_MODE" = "permanent" ]; then
        protonvpn-cli killswitch --on || true
    fi
fi

# 2. Get list of available servers
log "Fetching available server list..."
SERVERS=""
if command -v protonvpn-cli &>/dev/null; then
    # Parse server list from protonvpn-cli
    SERVERS=$(protonvpn-cli servers 2>/dev/null || true)
fi

if [ -z "$SERVERS" ] && command -v protonvpn &>/dev/null; then
    # Try alternative output format or commands if using v4 CLI
    SERVERS=$(protonvpn status --help &>/dev/null && protonvpn status || true)
fi

# Fallback: If no server list can be fetched or parsed, we'll use a pre-defined list of US states.
# This ensures the script is robust even if the API changes or CLI is not initialized yet.
US_SERVERS=""
if [ -n "$SERVERS" ]; then
    # Extract US servers matching format US-XX#YY (e.g. US-WA#10)
    US_SERVERS=$(echo "$SERVERS" | grep -o -E 'US-[A-Z]{2}#[0-9]+' | sort -u || true)
fi

# 3. Filter and categorize servers
FILTERED_SERVERS=()
FAVORED_SERVERS=()

if [ -n "$US_SERVERS" ]; then
    # Optimization: Use native bash parameter expansion and regex to extract state
    # and filter servers instead of spawning 'cut' and 'grep' subshells in the loop.
    # This avoids thousands of subshell forks and speeds up processing significantly.
    for server in $US_SERVERS; do
        # Extract state code (e.g., US-WA#10 -> WA)
        state="${server#US-}"
        state="${state%%#*}"
        
        # Check against exclusions
        if [[ "$state" =~ ^($EXCLUDED_STATES)$ ]]; then
            continue
        fi
        
        FILTERED_SERVERS+=("$server")
        
        # Check against favorites
        if [[ "$state" =~ ^($FAVORED_STATES)$ ]]; then
            FAVORED_SERVERS+=("$server")
        fi
    done
fi

# 4. Choose a server
SELECTED_SERVER=""
if [ ${#FAVORED_SERVERS[@]} -gt 0 ]; then
    # Select random favored server
    SELECTED_SERVER=${FAVORED_SERVERS[$RANDOM % ${#FAVORED_SERVERS[@]}]}
    log "Selected server from favored states ($FAVORED_STATES): $SELECTED_SERVER"
elif [ ${#FILTERED_SERVERS[@]} -gt 0 ]; then
    # Select random filtered server
    SELECTED_SERVER=${FILTERED_SERVERS[$RANDOM % ${#FILTERED_SERVERS[@]}]}
    log "No favored servers found. Selected random filtered server: $SELECTED_SERVER"
else
    # Fallback to connecting to US general profile if parser failed
    SELECTED_SERVER="US"
    log "No servers parsed. Falling back to country-wide connection: US"
fi

# 5. Connect to the chosen server
log "Establishing connection to $SELECTED_SERVER..."
CONNECT_SUCCESS=false

# Try v4 CLI commands
if command -v protonvpn &>/dev/null; then
    if [ "$SELECTED_SERVER" = "US" ]; then
        protonvpn connect --country US && CONNECT_SUCCESS=true
    else
        protonvpn connect "$SELECTED_SERVER" && CONNECT_SUCCESS=true
    fi
fi

# Try older protonvpn-cli if v4 failed or is not present
if [ "$CONNECT_SUCCESS" = "false" ] && command -v protonvpn-cli &>/dev/null; then
    if [ "$SELECTED_SERVER" = "US" ]; then
        protonvpn-cli c --cc US && CONNECT_SUCCESS=true
    else
        protonvpn-cli c "$SELECTED_SERVER" && CONNECT_SUCCESS=true
    fi
fi

if [ "$CONNECT_SUCCESS" = "true" ]; then
    log "Successfully connected to ProtonVPN ($SELECTED_SERVER)."
else
    log "Error: Failed to connect to ProtonVPN."
    exit 1
fi
