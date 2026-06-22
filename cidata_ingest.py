#!/usr/bin/env python3
# /usr/local/bin/cidata_ingest.py
# Ingests secrets from the CIDATA drive during installation.
# Supports encrypted archive 'secrets.tar.gz.enc' (AES-256-CBC, PBKDF2)
# and falls back to cleartext 'user-data' YAML.

import yaml
import os
import sys
import subprocess
import getpass

def prompt_passphrase():
    tty_out = sys.stdout
    tty_in = sys.stdin

    # Attempt to use active TTY if available
    tty_path = '/dev/tty1'
    if not os.path.exists(tty_path):
        tty_path = '/dev/console'
        
    try:
        tty_fd = os.open(tty_path, os.O_RDWR | os.O_NOCTTY)
        tty_in = os.fdopen(tty_fd, 'r')
        tty_out = os.fdopen(tty_fd, 'w')
    except Exception as e:
        print(f"Warning: could not open {tty_path}, falling back to stdin/stdout: {e}")

    tty_out.write("\n============================================\n")
    tty_out.write("   ENTER CIDATA SECRETS DECRYPTION KEY\n")
    tty_out.write("============================================\n")
    tty_out.flush()
    
    try:
        passphrase = getpass.getpass(prompt="Enter passphrase: ", stream=tty_out)
    except Exception as e:
        # Fallback if getpass fails (e.g. not a terminal at all)
        tty_out.write("Enter passphrase: ")
        tty_out.flush()
        passphrase = tty_in.readline().strip()
        
    tty_out.write("\nPassphrase received. Decrypting...\n")
    tty_out.flush()
    return passphrase

def decrypt_secrets_archive(enc_file):
    print(f"Found encrypted secrets archive at {enc_file}")
    passphrase = prompt_passphrase()
    
    # Create temp tarball path
    dec_tar = '/tmp/secrets.tar.gz'
    
    # Run openssl decryption command
    # Uses PBKDF2 with 100k iterations (matches modern openssl defaults)
    cmd = [
        "openssl", "enc", "-d", "-aes-256-cbc", 
        "-pbkdf2", "-iter", "100000",
        "-pass", f"pass:{passphrase}",
        "-in", enc_file,
        "-out", dec_tar
    ]
    
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"ERROR: Decryption failed! {res.stderr}")
        return False
        
    # Extract tarball directly to target's home directory
    # Note: the tarball should contain folders like '.config', '.local', or direct files
    print("Extracting secrets tarball to target home...")
    extract_cmd = ["tar", "-xzf", dec_tar, "-C", "/target/home/shane/"]
    res_extract = subprocess.run(extract_cmd, capture_output=True, text=True)
    
    # Clean up decrypted file
    if os.path.exists(dec_tar):
        os.remove(dec_tar)
        
    if res_extract.returncode != 0:
        print(f"ERROR: Extraction failed! {res_extract.stderr}")
        return False
        
    # Correct ownership and permissions of home directory files
    print("Correcting ownership to user shane (1000:1000)...")
    # ⚡ Bolt: Replaced os.system("chown/find") subshells with native os.walk for better performance
    for root, dirs, files in os.walk('/target/home/shane/'):
        try:
            os.chown(root, 1000, 1000)
        except OSError:
            pass
        for name in files:
            path = os.path.join(root, name)
            try:
                os.chown(path, 1000, 1000)
                if name in ('rclone.conf', 'claude.json'):
                    os.chmod(path, 0o600)
            except OSError:
                pass
    
    print("Secrets decryption and ingestion completed successfully.")
    return True

def _write_single_file(file_info):
    path = file_info.get('path')
    content = file_info.get('content')
    owner = file_info.get('owner', 'shane:shane')
    permissions = file_info.get('permissions', '0600')

    if not path or content is None:
        return

    target_path = path
    if target_path.startswith('/'):
        target_path = '/target' + target_path
    else:
        target_path = '/target/home/shane/' + target_path

    print(f"Writing {path} -> {target_path}")
    os.makedirs(os.path.dirname(target_path), exist_ok=True)

    with open(target_path, 'w') as out_f:
        out_f.write(content)

    try:
        mode = int(permissions, 8)
        os.chmod(target_path, mode)
    except ValueError:
        os.chmod(target_path, 0o600)

    try:
        user, group = owner.split(':')
        uid = 1000 if user == 'shane' else 0
        gid = 1000 if group == 'shane' else 0
        os.chown(target_path, uid, gid)
        parent_dir = os.path.dirname(target_path)
        while parent_dir != '/target/home' and parent_dir != '/target' and parent_dir != '/':
            os.chown(parent_dir, uid, gid)
            parent_dir = os.path.dirname(parent_dir)
    except Exception as e:
        print(f"Warning: could not set ownership for {target_path}: {e}")

def ingest_cleartext_yaml(user_data_path):
    print(f"Parsing cleartext {user_data_path}...")
    try:
        with open(user_data_path, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        print(f"Error reading or parsing YAML: {e}")
        return False

    if not config:
        print("YAML is empty.")
        return False

    write_files = config.get('write_files', [])
    if not write_files:
        print("No 'write_files' block found in user-data.")
        return False

    print(f"Found {len(write_files)} files to ingest.")
    for file_info in write_files:
        _write_single_file(file_info)

    print("Cleartext secrets ingestion completed successfully.")
    return True

def main():
    enc_archive = '/tmp/cidata/secrets.tar.gz.enc'
    cleartext_yaml = '/tmp/cidata/user-data'
    
    if os.path.exists(enc_archive):
        success = decrypt_secrets_archive(enc_archive)
        if not success:
            sys.exit(1)
    elif os.path.exists(cleartext_yaml):
        success = ingest_cleartext_yaml(cleartext_yaml)
        if not success:
            sys.exit(1)
    else:
        print("Error: No secrets archive or user-data file found on CIDATA drive.")
        sys.exit(1)

if __name__ == '__main__':
    main()
