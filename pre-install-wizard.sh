#!/usr/bin/env bash
# /home/shane/TheMasterISO/pre-install-wizard.sh
# Interactive wizard to securely configure credentials, keys, and MDM before building the ISO.

set -e

WORKSPACE="/home/shane/TheMasterISO"

echo "========================================================"
echo "   TheMasterISO — Guided Pre-Install Configuration"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------------
# 1. LUKS & GRUB Recovery Password
# -----------------------------------------------------------------------------
echo -e "\e[1;34m[1/4] LUKS & GRUB Recovery Password\e[0m"
echo "This password will be used to unlock the encrypted drive if the TPM fails,"
echo "and to access the GRUB recovery menu."
read -rs -p "Enter secure password: " LUKS_PASS
echo
read -rs -p "Confirm password: " LUKS_PASS_CONFIRM
echo
if [ "$LUKS_PASS" != "$LUKS_PASS_CONFIRM" ]; then
    echo -e "\e[1;31mPasswords do not match. Exiting.\e[0m"
    exit 1
fi

echo "Generating PBKDF2 hash (this may take several seconds)..."
GRUB_HASH=$(echo -e "$LUKS_PASS\n$LUKS_PASS" | grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf2/ {print $NF}')

# Patch the temporary placeholder out of autoinstall.yaml
sed -i "s/TemporaryDefaultPassword123!/$LUKS_PASS/g" "$WORKSPACE/autoinstall.yaml"
# Replace the existing long hash placeholder
sed -i -E "s/password_pbkdf2 admin grub\.pbkdf2.*/password_pbkdf2 admin $GRUB_HASH/g" "$WORKSPACE/autoinstall.yaml"
echo -e "✅ \e[32mPasswords and hashes securely injected into autoinstall.yaml.\e[0m"
echo ""

# -----------------------------------------------------------------------------
# 2. MDM Remote Wipe Configuration
# -----------------------------------------------------------------------------
echo -e "\e[1;34m[2/4] MDM Remote Wipe Configuration\e[0m"
read -p "Are you hosting the endpoint on a static VPS (v) or a Serverless Function (s)? [v/s]: " MDM_TYPE

if [ "$MDM_TYPE" = "s" ]; then
    echo "Serverless mode selected. Removing static IP-locking from systemd service."
    sed -i '/IPAddressAllow=/d' "$WORKSPACE/checkin.service"
else
    read -p "Enter the static IPv4 address of your VPS: " VPS_IP
    sed -i "s|IPAddressAllow=.*|IPAddressAllow=$VPS_IP/32|g" "$WORKSPACE/checkin.service"
fi

read -p "Enter the full HTTPS endpoint URL (e.g., https://api.example.com/checkin): " MDM_URL
sed -i "s|MDM_ENDPOINT=\".*\"|MDM_ENDPOINT=\"$MDM_URL\"|g" "$WORKSPACE/checkin.sh"

read -p "Enter the secret wipe trigger phrase [Default: WIPE_CONFIRMED]: " WIPE_CMD
WIPE_CMD=${WIPE_CMD:-WIPE_CONFIRMED}
sed -i "s|MDM_WIPE_COMMAND=\".*\"|MDM_WIPE_COMMAND=\"$WIPE_CMD\"|g" "$WORKSPACE/checkin.sh"

MDM_TOKEN=$(openssl rand -hex 32)
sed -i "s|MDM_TOKEN=\".*\"|MDM_TOKEN=\"$MDM_TOKEN\"|g" "$WORKSPACE/checkin.sh"

echo -e "✅ \e[32mMDM Agent configured.\e[0m"
echo -e "   \e[1;33mIMPORTANT: Your authentication token is ->\e[0m $MDM_TOKEN"
echo "   Save this token! Your server must validate this in the 'X-Token' HTTP header."
echo ""

# -----------------------------------------------------------------------------
# 3. Pre-Boot Network Unlock (Initramfs)
# -----------------------------------------------------------------------------
echo -e "\e[1;34m[3/4] Pre-Boot Network Unlock (Dropbear & WiFi)\e[0m"
echo "This allows you to SSH into the laptop to type the LUKS password or trigger MDM."
read -p "Enter your home WiFi SSID: " WIFI_SSID
read -rs -p "Enter your home WiFi Password: " WIFI_PASS
echo
# Escape backslashes and double quotes to prevent configuration injection
SAFE_SSID="${WIFI_SSID//\\/\\\\}"
SAFE_SSID="${SAFE_SSID//\"/\\\"}"
SAFE_PASS="${WIFI_PASS//\\/\\\\}"
SAFE_PASS="${SAFE_PASS//\"/\\\"}"



cat << EOF > "$WORKSPACE/initramfs.conf"
ctrl_interface=/run/wpa_supplicant
update_config=0
network={
    ssid="$SAFE_SSID"
    psk="$SAFE_PASS"
    key_mgmt=WPA-PSK
}
EOF
chmod 600 "$WORKSPACE/initramfs.conf"
echo -e "✅ \e[32minitramfs.conf generated.\e[0m"

echo "Generating dedicated SSH keypair for pre-boot unlock..."
mkdir -p "$WORKSPACE/ssh_keys"
if [ ! -f "$WORKSPACE/ssh_keys/initramfs_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$WORKSPACE/ssh_keys/initramfs_ed25519" -N "" -C "latitude-preboot" >/dev/null
fi
cp "$WORKSPACE/ssh_keys/initramfs_ed25519.pub" "$WORKSPACE/authorized_keys"
chmod 644 "$WORKSPACE/authorized_keys"
echo -e "✅ \e[32mSSH keys generated.\e[0m"
echo "   Private key saved to: $WORKSPACE/ssh_keys/initramfs_ed25519"
echo ""

# -----------------------------------------------------------------------------
# 4. MDM Server Certificate Placeholder
# -----------------------------------------------------------------------------
echo -e "\e[1;34m[4/4] MDM Server TLS Certificate\e[0m"
if [ ! -f "$WORKSPACE/server.pem" ]; then
    touch "$WORKSPACE/server.pem"
    echo -e "⚠️  \e[1;33mCreated empty placeholder for server.pem\e[0m"
    echo "   Because the MDM agent uses strict certificate pinning, you MUST paste"
    echo "   your server's PEM certificate into $WORKSPACE/server.pem before building."
    echo "   You can fetch it using:"
    echo "   openssl s_client -connect your-url.com:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > server.pem"
else
    echo -e "✅ \e[32mserver.pem already exists.\e[0m"
fi
echo ""

echo "========================================================"
echo -e "\e[1;32m Guided setup complete!\e[0m"
echo " Next steps:"
echo " 1. Ensure server.pem contains your valid endpoint certificate."
echo " 2. Insert your CIDATA drive if you want to ingest extra secrets (like VPN)."
echo " 3. Run ./build-docker.sh to build the zero-touch ISO."
echo "========================================================"
