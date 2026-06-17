#!/usr/bin/env bash
# /etc/profile.d/firefox-profile-setup.sh
# Automates the setup of Firefox with arkenfox-style user.js for new graphical logins

# Run only in graphical sessions
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    # Prevent run if already configured for this login session
    if [ "${FIREFOX_INIT_DONE:-0}" -eq 1 ]; then
        return 0
    fi
    export FIREFOX_INIT_DONE=1

    # Standard Mozilla Firefox Profile directory
    FF_DIR="$HOME/.mozilla/firefox"
    USER_JS_SOURCE="/etc/firefox/user.js"

    # If the user.js source does not exist, do nothing
    if [ ! -f "$USER_JS_SOURCE" ]; then
        return 0
    fi

    # Create directory structure if missing
    mkdir -p "$FF_DIR"

    # Create the default profile if no profile directory exists
    # Firefox requires X/Wayland or headless to create a profile. We use headless for automation.
    if [ ! -f "$FF_DIR/profiles.ini" ]; then
        echo "Initializing default Firefox profile..."
        timeout 5 firefox --headless --CreateProfile "default-release" &>/dev/null || true
    fi

    # Find the newly created profile folder (usually ends in .default-release)
    PROFILE_DIR=$(find "$FF_DIR" -maxdepth 1 -name "*.default-release" -print -quit || true)
    
    if [ -n "$PROFILE_DIR" ]; then
        # Copy the pre-configured arkenfox user.js
        cp "$USER_JS_SOURCE" "$PROFILE_DIR/user.js"
        echo "Firefox privacy profile configured at $PROFILE_DIR/user.js"
    fi
fi
