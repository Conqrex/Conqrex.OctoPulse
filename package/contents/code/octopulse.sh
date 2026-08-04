#!/usr/bin/env bash
# OctoPulse helper: keyring access and desktop notifications.
# The widget's QML runs this through the Plasma executable engine; everything
# network-related stays in QML (XMLHttpRequest), only local integrations live here.
set -u

SUB="${1:-}"
SERVICE="cnq-octopulse"

case "$SUB" in
    # Print the stored GitHub token (empty output = not stored / no keyring).
    secret-get)
        if command -v secret-tool >/dev/null 2>&1; then
            secret-tool lookup service "$SERVICE" key token 2>/dev/null
        elif command -v kwallet-query >/dev/null 2>&1; then
            kwallet-query -r "$SERVICE-token" -f Passwords kdewallet 2>/dev/null
        fi
        exit 0
        ;;

    # Store the token. Read from stdin so it never appears on a command line
    # by itself; callers use: printf %s "$TOKEN" | ... secret-set
    secret-set)
        TOKEN="$(cat)"
        [ -n "$TOKEN" ] || exit 1
        if command -v secret-tool >/dev/null 2>&1; then
            printf %s "$TOKEN" | secret-tool store --label="OctoPulse GitHub token" \
                service "$SERVICE" key token
        elif command -v kwallet-query >/dev/null 2>&1; then
            printf %s "$TOKEN" | kwallet-query -w "$SERVICE-token" -f Passwords kdewallet
        else
            exit 2
        fi
        ;;

    secret-clear)
        command -v secret-tool >/dev/null 2>&1 && \
            secret-tool clear service "$SERVICE" key token 2>/dev/null
        exit 0
        ;;

    # notify <summary> <body> [icon]
    notify)
        command -v notify-send >/dev/null 2>&1 || exit 0
        notify-send --app-name=OctoPulse \
            --icon="${4:-vcs-normal}" "${2:-OctoPulse}" "${3:-}"
        ;;

    *)
        echo "usage: octopulse.sh secret-get|secret-set|secret-clear|notify" >&2
        exit 64
        ;;
esac
