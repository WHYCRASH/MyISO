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
    try:
        with os.scandir(directory) as entries:
            for entry in entries:
                if entry.is_file() and entry.name in rename_map:
                    new_name = rename_map[entry.name]
                    filepath = entry.path
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
    except OSError as e:
        print(f"Error accessing directory {directory}: {e}")

def main():
    # Target folders are prefixed with /target since this script runs in the installer env
    rename_in_dirs('/target/usr/local/share/applications')

if __name__ == '__main__':
    main()
