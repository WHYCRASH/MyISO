#!/usr/bin/env python3
# /usr/local/bin/desktop_rename.py
# Renames desktop entries to generic names in /usr/local/share/applications (XDG override).

import os

rename_map = {
    'trojita.desktop': 'Email',
    'pcmanfm-qt.desktop': 'Files',
    'qterminal.desktop': 'Terminal'
}

def rename_in_dirs(directory):
    if not os.path.exists(directory):
        print(f"Directory {directory} does not exist. Skipping.")
        return
    for filename, new_name in rename_map.items():
        filepath = os.path.join(directory, filename)
        if os.path.exists(filepath):
            print(f"Renaming shortcut in {filepath} -> Name={new_name}")
            with open(filepath, 'r') as f:
                lines = f.readlines()
            
            in_entry = False
            for i, line in enumerate(lines):
                if line.startswith('[Desktop Entry]'):
                    in_entry = True
                elif line.startswith('[') and in_entry:
                    # Switched to a different section
                    in_entry = False
                
                if in_entry and line.startswith('Name='):
                    lines[i] = f'Name={new_name}\n'
                    break
            with open(filepath, 'w') as f:
                f.writelines(lines)

def main():
    # Target folders are prefixed with /target since this script runs in the installer env
    rename_in_dirs('/target/usr/local/share/applications')

if __name__ == '__main__':
    main()
