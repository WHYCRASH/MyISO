# Self-Hosted MDM Remote Wipe — Setup Guide

## Overview

This system provides Apple Find My Mac / Microsoft Intune equivalent remote wipe capability for a self-managed Ubuntu 26.04 LTS Dell Latitude 5410. The wipe method is **NIST 800-88 Rev.1 compliant cryptographic erasure** — destroying LUKS2 keyslots renders the encrypted volume permanently irrecoverable without physical overwrite.

### Architecture

```
┌─────────────────────────────┐
│  Owner's VPS (HTTPS)        │
│  Returns "WIPE_CONFIRMED"   │◄── Owner triggers via SSH/web panel
│  or "OK" (normal)           │
└──────────┬──────────────────┘
           │ TLS (pinned cert)
           │ X-Token auth
           ▼
┌─────────────────────────────┐
│  checkin.sh (systemd)       │  Polls every 60s
│  ├─ AppArmor confined       │
│  ├─ IPAddressAllow=VPS only │
│  └─ On "WIPE_CONFIRMED" ──►│──► sanitize.sh
│                             │    ├─ cryptsetup erase
│                             │    ├─ dd header overwrite
│                             │    └─ sysrq poweroff
└─────────────────────────────┘

Alternative triggers:
  - Super+Shift+Delete → emergency-hotkey.sh → sanitize.sh
  - SSH into initramfs Dropbear → run sanitize.sh manually
```

---

## Manual Operator Steps

The following items are **not** included in the ISO and must be provisioned by the operator.

### 1. wpa_supplicant Initramfs Configuration

Create `/etc/wpa_supplicant/initramfs.conf` on the target system:

```ini
ctrl_interface=/run/wpa_supplicant
update_config=0

network={
    ssid="YOUR_HOME_WIFI_SSID"
    psk="YOUR_WIFI_PASSWORD"
    key_mgmt=WPA-PSK
    # For WPA3: key_mgmt=SAE
}
```

> **⚠️ Security Note:** This file is bundled into the initramfs on the **unencrypted `/boot` partition**. Anyone with physical access to the drive can read the WiFi PSK. This is an accepted tradeoff — the alternative is no pre-boot network access on a WiFi-only laptop. Mitigations:
> - Use a dedicated VLAN/SSID for this device
> - The PSK only grants WiFi access, not access to the encrypted volume
> - TPM+PCR binding detects `/boot` tampering

### 2. Dropbear SSH Authorized Keys

Place your SSH public key for pre-boot access:

```bash
sudo mkdir -p /etc/dropbear/initramfs
sudo cp ~/.ssh/id_ed25519.pub /etc/dropbear/initramfs/authorized_keys
sudo chmod 600 /etc/dropbear/initramfs/authorized_keys
```

Install Dropbear itself:

```bash
sudo apt install dropbear-initramfs
```

### 3. Pinned VPS TLS Certificate

Export your server's certificate and place it on the target:

```bash
# On any machine that can reach the VPS:
openssl s_client -connect your-vps.example.com:443 </dev/null 2>/dev/null \
    | openssl x509 -outform PEM > server.pem

# Copy to target:
sudo mkdir -p /etc/mdm
sudo cp server.pem /etc/mdm/server.pem
sudo chmod 644 /etc/mdm/server.pem
```

### 4. Configure checkin.sh

Edit `/usr/local/sbin/checkin.sh` and set:

```bash
MDM_ENDPOINT="https://your-vps.example.com/device/checkin"
MDM_TOKEN="$(openssl rand -hex 32)"    # Generate a strong token
MDM_WIPE_COMMAND="WIPE_CONFIRMED"      # Or any string you choose
```

### 5. Configure checkin.service

Edit `/etc/systemd/system/checkin.service` and replace `203.0.113.1` with your actual VPS IP:

```ini
IPAddressAllow=YOUR_VPS_IP/32
```

### 6. Minimal VPS Endpoint

Your management server needs a single endpoint that:
- Accepts GET requests with an `X-Token` header
- Validates the token matches your configured secret
- Returns `WIPE_CONFIRMED` (or your chosen command string) when you want to trigger a wipe
- Returns anything else (e.g., `OK`) for normal check-ins

Minimal example (Python/Flask):

```python
from flask import Flask, request, abort
app = Flask(__name__)

VALID_TOKEN = "your-strong-random-token-here"
WIPE_ARMED = False  # Set to True via separate admin interface when needed

@app.route("/device/checkin")
def checkin():
    if request.headers.get("X-Token") != VALID_TOKEN:
        abort(403)
    if WIPE_ARMED:
        return "WIPE_CONFIRMED", 200
    return "OK", 200
```

