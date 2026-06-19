# Auditing Plan: Ubuntu Automated Installer & Remote Wipe MDM

This document outlines a comprehensive auditing strategy for the custom Ubuntu automated installer ISO and its integrated Self-Hosted MDM Remote Wipe capabilities.

## 1. Security Audit
* **Cryptographic Erasure (`sanitize.sh`)**:
  * Verify `cryptsetup erase` reliably destroys LUKS2 keyslots on the identified block device.
  * Audit the fallback mechanism that overwrites the LUKS partition header with `HEADER_OVERWRITE_BYTES` from `/dev/urandom`.
  * Ensure the immediate power-off via sysrq (`echo o > /proc/sysrq-trigger`) bypasses userspace shutdown securely.
* **Network & Endpoint Security (`checkin.sh` & `checkin.service`)**:
  * Validate TLS certificate pinning (`--cacert /etc/mdm/server.pem`) and strict `curl` timeouts against MITM or slowloris attacks.
  * Verify the `X-Token` authentication header is correctly utilized.
  * Audit the `checkin.service` systemd hardening: `IPAddressAllow=203.0.113.1/32`, `NoNewPrivileges`, `CapabilityBoundingSet`, `ProtectSystem=strict`, and other namespace/sandbox configurations.
* **Access Controls (AppArmor & Sudo)**:
  * Review `/etc/apparmor.d/usr.local.sbin.checkin.sh` to ensure it correctly confines the check-in script, restricts network access strictly to TCP streams, and successfully prevents memory dumping (`deny /proc/keys`, etc.).
  * Confirm that `emergency-hotkey.sh` executes `/usr/local/sbin/sanitize.sh` securely via the configured sudoers drop-in.
* **LUKS / TPM Integration (`autoinstall.yaml`)**:
  * Verify that Subiquity successfully provisions LUKS2 and correctly binds it to TPM 2.0 (PCRs 0+4+7) as defined in the `late-commands`.

## 2. Feature Functionality Audit
* **MDM Check-In Loop**:
  * Test that the daemon polls the server every 60 seconds (`POLL_INTERVAL=60`).
  * Confirm that the script ignores all responses except the exact match for `MDM_WIPE_COMMAND`.
* **Automated Installation (`autoinstall.yaml`)**:
  * Validate Subiquity configuration sets the locale, keyboard layout, identity (hostname, hashed password), network, and LVM-on-LUKS storage properly.
  * Test the `late-commands` execution order (deploying scripts, systemd units, apparmor profiles, and initramfs hooks).
* **ISO Generation (`build-iso.sh` & `build-docker.sh`)**:
  * Ensure the Docker wrapper (`build-docker.sh`) successfully spins up a reproducible environment.
  * Validate the steps in `build-iso.sh` for downloading the daily live ISO, patching grub, and packaging the custom autoinstall configuration via `xorriso`.

## 3. Redundancy Audit
* **Wipe Triggers**:
  * Confirm the main MDM trigger operates independently of the local emergency trigger (`emergency-hotkey.sh`).
  * Evaluate the reliability of the initramfs Dropbear SSH fallback.
* **Network Fallback**:
  * Ensure `checkin.sh` correctly swallows curl errors (`|| true`) and sleeps without crashing if the network is disconnected or the endpoint is unreachable.

## 4. Performance Audit
* **Resource Usage**:
  * Monitor CPU and memory consumption of the idle `checkin.sh` bash loop.
  * Evaluate the impact of the strict systemd sandboxing on the service startup time.
* **Build Efficiency**:
  * Assess the build time inside the Docker container (`ubuntu-iso-builder`) and identify potential cache optimizations for the `apt-get` dependency installation.
