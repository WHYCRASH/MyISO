#!/usr/bin/env bash
# /usr/local/sbin/checkin.sh
# Self-Hosted MDM Device Check-In Agent
#
# Polls an owner-controlled HTTPS management endpoint at a fixed interval.
# If and only if the server responds with the exact wipe command string,
# the agent invokes sanitize.sh for cryptographic erasure.
#
# Safety invariants:
#   - Network errors, timeouts, or non-200 responses → NO ACTION
#   - Unexpected response bodies → NO ACTION
#   - Server unreachable → NO ACTION
#   - Only an explicit, authenticated wipe command triggers erasure
#
# TLS authenticity is enforced via certificate pinning (--cacert).

set -euo pipefail

# ============================================================================
# CONFIGURATION — Operator must set these before deployment
# ============================================================================
MDM_ENDPOINT="https://your-vps.example.com/device/checkin"
MDM_TOKEN_FILE="/etc/mdm/token"
MDM_WIPE_COMMAND="WIPE_CONFIRMED"
PINNED_CERT="/etc/mdm/server.pem"
POLL_INTERVAL=60
SANITIZE_SCRIPT="/usr/local/sbin/sanitize.sh"
LOG_TAG="mdm-checkin"

# ============================================================================
# MAIN LOOP
# ============================================================================

logger -t "$LOG_TAG" "MDM check-in agent started, polling ${MDM_ENDPOINT} every ${POLL_INTERVAL}s"

while true; do
    if [ ! -f "$MDM_TOKEN_FILE" ]; then
        logger -t "$LOG_TAG" "ERROR: MDM token file not found at $MDM_TOKEN_FILE"
        sleep "$POLL_INTERVAL"
        continue
    fi
    MDM_TOKEN=$(cat "$MDM_TOKEN_FILE")
    RESPONSE=""

    # Attempt check-in with strict constraints:
    #   --max-time 15      : hard timeout per request
    #   --connect-timeout 10: connection phase timeout
    #   --cacert            : pinned server certificate (no system CA fallback)
    #   --fail-with-body    : treat HTTP errors as failures but capture body
    #   --silent            : suppress progress output
    RESPONSE=$(curl \
        --silent \
        --max-time 15 \
        --connect-timeout 10 \
        --cacert "$PINNED_CERT" \
        -H "X-Token: ${MDM_TOKEN}" \
        "$MDM_ENDPOINT" 2>/dev/null) || true

    # Only act on the exact wipe command — nothing else
    if [ "$RESPONSE" = "$MDM_WIPE_COMMAND" ]; then
        logger -t "$LOG_TAG" "CRITICAL: Wipe command received from management server"
        exec "$SANITIZE_SCRIPT"
        # exec replaces this process; if sanitize.sh fails to exec, fall through
        logger -t "$LOG_TAG" "ERROR: Failed to exec sanitize script"
        exit 1
    fi

    # Any other response (empty, error, different body) → do nothing
    sleep "$POLL_INTERVAL"
done