> **Important:** The server should require separate, strong authentication to arm the wipe (e.g., SSH-only admin endpoint, hardware token). The check-in token only authenticates the *device*, not the wipe command.

### 7. Rebuild Initramfs

After placing the wpa_supplicant config and Dropbear keys:

```bash
sudo update-initramfs -u -k all
```

---

## autoinstall.yaml Late-Commands Block

Add this to the `late-commands:` section of `autoinstall.yaml` to deploy all MDM components during installation:

```yaml
    # ====== SECTION: Self-Hosted MDM Remote Wipe Agent ======
    - |
      echo "=== Installing Self-Hosted MDM Agent ==="

      # 1. Deploy sanitize script
      cp /cdrom/sanitize.sh /target/usr/local/sbin/sanitize.sh
      chmod 700 /target/usr/local/sbin/sanitize.sh
      chown root:root /target/usr/local/sbin/sanitize.sh

      # 2. Deploy check-in agent
      cp /cdrom/checkin.sh /target/usr/local/sbin/checkin.sh
      chmod 700 /target/usr/local/sbin/checkin.sh
      chown root:root /target/usr/local/sbin/checkin.sh

      # 3. Deploy and enable systemd service
      cp /cdrom/checkin.service /target/etc/systemd/system/checkin.service
      chroot /target systemctl enable checkin.service

      # 4. Deploy AppArmor profile
      cp /cdrom/apparmor-checkin /target/etc/apparmor.d/usr.local.sbin.checkin.sh
      chroot /target apparmor_parser -r /etc/apparmor.d/usr.local.sbin.checkin.sh || true

      # 5. Create MDM config directory (operator places server.pem here post-install)
      mkdir -p /target/etc/mdm
      chmod 755 /target/etc/mdm

      # 6. Deploy initramfs hooks
      cp /cdrom/initramfs/hooks/wifi-dropbear /target/etc/initramfs-tools/hooks/wifi-dropbear
      chmod 755 /target/etc/initramfs-tools/hooks/wifi-dropbear

      mkdir -p /target/etc/initramfs-tools/scripts/init-premount
      cp /cdrom/initramfs/scripts/init-premount/wifi-connect /target/etc/initramfs-tools/scripts/init-premount/wifi-connect
      chmod 755 /target/etc/initramfs-tools/scripts/init-premount/wifi-connect

      # 7. Deploy emergency hotkey wrapper and sudoers
      cp /cdrom/emergency-hotkey.sh /target/usr/local/bin/emergency-hotkey.sh
      chmod 755 /target/usr/local/bin/emergency-hotkey.sh
      chown root:root /target/usr/local/bin/emergency-hotkey.sh
      echo "shane ALL=(root) NOPASSWD: /usr/local/sbin/sanitize.sh" > /target/etc/sudoers.d/emergency-hotkey
      chmod 440 /target/etc/sudoers.d/emergency-hotkey

      # 8. Deploy LXQt keyboard shortcut config
      mkdir -p /target/home/shane/.config/lxqt
      cat << 'SHORTCUT' > /target/home/shane/.config/lxqt/globalkeyshortcuts.conf
      [Meta+Shift+Delete]
      Comment=Emergency Sanitize
      Exec=/usr/local/bin/emergency-hotkey.sh
      SHORTCUT
      chroot /target chown -R 1000:1000 /home/shane/.config/lxqt

      # 9. Immutable bit on sanitize script (prevent accidental modification)
      chroot /target chattr +i /usr/local/sbin/sanitize.sh

      echo "MDM agent deployed. Operator must provide: server.pem, wpa_supplicant initramfs.conf, Dropbear keys."
```

---

## Post-Install Checklist

- [ ] Place `/etc/wpa_supplicant/initramfs.conf` with WiFi credentials
- [ ] Place `/etc/dropbear/initramfs/authorized_keys` with SSH pubkey
- [ ] Place `/etc/mdm/server.pem` with pinned VPS certificate
- [ ] Edit `/usr/local/sbin/checkin.sh` — set endpoint, token, wipe command
- [ ] Edit `/etc/systemd/system/checkin.service` — set VPS IP in `IPAddressAllow`
- [ ] Run `sudo update-initramfs -u -k all` to rebuild initramfs with WiFi/Dropbear
- [ ] Run `sudo systemctl restart checkin.service` to start the agent
- [ ] Deploy the VPS endpoint
- [ ] **Test:** Verify check-in works with a non-wipe response before arming
- [ ] Log out / back in for LXQt shortcut (`Super+Shift+Delete`) to take effect
