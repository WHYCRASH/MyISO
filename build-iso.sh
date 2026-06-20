#!/usr/bin/env bash
# /home/shane/TheMasterISO/build-iso.sh
# IaC Orchestrator: Downloads base Ubuntu ISO, patches bootloaders,
# maps custom configurations, and repacks UEFI-bootable installer ISO.

set -euo pipefail

# Configuration
WORKSPACE="/home/shane/TheMasterISO"
BASE_ISO_DIR="$WORKSPACE/base_iso"
BUILD_DIR="$WORKSPACE/build"
OUTPUT_DIR="$WORKSPACE/output"
CUSTOM_ISO="$OUTPUT_DIR/ubuntu-26.04-custom-latitude5410.iso"
BOOT_TIMEOUT=2

# Base ISO configuration (Ubuntu 26.04 LTS / current server ISO - no codename yet)
UBUNTU_DAILY_URL="https://cdimage.ubuntu.com/ubuntu-server/daily-live/current/"

log() {
    echo -e "\e[1;32m[+] $1\e[0m"
}

error() {
    echo -e "\e[1;31m[-] ERROR: $1\e[0m" >&2
    exit 1
}

# 1. Install prerequisites if running as root / sudo available
check_prerequisites() {
    log "Checking host system packages..."
    local pkgs=(xorriso wget curl grep sed)
    local missing=()
    for pkg in "${pkgs[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log "Missing packages: ${missing[*]}. Attempting automatic installation..."
        if [ "$EUID" -ne 0 ]; then
            sudo apt-get update && sudo apt-get install -y "${missing[@]}"
        else
            apt-get update && apt-get install -y "${missing[@]}"
        fi
    fi
}

# 2. Resolve and download base ISO
download_base_iso() {
    mkdir -p "$BASE_ISO_DIR"
    
    log "Resolving latest daily-live server ISO from $UBUNTU_DAILY_URL..."
    local iso_filename
    iso_filename=$(curl -sL "$UBUNTU_DAILY_URL" | grep -o -E 'href="[^"]+-live-server-amd64\.iso"' | head -n1 | cut -d'"' -f2 || true)
    
    if [ -z "$iso_filename" ]; then
        error "Could not resolve live-server ISO filename from cdimage mirror."
    fi
    
    local download_url="${UBUNTU_DAILY_URL}${iso_filename}"
    local base_iso_path="$BASE_ISO_DIR/ubuntu-base.iso"
    
    if [ ! -f "$base_iso_path" ]; then
        log "Downloading base ISO: $iso_filename..."
        wget --show-progress -O "$base_iso_path" "$download_url"
    else
        log "Found existing base ISO at $base_iso_path."
    fi
    
    echo "$base_iso_path"
}

# 3. Process and patch boot config files
patch_boot_configs() {
    local base_iso="$1"
    mkdir -p "$BUILD_DIR"
    
    log "Extracting bootloader configurations from base ISO..."
    
    # Extract GRUB config
    xorriso -osirrox on -indev "$base_iso" -extract /boot/grub/grub.cfg "$BUILD_DIR/grub.cfg" 2>/dev/null || \
        error "Failed to extract grub.cfg from base ISO."
    chmod +w "$BUILD_DIR/grub.cfg"
    
    # Extract isolinux config if it exists (legacy BIOS boot support)
    local has_isolinux=false
    if xorriso -indev "$base_iso" -find /isolinux -name txt.cfg -exec report 2>/dev/null | grep -q "txt.cfg"; then
        xorriso -osirrox on -indev "$base_iso" -extract /isolinux/txt.cfg "$BUILD_DIR/txt.cfg" 2>/dev/null || true
        chmod +w "$BUILD_DIR/txt.cfg" || true
        has_isolinux=true
    fi
    
    log "Patching bootloaders to enable unattended autoinstall..."
    
    # Modify GRUB to auto-inject the /user-data from ISO root and escape semicolons
    # We replace kernel parameters to append 'autoinstall ds=nocloud;s=/cdrom/' and 'console=ttyS0'
    sed -i 's|\(linux\s\+/casper/[a-zA-Z0-9.-]\+\)\s\+\(.*\)$|\1 autoinstall ds=nocloud\\;s=/cdrom/ console=ttyS0 \2|g' "$BUILD_DIR/grub.cfg"
    
    # Set immediate default boot timeout
    sed -i "s/timeout=[0-9]\\+/timeout=${BOOT_TIMEOUT}/g" "$BUILD_DIR/grub.cfg"
    
    # Modify isolinux legacy BIOS config if present
    if [ "$has_isolinux" = "true" ] && [ -f "$BUILD_DIR/txt.cfg" ]; then
        sed -i 's|\(append\s\+.*\)$|\1 autoinstall ds=nocloud;s=/cdrom/|g' "$BUILD_DIR/txt.cfg"
    fi
    
    echo "$has_isolinux"
}

