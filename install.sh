#!/usr/bin/env bash
# Install or upgrade the OctoPulse plasmoid (per-user, no sudo).
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
PKG="$DIR/package"
ID="com.conqrex.octopulse"

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
    echo "Upgrading $ID ..."
    kpackagetool6 -t Plasma/Applet -u "$PKG"
else
    echo "Installing $ID ..."
    kpackagetool6 -t Plasma/Applet -i "$PKG"
fi

echo
echo "Installed to ~/.local/share/plasma/plasmoids/$ID/"
echo "Add it: right-click your desktop or panel -> Add Widgets -> search 'OctoPulse'."
echo "Then open its settings -> Account -> paste a GitHub Personal Access Token."
echo "Reload after changes: kquitapp6 plasmashell && kstart plasmashell"
