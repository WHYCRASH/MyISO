#!/usr/bin/env bash
# /usr/local/sbin/sanitize.sh
# NIST 800-88 Compliant Cryptographic Erasure for LUKS2 Volumes
#
# Destroys all LUKS2 keyslots rendering the encrypted volume irrecoverable,
# then overwrites the partition header with random bytes and powers off.
#
# This is the self-hosted equivalent of a commercial MDM remote wipe
# (Jamf, Intune, Find My Mac). It performs cryptographic erasure only —
# no physical overwrite is needed for SSDs per NIST 800-88 Rev.1 §2.4.
#
# NOTE: After deployment, apply `chattr +i /usr/local/sbin/sanitize.sh`
#       to prevent accidental modification. The autoinstall late-commands
#       block handles this automatically.

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
LUKS_PARTITION=$(blkid -t TYPE=crypto_LUKS -o device | head -n1)
HEADER_OVERWRITE_BYTES=33554432  # 32 MiB — covers LUKS2 header + metadata areas
LOG_TAG="mdm-sanitize"

# ============================================================================
# EXECUTION
# ============================================================================

logger -t "$LOG_TAG" "CRITICAL: Cryptographic erasure initiated on $LUKS_PARTITION"

# 1. Destroy all LUKS2 keyslots (cryptographic erasure)
#    After this, the master key is unrecoverable — all data on the volume
#    is permanently inaccessible regardless of passphrase or TPM state.
if cryptsetup isLuks "$LUKS_PARTITION" 2>/dev/null; then
    cryptsetup erase --batch-mode "$LUKS_PARTITION"
    logger -t "$LOG_TAG" "All LUKS2 keyslots destroyed"
else
    logger -t "$LOG_TAG" "WARNING: $LUKS_PARTITION is not a LUKS device, proceeding with header overwrite"
fi

# 2. Overwrite the LUKS2 header area with random bytes for defense in depth.
#    This ensures metadata (cipher, hash, iteration count) is also gone.
dd if=/dev/urandom of="$LUKS_PARTITION" bs=4096 count=$((HEADER_OVERWRITE_BYTES / 4096)) conv=notrunc 2>/dev/null
logger -t "$LOG_TAG" "Partition header overwritten with ${HEADER_OVERWRITE_BYTES} bytes of random data"

# 3. Sync and flush all buffers
sync

# 4. Immediate power off via sysrq — bypasses userspace shutdown to prevent
#    any recovery attempt during graceful shutdown sequence
logger -t "$LOG_TAG" "Powering off immediately"
echo 1 > /proc/sys/kernel/sysrq
echo o > /proc/sysrq-trigger

# Fallback if sysrq fails
sleep 2
poweroff -f