# 4. Pack custom files into ISO using xorriso native replay
repack_iso() {
    local base_iso="$1"
    local has_isolinux="$2"
    
    mkdir -p "$OUTPUT_DIR"
    touch "$BUILD_DIR/meta-data" # Create empty meta-data file
    
    log "Assembling custom configurations into new ISO..."
    
    # Construct base xorriso command mapping local files directly into ISO structure
    local xorriso_cmd=(
        xorriso
        -indev "$base_iso"
        -outdev "$CUSTOM_ISO"
        -map "$WORKSPACE/autoinstall.yaml" "/user-data"
        -map "$BUILD_DIR/meta-data" "/meta-data"
        -map "$BUILD_DIR/grub.cfg" "/boot/grub/grub.cfg"
        -map "$WORKSPACE/vpn-auto.sh" "/vpn-auto.sh"
        -map "$WORKSPACE/rclone-backup.service" "/rclone-backup.service"
        -map "$WORKSPACE/rclone-backup.timer" "/rclone-backup.timer"
        -map "$WORKSPACE/firefox-user.js" "/firefox-user.js"
        -map "$WORKSPACE/firefox-profile-setup.sh" "/firefox-profile-setup.sh"
        -map "$WORKSPACE/cidata_ingest.py" "/cidata_ingest.py"
        -map "$WORKSPACE/desktop_rename.py" "/desktop_rename.py"
        -map "$WORKSPACE/sanitize.sh" "/sanitize.sh"
        -map "$WORKSPACE/checkin.sh" "/checkin.sh"
        -map "$WORKSPACE/checkin.service" "/checkin.service"
        -map "$WORKSPACE/apparmor-checkin" "/apparmor-checkin"
        -map "$WORKSPACE/emergency-hotkey.sh" "/emergency-hotkey.sh"
        -map "$WORKSPACE/initramfs/hooks/wifi-dropbear" "/initramfs/hooks/wifi-dropbear"
        -map "$WORKSPACE/initramfs/scripts/init-premount/wifi-connect" "/initramfs/scripts/init-premount/wifi-connect"
        -map "$WORKSPACE/server.pem" "/server.pem"
        -map "$WORKSPACE/authorized_keys" "/authorized_keys"
        -map "$WORKSPACE/initramfs.conf" "/initramfs.conf"
    )
    
    # Append isolinux configuration mapping if applicable
    if [ "$has_isolinux" = "true" ] && [ -f "$BUILD_DIR/txt.cfg" ]; then
        xorriso_cmd+=("-map" "$BUILD_DIR/txt.cfg" "/isolinux/txt.cfg")
    fi
    
    # Add native boot metadata replay options (critical for EFI/BIOS hybrid booting)
    xorriso_cmd+=("-boot_image" "any" "replay")
    
    # Execute xorriso
    log "Compiling new ISO..."
    "${xorriso_cmd[@]}"
    
    log "ISO Repacking complete!"
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$BUILD_DIR"
}

main() {
    check_prerequisites
    local base_iso
    base_iso=$(download_base_iso)
    local has_isolinux
    has_isolinux=$(patch_boot_configs "$base_iso")
    repack_iso "$base_iso" "$has_isolinux"
    cleanup
    
    log "=========================================================="
    log "SUCCESS! Custom ISO built successfully:"
    log "Path: $CUSTOM_ISO"
    log "=========================================================="
    log "Steps to deploy secrets drive:"
    log "1. Format a USB drive as FAT32 or EXT4."
    log "2. Label the partition 'CIDATA' (exactly)."
    log "3. Copy the configured 'cidata-user-data.yaml' template to the root"
    log "   of that USB drive and rename it to 'user-data'."
    log "4. Insert both the installation media (ISO) and the CIDATA drive"
    log "   into the target Dell Latitude 5410 to run the automated install."
    log "=========================================================="
    log "Running automated ISO smoke test (timeout: 30 minutes)..."
    qemu-img create -f qcow2 "$BUILD_DIR/test-disk.qcow2" 40G > /dev/null
    SMOKE_RESULT=0
    timeout 1800 qemu-system-x86_64 \
        -m 4096 -smp 2 \
        -enable-kvm \
        -nographic \
        -drive file="$BUILD_DIR/test-disk.qcow2",format=qcow2 \
        -cdrom "$CUSTOM_ISO" \
        -boot once=d \
        -serial stdio \
        2>&1 | tee "$BUILD_DIR/smoke-test.log" | grep -m 1 "login:" || SMOKE_RESULT=$?
    rm -f "$BUILD_DIR/test-disk.qcow2"
    if [ "$SMOKE_RESULT" -eq 0 ]; then
        log "Smoke test passed! System reached login."
    else
        log "WARNING: Smoke test did not detect login prompt (exit code: $SMOKE_RESULT)."
        log "Review smoke test log: $BUILD_DIR/smoke-test.log"
    fi
}

main
